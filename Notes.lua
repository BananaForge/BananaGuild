--[[
  BananaGuild - Notes
  Guild note format (public note, max 31 characters):
      [MAIN] [AL+VZ] [Retri]          main, professions, spec
      [TWINK Bananenbank] [KO]        twink of Bananenbank (short form: [T Bananenbank])
  Group 1 = role (required), group 2 = professions (optional, "-" = none), group 3 = spec (optional).
  The parser is forgiving: upper/lower case, spaces, "+" "," "/" "&" as separators, German or English names.
]]

local BG = BananaGuild
local Notes = {}
BG.Notes = Notes
Notes.MAXLEN = 31

--------------------------------------------------------------------- tables

-- code, main profession?, German name, English name, extra aliases (all folded, see Fold)
Notes.PROFS = {
	{ "AL", true,  "Alchemie",          "Alchemy",        { "alchi", "alch" } },
	{ "SM", true,  "Schmiedekunst",     "Blacksmithing",  { "schmied", "bs" } },
	{ "VZ", true,  "Verzauberkunst",    "Enchanting",     { "verz", "verzauberer", "ench" } },
	{ "IN", true,  "Ingenieurskunst",   "Engineering",    { "ingi", "inge", "ingenieur", "eng" } },
	{ "KR", true,  "Kraeuterkunde",     "Herbalism",      { "kraeuter", "herb" } },
	{ "LE", true,  "Lederverarbeitung", "Leatherworking", { "leder", "lw" } },
	{ "BB", true,  "Bergbau",           "Mining",         { "min" } },
	{ "KS", true,  "Kuerschnerei",      "Skinning",       { "kuerschner", "skin" } },
	{ "SN", true,  "Schneiderei",       "Tailoring",      { "schneider", "tail" } },
	{ "KO", false, "Kochkunst",         "Cooking",        { "koch", "cook" } },
	{ "EH", false, "Erste Hilfe",       "First Aid",      { "erstehilfe", "fa" } },
	{ "AN", false, "Angeln",            "Fishing",        { "angler", "fischen", "fish" } },
}

-- classes: key, name prefixes (folded; German + English, also the female forms), specs {code, de, en, role}
-- role: T tank, H healer, D damage
Notes.CLASSES = {
	{ "WARRIOR", { "krieger", "warrior" }, {
		{ "Waf", "Waffen", "Arms", "D" }, { "Fur", "Furor", "Fury", "D" }, { "Prot", "Schutz", "Protection", "T" } } },
	{ "PALADIN", { "paladin" }, {
		{ "Holy", "Heilig", "Holy", "H" }, { "Prot", "Schutz", "Protection", "T" }, { "Retri", "Vergeltung", "Retribution", "D" } } },
	{ "HUNTER", { "jaeger", "hunter" }, {
		{ "BM", "Tierherrschaft", "Beast Mastery", "D" }, { "MM", "Treffsicherheit", "Marksmanship", "D" }, { "SV", "Ueberleben", "Survival", "D" } } },
	{ "ROGUE", { "schurk", "rogue" }, {
		{ "Assa", "Meucheln", "Assassination", "D" }, { "Kampf", "Kampf", "Combat", "D" }, { "Sub", "Gewandtheit", "Subtlety", "D" } } },
	{ "PRIEST", { "priester", "priest" }, {
		{ "Disz", "Disziplin", "Discipline", "H" }, { "Holy", "Heilig", "Holy", "H" }, { "Schatten", "Schatten", "Shadow", "D" } } },
	{ "SHAMAN", { "schaman", "shaman" }, {
		{ "Ele", "Elementar", "Elemental", "D" }, { "Enh", "Verstaerkung", "Enhancement", "D" }, { "Resto", "Wiederherstellung", "Restoration", "H" } } },
	{ "MAGE", { "magier", "mage" }, {
		{ "Arkan", "Arkan", "Arcane", "D" }, { "Feuer", "Feuer", "Fire", "D" }, { "Frost", "Frost", "Frost", "D" } } },
	{ "WARLOCK", { "hexenmeister", "warlock" }, {
		{ "Affli", "Gebrechen", "Affliction", "D" }, { "Demo", "Daemonologie", "Demonology", "D" }, { "Destro", "Zerstoerung", "Destruction", "D" } } },
	{ "DRUID", { "druid" }, {
		{ "Eule", "Gleichgewicht", "Balance", "D" }, { "Katze", "Wilder Kampf (Katze)", "Feral DPS", "D" },
		{ "Baer", "Wilder Kampf (Baer)", "Feral Tank", "T" }, { "Resto", "Wiederherstellung", "Restoration", "H" } } },
}

--------------------------------------------------------------------- helpers

-- lower case, umlauts -> ae/oe/ue/ss, no blanks or dots ("Erste Hilfe" -> "erstehilfe", "Bär" -> "baer")
function Notes.Fold(s)
	s = string.lower(s or "")
	s = string.gsub(s, "\195\164", "ae")
	s = string.gsub(s, "\195\132", "ae")
	s = string.gsub(s, "\195\182", "oe")
	s = string.gsub(s, "\195\150", "oe")
	s = string.gsub(s, "\195\188", "ue")
	s = string.gsub(s, "\195\156", "ue")
	s = string.gsub(s, "\195\159", "ss")
	s = string.gsub(s, "[%s%.]", "")
	return s
end
local Fold = Notes.Fold

local profMap = {}
for i = 1, table.getn(Notes.PROFS) do
	local p = Notes.PROFS[i]
	profMap[Fold(p[1])] = p
	profMap[Fold(p[3])] = p
	profMap[Fold(p[4])] = p
	for j = 1, table.getn(p[5]) do profMap[p[5][j]] = p end
end

function Notes.ProfByCode(code)
	return profMap[Fold(code or "")]
end

-- "Kraeuterkunde" -> "Kräuterkunde" (the tables are ASCII so the parser can compare them folded)
local function Umlauts(s)
	s = string.gsub(s, "ae", "\195\164")
	s = string.gsub(s, "oe", "\195\182")
	s = string.gsub(s, "ue", "\195\188")
	s = string.gsub(s, "Ue", "\195\156")
	return s
end

function Notes.ProfName(code)
	local p = Notes.ProfByCode(code)
	if not p then return code end
	if BG.Lang() == "de" then return Umlauts(p[3]) end
	return p[4]
end

-- localized class name ("Krieger", "Jägerin", "Warrior") -> key ("WARRIOR") or nil
function Notes.ClassKey(name)
	if not name or name == "" then return nil end
	local f = Fold(name)
	for i = 1, table.getn(Notes.CLASSES) do
		local c = Notes.CLASSES[i]
		for j = 1, table.getn(c[2]) do
			if string.sub(f, 1, string.len(c[2][j])) == c[2][j] then return c[1] end
		end
	end
	return nil
end

function Notes.Specs(classKey)
	for i = 1, table.getn(Notes.CLASSES) do
		if Notes.CLASSES[i][1] == classKey then return Notes.CLASSES[i][3] end
	end
	return {}
end

function Notes.SpecName(spec)
	if BG.Lang() == "de" then return Umlauts(spec[2]) end
	return spec[3]
end

local function FindSpec(classKey, token)
	local list = Notes.Specs(classKey)
	local f = Fold(token)
	for i = 1, table.getn(list) do
		local s = list[i]
		if Fold(s[1]) == f or Fold(s[2]) == f or Fold(s[3]) == f then return s end
	end
	return nil
end

function Notes.RoleName(role)
	if role == "T" then return BG.T("role_tank") end
	if role == "H" then return BG.T("role_heal") end
	if role == "D" then return BG.T("role_dd") end
	return "?"
end

--------------------------------------------------------------------- parser

local function Trim(s) return (string.gsub(string.gsub(s, "^%s+", ""), "%s+$", "")) end

local function Tokens(s)
	local out = {}
	for t in string.gfind(s, "[^%+,/&%s]+") do table.insert(out, t) end
	return out
end

-- returns { kind = "main"|"twink"|nil, main = name, profs = {codes}, spec = {..}|nil, role = "T"|"H"|"D"|nil, warn = { {key, arg}, ... } }
function Notes.Parse(note, classKey)
	local r = { profs = {}, warn = {} }
	if not note or Trim(note) == "" then return r end
	local groups = {}
	for g in string.gfind(note, "%[([^%]]*)%]") do table.insert(groups, Trim(g)) end
	if table.getn(groups) == 0 then
		table.insert(r.warn, { "nw_nogroup" })
		return r
	end

	-- group 1: role
	local g1 = groups[1]
	local lw = string.lower(g1)
	if lw == "main" or lw == "m" then
		r.kind = "main"
	else
		local kws = { "twink", "twk", "alt", "t" }
		for i = 1, table.getn(kws) do
			local kw = kws[i]
			if string.sub(lw, 1, string.len(kw)) == kw then
				local rest = Trim(string.sub(g1, string.len(kw) + 1))
				local hadSep = (rest ~= string.sub(g1, string.len(kw) + 1)) or string.sub(rest, 1, 1) == "+"
				rest = Trim((string.gsub(rest, "^%+", "")))
				if rest ~= "" and hadSep and not string.find(rest, "[%s%+]") then
					r.kind = "twink"
					r.main = BG.NormName(rest)
					break
				end
			end
		end
		if not r.kind then table.insert(r.warn, { "nw_badfirst", g1 }) return r end
	end

	-- group 2: professions
	local seen, mainCount = {}, 0
	if groups[2] then
		local toks = Tokens(groups[2])
		for i = 1, table.getn(toks) do
			local t = toks[i]
			if t ~= "-" and t ~= "?" then
				local p = profMap[Fold(t)]
				if not p then
					table.insert(r.warn, { "nw_prof", t })
				elseif not seen[p[1]] then
					seen[p[1]] = true
					table.insert(r.profs, p[1])
					if p[2] then mainCount = mainCount + 1 end
				end
			end
		end
		if mainCount > 2 then table.insert(r.warn, { "nw_manyprof" }) end
	end

	-- group 3: spec (class decides the meaning of the short names)
	if groups[3] then
		local toks = Tokens(groups[3])
		local first
		for i = 1, table.getn(toks) do
			if toks[i] ~= "-" and toks[i] ~= "?" then first = toks[i] break end
		end
		if first then
			if classKey then
				local s = FindSpec(classKey, first)
				if s then r.spec, r.role = s, s[4]
				else table.insert(r.warn, { "nw_spec", first }) end
			else
				r.specRaw = first
			end
		end
	end
	if table.getn(groups) > 3 then table.insert(r.warn, { "nw_many" }) end
	return r
end

--------------------------------------------------------------------- builder

local function Bytes(s) return string.len(s) end

-- kind "main"|"twink", main = name (twink), profs = {codes} (empty = none), spec = code or nil
-- returns note, length. With blanks between the groups if that fits into 31 characters, otherwise without.
function Notes.Build(kind, main, profs, spec)
	local head = (kind == "twink") and ("[T " .. (main or "?") .. "]") or "[MAIN]"
	local prof = ""
	if profs and table.getn(profs) > 0 then
		prof = "[" .. table.concat(profs, "+") .. "]"
	elseif spec and spec ~= "" then
		prof = "[-]"
	end
	local sp = (spec and spec ~= "") and ("[" .. spec .. "]") or ""
	local parts = { head }
	if prof ~= "" then table.insert(parts, prof) end
	if sp ~= "" then table.insert(parts, sp) end
	local a = table.concat(parts, " ")
	if Bytes(a) <= Notes.MAXLEN then return a, Bytes(a) end
	local b = table.concat(parts, "")
	return b, Bytes(b)
end

--------------------------------------------------------------------- setting a note (needs the guild right)

function Notes.CanEdit()
	if CanEditPublicNote then return CanEditPublicNote() and true or false end
	return false
end

local function RosterIndex(name)
	local n = GetNumGuildMembers and GetNumGuildMembers(true) or 0
	for i = 1, n do
		local nm = GetGuildRosterInfo(i)
		if nm == name then return i end
	end
	return nil
end

-- writes the public note of a guild member; checks the result after a moment. cb(ok) is optional.
function Notes.Set(name, text, cb)
	if not Notes.CanEdit() then BG.Print(BG.T("note_no_right")) if cb then cb(false) end return false end
	if string.len(text) > Notes.MAXLEN then BG.Print(BG.T("note_too_long", string.len(text))) if cb then cb(false) end return false end
	local idx = RosterIndex(name)
	if not idx or not GuildRosterSetPublicNote then BG.Print(BG.T("note_not_found", name)) if cb then cb(false) end return false end
	GuildRosterSetPublicNote(idx, text)
	if GuildRoster then GuildRoster() end
	BG.After(3, function()
		if GuildRoster then GuildRoster() end
		BG.After(2, function()
			local info = BG.roster[name]
			local ok = info and info.note == text
			if ok then BG.Print(BG.T("note_set_ok", name, text))
			else BG.Print(BG.T("note_set_fail", name)) end
			if cb then cb(ok and true or false) end
		end)
	end)
	return true
end

BananaGuild.files = BananaGuild.files or {}
BananaGuild.files.Notes = true
