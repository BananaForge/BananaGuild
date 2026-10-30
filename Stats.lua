--[[
  BananaGuild - Stats
  Guild statistics window.
    "Klassen":        donut chart of the classes + ranked list with bars + role split; hover on a slice or a row shows
                      the class with its specs, a click opens the specs of that class
    "Specs pro Klasse": pick a class (buttons) -> one donut chart with the specs of exactly that class
    "Rollen":         donut chart of Tank / Heal / DD (from the specs in the notes) for a level range, e.g. only level 40 and up,
                      so that low level and levelling characters do not distort what the guild has at the top
  WoW 1.12 has no drawing functions. The slices are painted with coloured strips (one texture per run of equal colour on
  a pixel row, painted a few rows per frame); a ring-shaped overlay texture (Media\donut.tga, antialiased) cuts the
  round outer edge and the hole and adds the golden rims.
]]

local BG = BananaGuild
local Stats = {}
BG.Stats = Stats

local W, H = 800, 524
local R = 165                       -- radius of the chart
local HOLE = 0.56                   -- hole of the donut (matches the overlay texture)
local MARGIN = 4                    -- overlay texture is a bit bigger than the circle
local CX, CY = 20 + R + MARGIN, -(92 + R + MARGIN)    -- centre of the chart in the window
local RX, RW = 424, 362             -- right hand side: x and width
local ROW = 2                       -- strip height / cell size in pixels
local GAP = 1.2                     -- dark gap between two slices in pixels
local win

local GOLD, GRAY = "|cffffd100", "|cff999999"
local ROLE_COL = { T = { 0.42, 0.65, 1.0 }, H = { 0.48, 0.88, 0.61 }, D = { 1.0, 0.56, 0.52 } }
local BGC = { r = 0.03, g = 0.05, b = 0.13 }          -- window background (gaps)

---------------------------------------------------------------- data

-- list of classes (biggest first): { key, total, specs = { code -> n }, unknown, roles = { T, H, D } }, and the guild total
function Stats.Collect()
	local byClass, total = {}, 0
	for name, info in pairs(BG.roster) do
		local key = info.ckey or "UNKNOWN"
		local c = byClass[key]
		if not c then c = { key = key, total = 0, specs = {}, unknown = 0, roles = { T = 0, H = 0, D = 0 } } byClass[key] = c end
		c.total = c.total + 1
		total = total + 1
		local pn = info.parsed
		if pn and pn.spec then
			c.specs[pn.spec[1]] = (c.specs[pn.spec[1]] or 0) + 1
			if pn.role then c.roles[pn.role] = c.roles[pn.role] + 1 end
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

-- roles inside a level range: { T, H, D, ? } counts, the number of characters in the range, and per role the
-- "class / spec" breakdown for the tooltip
function Stats.CollectRoles(lo, hi)
	local out = { T = 0, H = 0, D = 0, ["?"] = 0, inRange = 0, total = 0, detail = { T = {}, H = {}, D = {}, ["?"] = {} } }
	for name, info in pairs(BG.roster) do
		out.total = out.total + 1
		local lvl = info.level or 0
		if lvl >= lo and lvl <= hi then
			out.inRange = out.inRange + 1
			local pn = info.parsed
			local role = (pn and pn.spec and pn.role) or "?"
			out[role] = out[role] + 1
			local label
			if role == "?" then
				label = info.ckey and BG.Notes.ClassName(info.ckey) or BG.T("stats_unknown_class")
			else
				label = BG.Notes.ClassName(info.ckey) .. " (" .. BG.Notes.SpecName(pn.spec) .. ")"
			end
			out.detail[role][label] = (out.detail[role][label] or 0) + 1
		end
	end
	return out
end

-- level range from the settings (saved): lo <= hi, 1..60
function Stats.Range()
	local r = BG.db.statsRange
	local lo, hi = tonumber(r.min) or 40, tonumber(r.max) or 60
	if lo < 1 then lo = 1 end
	if hi > 60 then hi = 60 end
	if hi < lo then hi = lo end
	return lo, hi
end

function Stats.SetRange(lo, hi)
	lo, hi = tonumber(lo), tonumber(hi)
	if not lo or not hi then return end
	if hi < lo then lo, hi = hi, lo end
	if lo < 1 then lo = 1 end
	if hi > 60 then hi = 60 end
	if lo > hi then lo = hi end
	BG.db.statsRange = { min = lo, max = hi }
	Stats.Refresh(true)
end

local function ClassLabel(key)
	if key == "UNKNOWN" then return BG.T("stats_unknown_class") end
	return BG.Notes.ClassName(key)
end

-- slices of the class chart
function Stats.ClassSegments(list, total)
	local segs = {}
	for i = 1, table.getn(list) do
		local c = list[i]
		local r, g, b = BG.Notes.ClassColor(c.key)
		table.insert(segs, { n = c.total, r = r, g = g, b = b, label = ClassLabel(c.key), key = c.key, class = c, share = c.total / math.max(total, 1) })
	end
	return segs
end

-- slices of one class: its specs (only those that exist) + "spec unknown"
local function Tint(r, g, b, i)
	if i == 1 then return r + (1 - r) * 0.28, g + (1 - g) * 0.28, b + (1 - b) * 0.28 end
	if i == 2 then return r, g, b end
	if i == 3 then return r * 0.72, g * 0.72, b * 0.72 end
	return r * 0.50, g * 0.50, b * 0.50
end

function Stats.SpecSegments(c)
	local segs = {}
	local r, g, b = BG.Notes.ClassColor(c.key)
	local specs = BG.Notes.Specs(c.key)
	local k = 0
	for j = 1, table.getn(specs) do
		local n = c.specs[specs[j][1]] or 0
		k = k + 1
		if n > 0 then
			local sr, sg, sb = Tint(r, g, b, k)
			table.insert(segs, { n = n, r = sr, g = sg, b = sb, label = BG.Notes.SpecName(specs[j]), role = specs[j][4], share = n / math.max(c.total, 1) })
		end
	end
	if c.unknown > 0 then
		table.insert(segs, { n = c.unknown, r = 0.30, g = 0.33, b = 0.42, label = BG.T("stats_unknown_spec"), unknown = true, share = c.unknown / math.max(c.total, 1) })
	end
	return segs
end

local function Pct(n, total)
	if total <= 0 then return "0%" end
	return math.floor(n * 100 / total + 0.5) .. "%"
end

local function Hex(r, g, b)
	return string.format("|cff%02x%02x%02x", math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5))
end

---------------------------------------------------------------- painting (a few rows per frame)

local pool, used = {}, 0
Stats.pool = pool
local TWO_PI = 2 * math.pi
local job

-- the painted disc (cells * ROW pixels) sits in the middle of the chart frame (which has a margin around the circle)
local OFF = R + MARGIN - math.floor(R / ROW) * ROW

local function Strip(x, y, w, h, c)
	x, y = x + OFF, y - OFF
	used = used + 1
	local t = pool[used]
	if not t then
		t = { tex = win.chart:CreateTexture(nil, "ARTWORK") }
		pool[used] = t
	end
	t.x, t.y, t.w, t.h, t.r, t.g, t.b = x, y, w, h, c.r, c.g, c.b
	t.tex:SetTexture(c.r, c.g, c.b, 1)
	t.tex:ClearAllPoints()
	t.tex:SetPoint("TOPLEFT", win.chart, "TOPLEFT", x, y)
	t.tex:SetWidth(w)
	t.tex:SetHeight(h)
	t.tex:Show()
end

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

-- which slice is at (dx, dy) relative to the centre (up = positive)? nil = hole / outside
function Stats.HitTest(dx, dy)
	local cur = Stats.cur
	if not cur then return nil end
	local d = math.sqrt(dx * dx + dy * dy)
	if d > R or d < R * HOLE then return nil end
	local a = math.atan2(dx, dy)
	if a < 0 then a = a + TWO_PI end
	return SegAt(cur.bounds, a)
end

-- paint rows [from, to] of the job
local function PaintRows(j, from, to)
	local cells = j.cells
	local r2 = (cells * ROW) * (cells * ROW)
	local hole = R * HOLE
	local segs, bounds = j.segs, j.bounds
	local nb = table.getn(bounds)
	for row = from, to do
		local dy = (cells - row - 0.5) * ROW                -- up is positive
		local runColor, runStart = nil, 0
		for col = 0, 2 * cells do                           -- one cell too many: flushes the last strip
			local color
			if col < 2 * cells then
				local dx = (col - cells + 0.5) * ROW
				local d2 = dx * dx + dy * dy
				if d2 <= r2 then
					local d = math.sqrt(d2)
					if d >= hole - 1 then
						local a = math.atan2(dx, dy)
						if a < 0 then a = a + TWO_PI end
						local idx = SegAt(bounds, a)
						color = segs[idx].color
						-- thin dark line between two slices (not when there is only one)
						if nb > 1 then
							local lo = (idx > 1) and bounds[idx - 1] or 0
							local da = a - lo
							if idx < nb then da = math.min(da, bounds[idx] - a) end   -- the line at 12 o'clock only once
							if da * d < GAP then color = BGC end
						end
					end
				end
			end
			if color ~= runColor then
				if runColor then Strip(runStart * ROW, -(row * ROW), (col - runStart) * ROW, ROW, runColor) end
				runColor, runStart = color, col
			end
		end
	end
end

local ROWS_PER_FRAME = 50

local function PaintStep()
	local j = job
	if not j then return end
	local last = math.min(j.next + ROWS_PER_FRAME - 1, 2 * j.cells - 1)
	PaintRows(j, j.next, last)
	j.next = last + 1
	if j.next > 2 * j.cells - 1 then
		for i = used + 1, table.getn(pool) do pool[i].tex:Hide() end
		job = nil
	end
end

-- segs get their colour table here; start painting
local function StartPaint(segs)
	for i = 1, table.getn(segs) do
		local s = segs[i]
		s.color = { r = s.r, g = s.g, b = s.b }
	end
	used = 0
	Stats.cur = { segs = segs, bounds = Bounds(segs) }
	job = { segs = segs, bounds = Stats.cur.bounds, cells = math.floor(R / ROW), next = 0 }
	PaintStep()
end

---------------------------------------------------------------- right hand side: rows with bars

local rows = {}
local ROW_H = 31

local function BuildRow(i)
	local r = CreateFrame("Button", "BananaGuildStatsRow" .. i, win)
	r:SetWidth(RW)
	r:SetHeight(ROW_H - 3)
	r.bg = r:CreateTexture(nil, "BACKGROUND")
	r.bg:SetAllPoints(r)
	r.bg:SetTexture(1, 1, 1, 0)
	r.icon = r:CreateTexture(nil, "ARTWORK")
	r.icon:SetWidth(14)
	r.icon:SetHeight(14)
	r.icon:SetPoint("LEFT", r, "LEFT", 8, 0)
	r.name = r:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	r.name:SetPoint("LEFT", r, "LEFT", 30, 0)
	r.name:SetWidth(112)
	r.name:SetJustifyH("LEFT")
	r.track = r:CreateTexture(nil, "ARTWORK")
	r.track:SetTexture(0.10, 0.12, 0.20, 1)
	r.track:SetWidth(120)
	r.track:SetHeight(9)
	r.track:SetPoint("LEFT", r, "LEFT", 148, 0)
	r.fill = r:CreateTexture(nil, "OVERLAY")
	r.fill:SetHeight(9)
	r.fill:SetPoint("LEFT", r, "LEFT", 148, 0)
	r.count = r:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	r.count:SetPoint("LEFT", r, "LEFT", 276, 0)
	r.count:SetWidth(30)
	r.count:SetJustifyH("RIGHT")
	r.pct = r:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	r.pct:SetPoint("LEFT", r, "LEFT", 310, 0)
	r.pct:SetWidth(44)
	r.pct:SetJustifyH("RIGHT")
	r:SetScript("OnEnter", function()
		this.bg:SetTexture(1, 1, 1, 0.08)
		if this.tip then Stats.ShowTip(this, this.tip) end
	end)
	r:SetScript("OnLeave", function() this.bg:SetTexture(1, 1, 1, 0) GameTooltip:Hide() end)
	r:SetScript("OnClick", function() if this.onClick then this.onClick() end end)
	rows[i] = r
	return r
end

-- entries: { r, g, b, label, n, pct (text), share (0..1 for the bar), tip, onClick }
local function ShowRows(entries, y0)
	for i = 1, table.getn(entries) do
		local e = entries[i]
		local r = rows[i] or BuildRow(i)
		r:ClearAllPoints()
		r:SetPoint("TOPLEFT", win, "TOPLEFT", RX, y0 - (i - 1) * ROW_H)
		r.icon:SetTexture(e.r, e.g, e.b, 1)
		r.fill:SetTexture(e.r, e.g, e.b, 1)
		r.fill:SetWidth(math.max(2, math.floor(120 * e.share + 0.5)))
		r.name:SetText(e.label)
		r.count:SetText(GOLD .. e.n .. "|r")
		r.pct:SetText(e.pct)
		r.tip = e.tip
		r.onClick = e.onClick
		r:Show()
	end
	for i = table.getn(entries) + 1, table.getn(rows) do rows[i]:Hide() end
end

---------------------------------------------------------------- tooltips

function Stats.ShowTip(owner, lines)
	GameTooltip:SetOwner(owner, "ANCHOR_CURSOR")
	GameTooltip:SetText(lines[1][1], lines[1][2], lines[1][3], lines[1][4])
	for i = 2, table.getn(lines) do
		local l = lines[i]
		GameTooltip:AddLine(l[1], l[2] or 1, l[3] or 1, l[4] or 1)
	end
	GameTooltip:Show()
end

-- hover text of a class: members, how many have a spec, and every spec with its count
local function ClassTip(c, total)
	local r, g, b = BG.Notes.ClassColor(c.key)
	local lines = { { ClassLabel(c.key), r, g, b } }
	table.insert(lines, { BG.T("stats_members", c.total, Pct(c.total, total)), 1, 1, 1 })
	local known = c.total - c.unknown
	local specs = BG.Notes.Specs(c.key)
	table.insert(lines, { BG.T("stats_specs_known", known, c.total), 0.7, 0.7, 0.7 })
	for j = 1, table.getn(specs) do
		local n = c.specs[specs[j][1]] or 0
		if n > 0 then
			local rc = ROLE_COL[specs[j][4]]
			table.insert(lines, { "  " .. BG.Notes.SpecName(specs[j]) .. ":  " .. n, rc[1], rc[2], rc[3] })
		end
	end
	if c.unknown > 0 then table.insert(lines, { "  " .. BG.T("stats_unknown_spec") .. ":  " .. c.unknown, 0.55, 0.58, 0.66 }) end
	table.insert(lines, { BG.T("stats_click_class"), 0.5, 0.5, 0.5 })
	return lines
end

-- hover text of a role slice: which classes / specs make it up
local function RoleTip(role, n, rolesData, inRange)
	local col = ROLE_COL[role] or { 0.55, 0.58, 0.66 }
	local title = (role == "?") and BG.T("stats_unknown") or BG.Notes.RoleName(role)
	local lines = { { title, col[1], col[2], col[3] } }
	table.insert(lines, { BG.T("stats_members", n, Pct(n, inRange)), 1, 1, 1 })
	local items = {}
	for label, c in pairs(rolesData.detail[role]) do table.insert(items, { label = label, n = c }) end
	table.sort(items, function(a, b)
		if a.n ~= b.n then return a.n > b.n end
		return a.label < b.label
	end)
	for i = 1, table.getn(items) do
		if i > 12 then table.insert(lines, { "  ...", 0.6, 0.6, 0.6 }) break end
		table.insert(lines, { "  " .. items[i].label .. ":  " .. items[i].n, col[1], col[2], col[3] })
	end
	return lines
end

local function SpecTip(seg, c)
	local lines = { { seg.label, seg.r, seg.g, seg.b } }
	table.insert(lines, { BG.T("stats_members", seg.n, Pct(seg.n, c.total)), 1, 1, 1 })
	if seg.role then
		local rc = ROLE_COL[seg.role]
		table.insert(lines, { BG.Notes.RoleName(seg.role), rc[1], rc[2], rc[3] })
	end
	return lines
end

---------------------------------------------------------------- window

local function Name(prefix)
	Stats.counter = (Stats.counter or 0) + 1
	return "BananaGuildStats" .. prefix .. Stats.counter
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

	local logo = win:CreateTexture(nil, "ARTWORK")
	logo:SetTexture(BG.LOGO)
	logo:SetWidth(44)
	logo:SetHeight(44)
	logo:SetPoint("TOPLEFT", win, "TOPLEFT", 14, -12)
	win.title = win:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	win.title:SetPoint("TOPLEFT", win, "TOPLEFT", 66, -16)
	win.sub = win:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	win.sub:SetPoint("TOPLEFT", win, "TOPLEFT", 66, -38)

	win.btnClasses = BG.MakeButton(win, Name("Btn"), 100, 24, "")
	win.btnClasses:SetPoint("TOPLEFT", win, "TOPLEFT", RX, -18)
	win.btnClasses:SetScript("OnClick", function() Stats.mode = "classes" Stats.Refresh(true) end)
	win.btnSpecs = BG.MakeButton(win, Name("Btn"), 160, 24, "")
	win.btnSpecs:SetPoint("LEFT", win.btnClasses, "RIGHT", 6, 0)
	win.btnSpecs:SetScript("OnClick", function() Stats.mode = "specs" Stats.Refresh(true) end)
	win.btnRoles = BG.MakeButton(win, Name("Btn"), 90, 24, "")
	win.btnRoles:SetPoint("LEFT", win.btnSpecs, "RIGHT", 6, 0)
	win.btnRoles:SetScript("OnClick", function() Stats.mode = "roles" Stats.Refresh(true) end)

	-- the chart: a button (click on a slice), strips inside, the ring overlay on top
	win.chart = CreateFrame("Button", Name("Chart"), win)
	win.chart:SetWidth(2 * (R + MARGIN))
	win.chart:SetHeight(2 * (R + MARGIN))
	win.chart:SetPoint("CENTER", win, "TOPLEFT", CX, CY)
	win.chart:EnableMouse(true)
	win.mask = win.chart:CreateTexture(nil, "OVERLAY")
	win.mask:SetTexture(BG.MEDIA .. "donut")
	win.mask:SetAllPoints(win.chart)
	-- centre text (inside the hole)
	win.cBig = win.chart:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	win.cBig:SetPoint("CENTER", win.chart, "CENTER", 0, 12)
	win.cBig:SetWidth(2 * R * HOLE - 20)
	win.cSmall = win.chart:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	win.cSmall:SetPoint("CENTER", win.chart, "CENTER", 0, -12)
	win.cSmall:SetWidth(2 * R * HOLE - 20)
	win.empty = win.chart:CreateFontString(nil, "OVERLAY", "GameFontDisable")
	win.empty:SetPoint("CENTER", win.chart, "CENTER", 0, 0)

	win.chart:SetScript("OnClick", function()
		local idx = Stats.hover
		if idx and Stats.mode == "classes" and Stats.cur and Stats.cur.segs[idx] then Stats.SelectClass(Stats.cur.segs[idx].key) end
	end)
	win.chart:SetScript("OnLeave", function() Stats.hover = nil GameTooltip:Hide() end)

	-- right hand side header + class buttons + roles
	win.hdr = win:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	win.hdr:SetPoint("TOPLEFT", win, "TOPLEFT", RX, -58)
	win.classBtns = {}
	for i = 1, 9 do
		local b = BG.MakeButton(win, Name("CBtn"), 116, 22, "")
		b:Hide()
		win.classBtns[i] = b
	end
	win.roleBar = {}
	for i = 1, 4 do
		local t = win:CreateTexture(nil, "ARTWORK")
		t:Hide()
		win.roleBar[i] = t
	end
	win.roleHdr = win:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	win.roleTxt = win:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	win.roleTxt:SetWidth(RW)
	win.roleTxt:SetJustifyH("LEFT")

	-- level range (mode "roles"): from / to and quick buttons
	win.rngLbl1 = win:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	win.rngLbl1:SetPoint("TOPLEFT", win, "TOPLEFT", RX, -86)
	local function RangeBox(x)
		local e = CreateFrame("EditBox", Name("Range"), win, "InputBoxTemplate")
		e:SetWidth(36)
		e:SetHeight(20)
		e:SetPoint("TOPLEFT", win, "TOPLEFT", x, -82)
		e:SetAutoFocus(false)
		e:SetNumeric(true)
		e:SetMaxLetters(2)
		e:SetScript("OnEscapePressed", function() this:ClearFocus() end)
		e:SetScript("OnEnterPressed", function() this:ClearFocus() end)
		e:SetScript("OnEditFocusLost", function()
			Stats.SetRange(win.rngMin:GetText(), win.rngMax:GetText())
		end)
		e:Hide()
		return e
	end
	win.rngMin = RangeBox(RX + 84)
	win.rngLbl2 = win:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	win.rngLbl2:SetPoint("TOPLEFT", win, "TOPLEFT", RX + 132, -86)
	win.rngMax = RangeBox(RX + 164)
	win.presets = {}
	local PRE = { { "stats_pre_40", 40, 60 }, { "stats_pre_50", 50, 60 }, { "stats_pre_60", 60, 60 }, { "stats_pre_all", 1, 60 } }
	for i = 1, 4 do
		local lo, hi = PRE[i][2], PRE[i][3]
		local b = BG.MakeButton(win, Name("Pre"), 82, 22, "")
		b:SetPoint("TOPLEFT", win, "TOPLEFT", RX + (i - 1) * 88, -110)
		b.key = PRE[i][1]
		b.lo, b.hi = lo, hi
		b:SetScript("OnClick", function() Stats.SetRange(this.lo, this.hi) end)
		b:Hide()
		win.presets[i] = b
	end
	win.rngInfo = win:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	win.rngInfo:SetPoint("TOPLEFT", win, "TOPLEFT", RX, -138)
	win.rngInfo:SetWidth(RW)
	win.rngInfo:SetJustifyH("LEFT")

	-- hover over the chart: which slice?
	win.chart.t = 0
	win.chart:SetScript("OnUpdate", function()
		if job then PaintStep() end
		this.t = this.t + arg1
		if this.t < 0.04 then return end
		this.t = 0
		if not Stats.cur or not (MouseIsOver and MouseIsOver(this)) then
			if Stats.hover then Stats.hover = nil GameTooltip:Hide() end
			return
		end
		local x, y = GetCursorPosition()
		local s = this:GetEffectiveScale()
		x, y = x / s, y / s
		local idx = Stats.HitTest(x - (this:GetLeft() + R + MARGIN), y - (this:GetTop() - R - MARGIN))
		if idx ~= Stats.hover then
			Stats.hover = idx
			if idx then Stats.ShowTip(this, Stats.tips[idx]) else GameTooltip:Hide() end
		end
	end)
end

function Stats.SelectClass(key)
	Stats.class = key
	Stats.mode = "specs"
	Stats.Refresh(true)
end

local function Header(text)
	win.hdr:SetText(text)
end

-- force = repaint even when the numbers did not change
function Stats.Refresh(force)
	if not win or not win:IsShown() then return end
	local list, total = Stats.Collect()
	local classSegs = Stats.ClassSegments(list, total)
	local byKey = {}
	for i = 1, table.getn(list) do byKey[list[i].key] = list[i] end
	if not Stats.class or not byKey[Stats.class] then Stats.class = list[1] and list[1].key or nil end
	local cur = Stats.class and byKey[Stats.class]

	local rangeLo, rangeHi = Stats.Range()
	local rd
	if Stats.mode == "roles" then rd = Stats.CollectRoles(rangeLo, rangeHi) end

	-- signature: only repaint when something visible changed
	local sig = Stats.mode .. ":" .. tostring(Stats.class) .. ":" .. total
	if rd then sig = sig .. ":" .. rangeLo .. "-" .. rangeHi .. ":" .. rd.T .. "," .. rd.H .. "," .. rd.D .. "," .. rd["?"] end
	for i = 1, table.getn(list) do
		local c = list[i]
		sig = sig .. "," .. c.key .. c.total .. "/" .. c.unknown
		for code, n in pairs(c.specs) do sig = sig .. code .. n end
	end

	win.title:SetText(GOLD .. BG.T("stats_title") .. "|r")
	win.sub:SetText(BG.T("stats_total", total))
	win.btnClasses:SetText(BG.T("stats_classes"))
	win.btnSpecs:SetText(BG.T("stats_specs"))
	win.btnRoles:SetText(BG.T("stats_roles_btn"))
	Mark(win.btnClasses, Stats.mode == "classes")
	Mark(win.btnSpecs, Stats.mode == "specs")
	Mark(win.btnRoles, Stats.mode == "roles")
	if not force and sig == Stats.sig then return end
	Stats.sig = sig

	for i = 1, table.getn(win.classBtns) do win.classBtns[i]:Hide() end
	for i = 1, table.getn(win.roleBar) do win.roleBar[i]:Hide() end
	win.roleHdr:SetText("")
	win.roleTxt:SetText("")
	-- range controls only in the roles view
	local rolesMode = (Stats.mode == "roles")
	win.rngLbl1:SetText(rolesMode and BG.T("stats_range_from") or "")
	win.rngLbl2:SetText(rolesMode and BG.T("stats_range_to") or "")
	win.rngInfo:SetText("")
	if rolesMode then
		win.rngMin:Show() win.rngMax:Show()
		win.rngMin:SetText(rangeLo) win.rngMax:SetText(rangeHi)
	else
		win.rngMin:Hide() win.rngMax:Hide()
	end
	for i = 1, table.getn(win.presets) do
		local b = win.presets[i]
		if rolesMode then
			b:SetText(BG.T(b.key))
			Mark(b, b.lo == rangeLo and b.hi == rangeHi)
			b:Show()
		else
			b:Hide()
		end
	end
	if rolesMode then
		-- donut of Tank / Heal / DD / unknown for the level range
		local segs = {}
		local order = { "T", "H", "D", "?" }
		Stats.tips = {}
		local entries = {}
		local max = 0
		for i = 1, 4 do if rd[order[i]] > max then max = rd[order[i]] end end
		for i = 1, 4 do
			local role = order[i]
			local n = rd[role]
			if n > 0 then
				local col = ROLE_COL[role] or { 0.30, 0.33, 0.42 }
				local label = (role == "?") and BG.T("stats_unknown") or BG.Notes.RoleName(role)
				table.insert(segs, { n = n, r = col[1], g = col[2], b = col[3], label = label, role = role })
			end
		end
		if rd.inRange == 0 then
			for i = 1, table.getn(pool) do pool[i].tex:Hide() end
			used = 0
			job = nil
			Stats.cur = nil
			win.cBig:SetText("")
			win.cSmall:SetText("")
			win.empty:SetText(BG.T("stats_range_empty", rangeLo, rangeHi))
			ShowRows({}, 0)
			Header(BG.T("stats_hdr_roles"))
			return
		end
		StartPaint(segs)
		win.cBig:SetText(GOLD .. rd.inRange .. "|r")
		win.cSmall:SetText(BG.T("stats_range_center", rangeLo, rangeHi))
		Header(BG.T("stats_hdr_roles"))
		win.rngInfo:SetText(GRAY .. BG.T("stats_range_info", rd.inRange, rd.total) .. "|r")
		for i = 1, table.getn(segs) do
			local sg = segs[i]
			local tip = RoleTip(sg.role, sg.n, rd, rd.inRange)
			Stats.tips[i] = tip
			table.insert(entries, { r = sg.r, g = sg.g, b = sg.b, label = sg.label, n = sg.n, pct = GRAY .. Pct(sg.n, rd.inRange) .. "|r",
				share = sg.n / math.max(max, 1), tip = tip })
		end
		ShowRows(entries, -168)
		return
	end
	if total == 0 or not cur then
		for i = 1, table.getn(pool) do pool[i].tex:Hide() end
		used = 0
		job = nil
		Stats.cur = nil
		win.cBig:SetText("")
		win.cSmall:SetText("")
		win.empty:SetText(BG.T("stats_empty"))
		ShowRows({}, 0)
		Header("")
		return
	end
	win.empty:SetText("")
	Stats.tips = {}

	if Stats.mode == "classes" then
		StartPaint(classSegs)
		win.cBig:SetText(GOLD .. total .. "|r")
		win.cSmall:SetText(BG.T("stats_chars"))
		Header(BG.T("stats_hdr_classes"))
		local max = 0
		for i = 1, table.getn(classSegs) do if classSegs[i].n > max then max = classSegs[i].n end end
		local entries = {}
		for i = 1, table.getn(classSegs) do
			local s = classSegs[i]
			local tip = ClassTip(s.class, total)
			Stats.tips[i] = tip
			local key = s.key
			table.insert(entries, { r = s.r, g = s.g, b = s.b, label = s.label, n = s.n, pct = GRAY .. Pct(s.n, total) .. "|r",
				share = s.n / max, tip = tip, onClick = function() Stats.SelectClass(key) end })
		end
		ShowRows(entries, -86)
		-- roles over the whole guild (from the specs in the notes)
		local roles = { T = 0, H = 0, D = 0 }
		local known = 0
		for i = 1, table.getn(list) do
			for k, v in pairs(list[i].roles) do roles[k] = roles[k] + v end
			known = known + (list[i].total - list[i].unknown)
		end
		local unknown = total - known
		local y = -86 - table.getn(classSegs) * ROW_H - 12
		win.roleHdr:ClearAllPoints()
		win.roleHdr:SetPoint("TOPLEFT", win, "TOPLEFT", RX, y)
		win.roleHdr:SetText(BG.T("stats_roles"))
		local parts = { { "T", roles.T }, { "H", roles.H }, { "D", roles.D }, { "?", unknown } }
		local x = 0
		for i = 1, 4 do
			local t = win.roleBar[i]
			local n = parts[i][2]
			local w = math.floor(RW * n / total + 0.5)
			if n > 0 and w < 2 then w = 2 end
			local col = ROLE_COL[parts[i][1]] or { 0.30, 0.33, 0.42 }
			t:ClearAllPoints()
			t:SetPoint("TOPLEFT", win, "TOPLEFT", RX + x, y - 20)
			t:SetWidth(math.max(w, 1))
			t:SetHeight(12)
			t:SetTexture(col[1], col[2], col[3], 1)
			if n > 0 then t:Show() else t:Hide() end
			x = x + w
		end
		win.roleTxt:ClearAllPoints()
		win.roleTxt:SetPoint("TOPLEFT", win, "TOPLEFT", RX, y - 38)
		win.roleTxt:SetText(Hex(unpack(ROLE_COL.T)) .. BG.T("role_tank") .. " " .. roles.T .. "|r    " ..
			Hex(unpack(ROLE_COL.H)) .. BG.T("role_heal") .. " " .. roles.H .. "|r    " ..
			Hex(unpack(ROLE_COL.D)) .. BG.T("role_dd") .. " " .. roles.D .. "|r    " ..
			GRAY .. BG.T("stats_unknown") .. " " .. unknown .. "|r")
	else
		-- one class: its specs
		local segs = Stats.SpecSegments(cur)
		StartPaint(segs)
		local r, g, b = BG.Notes.ClassColor(cur.key)
		win.cBig:SetText(Hex(r, g, b) .. ClassLabel(cur.key) .. "|r")
		win.cSmall:SetText(BG.T("stats_class_members", cur.total))
		Header(BG.T("stats_pick"))
		-- class buttons (3 x 3), coloured names with their member count
		for i = 1, table.getn(list) do
			local c = list[i]
			local b2 = win.classBtns[i]
			local key = c.key
			local cr, cg, cb = BG.Notes.ClassColor(key)
			b2:ClearAllPoints()
			local col = (i - 1) - math.floor((i - 1) / 3) * 3
			local row = math.floor((i - 1) / 3)
			b2:SetPoint("TOPLEFT", win, "TOPLEFT", RX + col * 123, -82 - row * 26)
			b2:SetText(Hex(cr, cg, cb) .. ClassLabel(key) .. "|r " .. GRAY .. c.total .. "|r")
			b2:SetScript("OnClick", function() Stats.SelectClass(key) end)
			Mark(b2, key == cur.key)
			b2:Show()
		end
		local rowsBelow = math.ceil(table.getn(list) / 3)
		local entries = {}
		for i = 1, table.getn(segs) do
			local s = segs[i]
			Stats.tips[i] = SpecTip(s, cur)
			local role = ""
			if s.role then role = "  " .. Hex(unpack(ROLE_COL[s.role])) .. BG.Notes.RoleName(s.role) .. "|r" end
			table.insert(entries, { r = s.r, g = s.g, b = s.b, label = s.label .. role, n = s.n, pct = GRAY .. Pct(s.n, cur.total) .. "|r",
				share = s.n / cur.total, tip = Stats.tips[i] })
		end
		ShowRows(entries, -82 - rowsBelow * 26 - 16)
	end
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
