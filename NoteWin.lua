--[[
  BananaGuild - NoteWin
  Window to enter / edit the data of a member: main or twink (+ main name), professions, spec and second spec.
  The data is stored in the addon (Data.lua), nothing is written into the guild note.
  Opens automatically for the inviter / recruiter and the officers when somebody joins ("join" mode), or from the members tab ("edit" mode).
  Has buttons to ask the player for professions / spec / twinks by whisper (the reply comes in the normal chat).
  Spec: up to two specs can be ticked in one row (the first one is the spec, the second one the second spec).
]]

local BG = BananaGuild
local NW = {}
BG.NoteWin = NW

local W, H = 460, 472
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

	-- specs of the class: up to two can be ticked, the first is the spec, the second one the second spec
	local specs = BG.Notes.Specs(win.ckey)
	if win.spec2 and win.spec2 == win.spec then win.spec2 = nil end
	for i = 1, 5 do
		local b = win.specBtns[i]
		local s = specs[i]
		if i <= table.getn(specs) then
			b.spec = s[1]
			b.specInfo = s
			local mark = ""
			if win.spec == s[1] then mark = "" elseif win.spec2 == s[1] then mark = " (2)" end
			b:SetText(s[1] .. mark)
			b:Show()
			Mark(b, win.spec == s[1] or win.spec2 == s[1])
		elseif i == table.getn(specs) + 1 then
			b.spec = ""
			b.specInfo = nil
			b:SetText(BG.T("nwin_spec_none"))
			b:Show()
			Mark(b, not win.spec)
		else
			b.spec = nil
			b:Hide()
		end
	end
	win.specHint:SetText(win.ckey and "" or (GRAY .. BG.T("nwin_spec_noclass") .. "|r"))

	-- status line: what is entered, what is missing
	local problem
	if win.kind == "twink" and (not win.main or win.main == "") then problem = BG.T("nwin_needmain") end
	local can = BG.Data.CanEdit()
	if problem then
		win.info:SetText(RED .. problem .. "|r")
	elseif not can then
		win.info:SetText(GOLD .. BG.T("nwin_noright") .. "|r")
	else
		local parts = {}
		if win.kind == "twink" then table.insert(parts, BG.T("nwin_sug_twink", win.main or "?")) else table.insert(parts, BG.T("nwin_sug_main")) end
		if win.noprof then
			table.insert(parts, BG.T("data_noprof"))
		elseif table.getn(win.profs) > 0 then
			local names = {}
			for i = 1, table.getn(win.profs) do table.insert(names, BG.Notes.ProfName(win.profs[i])) end
			table.insert(parts, table.concat(names, " + "))
		end
		if win.spec then table.insert(parts, win.spec .. (win.spec2 and (" / " .. win.spec2) or "")) end
		local missing = {}
		if table.getn(win.profs) == 0 and not win.noprof then table.insert(missing, BG.T("data_miss_profs")) end
		if not win.spec then table.insert(missing, BG.T("data_miss_spec")) end
		local line = table.concat(parts, " - ")
		if table.getn(missing) == 0 then
			win.info:SetText(GREEN .. BG.T("data_complete") .. "|r  " .. line)
		else
			win.info:SetText(GOLD .. BG.T("data_missing", table.concat(missing, ", ")) .. "|r  " .. line)
		end
	end
	local ok = (not problem) and can
	if ok then
		win.btnGo:Enable() win.btnOnly:Enable()
	else
		win.btnGo:Disable() win.btnOnly:Disable()
	end
	local canGreet = win.mode == "join" and win.greet
	win.btnGo:SetText(BG.T(canGreet and "btn_note_greet" or "btn_note_set"))
	win.btnOnly:SetText(BG.T("btn_note_only"))
	win.btnLater:SetText(BG.T(win.mode == "join" and "btn_later" or "btn_close"))
	if canGreet then win.btnOnly:Show() else win.btnOnly:Hide() end
	NW.RedrawAsk()
end

-- the "ask" section: buttons, last reply and the proposal read from the replies
function NW.RedrawAsk()
	if not win or not win:IsShown() then return end
	local name = win.target
	local info = BG.roster[name]
	local online = info and info.online
	for i = 1, table.getn(win.askBtns) do
		if online then win.askBtns[i]:Enable() else win.askBtns[i]:Disable() end
	end
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
		local b = BG.MakeButton(win, Name("Btn"), 106, 20, "")
		local fs = b:GetFontString()
		if fs then fs:SetFont("Fonts\\FRIZQT__.TTF", 10) end
		b.code = code
		local row = math.floor((i - 1) / 4)
		local col = (i - 1) - row * 4
		b:SetPoint("TOPLEFT", win, "TOPLEFT", 16 + col * 110, -126 - row * 24)
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
	win.noprofChk:SetPoint("TOPLEFT", win, "TOPLEFT", 12, -222)
	win.noprofText = getglobal(win.noprofChk:GetName() .. "Text")
	win.noprofText:SetJustifyH("LEFT")
	win.noprofText:SetWidth(300)
	win.noprofChk:SetScript("OnClick", function()
		win.noprof = this:GetChecked() and true or false
		if win.noprof then win.profs = {} end
		NW.Redraw()
	end)

	-- spec
	win.specLbl = Text(win, 16, -254, "GameFontNormalSmall", W - 32)
	win.specBtns = {}
	for i = 1, 5 do
		local b = BG.MakeButton(win, Name("Btn"), 80, 20, "")
		b:SetPoint("TOPLEFT", win, "TOPLEFT", 16 + (i - 1) * 84, -270)
		b:SetScript("OnClick", function()
			if this.spec == nil then return end
			local code = this.spec
			if code == "" then
				win.spec, win.spec2 = nil, nil          -- "empty": nothing ticked
			elseif code == win.spec then
				win.spec, win.spec2 = win.spec2, nil    -- untick the first: the second one moves up
			elseif code == win.spec2 then
				win.spec2 = nil
			elseif not win.spec then
				win.spec = code
			else
				win.spec2 = code                        -- the second one (a third click replaces it)
			end
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
	win.specHint = Text(win, 150, -255, "GameFontHighlightSmall", W - 170)
	-- note preview (an edit box so it can be selected and copied, but not changed)
	win.info = Text(win, 16, -302, "GameFontHighlightSmall", W - 32)
	win.info:SetHeight(30)
	win.info:SetJustifyV("TOP")

	-- own note (stays in the addon, synced to other BananaGuild users): saved when the window closes
	win.intLbl = Text(win, 16, -340, "GameFontNormalSmall", W - 32)
	win.intEdit = CreateFrame("EditBox", Name("IntEdit"), win, "InputBoxTemplate")
	win.intEdit:SetWidth(W - 44)
	win.intEdit:SetHeight(20)
	win.intEdit:SetPoint("TOPLEFT", win, "TOPLEFT", 20, -354)
	win.intEdit:SetAutoFocus(false)
	win.intEdit:SetMaxLetters(60)
	win.intEdit:SetScript("OnEscapePressed", function() this:ClearFocus() end)
	win.intEdit:SetScript("OnEnterPressed", function() this:ClearFocus() end)
	win:SetScript("OnHide", function() NW.SaveInternal() end)

	-- ask the player by whisper (professions / spec / twinks / everything) and read the reply
	win.askLbl = Text(win, 16, -386, "GameFontNormalSmall", W - 32)
	win.askBtns = {}
	local askKinds = { "askAll", "askProf", "askSpec", "askTwink" }
	local askKeys = { "nwin_ask_all", "nwin_ask_prof", "nwin_ask_spec", "nwin_ask_twink" }
	for i = 1, 4 do
		local kind, key = askKinds[i], askKeys[i] -- local per iteration (Lua 5.0 closures share the loop variable)
		local b = BG.MakeButton(win, Name("Btn"), 104, 22, "")
		b:SetPoint("TOPLEFT", win, "TOPLEFT", 16 + (i - 1) * 108, -400)
		b:SetScript("OnClick", function() NW.Ask(win.target, kind) end)
		b:SetScript("OnEnter", function()
			GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
			GameTooltip:SetText(BG.T(key), 1, 0.82, 0)
			GameTooltip:AddLine(BG.T("tip_nwin_ask"), 1, 1, 1, 1)
			GameTooltip:Show()
		end)
		b:SetScript("OnLeave", function() GameTooltip:Hide() end)
		win.askBtns[i] = b
	end
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

-- the shared note: saved when the window closes (only officers can change it)
function NW.SaveInternal()
	if not win or not win.target or not win.intLoaded then return end
	local txt = win.intEdit:GetText() or ""
	if BG.Data.CanEdit() then BG.Data.SetNote(win.target, txt) end
	win.intLoaded = false
end

function NW.Apply(greet)
	if not win or not win.target then return end
	local name = win.target
	if not BG.Data.CanEdit() then return end
	if win.kind == "twink" and (not win.main or win.main == "") then return end
	local profs = {}
	if not win.noprof then
		for i = 1, table.getn(win.profs) do table.insert(profs, win.profs[i]) end
	end
	BG.Data.Save(name, { kind = win.kind, main = win.main, profs = profs, noprof = win.noprof, spec = win.spec, spec2 = win.spec2 })
	if greet and BG.Recruit then BG.Recruit.Welcome(name) end
	win:Hide()
end

--------------------------------------------------------------------- ask + replies

function NW.Ask(name, kind)
	local info = name and BG.roster[name]
	if not info or name == BG.me then return end
	if not info.online then BG.Print(BG.T("menu_offline", name)) return end
	local line = BG.PickVariant(kind)
	if not line then return end
	BG.SendChat(BG.Fill(line, { name = name }), "WHISPER", name)
	BG.Print(BG.T("menu_sent", name))
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
	win.spec2 = nil
	win.kind = "main"
	local info = BG.roster[name]
	win.ckey = info and info.ckey or nil
	do
		local s2 = win.ckey and BG.Data.Spec2(name, win.ckey)
		if s2 then win.spec2 = s2[1] end
	end
	local p = info and info.parsed
	win.main = nil
	if p then
		if p.kind then
			win.kind = p.kind
			if p.main then win.main = p.main end
		end
		for i = 1, table.getn(p.profs) do table.insert(win.profs, p.profs[i]) end
		if p.spec then win.spec = p.spec[1] end
		if p.noprof then win.noprof = true end
	end
	win.intEdit:SetText(BG.Data.Note(name) or "")
	win.intLoaded = true
	win.intLbl:SetText(GOLD .. BG.T("nwin_intnote") .. "|r")
	win.who:SetText(BG.T("nwin_who"))
	win.btnMain:SetText(BG.T("nwin_main"))
	win.btnTwink:SetText(BG.T("nwin_twink"))
	win.twinkLbl:SetText(BG.T("nwin_twinkof"))
	win.profLbl:SetText(GOLD .. BG.T("nwin_profs") .. "|r")
	win.noprofText:SetText(BG.T("nwin_noprof"))
	win.specLbl:SetText(GOLD .. BG.T("nwin_spec") .. "|r")
	win.askLbl:SetText(GOLD .. BG.T("nwin_ask") .. "|r")
	win.askBtns[1]:SetText(BG.T("nwin_ask_all"))
	win.askBtns[2]:SetText(BG.T("nwin_ask_prof"))
	win.askBtns[3]:SetText(BG.T("nwin_ask_spec"))
	win.askBtns[4]:SetText(BG.T("nwin_ask_twink"))
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
