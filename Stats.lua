--[[
  BananaGuild - Stats
  Guild statistics window: pie chart of the classes and a two ring chart (classes inside, specs of every class outside).
  WoW 1.12 has no drawing functions, so the charts are painted with coloured strips: for every pixel row the circle is
  split into runs of the same colour and every run is one texture (a few hundred in total, reused between redraws).
]]

local BG = BananaGuild
local Stats = {}
BG.Stats = Stats

local W, H = 780, 500
local CX, CY, R = 190, -262, 170   -- centre of the chart inside the chart frame, radius
local ROW = 2                       -- height of a strip in pixels
local win

---------------------------------------------------------------- data

-- class -> { total, specs = { code -> n }, unknownSpec = n }; sorted list of classes (biggest first)
function Stats.Collect()
	local byClass, total = {}, 0
	for name, info in pairs(BG.roster) do
		local key = info.ckey or "UNKNOWN"
		local c = byClass[key]
		if not c then c = { key = key, total = 0, specs = {}, unknown = 0 } byClass[key] = c end
		c.total = c.total + 1
		total = total + 1
		local pn = info.parsed
		if pn and pn.spec then
			c.specs[pn.spec[1]] = (c.specs[pn.spec[1]] or 0) + 1
		else
			c.unknown = c.unknown + 1
		end
	end
	local list = {}
	for _, c in pairs(byClass) do table.insert(list, c) end
	table.sort(list, function(a, b)
		if a.total ~= b.total then return a.total > b.total end
		return a.key < b.key
	end)
	return list, total
end

-- lighter / darker variants of the class colour for the specs
local function Shade(r, g, b, i)
	if i == 1 then return r + (1 - r) * 0.30, g + (1 - g) * 0.30, b + (1 - b) * 0.30 end
	if i == 2 then return r * 0.80, g * 0.80, b * 0.80 end
	if i == 3 then return r * 0.58, g * 0.58, b * 0.58 end
	return r * 0.42, g * 0.42, b * 0.42
end

-- segments of the chart: inner = classes, outer = specs (in the order of the classes, so they sit beside their class)
function Stats.Segments(list)
	local inner, outer = {}, {}
	for i = 1, table.getn(list) do
		local c = list[i]
		local r, g, b = BG.Notes.ClassColor(c.key)
		local name = (c.key == "UNKNOWN") and BG.T("stats_unknown_class") or BG.Notes.ClassName(c.key)
		table.insert(inner, { n = c.total, r = r, g = g, b = b, label = name, class = c.key })
		local specs = BG.Notes.Specs(c.key)
		local shade = 0
		for j = 1, table.getn(specs) do
			local n = c.specs[specs[j][1]] or 0
			shade = shade + 1
			if n > 0 then
				local sr, sg, sb = Shade(r, g, b, shade)
				table.insert(outer, { n = n, r = sr, g = sg, b = sb, label = BG.Notes.SpecName(specs[j]), class = c.key })
			end
		end
		if c.unknown > 0 then
			table.insert(outer, { n = c.unknown, r = 0.22 + r * 0.18, g = 0.22 + g * 0.18, b = 0.22 + b * 0.18,
				label = BG.T("stats_unknown_spec"), class = c.key, unknown = true })
		end
	end
	return inner, outer
end

---------------------------------------------------------------- painting

local pool, used = {}, 0
Stats.pool = pool

local function Strip(x, y, w, h, r, g, b)
	used = used + 1
	local t = pool[used]
	if not t then
		t = { tex = win.chart:CreateTexture(nil, "ARTWORK") }
		pool[used] = t
	end
	t.x, t.y, t.w, t.h, t.r, t.g, t.b = x, y, w, h, r, g, b
	t.tex:SetTexture(r, g, b, 1)
	t.tex:ClearAllPoints()
	t.tex:SetPoint("TOPLEFT", win.chart, "TOPLEFT", x, y)
	t.tex:SetWidth(w)
	t.tex:SetHeight(h)
	t.tex:Show()
end

local TWO_PI = 2 * math.pi
local CELL = 2   -- 2 x 2 pixel cells; neighbours of the same colour become one strip

-- boundaries of the segments as angles (0 = 12 o'clock, clockwise)
local function Bounds(segs)
	local total = 0
	for i = 1, table.getn(segs) do total = total + segs[i].n end
	local b, acc = {}, 0
	for i = 1, table.getn(segs) do
		acc = acc + segs[i].n
		b[i] = (total > 0) and (acc / total * TWO_PI) or 0
	end
	return b
end

local function SegAt(bounds, a)
	for i = 1, table.getn(bounds) do
		if a <= bounds[i] then return i end
	end
	return table.getn(bounds)
end

-- rings = { { innerRadius, outerRadius, segments, bounds }, ... }; the biggest outer radius is the chart radius
local function Paint(rings)
	used = 0
	local nr = table.getn(rings)
	local radius = rings[nr][2]
	local cells = math.floor(radius / CELL)
	local r2 = (cells * CELL) * (cells * CELL)
	for row = 0, 2 * cells - 1 do
		local dy = (cells - row - 0.5) * CELL           -- up is positive
		local runColor, runStart = nil, 0
		for col = 0, 2 * cells do                       -- one cell too many: flushes the last strip
			local color
			if col < 2 * cells then
				local dx = (col - cells + 0.5) * CELL
				local d2 = dx * dx + dy * dy
				if d2 <= r2 then
					local d = math.sqrt(d2)
					for k = 1, nr do
						local ring = rings[k]
						if d >= ring[1] and d <= ring[2] then
							local a = math.atan2(dx, dy)
							if a < 0 then a = a + TWO_PI end
							color = ring[3][SegAt(ring[4], a)]
							break
						end
					end
				end
			end
			if color ~= runColor then
				if runColor then
					Strip(runStart * CELL, -(row * CELL), (col - runStart) * CELL, CELL, runColor.r, runColor.g, runColor.b)
				end
				runColor, runStart = color, col
			end
		end
	end
	for i = used + 1, table.getn(pool) do pool[i].tex:Hide() end
end

---------------------------------------------------------------- legend

local lines, squares = {}, {}

local function Line(i)
	local l = lines[i]
	if not l then
		l = win:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		l:SetJustifyH("LEFT")
		lines[i] = l
		squares[i] = win:CreateTexture(nil, "ARTWORK")
	end
	return l, squares[i]
end

local COLW, LINEH, LEG_X, LEG_Y = 200, 13, 384, -74

local function Legend(entries)
	local perCol = math.floor((H - 100) / LINEH)
	for i = 1, table.getn(entries) do
		local e = entries[i]
		local fs, sq = Line(i)
		local col = math.floor((i - 1) / perCol)
		local row = (i - 1) - col * perCol
		fs:ClearAllPoints()
		fs:SetPoint("TOPLEFT", win, "TOPLEFT", LEG_X + col * COLW + (e.indent and 24 or 14), LEG_Y - row * LINEH)
		fs:SetWidth(COLW - 30)
		fs:SetText(e.text)
		fs:Show()
		sq:ClearAllPoints()
		sq:SetPoint("TOPLEFT", win, "TOPLEFT", LEG_X + col * COLW + (e.indent and 10 or 0), LEG_Y - row * LINEH - 1)
		sq:SetWidth(9)
		sq:SetHeight(9)
		if e.r then sq:SetTexture(e.r, e.g, e.b, 1) sq:Show() else sq:Hide() end
	end
	for i = table.getn(entries) + 1, table.getn(lines) do lines[i]:Hide() squares[i]:Hide() end
end

local function Pct(n, total)
	if total <= 0 then return "0%" end
	return math.floor(n * 100 / total + 0.5) .. "%"
end

---------------------------------------------------------------- window

local function Name(prefix)
	Stats.counter = (Stats.counter or 0) + 1
	return "BananaGuildStats" .. prefix .. Stats.counter
end

local function Build()
	win = CreateFrame("Frame", "BananaGuildStatsWin", UIParent)
	win:SetWidth(W)
	win:SetHeight(H)
	win:SetPoint("CENTER", UIParent, "CENTER", 0, 10)
	win:SetFrameStrata("DIALOG")
	win:EnableMouse(true)
	win:SetMovable(true)
	win:RegisterForDrag("LeftButton")
	win:SetScript("OnDragStart", function() this:StartMoving() end)
	win:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
	BG.Backdrop(win, false, true)
	win:SetToplevel(true)
	win:Hide()
	table.insert(UISpecialFrames, "BananaGuildStatsWin")
	local close = CreateFrame("Button", Name("Close"), win, "UIPanelCloseButton")
	close:SetPoint("TOPRIGHT", win, "TOPRIGHT", -4, -4)
	close:SetScript("OnClick", function() win:Hide() end)

	win.title = win:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	win.title:SetPoint("TOPLEFT", win, "TOPLEFT", 16, -14)
	win.sub = win:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	win.sub:SetPoint("TOPLEFT", win, "TOPLEFT", 16, -38)

	win.btnClasses = BG.MakeButton(win, Name("Btn"), 150, 22, "")
	win.btnClasses:SetPoint("TOPLEFT", win, "TOPLEFT", 384, -12)
	win.btnClasses:SetScript("OnClick", function() Stats.mode = "classes" Stats.Refresh(true) end)
	win.btnSpecs = BG.MakeButton(win, Name("Btn"), 190, 22, "")
	win.btnSpecs:SetPoint("LEFT", win.btnClasses, "RIGHT", 4, 0)
	win.btnSpecs:SetScript("OnClick", function() Stats.mode = "specs" Stats.Refresh(true) end)

	-- the chart is painted into its own frame; (0,0) is the top left corner of the square around the circle
	win.chart = CreateFrame("Frame", Name("Chart"), win)
	win.chart:SetWidth(2 * R)
	win.chart:SetHeight(2 * R)
	win.chart:SetPoint("TOPLEFT", win, "TOPLEFT", CX - R, CY + R)

	win.empty = win:CreateFontString(nil, "OVERLAY", "GameFontDisable")
	win.empty:SetPoint("CENTER", win.chart, "CENTER", 0, 0)
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

-- force = repaint even when the numbers did not change
function Stats.Refresh(force)
	if not win or not win:IsShown() then return end
	local list, total = Stats.Collect()
	local inner, outer = Stats.Segments(list)
	local sig = Stats.mode .. ":" .. total
	for i = 1, table.getn(inner) do sig = sig .. "," .. inner[i].label .. inner[i].n end
	for i = 1, table.getn(outer) do sig = sig .. "," .. outer[i].label .. outer[i].n end
	win.title:SetText("|cffffd100" .. BG.T("stats_title") .. "|r")
	win.sub:SetText(BG.T("stats_total", total))
	win.btnClasses:SetText(BG.T("stats_classes"))
	win.btnSpecs:SetText(BG.T("stats_specs"))
	Mark(win.btnClasses, Stats.mode == "classes")
	Mark(win.btnSpecs, Stats.mode == "specs")
	if not force and sig == Stats.sig then return end
	Stats.sig = sig
	if total == 0 then
		for i = 1, table.getn(pool) do pool[i].tex:Hide() end
		used = 0
		win.empty:SetText(BG.T("stats_empty"))
		Legend({})
		return
	end
	win.empty:SetText("")
	local entries = {}
	if Stats.mode == "classes" then
		Paint({ { 0, R, inner, Bounds(inner) } })
		for i = 1, table.getn(inner) do
			local s = inner[i]
			table.insert(entries, { r = s.r, g = s.g, b = s.b, text = s.label .. "  |cffffd100" .. s.n .. "|r  |cff999999(" .. Pct(s.n, total) .. ")|r" })
		end
	else
		-- inner pie: classes; outer ring: the specs of every class (same order, so they stay beside their class)
		Paint({ { 0, R * 0.52, inner, Bounds(inner) }, { R * 0.54, R, outer, Bounds(outer) } })
		for i = 1, table.getn(list) do
			local c = list[i]
			local s = inner[i]
			table.insert(entries, { r = s.r, g = s.g, b = s.b, text = "|cffffd100" .. s.label .. "|r  " .. c.total .. "  |cff999999(" .. Pct(c.total, total) .. ")|r" })
			for k = 1, table.getn(outer) do
				local o = outer[k]
				if o.class == c.key then
					table.insert(entries, { r = o.r, g = o.g, b = o.b, indent = true, text = o.label .. "  " .. o.n })
				end
			end
		end
	end
	Legend(entries)
end

function Stats.Open(mode)
	if not win then Build() end
	Stats.mode = mode or Stats.mode or "classes"
	win:Show()
	win:Raise()
	Stats.Refresh(true)
end

-- the guild list changed: repaint when the window is open
function Stats.OnRoster()
	if win and win:IsShown() then Stats.Refresh(false) end
end

function Stats.IsOpen() return win and win:IsShown() end

BananaGuild.files = BananaGuild.files or {}
BananaGuild.files.Stats = true
