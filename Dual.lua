--[[
  BananaGuild - Dual
  Tracks the specs of a character without writing anything into the guild note.
    * every client reads the talents of its OWN character; the specs it has been seen with (the two newest)
      are the "dual spec" of that character
    * the data is sent to everybody who runs BananaGuild ("D": own data, accepted from anybody, it is the sender's own
      character) and the officers hand the whole list to a client that just logged in ("DQ" request, "DS" answer)
    * the statistics use it ("both specs counts": a character counts for every role it can play) and the member
      list shows it
  WoW 1.12 only gives the talents of the own character (GetTalentTabInfo), so a second spec becomes known as soon as
  the player has played it once.
]]

local BG = BananaGuild
local Dual = {}
BG.Dual = Dual

local CHECK_EVERY = 60      -- seconds between two looks at the own talents
local RESEND_EVERY = 1800   -- own data is repeated every 30 minutes (new clients, lost messages)

--------------------------------------------------------------------- data

-- db.dual[name] = { specs = { code1, code2 }, active = code, ts = time of the last change }
local function Store()
	BG.db.dual = BG.db.dual or {}
	return BG.db.dual
end

function Dual.Get(name)
	return BG.db.dual and BG.db.dual[name]
end

-- spec entries ({ code, de, en, role }) of a character, in the order they were seen
function Dual.SpecsOf(name, classKey)
	local rec = Dual.Get(name)
	local out = {}
	if not rec then return out end
	local list = BG.Notes.Specs(classKey)
	for i = 1, table.getn(rec.specs) do
		for j = 1, table.getn(list) do
			if list[j][1] == rec.specs[i] then table.insert(out, list[j]) break end
		end
	end
	return out
end

-- every role (T / H / D) a character can play: from the spec in the note and from the dual spec data
function Dual.Roles(name, info)
	local roles = {}
	local pn = info and info.parsed
	if pn and pn.role then roles[pn.role] = true end
	if info and info.ckey then
		local specs = Dual.SpecsOf(name, info.ckey)
		for i = 1, table.getn(specs) do roles[specs[i][4]] = true end
	end
	return roles
end

-- the role of the spec the character plays (note first, then what the client reported as active)
function Dual.MainRole(name, info)
	local pn = info and info.parsed
	if pn and pn.role then return pn.role end
	local rec = Dual.Get(name)
	if rec and rec.active and info and info.ckey then
		local list = BG.Notes.Specs(info.ckey)
		for j = 1, table.getn(list) do
			if list[j][1] == rec.active then return list[j][4] end
		end
	end
	return nil
end

--------------------------------------------------------------------- reading the own talents

-- spec code of the own character from the talent points; nil while there are too few points
function Dual.DetectOwn()
	if not GetTalentTabInfo or not UnitClass then return nil end
	local _, classKey = UnitClass("player")
	classKey = classKey and string.upper(classKey)
	if not classKey then return nil end
	local best, bestN, total = nil, 0, 0
	for i = 1, 3 do
		local _, _, pts = GetTalentTabInfo(i)
		pts = tonumber(pts) or 0
		total = total + pts
		if pts > bestN then best, bestN = i, pts end
	end
	if not best or total < 5 then return nil end
	local specs = BG.Notes.Specs(classKey)
	local spec
	if classKey == "DRUID" then
		-- tabs: balance, feral (cat or bear), restoration
		if best == 1 then spec = specs[1]
		elseif best == 3 then spec = specs[4]
		else
			-- cat or bear: believe the note when it says bear, otherwise cat
			local info = BG.roster and BG.roster[BG.me]
			local pn = info and info.parsed
			spec = (pn and pn.spec and pn.spec[1] == specs[3][1]) and specs[3] or specs[2]
		end
	else
		spec = specs[best]
	end
	if not spec then return nil end
	return classKey, spec[1]
end

local function SameRec(a, b)
	if not a or not b then return false end
	return a.specs[1] == b.specs[1] and a.specs[2] == b.specs[2] and a.active == b.active
end

function Dual.Broadcast()
	local rec = Dual.Get(BG.me)
	if not rec then return false end
	return BG.Send("D", rec.specs[1] or "-", rec.specs[2] or "-", rec.active or "-", rec.ts or 0)
end

-- look at the own talents; a new spec or a switch is remembered and sent
function Dual.Update()
	if not BG.db or not BG.me then return false end
	local classKey, code = Dual.DetectOwn()
	if not code then return false end
	local my = BG.db.dualSelf
	if not my or my.class ~= classKey then
		my = { class = classKey, list = {} }
		BG.db.dualSelf = my
	end
	local now = time()
	local found
	for i = 1, table.getn(my.list) do
		if my.list[i].code == code then my.list[i].ts = now found = true end
	end
	if not found then table.insert(my.list, { code = code, ts = now, first = now }) end
	-- two specs at most: the one that was seen least recently drops out
	while table.getn(my.list) > 2 do
		local oldest = 1
		for i = 2, table.getn(my.list) do
			if my.list[i].ts < my.list[oldest].ts then oldest = i end
		end
		table.remove(my.list, oldest)
	end
	table.sort(my.list, function(a, b) return a.first < b.first end)
	local rec = { specs = { my.list[1].code, my.list[2] and my.list[2].code or nil }, active = code, ts = now }
	local old = Dual.Get(BG.me)
	if SameRec(old, rec) then return false end
	Store()[BG.me] = rec
	Dual.Broadcast()
	if BG.UI and BG.UI.Refresh then BG.UI.Refresh("members") end
	if BG.Stats and BG.Stats.OnRoster then BG.Stats.OnRoster() end
	return true
end

--------------------------------------------------------------------- the wire

local function ValidCode(classKey, code)
	if code == nil or code == "-" or code == "" then return nil end
	if not classKey then return code end -- class not known (yet): accept
	local list = BG.Notes.Specs(classKey)
	for j = 1, table.getn(list) do
		if list[j][1] == code then return code end
	end
	return nil
end

local function Apply(name, c1, c2, active, ts)
	name = BG.NormName(name or "")
	ts = tonumber(ts) or 0
	if name == "" or name == BG.me then return false end
	local rec = Dual.Get(name)
	if rec and (rec.ts or 0) >= ts then return false end
	local info = BG.roster and BG.roster[name]
	local ck = info and info.ckey
	local s1, s2, act = ValidCode(ck, c1), ValidCode(ck, c2), ValidCode(ck, active)
	if not s1 and not s2 then return false end
	local specs = { s1 or s2, s1 and s2 or nil }
	Store()[name] = { specs = specs, active = act, ts = ts }
	return true
end

local function Changed()
	if BG.UI and BG.UI.Refresh then BG.UI.Refresh("members") end
	if BG.Stats and BG.Stats.OnRoster then BG.Stats.OnRoster() end
end

-- a character reports itself
BG.OnComm("D", function(sender, p)
	if Apply(sender, p[1], p[2], p[3], p[4]) then Changed() end
end)

local function Newest()
	local t = 0
	for _, rec in pairs(BG.db.dual or {}) do
		if (rec.ts or 0) > t then t = rec.ts end
	end
	return t
end

local function IsOfficer(sender)
	return BG.Recruit and BG.Recruit.OfficerRank and BG.Recruit.OfficerRank(sender) and true or false
end

-- records: name:code1:code2:active:ts
local function Encode(name, rec)
	return name .. ":" .. (rec.specs[1] or "-") .. ":" .. (rec.specs[2] or "-") .. ":" .. (rec.active or "-") .. ":" .. tostring(rec.ts or 0)
end

-- a client that just logged in asks for everything newer than what it has; officers answer (the first answer wins)
BG.OnComm("DQ", function(sender, p)
	if not IsOfficer(BG.me) then return end
	local since = tonumber(p[1]) or 0
	local recs = {}
	for name, rec in pairs(BG.db.dual or {}) do
		if (rec.ts or 0) > since then table.insert(recs, Encode(name, rec)) end
	end
	if table.getn(recs) == 0 then return end
	Dual.answered = false
	BG.After(2 + math.random() * 8, function()
		if Dual.answered then return end -- somebody else was faster
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
			BG.After((i - 1) * 0.4, function() BG.Send("DS", data) end)
		end
	end)
end)

-- the answer of an officer: records of other characters (only accepted from officer ranks)
BG.OnComm("DS", function(sender, p)
	Dual.answered = true
	if not IsOfficer(sender) then return end
	local changed = false
	for i = 1, table.getn(p) do
		local f = BG.SplitBy(p[i], ":")
		if f[1] and Apply(f[1], f[2], f[3], f[4], f[5]) then changed = true end
	end
	if changed then Changed() end
end)

--------------------------------------------------------------------- when to look

BG.OnLogin(function()
	BG.After(40 + math.random() * 20, function()
		Dual.Update()
		Dual.Broadcast()
		BG.Send("DQ", Newest())
	end)
	BG.Ticker("dualcheck", CHECK_EVERY, function() Dual.Update() end)
	BG.Ticker("dualsend", RESEND_EVERY, function() Dual.Broadcast() end)
end)

-- talent changes: look again a moment later (event names differ between clients, unknown ones are ignored)
local function Soon() BG.After(2, function() Dual.Update() end) end
for _, ev in ipairs({ "CHARACTER_POINTS_CHANGED", "PLAYER_TALENT_UPDATE", "ACTIVE_TALENT_GROUP_CHANGED", "PLAYER_SPECIALIZATION_CHANGED" }) do
	pcall(BG.On, ev, Soon)
end

BananaGuild = BananaGuild or {}
BananaGuild.files = BananaGuild.files or {}
BananaGuild.files.Dual = true
