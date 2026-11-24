--[[
  BananaGuild - Stand ("Unser Stand")
  What the guild tells in its recruiting texts: the raids it has cleared, the days it raids on (optional time of day) and
  three statements it may use (community first, raiding is voluntary, own self-written addons). Officers edit it in a small
  window (button on the Gildensuche tab), the state is synced between the officers (message "ST", newest wins).

  Texts of the kinds standAll / standHeal / standTank / standDps / standClass / standMix use it:
    {raids}      "Kara 10, ZG und MC"       (cleared raids; more than 4: "Kara 10, ZG, MC und 2 weitere")
    {raidsdran}  "ZG"                       (raids in progress, at most two)
    {liegt}      "liegt" / "liegen"         (verb for {raids}: "{raids} {liegt} hinter uns")
    {ist}        "ist" / "sind"             ("{raids} {ist} geschafft")
    {raidtag}    "Donnerstag" / "Dienstag und Donnerstag"          (4 or more days: "mehrmals pro Woche")
    {raidtags}   "donnerstags ab 20 Uhr"    (adverb, with the optional time)
    {raidzeit}   "ab 20 Uhr" or nothing
  and three markers that print nothing: {community} {freiwillig} {addons}. A text that contains a marker is only used when the
  statement is ticked, a text with {raids} / {raidtag(s)} only when a raid / a day is ticked.
]]

local BG = BananaGuild
local Stand = {}
BG.Stand = Stand

-- key, long name, short name (in the order of the window)
Stand.RAIDS = {
	{ "kara10", "Kara 10", "Kara 10" }, { "zg", "ZG", "ZG" }, { "mc", "MC", "MC" },
	{ "ony", "Onyxia", "Ony" }, { "bwl", "BWL", "BWL" }, { "es", "Emerald Sanctum", "ES" },
	{ "aq20", "AQ20", "AQ20" }, { "aq40", "AQ40", "AQ40" }, { "kara40", "Kara 40", "Kara 40" },
}
-- Monday = 1 ... Sunday = 7: noun, adverb, short
Stand.DAYS = {
	{ "Montag", "montags", "Mo" }, { "Dienstag", "dienstags", "Di" }, { "Mittwoch", "mittwochs", "Mi" },
	{ "Donnerstag", "donnerstags", "Do" }, { "Freitag", "freitags", "Fr" }, { "Samstag", "samstags", "Sa" },
	{ "Sonntag", "sonntags", "So" },
}
Stand.CLAIMS = { "community", "freiwillig", "addons" }

local function Data()
	local s = BG.db.stand
	if not s then s = { raids = {}, trying = {}, days = {}, claims = {}, time = "", ts = 0, by = "" } BG.db.stand = s end
	s.raids, s.trying, s.days, s.claims = s.raids or {}, s.trying or {}, s.days or {}, s.claims or {}
	return s
end
Stand.Data = Data

--------------------------------------------------------------------- texts

local function JoinList(list, word)
	local n = table.getn(list)
	if n == 0 then return "" end
	if n == 1 then return list[1] end
	return table.concat(list, ", ", 1, n - 1) .. " " .. word .. " " .. list[n]
end

function Stand.PickedRaids()
	local out, s = {}, Data()
	for i = 1, table.getn(Stand.RAIDS) do
		if s.raids[Stand.RAIDS[i][1]] then table.insert(out, i) end
	end
	return out
end

-- raids in progress (red tick)
function Stand.PickedTrying()
	local out, s = {}, Data()
	for i = 1, table.getn(Stand.RAIDS) do
		if s.trying[Stand.RAIDS[i][1]] then table.insert(out, i) end
	end
	return out
end

function Stand.PickedDays()
	local out, s = {}, Data()
	for i = 1, 7 do if s.days[i] then table.insert(out, i) end end
	return out
end

function Stand.RaidText(short, trying)
	local picked = trying and Stand.PickedTrying() or Stand.PickedRaids()
	local names = {}
	for i = 1, table.getn(picked) do
		local r = Stand.RAIDS[picked[i]]
		table.insert(names, short and r[3] or r[2])
	end
	local n = table.getn(names)
	if trying then
		-- in progress: at most two are named
		if n > 2 then return JoinList({ names[1], names[2] }, "und") end
		return JoinList(names, "und")
	end
	if n > 4 then
		return table.concat(names, ", ", 1, 3) .. " " .. string.format(BG.T("stand_more"), n - 3)
	end
	return JoinList(names, "und")
end

-- "20" -> "20 Uhr", "20:30" -> "20:30 Uhr", anything else -> ""
function Stand.TimeText()
	local raw = BG.Trim(Data().time or "")
	local _, _, h, m = string.find(raw, "^(%d%d?)[:%.]?(%d?%d?)$")
	h = tonumber(h)
	if not h or h > 23 then return "" end
	local mm = tonumber(m)
	if mm and mm > 59 then return "" end
	if m == "" or mm == nil or mm == 0 then return h .. " Uhr" end
	return string.format("%d:%02d Uhr", h, mm)
end

function Stand.DayTexts()
	local picked = Stand.PickedDays()
	local n = table.getn(picked)
	if n == 0 then return "", "" end
	if n >= 4 then return BG.T("stand_weekly"), BG.T("stand_weekly") end
	local noun, adv = {}, {}
	for i = 1, n do
		table.insert(noun, Stand.DAYS[picked[i]][1])
		table.insert(adv, Stand.DAYS[picked[i]][2])
	end
	return JoinList(noun, "und"), JoinList(adv, "und")
end

-- values of the placeholders; short = short raid names
function Stand.Vars(short)
	local noun, adv = Stand.DayTexts()
	local t = Stand.TimeText()
	local nDone = table.getn(Stand.PickedRaids())
	local vars = { raids = Stand.RaidText(short), raidsdran = Stand.RaidText(short, true), raidtag = noun, raidtags = adv, raidzeit = "",
		liegt = (nDone > 1) and "liegen" or "liegt", ist = (nDone > 1) and "sind" or "ist",
		community = "", freiwillig = "", addons = "" }
	if t ~= "" then
		vars.raidzeit = "ab " .. t
		if adv ~= "" then vars.raidtags = adv .. " ab " .. t end
		if noun ~= "" then vars.raidtag = noun .. " ab " .. t end   -- "Raidabend ist bei uns Donnerstag ab 20 Uhr"
	end
	return vars
end

-- anything ticked at all: the stand texts come into play
function Stand.Active()
	local s = Data()
	for _ in pairs(s.raids) do return true end
	for _ in pairs(s.trying) do return true end
	for _ in pairs(s.days) do return true end
	for _ in pairs(s.claims) do return true end
	return false
end

-- which text kind fits the wanted classes / roles
function Stand.Kind()
	local w = BG.db.wanted
	local R = BG.Recruit
	local classes, roles = 0, {}
	for i = 1, table.getn(R.CLASS_ORDER) do if w.classes[R.CLASS_ORDER[i]] then classes = classes + 1 end end
	for i = 1, table.getn(R.ROLE_ORDER) do if w.roles[R.ROLE_ORDER[i]] then table.insert(roles, R.ROLE_ORDER[i]) end end
	local nr = table.getn(roles)
	if classes == table.getn(R.CLASS_ORDER) or nr == table.getn(R.ROLE_ORDER) or (classes == 0 and nr == 0) then return "standAll" end
	if nr == 0 then return "standClass" end
	if classes == 0 and nr == 1 then
		if roles[1] == "T" then return "standTank" end
		if roles[1] == "H" then return "standHeal" end
		return "standDps"
	end
	return "standMix"
end

local function Has(t, ph) return string.find(t, ph, 1, true) ~= nil end

-- a text may only be used when everything it mentions is ticked
function Stand.Eligible(text)
	local s = Data()
	if Has(text, "{community}") and not s.claims.community then return false end
	if Has(text, "{freiwillig}") and not s.claims.freiwillig then return false end
	if Has(text, "{addons}") and not s.claims.addons then return false end
	if (Has(text, "{raids}") or Has(text, "{liegt}") or Has(text, "{ist}")) and table.getn(Stand.PickedRaids()) == 0 then return false end
	if Has(text, "{raidsdran}") and table.getn(Stand.PickedTrying()) == 0 then return false end
	if (Has(text, "{raidtag}") or Has(text, "{raidtags}")) and table.getn(Stand.PickedDays()) == 0 then return false end
	return true
end

-- short sentences that name the raid day (and time); used when a ticked day would otherwise not appear in the text
Stand.DAY_SENTENCES = { "Raidtag: {raidtag}.", "Wir raiden {raidtags}.", "Geraidet wird {raidtags}.", "Unser Raidabend: {raidtag}." }

-- the text with a day sentence in front of its last sentence (the call to action), or the text itself
function Stand.WithDay(line)
	if table.getn(Stand.PickedDays()) == 0 then return line end
	if Has(line, "{raidtag}") or Has(line, "{raidtags}") or Has(line, "{raidzeit}") then return line end
	-- the markers at the end ({community} ...) stay at the end
	local core, tail = line, ""
	while true do
		local _, _, rest, tag = string.find(core, "^(.*) ({%a+})$")
		if rest and (tag == "{community}" or tag == "{freiwillig}" or tag == "{addons}") then
			core, tail = rest, " " .. tag .. tail
		else
			break
		end
	end
	-- position of the last sentence: after the last ". " / "! " / "? "
	local pos, init = nil, 1
	while true do
		local _, e = string.find(core, "[%.!%?] ", init)
		if not e then break end
		pos, init = e, e + 1
	end
	if not pos then return line end
	local sentence = Stand.DAY_SENTENCES[math.random(1, table.getn(Stand.DAY_SENTENCES))]
	return string.sub(core, 1, pos) .. sentence .. " " .. string.sub(core, pos + 1) .. tail
end

local function Clean(msg)
	msg = string.gsub(msg, "%s+", " ")
	msg = string.gsub(msg, " ([%.,!%?])", "%1")
	return BG.Trim(msg)
end

-- a chat message from the stand texts, nil when nothing is ticked or no text fits
function Stand.PostText()
	if not Stand.Active() then return nil end
	local kind = Stand.Kind()
	local base = BG.Recruit.WantedVars()
	for attempt = 1, 8 do
		local line = BG.PickVariant(kind, Stand.Eligible)
		if not line then return nil end
		local withDay = Stand.WithDay(line)
		for pass = 1, 3 do
			local vars = Stand.Vars(pass >= 2)
			for k, v in pairs(base) do vars[k] = v end
			if pass == 3 then vars.klassen, vars.klassen_oder = BG.T("wanted_many"), BG.T("wanted_many") end
			local msg = Clean(BG.Fill(withDay, vars))
			if string.len(msg) > 255 and withDay ~= line then msg = Clean(BG.Fill(line, vars)) end
			if string.len(msg) <= 255 then return msg end
		end
	end
	return nil
end

--------------------------------------------------------------------- changing and syncing

local function Bits(list, n, key)
	local out = {}
	for i = 1, n do out[i] = key(i) and "1" or "0" end
	return table.concat(out)
end

local function Encode()
	local s = Data()
	-- one digit per raid: 0 = nothing, 1 = cleared, 2 = in progress (old versions read only the 1s)
	local rt = {}
	for i = 1, table.getn(Stand.RAIDS) do
		local key = Stand.RAIDS[i][1]
		rt[i] = s.raids[key] and "1" or (s.trying[key] and "2" or "0")
	end
	local raids = table.concat(rt)
	local days = Bits(nil, 7, function(i) return s.days[i] end)
	local claims = Bits(nil, table.getn(Stand.CLAIMS), function(i) return s.claims[Stand.CLAIMS[i]] end)
	local t = string.gsub(s.time or "", "[^%d:%.]", "")
	if t == "" then t = "_" end
	return raids, days, claims, t, tostring(s.ts or 0)
end

function Stand.Broadcast()
	local a, b, c, d, e = Encode()
	BG.Send("ST", a, b, c, d, e)
end

function Stand.CanEdit()
	return BG.Recruit and BG.Recruit.CanEditWanted and BG.Recruit.CanEditWanted() or false
end

local function Touched()
	local s = Data()
	s.ts = time()
	s.by = BG.me
	Stand.Broadcast()
	if BG.UI and BG.UI.Refresh then BG.UI.Refresh("recruit") end
	if Stand.Update then Stand.Update() end
end

-- group = "raids" | "days" | "claims"
function Stand.Set(group, key, on)
	if not Stand.CanEdit() then return false end
	Data()[group][key] = on and true or nil
	Touched()
	return true
end

-- state of one raid: nil = nothing, "done" = cleared (gold tick), "try" = in progress (red tick)
function Stand.SetRaid(key, state)
	if not Stand.CanEdit() then return false end
	local s = Data()
	s.raids[key] = (state == "done") and true or nil
	s.trying[key] = (state == "try") and true or nil
	Touched()
	return true
end

function Stand.RaidState(key)
	local s = Data()
	if s.raids[key] then return "done" end
	if s.trying[key] then return "try" end
	return nil
end

function Stand.SetTime(text)
	if not Stand.CanEdit() then return false end
	local t = string.gsub(text or "", "[^%d:%.]", "")
	if t == (Data().time or "") then return true end
	Data().time = t
	Touched()
	return true
end

BG.OnComm("ST", function(sender, p)
	if not BG.Recruit or not BG.Recruit.OfficerRank or not BG.Recruit.OfficerRank(sender) or not BG.db.sync.accept then return end
	local rm, dm, cm, tm, ts = p[1], p[2], p[3], p[4], tonumber(p[5]) or 0
	if not rm or string.len(rm) ~= table.getn(Stand.RAIDS) or string.len(dm or "") ~= 7 or string.len(cm or "") ~= table.getn(Stand.CLAIMS) then return end
	local s = Data()
	if ts <= (s.ts or 0) then return end
	s.raids, s.trying, s.days, s.claims = {}, {}, {}, {}
	for i = 1, table.getn(Stand.RAIDS) do
		local c = string.sub(rm, i, i)
		if c == "1" then s.raids[Stand.RAIDS[i][1]] = true elseif c == "2" then s.trying[Stand.RAIDS[i][1]] = true end
	end
	for i = 1, 7 do if string.sub(dm, i, i) == "1" then s.days[i] = true end end
	for i = 1, table.getn(Stand.CLAIMS) do if string.sub(cm, i, i) == "1" then s.claims[Stand.CLAIMS[i]] = true end end
	s.time = (tm and tm ~= "_") and string.gsub(tm, "[^%d:%.]", "") or ""
	s.ts, s.by = ts, sender
	if BG.UI and BG.UI.Refresh then BG.UI.Refresh("recruit") end
	if Stand.Update then Stand.Update() end
end)

-- a client that just logged in asks; an officer answers after a random pause (newest ts wins anyway)
BG.OnComm("STQ", function(sender)
	if not Stand.CanEdit() or (Data().ts or 0) == 0 then return end
	BG.After(1 + math.random() * 5, function() Stand.Broadcast() end)
end)

BG.OnLogin(function()
	BG.After(50, function() BG.Send("STQ") end)
end)

--------------------------------------------------------------------- window

local W, H = 560, 476
local win
local counter = 0

local function Name(prefix)
	counter = counter + 1
	return "BananaGuildStand" .. prefix .. counter
end

local function Text(parent, x, y, font, width)
	local fs = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlightSmall")
	fs:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
	fs:SetJustifyH("LEFT")
	if width then fs:SetWidth(width) end
	return fs
end

local function Check(parent, x, y, labelW, onClick)
	local nm = Name("Check")
	local c = CreateFrame("CheckButton", nm, parent, "UICheckButtonTemplate")
	c:SetWidth(24)
	c:SetHeight(24)
	c:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
	c.label = getglobal(nm .. "Text")
	c.label:SetJustifyH("LEFT")
	c.label:SetWidth(labelW)
	c:SetScript("OnClick", function()
		local on = this:GetChecked() and true or false
		if not onClick(on) then
			this:SetChecked(on and nil or 1)   -- not allowed: back to the old state
			BG.Print(BG.T("stand_noright"))
		end
	end)
	return c
end

local function Build()
	win = CreateFrame("Frame", "BananaGuildStandWin", UIParent)
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

	win.title = Text(win, 16, -14, "GameFontNormalLarge", W - 60)
	win.sub = Text(win, 16, -38, "GameFontHighlightSmall", W - 32)
	win.sub:SetHeight(28)
	win.sub:SetJustifyV("TOP")

	-- raids: 3 columns. Left click = cleared (gold tick), right click = in progress (red tick), again = off
	win.raidLbl = Text(win, 16, -76, "GameFontNormal", 400)
	win.raidChecks = {}
	for i = 1, table.getn(Stand.RAIDS) do
		local key = Stand.RAIDS[i][1] -- local per iteration (Lua 5.0 closures share the loop variable)
		local row = math.floor((i - 1) / 3)
		local col = (i - 1) - row * 3
		local c = Check(win, 12 + col * 178, -94 - row * 24, 140, function() return true end)
		c:RegisterForClicks("LeftButtonUp", "RightButtonUp")
		c:SetScript("OnClick", function()
			local want = (arg1 == "RightButton") and "try" or "done"
			local cur = Stand.RaidState(key)
			local state = want
			if cur == want then state = nil end   -- same click again: tick off (not "(a and nil) or b": that is always b)
			if not Stand.SetRaid(key, state) then
				BG.Print(BG.T("stand_noright"))
			end
			Stand.Update()
		end)
		c:SetScript("OnEnter", function()
			GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
			GameTooltip:SetText(BG.T("stand_raid_tip"), 1, 1, 1, 1, 1)
			GameTooltip:Show()
		end)
		c:SetScript("OnLeave", function() GameTooltip:Hide() end)
		c.label:SetText(Stand.RAIDS[i][2])
		c.key = key
		table.insert(win.raidChecks, c)
	end
	win.legend = Text(win, 16, -170, "GameFontHighlightSmall", W - 32)

	-- days: one row
	win.dayLbl = Text(win, 16, -194, "GameFontNormal", 300)
	win.dayChecks = {}
	for i = 1, 7 do
		local idx = i
		local c = Check(win, 12 + (i - 1) * 76, -212, 56, function(on) return Stand.Set("days", idx, on) end)
		c.label:SetText(Stand.DAYS[i][3])
		c.idx = idx
		table.insert(win.dayChecks, c)
	end
	win.timeLbl = Text(win, 16, -246, "GameFontHighlightSmall", 190)
	win.timeEdit = CreateFrame("EditBox", Name("Edit"), win, "InputBoxTemplate")
	win.timeEdit:SetWidth(56)
	win.timeEdit:SetHeight(20)
	win.timeEdit:SetPoint("TOPLEFT", win, "TOPLEFT", 204, -242)
	win.timeEdit:SetAutoFocus(false)
	win.timeEdit:SetMaxLetters(5)
	win.timeEdit:SetScript("OnEnterPressed", function() this:ClearFocus() end)
	win.timeEdit:SetScript("OnEscapePressed", function() this:ClearFocus() Stand.Update() end)
	win.timeEdit:SetScript("OnEditFocusLost", function()
		if win.loading then return end
		if not Stand.SetTime(this:GetText()) then BG.Print(BG.T("stand_noright")) Stand.Update() end
	end)
	win.timeHint = Text(win, 270, -248, "GameFontDisableSmall", 270)

	-- statements
	win.claimLbl = Text(win, 16, -280, "GameFontNormal", 400)
	win.claimChecks = {}
	for i = 1, table.getn(Stand.CLAIMS) do
		local key = Stand.CLAIMS[i]
		local c = Check(win, 12, -298 - (i - 1) * 24, 500, function(on) return Stand.Set("claims", key, on) end)
		c.key = key
		table.insert(win.claimChecks, c)
	end

	-- preview
	win.prevLbl = Text(win, 16, -380, "GameFontNormal", 300)
	win.prev = Text(win, 16, -398, "GameFontHighlightSmall", W - 32)
	win.prev:SetHeight(40)
	win.prev:SetJustifyV("TOP")
	win.other = BG.MakeButton(win, Name("Btn"), 170, 22, "")
	win.other:SetPoint("TOPRIGHT", win, "TOPRIGHT", -16, -376)
	win.other:SetScript("OnClick", function() Stand.Update() end)
	win.by = Text(win, 16, -446, "GameFontDisableSmall", W - 32)
end

function Stand.Update()
	if not win or not win:IsShown() then return end
	local s = Data()
	local can = Stand.CanEdit()
	win.title:SetText(BG.T("stand_title"))
	win.sub:SetText(BG.T("stand_sub"))
	win.raidLbl:SetText(BG.T("stand_raids"))
	win.dayLbl:SetText(BG.T("stand_days"))
	win.timeLbl:SetText(BG.T("stand_time"))
	win.timeHint:SetText("|cff999999" .. BG.T("stand_time_hint") .. "|r")
	win.claimLbl:SetText(BG.T("stand_claims"))
	win.prevLbl:SetText(BG.T("stand_preview"))
	win.other:SetText(BG.T("stand_other"))
	win.legend:SetText("|cffffd100" .. BG.T("stand_legend_done") .. "|r     |cffff4040" .. BG.T("stand_legend_try") .. "|r")
	for i = 1, table.getn(win.raidChecks) do
		local c = win.raidChecks[i]
		local st = Stand.RaidState(c.key)
		c:SetChecked(st and 1 or nil)
		local tex = c.GetCheckedTexture and c:GetCheckedTexture()
		if tex then
			if st == "try" then tex:SetVertexColor(1, 0.25, 0.25) else tex:SetVertexColor(1, 0.82, 0) end
		end
		if can then c:Enable() else c:Disable() end
	end
	for i = 1, 7 do
		local c = win.dayChecks[i]
		c:SetChecked(s.days[c.idx] and 1 or nil)
		if can then c:Enable() else c:Disable() end
	end
	for i = 1, table.getn(win.claimChecks) do
		local c = win.claimChecks[i]
		c.label:SetText(BG.T("stand_claim_" .. c.key))
		c:SetChecked(s.claims[c.key] and 1 or nil)
		if can then c:Enable() else c:Disable() end
	end
	win.loading = true
	win.timeEdit:SetText(s.time or "")
	win.loading = false
	if can then win.timeEdit:EnableMouse(true) else win.timeEdit:EnableMouse(false) end
	local msg = Stand.PostText()
	if msg then
		win.prev:SetText(msg .. "  |cff999999(" .. string.len(msg) .. "/255)|r")
	else
		win.prev:SetText("|cff999999" .. BG.T("stand_prev_none") .. "|r")
	end
	if not can then
		win.by:SetText("|cffffff66" .. BG.T("stand_readonly") .. "|r")
	elseif (s.ts or 0) > 0 then
		win.by:SetText(BG.T("stand_by", s.by or "?", BG.Stamp(s.ts)))
	else
		win.by:SetText("")
	end
end

function Stand.Open()
	if not win then Build() end
	win:Show()
	win:Raise()
	Stand.Update()
end

-- one line for the Gildensuche tab: "Do 20 Uhr - Kara 10, ZG - Community, freiwillig"
function Stand.Summary()
	if not Stand.Active() then return "" end
	local parts = {}
	local raids = Stand.RaidText(true)
	local noun, adv = Stand.DayTexts()
	if noun ~= "" then
		local picked = Stand.PickedDays()
		local d = {}
		if table.getn(picked) <= 3 then
			for i = 1, table.getn(picked) do table.insert(d, Stand.DAYS[picked[i]][3]) end
		else
			d[1] = noun
		end
		local t = Stand.TimeText()
		table.insert(parts, table.concat(d, "/") .. (t ~= "" and (" " .. t) or ""))
	end
	if raids ~= "" then table.insert(parts, raids) end
	local c = {}
	for i = 1, table.getn(Stand.CLAIMS) do
		if Data().claims[Stand.CLAIMS[i]] then table.insert(c, BG.T("stand_claim_short_" .. Stand.CLAIMS[i])) end
	end
	if table.getn(c) > 0 then table.insert(parts, table.concat(c, ", ")) end
	return table.concat(parts, "  -  ")
end

BananaGuild.files = BananaGuild.files or {}
BananaGuild.files.Stand = true
