--[[
  BananaGuild - Promote
  Reminder + step by step promotion of new members:
    * after 'weeks' on the start rank (db.promo.from) the leaders/officers who may promote get a window
    * a click promotes one rank at a time (GuildPromote) until the target rank (db.promo.to) is reached
  The addon only ever touches members who are on the start rank right now; every other rank is protected.
  WoW 1.12 has no "set rank" call, only GuildPromote / GuildDemote (one rank per call), so the roster is checked after each step.
]]

local BG = BananaGuild
local Promo = {}
BG.Promo = Promo

Promo.queue = {}   -- names waiting
Promo.busy = {}    -- name -> true while queued or running
Promo.cur = nil    -- { name, wait, lastRank, t0 }
Promo.lastMsg = ""

local GOLD, WHITE, GRAY, GREEN, RED = "|cffffd100", "|cffffffff", "|cff999999", "|cff40ff40", "|cffff5555"

--------------------------------------------------------------------- ranks (read from the game)

-- index (0 = top) -> name; the game defines the order, the addon only reads it
function Promo.Ranks()
	local out, n = {}, 0
	local num = GuildControlGetNumRanks and GuildControlGetNumRanks() or 0
	if num and num > 0 then
		for i = 1, num do out[i - 1] = GuildControlGetRankName(i) end
		n = num
	end
	-- ranks of members as a fallback / addition (the guild control data may not be loaded yet)
	for _, info in pairs(BG.roster) do
		if info.rank and out[info.rankIndex] == nil then
			out[info.rankIndex] = info.rank
			if info.rankIndex + 1 > n then n = info.rankIndex + 1 end
		end
	end
	return out, n
end

function Promo.RankIndex(name)
	local ranks, n = Promo.Ranks()
	for i = 0, n - 1 do
		if ranks[i] == name then return i end
	end
	return nil
end

-- steps from start to target rank (nil when the settings do not make sense)
function Promo.Steps()
	local pr = BG.db.promo
	local a, b = Promo.RankIndex(pr.from), Promo.RankIndex(pr.to)
	if not a or not b or a <= b then return nil end
	return a - b, a, b
end

function Promo.Path()
	local steps, a, b = Promo.Steps()
	if not steps then return "" end
	local ranks = Promo.Ranks()
	local t = {}
	for i = a, b, -1 do table.insert(t, ranks[i] or "?") end
	return table.concat(t, " > ")
end

function Promo.CanPromote()
	return CanGuildPromote and CanGuildPromote() and true or false
end

--------------------------------------------------------------------- who is due

local function ParseDate(s)
	if not s or s == "" then return nil end
	local _, _, y, m, d = string.find(s, "^(%d%d%d%d)%-(%d%d?)%-(%d%d?)$")
	if not y then
		local _, _, d2, m2, y2 = string.find(s, "^(%d%d?)%.(%d%d?)%.(%d%d%d%d)$")
		if y2 then y, m, d = y2, m2, d2 end
	end
	if not y then return nil end
	local t = time({ year = tonumber(y), month = tonumber(m), day = tonumber(d), hour = 12 })
	if not t then return nil end
	return t, tonumber(d), tonumber(m)
end

-- members on the start rank for at least 'weeks' weeks. includeSnoozed = also those postponed for today
function Promo.Due(includeSnoozed)
	local pr = BG.db.promo
	local out = {}
	local today = BG.Today()
	local need = (tonumber(pr.weeks) or 4) * 7
	for name, info in pairs(BG.roster) do
		if info.rank == pr.from and name ~= BG.me and not Promo.busy[name] then
			local c = BG.db.chars[name]
			if not c then c = {} BG.db.chars[name] = c end
			-- no real join date known: the day the addon first saw the member counts
			if not c.joined or c.joined == "" then c.joined = today c.approx = true end
			local t, d, m = ParseDate(c.joined)
			if t then
				local days = math.floor((time() - t) / 86400)
				if days >= need and (includeSnoozed or pr.snooze[name] ~= today) then
					table.insert(out, { name = name, days = days, joined = string.format("%02d.%02d.", d, m), approx = c.approx })
				end
			end
		end
	end
	table.sort(out, function(a, b)
		if a.days ~= b.days then return a.days > b.days end
		return a.name < b.name
	end)
	return out
end

function Promo.Snooze(name)
	BG.db.promo.snooze[name] = BG.Today()
	Promo.Refresh()
end

--------------------------------------------------------------------- the promotion itself

function Promo.IsBusy(name) return Promo.busy[name] and true or false end

local function Note(msg)
	Promo.lastMsg = msg
	BG.Print(msg)
end

-- The promote / demote calls differ between clients: 1.12 FrameXML uses GuildPromoteByName / GuildDemoteByName,
-- some clients GuildPromote(name) / GuildDemote(name). Last resort: the slash command handlers of the chat frame.
local function FindFn(byName, plain, slash)
	if type(getglobal(byName)) == "function" then return getglobal(byName), byName end
	if type(getglobal(plain)) == "function" then return getglobal(plain), plain end
	if SlashCmdList and type(SlashCmdList[slash]) == "function" then return SlashCmdList[slash], "/g" .. string.lower(string.sub(slash, 7)) end
	return nil
end

function Promo.PromoteFn() return FindFn("GuildPromoteByName", "GuildPromote", "GUILD_PROMOTE") end
function Promo.DemoteFn() return FindFn("GuildDemoteByName", "GuildDemote", "GUILD_DEMOTE") end

function Promo.CanDemote()
	return CanGuildDemote and CanGuildDemote() and true or false
end

-- counts a batch of changes so that a summary can be shown at the end
local function BatchAdd()
	if not Promo.batch or (not Promo.cur and table.getn(Promo.queue) == 0) then Promo.batch = { ok = 0, fail = 0, total = 0 } end
	Promo.batch.total = Promo.batch.total + 1
end

-- queue entries: { name, to = target rank name, toIdx, dir = -1 promote (index gets smaller) / 1 demote,
--                  auto = true for the reminder promotion (start rank -> target rank) }
function Promo.Enqueue(names)
	local pr = BG.db.promo
	if not Promo.CanPromote() then BG.Print(BG.T("promo_no_right")) return 0 end
	if not Promo.PromoteFn() then BG.Print(BG.T("promo_noapi")) return 0 end
	local steps, a, b = Promo.Steps()
	if not steps then BG.Print(BG.T("promo_bad_ranks")) return 0 end
	local added = 0
	for i = 1, table.getn(names) do
		local name = names[i]
		local info = BG.roster[name]
		if info and info.rank == pr.from and not Promo.busy[name] then
			BatchAdd()
			Promo.busy[name] = true
			table.insert(Promo.queue, { name = name, to = pr.to, toIdx = b, dir = -1, auto = true })
			added = added + 1
		end
	end
	Promo.Refresh()
	return added
end

-- rank of the player himself (0 = guild leader); nil while the roster is not known
function Promo.MyIndex()
	local me = BG.roster[BG.me]
	return me and me.rankIndex or nil
end

-- what happens to a member when he is set to rank index 'toIdx': "up", "down", or nil + reason key
function Promo.Plan(name, toIdx)
	local info = BG.roster[name]
	local my = Promo.MyIndex()
	if not info or not my then return nil, "chg_skip_unknown" end
	if info.rankIndex <= my or toIdx <= my then return nil, "chg_skip_above" end
	if toIdx == info.rankIndex then return nil, "chg_skip_same" end
	if toIdx < info.rankIndex then return "up" end
	return "down"
end

-- set a member to any rank below the player's own rank, up or down (one rank per step)
function Promo.EnqueueTo(name, toName)
	local toIdx = Promo.RankIndex(toName)
	local info = BG.roster[name]
	if not toIdx or not info or Promo.busy[name] then return false end
	local plan, why = Promo.Plan(name, toIdx)
	if not plan then return false end
	if plan == "up" then
		if not Promo.CanPromote() then BG.Print(BG.T("promo_no_right")) return false end
		if not Promo.PromoteFn() then BG.Print(BG.T("promo_noapi")) return false end
	else
		if not Promo.CanDemote() then BG.Print(BG.T("demote_no_right")) return false end
		if not Promo.DemoteFn() then BG.Print(BG.T("demote_noapi")) return false end
	end
	BatchAdd()
	Promo.busy[name] = true
	table.insert(Promo.queue, { name = name, to = toName, toIdx = toIdx, dir = (plan == "up") and -1 or 1, auto = false })
	Promo.Refresh()
	return true
end

function Promo.Cancel()
	for i = 1, table.getn(Promo.queue) do Promo.busy[Promo.queue[i].name] = nil end
	Promo.queue = {}
	if Promo.cur then Promo.busy[Promo.cur.name] = nil Promo.cur = nil end
	Promo.batch = nil
	Promo.Refresh()
end

local function Done(cur, ok, rankNow)
	Promo.busy[cur.name] = nil
	Promo.cur = nil
	local up = cur.dir < 0
	if ok then
		BG.AddLog(up and "promote" or "demote", BG.me, cur.name, cur.to)
		BG.db.promo.snooze[cur.name] = nil
		Note(BG.T(up and "promo_done" or "promo_done_demote", cur.name, cur.to))
	else
		Note(BG.T(up and "promo_fail" or "promo_fail_demote", cur.name, rankNow or "?"))
	end
	local b = Promo.batch
	if b then
		if ok then b.ok = b.ok + 1 else b.fail = b.fail + 1 end
		if table.getn(Promo.queue) == 0 then
			if b.total > 1 then Note(BG.T("chg_batch_done", b.ok, b.fail)) end
			Promo.batch = nil
		end
	end
	Promo.Refresh()
end

-- one tick per second
local function Tick()
	if not Promo.cur then
		local q = table.remove(Promo.queue, 1)
		if not q then return end
		local info0 = BG.roster[q.name]
		Promo.cur = { name = q.name, to = q.to, toIdx = q.toIdx, dir = q.dir or -1, auto = q.auto, wait = false,
			startIdx = info0 and info0.rankIndex or 99 }
		Promo.Refresh()
	end
	local cur = Promo.cur
	local info = BG.roster[cur.name]
	local up = cur.dir < 0
	if not info or not (up and Promo.CanPromote() or (not up and Promo.CanDemote())) then
		Done(cur, false, info and info.rank)
		return
	end
	local idx = info.rankIndex
	if info.rank == cur.to or idx == cur.toIdx then Done(cur, true) return end
	-- somebody else already moved him past the target
	if (up and idx < cur.toIdx) or (not up and idx > cur.toIdx) then Done(cur, false, info.rank) return end
	if not cur.wait then
		-- moved the other way in the meantime: stop
		if (up and idx > cur.startIdx) or (not up and idx < cur.startIdx) then Done(cur, false, info.rank) return end
		local fn
		if up then fn = Promo.PromoteFn() else fn = Promo.DemoteFn() end
		if not fn then
			Note(BG.T(up and "promo_noapi" or "demote_noapi"))
			Done(cur, false, info.rank)
			return
		end
		cur.wait = true
		cur.lastIdx = idx
		cur.t0 = GetTime()
		cur.poll = GetTime()
		local ok, err = pcall(fn, cur.name)
		if not ok then
			BG.Fail(up and "promote" or "demote", err)
			Done(cur, false, info.rank)
			return
		end
		if GuildRoster then GuildRoster() end
	else
		if idx ~= cur.lastIdx then
			cur.wait = false -- the rank changed: next step (or done) on the next tick
			Promo.Refresh()
		elseif GetTime() - cur.t0 > 15 then
			Done(cur, false, info.rank)
		elseif GetTime() - cur.poll >= 2 then
			cur.poll = GetTime()
			if GuildRoster then GuildRoster() end
		end
	end
end

BG.OnLogin(function()
	BG.Ticker("promorun", 1, Tick)
	-- reminder: once per day, only for people who may promote
	BG.After(40, function() Promo.Remind() end)
	BG.Ticker("promoremind", 300, function() Promo.Remind() end)
end)

function Promo.Remind()
	local pr = BG.db.promo
	if not pr.enabled or not Promo.CanPromote() then return end
	if (BG.Roster and BG.Roster.scans or 0) == 0 then return end
	if pr.day == BG.Today() then return end
	if not Promo.Steps() then return end
	local due = Promo.Due(false)
	if table.getn(due) == 0 then return end
	pr.day = BG.Today()
	BG.Popup.Push({ type = "promo", defer = true, key = "promo", open = function() Promo.Open() end })
end

--------------------------------------------------------------------- window

local W, ROWS = 500, 6
local win
local counter = 0

local function Name(prefix)
	counter = counter + 1
	return "BananaGuildPromo" .. prefix .. counter
end

local function Build()
	win = CreateFrame("Frame", "BananaGuildPromoWin", UIParent)
	win:SetWidth(W)
	win:SetHeight(120 + ROWS * 38)
	win:SetPoint("CENTER", UIParent, "CENTER", 0, 80)
	win:SetFrameStrata("DIALOG")
	win:EnableMouse(true)
	win:SetMovable(true)
	win:RegisterForDrag("LeftButton")
	win:SetScript("OnDragStart", function() this:StartMoving() end)
	win:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
	BG.Backdrop(win, false, true)
	win:SetToplevel(true)
	win:Hide()
	local close = CreateFrame("Button", Name("Close"), win, "UIPanelCloseButton")
	close:SetPoint("TOPRIGHT", win, "TOPRIGHT", -2, -2)
	close:SetScript("OnClick", function() win:Hide() end)

	win.title = win:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	win.title:SetPoint("TOPLEFT", win, "TOPLEFT", 16, -14)
	win.body = win:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	win.body:SetPoint("TOPLEFT", win, "TOPLEFT", 16, -40)
	win.body:SetWidth(W - 32)
	win.body:SetJustifyH("LEFT")
	win.hint = win:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	win.hint:SetPoint("TOPLEFT", win, "TOPLEFT", 16, -58)
	win.hint:SetWidth(W - 32)
	win.hint:SetJustifyH("LEFT")

	win.rows = {}
	for i = 1, ROWS do
		local row = CreateFrame("Frame", Name("Row"), win)
		row:SetWidth(W - 32)
		row:SetHeight(34)
		row:SetPoint("TOPLEFT", win, "TOPLEFT", 16, -78 - (i - 1) * 38)
		BG.Backdrop(row, false)
		row.name = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		row.name:SetPoint("TOPLEFT", row, "TOPLEFT", 10, -5)
		row.info = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
		row.info:SetPoint("TOPLEFT", row, "TOPLEFT", 10, -19)
		row.info:SetWidth(250)
		row.info:SetJustifyH("LEFT")
		row.later = BG.MakeButton(row, Name("Btn"), 70, 22, "")
		row.later:SetPoint("RIGHT", row, "RIGHT", -6, 0)
		row.later:SetScript("OnClick", function()
			local item = this:GetParent().item
			if item then Promo.Snooze(item.name) end
		end)
		row.go = BG.MakeButton(row, Name("Btn"), 110, 22, "")
		row.go:SetPoint("RIGHT", row.later, "LEFT", -4, 0)
		row.go:SetScript("OnClick", function()
			local item = this:GetParent().item
			if item then Promo.Enqueue({ item.name }) end
		end)
		row:Hide()
		win.rows[i] = row
	end

	win.more = win:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	win.more:SetPoint("BOTTOMLEFT", win, "BOTTOMLEFT", 18, 44)
	win.more:SetWidth(W - 36)
	win.more:SetJustifyH("LEFT")
	win.status = win:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	win.status:SetPoint("BOTTOMLEFT", win, "BOTTOMLEFT", 18, 20)
	win.status:SetWidth(W - 280)
	win.status:SetJustifyH("LEFT")
	win.all = BG.MakeButton(win, Name("Btn"), 130, 24, "")
	win.all:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", -112, 14)
	win.all:SetScript("OnClick", function()
		local names = {}
		for i = 1, table.getn(win.shown or {}) do table.insert(names, win.shown[i].name) end
		Promo.Enqueue(names)
	end)
	win.closeBtn = BG.MakeButton(win, Name("Btn"), 90, 24, "")
	win.closeBtn:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", -16, 14)
	win.closeBtn:SetScript("OnClick", function() win:Hide() end)

	win.elapsed = 0
	win:SetScript("OnUpdate", function()
		this.elapsed = this.elapsed + arg1
		if this.elapsed < 1 then return end
		this.elapsed = 0
		Promo.Refresh()
	end)
end

function Promo.Refresh()
	if BG.UI and BG.UI.UpdatePromoButton then BG.UI.UpdatePromoButton() end
	if not win or not win:IsShown() then return end
	local pr = BG.db.promo
	local steps = Promo.Steps()
	win.title:SetText(GOLD .. BG.T("promo_title") .. "|r")
	win.body:SetText(BG.T("promo_body", pr.weeks, pr.from))
	win.hint:SetText(steps and BG.T("promo_steps_hint", steps, Promo.Path()) or (RED .. BG.T("promo_bad_ranks") .. "|r"))
	local list = Promo.Due(false)
	-- members that are being promoted stay visible until they are done
	local shown = {}
	for i = 1, table.getn(list) do shown[i] = list[i] end
	win.shown = shown
	for i = 1, ROWS do
		local row = win.rows[i]
		local item = shown[i]
		row.item = item
		if item then
			row.name:SetText(item.name)
			local key = item.approx and "promo_row_approx" or "promo_row"
			row.info:SetText(BG.T(key, pr.from, item.joined, item.days))
			row.go:SetText(BG.T("btn_promote_to", pr.to))
			row.later:SetText(BG.T("btn_later"))
			if steps and Promo.CanPromote() then row.go:Enable() else row.go:Disable() end
			row:Show()
		else
			row:Hide()
		end
	end
	local extra = table.getn(shown) - ROWS
	win.more:SetText(extra > 0 and (GRAY .. "+ " .. extra .. "|r") or (table.getn(shown) == 0 and (GRAY .. BG.T("promo_none") .. "|r") or ""))
	local cur = Promo.cur
	if cur then
		local info = BG.roster[cur.name]
		local done = info and (cur.startIdx - info.rankIndex) or 0
		win.status:SetText(GREEN .. BG.T("promo_status", cur.name, math.abs(done), math.abs(cur.startIdx - cur.toIdx)) .. "|r")
	elseif table.getn(Promo.queue) > 0 then
		win.status:SetText(GREEN .. BG.T("promo_running") .. "|r")
	else
		win.status:SetText(Promo.lastMsg ~= "" and (GRAY .. Promo.lastMsg .. "|r") or "")
	end
	win.all:SetText(BG.T("btn_promote_all"))
	win.closeBtn:SetText(BG.T("btn_close"))
	if table.getn(shown) > 0 and steps and Promo.CanPromote() then win.all:Enable() else win.all:Disable() end
end

function Promo.Open()
	if not win then Build() end
	win:Show()
	win:Raise()
	Promo.Refresh()
end

--------------------------------------------------------------------- dropdown (opens a list of choices)

local dropCounter = 0

-- b.SetItems({ { label, value }, ... }); b.SetValue(value) (no callback); onPick(value) when the user picks one
function BG.Dropdown(parent, x, y, w, onPick)
	dropCounter = dropCounter + 1
	local b = BG.MakeButton(parent, "BananaGuildDrop" .. dropCounter, w, 22, "")
	b:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
	local lf = CreateFrame("Frame", "BananaGuildDropList" .. dropCounter, parent)
	lf:SetFrameStrata("FULLSCREEN_DIALOG")
	lf:SetWidth(w + 8)
	BG.Backdrop(lf, false, true)
	lf:SetPoint("TOPLEFT", b, "BOTTOMLEFT", -4, 2)
	lf:Hide()
	b.list = lf
	b.items = {}
	lf.rows = {}

	function b.SetItems(items)
		b.items = items or {}
		for i = 1, table.getn(b.items) do
			local r = lf.rows[i]
			if not r then
				r = CreateFrame("Button", "BananaGuildDropRow" .. dropCounter .. "_" .. i, lf)
				r:SetWidth(w)
				r:SetHeight(20)
				r.bg = r:CreateTexture(nil, "BACKGROUND")
				r.bg:SetAllPoints(r)
				r.bg:SetTexture(1, 1, 1, 0)
				r.fs = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
				r.fs:SetPoint("LEFT", r, "LEFT", 8, 0)
				r:SetScript("OnEnter", function() this.bg:SetTexture(1, 1, 1, 0.18) end)
				r:SetScript("OnLeave", function() this.bg:SetTexture(1, 1, 1, 0) end)
				r:SetScript("OnClick", function()
					local it = this.item
					lf:Hide()
					if it then
						b.value = it.value
						b:SetText(it.label)
						if onPick then onPick(it.value) end
					end
				end)
				lf.rows[i] = r
			end
			r.item = b.items[i]
			r.fs:SetText(b.items[i].label)
			r:ClearAllPoints()
			r:SetPoint("TOPLEFT", lf, "TOPLEFT", 4, -4 - (i - 1) * 20)
			r:Show()
		end
		for i = table.getn(b.items) + 1, table.getn(lf.rows) do lf.rows[i]:Hide() end
		lf:SetHeight(8 + table.getn(b.items) * 20)
	end

	function b.SetValue(v)
		b.value = v
		b:SetText("-")
		for i = 1, table.getn(b.items) do
			if b.items[i].value == v then b:SetText(b.items[i].label) end
		end
	end

	b:SetScript("OnClick", function()
		if lf:IsShown() then lf:Hide() elseif table.getn(b.items) > 0 then lf:Show() lf:Raise() end
	end)
	return b
end

--------------------------------------------------------------------- change rank window (one or many members, up or down)

local cw
local CROWS, CW = 8, 540

local function Ranks2()
	local ranks, n = Promo.Ranks()
	return ranks, n
end

local function BuildChange()
	cw = CreateFrame("Frame", "BananaGuildChangeWin", UIParent)
	cw:SetWidth(CW)
	cw:SetHeight(386)
	cw:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
	cw:SetFrameStrata("DIALOG")
	cw:EnableMouse(true)
	cw:SetMovable(true)
	cw:RegisterForDrag("LeftButton")
	cw:SetScript("OnDragStart", function() this:StartMoving() end)
	cw:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
	BG.Backdrop(cw, false, true)
	cw:SetToplevel(true)
	cw:Hide()
	local close = CreateFrame("Button", Name("CClose"), cw, "UIPanelCloseButton")
	close:SetPoint("TOPRIGHT", cw, "TOPRIGHT", -2, -2)
	close:SetScript("OnClick", function() cw:Hide() end)
	cw.title = cw:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	cw.title:SetPoint("TOPLEFT", cw, "TOPLEFT", 16, -14)
	cw.lbl = cw:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	cw.lbl:SetPoint("TOPLEFT", cw, "TOPLEFT", 16, -52)
	cw.drop = BG.Dropdown(cw, 90, -47, 250, function(v)
		cw.target = v
		Promo.RefreshChange()
	end)
	cw.hint = cw:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	cw.hint:SetPoint("TOPLEFT", cw, "TOPLEFT", 350, -44)
	cw.hint:SetWidth(CW - 366)
	cw.hint:SetHeight(28)
	cw.hint:SetJustifyH("LEFT")
	cw.hint:SetJustifyV("TOP")

	cw.rows = {}
	for i = 1, CROWS do
		local row = CreateFrame("Frame", Name("CRow"), cw)
		row:SetWidth(CW - 32)
		row:SetHeight(24)
		row:SetPoint("TOPLEFT", cw, "TOPLEFT", 16, -84 - (i - 1) * 24)
		row.chk = CreateFrame("CheckButton", Name("CChk"), row, "UICheckButtonTemplate")
		row.chk:SetWidth(22)
		row.chk:SetHeight(22)
		row.chk:SetPoint("LEFT", row, "LEFT", 0, 0)
		row.chk:SetScript("OnClick", function()
			local r = this:GetParent()
			if r.member then
				cw.checked[r.member] = this:GetChecked() and true or false
				Promo.RefreshChange()
			end
		end)
		row.fs = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		row.fs:SetPoint("LEFT", row, "LEFT", 28, 0)
		row.fs:SetWidth(CW - 70)
		row.fs:SetJustifyH("LEFT")
		row:Hide()
		cw.rows[i] = row
	end

	cw.prev = BG.MakeButton(cw, Name("CBtn"), 28, 20, "<")
	cw.prev:SetPoint("TOPLEFT", cw, "TOPLEFT", 16, -282)
	cw.prev:SetScript("OnClick", function() cw.page = (cw.page or 1) - 1 Promo.RefreshChange() end)
	cw.next = BG.MakeButton(cw, Name("CBtn"), 28, 20, ">")
	cw.next:SetPoint("LEFT", cw.prev, "RIGHT", 4, 0)
	cw.next:SetScript("OnClick", function() cw.page = (cw.page or 1) + 1 Promo.RefreshChange() end)
	cw.pageFs = cw:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	cw.pageFs:SetPoint("LEFT", cw.next, "RIGHT", 8, 0)

	cw.confirm = CreateFrame("CheckButton", Name("CConfirm"), cw, "UICheckButtonTemplate")
	cw.confirm:SetWidth(24)
	cw.confirm:SetHeight(24)
	cw.confirm:SetPoint("TOPLEFT", cw, "TOPLEFT", 12, -312)
	cw.confirm:SetScript("OnClick", function() Promo.RefreshChange() end)
	cw.confirmText = getglobal(cw.confirm:GetName() .. "Text")
	cw.confirmText:SetJustifyH("LEFT")
	cw.confirmText:SetWidth(CW - 60)

	cw.go = BG.MakeButton(cw, Name("CBtn"), 190, 24, "")
	cw.go:SetPoint("BOTTOMLEFT", cw, "BOTTOMLEFT", 16, 14)
	cw.go:SetScript("OnClick", function() Promo.ApplyChange() end)
	cw.cancel = BG.MakeButton(cw, Name("CBtn"), 110, 24, "")
	cw.cancel:SetPoint("BOTTOMRIGHT", cw, "BOTTOMRIGHT", -16, 14)
	cw.cancel:SetScript("OnClick", function() cw:Hide() end)
end

-- plan of every marked member for the chosen target rank
local function Plans()
	local out = {}
	local ranks = Ranks2()
	for i = 1, table.getn(cw.names) do
		local name = cw.names[i]
		local info = BG.roster[name]
		local plan, why = nil, "chg_skip_unknown"
		if cw.target then plan, why = Promo.Plan(name, cw.target) end
		table.insert(out, { name = name, info = info, plan = plan, why = why,
			steps = (info and cw.target) and math.abs(info.rankIndex - cw.target) or 0 })
	end
	return out, ranks
end

function Promo.RefreshChange()
	if not cw or not cw:IsShown() then return end
	local plans, ranks = Plans()
	local toName = cw.target and ranks[cw.target] or "?"
	if table.getn(cw.names) == 1 then
		cw.title:SetText(GOLD .. BG.T("chg_title_one", cw.names[1]) .. "|r")
	else
		cw.title:SetText(GOLD .. BG.T("chg_title_n", table.getn(cw.names)) .. "|r")
	end
	cw.lbl:SetText(BG.T("chg_target"))
	cw.drop.SetValue(cw.target)
	local pages = math.max(1, math.ceil(table.getn(plans) / CROWS))
	if cw.page > pages then cw.page = pages end
	if cw.page < 1 then cw.page = 1 end
	local nChecked, nDown = 0, 0
	for i = 1, table.getn(plans) do
		local pl = plans[i]
		if pl.plan and cw.checked[pl.name] then
			nChecked = nChecked + 1
			if pl.plan == "down" then nDown = nDown + 1 end
		end
	end
	for i = 1, CROWS do
		local row = cw.rows[i]
		local pl = plans[(cw.page - 1) * CROWS + i]
		if pl then
			row.member = pl.name
			if pl.plan then
				local up = pl.plan == "up"
				local col = up and "|cff40ff40" or "|cffff9a40"
				row.fs:SetText(col .. BG.T(up and "chg_row_up" or "chg_row_down", pl.name, pl.info.rank, toName, pl.steps) .. "|r")
				row.chk:Enable()
				row.chk:SetChecked(cw.checked[pl.name] and 1 or nil)
			else
				row.fs:SetText(GRAY .. BG.T(pl.why, pl.name, pl.info and pl.info.rank or "?") .. "|r")
				row.chk:SetChecked(nil)
				row.chk:Disable()
			end
			row:Show()
		else
			row.member = nil
			row:Hide()
		end
	end
	if pages > 1 then
		cw.pageFs:SetText(BG.T("chg_page", cw.page, pages))
		cw.prev:Show() cw.next:Show()
	else
		cw.pageFs:SetText("")
		cw.prev:Hide() cw.next:Hide()
	end
	if nDown > 0 then
		cw.confirm:Show()
		cw.confirmText:SetText(RED .. BG.T("chg_confirm_demote", nDown) .. "|r")
		cw.hint:SetText(RED .. BG.T("chg_hint_demote") .. "|r")
	else
		cw.confirm:Hide()
		cw.confirm:SetChecked(nil)
		cw.hint:SetText("")
	end
	cw.go:SetText(BG.T("chg_apply", nChecked))
	cw.cancel:SetText(BG.T("btn_close"))
	if nChecked > 0 and (nDown == 0 or cw.confirm:GetChecked()) then cw.go:Enable() else cw.go:Disable() end
end

function Promo.ApplyChange()
	if not cw or not cw.target then return end
	local plans, ranks = Plans()
	local toName = ranks[cw.target]
	local list = {}
	local down = 0
	for i = 1, table.getn(plans) do
		local pl = plans[i]
		if pl.plan and cw.checked[pl.name] then
			table.insert(list, pl.name)
			if pl.plan == "down" then down = down + 1 end
		end
	end
	if table.getn(list) == 0 then return end
	if down > 0 and not cw.confirm:GetChecked() then return end
	if table.getn(list) > 1 then BG.Print(BG.T("chg_start", table.getn(list), toName)) end
	for i = 1, table.getn(list) do Promo.EnqueueTo(list[i], toName) end
	cw:Hide()
end

-- names: members of the roster to set to another rank
function Promo.OpenChange(names)
	local list = {}
	for i = 1, table.getn(names) do
		if BG.roster[names[i]] then table.insert(list, names[i]) end
	end
	if table.getn(list) == 0 then BG.Print(BG.T("chg_none")) return end
	local my = Promo.MyIndex()
	if not my then BG.Print(BG.T("promo_bad_ranks")) return end
	if not cw then BuildChange() end
	cw.names = list
	cw.checked = {}
	for i = 1, table.getn(list) do cw.checked[list[i]] = true end
	cw.page = 1
	cw.confirm:SetChecked(nil)
	-- the choices: every rank below my own
	local ranks, n = Ranks2()
	local items = {}
	for i = my + 1, n - 1 do
		if ranks[i] then
			local label = ranks[i]
			if table.getn(list) == 1 and BG.roster[list[1]].rankIndex == i then label = label .. " " .. BG.T("chg_current") end
			table.insert(items, { label = label, value = i })
		end
	end
	cw.drop.SetItems(items)
	-- default target: the automatic target rank, for one member never his own rank
	local want = Promo.RankIndex(BG.db.promo.to)
	if table.getn(list) == 1 then
		local cur = BG.roster[list[1]].rankIndex
		if not want or want == cur or want <= my then want = cur - 1 end
	end
	if not want or want <= my then want = (items[1] and items[1].value) or nil end
	cw.target = want
	cw:Show()
	cw:Raise()
	Promo.RefreshChange()
end

function Promo.OpenManual(name) Promo.OpenChange({ name }) end

BananaGuild.files = BananaGuild.files or {}
BananaGuild.files.Promote = true
