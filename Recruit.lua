--[[
  BananaGuild - Recruiting
  * automatic guild search (timed post into /4, or /5 while in an instance)
  * only ONE recruiter at a time (guild addon channel lock + conflict popup with funny whispers)
  * whisper popup with predefined answers / invite
  * scanner for "looking for a guild" messages in the channels
  * welcome message for new members
  * "Invite to guild" in the chat-name right click menu
]]

local BG = BananaGuild
local Recruit = {}
BG.Recruit = Recruit

Recruit.active    = false
Recruit.startedAt = 0
Recruit.nextPost  = 0
Recruit.lastPost  = 0
Recruit.posts     = 0
Recruit.others    = {}   -- name -> { started, seen }
Recruit.whisperSeen = {}
Recruit.lastChannelText = ""

local LOCK_TTL = 110   -- seconds without heartbeat -> recruiter counts as stopped
local HEARTBEAT = 45

local function Refresh() if BG.UI and BG.UI.Refresh then BG.UI.Refresh("recruit") end end

--------------------------------------------------------------------- lock handling

function Recruit.OtherActive()
	local now = time()
	local bestName, bestInfo
	for name, info in pairs(Recruit.others) do
		if now - info.seen > LOCK_TTL then
			Recruit.others[name] = nil
		elseif not bestInfo or info.started < bestInfo.started then
			bestName, bestInfo = name, info
		end
	end
	return bestName, bestInfo
end

BG.OnComm("R", function(sender, p)
	local started = tonumber(p[1]) or time()
	Recruit.others[sender] = { started = started, seen = time() }
	if Recruit.active then
		local mine = Recruit.startedAt
		if started < mine or (started == mine and sender < BG.me) then
			Recruit.Stop("conflict", sender)
		else
			BG.Send("R", mine) -- tell the later starter that we were first
		end
	end
	Refresh()
end)

BG.OnComm("RS", function(sender)
	Recruit.others[sender] = nil
	Refresh()
end)

--------------------------------------------------------------------- start / stop

function Recruit.Interval()
	local n = tonumber(BG.db.recruit.interval) or 10
	if n < 1 then n = 1 end
	return n
end

function Recruit.Start(force)
	if Recruit.active then return end
	local db = BG.db
	if not db.features.recruit then BG.Print(BG.T("feature_off")) return end
	if not BG.PickVariant("recruit") then BG.Print(BG.T("rec_nomsg")) return end
	if not IsInGuild or not IsInGuild() then BG.Print(BG.T("not_in_guild")) return end
	local other, info = Recruit.OtherActive()
	if other and not force then
		Recruit.ConflictPopup(other, info)
		return
	end
	Recruit.active = true
	Recruit.startedAt = time()
	Recruit.nextPost = time() + 3
	BG.Send("R", Recruit.startedAt)
	BG.Print(BG.T("rec_started", Recruit.Interval()))
	if CanGuildInvite and not CanGuildInvite() then BG.Print(BG.T("no_invite_right")) end
	Refresh()
end

function Recruit.Stop(reason, by)
	if not Recruit.active then return end
	Recruit.active = false
	BG.Send("RS")
	if reason == "conflict" then
		BG.Print(BG.T("rec_conflict_stop", by or "?"))
		BG.Popup.Push({
			type = "conflict",
			key = "conflict-" .. tostring(by),
			title = BG.T("pop_conflict_title"),
			body = BG.T("rec_conflict_stop", by or "?"),
			buttons = {
				{ text = BG.T("btn_tease"), fn = function() Recruit.Tease(by) end, tip = BG.T("tip_tease") },
				{ text = BG.T("btn_close"), fn = function() end },
			},
		})
	else
		BG.Print(BG.T("rec_stopped"))
	end
	Refresh()
end

function Recruit.Toggle()
	if Recruit.active then Recruit.Stop() else Recruit.Start() end
end

function Recruit.Tease(name)
	if not name then return end
	local line = BG.PickVariant("funny")
	if not line then return end
	BG.SendChat(BG.Fill(line, { name = name }), "WHISPER", name)
end

function Recruit.ConflictPopup(name, info)
	local since = info and BG.Stamp(info.started) or "?"
	BG.Popup.Push({
		key = "lock-" .. name,
		title = BG.T("pop_conflict_title"),
		body = BG.T("pop_conflict_body", name, since),
		buttons = {
			{ text = BG.T("btn_tease"), fn = function() Recruit.Tease(name) end, tip = BG.T("tip_tease") },
			{ text = BG.T("btn_start_anyway"), fn = function() Recruit.Start(true) end },
			{ text = BG.T("btn_cancel"), fn = function() end },
		},
	})
end

--------------------------------------------------------------------- posting

function Recruit.PickChannel()
	local r = BG.db.recruit
	local inst = BG.InInstance()
	local first = inst and r.chInstance or r.chMain
	local second = inst and r.chMain or r.chInstance
	local list = { first, second }
	for i = 1, 2 do
		local n = tonumber(list[i])
		if n and n > 0 and GetChannelName then
			local id = GetChannelName(n)
			if id and id > 0 then return id, n, inst end
		end
	end
	return nil, first, inst
end

--------------------------------------------------------------------- wanted classes / roles

-- The officers pick the classes and roles the guild is looking for. Nothing (or everything) picked = the general search
-- texts; otherwise one of the texts for exactly this kind of list is posted. The list is synced between the officers.
local CLASS_ORDER = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID" }
local CLASS_PLURAL = { WARRIOR = "Krieger", PALADIN = "Paladine", HUNTER = "J\195\164ger", ROGUE = "Schurken", PRIEST = "Priester",
	SHAMAN = "Schamanen", MAGE = "Magier", WARLOCK = "Hexenmeister", DRUID = "Druiden" }
local CLASS_NOM = { WARRIOR = "Krieger", PALADIN = "Paladin", HUNTER = "J\195\164ger", ROGUE = "Schurke", PRIEST = "Priester",
	SHAMAN = "Schamane", MAGE = "Magier", WARLOCK = "Hexenmeister", DRUID = "Druide" }
local CLASS_ACC = { WARRIOR = "Krieger", PALADIN = "Paladin", HUNTER = "J\195\164ger", ROGUE = "Schurken", PRIEST = "Priester",
	SHAMAN = "Schamanen", MAGE = "Magier", WARLOCK = "Hexenmeister", DRUID = "Druiden" }
local ROLE_ORDER = { "T", "H", "D" }
local ROLE_PLURAL = { T = "Tanks", H = "Heiler", D = "DDs" }
Recruit.CLASS_ORDER = CLASS_ORDER
Recruit.ROLE_ORDER = ROLE_ORDER

-- "A", "A und B", "A, B und C"
local function JoinList(list, word)
	local n = table.getn(list)
	if n == 0 then return "" end
	if n == 1 then return list[1] end
	return table.concat(list, ", ", 1, n - 1) .. " " .. word .. " " .. list[n]
end

local function WantedPicked()
	local w = BG.db.wanted
	local classes, roles = {}, {}
	for i = 1, table.getn(CLASS_ORDER) do if w.classes[CLASS_ORDER[i]] then table.insert(classes, CLASS_ORDER[i]) end end
	for i = 1, table.getn(ROLE_ORDER) do if w.roles[ROLE_ORDER[i]] then table.insert(roles, ROLE_ORDER[i]) end end
	return classes, roles
end

-- which text kind fits the list (nil = general search texts), plus the words for the placeholders
function Recruit.WantedKind()
	local classes, roles = WantedPicked()
	local nc, nr = table.getn(classes), table.getn(roles)
	if nc == table.getn(CLASS_ORDER) or nr == table.getn(ROLE_ORDER) or (nc == 0 and nr == 0) then return nil end
	if nr == 0 then
		if nc == 1 then return "recruitOne" end
		if nc <= 4 then return "recruitFew" end
		return "recruitMany"
	end
	if nc == 0 then return "recruitRole" end
	return "recruitMix"
end

function Recruit.WantedVars()
	local classes, roles = WantedPicked()
	local plural = {}
	for i = 1, table.getn(roles) do table.insert(plural, ROLE_PLURAL[roles[i]]) end
	for i = 1, table.getn(classes) do table.insert(plural, CLASS_PLURAL[classes[i]]) end
	local vars = { klassen = JoinList(plural, "und"), klassen_oder = JoinList(plural, "oder") }
	if table.getn(classes) == 1 and table.getn(roles) == 0 then
		vars.klasse, vars.klasse_akk = CLASS_NOM[classes[1]], CLASS_ACC[classes[1]]
	end
	return vars
end

-- readable list for the settings page / popup ("Tanks, Heiler, Magier")
function Recruit.WantedText()
	local classes, roles = WantedPicked()
	local out = {}
	for i = 1, table.getn(roles) do table.insert(out, ROLE_PLURAL[roles[i]]) end
	for i = 1, table.getn(classes) do table.insert(out, CLASS_PLURAL[classes[i]]) end
	return table.concat(out, ", ")
end

-- which roles a class can play (from the specs in the note tables)
local function ClassRoles(key)
	local r = {}
	local specs = BG.Notes.Specs(key)
	for i = 1, table.getn(specs) do r[specs[i][4]] = true end
	return r
end

-- verdict for a player class key: nil (no list active), "class", "role" (+ list of roles), or "no"
function Recruit.WantedMatch(key)
	if not Recruit.WantedKind() or not key then return nil end
	local w = BG.db.wanted
	if w.classes[key] then return "class" end
	local can, got = ClassRoles(key), {}
	for i = 1, table.getn(ROLE_ORDER) do
		local r = ROLE_ORDER[i]
		if w.roles[r] and can[r] then table.insert(got, ROLE_PLURAL[r]) end
	end
	if table.getn(got) > 0 then return "role", table.concat(got, ", ") end
	return "no"
end

function Recruit.WantedLine(key)
	local m, extra = Recruit.WantedMatch(key)
	if not m then return nil end
	local name = BG.Notes.ClassName(key)
	if m == "class" then return "|cffffd100" .. BG.T("wanted_class", name) .. "|r" end
	if m == "role" then return "|cff9be37a" .. BG.T("wanted_role", extra) .. "|r" end
	return "|cffff8844" .. BG.T("wanted_no", name, Recruit.WantedText()) .. "|r"
end

-- officers (rank up to the sync trust rank or the officer rank of the greeting popup) may change and send the list
local function OfficerRank(sender)
	local info = BG.roster[sender]
	if not info then return false end
	local idx = BG.Promo and BG.Promo.RankIndex and BG.Promo.RankIndex(BG.db.greet.rank)
	local lim = math.max(BG.db.sync.trustRank or 2, idx or 0)
	return (info.rankIndex or 99) <= lim
end

function Recruit.CanEditWanted()
	return OfficerRank(BG.me)
end

local function EncodeWanted()
	local w = BG.db.wanted
	local c, r = {}, {}
	for i = 1, table.getn(CLASS_ORDER) do c[i] = w.classes[CLASS_ORDER[i]] and "1" or "0" end
	for i = 1, table.getn(ROLE_ORDER) do r[i] = w.roles[ROLE_ORDER[i]] and "1" or "0" end
	return table.concat(c) .. ";" .. table.concat(r) .. ";" .. tostring(w.ts or 0)
end

function Recruit.BroadcastWanted()
	BG.Send("K", EncodeWanted())
end

-- called by the settings page when an officer ticks a class or role
function Recruit.SetWanted(kind, key, on)
	if not Recruit.CanEditWanted() then return false end
	local w = BG.db.wanted
	w[kind][key] = on and true or nil
	w.ts = time()
	w.by = BG.me
	Recruit.BroadcastWanted()
	Refresh()
	return true
end

function Recruit.SetWantedAll(classes, roles)
	if not Recruit.CanEditWanted() then return false end
	local w = BG.db.wanted
	w.classes, w.roles = {}, {}
	if classes then for i = 1, table.getn(CLASS_ORDER) do w.classes[CLASS_ORDER[i]] = true end end
	w.ts = time()
	w.by = BG.me
	Recruit.BroadcastWanted()
	Refresh()
	return true
end

-- incoming list from an officer: newest wins
BG.OnComm("K", function(sender, p)
	if not OfficerRank(sender) or not BG.db.sync.accept then return end
	local cm, rm, ts = p[1], p[2], tonumber(p[3]) or 0
	if not cm or not rm or string.len(cm) ~= table.getn(CLASS_ORDER) or string.len(rm) ~= table.getn(ROLE_ORDER) then return end
	local w = BG.db.wanted
	if ts <= (w.ts or 0) then return end
	w.classes, w.roles = {}, {}
	for i = 1, table.getn(CLASS_ORDER) do if string.sub(cm, i, i) == "1" then w.classes[CLASS_ORDER[i]] = true end end
	for i = 1, table.getn(ROLE_ORDER) do if string.sub(rm, i, i) == "1" then w.roles[ROLE_ORDER[i]] = true end end
	w.ts, w.by = ts, sender
	Refresh()
end)

-- a client that just logged in asks; officers answer after a random pause (the first answer wins, the rest is ignored by ts)
BG.OnComm("KQ", function(sender)
	if not Recruit.CanEditWanted() or (BG.db.wanted.ts or 0) == 0 then return end
	BG.After(1 + math.random() * 5, function() Recruit.BroadcastWanted() end)
end)

BG.OnLogin(function()
	BG.After(45, function() BG.Send("KQ") end)
end)

function Recruit.PostText()
	local kind = Recruit.WantedKind()
	local vars = kind and Recruit.WantedVars() or {}
	local line
	if kind then
		line = BG.PickVariant(kind)
		if line then
			local msg = BG.Fill(line, vars)
			if string.len(msg) > 255 then
				-- too long with this list: the words for the classes shrink to "viele Klassen"
				vars.klassen, vars.klassen_oder = BG.T("wanted_many"), BG.T("wanted_many")
				msg = BG.Fill(line, vars)
			end
			if string.len(msg) <= 255 then return msg end
		end
	end
	line = BG.PickVariant("recruit")
	if not line then return nil end
	return BG.Fill(line, {})
end

function Recruit.PostNow()
	local id, n, inst = Recruit.PickChannel()
	if not id then
		Recruit.lastChannelText = BG.T("rec_no_channel", n or "?")
		BG.Print(BG.T("rec_no_channel", n or "?"))
		return false
	end
	local msg = Recruit.PostText()
	if not msg then Recruit.lastChannelText = BG.T("rec_nomsg") return false end
	if BG.SendChat(msg, "CHANNEL", id) then
		Recruit.lastPost = time()
		Recruit.posts = Recruit.posts + 1
		BG.db.stats.posts = BG.db.stats.posts + 1
		Recruit.lastChannelText = "/" .. id .. (inst and (" (" .. BG.T("rec_instance") .. ")") or "")
		return true
	end
	return false
end

BG.OnLogin(function()
	BG.Ticker("recruitpost", 1, function()
		if not Recruit.active then return end
		-- heartbeat for the lock
		if not Recruit.hb or time() - Recruit.hb >= HEARTBEAT then
			Recruit.hb = time()
			BG.Send("R", Recruit.startedAt)
		end
		if time() < Recruit.nextPost then return end
		if BG.db.recruit.skipCombat and UnitAffectingCombat and UnitAffectingCombat("player") then
			Recruit.nextPost = time() + 15
			return
		end
		Recruit.nextPost = time() + Recruit.Interval() * 60
		Recruit.PostNow()
		Refresh()
	end)
end)

-- stop cleanly when logging out so others are not blocked for two minutes
BG.On("PLAYER_LEAVING_WORLD", function()
	if Recruit.active then BG.Send("RS") end
end)

--------------------------------------------------------------------- whispers

local function Prospect(name, source)
	BG.db.prospects[name] = { t = time(), src = source }
	BG.db.stats.scans = BG.db.stats.scans + 1
end

-- Guess the language of a whisper: "de" or "en" (ties and unknown -> "de", it is a German guild)
local DE_WORDS = { "hallo", "moin", "servus", "ihr", "wir", "ich", "du", "und", "nicht", "seit", "seid", "bin", "bist",
	"habt", "habe", "hab", "suche", "gilde", "bitte", "danke", "wieder", "noch", "auch", "mal", "kann", "könnt",
	"wollt", "möchte", "aber", "oder", "ein", "eine", "wer", "wie", "was", "jemand", "aufnehmen", "lust", "gerne",
	"grüß", "tach", "euch", "dabei", "mitmachen", "aufnahme", "da", "mich", "mir", "dich", "freue", "gruss" }
local EN_WORDS = { "hello", "hey", "the", "you", "your", "are", "is", "guild", "join", "looking", "can", "please",
	"thanks", "thank", "want", "would", "anyone", "and", "with", "for", "what", "how", "who", "back", "again",
	"there", "still", "recruiting", "invite", "interested", "me", "my", "am", "any", "need", "to", "of" }
local DE_SET, EN_SET = {}, {}
for i = 1, table.getn(DE_WORDS) do DE_SET[DE_WORDS[i]] = true end
for i = 1, table.getn(EN_WORDS) do EN_SET[EN_WORDS[i]] = true end

function Recruit.DetectLang(msg)
	local de, en = 0, 0
	for w in string.gfind(string.lower(msg or ""), "[%a\128-\255]+") do
		if DE_SET[w] then de = de + 1 end
		if EN_SET[w] then en = en + 1 end
	end
	if en > de then return "en" end
	return "de"
end

local function ReplyWhisper(name, text, invite)
	BG.SendChat(BG.Fill(text, { name = name }), "WHISPER", name)
	if invite then
		BG.After(1.2, function() BG.Invite(name) end)
	end
end

--------------------------------------------------------------------- who lookup (class / level / guild of a prospect)
-- WoW 1.12 shows class and level of strangers only through /who. The answer is read from the WHO_LIST_UPDATE event;
-- SetWhoToUI keeps it out of the chat and the friends window stays closed. One query at a time, at most one per 5 s.

Recruit.whoCache = {}
local whoQueue, whoCur, lastWho = {}, nil, -100
local whoFrameHad = false

local function WhoRestore()
	if SetWhoToUI then SetWhoToUI(0) end
	if whoFrameHad and FriendsFrame then FriendsFrame:RegisterEvent("WHO_LIST_UPDATE") end
	whoFrameHad = false
end

local WhoNext

local function WhoFinish(info)
	local cur = whoCur
	whoCur = nil
	WhoRestore()
	if cur then
		Recruit.whoCache[string.lower(cur.name)] = { t = time(), info = info }
		for i = 1, table.getn(cur.cbs) do
			local ok, err = pcall(cur.cbs[i], info)
			if not ok then BG.Fail("who", err) end
		end
	end
	BG.After(1, WhoNext)
end

WhoNext = function()
	if whoCur or table.getn(whoQueue) == 0 then return end
	local wait = 5 - (GetTime() - lastWho)
	if wait > 0 then BG.After(wait + 0.2, WhoNext) return end
	local q = table.remove(whoQueue, 1)
	whoCur = q
	lastWho = GetTime()
	if SetWhoToUI then SetWhoToUI(1) end
	if FriendsFrame and FriendsFrame.UnregisterEvent then
		FriendsFrame:UnregisterEvent("WHO_LIST_UPDATE")
		whoFrameHad = true
	end
	local ok = SendWho and pcall(SendWho, "n-" .. q.name)
	if not ok then WhoFinish(nil) return end
	BG.After(6, function() if whoCur == q then WhoFinish(nil) end end)
end

BG.On("WHO_LIST_UPDATE", function()
	if not whoCur then return end
	local n = GetNumWhoResults and GetNumWhoResults() or 0
	local found
	for i = 1, n do
		local name, guild, level, race, class, zone = GetWhoInfo(i)
		if name and string.lower(name) == string.lower(whoCur.name) then
			found = { name = name, guild = guild, level = level, race = race, class = class, zone = zone }
		end
	end
	WhoFinish(found)
end)

-- cb(info) with info = { level, class, race, guild, zone } or nil (offline / no answer); immediately when cached
function Recruit.Lookup(name, cb)
	local key = string.lower(name)
	local c = Recruit.whoCache[key]
	if c and time() - c.t < 900 and (c.info or time() - c.t < 120) then cb(c.info) return end
	if whoCur and string.lower(whoCur.name) == key then table.insert(whoCur.cbs, cb) return end
	for i = 1, table.getn(whoQueue) do
		if string.lower(whoQueue[i].name) == key then table.insert(whoQueue[i].cbs, cb) return end
	end
	table.insert(whoQueue, { name = name, cbs = { cb } })
	WhoNext()
end

-- one or two lines about the player for the popup
function Recruit.InfoText(info, waiting)
	if waiting then return "|cff999999" .. BG.T("pop_info_wait") .. "|r" end
	if not info then return "|cff999999" .. BG.T("pop_info_none") .. "|r" end
	local col = "|cffffffff"
	local key = BG.Notes and BG.Notes.ClassKey(info.class)
	local rc = key and RAID_CLASS_COLORS and RAID_CLASS_COLORS[key]
	if rc then col = string.format("|cff%02x%02x%02x", math.floor(rc.r * 255 + 0.5), math.floor(rc.g * 255 + 0.5), math.floor(rc.b * 255 + 0.5)) end
	local line1 = "|cffffd100" .. BG.T("pop_info_level", info.level or "?") .. "|r  " .. col .. (info.class or "?") .. "|r"
	if info.race and info.race ~= "" then line1 = line1 .. "  |cffcccccc" .. info.race .. "|r" end
	local guild = (info.guild and info.guild ~= "") and BG.T("pop_info_guild", info.guild) or BG.T("pop_info_noguild")
	local line2 = "|cffcccccc" .. guild
	if info.zone and info.zone ~= "" then line2 = line2 .. "  -  " .. info.zone end
	local out = line1 .. "\n" .. line2 .. "|r"
	-- control: is this class one of the wanted ones?
	local wl = Recruit.WantedLine(key)
	if wl then out = out .. "\n" .. wl end
	return out
end

-- push a popup item and fill in the player info as soon as it is known
local function PushWithInfo(item, name)
	local base = item.body
	local cached = Recruit.whoCache[string.lower(name)]
	local known = cached and time() - cached.t < 900 and (cached.info or time() - cached.t < 120)
	item.body = base .. "\n" .. Recruit.InfoText(known and cached.info, not known)
	BG.Popup.Push(item)
	if not known then
		Recruit.Lookup(name, function(info)
			item.body = base .. "\n" .. Recruit.InfoText(info, false)
			BG.Popup.Refresh(item)
		end)
	end
end

-- The reply variant is rolled when the popup opens, so the tooltip shows exactly what will be sent.
-- "Another variant" rolls again (never the same one twice in a row).
local WhisperPopup
WhisperPopup = function(sender, msg, lang, force, nonce)
	local reply = BG.PickVariant(lang == "en" and "repliesEN" or "repliesDE")
	local buttons = {}
	if reply then
		local tip = BG.Fill(reply, { name = sender })
		table.insert(buttons, { text = BG.T("btn_reply_invite"), tip = tip, fn = function() ReplyWhisper(sender, reply, true) end })
		table.insert(buttons, { text = BG.T("btn_reply"), tip = tip, fn = function() ReplyWhisper(sender, reply, false) end })
		table.insert(buttons, { text = BG.T("btn_other_variant"), fn = function() WhisperPopup(sender, msg, lang, true, (nonce or 0) + 1) end })
	end
	table.insert(buttons, { text = BG.T("btn_invite_only"), fn = function() BG.Invite(sender) end })
	local other = (lang == "en") and "de" or "en"
	table.insert(buttons, { text = BG.T("btn_other_lang", string.upper(other)),
		fn = function() WhisperPopup(sender, msg, other, true) end })
	table.insert(buttons, { text = BG.T("btn_ignore"), fn = function() end })
	local shown = msg
	if string.len(shown) > 160 then shown = string.sub(shown, 1, 157) .. "..." end
	PushWithInfo({
		type = "whisper", defer = true, force = force,
		key = "whisper-" .. sender .. "-" .. lang .. (nonce and ("-" .. nonce) or ""),
		title = BG.T("pop_whisper_title", sender) .. "  |cff999999[" .. string.upper(lang) .. "]|r",
		body = "|cffffffff\"" .. shown .. "\"|r",
		buttons = buttons,
	}, sender)
end

BG.On("CHAT_MSG_WHISPER", function(msg, sender)
	local db = BG.db
	if not db.features.whisperPopup or not sender or sender == BG.me then return end
	local window = (tonumber(db.recruit.window) or 30) * 60
	if not Recruit.active and (time() - Recruit.lastPost) > window then return end
	if BG.Roster.IsMember(sender) then return end
	local seen = Recruit.whisperSeen[sender]
	if seen and time() - seen < 600 then return end
	Recruit.whisperSeen[sender] = time()
	Prospect(sender, "whisper")
	BG.AddLog("prospect", sender, BG.T("src_whisper"))
	WhisperPopup(sender, msg or "", Recruit.DetectLang(msg))
end)

--------------------------------------------------------------------- scanner (/4 /5)

local kwCache = {}
local function KW(name)
	local raw = BG.db.keywords[name] or ""
	local c = kwCache[name]
	if not c or c.raw ~= raw then
		local list = BG.Lines(string.lower(raw))
		c = { raw = raw, list = list }
		kwCache[name] = c
	end
	return c.list
end

local function Contains(s, kw)
	local init = 1
	local needBoundary = string.find(string.sub(kw, 1, 1), "%w") ~= nil
	while true do
		local a = string.find(s, kw, init, true)
		if not a then return false end
		if not needBoundary or a == 1 then return true end
		if not string.find(string.sub(s, a - 1, a - 1), "%a") then return true end
		init = a + 1
	end
end

local function HasAny(s, list)
	for i = 1, table.getn(list) do
		if Contains(s, list[i]) then return true end
	end
	return false
end

-- returns "de", "en" or nil
function Recruit.Classify(msg)
	if not msg or msg == "" then return nil end
	local s = string.lower(msg)
	if HasAny(s, KW("kwExclude")) then return nil end
	local mode = BG.db.scanner.lang
	if mode ~= "en" and HasAny(s, KW("kwGuildDE")) and HasAny(s, KW("kwSeekDE")) then return "de" end
	if mode ~= "de" and HasAny(s, KW("kwGuildEN")) and HasAny(s, KW("kwSeekEN")) then return "en" end
	return nil
end

local function ScanChannels()
	local set = {}
	for n in string.gfind(BG.db.scanner.channels or "", "%d+") do set[tonumber(n)] = true end
	return set
end

local ScannerPopup
ScannerPopup = function(author, msg, lang, chan, force, nonce)
	local text = BG.PickVariant(lang == "en" and "contactEN" or "contactDE")
	local shown = msg
	if string.len(shown) > 150 then shown = string.sub(shown, 1, 147) .. "..." end
	local buttons = {}
	if text then
		local tip = BG.Fill(text, { name = author })
		local function whisper() BG.SendChat(tip, "WHISPER", author) end
		table.insert(buttons, { text = BG.T("btn_contact_invite"), tip = tip,
			fn = function() whisper() BG.After(1.2, function() BG.Invite(author) end) end })
		table.insert(buttons, { text = BG.T("btn_contact"), tip = tip, fn = whisper })
		table.insert(buttons, { text = BG.T("btn_other_variant"), fn = function() ScannerPopup(author, msg, lang, chan, true, (nonce or 0) + 1) end })
	end
	table.insert(buttons, { text = BG.T("btn_invite_only"), fn = function() BG.Invite(author) end })
	table.insert(buttons, { text = BG.T("btn_ignore"), fn = function() end })
	PushWithInfo({
		type = "scanner", defer = true, force = force,
		key = "scan-" .. author .. (nonce and ("-" .. nonce) or ""),
		title = BG.T("pop_scan_title", author),
		body = "|cff999999[" .. tostring(chan) .. "]|r |cffffffff" .. shown .. "|r",
		buttons = buttons,
	}, author)
end

BG.On("CHAT_MSG_CHANNEL", function(msg, author, language, chanFull, target, flags, zoneId, chanNum, chanName)
	local db = BG.db
	if not db.features.scanner or not msg or not author or author == BG.me then return end
	if BananaPresence and string.sub(msg, 1, string.len(BananaPresence.MARK)) == BananaPresence.MARK then return end
	local num = tonumber(chanNum)
	if not num and chanFull then
		local _, _, d = string.find(chanFull, "^(%d+)")
		num = tonumber(d)
	end
	if not num or not ScanChannels()[num] then return end
	local lang = Recruit.Classify(msg)
	if not lang then return end
	if BG.Roster.IsMember(author) then return end
	local p = db.prospects[author]
	local cd = (tonumber(db.scanner.cooldown) or 30) * 60
	if p and time() - p.t < cd then return end
	Prospect(author, "scan")
	BG.AddLog("prospect", author, BG.T("src_scan"))
	ScannerPopup(author, msg, lang, num)
end)

--------------------------------------------------------------------- welcome

-- Which greeting is used: the recruiter / inviter always sends the greeting with the Discord link (welcomeRec); officers
-- who only react to somebody else's join use the role play greeting (welcome). Without a real Discord link the
-- recruiter falls back to the role play text.
function BG.DiscordReady()
	local d = BG.Trim((BG.db and BG.db.discord) or "")
	return d ~= "" and not string.find(string.lower(d), "dein-link", 1, true)
end

function Recruit.WelcomeKind(quiet)
	if BG.DiscordReady() then return "welcomeRec" end
	if not quiet then BG.Print(BG.T("welcome_nodiscord")) end
	return "welcome"
end

-- The greeting goes to guild chat (random variant); there is no whisper. Returns true when it was sent.
-- kind: "welcome" (role play, officers) or nil = recruiter greeting with Discord. Several people may greet (more life in chat);
-- the only rule: officers always use the role play text, the Discord text is the recruiter's alone.
function Recruit.Welcome(name, text, kind)
	local db = BG.db
	if not name or name == "" then return false end
	text = text or BG.PickVariant(kind or Recruit.WelcomeKind())
	if text and BG.Trim(text) ~= "" then
		BG.SendChat(BG.Fill(text, { name = name }), "GUILD")
	end
	db.stats.welcomes = db.stats.welcomes + 1
	return true
end

-- A join is "mine" when I invited the player (recent invite), or - when nobody is known to have invited him - while I
-- am recruiting. The inviter greets automatically.
function Recruit.IsMyJoin(name)
	local inv = BG.pendingInvites and BG.pendingInvites[name]
	if inv and inv.at and time() - inv.at < 86400 then return inv.by == BG.me end
	return Recruit.active and true or false
end

-- Officers (rank setting) get a small greeting popup for every join; the note window is only for the inviter / recruiter.
function Recruit.IsOfficer()
	local me = BG.roster and BG.roster[BG.me]
	if not me or not me.rankIndex then return false end
	local idx = BG.Promo and BG.Promo.RankIndex and BG.Promo.RankIndex(BG.db.greet.rank)
	if idx == nil then idx = BG.db.sync.trustRank or 2 end
	return me.rankIndex <= idx
end

-- fromRoster: only the roster diff noticed the join (no system message); then only the inviter / recruiter reacts, not every officer
function Recruit.OnJoin(name, fromRoster)
	local db = BG.db
	if name == BG.me then return end
	Recruit.joinSeen = Recruit.joinSeen or {}
	if Recruit.joinSeen[name] and time() - Recruit.joinSeen[name] < 300 then return end
	local mine = Recruit.IsMyJoin(name)
	if not mine and (fromRoster or not Recruit.IsOfficer()) then return end
	Recruit.joinSeen[name] = time()
	if not mine then
		-- an officer who did not invite him: only a small popup with a role play greeting, no note window
		if db.features.welcomePopup then
			BG.After(2, function()
				local text = BG.PickVariant("welcome")
				BG.Popup.Push({
					type = "welcome", defer = true,
					key = "join-" .. name,
					title = BG.T("pop_join_title", name),
					body = BG.T("pop_join_body", name),
					buttons = {
						{ text = BG.T("btn_welcome"), tip = text and BG.Fill(text, { name = name }),
						  fn = function() Recruit.Welcome(name, text, "welcome") end },
						{ text = BG.T("btn_ignore"), fn = function() end },
					},
				})
			end)
		end
		return
	end
	if db.features.autoWelcome then
		BG.After(3, function() Recruit.Welcome(name) end)
	end
	if db.features.joinWindow then
		-- window to enter the guild note (main/twink, professions, spec); the roster needs a moment to know the new member
		if GuildRoster then GuildRoster() end
		BG.After(4, function()
			BG.Popup.Push({
				type = "welcome", defer = true,
				key = "join-" .. name,
				open = function() BG.NoteWin.Open(name, "join", { greet = true }) end,
			})
		end)
	elseif not db.features.autoWelcome and db.features.welcomePopup then
		local text = BG.PickVariant(Recruit.WelcomeKind())
		BG.Popup.Push({
			type = "welcome", defer = true,
			key = "join-" .. name,
			title = BG.T("pop_join_title", name),
			body = BG.T("pop_join_body", name),
			buttons = {
				{ text = BG.T("btn_welcome"), tip = text and BG.Fill(text, { name = name }), fn = function() Recruit.Welcome(name, text) end },
				{ text = BG.T("btn_ignore"), fn = function() end },
			},
		})
	end
end

--------------------------------------------------------------------- chat-name right click menu

local MENU_VALUE = "BG_GUILD_INVITE"

function Recruit.RelabelMenu()
	if UnitPopupButtons and UnitPopupButtons[MENU_VALUE] then
		UnitPopupButtons[MENU_VALUE].text = BG.T("menu_invite")
	end
end

BG.OnInit(function()
	if not UnitPopupButtons or not UnitPopupMenus then return end
	UnitPopupButtons[MENU_VALUE] = { text = BG.T("menu_invite"), dist = 0 }
	local targets = { "FRIEND", "PLAYER" }
	for t = 1, table.getn(targets) do
		local menu = UnitPopupMenus[targets[t]]
		if menu then
			local has = false
			for i = 1, table.getn(menu) do if menu[i] == MENU_VALUE then has = true end end
			if not has then
				local pos = table.getn(menu)
				for i = 1, table.getn(menu) do
					if menu[i] == "CANCEL" then pos = i break end
				end
				table.insert(menu, pos, MENU_VALUE)
			end
		end
	end

	if UnitPopup_OnClick and not BG.hookedPopupClick then
		BG.hookedPopupClick = true
		local origClick = UnitPopup_OnClick
		UnitPopup_OnClick = function()
			if this and this.value == MENU_VALUE then
				local dd = getglobal(UIDROPDOWNMENU_INIT_MENU)
				local name = dd and dd.name
				if (not name or name == "") and dd and dd.unit then name = UnitName(dd.unit) end
				if name and name ~= "" then BG.Invite(BG.NormName(name)) end
				return
			end
			return origClick()
		end
	end

	if UnitPopup_HideButtons and not BG.hookedPopupHide then
		BG.hookedPopupHide = true
		local origHide = UnitPopup_HideButtons
		UnitPopup_HideButtons = function()
			origHide()
			local ok = pcall(function()
				local dd = getglobal(UIDROPDOWNMENU_INIT_MENU)
				local menu = dd and UnitPopupMenus[dd.which]
				if not menu then return end
				local hide = (not BG.db.features.rightClickInvite) or (CanGuildInvite and not CanGuildInvite())
					or (dd.name and BG.me and dd.name == BG.me)
				for i = 1, table.getn(menu) do
					if menu[i] == MENU_VALUE and hide then
						UnitPopupShown[UIDROPDOWNMENU_MENU_LEVEL][i] = 0
					end
				end
			end)
		end
	end
end)

BananaGuild = BananaGuild or {}
BananaGuild.files = BananaGuild.files or {}
BananaGuild.files.Recruit = true
