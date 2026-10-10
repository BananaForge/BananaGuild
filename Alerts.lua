--[[
  BananaGuild - Alerts
  * level-up hint in chat + clickable GZ toast
  * big level-60 splash (logo + player name)
  * generic popup queue (used for whispers, scanner hits, new members, recruiter conflict)
]]

local BG = BananaGuild
local Alerts = {}
BG.Alerts = Alerts
BG.announced = {}

local GOLD = "|cffffd100"

function BG.Sound(kind)
	if not BG.db or not BG.db.features.sound then return end
	local file
	if kind == "levelup" then file = "Sound\\Interface\\LevelUp.wav"
	elseif kind == "alert" then file = "Sound\\Interface\\RaidWarning.wav"
	else file = "Sound\\Interface\\iQuestUpdate.wav" end
	if PlaySoundFile then pcall(PlaySoundFile, file) end
end

local function Backdrop(f, dialog)
	if dialog then
		f:SetBackdrop({
			bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
			edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
			tile = true, tileSize = 32, edgeSize = 32,
			insets = { left = 11, right = 12, top = 12, bottom = 11 },
		})
	else
		f:SetBackdrop({
			bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
			edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
			tile = true, tileSize = 16, edgeSize = 16,
			insets = { left = 5, right = 5, top = 5, bottom = 5 },
		})
		f:SetBackdropColor(0.04, 0.07, 0.2, 0.95)
		f:SetBackdropBorderColor(0.9, 0.75, 0.2, 1)
	end
end
BG.Backdrop = Backdrop

local function Button(parent, name, w, h, text)
	local b = CreateFrame("Button", name, parent, "UIPanelButtonTemplate")
	b:SetWidth(w)
	b:SetHeight(h)
	b:SetText(text or "")
	return b
end
BG.MakeButton = Button

--------------------------------------------------------------------- GZ

function Alerts.SendGZ(name, level)
	name = name or (BG.lastLevelUp and BG.lastLevelUp.name)
	level = level or (BG.lastLevelUp and BG.lastLevelUp.level) or ""
	if not name then BG.Print(BG.T("no_levelup_yet")) return end
	local line = BG.RandomLine(BG.db.texts.gz) or "GZ {name}!"
	BG.SendChat(BG.Fill(line, { name = name, level = level }), "GUILD")
end

--------------------------------------------------------------------- level toast

local toast, toastQueue = nil, {}

local function ToastNext()
	if table.getn(toastQueue) == 0 then toast:Hide() return end
	local item = table.remove(toastQueue, 1)
	toast.name, toast.level = item.name, item.level
	toast.text:SetText(BG.T("toast_levelup", GOLD .. item.name .. "|r", item.level))
	toast.elapsed = 0
	toast:Show()
end

local function BuildToast()
	toast = CreateFrame("Frame", "BananaGuildToast", UIParent)
	toast:SetWidth(340)
	toast:SetHeight(74)
	toast:SetPoint("TOP", UIParent, "TOP", 0, -170)
	toast:SetFrameStrata("DIALOG")
	toast:EnableMouse(true)
	toast:SetMovable(true)
	toast:RegisterForDrag("LeftButton")
	toast:SetScript("OnDragStart", function() this:StartMoving() end)
	toast:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
	Backdrop(toast, false)
	local icon = toast:CreateTexture(nil, "ARTWORK")
	icon:SetTexture(BG.LOGO)
	icon:SetWidth(52)
	icon:SetHeight(52)
	icon:SetPoint("LEFT", toast, "LEFT", 10, 0)
	toast.text = toast:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	toast.text:SetPoint("TOPLEFT", toast, "TOPLEFT", 70, -12)
	toast.text:SetWidth(255)
	toast.text:SetJustifyH("LEFT")
	local gz = Button(toast, "BananaGuildToastGZ", 110, 22, BG.T("btn_gz"))
	gz:SetPoint("BOTTOMLEFT", toast, "BOTTOMLEFT", 70, 10)
	gz:SetScript("OnClick", function()
		Alerts.SendGZ(toast.name, toast.level)
		ToastNext()
	end)
	toast.gz = gz
	local skip = Button(toast, "BananaGuildToastSkip", 70, 22, BG.T("btn_close"))
	skip:SetPoint("LEFT", gz, "RIGHT", 6, 0)
	skip:SetScript("OnClick", function() ToastNext() end)
	toast.skip = skip
	toast.elapsed = 0
	toast:SetScript("OnUpdate", function()
		this.elapsed = (this.elapsed or 0) + arg1
		if this.elapsed > 25 then ToastNext() end
	end)
	toast:Hide()
end

function Alerts.RelabelToast()
	if toast then
		toast.gz:SetText(BG.T("btn_gz"))
		toast.skip:SetText(BG.T("btn_close"))
	end
end

function Alerts.LevelToast(name, level, test)
	if not toast then BuildToast() end
	BG.lastLevelUp = { name = name, level = level }
	table.insert(toastQueue, { name = name, level = level })
	if not toast:IsVisible() then ToastNext() end
	BG.Sound("levelup")
end
-- slash helper alias
BG.Alerts.LevelToast = Alerts.LevelToast

--------------------------------------------------------------------- level 60 splash

local splash, splashQueue = nil, {}

local function SplashNext()
	if table.getn(splashQueue) == 0 then splash:Hide() return end
	local name = table.remove(splashQueue, 1)
	splash.name = name
	splash.nameText:SetText(name)
	splash.sub:SetText(BG.T("splash_sub"))
	splash.elapsed = 0
	splash:SetAlpha(0)
	splash:Show()
	BG.Sound("levelup")
end

local function BuildSplash()
	splash = CreateFrame("Frame", "BananaGuildSplash", UIParent)
	splash:SetWidth(520)
	splash:SetHeight(520)
	splash:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
	splash:SetFrameStrata("FULLSCREEN_DIALOG")
	splash:EnableMouse(true)
	local logo = splash:CreateTexture(nil, "ARTWORK")
	logo:SetTexture(BG.LOGO)
	logo:SetWidth(340)
	logo:SetHeight(340)
	logo:SetPoint("TOP", splash, "TOP", 0, 0)
	splash.nameText = splash:CreateFontString(nil, "OVERLAY")
	splash.nameText:SetFont("Fonts\\FRIZQT__.TTF", 44, "OUTLINE")
	splash.nameText:SetTextColor(1, 0.82, 0)
	splash.nameText:SetPoint("TOP", logo, "BOTTOM", 0, 0)
	splash.sub = splash:CreateFontString(nil, "OVERLAY")
	splash.sub:SetFont("Fonts\\FRIZQT__.TTF", 24, "OUTLINE")
	splash.sub:SetTextColor(1, 1, 1)
	splash.sub:SetPoint("TOP", splash.nameText, "BOTTOM", 0, -6)
	local gz = Button(splash, "BananaGuildSplashGZ", 140, 26, BG.T("btn_gz"))
	gz:SetPoint("TOP", splash.sub, "BOTTOM", 0, -14)
	gz:SetScript("OnClick", function() Alerts.SendGZ(splash.name, 60) end)
	splash.gz = gz
	splash:SetScript("OnMouseUp", function() SplashNext() end)
	splash.elapsed = 0
	splash:SetScript("OnUpdate", function()
		this.elapsed = (this.elapsed or 0) + arg1
		local t = this.elapsed
		local a
		if t < 0.8 then a = t / 0.8
		elseif t < 8.8 then a = 1
		elseif t < 10.3 then a = 1 - (t - 8.8) / 1.5
		else SplashNext() return end
		this:SetAlpha(a)
	end)
	splash:Hide()
end

function Alerts.ShowLevel60(name, test)
	if not splash then BuildSplash() end
	table.insert(splashQueue, name or "?")
	if not splash:IsVisible() then SplashNext() end
end

function Alerts.RelabelSplash()
	if splash then splash.gz:SetText(BG.T("btn_gz")) end
end

--------------------------------------------------------------------- level up entry point

-- Does this level up get a GZ popup / chat notice? (settings: all levels, or only chosen full tens)
function Alerts.LevelWanted(level)
	local g = BG.db.gz
	if not g or g.mode ~= "tens" then return true end
	if math.mod(level, 10) ~= 0 then return false end
	return g.levels[level] and true or false
end

function Alerts.OnLevel(name, level, source)
	if not name or not level then return end
	if BG.announced[name] and BG.announced[name] >= level then return end
	BG.announced[name] = level
	BG.db.levels[name] = level
	BG.AddLog("levelup", name, level)
	BG.lastLevelUp = { name = name, level = level }
	local f = BG.db.features
	local isSelf = (name == BG.me)
	if level == 60 and f.level60 and not BG.QuietBlocks("level60") then
		Alerts.ShowLevel60(name)
	end
	if f.levelup and (not isSelf or f.selfToast) and Alerts.LevelWanted(level) and not BG.QuietBlocks("levelup") then
		BG.Print(BG.T("levelup_chat", GOLD .. name .. "|r", level))
		Alerts.LevelToast(name, level)
	end
	if BG.UI and BG.UI.Refresh then BG.UI.Refresh("log") end
end

BG.On("PLAYER_LEVEL_UP", function(newLevel)
	local lvl = tonumber(newLevel)
	if not lvl then return end
	BG.Send("L", BG.me, lvl)
	Alerts.OnLevel(BG.me, lvl, "self")
end)

BG.OnComm("L", function(sender, p)
	local who = BG.NormName(p[1] or sender)
	local lvl = tonumber(p[2])
	if who ~= "" and lvl then Alerts.OnLevel(who, lvl, "comm") end
end)

--------------------------------------------------------------------- generic popup queue

local Popup = { queue = {}, current = nil }
BG.Popup = Popup
local pf

local BTN_W, BTN_H, GAP, POP_W = 158, 26, 8, 540

local function BuildPopup()
	pf = CreateFrame("Frame", "BananaGuildPopup", UIParent)
	pf:SetWidth(POP_W)
	pf:SetHeight(200)
	pf:SetPoint("CENTER", UIParent, "CENTER", 0, 160)
	pf:SetFrameStrata("DIALOG")
	pf:EnableMouse(true)
	pf:SetMovable(true)
	pf:RegisterForDrag("LeftButton")
	pf:SetScript("OnDragStart", function() this:StartMoving() end)
	pf:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
	Backdrop(pf, false)
	local icon = pf:CreateTexture(nil, "ARTWORK")
	icon:SetTexture(BG.LOGO)
	icon:SetWidth(44)
	icon:SetHeight(44)
	icon:SetPoint("TOPLEFT", pf, "TOPLEFT", 12, -10)
	pf.title = pf:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	pf.title:SetPoint("TOPLEFT", pf, "TOPLEFT", 64, -14)
	pf.title:SetWidth(POP_W - 130)
	pf.title:SetJustifyH("LEFT")
	pf.more = pf:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	pf.more:SetPoint("TOPRIGHT", pf, "TOPRIGHT", -30, -16)
	pf.body = pf:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	pf.body:SetPoint("TOPLEFT", pf, "TOPLEFT", 64, -34)
	pf.body:SetWidth(POP_W - 84)
	pf.body:SetHeight(66)
	pf.body:SetJustifyH("LEFT")
	pf.body:SetJustifyV("TOP")
	local close = CreateFrame("Button", "BananaGuildPopupClose", pf, "UIPanelCloseButton")
	close:SetPoint("TOPRIGHT", pf, "TOPRIGHT", -2, -2)
	close:SetScript("OnClick", function() Popup.Next() end)
	pf.buttons = {}
	for i = 1, 8 do
		local b = Button(pf, "BananaGuildPopupBtn" .. i, BTN_W, BTN_H, "")
		b:SetScript("OnClick", function()
			local item = Popup.current
			local act = this.act
			if act then
				local ok, err = pcall(act)
				if not ok then BG.Fail("popup", err) end
			end
			if item == Popup.current then Popup.Next() end
		end)
		b:SetScript("OnEnter", function()
			if this.tip then
				GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
				GameTooltip:SetText(this.tip, 1, 1, 1, 1, 1)
				GameTooltip:Show()
			end
		end)
		b:SetScript("OnLeave", function() GameTooltip:Hide() end)
		pf.buttons[i] = b
	end
	pf:Hide()
end

local function Show(item)
	if not pf then BuildPopup() end
	Popup.current = item
	pf.title:SetText(item.title or "BananaGuild")
	pf.body:SetText(item.body or "")
	local n = table.getn(item.buttons)
	if n > 8 then n = 8 end
	-- balanced rows (max 3 per row), every row centred: 5 buttons -> 3 + 2, 6 -> 3 + 3, 4 -> 2 + 2
	local perRow = n
	if n > 3 then perRow = math.ceil(n / 2) end
	if perRow > 3 then perRow = 3 end
	local rows = math.ceil(n / perRow)
	for i = 1, 8 do
		local b = pf.buttons[i]
		if i <= n then
			local def = item.buttons[i]
			b:SetText(def.text)
			b.act = def.fn
			b.tip = def.tip
			local row = math.floor((i - 1) / perRow)
			local inRow = perRow
			if row == rows - 1 then inRow = n - row * perRow end
			local col = (i - 1) - row * perRow
			local rowW = inRow * BTN_W + (inRow - 1) * GAP
			b:ClearAllPoints()
			b:SetPoint("TOPLEFT", pf, "TOPLEFT", (POP_W - rowW) / 2 + col * (BTN_W + GAP), -108 - row * (BTN_H + GAP))
			b:Show()
		else
			b:Hide()
		end
	end
	pf:SetHeight(108 + rows * (BTN_H + GAP) + 10)
	local q = table.getn(Popup.queue)
	pf.more:SetText(q > 0 and BG.T("popup_more", q) or "")
	pf:Show()
	BG.Sound("alert")
end

function Popup.Push(item)
	-- instance / raid mode: item.type says what kind of message it is; item.force skips the check (user-triggered)
	if item.type and not item.force and BG.QuietBlocks(item.type) then
		if item.defer and BG.db.quiet.catchup and table.getn(BG.quiet.deferred) < 10 then
			local dup = false
			for i = 1, table.getn(BG.quiet.deferred) do
				if BG.quiet.deferred[i].key == item.key then dup = true end
			end
			if not dup then table.insert(BG.quiet.deferred, item) end
		end
		return
	end
	if item.key then
		if Popup.current and Popup.current.key == item.key then return end
		for i = 1, table.getn(Popup.queue) do
			if Popup.queue[i].key == item.key then return end
		end
	end
	if table.getn(Popup.queue) >= 10 then return end
	if Popup.current then
		table.insert(Popup.queue, item)
		if pf then pf.more:SetText(BG.T("popup_more", table.getn(Popup.queue))) end
	else
		Show(item)
	end
end

function Popup.Next()
	Popup.current = nil
	if table.getn(Popup.queue) > 0 then
		Show(table.remove(Popup.queue, 1))
	elseif pf then
		pf:Hide()
	end
end

function Popup.Clear()
	Popup.queue = {}
	Popup.current = nil
	if pf then pf:Hide() end
end

BananaGuild = BananaGuild or {}
BananaGuild.files = BananaGuild.files or {}
BananaGuild.files.Alerts = true
