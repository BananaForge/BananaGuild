--[[
  BananaGuild - NoteWin
  Window to enter / edit the guild note of a member: main or twink (+ main name), professions, spec.
  Opens automatically for the player who is recruiting when somebody joins ("join" mode), or from the members tab ("edit" mode).
]]

local BG = BananaGuild
local NW = {}
BG.NoteWin = NW

local W, H = 460, 448
local GOLD, WHITE, GRAY, GREEN, RED = "|cffffd100", "|cffffffff", "|cff999999", "|cff40ff40", "|cffff5555"
local win
local counter = 0

local function Name(prefix)
	counter = counter + 1
	return "BananaGuildNW" .. prefix .. counter
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

local function Text(parent, x, y, font, width)
	local fs = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlightSmall")
	fs:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
	fs:SetJustifyH("LEFT")
	if width then fs:SetWidth(width) end
	return fs
end

--------------------------------------------------------------------- state

local function CurrentNote()
	if not win then return "", 0 end
	local profs = {}
	if not win.noprof then
		for i = 1, table.getn(win.profs) do table.insert(profs, win.profs[i]) end
	end
	return BG.Notes.Build(win.kind, win.main or "", profs, win.spec)
end

function NW.Redraw()
	if not win or not win:IsShown() then return end
	local info = BG.roster[win.target]
	win.ckey = (info and info.ckey) or win.ckey

	-- header
	win.title:SetText(GOLD .. BG.T(win.mode == "join" and "nwin_join" or "nwin_edit") .. "|r")
	local cls = (info and info.class) or "?"
	local sub = BG.T("nwin_sub", WHITE .. win.target .. "|r", cls, info and info.level or "?")
	local c = BG.db.chars[win.target]
	if c and c.invitedBy and c.invitedBy ~= "" then sub = sub .. " - " .. BG.T("nwin_invby", c.invitedBy) end
	win.sub:SetText(sub)

	-- role
	Mark(win.btnMain, win.kind == "main")
	Mark(win.btnTwink, win.kind == "twink")
	if win.kind == "twink" then win.mainDrop:Show() win.twinkLbl:Show() else win.mainDrop:Hide() win.mainDrop.list:Hide() win.twinkLbl:Hide() end
	win.mainDrop.SetValue(win.main, win.main)

	-- professions
	for i = 1, table.getn(win.profBtns) do
		local b = win.profBtns[i]
		local on = false
		if not win.noprof then
			for j = 1, table.getn(win.profs) do if win.profs[j] == b.code then on = true end end
		end
		b:SetText(BG.Notes.ProfName(b.code))
		Mark(b, on)
	end
	win.noprofChk:SetChecked(win.noprof and 1 or nil)

	-- specs of the class
	local specs = BG.Notes.Specs(win.ckey)
	for i = 1, 5 do
		local b = win.specBtns[i]
		local s = specs[i]
		if i <= table.getn(specs) then
			b.spec = s[1]
			b.specInfo = s
			b:SetText(s[1])
			b:Show()
			Mark(b, win.spec == s[1])
		elseif i == table.getn(specs) + 1 then
			b.spec = ""
			b.specInfo = nil
			b:SetText(BG.T("nwin_spec_none"))
			b:Show()
			Mark(b, not win.spec or win.spec == "")
		else
			b.spec = nil
			b:Hide()
		end
	end
	win.specHint:SetText(win.ckey and "" or (GRAY .. BG.T("nwin_spec_noclass") .. "|r"))

	-- note preview + counter
	local note, len = CurrentNote()
	win.note = note
	win.preview.locked = true
	if win.preview:GetText() ~= note then win.preview:SetText(note) end
	win.preview.locked = false
	local problem
	if win.kind == "twink" and (not win.main or win.main == "") then
		problem = BG.T("nwin_needmain")
	elseif len > BG.Notes.MAXLEN then
		problem = BG.T("nwin_toolong", len)
	end
	local pct = len / BG.Notes.MAXLEN
	if pct > 1 then pct = 1 end
	win.bar:SetWidth(math.max(1, (W - 40) * pct))
	if len > BG.Notes.MAXLEN then win.bar:SetTexture(1, 0.3, 0.3, 1) else win.bar:SetTexture(0.3, 0.9, 0.45, 1) end
	local can = BG.Notes.CanEdit()
	if problem then
		win.info:SetText(RED .. problem .. "|r")
	elseif not can then
		win.info:SetText(GOLD .. BG.T("nwin_noright") .. "|r")
	else
		win.info:SetText(GRAY .. BG.T("nwin_count", len) .. "|r")
	end
	local ok = (not problem) and can
	if ok then
		win.btnGo:Enable() win.btnOnly:Enable()
	else
		win.btnGo:Disable() win.btnOnly:Disable()
	end
	win.btnGo:SetText(BG.T(win.mode == "join" and "btn_note_greet" or "btn_note_set"))
	win.btnOnly:SetText(BG.T("btn_note_only"))
	win.btnLater:SetText(BG.T(win.mode == "join" and "btn_later" or "btn_close"))
	if win.mode == "join" and not win.greet then win.btnGo:SetText(BG.T("btn_note_set")) end
	if win.mode == "join" and win.greet then win.btnOnly:Show() else win.btnOnly:Hide() end
end

--------------------------------------------------------------------- build

local function Build()
	win = CreateFrame("Frame", "BananaGuildNoteWin", UIParent)
	win:SetWidth(W)
	win:SetHeight(H)
	win:SetPoint("CENTER", UIParent, "CENTER", 0, 60)
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

	win.title = Text(win, 16, -14, "GameFontNormalLarge", W - 60)
	win.sub = Text(win, 16, -38, "GameFontHighlightSmall", W - 32)

	-- role
	win.who = Text(win, 16, -62, "GameFontNormalSmall", 200)
	win.btnMain = BG.MakeButton(win, Name("Btn"), 70, 22, "")
	win.btnMain:SetPoint("TOPLEFT", win, "TOPLEFT", 16, -78)
	win.btnMain:SetScript("OnClick", function() win.kind = "main" NW.Redraw() end)
	win.btnTwink = BG.MakeButton(win, Name("Btn"), 70, 22, "")
	win.btnTwink:SetPoint("LEFT", win.btnMain, "RIGHT", 4, 0)
	win.btnTwink:SetScript("OnClick", function() win.kind = "twink" NW.Redraw() end)
	win.twinkLbl = Text(win, 176, -83, "GameFontHighlightSmall", 70)
	-- the main is picked from the members of the guild (scrolling list)
	win.mainDrop = BG.Dropdown(win, 252, -79, 190, function(v)
		win.main = v
		NW.Redraw()
	end, 10)

	-- professions: written out in small letters (the note gets the short keyword), 5 per row
	win.profLbl = Text(win, 16, -110, "GameFontNormalSmall", W - 32)
	win.profBtns = {}
	for i = 1, table.getn(BG.Notes.PROFS) do
		local code = BG.Notes.PROFS[i][1] -- local copy: Lua 5.0 closures share the loop variable
		local b = BG.MakeButton(win, Name("Btn"), 82, 20, "")
		local fs = b:GetFontString()
		if fs then fs:SetFont("Fonts\\FRIZQT__.TTF", 8) end
		b.code = code
		local row = math.floor((i - 1) / 5)
		local col = (i - 1) - row * 5
		b:SetPoint("TOPLEFT", win, "TOPLEFT", 16 + col * 86, -126 - row * 24)
		b:SetScript("OnClick", function()
			win.noprof = false
			local at
			for j = 1, table.getn(win.profs) do if win.profs[j] == code then at = j end end
			if at then
				table.remove(win.profs, at)
			else
				local p = BG.Notes.ProfByCode(code)
				if p and p[2] then
					-- max. 2 main professions: the oldest one drops out
					local mains = {}
					for j = 1, table.getn(win.profs) do
						local q = BG.Notes.ProfByCode(win.profs[j])
						if q and q[2] then table.insert(mains, win.profs[j]) end
					end
					if table.getn(mains) >= 2 then
						for j = 1, table.getn(win.profs) do
							if win.profs[j] == mains[1] then table.remove(win.profs, j) break end
						end
					end
				end
				table.insert(win.profs, code)
			end
			NW.Redraw()
		end)
		b:SetScript("OnEnter", function()
			local p = BG.Notes.ProfByCode(this.code)
			GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
			GameTooltip:SetText(BG.Notes.ProfName(this.code, "de") .. " / " .. BG.Notes.ProfName(this.code, "en"), 1, 0.82, 0)
			GameTooltip:AddLine(BG.T("tip_prof_code", this.code), 1, 1, 1)
			GameTooltip:AddLine(BG.T((p and p[2]) and "tip_prof_main" or "tip_prof_secondary"), 0.7, 0.7, 0.7)
			GameTooltip:Show()
		end)
		b:SetScript("OnLeave", function() GameTooltip:Hide() end)
		table.insert(win.profBtns, b)
	end
	win.noprofChk = CreateFrame("CheckButton", Name("Check"), win, "UICheckButtonTemplate")
	win.noprofChk:SetWidth(24)
	win.noprofChk:SetHeight(24)
	win.noprofChk:SetPoint("TOPLEFT", win, "TOPLEFT", 12, -198)
	win.noprofText = getglobal(win.noprofChk:GetName() .. "Text")
	win.noprofText:SetJustifyH("LEFT")
	win.noprofText:SetWidth(300)
	win.noprofChk:SetScript("OnClick", function()
		win.noprof = this:GetChecked() and true or false
		if win.noprof then win.profs = {} end
		NW.Redraw()
	end)

	-- spec
	win.specLbl = Text(win, 16, -228, "GameFontNormalSmall", W - 32)
	win.specBtns = {}
	for i = 1, 5 do
		local b = BG.MakeButton(win, Name("Btn"), 80, 20, "")
		b:SetPoint("TOPLEFT", win, "TOPLEFT", 16 + (i - 1) * 84, -244)
		b:SetScript("OnClick", function()
			if this.spec == nil then return end
			win.spec = (this.spec ~= "") and this.spec or nil
			NW.Redraw()
		end)
		b:SetScript("OnEnter", function()
			GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
			local sp = this.specInfo
			if not sp then
				GameTooltip:SetText(BG.T("tip_spec_none"), 1, 1, 1)
			else
				-- both languages, whatever language the addon is set to
				GameTooltip:SetText(sp[1], 1, 0.82, 0)
				GameTooltip:AddLine("DE: " .. BG.Notes.SpecName(sp, "de"), 1, 1, 1)
				GameTooltip:AddLine("EN: " .. BG.Notes.SpecName(sp, "en"), 1, 1, 1)
				local col = (sp[4] == "T") and { 0.42, 0.65, 1 } or ((sp[4] == "H") and { 0.48, 0.88, 0.61 } or { 1, 0.56, 0.52 })
				GameTooltip:AddLine(BG.T("rolefull_de_" .. sp[4]), col[1], col[2], col[3], 1)
				GameTooltip:AddLine(BG.T("rolefull_en_" .. sp[4]), col[1], col[2], col[3], 1)
			end
			GameTooltip:Show()
		end)
		b:SetScript("OnLeave", function() GameTooltip:Hide() end)
		b:Hide()
		win.specBtns[i] = b
	end
	win.specHint = Text(win, 16, -268, "GameFontHighlightSmall", W - 32)

	-- note preview (an edit box so it can be selected and copied, but not changed)
	win.noteLbl = Text(win, 16, -286, "GameFontNormalSmall", W - 32)
	win.preview = CreateFrame("EditBox", Name("Preview"), win, "InputBoxTemplate")
	win.preview:SetWidth(W - 44)
	win.preview:SetHeight(20)
	win.preview:SetPoint("TOPLEFT", win, "TOPLEFT", 20, -302)
	win.preview:SetAutoFocus(false)
	win.preview:SetScript("OnTextChanged", function()
		if this.locked then return end
		this.locked = true
		this:SetText(win.note or "")
		this.locked = false
	end)
	win.preview:SetScript("OnEscapePressed", function() this:ClearFocus() end)
	win.preview:SetScript("OnEnterPressed", function() this:ClearFocus() end)
	local back = win:CreateTexture(nil, "ARTWORK")
	back:SetTexture(0, 0, 0, 0.6)
	back:SetWidth(W - 40)
	back:SetHeight(5)
	back:SetPoint("TOPLEFT", win, "TOPLEFT", 20, -326)
	win.bar = win:CreateTexture(nil, "OVERLAY")
	win.bar:SetTexture(0.3, 0.9, 0.45, 1)
	win.bar:SetWidth(10)
	win.bar:SetHeight(5)
	win.bar:SetPoint("TOPLEFT", win, "TOPLEFT", 20, -326)
	win.info = Text(win, 16, -336, "GameFontHighlightSmall", W - 32)
	win.info:SetHeight(26)
	win.info:SetJustifyV("TOP")

	-- own note (stays in the addon, synced to other BananaGuild users): saved when the window closes
	win.intLbl = Text(win, 16, -366, "GameFontNormalSmall", W - 32)
	win.intEdit = CreateFrame("EditBox", Name("IntEdit"), win, "InputBoxTemplate")
	win.intEdit:SetWidth(W - 44)
	win.intEdit:SetHeight(20)
	win.intEdit:SetPoint("TOPLEFT", win, "TOPLEFT", 20, -380)
	win.intEdit:SetAutoFocus(false)
	win.intEdit:SetMaxLetters(80)
	win.intEdit:SetScript("OnEscapePressed", function() this:ClearFocus() end)
	win.intEdit:SetScript("OnEnterPressed", function() this:ClearFocus() end)
	win:SetScript("OnHide", function() NW.SaveInternal() end)

	-- actions
	win.btnGo = BG.MakeButton(win, Name("Btn"), 186, 24, "")
	win.btnGo:SetPoint("BOTTOMLEFT", win, "BOTTOMLEFT", 16, 14)
	win.btnGo:SetScript("OnClick", function() NW.Apply(win.mode == "join" and win.greet) end)
	win.btnOnly = BG.MakeButton(win, Name("Btn"), 110, 24, "")
	win.btnOnly:SetPoint("LEFT", win.btnGo, "RIGHT", 6, 0)
	win.btnOnly:SetScript("OnClick", function() NW.Apply(false) end)
	win.btnLater = BG.MakeButton(win, Name("Btn"), 110, 24, "")
	win.btnLater:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", -16, 14)
	win.btnLater:SetScript("OnClick", function() win:Hide() end)

	win.profs = {}
	win.kind = "main"
end

--------------------------------------------------------------------- actions

local SyncMainItems

-- members that can be a main: everybody in the guild except the member himself and members whose note says twink
function NW.MainItems()
	local names = {}
	for name, info in pairs(BG.roster) do
		local pn = info.parsed
		if name ~= win.target and not (pn and pn.kind == "twink") then table.insert(names, name) end
	end
	table.sort(names, function(a, b) return string.lower(a) < string.lower(b) end)
	local items = {}
	for i = 1, table.getn(names) do
		local info = BG.roster[names[i]]
		table.insert(items, { label = names[i] .. "  |cff999999" .. (info.level or "?") .. "|r", value = names[i] })
	end
	return items
end

function NW.SaveInternal()
	if not win or not win.target or not win.intLoaded then return end
	local txt = win.intEdit:GetText() or ""
	local c = BG.db.chars[win.target]
	local old = (c and c.note) or ""
	if txt ~= old and BG.Roster then
		BG.Roster.SetDetails(win.target, nil, nil, txt)
	end
	win.intLoaded = false
end

function NW.Apply(greet)
	if not win or not win.target then return end
	local name = win.target
	if not BG.Notes.CanEdit() then return end
	local note = win.note or ""
	if note == "" or string.len(note) > BG.Notes.MAXLEN then return end
	if win.kind == "twink" and (not win.main or win.main == "") then return end
	BG.Notes.Set(name, note)
	if greet and BG.Recruit then BG.Recruit.Welcome(name) end
	win:Hide()
end

-- name: guild member; mode: "join" (new member, recruiter) or "edit"; opts.greet = offer the guild-chat greeting
function NW.Open(name, mode, opts)
	if not win then Build() end
	NW.SaveInternal() -- the previous member's own note
	opts = opts or {}
	win.target = name
	win.mode = mode or "edit"
	win.greet = opts.greet and true or false
	win.noprof = false
	win.profs = {}
	win.spec = nil
	win.kind = "main"
	local info = BG.roster[name]
	win.ckey = info and info.ckey or nil
	local p = info and info.parsed
	win.main = nil
	if p and p.kind then
		win.kind = p.kind
		if p.main then win.main = p.main end
		for i = 1, table.getn(p.profs) do table.insert(win.profs, p.profs[i]) end
		if p.spec then win.spec = p.spec[1] end
		if table.getn(p.profs) == 0 then
			-- an existing note without professions: keep it that way
			local _, _, g2 = string.find(info.note or "", "%[[^%]]*%]%s*%[([^%]]*)%]")
			if g2 then win.noprof = true end
		end
	end
	local c0 = BG.db.chars[name]
	win.intEdit:SetText((c0 and c0.note) or "")
	win.intLoaded = true
	win.intLbl:SetText(GOLD .. BG.T("nwin_intnote") .. "|r")
	win.who:SetText(BG.T("nwin_who"))
	win.btnMain:SetText(BG.T("nwin_main"))
	win.btnTwink:SetText(BG.T("nwin_twink"))
	win.twinkLbl:SetText(BG.T("nwin_twinkof"))
	win.profLbl:SetText(GOLD .. BG.T("nwin_profs") .. "|r")
	win.noprofText:SetText(BG.T("nwin_noprof"))
	win.specLbl:SetText(GOLD .. BG.T("nwin_spec") .. "|r")
	win.noteLbl:SetText(GOLD .. BG.T("nwin_note") .. "|r")
	SyncMainItems(true)
	win:Show()
	win:Raise()
	if BG.Sound and mode == "join" then BG.Sound("alert") end
	NW.Redraw()
end

-- the roster was refreshed: class / note of the target may have become known
-- fill the main list; only when the guild changed (a refresh would otherwise throw the scroll position away)
SyncMainItems = function(force)
	local items = NW.MainItems()
	local n = table.getn(items)
	local sig = n .. (items[1] and items[1].value or "") .. (items[n] and items[n].value or "")
	if force or sig ~= win.mainSig then
		win.mainSig = sig
		win.mainDrop.SetItems(items)
	end
end

function NW.OnRoster()
	if win and win:IsShown() and win.target then
		SyncMainItems(false)
		if not win.ckey then NW.Redraw() end
	end
end

function NW.IsOpen() return win and win:IsShown() end

BananaGuild.files = BananaGuild.files or {}
BananaGuild.files.NoteWin = true
