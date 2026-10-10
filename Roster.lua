--[[
  BananaGuild - Roster
  * reads the guild roster, detects level ups (-> Alerts)
  * parses guild system messages into the log (join / leave / kick / promote / demote)
  * main / twink assignment (self maintained, synced to other BananaGuild users)
]]

local BG = BananaGuild
local Roster = {}
BG.Roster = Roster
BG.roster = {}
Roster.scans = 0

--------------------------------------------------------------------- lookups

function Roster.IsMember(name) return name ~= nil and BG.roster[name] ~= nil end
function Roster.Info(name)     return BG.roster[name] end
function Roster.Count()        return BG.Count(BG.roster) end

--------------------------------------------------------------------- scan

local function Scan()
	if not IsInGuild or not IsInGuild() then
		BG.roster = {}
		return
	end
	local n = GetNumGuildMembers(true) or 0
	if n == 0 then return end
	local new = {}
	for i = 1, n do
		local name, rank, rankIndex, level, class, zone, note, officernote, online, status = GetGuildRosterInfo(i)
		if name then
			new[name] = {
				rank = rank, rankIndex = rankIndex or 99, level = level or 0, class = class,
				zone = zone, note = note, online = online and true or false, status = status,
			}
		end
	end
	local first = (Roster.scans == 0)
	BG.roster = new
	Roster.scans = Roster.scans + 1

	local db = BG.db
	local initial = not db.rosterInit
	for name, info in pairs(new) do
		-- level ups
		local prev = db.levels[name]
		if prev and info.level > prev and not first and info.online then
			if BG.Alerts then BG.Alerts.OnLevel(name, info.level, "roster") end
		end
		db.levels[name] = info.level
		-- newly seen characters
		if not db.chars[name] then
			db.chars[name] = {}
			if not initial then
				db.chars[name].joined = BG.Today()
				db.chars[name].approx = true
				local inv = BG.pendingInvites and BG.pendingInvites[name]
				if inv then db.chars[name].invitedBy = inv.by end
			end
		end
	end
	if initial then db.rosterInit = true end
	if BG.UI and BG.UI.Refresh then BG.UI.Refresh("members") BG.UI.Refresh("addons") end
end

BG.On("GUILD_ROSTER_UPDATE", function()
	BG.rosterDirty = true
end)

BG.OnLogin(function()
	BG.After(4, function() if IsInGuild and IsInGuild() then GuildRoster() end end)
	BG.Ticker("roster", 20, function() if IsInGuild and IsInGuild() then GuildRoster() end end)
	BG.Ticker("rosterscan", 3, function()
		if BG.rosterDirty or Roster.scans == 0 then
			BG.rosterDirty = false
			Scan()
		end
	end)
end)

Roster.Scan = Scan

--------------------------------------------------------------------- system message parsing

local function Esc(s)
	return (string.gsub(s, "([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1"))
end

local function Compile(fmt)
	local order, pat, pos, idx = {}, "", 1, 0
	while true do
		local s, e, num = string.find(fmt, "%%(%d?)%$?s", pos)
		if not s then
			pat = pat .. Esc(string.sub(fmt, pos))
			break
		end
		pat = pat .. Esc(string.sub(fmt, pos, s - 1)) .. "(.-)"
		idx = idx + 1
		if num ~= "" then order[idx] = tonumber(num) else order[idx] = idx end
		pos = e + 1
	end
	return "^" .. pat .. "$", order, idx
end
Roster.Compile = Compile

local RULES = {}
local function AddRule(kind, globalName, fallbacks)
	local list = {}
	local g = globalName and getglobal(globalName)
	if type(g) == "string" then table.insert(list, g) end
	for i = 1, table.getn(fallbacks) do table.insert(list, fallbacks[i]) end
	for i = 1, table.getn(list) do
		local pat, order, count = Compile(list[i])
		table.insert(RULES, { kind = kind, pat = pat, order = order, count = count })
	end
end

AddRule("join",    "ERR_GUILD_JOIN_S",    { "%s has joined the guild.", "%s ist der Gilde beigetreten." })
AddRule("leave",   "ERR_GUILD_LEAVE_S",   { "%s has left the guild.", "%s hat die Gilde verlassen." })
AddRule("promote", "ERR_GUILD_PROMOTE_SSS", { "%s has promoted %s to %s.", "%s hat %s zum Rang %s befördert." })
AddRule("demote",  "ERR_GUILD_DEMOTE_SSS",  { "%s has demoted %s to %s.", "%s hat %s zum Rang %s degradiert." })
AddRule("kick",    "ERR_GUILD_REMOVE_SS", { "%s has been kicked out of the guild by %s." })
AddRule("decline", "ERR_GUILD_DECLINE_S", { "%s declines your guild invitation." })

function Roster.ParseSystem(msg)
	for i = 1, table.getn(RULES) do
		local r = RULES[i]
		local caps = { string.find(msg, r.pat) }
		if caps[1] then
			local v = {}
			for j = 1, r.count do v[r.order[j]] = caps[2 + j] end
			return r.kind, v[1], v[2], v[3]
		end
	end
	return nil
end

BG.On("CHAT_MSG_SYSTEM", function(msg)
	if not msg then return end
	local kind, a, b, c = Roster.ParseSystem(msg)
	if not kind then return end
	local db = BG.db
	if kind == "join" then
		local name = BG.NormName(a)
		local ch = db.chars[name] or {}
		db.chars[name] = ch
		ch.joined = BG.Today()
		ch.approx = nil
		local inv = BG.pendingInvites and BG.pendingInvites[name]
		if inv then ch.invitedBy = inv.by end
		BG.AddLog("join", name, ch.invitedBy or "")
		db.levels[name] = db.levels[name] or 1
		if GuildRoster then GuildRoster() end
		if BG.Recruit then BG.Recruit.OnJoin(name) end
	elseif kind == "leave" then
		BG.AddLog("leave", BG.NormName(a))
	elseif kind == "kick" then
		BG.AddLog("kick", BG.NormName(a), BG.NormName(b))
	elseif kind == "promote" or kind == "demote" then
		BG.AddLog(kind, BG.NormName(a), BG.NormName(b), c)
	elseif kind == "decline" then
		BG.AddLog("decline", BG.NormName(a))
	end
	if BG.UI and BG.UI.Refresh then BG.UI.Refresh("members") end
end)

--------------------------------------------------------------------- hook: remember who we invite

BG.OnInit(function()
	if GuildInviteByName and not BG.hookedInvite then
		BG.hookedInvite = true
		local orig = GuildInviteByName
		GuildInviteByName = function(name)
			if name and name ~= "" and not BG.inInviteWrapper then
				BG.pendingInvites = BG.pendingInvites or {}
				local n = BG.NormName(name)
				if not BG.pendingInvites[n] then
					BG.pendingInvites[n] = { by = UnitName("player"), at = time() }
					BG.Send("I", n, UnitName("player"))
					BG.AddLog("invite", UnitName("player"), n)
				end
			end
			return orig(name)
		end
	end
end)

--------------------------------------------------------------------- characters: main / twink

local function Char(name)
	BG.db.chars[name] = BG.db.chars[name] or {}
	return BG.db.chars[name]
end
Roster.Char = Char

function Roster.RootOf(name)
	local c = BG.db.chars[name]
	local guard = 0
	while c and c.main and guard < 5 do
		name = c.main
		c = BG.db.chars[name]
		guard = guard + 1
	end
	return name
end

function Roster.Twinks(main)
	local out = {}
	for name, c in pairs(BG.db.chars) do
		if c.main == main then table.insert(out, name) end
	end
	table.sort(out)
	return out
end

function Roster.IsAssigned(name)
	local c = BG.db.chars[name]
	if not c then return false end
	if c.main or c.isMain then return true end
	for _, o in pairs(BG.db.chars) do
		if o.main == name then return true end
	end
	return false
end

-- alt becomes twink of main
function Roster.SetMain(alt, main, silent)
	alt, main = BG.NormName(alt), BG.NormName(main)
	if alt == "" or main == "" or alt == main then return false end
	main = Roster.RootOf(main)
	if main == alt then return false end
	Char(alt).main = main
	Char(alt).isMain = nil
	Char(main).isMain = true
	-- twinks of the alt move with it
	for name, c in pairs(BG.db.chars) do
		if c.main == alt then c.main = main end
	end
	if not silent then BG.Send("M", alt, main) end
	if BG.UI and BG.UI.Refresh then BG.UI.Refresh("members") end
	return true
end

function Roster.MarkMain(name, silent)
	name = BG.NormName(name)
	if name == "" then return false end
	Char(name).main = nil
	Char(name).isMain = true
	if not silent then BG.Send("M", name, "-") end
	if BG.UI and BG.UI.Refresh then BG.UI.Refresh("members") end
	return true
end

function Roster.Unassign(name, silent)
	name = BG.NormName(name)
	local c = BG.db.chars[name]
	if not c then return false end
	c.main = nil
	c.isMain = nil
	if not silent then BG.Send("M", name, "!") end
	if BG.UI and BG.UI.Refresh then BG.UI.Refresh("members") end
	return true
end

function Roster.SetDetails(name, joined, invitedBy, note, silent)
	name = BG.NormName(name)
	local c = Char(name)
	if joined ~= nil then c.joined = (joined ~= "" and joined) or nil; c.approx = nil end
	if invitedBy ~= nil then c.invitedBy = (invitedBy ~= "" and BG.NormName(invitedBy)) or nil end
	if note ~= nil then c.note = (note ~= "" and note) or nil end
	if not silent then BG.Send("D", name, c.joined or "-", c.invitedBy or "-") end
	if BG.UI and BG.UI.Refresh then BG.UI.Refresh("members") end
end

-- Grouped rows for the members table.
-- row = { kind = "main" | "twink", name, root, twinks = n, assigned = bool }
function Roster.Rows(filter, onlyUnassigned)
	filter = string.lower(BG.Trim(filter or ""))
	local names = {}
	for n in pairs(BG.roster) do names[n] = true end
	for n, c in pairs(BG.db.chars) do
		if c.main or c.isMain then names[n] = true end
	end
	local groups, order = {}, {}
	for n in pairs(names) do
		local root = Roster.RootOf(n)
		if not groups[root] then groups[root] = { main = root, twinks = {} } table.insert(order, root) end
		if n ~= root then table.insert(groups[root].twinks, n) end
	end
	table.sort(order)
	local rows = {}
	for i = 1, table.getn(order) do
		local g = groups[order[i]]
		table.sort(g.twinks)
		local assigned = Roster.IsAssigned(g.main)
		local match = (filter == "")
		if not match then
			if string.find(string.lower(g.main), filter, 1, true) then match = true end
			for j = 1, table.getn(g.twinks) do
				if string.find(string.lower(g.twinks[j]), filter, 1, true) then match = true end
			end
		end
		if onlyUnassigned and assigned then match = false end
		if match then
			table.insert(rows, { kind = "main", name = g.main, root = g.main, twinks = table.getn(g.twinks), assigned = assigned })
			for j = 1, table.getn(g.twinks) do
				table.insert(rows, { kind = "twink", name = g.twinks[j], root = g.main, assigned = true })
			end
		end
	end
	return rows
end

--------------------------------------------------------------------- sync

local function Trusted(sender)
	if not BG.db.sync.accept then return false end
	local info = BG.roster[sender]
	if not info then return false end
	return (info.rankIndex or 99) <= (BG.db.sync.trustRank or 2)
end

BG.OnComm("M", function(sender, p)
	if not Trusted(sender) then return end
	local alt, main = p[1], p[2]
	if not alt or not main then return end
	if main == "-" then Roster.MarkMain(alt, true)
	elseif main == "!" then Roster.Unassign(alt, true)
	else Roster.SetMain(alt, main, true) end
end)

BG.OnComm("MB", function(sender, p, raw)
	if not Trusted(sender) then return end
	for i = 1, table.getn(p) do
		local _, _, alt, main = string.find(p[i], "^(.-)>(.-)$")
		if alt and main then
			if main == "-" then Roster.MarkMain(alt, true) else Roster.SetMain(alt, main, true) end
		end
	end
end)

BG.OnComm("D", function(sender, p)
	if not Trusted(sender) then return end
	local name = p[1]
	if not name then return end
	local joined = (p[2] ~= "-") and p[2] or ""
	local by = (p[3] ~= "-") and p[3] or ""
	Roster.SetDetails(name, joined, by, nil, true)
end)

-- bundle format: "MB;alt>main;alt>main;..." (several messages if it does not fit)
function Roster.SyncAll()
	if not IsInGuild or not IsInGuild() then BG.Print(BG.T("not_in_guild")) return end
	local items = {}
	for name, c in pairs(BG.db.chars) do
		if c.main then table.insert(items, name .. ">" .. c.main)
		elseif c.isMain then table.insert(items, name .. ">-") end
	end
	table.sort(items)
	local chunks, cur = {}, ""
	for i = 1, table.getn(items) do
		if string.len(cur) + string.len(items[i]) + 1 > 230 then
			table.insert(chunks, cur)
			cur = ""
		end
		cur = (cur == "") and items[i] or (cur .. BG.SEP .. items[i])
	end
	if cur ~= "" then table.insert(chunks, cur) end
	for i = 1, table.getn(chunks) do
		local data = chunks[i]
		BG.After((i - 1) * 0.4, function() BG.Send("MB", data) end)
	end
	BG.Print(BG.T("sync_sent", table.getn(items)))
end

BananaGuild = BananaGuild or {}
BananaGuild.files = BananaGuild.files or {}
BananaGuild.files.Roster = true
