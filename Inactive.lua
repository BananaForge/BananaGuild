--[[
  BananaGuild - Inactive
  Who has not been online for a long time?
    * helpers to show the offline time of a member (from the guild list, or observed by the addon)
    * a window that lists the members offline for at least N days and can
        - set them to the "inactive" rank (step by step, uses Promote.lua), or
        - remove them from the guild (one by one, with a clear confirmation)
  Only members below the player's own rank are ever offered.
]]

local BG = BananaGuild
local Inactive = {}
BG.Inactive = Inactive

Inactive.queue = {}
Inactive.busy = {}
Inactive.cur = nil

local GOLD, WHITE, GRAY, GREEN, RED, ORANGE = "|cffffd100", "|cffffffff", "|cff999999", "|cff40ff40", "|cffff5555", "|cffff9a40"

---------------------------------------------------------------- offline time

-- short form for the list: "<1 T", "12 T", "5 Mon", "2 J"
function Inactive.Short(days)
	if not days then return "?" end
	if days < 1 then return "<1 " .. BG.T("unit_d") end
	if days < 60 then return math.floor(days) .. " " .. BG.T("unit_d") end
	if days < 730 then return math.floor(days / 30) .. " " .. BG.T("unit_mo") end
	return math.floor(days / 365) .. " " .. BG.T("unit_y")
end

-- long form for the detail view: "vor 12 Tagen"
function Inactive.Ago(days)
	if not days then return BG.T("detail_lastseen_unknown") end
	if days < 1 then return BG.T("ago_less") end
	if days < 2 then return BG.T("ago_day1") end
	if days < 60 then return BG.T("ago_days", math.floor(days)) end
	if days < 730 then return BG.T("ago_months", math.floor(days / 30)) end
	return BG.T("ago_years", math.floor(days / 365))
end

-- colour of the offline time in the list: grey, orange from half of the limit, red from the limit
function Inactive.Color(days)
	if not days then return GRAY end
	local lim = tonumber(BG.db.inactive.days) or 30
	if days >= lim then return RED end
	if days >= lim / 2 then return ORANGE end
	return WHITE
end

-- where the numbers come from
function Inactive.SourceNote()
	if GetGuildRosterLastOnline then return BG.T("ina_src_api") end
	return BG.T("ina_src_seen")
end

local function JoinedShort(name)
	local c = BG.db.chars[name]
	local _, _, y, m, d = string.find((c and c.joined) or "", "^(%d%d%d%d)%-(%d%d?)%-(%d%d?)$")
	if not y then return "?" end
	return string.format("%02d.%02d.%s", tonumber(d), tonumber(m), string.sub(y, 3))
end
Inactive.JoinedShort = JoinedShort

---------------------------------------------------------------- candidates

-- mode "rank": members above the inactive rank; mode "kick": everybody below me. Sorted by offline time, longest first.
function Inactive.Candidates(mode, days)
	local out = {}
	local my = BG.Promo.MyIndex()
	if not my then return out end
	local inactiveIdx = BG.Promo.RankIndex(BG.db.inactive.rank)
	for name, info in pairs(BG.roster) do
		local off = info.offlineDays
		if name ~= BG.me and off and off >= days and info.rankIndex > my
			and not BG.Promo.busy[name] and not Inactive.busy[name] then
			local ok = true
			if mode == "rank" then ok = inactiveIdx and inactiveIdx > my and info.rankIndex < inactiveIdx end
			if ok then table.insert(out, { name = name, info = info, off = off }) end
		end
	end
	table.sort(out, function(a, b)
		if a.off ~= b.off then return a.off > b.off end
		return a.name < b.name
	end)
	return out
end

---------------------------------------------------------------- removing members (one at a time)

function Inactive.CanKick()
	return CanGuildRemove and CanGuildRemove() and true or false
end

function Inactive.KickFn()
	if type(GuildUninviteByName) == "function" then return GuildUninviteByName, "GuildUninviteByName" end
	if type(GuildUninvite) == "function" then return GuildUninvite, "GuildUninvite" end
	if SlashCmdList and type(SlashCmdList["GUILD_UNINVITE"]) == "function" then return SlashCmdList["GUILD_UNINVITE"], "/gremove" end
	return nil
end

local function Note(msg) BG.Print(msg) end

function Inactive.EnqueueKick(names, minDays)
	if not Inactive.CanKick() then Note(BG.T("kick_no_right")) return 0 end
	if not Inactive.KickFn() then Note(BG.T("kick_noapi")) return 0 end
	if not Inactive.batch or (not Inactive.cur and table.getn(Inactive.queue) == 0) then Inactive.batch = { ok = 0, fail = 0, total = 0 } end
	local n = 0
	for i = 1, table.getn(names) do
		local name = names[i]
		if not Inactive.busy[name] and BG.roster[name] then
			Inactive.busy[name] = true
			table.insert(Inactive.queue, { name = name, minDays = minDays })
			Inactive.batch.total = Inactive.batch.total + 1
			n = n + 1
		end
	end
	return n
end

function Inactive.Cancel()
	for i = 1, table.getn(Inactive.queue) do Inactive.busy[Inactive.queue[i].name] = nil end
	Inactive.queue = {}
	if Inactive.cur then Inactive.busy[Inactive.cur.name] = nil Inactive.cur = nil end
	Inactive.batch = nil
end

local function Finish(cur, ok, why)
	Inactive.busy[cur.name] = nil
	Inactive.cur = nil
	local b = Inactive.batch
	if b then if ok then b.ok = b.ok + 1 else b.fail = b.fail + 1 end end
	if ok then Note(BG.T("kick_done", cur.name, cur.off))
	elseif why == "skip" then Note(BG.T("kick_skip", cur.name))
	else Note(BG.T("kick_fail", cur.name)) end
	if b and table.getn(Inactive.queue) == 0 then
		if b.total > 1 then Note(BG.T("ina_batch_done", b.ok, b.fail)) end
		Inactive.batch = nil
	end
	if Inactive.Refresh then Inactive.Refresh() end
end

local function Tick()
	if not Inactive.cur then
		local q = table.remove(Inactive.queue, 1)
		if not q then return end
		local info = BG.roster[q.name]
		local my = BG.Promo and BG.Promo.MyIndex()
		local cur = { name = q.name, minDays = q.minDays, off = info and Inactive.Short(info.offlineDays) or "?" }
		Inactive.cur = cur
		-- check again right before: still in the guild, still offline long enough, still below me
		if not info or not my or info.rankIndex <= my or not info.offlineDays or info.offlineDays < q.minDays then
			Finish(cur, false, "skip")
			return
		end
		local fn = Inactive.KickFn()
		if not fn or not Inactive.CanKick() then Finish(cur, false) return end
		local ok, err = pcall(fn, q.name)
		if not ok then BG.Fail("kick", err) Finish(cur, false) return end
		cur.t0 = GetTime()
		cur.poll = GetTime()
		if GuildRoster then GuildRoster() end
		return
	end
	local cur = Inactive.cur
	if not BG.roster[cur.name] then Finish(cur, true) return end
	if GetTime() - cur.t0 > 12 then Finish(cur, false) return end
	if GetTime() - cur.poll >= 2 then
		cur.poll = GetTime()
		if GuildRoster then GuildRoster() end
	end
end

BG.OnLogin(function()
	BG.Ticker("inactivekick", 1.5, Tick)
end)

---------------------------------------------------------------- window

local W, H, ROWS = 660, 472, 9
local win
local counter = 0

local function Name(prefix)
	counter = counter + 1
	return "BananaGuildIna" .. prefix .. counter
end

local function Mark(b, on)
	b:Enable()
	local fs = b.GetFontString and b:GetFontString()
	if on then
		if b.LockHighlight then b:LockHighlight() end
		if fs then fs:SetTextColor(1, 0.82, 0) end
	else
		if b.UnlockHighlight then b:UnlockHighlight() end
		if fs then fs:SetTextColor(1, 1, 1) end
	end
end

local function Days()
	local d = BG.db.inactive
	if win.mode == "kick" then return tonumber(d.kickDays) or 90 end
	return tonumber(d.days) or 30
end

local function Build()
	win = CreateFrame("Frame", "BananaGuildInactiveWin", UIParent)
	win:SetWidth(W)
	win:SetHeight(H)
	win:SetPoint("CENTER", UIParent, "CENTER", 0, 20)
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

	win.btnRank = BG.MakeButton(win, Name("Btn"), 190, 24, "")
	win.btnRank:SetPoint("TOPLEFT", win, "TOPLEFT", 16, -44)
	win.btnRank:SetScript("OnClick", function() win.mode = "rank" win.checked = nil Inactive.Refresh() end)
	win.btnKick = BG.MakeButton(win, Name("Btn"), 210, 24, "")
	win.btnKick:SetPoint("LEFT", win.btnRank, "RIGHT", 6, 0)
	win.btnKick:SetScript("OnClick", function() win.mode = "kick" win.checked = nil Inactive.Refresh() end)

	win.lblDays = win:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	win.lblDays:SetPoint("TOPLEFT", win, "TOPLEFT", 16, -84)
	win.days = CreateFrame("EditBox", Name("Edit"), win, "InputBoxTemplate")
	win.days:SetWidth(44)
	win.days:SetHeight(20)
	win.days:SetPoint("TOPLEFT", win, "TOPLEFT", 196, -80)
	win.days:SetAutoFocus(false)
	win.days:SetMaxLetters(4)
	win.days:SetScript("OnTextChanged", function()
		if this.loading then return end
		local n = tonumber(this:GetText())
		if n and n >= 1 then
			if win.mode == "kick" then BG.db.inactive.kickDays = n else BG.db.inactive.days = n end
			win.checked = nil
			win.page = 1
			Inactive.Refresh(true)
		end
	end)
	win.days:SetScript("OnEscapePressed", function() this:ClearFocus() end)
	win.days:SetScript("OnEnterPressed", function() this:ClearFocus() end)
	win.lblUnit = win:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	win.lblUnit:SetPoint("LEFT", win.days, "RIGHT", 8, 0)

	win.lblTarget = win:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	win.lblTarget:SetPoint("TOPLEFT", win, "TOPLEFT", 330, -84)
	win.target = BG.Dropdown(win, 420, -80, 150, function(v)
		BG.db.inactive.rank = v
		win.checked = nil
		Inactive.Refresh(true)
	end, 10)

	win.warn = win:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	win.warn:SetPoint("TOPLEFT", win, "TOPLEFT", 16, -110)
	win.warn:SetWidth(W - 32)
	win.warn:SetJustifyH("LEFT")
	win.src = win:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	win.src:SetPoint("TOPLEFT", win, "TOPLEFT", 16, -126)
	win.src:SetWidth(W - 32)
	win.src:SetHeight(26)
	win.src:SetJustifyH("LEFT")
	win.src:SetJustifyV("TOP")

	win.rows = {}
	for i = 1, ROWS do
		local row = CreateFrame("Frame", Name("Row"), win)
		row:SetWidth(W - 32)
		row:SetHeight(22)
		row:SetPoint("TOPLEFT", win, "TOPLEFT", 16, -160 - (i - 1) * 22)
		row.chk = CreateFrame("CheckButton", Name("Chk"), row, "UICheckButtonTemplate")
		row.chk:SetWidth(20)
		row.chk:SetHeight(20)
		row.chk:SetPoint("LEFT", row, "LEFT", 0, 0)
		row.chk:SetScript("OnClick", function()
			local r = this:GetParent()
			if r.member then
				win.checked[r.member] = this:GetChecked() and true or false
				Inactive.Refresh()
			end
		end)
		row.fs = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		row.fs:SetPoint("LEFT", row, "LEFT", 26, 0)
		row.fs:SetWidth(W - 70)
		row.fs:SetJustifyH("LEFT")
		row:Hide()
		win.rows[i] = row
	end

	win.prev = BG.MakeButton(win, Name("Btn"), 28, 20, "<")
	win.prev:SetPoint("TOPLEFT", win, "TOPLEFT", 16, -366)
	win.prev:SetScript("OnClick", function() win.page = (win.page or 1) - 1 Inactive.Refresh() end)
	win.next = BG.MakeButton(win, Name("Btn"), 28, 20, ">")
	win.next:SetPoint("LEFT", win.prev, "RIGHT", 4, 0)
	win.next:SetScript("OnClick", function() win.page = (win.page or 1) + 1 Inactive.Refresh() end)
	win.pageFs = win:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	win.pageFs:SetPoint("LEFT", win.next, "RIGHT", 8, 0)
	win.count = win:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	win.count:SetPoint("TOPRIGHT", win, "TOPRIGHT", -20, -370)

	win.confirm = CreateFrame("CheckButton", Name("Confirm"), win, "UICheckButtonTemplate")
	win.confirm:SetWidth(24)
	win.confirm:SetHeight(24)
	win.confirm:SetPoint("TOPLEFT", win, "TOPLEFT", 12, -392)
	win.confirm:SetScript("OnClick", function() Inactive.Refresh() end)
	win.confirmText = getglobal(win.confirm:GetName() .. "Text")
	win.confirmText:SetJustifyH("LEFT")
	win.confirmText:SetWidth(W - 60)

	win.go = BG.MakeButton(win, Name("Btn"), 240, 24, "")
	win.go:SetPoint("BOTTOMLEFT", win, "BOTTOMLEFT", 16, 14)
	win.go:SetScript("OnClick", function() Inactive.Apply() end)
	win.cancel = BG.MakeButton(win, Name("Btn"), 110, 24, "")
	win.cancel:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", -16, 14)
	win.cancel:SetScript("OnClick", function() win:Hide() end)
end

-- redraw; force = the candidates may have changed (days / target changed)
function Inactive.Refresh(force)
	if not win or not win:IsShown() then return end
	local d = BG.db.inactive
	win.title:SetText(GOLD .. BG.T("ina_title") .. "|r")
	Mark(win.btnRank, win.mode == "rank")
	Mark(win.btnKick, win.mode == "kick")
	win.btnRank:SetText(BG.T("ina_mode_rank"))
	win.btnKick:SetText(BG.T("ina_mode_kick"))
	win.lblDays:SetText(BG.T("ina_offline_min"))
	win.lblUnit:SetText(BG.T("lbl_days_unit"))
	local shownDays = tostring(Days())
	if tonumber(win.days:GetText()) ~= Days() then
		win.days.loading = true
		win.days:SetText(shownDays)
		win.days.loading = false
	end
	win.src:SetText(Inactive.SourceNote())
	win.cancel:SetText(BG.T("btn_close"))

	local my = BG.Promo.MyIndex()
	local ranks, n = BG.Promo.Ranks()
	if win.mode == "rank" then
		win.lblTarget:SetText(BG.T("ina_target"))
		win.target:Show()
		local items = {}
		if my then
			for i = my + 1, n - 1 do
				if ranks[i] then table.insert(items, { label = ranks[i], value = ranks[i] }) end
			end
		end
		win.target.SetItems(items)
		win.target.SetValue(d.rank, d.rank)
		win.warn:SetText("")
	else
		win.lblTarget:SetText("")
		win.target:Hide()
		win.target.list:Hide()
		win.warn:SetText(RED .. BG.T("ina_kick_warn") .. "|r")
	end

	local list = Inactive.Candidates(win.mode, Days())
	win.list = list
	-- everybody is ticked at first; new candidates (list changed) too, what the user unticked stays unticked
	win.checked = win.checked or {}
	for i = 1, table.getn(list) do
		if win.checked[list[i].name] == nil then win.checked[list[i].name] = true end
	end
	local pages = math.max(1, math.ceil(table.getn(list) / ROWS))
	win.page = win.page or 1
	if win.page > pages then win.page = pages end
	if win.page < 1 then win.page = 1 end
	local nChecked = 0
	for i = 1, table.getn(list) do if win.checked[list[i].name] then nChecked = nChecked + 1 end end
	for i = 1, ROWS do
		local row = win.rows[i]
		local c = list[(win.page - 1) * ROWS + i]
		if c then
			row.member = c.name
			row.chk:SetChecked(win.checked[c.name] and 1 or nil)
			row.fs:SetText(BG.T("ina_row", WHITE .. c.name .. "|r", c.info.rank, Inactive.Color(c.off) .. Inactive.Short(c.off) .. "|r" .. WHITE, JoinedShort(c.name)))
			row:Show()
		else
			row.member = nil
			row:Hide()
		end
	end
	if table.getn(list) == 0 then
		win.rows[1].fs:SetText(GRAY .. BG.T("ina_none") .. "|r")
		win.rows[1].chk:Hide()
		win.rows[1]:Show()
	else
		win.rows[1].chk:Show()
	end
	if pages > 1 then
		win.pageFs:SetText(BG.T("chg_page", win.page, pages))
		win.prev:Show() win.next:Show()
	else
		win.pageFs:SetText("")
		win.prev:Hide() win.next:Hide()
	end
	win.count:SetText(BG.T("ina_count", table.getn(list)))
	if win.mode == "kick" then
		win.confirm:Show()
		win.confirmText:SetText(RED .. BG.T("ina_confirm_kick", nChecked) .. "|r")
		win.go:SetText(BG.T("ina_apply_kick", nChecked))
	else
		win.confirm:Hide()
		win.confirm:SetChecked(nil)
		win.go:SetText(BG.T("ina_apply_rank", d.rank, nChecked))
	end
	local ready = nChecked > 0
	if win.mode == "kick" and not win.confirm:GetChecked() then ready = false end
	if ready then win.go:Enable() else win.go:Disable() end
end

function Inactive.Apply()
	if not win or not win.list then return end
	local names = {}
	for i = 1, table.getn(win.list) do
		if win.checked[win.list[i].name] then table.insert(names, win.list[i].name) end
	end
	if table.getn(names) == 0 then return end
	if win.mode == "kick" then
		if not win.confirm:GetChecked() then return end
		local n = Inactive.EnqueueKick(names, Days())
		if n > 0 then
			if n > 1 then Note(BG.T("ina_start_kick", n)) end
			win:Hide()
		end
	else
		local target = BG.db.inactive.rank
		if table.getn(names) > 1 then Note(BG.T("chg_start", table.getn(names), target)) end
		for i = 1, table.getn(names) do BG.Promo.EnqueueTo(names[i], target) end
		win:Hide()
	end
end

function Inactive.Open(mode)
	if not win then Build() end
	win.mode = mode or win.mode or "rank"
	win.checked = nil
	win.page = 1
	win:Show()
	win:Raise()
	Inactive.Refresh(true)
end

function Inactive.IsOpen() return win and win:IsShown() end

BananaGuild.files = BananaGuild.files or {}
BananaGuild.files.Inactive = true
