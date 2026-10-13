--[[
  BananaGuild - UI
  Main window with a left tab bar. Top right: language switch + support. Bottom right: version + self test.
  Every static label is registered with a locale key, so switching DE/EN relabels everything instantly.
]]

local BG = BananaGuild
local UI = {}
BG.UI = UI

local GOLD, WHITE, GRAY, GREEN, RED, YELLOW = "|cffffd100", "|cffffffff", "|cff999999", "|cff40ff40", "|cffff5555", "|cffffff66"

local main, panels, tabButtons = nil, {}, {}
local locList = {}     -- { widget, key, kind }
local loaders = {}     -- panelKey -> list of widgets with :Load()
UI.current = nil

local TABS = { "addons", "recruit", "scanner", "texts", "members", "log", "settings" }

--------------------------------------------------------------------- helpers

local function Reg(widget, key, kind)
	table.insert(locList, { w = widget, key = key, kind = kind or "text" })
	if (kind or "text") == "text" then widget:SetText(BG.T(key)) end
	return widget
end

local function Label(parent, key, x, y, font, width)
	local fs = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlight")
	fs:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
	fs:SetJustifyH("LEFT")
	if width then fs:SetWidth(width) end
	if key then Reg(fs, key) end
	return fs
end

local function Tooltip(widget, key)
	widget:SetScript("OnEnter", function()
		GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
		GameTooltip:SetText(BG.T(key), 1, 1, 1, 1, 1)
		GameTooltip:Show()
	end)
	widget:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

local function AddLoader(panelKey, w)
	loaders[panelKey] = loaders[panelKey] or {}
	table.insert(loaders[panelKey], w)
end

local function MakeButton(parent, name, key, w, h, onClick)
	local b = BG.MakeButton(parent, name, w, h or 22, "")
	Reg(b, key)
	if onClick then b:SetScript("OnClick", onClick) end
	return b
end

local nameCounter = 0
local function NextName(prefix)
	nameCounter = nameCounter + 1
	return "BananaGuild" .. prefix .. nameCounter
end

local function MakeCheck(panelKey, parent, x, y, labelKey, getv, setv, tipKey)
	local name = NextName("Check")
	local c = CreateFrame("CheckButton", name, parent, "UICheckButtonTemplate")
	c:SetWidth(24)
	c:SetHeight(24)
	c:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
	local fs = getglobal(name .. "Text")
	fs:SetJustifyH("LEFT")
	fs:SetWidth(250)
	Reg(fs, labelKey)
	c.get, c.set = getv, setv
	c:SetScript("OnClick", function()
		local v = this:GetChecked() and true or false
		this.set(v)
	end)
	if tipKey then
		c:SetScript("OnEnter", function()
			GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
			GameTooltip:SetText(BG.T(tipKey), 1, 1, 1, 1, 1)
			GameTooltip:Show()
		end)
		c:SetScript("OnLeave", function() GameTooltip:Hide() end)
	end
	c.Load = function(self) self:SetChecked(self.get() and 1 or nil) end
	AddLoader(panelKey, c)
	return c
end

local function MakeEdit(panelKey, parent, x, y, w, getv, setv, maxl)
	local e = CreateFrame("EditBox", NextName("Edit"), parent, "InputBoxTemplate")
	e:SetWidth(w)
	e:SetHeight(20)
	e:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
	e:SetAutoFocus(false)
	if maxl then e:SetMaxLetters(maxl) end
	e.get, e.set = getv, setv
	e:SetScript("OnTextChanged", function()
		if this.loading then return end
		this.set(this:GetText())
	end)
	e:SetScript("OnEscapePressed", function() this:ClearFocus() end)
	e:SetScript("OnEnterPressed", function() this:ClearFocus() end)
	e.Load = function(self)
		self.loading = true
		self:SetText(tostring(self.get() or ""))
		self.loading = false
	end
	if panelKey then AddLoader(panelKey, e) end
	return e
end

local function NumberSetter(tbl, key, minv)
	return function(txt)
		local n = tonumber(txt)
		if n then
			if minv and n < minv then n = minv end
			tbl[key] = n
		end
	end
end

-- multi-line text box with scrolling; get/set are functions
local function MakeTextArea(panelKey, parent, x, y, w, h, getv, setv, maxl)
	local box = CreateFrame("Frame", NextName("Area"), parent)
	box:SetWidth(w)
	box:SetHeight(h)
	box:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
	BG.Backdrop(box, false)
	local sf = CreateFrame("ScrollFrame", NextName("AreaSF"), box, "UIPanelScrollFrameTemplate")
	sf:SetPoint("TOPLEFT", box, "TOPLEFT", 8, -8)
	sf:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -30, 8)
	local eb = CreateFrame("EditBox", NextName("AreaEB"), sf)
	eb:SetMultiLine(true)
	eb:SetAutoFocus(false)
	eb:SetFontObject(GameFontHighlight)
	eb:SetWidth(w - 46)
	eb:SetHeight(h - 16)
	eb:SetMaxLetters(maxl or 3000)
	sf:SetScrollChild(eb)
	local meas = box:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	meas:SetWidth(w - 46)
	meas:SetPoint("TOPLEFT", UIParent, "BOTTOMRIGHT", 100, -100) -- off-screen measuring string
	meas:SetAlpha(0)
	local function Fit()
		local ok, th = pcall(function()
			meas:SetText((eb:GetText() or "") .. "\n")
			return meas:GetHeight()
		end)
		local want = h - 16
		if ok and th and th + 10 > want then want = th + 10 end
		eb:SetHeight(want)
		if sf.UpdateScrollChildRect then sf:UpdateScrollChildRect() end
	end
	eb.get, eb.set = getv, setv
	eb:SetScript("OnTextChanged", function()
		Fit()
		if this.loading then return end
		this.set(this:GetText())
	end)
	eb:SetScript("OnEscapePressed", function() this:ClearFocus() end)
	box:EnableMouse(true)
	box:SetScript("OnMouseDown", function() eb:SetFocus() end)
	eb.Load = function(self)
		self.loading = true
		self:SetText(tostring(self.get() or ""))
		self.loading = false
		Fit()
	end
	box.edit = eb
	if panelKey then AddLoader(panelKey, eb) end
	return box
end

-- scrolling list. build(row) creates the cells, fill(row, item, index) fills them.
local function MakeList(parent, x, y, w, rows, rh, build, fill, onClick)
	local L = { rows = {}, offset = 0, data = {}, nrows = rows }
	local f = CreateFrame("Frame", NextName("List"), parent)
	f:SetWidth(w)
	f:SetHeight(rows * rh + 8)
	f:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
	BG.Backdrop(f, false)
	f:SetBackdropColor(0, 0, 0, 0.55)
	L.frame = f

	local slider = CreateFrame("Slider", NextName("ListSlider"), f)
	slider:SetWidth(14)
	slider:SetHeight(rows * rh)
	slider:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4)
	slider:EnableMouse(true)
	slider:SetOrientation("VERTICAL")
	slider:SetMinMaxValues(0, 0)
	slider:SetValueStep(1)
	slider:SetValue(0)
	slider:SetThumbTexture("Interface\\Buttons\\UI-ScrollBar-Knob")
	local thumb = slider:GetThumbTexture()
	if thumb then thumb:SetWidth(14) thumb:SetHeight(22) end
	L.slider = slider

	local function Draw()
		for i = 1, rows do
			local r = L.rows[i]
			local idx = L.offset + i
			local item = L.data[idx]
			if item then
				r.item, r.index = item, idx
				fill(r, item, idx)
				r:Show()
			else
				r.item = nil
				r:Hide()
			end
		end
	end
	L.Draw = Draw

	slider:SetScript("OnValueChanged", function()
		L.offset = math.floor((this:GetValue() or 0) + 0.5)
		Draw()
	end)

	local function Wheel()
		local cur = slider:GetValue()
		slider:SetValue(cur - arg1 * 3)
	end
	f:EnableMouseWheel(true)
	f:SetScript("OnMouseWheel", Wheel)

	for i = 1, rows do
		local r = CreateFrame("Button", NextName("Row"), f)
		r:SetWidth(w - 26)
		r:SetHeight(rh)
		r:SetPoint("TOPLEFT", f, "TOPLEFT", 4, -4 - (i - 1) * rh)
		r.bg = r:CreateTexture(nil, "BACKGROUND")
		r.bg:SetAllPoints(r)
		r.bg:SetTexture(1, 1, 1, 0)
		r:EnableMouseWheel(true)
		r:SetScript("OnMouseWheel", Wheel)
		if onClick then
			r:SetScript("OnClick", function() onClick(this, this.item, this.index) end)
			r:SetScript("OnEnter", function() this.bg:SetTexture(1, 1, 1, 0.12) end)
			r:SetScript("OnLeave", function()
				if this.selected then this.bg:SetTexture(1, 0.82, 0, 0.18) else this.bg:SetTexture(1, 1, 1, 0) end
			end)
		end
		build(r)
		L.rows[i] = r
	end

	function L.SetData(d)
		L.data = d or {}
		local n = table.getn(L.data)
		local maxo = n - rows
		if maxo < 0 then maxo = 0 end
		slider:SetMinMaxValues(0, maxo)
		if L.offset > maxo then L.offset = maxo end
		slider:SetValue(L.offset)
		if maxo == 0 then slider:Hide() else slider:Show() end
		Draw()
	end
	return L
end

local function Cell(row, x, w, justify, font)
	local fs = row:CreateFontString(nil, "OVERLAY", font or "GameFontHighlightSmall")
	fs:SetPoint("LEFT", row, "LEFT", x, 0)
	fs:SetWidth(w)
	fs:SetJustifyH(justify or "LEFT")
	return fs
end

--------------------------------------------------------------------- panel: addons / analytics

local function BuildAddons(p)
	Label(p, "addons_header", 0, -2, "GameFontNormal")
	local cols = { { 0, 150, "col_addon" }, { 160, 70, "col_installed" }, { 235, 70, "col_running" },
		{ 310, 60, "col_7d" }, { 375, 60, "col_30d" }, { 440, 70, "col_share" } }
	for i = 1, table.getn(cols) do
		local c = cols[i]
		local fs = Label(p, c[3], c[1], -24, "GameFontNormalSmall", c[2])
	end
	p.stat = {}
	for r = 1, table.getn(BG.TRACKED) do
		p.stat[r] = {}
		for i = 1, table.getn(cols) do
			local c = cols[i]
			local fs = Label(p, nil, c[1], -24 - r * 15, "GameFontHighlightSmall", c[2])
			p.stat[r][i] = fs
		end
	end
	p.summary = Label(p, nil, 0, -24 - 6 * 15 - 6, "GameFontDisableSmall", 590)

	local q = MakeButton(p, NextName("Btn"), "btn_query", 170, 22, function() BG.Presence.Query() end)
	q:SetPoint("TOPLEFT", p, "TOPLEFT", 0, -148)
	Tooltip(q, "tip_query")
	MakeCheck("addons", p, 190, -148, "chk_show_all",
		function() return UI.showAllMembers end,
		function(v) UI.showAllMembers = v UI.Refresh("addons") end)

	-- member table
	local hdr = { { 6, 100, "col_name" }, { 112, 66, "key_craft" }, { 182, 66, "key_bank" }, { 252, 66, "key_lootline" },
		{ 322, 66, "key_loot" }, { 392, 66, "key_guild" }, { 460, 100, "col_last" } }
	for i = 1, table.getn(hdr) do
		Label(p, hdr[i][3], hdr[i][1], -178, "GameFontNormalSmall", hdr[i][2])
	end
	local keys = { "craft", "bank", "lootline", "loot", "guild" }
	p.list = MakeList(p, 0, -192, 596, 12, 17,
		function(r)
			r.name = Cell(r, 6, 100)
			r.k = {}
			for i = 1, 5 do r.k[i] = Cell(r, 112 + (i - 1) * 70, 66) end
			r.last = Cell(r, 460, 100)
		end,
		function(r, item)
			local info = BG.roster[item.name]
			local online = info and info.online
			r.name:SetText((online and GREEN or WHITE) .. item.name .. "|r")
			for i = 1, 5 do
				local v = item.p and item.p.addons and item.p.addons[keys[i]]
				if v then
					local ver, running = BG.Presence.Split(v)
					if running then r.k[i]:SetText(GREEN .. ver .. "|r") else r.k[i]:SetText(YELLOW .. BG.T("state_disabled") .. "|r") end
				else
					r.k[i]:SetText(GRAY .. "-|r")
				end
			end
			if item.p and item.p.last then
				r.last:SetText(date("%d.%m. %H:%M", item.p.last) .. GRAY .. " (" .. (item.p.count or 0) .. ")|r")
			else
				r.last:SetText(GRAY .. BG.T("never") .. "|r")
			end
		end)
	local hint = Label(p, "addons_hint", 0, -192 - 12 * 17 - 14, "GameFontDisableSmall", 590)
	hint:SetHeight(32)
	hint:SetJustifyV("TOP")

	p.refresh = function()
		local st = BG.Presence.Stats()
		for i = 1, table.getn(BG.TRACKED) do
			local e = BG.TRACKED[i]
			local row = st.byKey[e.key]
			local cells = p.stat[i]
			cells[1]:SetText(GOLD .. e.label .. "|r")
			cells[2]:SetText(tostring(row.installed))
			cells[3]:SetText(tostring(row.running))
			cells[4]:SetText(tostring(row.active7))
			cells[5]:SetText(tostring(row.active30))
			local pct = (st.guildTotal > 0) and math.floor(row.running * 100 / st.guildTotal + 0.5) or 0
			cells[6]:SetText(pct .. "%")
		end
		p.summary:SetText(BG.T("addons_summary", st.guildTotal, st.seen, st.outside))
		p.list.SetData(BG.Presence.Rows(UI.showAllMembers))
	end
end

--------------------------------------------------------------------- panel: recruiting

local function FormatLeft(sec)
	if sec < 0 then sec = 0 end
	return string.format("%d:%02d", math.floor(sec / 60), math.floor(sec - math.floor(sec / 60) * 60))
end

local function BuildRecruit(p)
	local db = BG.db
	Label(p, "rec_header", 0, -2, "GameFontNormal")

	local box = CreateFrame("Frame", NextName("Box"), p)
	box:SetWidth(596)
	box:SetHeight(64)
	box:SetPoint("TOPLEFT", p, "TOPLEFT", 0, -24)
	BG.Backdrop(box, false)
	p.status = box:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	p.status:SetPoint("TOPLEFT", box, "TOPLEFT", 12, -10)
	p.status:SetWidth(400)
	p.status:SetJustifyH("LEFT")
	p.other = box:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	p.other:SetPoint("TOPLEFT", box, "TOPLEFT", 12, -38)
	p.other:SetWidth(410)
	p.other:SetJustifyH("LEFT")
	p.toggle = BG.MakeButton(box, NextName("Btn"), 150, 30, "")
	p.toggle:SetPoint("RIGHT", box, "RIGHT", -14, 0)
	p.toggle:SetScript("OnClick", function() BG.Recruit.Toggle() end)

	Label(p, "rec_interval", 0, -100)
	MakeEdit("recruit", p, 112, -96, 36, function() return db.recruit.interval end, NumberSetter(db.recruit, "interval", 1), 4)
	Label(p, "rec_chmain", 180, -100)
	MakeEdit("recruit", p, 290, -96, 30, function() return db.recruit.chMain end, function(t)
		NumberSetter(db.recruit, "chMain", 1)(t)
		BG.Presence.Apply()
	end, 2)
	Label(p, "rec_chinst", 340, -100)
	MakeEdit("recruit", p, 500, -96, 30, function() return db.recruit.chInstance end, NumberSetter(db.recruit, "chInstance", 1), 2)

	MakeCheck("recruit", p, 0, -126, "chk_skipcombat",
		function() return db.recruit.skipCombat end,
		function(v) db.recruit.skipCombat = v end)
	local now = MakeButton(p, NextName("Btn"), "btn_postnow", 190, 22, function()
		if not BG.db.features.recruit then BG.Print(BG.T("feature_off")) return end
		BG.Recruit.PostNow()
	end)
	now:SetPoint("TOPLEFT", p, "TOPLEFT", 400, -128)
	Tooltip(now, "tip_postnow")

	Label(p, "rec_message", 0, -160, "GameFontNormal")
	p.counter = Label(p, nil, 400, -160, "GameFontDisableSmall", 190)
	p.counter:SetJustifyH("RIGHT")
	Label(p, "lbl_variant", 0, -186, "GameFontNormalSmall", 70)
	p.slotBtns = {}
	for s = 1, BG.VARIANTS do
		local slot = s
		local b = BG.MakeButton(p, NextName("Btn"), 40, 22, tostring(s))
		b:SetPoint("TOPLEFT", p, "TOPLEFT", 74 + (s - 1) * 44, -181)
		b:SetScript("OnClick", function() UI.SelectRecruitSlot(slot) end)
		p.slotBtns[s] = b
	end
	UI.recSlot = 1
	p.area = MakeTextArea("recruit", p, 0, -210, 596, 100,
		function()
			local v = db.variants.recruit
			return v and v[UI.recSlot or 1] or ""
		end,
		function(v)
			db.variants.recruit = db.variants.recruit or {}
			db.variants.recruit[UI.recSlot or 1] = (string.gsub(v, "[\r\n]+", " "))
			UI.UpdateCounter()
		end, 255)

	local reset = MakeButton(p, NextName("Btn"), "btn_reset_variant", 170, 22, function()
		BG.ResetVariant("recruit", UI.recSlot or 1)
		p.area.edit:Load()
		UI.UpdateCounter()
	end)
	reset:SetPoint("TOPLEFT", p, "TOPLEFT", 0, -316)
	local resetAll = MakeButton(p, NextName("Btn"), "btn_reset_all5", 150, 22, function()
		BG.ResetVariants("recruit")
		p.area.edit:Load()
		UI.UpdateCounter()
	end)
	resetAll:SetPoint("TOPLEFT", p, "TOPLEFT", 178, -316)
	local hint = Label(p, "rec_hint", 0, -346, "GameFontDisableSmall", 590)
	hint:SetHeight(70)
	hint:SetJustifyV("TOP")
	p.stats = Label(p, nil, 0, -420, "GameFontDisableSmall", 590)

	p.elapsed = 0
	p:SetScript("OnUpdate", function()
		this.elapsed = this.elapsed + arg1
		if this.elapsed < 0.5 then return end
		this.elapsed = 0
		UI.UpdateRecruitStatus()
	end)
	p.refresh = function() UI.UpdateRecruitStatus() UI.UpdateCounter() end
end

function UI.UpdateCounter()
	local p = panels.recruit
	if not p or not p.counter then return end
	local v = BG.db.variants.recruit
	local n = string.len(v and v[UI.recSlot or 1] or "")
	local col = (n > 255) and RED or GRAY
	p.counter:SetText(col .. n .. "/255|r")
	if p.slotBtns then
		for s = 1, BG.VARIANTS do UI.MarkSelected(p.slotBtns[s], s == (UI.recSlot or 1)) end
	end
end

function UI.SelectRecruitSlot(s)
	local p = panels.recruit
	if not p or not p.slotBtns then return end
	UI.recSlot = s
	p.area.edit:Load()
	UI.UpdateCounter()
end

function UI.UpdateRecruitStatus()
	local p = panels.recruit
	if not p or not p.status then return end
	local R = BG.Recruit
	if R.active then
		p.status:SetText(GREEN .. BG.T("rec_status_on", FormatLeft(R.nextPost - time())) .. "|r")
		p.toggle:SetText(BG.T("btn_stop_recruit"))
	else
		p.status:SetText(RED .. BG.T("rec_status_off") .. "|r")
		p.toggle:SetText(BG.T("btn_start_recruit"))
	end
	local name, info = R.OtherActive()
	if name then
		p.other:SetText(YELLOW .. BG.T("rec_other", name, BG.Stamp(info.started)) .. "|r")
	else
		local ch = (R.lastChannelText ~= "") and (" - " .. BG.T("rec_last_channel", R.lastChannelText)) or ""
		p.other:SetText(GRAY .. BG.T("rec_other_none") .. ch .. "|r")
	end
	p.stats:SetText(BG.T("rec_stats", BG.db.stats.posts, BG.db.stats.scans, BG.db.stats.invites, BG.db.stats.welcomes))
end

--------------------------------------------------------------------- panel: scanner

-- selected selector button: stays clickable, gold text + locked highlight (a greyed-out button looked "dead")
function UI.MarkSelected(b, on)
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

local KW_KEYS = { "kwGuildDE", "kwGuildEN", "kwSeekDE", "kwSeekEN", "kwExclude" }

local function BuildScanner(p)
	local db = BG.db
	Label(p, "scan_header", 0, -2, "GameFontNormal")
	MakeCheck("scanner", p, 0, -24, "feat_scanner",
		function() return db.features.scanner end,
		function(v) db.features.scanner = v end, "tip_scanner")

	p.langBtn = MakeButton(p, NextName("Btn"), "x", 170, 22, function()
		local order = { de = "en", en = "both", both = "de" }
		db.scanner.lang = order[db.scanner.lang] or "both"
		UI.UpdateScannerLang()
	end)
	p.langBtn:SetPoint("TOPLEFT", p, "TOPLEFT", 0, -56)
	Label(p, "scan_channels", 190, -60)
	MakeEdit("scanner", p, 300, -56, 70, function() return db.scanner.channels end, function(t) db.scanner.channels = t end, 20)
	Label(p, "scan_cooldown", 390, -60)
	MakeEdit("scanner", p, 520, -56, 40, function() return db.scanner.cooldown end, NumberSetter(db.scanner, "cooldown", 1), 4)

	p.kwBtns = {}
	for i = 1, table.getn(KW_KEYS) do
		local k = KW_KEYS[i] -- Lua 5.0: closures share the loop variable, so copy it into a local
		local b = MakeButton(p, NextName("Btn"), "kw_" .. k, 117, 22, function()
			UI.SelectKeyword(k)
		end)
		b:SetPoint("TOPLEFT", p, "TOPLEFT", (i - 1) * 119, -92)
		p.kwBtns[KW_KEYS[i]] = b
	end
	p.kwDesc = Label(p, nil, 0, -120, "GameFontDisableSmall", 590)
	p.kwDesc:SetHeight(28)
	p.kwDesc:SetJustifyV("TOP")
	p.area = MakeTextArea("scanner", p, 0, -152, 596, 170,
		function() return db.keywords[UI.kwSel or KW_KEYS[1]] end,
		function(v) db.keywords[UI.kwSel or KW_KEYS[1]] = v end, 3000)
	local reset = MakeButton(p, NextName("Btn"), "btn_default_text", 170, 22, function()
		db.keywords[UI.kwSel] = BG.KEYWORD_DEFAULTS[UI.kwSel]
		p.area.edit:Load()
	end)
	reset:SetPoint("TOPLEFT", p, "TOPLEFT", 0, -328)

	Label(p, "scan_test", 0, -364, "GameFontNormal")
	p.testBox = MakeEdit(nil, p, 0, -384, 440, function() return "" end, function() end, 255)
	local run = MakeButton(p, NextName("Btn"), "btn_check", 140, 22, function()
		local lang = BG.Recruit.Classify(p.testBox:GetText())
		if lang then
			p.testResult:SetText(GREEN .. BG.T("scan_hit", lang == "de" and "DE" or "EN") .. "|r")
		else
			p.testResult:SetText(RED .. BG.T("scan_nohit") .. "|r")
		end
	end)
	run:SetPoint("TOPLEFT", p, "TOPLEFT", 450, -383)
	p.testResult = Label(p, nil, 0, -410, "GameFontHighlight", 590)
	UI.kwSel = KW_KEYS[1]
	p.refresh = function() UI.UpdateScannerLang() UI.SelectKeyword(UI.kwSel) end
end

function UI.UpdateScannerLang()
	local p = panels.scanner
	if not p or not p.langBtn then return end
	local l = BG.db.scanner.lang
	local key = (l == "de") and "lang_de_only" or ((l == "en") and "lang_en_only" or "lang_both")
	p.langBtn:SetText(BG.T("scan_lang") .. ": " .. BG.T(key))
end

function UI.SelectKeyword(k)
	local p = panels.scanner
	if not p or not p.kwBtns then return end
	UI.kwSel = k
	for key, b in pairs(p.kwBtns) do
		UI.MarkSelected(b, key == k)
	end
	p.kwDesc:SetText(BG.T("kwdesc_" .. k))
	p.area.edit:Load()
end

--------------------------------------------------------------------- panel: texts

local TEXT_KEYS = { "welcome", "funny", "gz", "repliesDE", "repliesEN", "contactDE", "contactEN" }

-- the texts of the language that is NOT active are greyed out (they are still used automatically for
-- whispers in that language)
local function TextOff(kind)
	local suffix = string.sub(kind, -2)
	if suffix == "EN" and BG.Lang() == "de" then return true end
	if suffix == "DE" and BG.Lang() == "en" then return true end
	return false
end

local function BuildTexts(p)
	local db = BG.db
	Label(p, "texts_header", 0, -2, "GameFontNormal")
	Label(p, "lbl_discord", 0, -30)
	MakeEdit("texts", p, 130, -26, 320, function() return db.discord end, function(t) db.discord = t end, 120)
	Label(p, "lbl_guildtag", 0, -56)
	MakeEdit("texts", p, 130, -52, 200, function() return db.guildTag end, function(t) db.guildTag = t end, 60)

	-- row 1: greeting, funny, GZ; row 2: replies and contact messages (DE / EN)
	p.btns = {}
	for i = 1, table.getn(TEXT_KEYS) do
		local k = TEXT_KEYS[i] -- Lua 5.0: closures share the loop variable, so copy it into a local
		local b = MakeButton(p, NextName("Btn"), "txt_" .. k, 146, 22, function() UI.SelectText(k) end)
		local row, col = 0, i - 1
		if i > 3 then row, col = 1, i - 4 end
		b:SetPoint("TOPLEFT", p, "TOPLEFT", col * 150, -84 - row * 26)
		p.btns[k] = b
	end
	-- the 5 variants of the chosen kind
	Label(p, "lbl_variant", 0, -146, "GameFontNormalSmall", 70)
	p.slotBtns = {}
	for s = 1, BG.VARIANTS do
		local slot = s
		local b = BG.MakeButton(p, NextName("Btn"), 40, 22, tostring(s))
		b:SetPoint("TOPLEFT", p, "TOPLEFT", 74 + (s - 1) * 44, -141)
		b:SetScript("OnClick", function() UI.SelectSlot(slot) end)
		p.slotBtns[s] = b
	end
	p.desc = Label(p, nil, 0, -172, "GameFontDisableSmall", 590)
	p.desc:SetHeight(30)
	p.desc:SetJustifyV("TOP")
	p.area = MakeTextArea("texts", p, 0, -204, 596, 162,
		function()
			local v = db.variants[UI.textSel or TEXT_KEYS[1]]
			return v and v[UI.slotSel or 1] or ""
		end,
		function(v)
			local kind = UI.textSel or TEXT_KEYS[1]
			db.variants[kind] = db.variants[kind] or {}
			db.variants[kind][UI.slotSel or 1] = (string.gsub(v, "[\r\n]+", " "))
			UI.UpdateTextCounter()
		end, 255)
	local reset = MakeButton(p, NextName("Btn"), "btn_reset_variant", 170, 22, function()
		BG.ResetVariant(UI.textSel, UI.slotSel)
		p.area.edit:Load()
		UI.UpdateTextCounter()
	end)
	reset:SetPoint("TOPLEFT", p, "TOPLEFT", 0, -376)
	local resetAll = MakeButton(p, NextName("Btn"), "btn_reset_all5", 150, 22, function()
		BG.ResetVariants(UI.textSel)
		p.area.edit:Load()
		UI.UpdateTextCounter()
	end)
	resetAll:SetPoint("TOPLEFT", p, "TOPLEFT", 178, -376)
	local prev = MakeButton(p, NextName("Btn"), "btn_preview", 140, 22, function()
		local line, idx = BG.PickVariant(UI.textSel)
		if line then BG.Print(BG.T("preview_variant", idx) .. " " .. BG.Fill(line, { name = BG.me, level = 60 })) end
	end)
	prev:SetPoint("TOPLEFT", p, "TOPLEFT", 336, -376)
	p.counter = Label(p, nil, 400, -402, "GameFontDisableSmall", 190)
	p.counter:SetJustifyH("RIGHT")
	UI.textSel = TEXT_KEYS[1]
	UI.slotSel = 1
	p.refresh = function() UI.SelectText(UI.textSel) end
end

function UI.UpdateTextCounter()
	local p = panels.texts
	if not p or not p.counter then return end
	local v = BG.db.variants[UI.textSel]
	local n = string.len(BG.Fill(v and v[UI.slotSel or 1] or "", { name = "Playername", level = 60 }))
	local col = (n > 255) and RED or GRAY
	p.counter:SetText(col .. BG.T("longest_line", n) .. "|r")
end

-- highlight the chosen kind and variant, grey out the kinds of the other language
function UI.UpdateTextButtons()
	local p = panels.texts
	if not p or not p.btns then return end
	if TextOff(UI.textSel) then
		UI.textSel = TEXT_KEYS[1]
		UI.slotSel = 1
	end
	for key, b in pairs(p.btns) do
		UI.MarkSelected(b, key == UI.textSel)
		if TextOff(key) then b:Disable() end
	end
	for s = 1, BG.VARIANTS do
		UI.MarkSelected(p.slotBtns[s], s == UI.slotSel)
	end
end

function UI.SelectText(k)
	local p = panels.texts
	if not p or not p.btns or TextOff(k) then return end
	UI.textSel = k
	UI.slotSel = 1
	UI.UpdateTextButtons()
	p.desc:SetText(BG.T("txtdesc_" .. k))
	p.area.edit:Load()
	UI.UpdateTextCounter()
end

function UI.SelectSlot(s)
	local p = panels.texts
	if not p or not p.btns then return end
	UI.slotSel = s
	UI.UpdateTextButtons()
	p.area.edit:Load()
	UI.UpdateTextCounter()
end

--------------------------------------------------------------------- panel: members / twinks

local function BuildMembers(p)
	local db = BG.db
	Label(p, "members_header", 0, -2, "GameFontNormal")
	Label(p, "lbl_search", 0, -28)
	p.search = MakeEdit(nil, p, 60, -24, 150, function() return UI.memberFilter or "" end, function(t)
		UI.memberFilter = t
		UI.Refresh("members")
	end, 30)
	MakeCheck("members", p, 225, -24, "chk_unassigned",
		function() return UI.onlyUnassigned end,
		function(v) UI.onlyUnassigned = v UI.Refresh("members") end)
	local sync = MakeButton(p, NextName("Btn"), "btn_sync", 130, 22, function() BG.Roster.SyncAll() end)
	sync:SetPoint("TOPLEFT", p, "TOPLEFT", 466, -25)
	Tooltip(sync, "tip_sync")

	local hdr = { { 6, 120, "col_name" }, { 128, 28, "col_lvl" }, { 160, 76, "col_rank" }, { 240, 80, "col_role" } }
	for i = 1, table.getn(hdr) do
		Label(p, hdr[i][3], hdr[i][1], -54, "GameFontNormalSmall", hdr[i][2])
	end
	p.list = MakeList(p, 0, -68, 344, 19, 18,
		function(r)
			r.name = Cell(r, 4, 120)
			r.lvl = Cell(r, 126, 28)
			r.rank = Cell(r, 158, 76)
			r.role = Cell(r, 238, 80)
		end,
		function(r, item)
			local info = BG.roster[item.name]
			local col = (info and info.online) and GREEN or WHITE
			if not info then col = GRAY end
			if item.kind == "twink" then
				r.name:SetText("   " .. col .. item.name .. "|r")
			else
				r.name:SetText(col .. item.name .. "|r")
			end
			r.lvl:SetText(info and tostring(info.level) or "-")
			r.rank:SetText(info and (info.rank or "") or "")
			if item.kind == "twink" then
				r.role:SetText(GRAY .. BG.T("role_twink") .. "|r")
			elseif item.twinks > 0 then
				r.role:SetText(GOLD .. BG.T("role_main_n", item.twinks) .. "|r")
			elseif item.assigned then
				r.role:SetText(GOLD .. BG.T("role_main") .. "|r")
			else
				r.role:SetText(RED .. "?|r")
			end
			r.selected = (UI.selectedMember == item.name)
			r.bg:SetTexture(1, 0.82, 0, r.selected and 0.18 or 0)
		end,
		function(row, item)
			UI.selectedMember = item.name
			UI.LoadDetail()
			p.list.Draw()
		end)

	-- detail panel
	local d = CreateFrame("Frame", NextName("Detail"), p)
	d:SetWidth(246)
	d:SetHeight(378)
	d:SetPoint("TOPLEFT", p, "TOPLEFT", 350, -54)
	BG.Backdrop(d, false)
	p.detail = d
	d.title = d:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	d.title:SetPoint("TOPLEFT", d, "TOPLEFT", 12, -12)
	d.title:SetWidth(222)
	d.title:SetJustifyH("LEFT")
	d.info = d:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	d.info:SetPoint("TOPLEFT", d, "TOPLEFT", 12, -36)
	d.info:SetWidth(222)
	d.info:SetJustifyH("LEFT")
	d.twinks = d:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	d.twinks:SetPoint("TOPLEFT", d, "TOPLEFT", 12, -56)
	d.twinks:SetWidth(222)
	d.twinks:SetHeight(44)
	d.twinks:SetJustifyH("LEFT")
	d.twinks:SetJustifyV("TOP")

	Label(d, "lbl_main_of", 12, -108, "GameFontNormalSmall")
	d.mainEdit = MakeEdit(nil, d, 14, -122, 130, function() return "" end, function() end, 20)
	local assign = MakeButton(d, NextName("Btn"), "btn_assign", 84, 22, function()
		if UI.selectedMember then
			if not BG.Roster.SetMain(UI.selectedMember, d.mainEdit:GetText()) then BG.Print(BG.T("assign_fail")) end
			UI.LoadDetail()
		end
	end)
	assign:SetPoint("TOPLEFT", d, "TOPLEFT", 152, -121)
	local ismain = MakeButton(d, NextName("Btn"), "btn_is_main", 108, 22, function()
		if UI.selectedMember then BG.Roster.MarkMain(UI.selectedMember) UI.LoadDetail() end
	end)
	ismain:SetPoint("TOPLEFT", d, "TOPLEFT", 12, -148)
	local clear = MakeButton(d, NextName("Btn"), "btn_unassign", 116, 22, function()
		if UI.selectedMember then BG.Roster.Unassign(UI.selectedMember) UI.LoadDetail() end
	end)
	clear:SetPoint("TOPLEFT", d, "TOPLEFT", 122, -148)

	Label(d, "lbl_joined", 12, -184, "GameFontNormalSmall")
	d.joined = MakeEdit(nil, d, 14, -198, 110, function() return "" end, function() end, 12)
	Label(d, "lbl_invited_by", 130, -184, "GameFontNormalSmall")
	d.by = MakeEdit(nil, d, 132, -198, 100, function() return "" end, function() end, 20)
	Label(d, "lbl_note", 12, -226, "GameFontNormalSmall")
	d.note = MakeEdit(nil, d, 14, -240, 218, function() return "" end, function() end, 80)
	local save = MakeButton(d, NextName("Btn"), "btn_save_details", 110, 22, function()
		if UI.selectedMember then
			BG.Roster.SetDetails(UI.selectedMember, d.joined:GetText(), d.by:GetText(), d.note:GetText())
			BG.Print(BG.T("saved"))
		end
	end)
	save:SetPoint("TOPLEFT", d, "TOPLEFT", 12, -270)
	local hint = Label(d, "members_hint", 12, -304, "GameFontDisableSmall", 222)
	hint:SetHeight(66)
	hint:SetJustifyV("TOP")

	p.refresh = function()
		p.list.SetData(BG.Roster.Rows(UI.memberFilter, UI.onlyUnassigned))
		UI.LoadDetail()
	end
end

function UI.LoadDetail()
	local p = panels.members
	if not p or not p.detail then return end
	local d = p.detail
	local name = UI.selectedMember
	if not name then
		d.title:SetText(GRAY .. BG.T("select_member") .. "|r")
		d.info:SetText("")
		d.twinks:SetText("")
		return
	end
	local info = BG.roster[name]
	local c = BG.db.chars[name] or {}
	d.title:SetText(GOLD .. name .. "|r")
	if info then
		d.info:SetText(BG.T("detail_info", info.level, info.class or "?", info.rank or "?"))
	else
		d.info:SetText(GRAY .. BG.T("not_in_roster") .. "|r")
	end
	local root = BG.Roster.RootOf(name)
	if root ~= name then
		d.twinks:SetText(BG.T("detail_twink_of", root))
	else
		local tw = BG.Roster.Twinks(name)
		if table.getn(tw) > 0 then
			d.twinks:SetText(BG.T("detail_twinks", table.getn(tw), table.concat(tw, ", ")))
		else
			d.twinks:SetText(GRAY .. BG.T("detail_no_twinks") .. "|r")
		end
	end
	d.mainEdit.loading = true
	d.mainEdit:SetText(c.main or "")
	d.mainEdit.loading = false
	d.joined:SetText(c.joined or "")
	d.by:SetText(c.invitedBy or "")
	d.note:SetText(c.note or "")
end

--------------------------------------------------------------------- panel: log

local LOG_COLORS = {
	join = GREEN, leave = GRAY, kick = RED, promote = YELLOW, demote = "|cffffaa55", invite = "|cff66ccff",
	levelup = WHITE, level60 = GOLD, decline = GRAY, prospect = "|cff66ccff",
}

local function BuildLog(p)
	Label(p, "log_header", 0, -2, "GameFontNormal")
	p.list = MakeList(p, 0, -24, 596, 21, 18,
		function(r)
			r.t = Cell(r, 4, 100)
			r.txt = Cell(r, 108, 460)
		end,
		function(r, e)
			r.t:SetText(GRAY .. BG.Stamp(e.t) .. "|r")
			r.txt:SetText((LOG_COLORS[e.k] or WHITE) .. BG.LogText(e) .. "|r")
		end)
	local clear = MakeButton(p, NextName("Btn"), "btn_clear_log", 150, 22, function()
		BG.db.log = {}
		UI.Refresh("log")
	end)
	clear:SetPoint("TOPLEFT", p, "TOPLEFT", 0, -416)
	p.refresh = function()
		local rev = {}
		local src = BG.db.log
		for i = table.getn(src), 1, -1 do table.insert(rev, src[i]) end
		p.list.SetData(rev)
	end
end

--------------------------------------------------------------------- panel: settings

local FEATURES = {
	{ "levelup", "feat_levelup", "tip_levelup" },
	{ "level60", "feat_level60", "tip_level60" },
	{ "selfToast", "feat_selftoast", "tip_selftoast" },
	{ "recruit", "feat_recruit", "tip_recruit" },
	{ "whisperPopup", "feat_whisper", "tip_whisper" },
	{ "scanner", "feat_scanner", "tip_scanner" },
	{ "rightClickInvite", "feat_rightclick", "tip_rightclick" },
	{ "welcomePopup", "feat_welcomepopup", "tip_welcomepopup" },
	{ "autoWelcome", "feat_autowelcome", "tip_autowelcome" },
	{ "guildBroadcast", "feat_broadcast", "tip_broadcast" },
	{ "worldPing", "feat_worldping", "tip_worldping" },
	{ "minimap", "feat_minimap", "tip_minimap" },
	{ "sound", "feat_sound", "tip_sound" },
}

local QUIET_KINDS = { "levelup", "level60", "whisper", "scanner", "welcome", "conflict" }

-- page 2 of the settings: instance / raid mode
local function BuildQuietPage(root, q)
	local db = BG.db
	Label(q, "quiet_header", 0, -2, "GameFontNormal")
	local desc = Label(q, "quiet_desc", 0, -26, "GameFontHighlightSmall", 590)
	desc:SetHeight(58)
	desc:SetJustifyV("TOP")
	MakeCheck("settings", q, 0, -88, "quiet_enabled",
		function() return db.quiet.enabled end,
		function(v) db.quiet.enabled = v UI.UpdateQuiet() end, "tip_quiet_enabled")
	q.status = Label(q, nil, 4, -122, "GameFontNormal", 590)
	Label(q, "quiet_allow_header", 0, -152, "GameFontNormalSmall", 590)
	for idx = 1, table.getn(QUIET_KINDS) do
		local kind = QUIET_KINDS[idx] -- local per iteration (Lua 5.0 closures share the loop variable)
		local col = (idx - 1) - math.floor((idx - 1) / 2) * 2
		local row = math.floor((idx - 1) / 2)
		MakeCheck("settings", q, col * 300, -172 - row * 26, "quiet_allow_" .. kind,
			function() return db.quiet.allow[kind] end,
			function(v) db.quiet.allow[kind] = v end, "tip_quiet_allow")
	end
	MakeCheck("settings", q, 0, -262, "quiet_catchup",
		function() return db.quiet.catchup end, function(v) db.quiet.catchup = v end, "tip_quiet_catchup")
	MakeCheck("settings", q, 0, -288, "quiet_summary_chk",
		function() return db.quiet.summary end, function(v) db.quiet.summary = v end)
	q.elapsed = 0
	q:SetScript("OnUpdate", function()
		this.elapsed = this.elapsed + arg1
		if this.elapsed < 1 then return end
		this.elapsed = 0
		UI.UpdateQuiet()
	end)
	root.quietStatus = q.status
end

function UI.UpdateQuiet()
	local p = panels.settings
	if not p or not p.quietStatus then return end
	local q = BG.db.quiet
	if not q.enabled then
		p.quietStatus:SetText(GRAY .. BG.T("quiet_status_disabled") .. "|r")
	elseif BG.QuietActive() then
		p.quietStatus:SetText(YELLOW .. BG.T("quiet_status_on") .. "|r")
	else
		p.quietStatus:SetText(GREEN .. BG.T("quiet_status_off") .. "|r")
	end
end

function UI.SettingsPage(which)
	local root = panels.settings
	if not root or not root.pages then return end
	UI.settingsPage = which
	for k, f in pairs(root.pages) do
		if k == which then f:Show() else f:Hide() end
	end
	UI.MarkSelected(root.btnGeneral, which == "general")
	UI.MarkSelected(root.btnQuiet, which == "quiet")
	UI.UpdateQuiet()
end

local function BuildSettings(root)
	local db = BG.db
	local p = CreateFrame("Frame", NextName("SetGeneral"), root)
	p:SetAllPoints(root)
	local qp = CreateFrame("Frame", NextName("SetQuiet"), root)
	qp:SetAllPoints(root)
	root.pages = { general = p, quiet = qp }
	root.btnQuiet = MakeButton(root, NextName("Btn"), "btn_set_quiet", 130, 20, function() UI.SettingsPage("quiet") end)
	root.btnQuiet:SetPoint("TOPRIGHT", root, "TOPRIGHT", 0, 2)
	root.btnGeneral = MakeButton(root, NextName("Btn"), "btn_set_general", 100, 20, function() UI.SettingsPage("general") end)
	root.btnGeneral:SetPoint("RIGHT", root.btnQuiet, "LEFT", -4, 0)
	BuildQuietPage(root, qp)
	Label(p, "settings_header", 0, -2, "GameFontNormal", 330)
	for i = 1, table.getn(FEATURES) do
		local f = FEATURES[i]
		local col = (i - 1) - math.floor((i - 1) / 2) * 2
		local row = math.floor((i - 1) / 2)
		MakeCheck("settings", p, col * 300, -24 - row * 24, f[2],
			function() return db.features[f[1]] end,
			function(v)
				db.features[f[1]] = v
				if f[1] == "worldPing" then BG.Presence.Apply() end
				if f[1] == "minimap" then UI.UpdateMinimap() end
				if f[1] == "recruit" and not v then BG.Recruit.Stop() end
				if f[1] == "scanner" and UI.panelsBuilt and panels.scanner then UI.Refresh("scanner") end
			end, f[3])
	end
	local y = -24 - 7 * 24 - 4
	local warn = Label(p, "worldping_warn", 0, y, "GameFontDisableSmall", 590)
	warn:SetHeight(28)
	warn:SetJustifyV("TOP")

	-- GZ popup: every level, or only the chosen full tens (10, 20 ... 60)
	y = y - 34
	p.gzBtn = BG.MakeButton(p, NextName("Btn"), 270, 22, "")
	p.gzBtn:SetPoint("TOPLEFT", p, "TOPLEFT", 0, y)
	p.gzBtn:SetScript("OnClick", function()
		db.gz.mode = (db.gz.mode == "tens") and "all" or "tens"
		UI.UpdateGZ()
	end)
	Tooltip(p.gzBtn, "tip_gz_mode")
	p.gzChecks = {}
	for step = 1, 6 do
		local lvl = step * 10 -- own local per iteration: Lua 5.0 closures would otherwise share the loop variable
		local c = MakeCheck("settings", p, 280 + (step - 1) * 52, y + 1, "gz_lvl_" .. lvl,
			function() return db.gz.levels[lvl] end,
			function(v) db.gz.levels[lvl] = v end, "tip_gz_level")
		getglobal(c:GetName() .. "Text"):SetWidth(24)
		p.gzChecks[lvl] = c
	end
	y = y - 56
	Label(p, "lbl_whisper_window", 0, y - 4)
	MakeEdit("settings", p, 250, y, 40, function() return db.recruit.window end, NumberSetter(db.recruit, "window", 1), 4)
	y = y - 30
	MakeCheck("settings", p, 0, y, "chk_sync_accept",
		function() return db.sync.accept end, function(v) db.sync.accept = v end, "tip_sync_accept")
	Label(p, "lbl_trust_rank", 300, y - 4)
	MakeEdit("settings", p, 540, y, 40, function() return db.sync.trustRank end, NumberSetter(db.sync, "trustRank", 0), 2)
	y = y - 36
	local syncNow = MakeButton(p, NextName("Btn"), "btn_sync_now", 190, 24, function() BG.Roster.RequestSync(true) end)
	syncNow:SetPoint("TOPLEFT", p, "TOPLEFT", 0, y)
	Tooltip(syncNow, "tip_sync_now")
	p.syncStatus = Label(p, nil, 200, y - 6, "GameFontDisableSmall", 390)
	y = y - 40
	local rp = MakeButton(p, NextName("Btn"), "btn_reset_presence", 190, 22, function()
		db.presence = {}
		BG.Presence.Record(BG.me, BG.Presence.LocalAddons(), "self")
		UI.Refresh("addons")
		BG.Print(BG.T("done"))
	end)
	rp:SetPoint("TOPLEFT", p, "TOPLEFT", 0, y)
	local rt = MakeButton(p, NextName("Btn"), "btn_reset_texts", 220, 22, function()
		BG.ResetTexts()
		BG.ResetKeywords()
		UI.Refresh("all")
		BG.Print(BG.T("done"))
	end)
	rt:SetPoint("TOPLEFT", p, "TOPLEFT", 200, y)
	root.gzBtn = p.gzBtn
	root.gzChecks = p.gzChecks
	root.refresh = function()
		UI.UpdateGZ()
		local last = BG.db.sync.last
		if last then
			p.syncStatus:SetText(BG.T("sync_status", BG.Stamp(last), BG.db.sync.lastApplied or 0))
		else
			p.syncStatus:SetText(BG.T("sync_never"))
		end
		UI.SettingsPage(UI.settingsPage or "general")
	end
end

--------------------------------------------------------------------- panel: self test

local function BuildSelfTest(p)
	Label(p, "selftest_header", 0, -2, "GameFontNormal")
	p.summary = Label(p, nil, 0, -26, "GameFontNormalLarge", 590)
	p.area = MakeTextArea("selftest", p, 0, -56, 596, 330,
		function() return BG.SelfTest and BG.SelfTest.text or "" end,
		function() end, 6000)
	local run = MakeButton(p, NextName("Btn"), "btn_rerun", 170, 22, function() BG.SelfTest.Run() end)
	run:SetPoint("TOPLEFT", p, "TOPLEFT", 0, -394)
	local hint = Label(p, "selftest_hint", 180, -396, "GameFontDisableSmall", 410)
	p.refresh = function()
		p.summary:SetText(BG.SelfTest and BG.SelfTest.summary or "")
		p.area.edit:Load()
	end
end

--------------------------------------------------------------------- main frame

local BUILDERS = {
	addons = BuildAddons, recruit = BuildRecruit, scanner = BuildScanner, texts = BuildTexts,
	members = BuildMembers, log = BuildLog, settings = BuildSettings, selftest = BuildSelfTest,
}

function UI.UpdateGZ()
	local p = panels.settings
	if not p or not p.gzBtn then return end
	local tens = (BG.db.gz.mode == "tens")
	p.gzBtn:SetText(BG.T("gz_mode") .. ": " .. BG.T(tens and "gz_mode_tens" or "gz_mode_all"))
	for lvl, c in pairs(p.gzChecks) do
		if tens then c:Enable() else c:Disable() end
	end
end

function UI.Refresh(kind)
	if not main or not main:IsVisible() then return end
	if kind == "all" then
		for _, l in pairs(loaders) do for _, w in ipairs(l) do w:Load() end end
		if UI.current and panels[UI.current] and panels[UI.current].refresh then panels[UI.current].refresh() end
		return
	end
	if kind == UI.current then
		local p = panels[kind]
		if p and p.refresh then p.refresh() end
	end
end

function UI.Show(key)
	UI.Build()
	key = key or UI.current or "addons"
	for k, p in pairs(panels) do
		if k == key then p:Show() else p:Hide() end
	end
	UI.current = key
	for k, b in pairs(tabButtons) do
		if k == key then b:Disable() else b:Enable() end
	end
	main:Show()
	local l = loaders[key]
	if l then for _, w in ipairs(l) do w:Load() end end
	local p = panels[key]
	if p and p.refresh then p.refresh() end
end

function UI.Toggle()
	UI.Build()
	if main:IsVisible() then main:Hide() else UI.Show(UI.current) end
end

function UI.ApplyLocale()
	for i = 1, table.getn(locList) do
		local it = locList[i]
		if it.kind == "text" then it.w:SetText(BG.T(it.key)) end
	end
	if main then
		main.sub:SetText(BG.T("subtitle"))
		main.version:SetText(BG.T("version") .. " " .. BG.version)
		local deOn = (BG.db.lang == "de")
		main.btnDE.fs:SetTextColor(deOn and 1 or 0.5, deOn and 0.82 or 0.5, deOn and 0 or 0.5)
		main.btnEN.fs:SetTextColor(deOn and 0.5 or 1, deOn and 0.5 or 0.82, deOn and 0.5 or 0)
		UI.UpdateScannerLang()
		UI.UpdateGZ()
		UI.UpdateQuiet()
		UI.UpdateTextButtons()
		if UI.current then UI.Refresh("all") end
	end
	if BG.Alerts then BG.Alerts.RelabelToast() BG.Alerts.RelabelSplash() end
	if BG.Recruit then BG.Recruit.RelabelMenu() end
	if UI.support then UI.support.RelabelSupport() end
end

function UI.Build()
	if main then return end
	main = CreateFrame("Frame", "BananaGuildFrame", UIParent)
	main:SetWidth(780)
	main:SetHeight(560)
	main:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	main:SetFrameStrata("HIGH")
	main:SetMovable(true)
	main:EnableMouse(true)
	main:RegisterForDrag("LeftButton")
	main:SetScript("OnDragStart", function() this:StartMoving() end)
	main:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
	BG.Backdrop(main, true)
	table.insert(UISpecialFrames, "BananaGuildFrame")

	local logo = main:CreateTexture(nil, "ARTWORK")
	logo:SetTexture(BG.LOGO)
	logo:SetWidth(64)
	logo:SetHeight(64)
	logo:SetPoint("TOPLEFT", main, "TOPLEFT", 18, -12)
	local title = main:CreateFontString(nil, "OVERLAY")
	title:SetFont("Fonts\\FRIZQT__.TTF", 24, "OUTLINE")
	title:SetTextColor(1, 0.82, 0)
	title:SetPoint("TOPLEFT", main, "TOPLEFT", 90, -22)
	title:SetText("BananaGuild")
	main.sub = main:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	main.sub:SetPoint("TOPLEFT", main, "TOPLEFT", 92, -50)

	local close = CreateFrame("Button", "BananaGuildFrameClose", main, "UIPanelCloseButton")
	close:SetPoint("TOPRIGHT", main, "TOPRIGHT", -8, -8)

	-- support heart + language switch (top right) - same pattern as BananaCraft / BananaBank / BananaLootline
	local infoBtn = CreateFrame("Button", "BananaGuildSupportBtn", main)
	infoBtn:SetWidth(16)
	infoBtn:SetHeight(16)
	infoBtn:SetPoint("RIGHT", close, "LEFT", -2, 0)
	local infoTex = infoBtn:CreateTexture(nil, "ARTWORK")
	infoTex:SetAllPoints(infoBtn)
	infoTex:SetTexture("Interface\\common\\friendship-heart")
	if not infoTex:GetTexture() then infoTex:SetTexture("Interface\\Icons\\INV_ValentinesCard01") end
	infoTex:SetVertexColor(1, 0.75, 0.3)
	infoBtn.tex = infoTex
	infoBtn:SetScript("OnEnter", function()
		this.tex:SetVertexColor(1, 1, 1)
		GameTooltip:SetOwner(this, "ANCHOR_LEFT")
		GameTooltip:SetText(BG.T("about_tooltip"))
		GameTooltip:Show()
	end)
	infoBtn:SetScript("OnLeave", function()
		this.tex:SetVertexColor(1, 0.75, 0.3)
		GameTooltip:Hide()
	end)
	infoBtn:SetScript("OnClick", function() UI.ToggleSupport() end)
	main.infoBtn = infoBtn

	local function LangButton(code, label, anchorTo, xoff)
		local lb = CreateFrame("Button", "BananaGuildLang" .. string.upper(code), main)
		lb:SetWidth(22)
		lb:SetHeight(16)
		lb:SetPoint("RIGHT", anchorTo, "LEFT", xoff, 0)
		local fs = lb:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		fs:SetAllPoints(lb)
		fs:SetText(label)
		lb.fs = fs
		lb:SetScript("OnEnter", function()
			GameTooltip:SetOwner(this, "ANCHOR_LEFT")
			GameTooltip:SetText(BG.T("lang_tooltip"))
			GameTooltip:Show()
		end)
		lb:SetScript("OnLeave", function() GameTooltip:Hide() end)
		lb:SetScript("OnClick", function() BG.SetLang(code) end)
		return lb
	end
	main.btnDE = LangButton("de", "DE", infoBtn, -4)
	main.btnEN = LangButton("en", "EN", main.btnDE, -2)

	-- tabs
	for i = 1, table.getn(TABS) do
		local key = TABS[i]
		local b = MakeButton(main, "BananaGuildTab" .. key, "tab_" .. key, 134, 28, function() UI.Show(key) end)
		b:SetPoint("TOPLEFT", main, "TOPLEFT", 20, -84 - (i - 1) * 32)
		tabButtons[key] = b
	end

	-- panels
	for key, builder in pairs(BUILDERS) do
		local p = CreateFrame("Frame", "BananaGuildPanel" .. key, main)
		p:SetWidth(596)
		p:SetHeight(440)
		p:SetPoint("TOPLEFT", main, "TOPLEFT", 168, -84)
		p:Hide()
		panels[key] = p
		local ok, err = pcall(builder, p)
		if not ok then BG.Fail("UI " .. key, err) end
	end
	UI.panelsBuilt = true

	-- footer
	main.version = main:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	main.version:SetPoint("BOTTOMRIGHT", main, "BOTTOMRIGHT", -24, 20)
	local st = MakeButton(main, "BananaGuildSelfTestBtn", "btn_selftest", 110, 22, function()
		UI.Show("selftest")
		BG.SelfTest.Run()
	end)
	st:SetPoint("RIGHT", main.version, "LEFT", -10, 0)
	Tooltip(st, "tip_selftest")
	local credit = main:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	credit:SetPoint("BOTTOMLEFT", main, "BOTTOMLEFT", 24, 22)
	credit:SetText("BananaForge")

	-- every time the window opens: quietly bring the shared data up to date (throttled in Roster.AutoSync)
	main:SetScript("OnShow", function() BG.Roster.AutoSync() end)
	main:Hide()
	UI.ApplyLocale()
end

--------------------------------------------------------------------- support / thank-you window
-- Same window as in the other Banana addons: character name to copy + one click to fill the mail recipient.

local function UpdateSupportHint()
	local tf = UI.support
	if not tf then return end
	if MailFrame and MailFrame:IsVisible() then
		tf.hint:SetText(BG.T("mailbox_open"))
		tf.mailBtn:Enable()
	else
		tf.hint:SetText(BG.T("mailbox_closed"))
		tf.mailBtn:Disable()
	end
end

function UI.ToggleSupport()
	local tf = UI.support
	if not tf then
		tf = CreateFrame("Frame", "BananaGuildSupport", UIParent)
		tf:SetWidth(340)
		tf:SetHeight(275)
		tf:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
		BG.Backdrop(tf, true)
		tf:SetMovable(true)
		tf:EnableMouse(true)
		tf:RegisterForDrag("LeftButton")
		tf:SetScript("OnDragStart", function() this:StartMoving() end)
		tf:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
		tf:SetFrameStrata("DIALOG")
		table.insert(UISpecialFrames, "BananaGuildSupport")

		local tt = tf:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
		tt:SetPoint("TOP", tf, "TOP", 0, -18)
		Reg(tt, "support_title")

		local tclose = CreateFrame("Button", nil, tf, "UIPanelCloseButton")
		tclose:SetPoint("TOPRIGHT", tf, "TOPRIGHT", -6, -6)

		local body = tf:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		body:SetPoint("TOPLEFT", tf, "TOPLEFT", 24, -52)
		body:SetWidth(292)
		body:SetJustifyH("LEFT")
		body:SetJustifyV("TOP")
		Reg(body, "support_text")

		local nameLabel = tf:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		nameLabel:SetPoint("TOPLEFT", tf, "TOPLEFT", 24, -158)
		Reg(nameLabel, "lbl_character")

		-- selectable box so the name can be copied with Ctrl+C
		local nameBox = CreateFrame("EditBox", nil, tf, "InputBoxTemplate")
		nameBox:SetWidth(150)
		nameBox:SetHeight(20)
		nameBox:SetPoint("LEFT", nameLabel, "RIGHT", 12, 0)
		nameBox:SetAutoFocus(false)
		nameBox:SetText(BG.AUTHOR_CHAR)
		nameBox:SetScript("OnTextChanged", function()
			if this:GetText() ~= BG.AUTHOR_CHAR then this:SetText(BG.AUTHOR_CHAR) end
		end)
		nameBox:SetScript("OnEscapePressed", function() this:ClearFocus() end)
		nameBox:SetScript("OnEnterPressed", function() this:ClearFocus() end)
		tf.nameBox = nameBox

		local hint = tf:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
		hint:SetPoint("TOPLEFT", tf, "TOPLEFT", 24, -184)
		hint:SetWidth(292)
		hint:SetJustifyH("LEFT")
		tf.hint = hint

		local mailBtn = CreateFrame("Button", nil, tf, "UIPanelButtonTemplate")
		mailBtn:SetWidth(150)
		mailBtn:SetHeight(24)
		mailBtn:SetPoint("BOTTOMLEFT", tf, "BOTTOMLEFT", 24, 22)
		Reg(mailBtn, "btn_fill_name")
		mailBtn:SetScript("OnClick", function()
			if MailFrame and MailFrame:IsVisible() and SendMailNameEditBox then
				if MailFrameTab2 and MailFrameTab_OnClick then MailFrameTab_OnClick(2) end
				SendMailNameEditBox:SetText(BG.AUTHOR_CHAR)
				if SendMailSubjectEditBox and SendMailSubjectEditBox:GetText() == "" then
					SendMailSubjectEditBox:SetText("BananaGuild")
				end
				BG.Print(BG.T("recipient_set", BG.AUTHOR_CHAR))
				tf:Hide()
			else
				BG.Print(BG.T("need_mailbox"))
			end
		end)
		tf.mailBtn = mailBtn

		local okBtn = CreateFrame("Button", nil, tf, "UIPanelButtonTemplate")
		okBtn:SetWidth(110)
		okBtn:SetHeight(24)
		okBtn:SetPoint("BOTTOMRIGHT", tf, "BOTTOMRIGHT", -24, 22)
		Reg(okBtn, "btn_close")
		okBtn:SetScript("OnClick", function() tf:Hide() end)

		tf:SetScript("OnShow", UpdateSupportHint)
		UI.support = tf
		tf.RelabelSupport = UpdateSupportHint
	end
	if tf:IsShown() then tf:Hide() else tf:Show() end
	UpdateSupportHint()
end

--------------------------------------------------------------------- minimap button

local mm

local function PlaceMinimap()
	if not mm then return end
	local a = math.rad(BG.db.minimap.angle or 200)
	mm:ClearAllPoints()
	mm:SetPoint("TOPLEFT", Minimap, "TOPLEFT", 52 - (80 * math.cos(a)), (80 * math.sin(a)) - 52)
end

function UI.UpdateMinimap()
	if not mm then return end
	if BG.db.features.minimap then mm:Show() else mm:Hide() end
end

local function BuildMinimap()
	mm = CreateFrame("Button", "BananaGuildMinimapButton", Minimap)
	mm:SetWidth(32)
	mm:SetHeight(32)
	mm:SetFrameStrata("MEDIUM")
	mm:SetFrameLevel(8)
	mm:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	mm:RegisterForDrag("LeftButton")
	local icon = mm:CreateTexture(nil, "BACKGROUND")
	icon:SetTexture(BG.LOGO)
	icon:SetWidth(22)
	icon:SetHeight(22)
	icon:SetPoint("CENTER", mm, "CENTER", 0, 0)
	local border = mm:CreateTexture(nil, "OVERLAY")
	border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
	border:SetWidth(54)
	border:SetHeight(54)
	border:SetPoint("TOPLEFT", mm, "TOPLEFT", 0, 0)
	mm:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
	mm:SetScript("OnClick", function()
		if arg1 == "RightButton" then
			if BG.Recruit.active then BG.Recruit.Stop() else UI.Show("recruit") end
		else
			UI.Toggle()
		end
	end)
	mm:SetScript("OnDragStart", function()
		this:SetScript("OnUpdate", function()
			local xpos, ypos = GetCursorPosition()
			local xmin, ymin = Minimap:GetLeft(), Minimap:GetBottom()
			xpos = xmin - xpos / UIParent:GetScale() + 70
			ypos = ypos / UIParent:GetScale() - ymin - 70
			BG.db.minimap.angle = math.deg(math.atan2(ypos, xpos))
			PlaceMinimap()
		end)
	end)
	mm:SetScript("OnDragStop", function() this:SetScript("OnUpdate", nil) end)
	mm:SetScript("OnEnter", function()
		GameTooltip:SetOwner(this, "ANCHOR_LEFT")
		GameTooltip:SetText("BananaGuild " .. BG.version, 1, 0.82, 0)
		GameTooltip:AddLine(BG.T("mm_left"), 1, 1, 1)
		GameTooltip:AddLine(BG.T("mm_right"), 1, 1, 1)
		GameTooltip:Show()
	end)
	mm:SetScript("OnLeave", function() GameTooltip:Hide() end)
	PlaceMinimap()
	UI.UpdateMinimap()
end

BG.OnLogin(function()
	BuildMinimap()
	BG.Print(BG.T("loaded", BG.version))
	if string.find(BG.db.discord or "", "DEIN-LINK", 1, true) then BG.Print(BG.T("discord_hint")) end
end)

BananaGuild = BananaGuild or {}
BananaGuild.files = BananaGuild.files or {}
BananaGuild.files.UI = true
