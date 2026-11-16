--[[
  BananaGuild - Presence / Analytics
  Who in the guild has which Banana addon installed (and running)?
  Data sources:
    * invisible guild addon channel: every client with BananaPresence says "H|craft=1.0,bank=2.1" once per login
    * dashboard "Query" button: asks everybody online to answer right now
    * optional hidden world-chat ping (opt-in)
  Everything is stored in BananaGuildDB.presence so the history survives relogs.
]]

local BG = BananaGuild
local Presence = {}
BG.files = BG.files or {}
if BananaPresence then BG.files.BananaPresence = true end
BG.Presence = Presence

-- state: 2 = loaded/running, 1 = installed but disabled, 0 = not found
function Presence.Detect(entry)
	for i = 1, table.getn(entry.aliases) do
		local alias = entry.aliases[i]
		local ver = GetAddOnMetadata and GetAddOnMetadata(alias, "Version")
		if IsAddOnLoaded and IsAddOnLoaded(alias) then
			return 2, ver or "?"
		end
		if GetAddOnInfo then
			local ok, name = pcall(GetAddOnInfo, alias)
			if ok and name then return 1, ver or "?" end
		end
	end
	return 0, nil
end

function Presence.LocalAddons()
	local t = {}
	for i = 1, table.getn(BG.TRACKED) do
		local e = BG.TRACKED[i]
		local state, ver = Presence.Detect(e)
		if e.key == "guild" then state, ver = 2, BG.version end
		if state == 2 then t[e.key] = ver
		elseif state == 1 then t[e.key] = (ver or "?") .. "~" end
	end
	return t
end

local function TrimDays(p)
	local keys = {}
	for d in pairs(p.days) do table.insert(keys, d) end
	if table.getn(keys) > 90 then
		table.sort(keys)
		for i = 1, table.getn(keys) - 90 do p.days[keys[i]] = nil end
	end
end

function Presence.Record(name, addons, source)
	if not name or name == "" then return end
	name = BG.NormName(name)
	local p = BG.db.presence[name]
	if not p then
		p = { first = time(), count = 0, days = {}, addons = {} }
		BG.db.presence[name] = p
	end
	p.last = time()
	p.src = source or p.src
	local today = date("%Y%m%d")
	if not p.days[today] then
		p.days[today] = 1
		p.count = p.count + 1
		TrimDays(p)
	end
	p.addons = {}
	for k, v in pairs(addons or {}) do p.addons[k] = v end
	if BG.UI and BG.UI.Refresh then BG.UI.Refresh("addons") end
end

-- version string, running?  (trailing "~" = installed but disabled)
function Presence.Split(v)
	if not v then return nil, false end
	if string.sub(v, -1) == "~" then return string.sub(v, 1, -2), false end
	return v, true
end

function Presence.Stats()
	local now = time()
	local res = { guildTotal = BG.Roster.Count(), seen = 0, outside = 0, byKey = {} }
	for i = 1, table.getn(BG.TRACKED) do
		res.byKey[BG.TRACKED[i].key] = { installed = 0, running = 0, active7 = 0, active30 = 0 }
	end
	for name, p in pairs(BG.db.presence) do
		if BG.Roster.IsMember(name) then
			res.seen = res.seen + 1
			for key, v in pairs(p.addons or {}) do
				local row = res.byKey[key]
				if row then
					local _, running = Presence.Split(v)
					row.installed = row.installed + 1
					if running then
						row.running = row.running + 1
						if (p.last or 0) >= now - 7 * 86400 then row.active7 = row.active7 + 1 end
						if (p.last or 0) >= now - 30 * 86400 then row.active30 = row.active30 + 1 end
					end
				end
			end
		else
			res.outside = res.outside + 1
		end
	end
	return res
end

-- rows for the member table: guild members with a presence record (and optionally everybody)
function Presence.Rows(showAll)
	local rows = {}
	for name, p in pairs(BG.db.presence) do
		if BG.Roster.IsMember(name) then
			table.insert(rows, { name = name, p = p })
		end
	end
	if showAll then
		for name in pairs(BG.roster or {}) do
			if not BG.db.presence[name] then table.insert(rows, { name = name }) end
		end
	end
	table.sort(rows, function(a, b)
		local la = a.p and a.p.last or 0
		local lb = b.p and b.p.last or 0
		if la ~= lb then return la > lb end
		return a.name < b.name
	end)
	return rows
end

--------------------------------------------------------------------- grouped list for the addons tab

-- "none" | "off" (installed, not running) | version string
function Presence.AddonState(name, key)
	local rec = BG.db.presence[name]
	local v = rec and rec.addons and rec.addons[key]
	if not v then return "none" end
	local ver, running = Presence.Split(v)
	if not running then return "off", ver end
	return ver
end

local function VerParts(v)
	local t = {}
	for n in string.gfind(v or "", "%d+") do table.insert(t, tonumber(n)) end
	return t
end

-- true when version a is newer than b
local function VerNewer(a, b)
	local x, y = VerParts(a), VerParts(b)
	for i = 1, math.max(table.getn(x), table.getn(y)) do
		local p, q = x[i] or 0, y[i] or 0
		if p ~= q then return p > q end
	end
	return false
end

-- sort value of a character for one addon: rank 0 = not installed, 1 = installed but off, 2 = running version
local function Val(name, key)
	local st = Presence.AddonState(name, key)
	if st == "none" then return { r = 0 } end
	if st == "off" then return { r = 1 } end
	return { r = 2, v = st }
end

-- true when a is strictly higher than b (running version above off above not installed)
local function Higher(a, b)
	if a.r ~= b.r then return a.r > b.r end
	if a.r == 2 then return VerNewer(a.v, b.v) end
	return false
end

-- Rows grouped by main: { kind = "main" | "twink", name, root, twinks = n, expanded = bool, p = presence record }
-- sort = { col = "name" | "last" | addon key, desc = bool }. Characters without the addon always come last.
-- A group is sorted by its best member (highest version when descending, lowest installed version when ascending).
function Presence.AddonRows(open, sort)
	sort = sort or { col = "last", desc = true }
	local col, desc = sort.col, sort.desc
	local isAddon = (col ~= "name" and col ~= "last")
	local groups, order = {}, {}
	for name in pairs(BG.roster or {}) do
		local root = BG.Roster.RootOf(name)
		if not groups[root] then groups[root] = { main = root, twinks = {}, last = 0, members = {} } table.insert(order, root) end
		local g = groups[root]
		if name ~= root then table.insert(g.twinks, name) end
		table.insert(g.members, name)
		local rec = BG.db.presence[name]
		if rec and (rec.last or 0) > g.last then g.last = rec.last end
	end
	-- best value of the group for the sorted addon column
	for _, g in pairs(groups) do
		if isAddon then
			local best
			for i = 1, table.getn(g.members) do
				local v = Val(g.members[i], col)
				if v.r > 0 then
					if not best then best = v
					elseif desc and Higher(v, best) then best = v
					elseif (not desc) and Higher(best, v) then best = v end
				end
			end
			g.val = best or { r = 0 }
		end
	end
	local function Tie(a, b, la, lb)
		if la ~= lb then return la > lb end
		return a < b
	end
	table.sort(order, function(a, b)
		local ga, gb = groups[a], groups[b]
		if col == "name" then
			if desc then return a > b end
			return a < b
		elseif col == "last" then
			if desc then return Tie(a, b, ga.last, gb.last) end
			if ga.last ~= gb.last then return ga.last < gb.last end
			return a < b
		end
		local va, vb = ga.val, gb.val
		if va.r == 0 or vb.r == 0 then
			if va.r ~= vb.r then return va.r > vb.r end
			return Tie(a, b, ga.last, gb.last)
		end
		if Higher(va, vb) then return desc end
		if Higher(vb, va) then return not desc end
		return Tie(a, b, ga.last, gb.last)
	end)
	local rows = {}
	for i = 1, table.getn(order) do
		local g = groups[order[i]]
		table.sort(g.twinks, function(a, b)
			if isAddon then
				local va, vb = Val(a, col), Val(b, col)
				if va.r == 0 or vb.r == 0 then
					if va.r ~= vb.r then return va.r > vb.r end
				elseif Higher(va, vb) then return desc
				elseif Higher(vb, va) then return not desc end
			elseif col == "name" then
				return desc and a > b or ((not desc) and a < b)
			end
			return a < b
		end)
		local expanded = (open and open[g.main]) and true or false
		table.insert(rows, { kind = "main", name = g.main, root = g.main, twinks = table.getn(g.twinks),
			expanded = expanded, p = BG.db.presence[g.main] })
		if expanded then
			for j = 1, table.getn(g.twinks) do
				table.insert(rows, { kind = "twink", name = g.twinks[j], root = g.main, p = BG.db.presence[g.twinks[j]] })
			end
		end
	end
	return rows
end

local lastAutoQuery = -10000
-- quiet ask "who is there?" when the tab is opened (at most every 15 minutes)
function Presence.AutoQuery()
	if GetTime() - lastAutoQuery < 900 then return end
	lastAutoQuery = GetTime()
	Presence.Query(true)
end

function Presence.Query(quiet)
	if not IsInGuild or not IsInGuild() then if not quiet then BG.Print(BG.T("not_in_guild")) end return end
	if not SendAddonMessage then if not quiet then BG.Print(BG.T("no_addon_msg")) end return end
	if BG.Send("Q") then
		if not quiet then BG.Print(BG.T("query_sent")) end
		if BananaPresence then BananaPresence.SendGuildHello() end
	elseif not quiet then
		BG.Print(BG.T("comm_disabled"))
	end
end

function Presence.Apply()
	if not BananaPresence then return end
	BananaPresence.SetWorldPing(BG.db.features.worldPing)
	BananaPresence.SetWorldChannel(BG.db.recruit.chMain)
end

-- The registry must be filled at PLAYER_LOGIN, not at load time: addons that load after BananaGuild
-- (BananaLoot, BananaLootline ...) are not "loaded" yet while our own files execute.
local function RegisterLocal()
	if not BananaPresence then return end
	for key, ver in pairs(Presence.LocalAddons()) do
		local label = key
		for i = 1, table.getn(BG.TRACKED) do
			if BG.TRACKED[i].key == key then label = BG.TRACKED[i].label end
		end
		BananaPresence.Register(key, label, ver)
	end
end

BG.OnInit(function()
	if not BananaPresence then return end
	Presence.Apply()
	BananaPresence.Listen(function(sender, addons, source)
		Presence.Record(sender, addons, source)
	end)
end)

BG.OnLogin(function()
	RegisterLocal()
	-- our own record (this also counts our own session for the analytics)
	Presence.Record(BG.me, Presence.LocalAddons(), "self")
end)

BananaGuild = BananaGuild or {}
BananaGuild.files = BananaGuild.files or {}
BananaGuild.files.Presence = true
