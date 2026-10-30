--[[
  BananaGuild - Alerts
  * generic popup queue (used for whispers, scanner hits, new members, recruiter conflict)
]]

local BG = BananaGuild
local Alerts = {}
BG.Alerts = Alerts

local GOLD = "|cffffd100"

function BG.Sound(kind)
	if not BG.db or not BG.db.features.sound then return end
	local file
	if kind == "alert" then file = "Sound\\Interface\\RaidWarning.wav"
	else file = "Sound\\Interface\\iQuestUpdate.wav" end
	if PlaySoundFile then pcall(PlaySoundFile, file) end
end

-- solid = readable popup windows: opaque dark background (the tooltip texture is see-through)
local function Backdrop(f, dialog, solid)
	if solid then
		f:SetBackdrop({
			bgFile = "Interface\\Buttons\\WHITE8X8",
			edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
			tile = false, tileSize = 16, edgeSize = 16,
			insets = { left = 4, right = 4, top = 4, bottom = 4 },
		})
		f:SetBackdropColor(0.03, 0.05, 0.13, 1)
		f:SetBackdropBorderColor(0.9, 0.75, 0.2, 1)
	elseif dialog then
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
	Backdrop(pf, false, true)
	pf:SetToplevel(true)
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
	pf.title:SetFontObject(item.big and GameFontNormalLarge or GameFontNormal)
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
	-- items with open() are windows of their own (e.g. the new member window): no popup frame
	if item.open then
		local ok, err = pcall(item.open)
		if not ok then BG.Fail("popup", err) end
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

-- the text of the shown popup changed (e.g. the /who answer arrived)
function Popup.Refresh(item)
	if pf and Popup.current == item then pf.body:SetText(item.body or "") end
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
