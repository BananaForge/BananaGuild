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
			-- how long has he been offline? (years, months, days, hours since the last login - where the client has it)
			local offDays, offSrc
			if not online and GetGuildRosterLastOnline then
				local ok, y, m, d, h = pcall(GetGuildRosterLastOnline, i)
				if ok and y then offDays = y * 365 + (m or 0) * 30 + (d or 0) + (h or 0) / 24 offSrc = "api" end
			end
			new[name] = {
				rank = rank, rankIndex = rankIndex or 99, level = level or 0, class = class,
				zone = zone, note = note, online = online and true or false, status = status,
				offlineDays = offDays, offlineSrc = offSrc,
			}
		end
	end
	-- guild notes: [MAIN] / [TWINK Name] + professions + spec (see Notes.lua)
	local byFold = {}
	for name in pairs(new) do byFold[BG.Notes.Fold(name)] = name end
	for name, info in pairs(new) do
		info.ckey = BG.Notes.ClassKey(info.class)
		info.parsed = BG.Notes.Parse(info.note, info.ckey)
		local p = info.parsed
		if p.kind == "twink" then
			local real = byFold[BG.Notes.Fold(p.main)]
			if real then p.main = real p.mainOk = true end
			if p.main == name then
				p.kind, p.main = nil, nil
				table.insert(p.warn, { "nw_self" })
			end
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
				-- the join message was missed (other wording on the server, loading screen ...): the roster tells us
				if not first and BG.Recruit then BG.Recruit.OnJoin(name) end
			end
		end
		-- last time the addon saw him online: the fallback when the client does not tell how long somebody was offline
		local ch = db.chars[name]
		if info.online then
			ch.seen = time()
		elseif not info.offlineDays and ch.seen then
			info.offlineDays = math.max(0, (time() - ch.seen) / 86400)
			info.offlineSrc = "seen"
		end
	end
	if initial then db.rosterInit = true end
	if BG.NoteWin then BG.NoteWin.OnRoster() end
	if BG.Stats then BG.Stats.OnRoster() end
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
		ch.ts = time()
		BG.AddLog("join", name, ch.invitedBy or "")
		db.levels[name] = db.levels[name] or 1
		if GuildRoster then GuildRoster() end
		if BG.Recruit then BG.Recruit.OnJoin(name) end
	elseif kind == "leave" then
		BG.AddLog("leave", BG.NormName(a))
	elseif kind == "kick" then
		BG.AddLog("kick", BG.NormName(a), BG.NormName(b))
	elseif kind == "promote" or kind == "demote" then
		-- our own step by step promotion (Promote.lua) is logged once at the end instead of once per rank
		local own = BG.Promo and BG.Promo.IsBusy(BG.NormName(b)) and BG.NormName(a) == BG.me
		if not own then BG.AddLog(kind, BG.NormName(a), BG.NormName(b), c) end
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
				local old = BG.pendingInvites[n]
				if not old or time() - (old.at or 0) > 60 then
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

-- the parent of a character: the guild note wins, the old manual assignment is the fallback
function Roster.ParentOf(name)
	local info = BG.roster[name]
	local p = info and info.parsed
	if p and p.kind == "main" then return nil end
	if p and p.kind == "twink" and p.main then return p.main end
	local c = BG.db.chars[name]
	return c and c.main
end

function Roster.RootOf(name)
	local guard = 0
	while guard < 5 do
		local up = Roster.ParentOf(name)
		if not up or up == name then break end
		name = up
		guard = guard + 1
	end
	return name
end

function Roster.Twinks(main)
	local names, out = {}, {}
	for n in pairs(BG.roster) do names[n] = true end
	for n in pairs(BG.db.chars) do names[n] = true end
	for n in pairs(names) do
		if n ~= main and Roster.ParentOf(n) == main then table.insert(out, n) end
	end
	table.sort(out)
	return out
end

-- true when the character is known as a main or twink (by note or by the old manual data)
function Roster.IsAssigned(name)
	local info = BG.roster[name]
	if info and info.parsed and info.parsed.kind then return true end
	local c = BG.db.chars[name]
	if c and (c.main or c.isMain) then return true end
	for n in pairs(BG.roster) do
		if n ~= name and Roster.ParentOf(n) == name then return true end
	end
	for n, o in pairs(BG.db.chars) do
		if o.main == name then return true end
	end
	return false
end

-- accounts = number of distinct mains (the root of every character, by guild note); characters without any note count
-- as one account each. chars = everybody in the guild. noNote = characters without a valid note and without manual data.
function Roster.CountAccounts()
	local roots, accounts, chars, noNote = {}, 0, 0, 0
	for name, info in pairs(BG.roster) do
		chars = chars + 1
		local root = Roster.RootOf(name)
		if not roots[root] then roots[root] = true accounts = accounts + 1 end
		if not Roster.IsAssigned(name) then noNote = noNote + 1 end
	end
	return accounts, chars, noNote
end

-- note problems of a character as readable lines
function Roster.NoteProblems(name)
	local out = {}
	local info = BG.roster[name]
	local p = info and info.parsed
	if not p then return out end
	for i = 1, table.getn(p.warn) do
		table.insert(out, BG.T(p.warn[i][1], p.warn[i][2]))
	end
	if p.kind == "twink" then
		if not p.mainOk then
			table.insert(out, BG.T("nw_mainmissing", p.main or "?"))
		else
			local mi = BG.roster[p.main]
			if mi and mi.parsed and mi.parsed.kind == "twink" then table.insert(out, BG.T("nw_mainistwink", p.main)) end
		end
	end
	return out
end

-- Every change stamps the character with ts = time(); the newest stamp wins when data is merged (sync).
local function Touch(list)
	local t = time()
	for i = 1, table.getn(list) do Char(list[i]).ts = t end
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
	local changed = { alt, main }
	-- twinks of the alt move with it
	for name, c in pairs(BG.db.chars) do
		if c.main == alt then c.main = main table.insert(changed, name) end
	end
	if not silent then Touch(changed) Roster.SendRecords(changed) end
	if BG.UI and BG.UI.Refresh then BG.UI.Refresh("members") end
	return true
end

function Roster.MarkMain(name, silent)
	name = BG.NormName(name)
	if name == "" then return false end
	Char(name).main = nil
	Char(name).isMain = true
	if not silent then Touch({ name }) Roster.SendRecords({ name }) end
	if BG.UI and BG.UI.Refresh then BG.UI.Refresh("members") end
	return true
end

function Roster.Unassign(name, silent)
	name = BG.NormName(name)
	local c = BG.db.chars[name]
	if not c then return false end
	c.main = nil
	c.isMain = nil
	if not silent then Touch({ name }) Roster.SendRecords({ name }) end
	if BG.UI and BG.UI.Refresh then BG.UI.Refresh("members") end
	return true
end

function Roster.SetDetails(name, joined, invitedBy, note, silent)
	name = BG.NormName(name)
	local c = Char(name)
	if joined ~= nil then c.joined = (joined ~= "" and joined) or nil; c.approx = nil end
	if invitedBy ~= nil then c.invitedBy = (invitedBy ~= "" and BG.NormName(invitedBy)) or nil end
	if note ~= nil then c.note = (note ~= "" and note) or nil end
	if not silent then Touch({ name }) Roster.SendRecords({ name }) end
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
-- Records travel as "S;rec;rec;..." with rec = name:main:flag:joined:invitedBy:ts   ('_' = empty,
-- flag m = is a main, t = twink, n = nothing). Newest ts wins. Pull = "SQ;<my newest ts>": officers answer
-- with everything newer (random delay, duplicates suppressed). That is the same ping/pong idea as BananaCraft.

local function Trusted(sender)
	if not BG.db.sync.accept then return false end
	local info = BG.roster[sender]
	if not info then return false end
	return (info.rankIndex or 99) <= (BG.db.sync.trustRank or 2)
end

local function MeTrusted()
	local info = BG.roster[BG.me]
	return info ~= nil and (info.rankIndex or 99) <= (BG.db.sync.trustRank or 2)
end

local function Enc(x) if x == nil or x == "" then return "_" end return tostring(x) end
local function Dec(x) if x == nil or x == "_" or x == "" then return nil end return x end

local function Encode(name)
	local c = BG.db.chars[name]
	if not c then return nil end
	local flag = c.main and "t" or (c.isMain and "m" or "n")
	return name .. ":" .. Enc(c.main) .. ":" .. flag .. ":" .. Enc(c.joined) .. ":" .. Enc(c.invitedBy) .. ":" .. tostring(c.ts or 1)
end

Roster.heard = {}   -- name -> newest ts we saw on the wire (to suppress duplicate answers)
Roster.applied = 0  -- records changed by incoming data since the last report

local function ApplyRecord(rec)
	local f = BG.SplitBy(rec, ":")
	local name = BG.NormName(f[1] or "")
	if name == "" then return false end
	local ts = tonumber(f[6]) or 0
	if (Roster.heard[name] or 0) < ts then Roster.heard[name] = ts end
	local c = BG.db.chars[name]
	if c and (c.ts or 0) >= ts then return false end
	c = Char(name)
	c.main = Dec(f[2])
	c.isMain = (f[3] == "m") or nil
	c.joined = Dec(f[4])
	c.invitedBy = Dec(f[5])
	c.approx = nil
	c.ts = ts
	return true
end

-- send records of one message kind in message-sized chunks (0.4 s apart)
local function SendChunked(kind, recs)
	local chunks, cur = {}, ""
	for i = 1, table.getn(recs) do
		if cur ~= "" and string.len(cur) + string.len(recs[i]) + 1 > 225 then
			table.insert(chunks, cur)
			cur = ""
		end
		cur = (cur == "") and recs[i] or (cur .. BG.SEP .. recs[i])
	end
	if cur ~= "" then table.insert(chunks, cur) end
	for i = 1, table.getn(chunks) do
		local data = chunks[i]
		BG.After((i - 1) * 0.4, function() BG.Send(kind, data) end)
	end
	return table.getn(recs)
end

-- send the given characters
function Roster.SendRecords(names)
	local recs = {}
	for i = 1, table.getn(names) do
		local e = Encode(names[i])
		if e then table.insert(recs, e) end
	end
	return SendChunked("S", recs)
end

----------------------------------------------------------------- history (log) sync
-- Every online client writes joins/promotions/... into its own log, so the same event exists several times
-- with slightly different times. Merging therefore de-duplicates by content (+ 2 minute window).
-- Private entries (prospects) are never shared.
local LOG_SYNC_KINDS = { join = true, leave = true, kick = true, promote = true, demote = true, invite = true, levelup = true, decline = true }
local LOG_WINDOW = 120
local LOG_SEND_MAX = 100

local function EscF(s)
	return (string.gsub(tostring(s or ""), "[%%:;,|]", function(c) return string.format("%%%02X", string.byte(c)) end))
end
local function UnescF(s)
	return (string.gsub(s or "", "%%(%x%x)", function(h) return string.char(tonumber(h, 16)) end))
end

local function LogKey(e)
	return tostring(e.k) .. ":" .. tostring(e.a or "") .. ":" .. tostring(e.b or "") .. ":" .. tostring(e.c or "")
end

local function LogHas(e)
	local log = BG.db.log
	local key = LogKey(e)
	for i = table.getn(log), 1, -1 do
		local o = log[i]
		if LogKey(o) == key then
			if e.k == "levelup" then return true end -- one level up per character and level, whatever the time
			if math.abs((o.t or 0) - (e.t or 0)) <= LOG_WINDOW then return true end
		end
		if e.k ~= "levelup" and (o.t or 0) < (e.t or 0) - LOG_WINDOW - 3600 then break end
	end
	return false
end

local function LogEncode(e)
	return tostring(e.t) .. ":" .. EscF(e.k) .. ":" .. EscF(e.a) .. ":" .. EscF(e.b) .. ":" .. EscF(e.c)
end

Roster.heardLog = {}
Roster.appliedLog = 0

local function LogApply(rec, trusted)
	local f = BG.SplitBy(rec, ":")
	local t = tonumber(f[1])
	local e = { t = t, k = UnescF(f[2]), a = UnescF(f[3]), b = UnescF(f[4]), c = UnescF(f[5]) }
	if not t or not LOG_SYNC_KINDS[e.k] then return false end
	Roster.heardLog[LogKey(e)] = true
	if not trusted or LogHas(e) then return false end
	if e.a == "" then e.a = nil end
	if e.b == "" then e.b = nil end
	if e.c == "" then e.c = nil end
	if e.k == "levelup" and e.a and e.b and tonumber(e.b) then
		BG.db.levels[e.a] = math.max(BG.db.levels[e.a] or 0, tonumber(e.b))
	end
	table.insert(BG.db.log, e)
	return true
end

local function LogFinish()
	local log = BG.db.log
	table.sort(log, function(x, y) return (x.t or 0) < (y.t or 0) end)
	while table.getn(log) > 600 do table.remove(log, 1) end
end

-- the entries we would send: newer than 'since', shareable kinds, newest LOG_SEND_MAX, nobody sent them yet
local function LogCollect(since, skipHeard)
	local out = {}
	local log = BG.db.log
	for i = table.getn(log), 1, -1 do
		local e = log[i]
		if (e.t or 0) > since and LOG_SYNC_KINDS[e.k] and not (skipHeard and Roster.heardLog[LogKey(e)]) then
			table.insert(out, 1, LogEncode(e))
			if table.getn(out) >= LOG_SEND_MAX then break end
		end
	end
	return out
end

BG.OnComm("G", function(sender, p)
	local trusted = Trusted(sender)
	if trusted then Roster.ackAt = GetTime() end
	for i = 1, table.getn(p) do
		if LogApply(p[i], trusted) then Roster.appliedLog = Roster.appliedLog + 1 end
	end
	if trusted then
		LogFinish()
		if BG.UI and BG.UI.Refresh then BG.UI.Refresh("log") end
	end
end)

BG.OnComm("S", function(sender, p)
	local trusted = Trusted(sender)
	if trusted then Roster.ackAt = GetTime() end
	for i = 1, table.getn(p) do
		if trusted then
			if ApplyRecord(p[i]) then Roster.applied = Roster.applied + 1 end
		else
			-- still remember it was sent, so we do not answer with the same data
			local f = BG.SplitBy(p[i], ":")
			local name, ts = BG.NormName(f[1] or ""), tonumber(f[6]) or 0
			if name ~= "" and (Roster.heard[name] or 0) < ts then Roster.heard[name] = ts end
		end
	end
	if BG.UI and BG.UI.Refresh then BG.UI.Refresh("members") end
end)

function Roster.NewestTs()
	local m = 0
	for _, c in pairs(BG.db.chars) do
		if (c.ts or 0) > m then m = c.ts end
	end
	return m
end

-- somebody asks for everything newer than their newest stamps: "SQ;<newest char ts>;<history since>"
BG.OnComm("SQ", function(sender, p)
	if not BG.db.sync.accept or not MeTrusted() then return end
	local since = tonumber(p[1]) or 0
	local sinceLog = tonumber(p[2]) or 0
	local any = table.getn(LogCollect(sinceLog, false)) > 0
	if not any then
		for _, c in pairs(BG.db.chars) do
			if (c.ts or 0) > since then any = true break end
		end
	end
	if not any then return end
	BG.After(1 + math.random() * 6, function()
		local names = {}
		for name, c in pairs(BG.db.chars) do
			if (c.ts or 0) > since and (Roster.heard[name] or 0) < c.ts then table.insert(names, name) end
		end
		if table.getn(names) > 0 then table.sort(names) Roster.SendRecords(names) end
		local recs = LogCollect(sinceLog, true)
		if table.getn(recs) > 0 then SendChunked("G", recs) end
	end)
end)

-- Pull what is outdated. manual = also push everything we have and report the result in chat.
function Roster.RequestSync(manual)
	if not IsInGuild or not IsInGuild() then
		if manual then BG.Print(BG.T("not_in_guild")) end
		return false
	end
	if not SendAddonMessage or not BG.db.features.guildBroadcast then
		if manual then BG.Print(BG.T("comm_disabled")) end
		return false
	end
	Roster.applied = 0
	Roster.appliedLog = 0
	Roster.reqAt = GetTime()
	local reqTime = time()
	if GuildRoster then GuildRoster() end
	local sinceLog = manual and 0 or (BG.db.sync.logSince or 0)
	BG.Send("SQ", manual and 0 or Roster.NewestTs(), sinceLog)
	local pushed = 0
	if manual then
		local all = {}
		for name, c in pairs(BG.db.chars) do
			if c.main or c.isMain or c.joined or c.invitedBy then table.insert(all, name) end
		end
		table.sort(all)
		pushed = Roster.SendRecords(all)
		local recs = LogCollect(0, false)
		if table.getn(recs) > 0 then
			BG.After(2, function() SendChunked("G", recs) end)
			pushed = pushed + table.getn(recs)
		end
	end
	BG.db.sync.last = time()
	BG.After(9, function()
		-- somebody trusted answered: from now on only ask for what is newer than this request
		if Roster.ackAt and Roster.ackAt >= Roster.reqAt then BG.db.sync.logSince = reqTime - 600 end
		BG.db.sync.lastApplied = Roster.applied + Roster.appliedLog
		if manual then BG.Print(BG.T("sync_done", Roster.applied + Roster.appliedLog, pushed)) end
		if BG.UI and BG.UI.Refresh then BG.UI.Refresh("settings") BG.UI.Refresh("members") BG.UI.Refresh("log") end
	end)
	return true
end

-- Automatic background update: every time the window opens (at most every 90 s) and once after login.
function Roster.AutoSync()
	if not BG.loaded or not BG.db.sync.accept then return end
	local now = GetTime()
	if Roster.lastAuto and now - Roster.lastAuto < 90 then return end
	Roster.lastAuto = now
	Roster.RequestSync(false)
	-- refresh the "who has which addon" data at most every 5 minutes
	if not Roster.lastPresence or now - Roster.lastPresence > 300 then
		Roster.lastPresence = now
		if BG.Presence then BG.Presence.Query(true) end
	end
end

BG.OnLogin(function()
	BG.After(25, function() Roster.AutoSync() end)
end)

-- the old "send my assignments" button now does the full two-way sync
function Roster.SyncAll() return Roster.RequestSync(true) end

BananaGuild = BananaGuild or {}
BananaGuild.files = BananaGuild.files or {}
BananaGuild.files.Roster = true
