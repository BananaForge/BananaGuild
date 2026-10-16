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

-- The promote call differs between clients: 1.12 FrameXML uses GuildPromoteByName, some use GuildPromote(name).
-- Last resort: the slash command handler of the chat frame (/gpromote).
function Promo.PromoteFn()
	if type(GuildPromoteByName) == "function" then return GuildPromoteByName, "GuildPromoteByName" end
	if type(GuildPromote) == "function" then return GuildPromote, "GuildPromote" end
	if SlashCmdList and type(SlashCmdList["GUILD_PROMOTE"]) == "function" then return SlashCmdList["GUILD_PROMOTE"], "/gpromote" end
	return nil
end

-- queue entries: { name, to = target rank name, toIdx, auto = true for the reminder promotion (start rank -> target rank) }
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
			Promo.busy[name] = true
			table.insert(Promo.queue, { name = name, to = pr.to, toIdx = b, auto = true })
			added = added + 1
		end
	end
	Promo.Refresh()
	return added
end

-- manual promotion of any member to any rank that is higher than his rank and below mine
function Promo.ManualTargets(name)
	local out = {}
	local info = BG.roster[name]
	local me = BG.roster[BG.me]
	if not info or not me then return out end
	local ranks = Promo.Ranks()
	for i = info.rankIndex - 1, me.rankIndex + 1, -1 do
		if ranks[i] then table.insert(out, { idx = i, name = ranks[i] }) end
	end
	return out
end

function Promo.EnqueueManual(name, toName)
	if not Promo.CanPromote() then BG.Print(BG.T("promo_no_right")) return false end
	if not Promo.PromoteFn() then BG.Print(BG.T("promo_noapi")) return false end
	local info = BG.roster[name]
	local me = BG.roster[BG.me]
	local toIdx = Promo.RankIndex(toName)
	if not info or not me or not toIdx or Promo.busy[name] then return false end
	if info.rankIndex <= me.rankIndex or toIdx >= info.rankIndex or toIdx <= me.rankIndex then
		BG.Print(BG.T("pman_none"))
		return false
	end
	Promo.busy[name] = true
	table.insert(Promo.queue, { name = name, to = toName, toIdx = toIdx, auto = false })
	Promo.Refresh()
	return true
end

function Promo.Cancel()
	for i = 1, table.getn(Promo.queue) do Promo.busy[Promo.queue[i].name] = nil end
	Promo.queue = {}
	if Promo.cur then Promo.busy[Promo.cur.name] = nil Promo.cur = nil end
	Promo.Refresh()
end

local function Done(cur, ok, rankNow)
	Promo.busy[cur.name] = nil
	Promo.cur = nil
	if ok then
		BG.AddLog("promote", BG.me, cur.name, cur.to)
		BG.db.promo.snooze[cur.name] = nil
		Note(BG.T("promo_done", cur.name, cur.to))
	else
		Note(BG.T("promo_fail", cur.name, rankNow or "?"))
	end
	Promo.Refresh()
end

-- one tick per second
local function Tick()
	if not Promo.cur then
		local q = table.remove(Promo.queue, 1)
		if not q then return end
		local info0 = BG.roster[q.name]
		Promo.cur = { name = q.name, to = q.to, toIdx = q.toIdx, auto = q.auto, wait = false,
			startIdx = info0 and info0.rankIndex or 99 }
		Promo.Refresh()
	end
	local cur = Promo.cur
	local info = BG.roster[cur.name]
	if not info or not Promo.CanPromote() then
		Done(cur, false, info and info.rank)
		return
	end
	local idx = info.rankIndex
	if info.rank == cur.to or idx == cur.toIdx then Done(cur, true) return end
	if idx < cur.toIdx then Done(cur, false, info.rank) return end -- somebody else already promoted further
	if not cur.wait then
		if idx > cur.startIdx then Done(cur, false, info.rank) return end -- demoted in the meantime: stop
		cur.wait = true
		cur.lastIdx = idx
		cur.t0 = GetTime()
		cur.poll = GetTime()
		local fn = Promo.PromoteFn()
		if not fn then
			Note(BG.T("promo_noapi"))
			Done(cur, false, info.rank)
			return
		end
		local ok, err = pcall(fn, cur.name)
		if not ok then
			BG.Fail("promote", err)
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
		win.status:SetText(GREEN .. BG.T("promo_status", cur.name, done, cur.startIdx - cur.toIdx) .. "|r")
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

--------------------------------------------------------------------- manual promotion window

local mw

local function BuildManual()
	mw = CreateFrame("Frame", "BananaGuildPromoManual", UIParent)
	mw:SetWidth(380)
	mw:SetHeight(176)
	mw:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
	mw:SetFrameStrata("DIALOG")
	mw:EnableMouse(true)
	mw:SetMovable(true)
	mw:RegisterForDrag("LeftButton")
	mw:SetScript("OnDragStart", function() this:StartMoving() end)
	mw:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
	BG.Backdrop(mw, false, true)
	mw:SetToplevel(true)
	mw:Hide()
	local close = CreateFrame("Button", Name("MClose"), mw, "UIPanelCloseButton")
	close:SetPoint("TOPRIGHT", mw, "TOPRIGHT", -2, -2)
	close:SetScript("OnClick", function() mw:Hide() end)
	mw.title = mw:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	mw.title:SetPoint("TOPLEFT", mw, "TOPLEFT", 16, -14)
	mw.cur = mw:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	mw.cur:SetPoint("TOPLEFT", mw, "TOPLEFT", 16, -42)
	mw.cur:SetWidth(348)
	mw.cur:SetJustifyH("LEFT")
	mw.lbl = mw:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	mw.lbl:SetPoint("TOPLEFT", mw, "TOPLEFT", 16, -70)
	mw.target = BG.MakeButton(mw, Name("MBtn"), 200, 22, "")
	mw.target:SetPoint("TOPLEFT", mw, "TOPLEFT", 90, -66)
	mw.target:SetScript("OnClick", function()
		local list = mw.targets or {}
		if table.getn(list) == 0 then return end
		mw.sel = (mw.sel or 1) + 1
		if mw.sel > table.getn(list) then mw.sel = 1 end
		Promo.RefreshManual()
	end)
	mw.info = mw:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	mw.info:SetPoint("TOPLEFT", mw, "TOPLEFT", 16, -98)
	mw.info:SetWidth(348)
	mw.info:SetHeight(28)
	mw.info:SetJustifyH("LEFT")
	mw.info:SetJustifyV("TOP")
	mw.go = BG.MakeButton(mw, Name("MBtn"), 150, 24, "")
	mw.go:SetPoint("BOTTOMLEFT", mw, "BOTTOMLEFT", 16, 14)
	mw.go:SetScript("OnClick", function()
		local t = mw.targets and mw.targets[mw.sel or 1]
		if t and Promo.EnqueueManual(mw.name, t.name) then mw:Hide() end
	end)
	mw.cancel = BG.MakeButton(mw, Name("MBtn"), 110, 24, "")
	mw.cancel:SetPoint("BOTTOMRIGHT", mw, "BOTTOMRIGHT", -16, 14)
	mw.cancel:SetScript("OnClick", function() mw:Hide() end)
end

function Promo.RefreshManual()
	if not mw or not mw:IsShown() then return end
	local info = BG.roster[mw.name]
	mw.title:SetText(GOLD .. BG.T("pman_title", mw.name) .. "|r")
	mw.lbl:SetText(BG.T("promo_to"))
	mw.cancel:SetText(BG.T("btn_close"))
	mw.go:SetText(BG.T("pman_go"))
	if not info then mw.cur:SetText("") mw.go:Disable() return end
	mw.cur:SetText(BG.T("pman_cur", info.rank or "?"))
	local list = mw.targets
	local t = list and list[mw.sel or 1]
	if not t or not Promo.CanPromote() then
		mw.target:SetText("-")
		mw.info:SetText(RED .. BG.T(Promo.CanPromote() and "pman_none" or "promo_no_right") .. "|r")
		mw.go:Disable()
		return
	end
	mw.target:SetText(t.name)
	local steps = info.rankIndex - t.idx
	local ranks = Promo.Ranks()
	local path = {}
	for i = info.rankIndex, t.idx, -1 do table.insert(path, ranks[i] or "?") end
	mw.info:SetText(BG.T("promo_steps_hint", steps, table.concat(path, " > ")))
	mw.go:Enable()
end

function Promo.OpenManual(name)
	if not name or not BG.roster[name] then return end
	if not mw then BuildManual() end
	mw.name = name
	mw.targets = Promo.ManualTargets(name)
	-- default: the automatic target rank when it fits, otherwise one rank up
	mw.sel = table.getn(mw.targets) > 0 and 1 or nil
	for i = 1, table.getn(mw.targets) do
		if mw.targets[i].name == BG.db.promo.to then mw.sel = i end
	end
	mw:Show()
	mw:Raise()
	Promo.RefreshManual()
end

BananaGuild.files = BananaGuild.files or {}
BananaGuild.files.Promote = true
