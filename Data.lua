--[[
  BananaGuild - Data
  The member data of the officers: main / twink, professions, spec and second spec. It lives in the addon, NOT in the
  guild note (the notes stay as they are and are only read once, see Data.ImportNotes).
    * main / twink: db.chars[name].main / .isMain (Roster.lua, synced with the "S" records as before)
    * professions, spec, second spec: db.data[name] = { profs = "BB+JC" | "-" (none on purpose), spec = code, spec2 = code, ts, by }
    * info.parsed (what the rest of the addon reads: kind, main, profs, spec, role) is built from these two
    * the shared note of a member (db.data[name].note, every officer sees and edits it) has its own timestamp .nts
    * synced between the officers: "M" (one record, accepted from officer ranks), "N" (a note), "MQ" (a client that just
      logged in asks), "MS" (an officer answers with everything newer)
]]

local BG = BananaGuild
local Data = {}
BG.Data = Data

local function Store()
	BG.db.data = BG.db.data or {}
	return BG.db.data
end

function Data.Get(name)
	return BG.db.data and BG.db.data[name]
end

--------------------------------------------------------------------- permission

local function OfficerRank(sender)
	return BG.Recruit and BG.Recruit.OfficerRank and BG.Recruit.OfficerRank(sender) and true or false
end

-- officers (the rank of the greeting popup / sync rank) and everybody above may change the data
function Data.CanEdit()
	return OfficerRank(BG.me)
end

--------------------------------------------------------------------- reading

-- the same structure the guild note parser used to deliver: { kind, main, mainOk, profs = {codes}, spec = {..}, role, noprof, warn }
function Data.Parsed(name, info)
	local p = { profs = {}, warn = {} }
	local c = BG.db.chars[name]
	if c and c.main then
		p.kind, p.main = "twink", c.main
	elseif c and c.isMain then
		p.kind = "main"
	end
	local d = Data.Get(name)
	if d then
		if d.profs == "-" then
			p.noprof = true
		elseif d.profs and d.profs ~= "" then
			for code in string.gfind(d.profs, "[^%+]+") do
				local pr = BG.Notes.ProfByCode(code)
				if pr then table.insert(p.profs, pr[1]) end
			end
		end
		local ck = info and info.ckey
		if d.spec and ck then
			local list = BG.Notes.Specs(ck)
			for j = 1, table.getn(list) do
				if list[j][1] == d.spec then p.spec, p.role = list[j], list[j][4] end
			end
		end
	end
	return p
end

-- spec entry ({ code, de, en, role }) of the second spec, nil when there is none (or it does not fit the class)
function Data.Spec2(name, classKey)
	local d = Data.Get(name)
	if not d or not d.spec2 or not classKey then return nil end
	local list = BG.Notes.Specs(classKey)
	for j = 1, table.getn(list) do
		if list[j][1] == d.spec2 then return list[j] end
	end
	return nil
end

-- every role (T / H / D) a character can play: the spec and the second spec
function Data.Roles(name, info)
	local roles = {}
	local pn = info and info.parsed
	if pn and pn.role then roles[pn.role] = true end
	local s2 = info and info.ckey and Data.Spec2(name, info.ckey)
	if s2 then roles[s2[4]] = true end
	return roles
end

-- one line for the member list: "Twink von Bedivere - Bergbau + Juwelenschleifen - Prot / Fur"
function Data.Summary(name, info)
	local p = info and info.parsed
	if not p then return "" end
	local parts = {}
	if p.kind == "twink" then table.insert(parts, BG.T("nwin_sug_twink", p.main or "?"))
	elseif p.kind == "main" then table.insert(parts, BG.T("nwin_sug_main")) end
	if table.getn(p.profs) > 0 then
		local names = {}
		for i = 1, table.getn(p.profs) do table.insert(names, BG.Notes.ProfName(p.profs[i])) end
		table.insert(parts, table.concat(names, " + "))
	elseif p.noprof then
		table.insert(parts, BG.T("data_noprof"))
	end
	if p.spec then
		local s = BG.Notes.SpecName(p.spec)
		local s2 = info.ckey and Data.Spec2(name, info.ckey)
		if s2 then s = s .. " / " .. BG.Notes.SpecName(s2) end
		table.insert(parts, s)
	end
	return table.concat(parts, " - ")
end

--------------------------------------------------------------------- saving and sending

local function Changed()
	if BG.Roster and BG.Roster.Reparse then BG.Roster.Reparse() end
	if BG.UI and BG.UI.Refresh then BG.UI.Refresh("members") BG.UI.Refresh("addons") end
	if BG.Stats and BG.Stats.OnRoster then BG.Stats.OnRoster() end
end

local function ProfString(profs, noprof)
	if noprof then return "-" end
	if profs and table.getn(profs) > 0 then return table.concat(profs, "+") end
	return nil
end

-- the new member window: d = { kind = "main" | "twink", main, profs = {codes}, noprof, spec, spec2 }
function Data.Save(name, d)
	name = BG.NormName(name or "")
	if name == "" or not Data.CanEdit() then return false end
	if d.kind == "twink" then
		if not d.main or d.main == "" then return false end
		BG.Roster.SetMain(name, d.main)
	elseif d.kind == "main" then
		BG.Roster.MarkMain(name)
	end
	local rec = { profs = ProfString(d.profs, d.noprof), spec = d.spec, spec2 = d.spec2, ts = time(), by = BG.me }
	Store()[name] = rec
	BG.Send("M", name, rec.profs or "_", rec.spec or "_", rec.spec2 or "_", rec.ts)
	Changed()
	if BG.Notes and BG.Notes.AutoWrite then BG.Notes.AutoWrite(name) end
	return true
end

local function Un(x) if x == nil or x == "_" or x == "" then return nil end return x end

-- notes travel in a field of the message: ';' ':' '%' and '|' are written as %XX
local function Esc(s)
	return (string.gsub(tostring(s or ""), "[%%:;|]", function(c) return string.format("%%%02X", string.byte(c)) end))
end
local function Unesc(s)
	return (string.gsub(s or "", "%%(%x%x)", function(h) return string.char(tonumber(h, 16)) end))
end

local function CleanProfs(s)
	s = Un(s)
	if not s then return nil end
	if s == "-" then return "-" end
	local out = {}
	for code in string.gfind(s, "[^%+]+") do
		local pr = BG.Notes.ProfByCode(code)
		if pr then table.insert(out, pr[1]) end
	end
	if table.getn(out) == 0 then return nil end
	return table.concat(out, "+")
end

local function ValidSpec(classKey, code)
	code = Un(code)
	if not code then return nil end
	if not classKey then return code end -- class not known (yet): accept
	local list = BG.Notes.Specs(classKey)
	for j = 1, table.getn(list) do
		if list[j][1] == code then return code end
	end
	return nil
end

-- one record from the wire (or an import); newest wins
local function Apply(name, profs, spec, spec2, ts, by)
	name = BG.NormName(name or "")
	ts = tonumber(ts) or 0
	if name == "" then return false end
	local old = Data.Get(name)
	if old and (old.ts or 0) >= ts then return false end
	local info = BG.roster and BG.roster[name]
	local ck = info and info.ckey
	Store()[name] = { profs = CleanProfs(profs), spec = ValidSpec(ck, spec), spec2 = ValidSpec(ck, spec2), ts = ts, by = by,
		note = old and old.note, nts = old and old.nts }
	return true
end

-- the shared note: newest wins, independent of the rest of the record
local function ApplyNote(name, nts, text)
	name = BG.NormName(name or "")
	nts = tonumber(nts) or 0
	if name == "" or nts <= 0 then return false end
	local d = Data.Get(name)
	if d and (d.nts or 0) >= nts then return false end
	if not d then d = { ts = 0 } Store()[name] = d end
	text = BG.Trim(Unesc(text))
	d.note = (text ~= "") and text or nil
	d.nts = nts
	return true
end

-- the note field of the new member window (every officer may change it)
function Data.SetNote(name, text)
	name = BG.NormName(name or "")
	if name == "" or not Data.CanEdit() then return false end
	text = BG.Trim(text or "")
	if string.len(text) > 60 then text = string.sub(text, 1, 60) end
	local d = Data.Get(name)
	if (d and d.note or "") == text then return false end
	if not d then d = { ts = 0 } Store()[name] = d end
	d.note = (text ~= "") and text or nil
	d.nts = time()
	BG.Send("N", name, d.nts, Esc(text))
	Changed()
	return true
end

function Data.Note(name)
	local d = Data.Get(name)
	return d and d.note or nil
end

BG.OnComm("N", function(sender, p)
	if not OfficerRank(sender) or not BG.db.sync.accept then return end
	if ApplyNote(p[1], p[2], p[3]) then Changed() end
end)

-- an officer entered something
BG.OnComm("M", function(sender, p)
	if not OfficerRank(sender) or not BG.db.sync.accept then return end
	if Apply(p[1], p[2], p[3], p[4], p[5], sender) then Changed() end
end)

local function Newest()
	local t = 0
	for _, rec in pairs(BG.db.data or {}) do
		if (rec.ts or 0) > t then t = rec.ts end
		if (rec.nts or 0) > t then t = rec.nts end
	end
	return t
end

-- records: name:profs:spec:spec2:ts
local function Encode(name, rec)
	return name .. ":" .. (rec.profs or "_") .. ":" .. (rec.spec or "_") .. ":" .. (rec.spec2 or "_") .. ":" .. tostring(rec.ts or 0)
		.. ":" .. tostring(rec.nts or 0) .. ":" .. (rec.note and Esc(rec.note) or "_")
end

-- a client that just logged in asks for everything newer than what it has; officers answer (the first answer wins)
BG.OnComm("MQ", function(sender, p)
	if not OfficerRank(BG.me) then return end
	local since = tonumber(p[1]) or 0
	local recs = {}
	for name, rec in pairs(BG.db.data or {}) do
		if ((rec.ts or 0) > since and (rec.ts or 0) > 1) or (rec.nts or 0) > since then table.insert(recs, Encode(name, rec)) end
	end
	if table.getn(recs) == 0 then return end
	Data.answered = false
	BG.After(2 + math.random() * 8, function()
		if Data.answered then return end -- somebody else was faster
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
			BG.After((i - 1) * 0.4, function() BG.Send("MS", data) end)
		end
	end)
end)

BG.OnComm("MS", function(sender, p)
	Data.answered = true
	if not OfficerRank(sender) or not BG.db.sync.accept then return end
	local changed = false
	for i = 1, table.getn(p) do
		local f = BG.SplitBy(p[i], ":")
		if f[1] then
			if (tonumber(f[5]) or 0) > 0 and Apply(f[1], f[2], f[3], f[4], f[5], sender) then changed = true end
			if (tonumber(f[6]) or 0) > 0 and ApplyNote(f[1], f[6], (f[7] ~= "_") and f[7] or "") then changed = true end
		end
	end
	if changed then Changed() end
end)

--------------------------------------------------------------------- import of the old guild notes (read only)

-- Reads the guild notes once ("[MAIN] [BB+JC] [Prot]" / "[T Name] ...") and fills the addon data where nothing is known
-- yet. Returns the number of characters taken over and a list { name, note } of notes that could not be read fully.
function Data.ImportNotes()
	local imported, bad = 0, {}
	local db = BG.db
	for name, info in pairs(BG.roster) do
		local note = BG.Trim(info.note or "")
		if note ~= "" then
			local r = BG.Notes.Parse(note, info.ckey)
			local c = db.chars[name]
			local assigned = c and (c.main or c.isMain)
			local took = false
			if r.kind == "twink" and r.main and r.main ~= name and not assigned then
				BG.Roster.SetMain(name, r.main, true)
				took = true
			elseif r.kind == "main" and not assigned then
				BG.Roster.MarkMain(name, true)
				took = true
			end
			local have = Data.Get(name)
			if not have and (table.getn(r.profs) > 0 or r.spec or r.kind) then
				local _, _, g2 = string.find(note, "%[[^%]]*%]%s*%[([^%]]*)%]")
				local profs = nil
				if table.getn(r.profs) > 0 then
					profs = table.concat(r.profs, "+")
				elseif g2 and (BG.Trim(g2) == "-" or BG.Trim(g2) == "") then
					profs = "-"
				end
				Store()[name] = { profs = profs, spec = r.spec and r.spec[1] or nil, ts = 1, by = "import" }
				took = true
			end
			if took then imported = imported + 1 end
			if not r.kind or table.getn(r.warn) > 0 then table.insert(bad, { name = name, note = note }) end
		end
	end
	table.sort(bad, function(a, b) return a.name < b.name end)
	db.dataImported = time()
	db.dataImportBad = {}
	for i = 1, table.getn(bad) do table.insert(db.dataImportBad, bad[i].name) end
	Changed()
	return imported, bad
end

-- popup with the characters whose notes could not be read, so the officers can ask them again or enter the data
function Data.ShowBad(bad)
	if not bad or table.getn(bad) == 0 then return end
	local names = {}
	for i = 1, table.getn(bad) do table.insert(names, bad[i].name) end
	local shown, len = {}, 0
	for i = 1, table.getn(names) do
		if len + string.len(names[i]) + 2 > 330 then break end
		table.insert(shown, names[i])
		len = len + string.len(names[i]) + 2
	end
	local more = table.getn(names) - table.getn(shown)
	local body = table.concat(shown, ", ") .. ((more > 0) and (" ... " .. BG.T("data_bad_more", more)) or "")
	BG.Popup.Push({
		type = "import", key = "databad", force = true,
		title = BG.T("data_bad_title", table.getn(bad)),
		body = body,
		buttons = {
			{ text = BG.T("data_bad_chat"), tip = BG.T("data_bad_chat_tip"), fn = function()
				for i = 1, table.getn(bad) do BG.Print(bad[i].name .. ": " .. bad[i].note) end
			end },
			{ text = BG.T("btn_close"), fn = function() end },
		},
	})
end

-- 1.24 stored the second spec in db.dual: move it over
BG.OnInit(function()
	-- the old private note ("own note") is shared with the officers from now on
	for name, c in pairs(BG.db.chars) do
		if c.note and c.note ~= "" then
			local d = Data.Get(name)
			if not d then d = { ts = 0 } Store()[name] = d end
			if not d.note then d.note = string.sub(c.note, 1, 60) d.nts = 1 end
			c.note = nil
		end
	end
	local old = BG.db.dual
	if not old then return end
	for name, rec in pairs(old) do
		if rec.spec2 and rec.spec2 ~= "-" then
			local d = Data.Get(name)
			if not d then d = { ts = rec.ts or 1, by = rec.by } Store()[name] = d end
			d.spec2 = rec.spec2
		end
	end
	BG.db.dual = nil
end)

-- first start: take over the notes automatically, as soon as the guild list is known (called after every roster scan)
function Data.OnRoster()
	local db = BG.db
	if db.dataImported or Data.importing or not next(BG.roster) then return end
	Data.importing = true
	local n, bad = Data.ImportNotes()
	Data.importing = false
	BG.Print(BG.T("data_import_done", n))
	if Data.CanEdit() then Data.ShowBad(bad) end
end

BG.OnLogin(function()
	BG.After(40 + math.random() * 20, function() BG.Send("MQ", Newest()) end)
end)

--------------------------------------------------------------------- backup as text

-- "BG2;name:flag:main:profs:spec:spec2:ts;..."  (flag m = main, t = twink, n = nothing)
function Data.Export()
	local names, out = {}, {}
	for name in pairs(BG.db.data or {}) do names[name] = true end
	for name, c in pairs(BG.db.chars) do
		if c.main or c.isMain then names[name] = true end
	end
	local list = {}
	for name in pairs(names) do table.insert(list, name) end
	table.sort(list)
	for i = 1, table.getn(list) do
		local name = list[i]
		local c = BG.db.chars[name]
		local d = Data.Get(name) or {}
		local flag = (c and c.main) and "t" or ((c and c.isMain) and "m" or "n")
		table.insert(out, name .. ":" .. flag .. ":" .. ((c and c.main) or "_") .. ":" .. (d.profs or "_") .. ":" .. (d.spec or "_") .. ":" .. (d.spec2 or "_") .. ":" .. tostring(d.ts or 1)
			.. ":" .. tostring(d.nts or 0) .. ":" .. (d.note and Esc(d.note) or "_"))
	end
	return "BG2;" .. table.concat(out, ";"), table.getn(list)
end

-- takes the text of Data.Export (also from another officer); newer data wins. Returns the number of records taken over.
function Data.Import(text)
	text = BG.Trim(text or "")
	if string.sub(text, 1, 4) ~= "BG2;" then return nil end
	local recs = BG.SplitBy(string.sub(text, 5), ";")
	local n = 0
	for i = 1, table.getn(recs) do
		local f = BG.SplitBy(BG.Trim(recs[i]), ":")
		local name = BG.NormName(f[1] or "")
		if name ~= "" then
			local ts = tonumber(f[7]) or 1
			local took = false
			local c = BG.db.chars[name]
			if f[2] == "t" and Un(f[3]) and not (c and (c.main or c.isMain)) then
				BG.Roster.SetMain(name, BG.NormName(f[3]), true) took = true
			elseif f[2] == "m" and not (c and (c.main or c.isMain)) then
				BG.Roster.MarkMain(name, true) took = true
			end
			if Apply(name, f[4], f[5], f[6], ts, "import") then took = true end
			if (tonumber(f[8]) or 0) > 0 and ApplyNote(name, f[8], (f[9] and f[9] ~= "_") and f[9] or "") then took = true end
			if took then n = n + 1 end
		end
	end
	Changed()
	return n
end

BananaGuild = BananaGuild or {}
BananaGuild.files = BananaGuild.files or {}
BananaGuild.files.Data = true
