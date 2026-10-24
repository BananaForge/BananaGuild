--[[
  BananaGuild - NoteWin
  Window to enter / edit the guild note of a member: main or twink (+ main name), professions, spec.
  Opens automatically for the inviter / recruiter and the officers when somebody joins ("join" mode), or from the members tab ("edit" mode).
  Has buttons to ask the player for professions / spec / twinks by whisper; the whisper replies are read and turned into a proposal.
]]

local BG = BananaGuild
local NW = {}
BG.NoteWin = NW

local W, H = 460, 548
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
	-- nobody gets two greetings: somebody else may have greeted already
	local by = BG.Recruit and BG.Recruit.GreetedBy(win.target)
	local canGreet = win.mode == "join" and win.greet and not by
	win.btnGo:SetText(BG.T(canGreet and "btn_note_greet" or "btn_note_set"))
	win.btnOnly:SetText(BG.T("btn_note_only"))
	win.btnLater:SetText(BG.T(win.mode == "join" and "btn_later" or "btn_close"))
	if canGreet then win.btnOnly:Show() else win.btnOnly:Hide() end
	if win.mode == "join" and by then
		win.greetInfo:SetText(GREEN .. BG.T("nwin_greeted", by) .. "|r")
	else
		win.greetInfo:SetText("")
	end
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
	local last = NW.LastReply(name)
	if last then
		win.reply:SetText(WHITE .. BG.T("nwin_reply", BG.Stamp(last.at)) .. "|r " .. last.text)
	elseif not online then
		win.reply:SetText(GRAY .. BG.T("nwin_ask_offline") .. "|r")
	else
		win.reply:SetText(GRAY .. BG.T("nwin_noreply") .. "|r")
	end
	local sug = NW.Suggestion(name)
	win.suggestion = sug
	if sug and sug.any then
		local parts = {}
		if sug.kind == "twink" then
			table.insert(parts, sug.main and BG.T("nwin_sug_twink", sug.main) or BG.T("nwin_sug_twink0"))
		elseif sug.kind == "main" then
			table.insert(parts, BG.T("nwin_sug_main"))
		end
		if table.getn(sug.profs) > 0 then
			local names = {}
			for i = 1, table.getn(sug.profs) do table.insert(names, BG.Notes.ProfName(sug.profs[i])) end
			table.insert(parts, BG.T("nwin_sug_profs", table.concat(names, ", ")))
		end
		if sug.spec then table.insert(parts, BG.T("nwin_sug_spec", sug.spec[1])) end
		win.sugText:SetText(GOLD .. BG.T("nwin_suggest") .. "|r " .. table.concat(parts, " - "))
		win.sugBtn:Show()
	else
		win.sugText:SetText("")
		win.sugBtn:Hide()
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

	-- ask the player by whisper (professions / spec / twinks / everything) and read the reply
	win.askLbl = Text(win, 16, -408, "GameFontNormalSmall", W - 32)
	win.askBtns = {}
	local askKinds = { "askAll", "askProf", "askSpec", "askTwink" }
	local askKeys = { "nwin_ask_all", "nwin_ask_prof", "nwin_ask_spec", "nwin_ask_twink" }
	for i = 1, 4 do
		local kind, key = askKinds[i], askKeys[i] -- local per iteration (Lua 5.0 closures share the loop variable)
		local b = BG.MakeButton(win, Name("Btn"), 104, 22, "")
		b:SetPoint("TOPLEFT", win, "TOPLEFT", 16 + (i - 1) * 108, -422)
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
	win.reply = Text(win, 16, -450, "GameFontHighlightSmall", W - 32)
	win.reply:SetHeight(28)
	win.reply:SetJustifyV("TOP")
	win.sugText = Text(win, 16, -482, "GameFontHighlightSmall", W - 168)
	win.sugText:SetHeight(26)
	win.sugText:SetJustifyV("TOP")
	win.sugBtn = BG.MakeButton(win, Name("Btn"), 130, 22, "")
	win.sugBtn:SetPoint("TOPRIGHT", win, "TOPRIGHT", -16, -482)
	win.sugBtn:SetScript("OnClick", function() NW.ApplySuggestion() end)
	win.sugBtn:Hide()
	win.greetInfo = Text(win, 200, -398, "GameFontHighlightSmall", W - 216)
	win.greetInfo:SetJustifyH("RIGHT")

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
	if greet and BG.Recruit and not BG.Recruit.GreetedBy(name) then BG.Recruit.Welcome(name) end
	win:Hide()
end

--------------------------------------------------------------------- ask + replies

NW.replies = {}   -- name -> { { at, text }, ... } (whispers of guild members, newest last)
local REPLY_TTL = 30 * 60

function NW.OnWhisper(msg, sender)
	if not msg or not sender then return end
	local name = BG.NormName(sender)
	if name == BG.me or not BG.roster[name] then return end
	local list = NW.replies[name] or {}
	NW.replies[name] = list
	table.insert(list, { at = time(), text = msg })
	while table.getn(list) > 6 do table.remove(list, 1) end
	if win and win:IsShown() and win.target == name then NW.RedrawAsk() end
end

-- the replies of the last 30 minutes
local function Recent(name)
	local out = {}
	local list = NW.replies[name]
	if not list then return out end
	local now = time()
	for i = 1, table.getn(list) do
		if now - list[i].at <= REPLY_TTL then table.insert(out, list[i]) end
	end
	return out
end

function NW.LastReply(name)
	local r = Recent(name)
	return r[table.getn(r)]
end

function NW.Suggestion(name)
	local r = Recent(name)
	if table.getn(r) == 0 then return nil end
	local texts = {}
	for i = 1, table.getn(r) do table.insert(texts, r[i].text) end
	local info = BG.roster[name]
	return BG.Notes.Suggest(table.concat(texts, " "), info and info.ckey, name)
end

function NW.Ask(name, kind)
	local info = name and BG.roster[name]
	if not info or name == BG.me then return end
	if not info.online then BG.Print(BG.T("menu_offline", name)) return end
	local line = BG.PickVariant(kind)
	if not line then return end
	BG.SendChat(BG.Fill(line, { name = name }), "WHISPER", name)
	BG.Print(BG.T("menu_sent", name))
end

-- takes over only what the reply contained; the person confirms with the normal buttons afterwards
function NW.ApplySuggestion()
	local sug = win and win.suggestion
	if not sug or not sug.any then return end
	if sug.kind then
		win.kind = sug.kind
		if sug.kind == "twink" and sug.main then win.main = sug.main end
	end
	if table.getn(sug.profs) > 0 then
		win.profs = {}
		for i = 1, table.getn(sug.profs) do table.insert(win.profs, sug.profs[i]) end
		win.noprof = false
	end
	if sug.spec then win.spec = sug.spec[1] end
	NW.Redraw()
end

-- somebody greeted this member (kind W): the greet button of an open window is switched off
function NW.MarkGreeted(name, by)
	if win and win:IsShown() and win.target == name then NW.Redraw() end
end

BG.On("CHAT_MSG_WHISPER", function(msg, sender) NW.OnWhisper(msg, sender) end)

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
	win.askLbl:SetText(GOLD .. BG.T("nwin_ask") .. "|r")
	win.askBtns[1]:SetText(BG.T("nwin_ask_all"))
	win.askBtns[2]:SetText(BG.T("nwin_ask_prof"))
	win.askBtns[3]:SetText(BG.T("nwin_ask_spec"))
	win.askBtns[4]:SetText(BG.T("nwin_ask_twink"))
	win.sugBtn:SetText(BG.T("nwin_suggest_btn"))
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
