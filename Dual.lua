--[[
  BananaGuild - Dual
  The second spec ("dual spec") of a character. It is NOT written into the guild note and NOT read out of the game:
  whoever asks the player (inviter / recruiter / officer) types it into the new member window ("Zweit-Spec").
    * stored in the addon (db.dual[name] = { spec2 = code, ts, by })
    * sent to everybody who runs BananaGuild ("D", accepted from officer ranks); a client that just logged in
      asks ("DQ") and an officer hands over everything newer ("DS")
    * used by the member list and by the statistics ("both specs counts")
]]

local BG = BananaGuild
local Dual = {}
BG.Dual = Dual

local function Store()
	BG.db.dual = BG.db.dual or {}
	return BG.db.dual
end

--------------------------------------------------------------------- data

function Dual.Get(name)
	return BG.db.dual and BG.db.dual[name]
end

-- the code of the second spec ("-" is stored as "removed" so that a removal travels too)
function Dual.Code(name)
	local rec = Dual.Get(name)
	if rec and rec.spec2 and rec.spec2 ~= "-" then return rec.spec2 end
	return nil
end

-- spec entry ({ code, de, en, role }) of the second spec, nil when there is none (or it does not fit the class)
function Dual.Spec2(name, classKey)
	local code = Dual.Code(name)
	if not code or not classKey then return nil end
	local list = BG.Notes.Specs(classKey)
	for j = 1, table.getn(list) do
		if list[j][1] == code then return list[j] end
	end
	return nil
end

-- every role (T / H / D) a character can play: the spec in the note plus the second spec
function Dual.Roles(name, info)
	local roles = {}
	local pn = info and info.parsed
	if pn and pn.role then roles[pn.role] = true end
	local s2 = info and info.ckey and Dual.Spec2(name, info.ckey)
	if s2 then roles[s2[4]] = true end
	return roles
end

--------------------------------------------------------------------- setting and sending

local function OfficerRank(sender)
	return BG.Recruit and BG.Recruit.OfficerRank and BG.Recruit.OfficerRank(sender) and true or false
end

local function Changed()
	if BG.UI and BG.UI.Refresh then BG.UI.Refresh("members") end
	if BG.Stats and BG.Stats.OnRoster then BG.Stats.OnRoster() end
end

-- called by the new member window: code of the second spec, or nil to remove it
function Dual.Set(name, code)
	name = BG.NormName(name or "")
	if name == "" then return false end
	local old = Dual.Code(name)
	if old == code then return false end
	if not code and not old then return false end
	local rec = { spec2 = code or "-", ts = time(), by = BG.me }
	Store()[name] = rec
	BG.Send("D", name, rec.spec2, rec.ts)
	Changed()
	return true
end

local function ValidCode(classKey, code)
	if code == nil or code == "" then return nil end
	if code == "-" then return "-" end
	if not classKey then return code end -- class not known (yet): accept
	local list = BG.Notes.Specs(classKey)
	for j = 1, table.getn(list) do
		if list[j][1] == code then return code end
	end
	return nil
end

local function Apply(name, code, ts, by)
	name = BG.NormName(name or "")
	ts = tonumber(ts) or 0
	if name == "" then return false end
	local rec = Dual.Get(name)
	if rec and (rec.ts or 0) >= ts then return false end
	local info = BG.roster and BG.roster[name]
	local valid = ValidCode(info and info.ckey, code)
	if not valid then return false end
	Store()[name] = { spec2 = valid, ts = ts, by = by }
	return true
end

-- an officer entered or removed a second spec
BG.OnComm("D", function(sender, p)
	if not OfficerRank(sender) or not BG.db.sync.accept then return end
	if Apply(p[1], p[2], p[3], sender) then Changed() end
end)

local function Newest()
	local t = 0
	for _, rec in pairs(BG.db.dual or {}) do
		if (rec.ts or 0) > t then t = rec.ts end
	end
	return t
end

-- records: name:code:ts
local function Encode(name, rec)
	return name .. ":" .. (rec.spec2 or "-") .. ":" .. tostring(rec.ts or 0)
end

-- a client that just logged in asks for everything newer than what it has; officers answer (the first answer wins)
BG.OnComm("DQ", function(sender, p)
	if not OfficerRank(BG.me) then return end
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

BG.OnComm("DS", function(sender, p)
	Dual.answered = true
	if not OfficerRank(sender) then return end
	local changed = false
	for i = 1, table.getn(p) do
		local f = BG.SplitBy(p[i], ":")
		if f[1] and Apply(f[1], f[2], f[3], sender) then changed = true end
	end
	if changed then Changed() end
end)

-- after the login (the roster must be known first) ask for what the others know
BG.OnLogin(function()
	BG.After(40 + math.random() * 20, function() BG.Send("DQ", Newest()) end)
end)

BananaGuild = BananaGuild or {}
BananaGuild.files = BananaGuild.files or {}
BananaGuild.files.Dual = true
