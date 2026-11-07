--[[
  BananaGuild - Activity
  Analysis for the "Aktivität" tab: heatmap (weekday x hour, server time) of the members online, of joins and of leaves,
  a short evaluation text and the inactivity overview.
  The online numbers come from BananaActivity.lua (measured by every client with BananaGuild or BananaBank and shared over
  the guild addon channel), joins and leaves come from the history (BG.db.log).
]]

local BG = BananaGuild
local Act = {}
BG.Activity = Act

local DAYS = {
	de = { [0] = "Mo", "Di", "Mi", "Do", "Fr", "Sa", "So" },
	en = { [0] = "Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun" },
}

function Act.DayName(d)
	local l = (BG.db and BG.db.lang == "en") and "en" or "de"
	return DAYS[l][d]
end

function Act.Store()
	BG.db.activity = BG.db.activity or {}
	local s = BG.db.activity
	s.a = s.a or {}
	s.b = s.b or {}
	return s
end

function Act.Init()
	local s = Act.Store()
	if BananaActivity and BananaActivity.Init then BananaActivity.Init(s) end
	if BananaActivity then BananaActivity.onData = function() if BG.UI and BG.UI.Refresh then BG.UI.Refresh("activity") end end end
end

local function Idx(t)
	if BananaActivity then return BananaActivity.HourIndex(t) end
	return math.floor((t or time()) / 3600)
end

local function WeekHour(idx)
	return math.mod(math.floor(idx / 24) + 3, 7), math.mod(idx, 24)
end

function Act.Now()
	local d, h = WeekHour(Idx())
	return d, h
end

--------------------------------------------------------------------- grids

local function NewGrid()
	local g = { v = {}, n = {}, max = 0, total = 0, count = 0 }
	for d = 0, 6 do
		g.v[d], g.n[d] = {}, {}
		for h = 0, 23 do g.v[d][h] = 0; g.n[d][h] = 0 end
	end
	return g
end

-- kind: "online" | "join" | "leave"; weeks: window; only60: only for "online"
function Act.Grid(kind, weeks, only60)
	local g = NewGrid()
	local now = Idx()
	local from = now - weeks * 168
	if kind == "online" then
		local s = Act.Store()
		local src = only60 and s.b or s.a
		local sum = NewGrid()
		for idx, val in pairs(s.a) do
			if idx > from and idx <= now then
				local d, h = WeekHour(idx)
				sum.v[d][h] = sum.v[d][h] + (src[idx] or 0)
				sum.n[d][h] = sum.n[d][h] + 1
				g.count = g.count + 1
				if not g.first or idx < g.first then g.first = idx end
			end
		end
		for d = 0, 6 do for h = 0, 23 do
			local n = sum.n[d][h]
			g.n[d][h] = n
			if n > 0 then
				g.v[d][h] = sum.v[d][h] / n
				if g.v[d][h] > g.max then g.max = g.v[d][h] end
			end
		end end
		return g
	end
	local log = BG.db.log or {}
	local lim = time() - weeks * 7 * 86400
	for i = 1, table.getn(log) do
		local e = log[i]
		local hit = (kind == "join" and e.k == "join") or (kind == "leave" and (e.k == "leave" or e.k == "kick"))
		if hit and e.t and e.t >= lim then
			local d, h = WeekHour(Idx(e.t))
			g.v[d][h] = g.v[d][h] + 1
			g.count = g.count + 1
			if g.v[d][h] > g.max then g.max = g.v[d][h] end
		end
	end
	return g
end

--------------------------------------------------------------------- evaluation

local function SpanLabel(days)
	local n = table.getn(days)
	if n == 1 then return Act.DayName(days[1]) end
	if n == 2 and days[1] == 5 then return Act.DayName(5) .. "/" .. Act.DayName(6) end
	return Act.DayName(days[1]) .. "-" .. Act.DayName(days[n])
end

local function HourLabel(start, len)
	return start .. "-" .. math.mod(start + len, 24)
end

local function Spans(cyclic3)
	local out = {}
	if cyclic3 then
		for s = 0, 6 do out[table.getn(out) + 1] = { math.mod(s, 7), math.mod(s + 1, 7), math.mod(s + 2, 7) } end
	else
		out[1] = { 0, 1, 2, 3, 4 }
		out[2] = { 5, 6 }
	end
	return out
end

-- best (or worst) rectangle: mean for online, sum for events. returns span, startHour, value
local function Rect(g, spans, len, worst, sum)
	local best, bs, bh, bv
	for i = 1, table.getn(spans) do
		local days = spans[i]
		for h = 0, 23 do
			local tot, cells = 0, 0
			for _, d in ipairs(days) do
				for k = 0, len - 1 do
					tot = tot + g.v[d][math.mod(h + k, 24)]
					cells = cells + 1
				end
			end
			local val = sum and tot or (tot / cells)
			if bv == nil or (worst and val < bv) or (not worst and val > bv) then
				bv, best, bs, bh = val, days, i, h
			end
		end
	end
	return best, bh, bv
end

local function Fmt1(x)
	return string.format("%.1f", x)
end

-- text lines (already with locale), kind as in Grid
function Act.Lines(kind, g)
	local out = {}
	if kind == "online" then
		if g.count < 24 then
			table.insert(out, BG.T("act_none"))
			return out
		end
		local pd, ph, pv = Rect(g, Spans(false), 3, false)
		local wd, wh, wv = Rect(g, Spans(false), 5, true)
		table.insert(out, BG.T("act_peak", SpanLabel(pd), HourLabel(ph, 3), Fmt1(pv), SpanLabel(wd), HourLabel(wh, 5), Fmt1(wv)))
		return out
	end
	local total = g.count
	if total < 3 then
		table.insert(out, BG.T("act_few", total))
		return out
	end
	local days, h, v = Rect(g, Spans(true), 3, false, true)
	table.insert(out, BG.T(kind == "join" and "act_join_best" or "act_leave_best", SpanLabel(days), HourLabel(h, 3), v, total))
	return out
end

function Act.Basis(kind, g)
	if kind == "online" then
		if g.count == 0 then return BG.T("act_basis_none") end
		return BG.T("act_basis", g.count, g.first and date("%d.%m.", (g.first - (BananaActivity and BananaActivity.Offset() or 0)) * 3600) or "?")
	end
	return BG.T("act_basis_log", g.count)
end

--------------------------------------------------------------------- inactivity

Act.BUCKETS = {
	{ key = "act_b_now",  from = -1, to = -1 },
	{ key = "act_b_1",    from = 0, to = 1 },
	{ key = "act_b_3",    from = 1, to = 3 },
	{ key = "act_b_7",    from = 3, to = 7 },
	{ key = "act_b_14",   from = 7, to = 14 },
	{ key = "act_b_30",   from = 14, to = 30 },
	{ key = "act_b_more", from = 30, to = 99999 },
}

-- counts per bucket + list of members offline for at least 'minDays' (longest first)
function Act.Inactivity(minDays)
	local counts = {}
	for i = 1, table.getn(Act.BUCKETS) do counts[i] = 0 end
	local list, total, unknown = {}, 0, 0
	for name, info in pairs(BG.roster or {}) do
		total = total + 1
		if info.online then
			counts[1] = counts[1] + 1
		elseif info.offlineDays == nil then
			unknown = unknown + 1
		else
			local d = info.offlineDays
			for i = 2, table.getn(Act.BUCKETS) do
				local b = Act.BUCKETS[i]
				if d >= b.from and (d < b.to or i == table.getn(Act.BUCKETS)) then counts[i] = counts[i] + 1 break end
			end
			if d >= minDays then table.insert(list, { name = name, rank = info.rank, days = d }) end
		end
	end
	table.sort(list, function(a, b)
		if a.days ~= b.days then return a.days > b.days end
		return a.name < b.name
	end)
	return counts, list, total, unknown
end

BG.OnInit(function() Act.Init() end)

BananaGuild.files.Activity = true
