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
	{ "JC", true,  "Juwelenschleifen",  "Jewelcrafting",  { "juwe", "juwi", "juwelier", "juwelenschleifer", "jc", "js", "jewel", "jewelcrafter" } },
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

-- name of a profession in a given language ("de" / "en"), default: the language of the addon
function Notes.ProfName(code, lang)
	local p = Notes.ProfByCode(code)
	if not p then return code end
	if (lang or BG.Lang()) == "de" then return Umlauts(p[3]) end
	return p[4]
end

-- class key -> readable name and the usual class colour (r, g, b)
Notes.CLASS_INFO = {
	WARRIOR = { "Krieger", "Warrior", 0.78, 0.61, 0.43 },
	PALADIN = { "Paladin", "Paladin", 0.96, 0.55, 0.73 },
	HUNTER  = { "J\195\164ger", "Hunter", 0.67, 0.83, 0.45 },
	ROGUE   = { "Schurke", "Rogue", 1.00, 0.96, 0.41 },
	PRIEST  = { "Priester", "Priest", 1.00, 1.00, 1.00 },
	SHAMAN  = { "Schamane", "Shaman", 0.00, 0.44, 0.87 },
	MAGE    = { "Magier", "Mage", 0.41, 0.80, 0.94 },
	WARLOCK = { "Hexenmeister", "Warlock", 0.58, 0.51, 0.79 },
	DRUID   = { "Druide", "Druid", 1.00, 0.49, 0.04 },
}

function Notes.ClassName(key, lang)
	local c = Notes.CLASS_INFO[key]
	if not c then return "?" end
	if (lang or BG.Lang()) == "de" then return c[1] end
	return c[2]
end

function Notes.ClassColor(key)
	local c = Notes.CLASS_INFO[key]
	if not c then return 0.6, 0.6, 0.6 end
	return c[3], c[4], c[5]
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

function Notes.SpecName(spec, lang)
	if (lang or BG.Lang()) == "de" then return Umlauts(spec[2]) end
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

--------------------------------------------------------------------- suggestion from a free-text reply

-- lower case + umlauts -> ae/oe/ue/ss, blanks kept (Fold removes them)
local function FoldKeep(s)
	s = string.lower(s or "")
	s = string.gsub(s, "\195\164", "ae")
	s = string.gsub(s, "\195\132", "ae")
	s = string.gsub(s, "\195\182", "oe")
	s = string.gsub(s, "\195\150", "oe")
	s = string.gsub(s, "\195\188", "ue")
	s = string.gsub(s, "\195\156", "ue")
	s = string.gsub(s, "\195\159", "ss")
	return s
end

local function Words(s)
	local out = {}
	for w in string.gfind(FoldKeep(s), "%a+") do table.insert(out, w) end
	return out
end

-- single words plus every pair glued together ("erste hilfe" -> "erstehilfe")
local function WordsAndPairs(words)
	local out = {}
	for i = 1, table.getn(words) do
		table.insert(out, words[i])
		if words[i + 1] then table.insert(out, words[i] .. words[i + 1]) end
	end
	return out
end

local function Starts(s, prefix) return string.sub(s, 1, string.len(prefix)) == prefix end

-- professions: short tokens (up to 3 letters) must match exactly, longer ones also by prefix ("Schmieden" -> Schmiedekunst)
local function SuggestProfs(tokens)
	local found, seen, mains = {}, {}, 0
	for i = 1, table.getn(tokens) do
		local t = tokens[i]
		local p = profMap[t]
		if not p and string.len(t) >= 4 then
			for key, q in pairs(profMap) do
				if (string.len(key) >= 4 and Starts(t, key)) or Starts(key, t) then p = q break end
			end
		end
		if p and not seen[p[1]] then
			if not p[2] or mains < 2 then
				seen[p[1]] = true
				table.insert(found, p[1])
				if p[2] then mains = mains + 1 end
			end
		end
	end
	return found
end

local ROLE_WORDS = { tank = "T", heal = "H", healer = "H", heiler = "H", heilung = "H", healing = "H" }

-- spec: code / German / English name, single words of the names; "tank" / "heal" when the class has exactly one such spec
local function SuggestSpec(tokens, classKey)
	local list = Notes.Specs(classKey)
	if table.getn(list) == 0 then return nil end
	local hits, count = {}, 0
	local function Hit(i)
		if not hits[i] then hits[i] = 0 count = count + 1 end
		hits[i] = hits[i] + 1
	end
	for i = 1, table.getn(list) do
		local sp = list[i]
		local names = { Fold(sp[1]), Fold(sp[2]), Fold(sp[3]) }
		local words = {}
		for n = 2, 3 do
			local w = Words(sp[n])
			for k = 1, table.getn(w) do if string.len(w[k]) >= 3 then table.insert(words, w[k]) end end
		end
		for t = 1, table.getn(tokens) do
			local tok = tokens[t]
			for n = 1, 3 do
				if tok == names[n] then Hit(i) end
			end
			for w = 1, table.getn(words) do
				local word = words[w]
				if tok == word or (string.len(tok) >= 4 and (Starts(word, tok) or Starts(tok, word))) then Hit(i) end
			end
		end
	end
	-- the spec with the most hits wins; words shared by several specs (druid "Wilder Kampf") and ties are not clear
	if count > 0 then
		local best, bestN, ties = nil, 0, 0
		for i = 1, table.getn(list) do
			local h = hits[i] or 0
			if h > bestN then best, bestN, ties = list[i], h, 1
			elseif h == bestN and h > 0 then ties = ties + 1 end
		end
		if best and ties == 1 then return best end
		return nil
	end
	if count == 0 then
		for t = 1, table.getn(tokens) do
			local role = ROLE_WORDS[tokens[t]]
			if role then
				local only, n = nil, 0
				for i = 1, table.getn(list) do
					if list[i][4] == role then only = list[i] n = n + 1 end
				end
				if n == 1 then return only end
			end
		end
	end
	return nil
end

-- Reads a free-text reply of a player and returns what it contains: { kind, main, profs = {codes}, spec = {..}, any = bool }.
-- Nothing is written anywhere; the window shows it as a proposal.
function Notes.Suggest(text, classKey, target)
	local r = { profs = {} }
	if not text or Trim(text) == "" then return r end
	local words = Words(text)
	local tokens = WordsAndPairs(words)
	r.profs = SuggestProfs(tokens)
	r.spec = SuggestSpec(tokens, classKey)

	-- main / twink: names of guild members that appear as a word
	local hasTwink, hasMainWord, mineTwink = false, false, false
	for i = 1, table.getn(words) do
		local w = words[i]
		if Starts(w, "twink") or w == "alt" or w == "zweitchar" or w == "second" or w == "zweitcharakter" then
			hasTwink = true
			local prev = words[i - 1]
			if prev == "mein" or prev == "meine" or prev == "my" or prev == "meinen" or prev == "einen" or prev == "habe" or prev == "have" then mineTwink = true end
		end
		if w == "main" or Starts(w, "haupt") then hasMainWord = true end
	end
	local named
	if BG.roster then
		local lw = {}
		for i = 1, table.getn(words) do lw[words[i]] = true end
		for name in pairs(BG.roster) do
			local f = FoldKeep(name)
			if name ~= target and string.len(f) >= 3 and lw[f] then named = name break end
		end
	end
	if mineTwink then
		r.kind = "main" -- "my twink is X": the player himself is the main
	elseif (hasTwink or hasMainWord) and named then
		r.kind, r.main = "twink", named
	elseif hasTwink then
		r.kind = "twink"
	elseif hasMainWord then
		r.kind = "main"
	end
	r.any = (r.kind or r.spec or table.getn(r.profs) > 0) and true or false
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
