--[[
  BananaGuild - Core
  Lua 5.0 / WoW 1.12 API: no '#', no '%', no string.match/gmatch, no select, no varargs tricks.
]]

BananaGuild = BananaGuild or {}
local BG = BananaGuild

BG.name    = "BananaGuild"
BG.version = (GetAddOnMetadata and GetAddOnMetadata("BananaGuild", "Version")) or "1.0.0"
BG.PREFIX  = "BGLD"
BG.SEP     = ";"
BG.LOGO    = "Interface\\AddOns\\BananaGuild\\Media\\logo" -- replaced in Boot() with the real folder name
BG.errors  = {}

-- People / links shown in the Support window. Edit freely.
BG.SUPPORT = {
	{ name = "Lumihunt", role = "Addon Author & Support" },
}

-- The Banana addons the dashboard looks for. 'aliases' are the folder names tried in order.
BG.TRACKED = {
	{ key = "craft",    label = "BananaCraft",     aliases = { "BananaCraft" } },
	{ key = "bank",     label = "BananaBank",      aliases = { "BananaBank" } },
	{ key = "lootline", label = "Banana Lootline", aliases = { "BananaLootline", "Banana_Lootline", "BananaLootLine", "Banana-Lootline" } },
	{ key = "loot",     label = "Bananaloot",      aliases = { "BananaLoot", "Bananaloot", "Banana_Loot" } },
	{ key = "guild",    label = "BananaGuild",     aliases = { "BananaGuild" } },
}

--------------------------------------------------------------------- small helpers

function BG.Print(msg)
	if DEFAULT_CHAT_FRAME then
		DEFAULT_CHAT_FRAME:AddMessage("|cffffd100[BananaGuild]|r " .. tostring(msg))
	end
end

function BG.Trim(s)
	if not s then return "" end
	s = string.gsub(s, "^%s+", "")
	s = string.gsub(s, "%s+$", "")
	return s
end

-- "tHRALL " -> "Thrall"
function BG.NormName(s)
	s = BG.Trim(s)
	if s == "" then return "" end
	s = string.gsub(s, "%-.*$", "") -- strip realm suffix if any
	return string.upper(string.sub(s, 1, 1)) .. string.lower(string.sub(s, 2))
end

function BG.SplitBy(s, sep)
	local out = {}
	if not s then return out end
	local pos = 1
	while true do
		local a, b = string.find(s, sep, pos, true)
		if not a then
			table.insert(out, string.sub(s, pos))
			break
		end
		table.insert(out, string.sub(s, pos, a - 1))
		pos = b + 1
	end
	return out
end

-- multi-line text -> array of non-empty trimmed lines
function BG.Lines(s)
	local out = {}
	if not s then return out end
	local parts = BG.SplitBy(string.gsub(s, "\r", ""), "\n")
	for i = 1, table.getn(parts) do
		local l = BG.Trim(parts[i])
		if l ~= "" then table.insert(out, l) end
	end
	return out
end

function BG.RandomLine(s)
	local l = BG.Lines(s)
	local n = table.getn(l)
	if n == 0 then return nil end
	return l[math.random(1, n)]
end

function BG.Today()
	return date("%Y-%m-%d")
end

function BG.Stamp(t)
	return date("%d.%m.%Y %H:%M", t or time())
end

function BG.Count(t)
	local n = 0
	if t then for _ in pairs(t) do n = n + 1 end end
	return n
end

--------------------------------------------------------------------- localisation

function BG.Lang()
	return (BG.db and BG.db.lang) or ((GetLocale and GetLocale() == "deDE") and "de" or "en")
end

function BG.T(key, a1, a2, a3, a4)
	local L = BG.L
	local lang = BG.Lang()
	local s = (L and L[lang] and L[lang][key]) or (L and L.en and L.en[key]) or key
	if a1 ~= nil then
		local ok, res = pcall(string.format, s, a1, a2, a3, a4)
		if ok then return res end
	end
	return s
end

-- Replace {name} {discord} {guild} {level} (and the old *Spielername* / *Discord Link* style)
function BG.Fill(tpl, vars)
	vars = vars or {}
	tpl = tpl or ""
	local db = BG.db or {}
	local function val(k)
		if vars[k] ~= nil then return tostring(vars[k]) end
		if k == "discord" then return db.discord or "" end
		if k == "guild" then return db.guildTag or "" end
		return "{" .. k .. "}"
	end
	tpl = string.gsub(tpl, "{(%w+)}", val)
	tpl = string.gsub(tpl, "%*[Ss]pielername%*", val("name"))
	tpl = string.gsub(tpl, "%*[Pp]layer[Nn]ame%*", val("name"))
	tpl = string.gsub(tpl, "%*[Dd]iscord[ %-]?[Ll]ink%*", val("discord"))
	return tpl
end

--------------------------------------------------------------------- defaults / DB

BG.KEYWORD_DEFAULTS = {
	-- the word "guild" itself
	kwGuildDE = "gilde\ngilden\ngildenlos\ngildensuche\ngildensuchende",
	kwGuildEN = "guild\nguildless\nguilds",
	-- something that says "I am LOOKING for one" (not "we recruit")
	kwSeekDE  = "suche\nsuchen\nsucht jemand\nauf der suche\njemand\nwer hat\nhat wer\nkennt wer\nwer kennt\ngibt es\ngibts\ngibt's\nnimmt\nnehmt\naufnahme\naufnehmen\naufgenommen\neinladen\ninv\nheimat\nanschluss\nbrauche\nsuch\nwer nimmt\n?",
	kwSeekEN  = "looking for\nlf\nlfg\nneed a\nneed guild\nany guild\nanyone know\nanybody\nknow of\nrecommend\njoin a\nwanna join\nwant to join\nsearching\nseeking\ninv\ninvite\n?",
	-- messages of OTHER guilds that recruit (must not trigger the popup)
	kwExclude = "recruit\nrekrut\nwir suchen\nwir sind\nwe are\nwe're\nsuchen wir\nlf members\nlf more\nlfm\nlooking for members\nlooking for more\ngilde sucht\nsucht mitglieder\nsucht member\nsucht spieler\njoin us\ntritt bei\nschliess dich\nschließ dich\nwerde teil\nbieten\nbiete\nunsere gilde\nour guild\ngildenbank\ngildenchat\ngildenkasse\ngildenmeister\nguildbank\nguild bank\ngbank\n<",
}

local DEFAULTS = {
	lang    = nil,
	discord = "discord.gg/DEIN-LINK",
	guildTag = "<Bananenrepublik>",
	features = {
		levelup          = true,   -- chat hint + toast when a guild member levels up
		level60          = true,   -- big splash at level 60
		recruit          = true,   -- recruiting module available
		whisperPopup     = true,   -- popup when somebody whispers after our ad
		scanner          = true,   -- /4 /5 scanner for "looking for a guild"
		rightClickInvite = true,   -- "Invite to guild" in the chat-name context menu
		welcomePopup     = true,   -- popup when somebody joins the guild
		welcomeGuild     = true,   -- also greet the new member in guild chat
		autoWelcome      = false,  -- send the welcome whisper automatically
		guildBroadcast   = true,   -- invisible addon channel (presence, recruiter lock, sync)
		worldPing        = false,  -- hidden world-chat presence ping (see README)
		minimap          = true,
		sound            = true,
		selfToast        = false,  -- also show toast for our own level ups
	},
	recruit = {
		interval  = 10,   -- minutes
		chMain    = 4,    -- /4
		chInstance = 5,   -- /5 used while inside an instance
		skipCombat = true,
		window    = 30,   -- minutes after the last ad in which whispers count as answers
	},
	scanner = {
		lang     = "both", -- de | en | both
		cooldown = 30,     -- minutes before the same player triggers again
		channels = "4,5",
	},
	sync = { accept = true, trustRank = 2 },
	minimap = { angle = 200 },
	texts = {},
	keywords = {},
	chars = {},
	log = {},
	presence = {},
	levels = {},
	prospects = {},
	stats = { posts = 0, scans = 0, invites = 0, welcomes = 0 },
}
BG.DEFAULTS = DEFAULTS

local function Merge(dst, src)
	for k, v in pairs(src) do
		if type(v) == "table" then
			if type(dst[k]) ~= "table" then dst[k] = {} end
			Merge(dst[k], v)
		elseif dst[k] == nil then
			dst[k] = v
		end
	end
end

BG.TEXT_NAMES = { "recruitMsg", "welcomeMsg", "welcomeGuild", "repliesDE", "repliesEN", "contactDE", "contactEN", "funny", "gz" }

-- "contactDE" / "repliesEN" ... are tied to one language, independent of the UI language
function BG.FixedLang(name)
	local suffix = string.sub(name, -2)
	if suffix == "DE" then return "de" end
	if suffix == "EN" then return "en" end
	return nil
end

function BG.DefaultText(name, lang)
	lang = lang or BG.Lang()
	local L = BG.L
	return (L and L[lang] and L[lang]["def_" .. name]) or (L and L.en and L.en["def_" .. name]) or ""
end

function BG.ResetTexts(lang)
	for i = 1, table.getn(BG.TEXT_NAMES) do
		local n = BG.TEXT_NAMES[i]
		BG.db.texts[n] = BG.DefaultText(n, lang)
	end
	-- texts that exist once per language are always reset to their own language
	for i = 1, table.getn(BG.TEXT_NAMES) do
		local n = BG.TEXT_NAMES[i]
		if BG.FixedLang(n) then BG.db.texts[n] = BG.DefaultText(n, BG.FixedLang(n)) end
	end
end

function BG.ResetKeywords()
	for k, v in pairs(BG.KEYWORD_DEFAULTS) do BG.db.keywords[k] = v end
end

local function InitDB()
	BananaGuildDB = BananaGuildDB or {}
	BG.db = BananaGuildDB
	Merge(BG.db, DEFAULTS)
	if not BG.db.lang then
		BG.db.lang = (GetLocale and GetLocale() == "deDE") and "de" or "en"
	end
	for i = 1, table.getn(BG.TEXT_NAMES) do
		local n = BG.TEXT_NAMES[i]
		if BG.db.texts[n] == nil then
			if BG.FixedLang(n) then
				BG.db.texts[n] = BG.DefaultText(n, BG.FixedLang(n))
			else
				BG.db.texts[n] = BG.DefaultText(n)
			end
		end
	end
	for k, v in pairs(BG.KEYWORD_DEFAULTS) do
		if BG.db.keywords[k] == nil then BG.db.keywords[k] = v end
	end
	-- trim logs
	while table.getn(BG.db.log) > 600 do table.remove(BG.db.log, 1) end
end

--------------------------------------------------------------------- events / timers

BG.handlers = {}
BG.initHooks = {}
BG.loginHooks = {}
BG.timers = {}
BG.tickers = {}

local frame = CreateFrame("Frame", "BananaGuildCoreFrame")
BG.frame = frame

local function Fail(where, err)
	local msg = where .. ": " .. tostring(err)
	table.insert(BG.errors, msg)
	if table.getn(BG.errors) > 25 then table.remove(BG.errors, 1) end
	if DEFAULT_CHAT_FRAME then
		DEFAULT_CHAT_FRAME:AddMessage("|cffff5555[BananaGuild] error|r " .. msg)
	end
end
BG.Fail = Fail

function BG.On(ev, fn)
	if not BG.handlers[ev] then
		BG.handlers[ev] = {}
		frame:RegisterEvent(ev)
	end
	table.insert(BG.handlers[ev], fn)
end

function BG.OnInit(fn)  table.insert(BG.initHooks, fn)  end
function BG.OnLogin(fn) table.insert(BG.loginHooks, fn) end

function BG.After(delay, fn)
	table.insert(BG.timers, { at = GetTime() + delay, fn = fn })
end

-- fn is called every 'interval' seconds (first call after one interval)
function BG.Ticker(name, interval, fn)
	BG.tickers[name] = { interval = interval, nextAt = GetTime() + interval, fn = fn }
end

local function RunList(list, where)
	for i = 1, table.getn(list) do
		local ok, err = pcall(list[i])
		if not ok then Fail(where, err) end
	end
end

-- Find the real folder name (it may be "bananaguild", "BananaGuild-main", ...)
local function FindFolder()
	if GetNumAddOns and GetAddOnInfo then
		for i = 1, GetNumAddOns() do
			local n = GetAddOnInfo(i)
			if n and string.find(string.lower(n), "bananaguild", 1, true) then return n end
		end
	end
	return "BananaGuild"
end

local function Boot(name)
	if BG.booted then return end
	BG.booted = true
	BG.folder = name or FindFolder()
	BG.LOGO = "Interface\\AddOns\\" .. BG.folder .. "\\Media\\logo"
	local ok, err = pcall(InitDB)
	if not ok then Fail("InitDB", err) return end
	BG.loaded = true
	RunList(BG.initHooks, "init")
end
BG.Boot = Boot

frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")

frame:SetScript("OnEvent", function()
	local ev = event
	local a1, a2, a3, a4, a5, a6, a7, a8, a9 = arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9
	if ev == "ADDON_LOADED" then
		if a1 and string.lower(a1) == "bananaguild" then Boot(a1) end
		return
	elseif ev == "PLAYER_LOGIN" then
		if not BG.loaded then Boot(nil) end
		if not BG.loaded then return end
		BG.me = UnitName("player")
		BG.loggedIn = true
		RunList(BG.loginHooks, "login")
	end
	local list = BG.handlers[ev]
	if list and BG.loaded then
		for i = 1, table.getn(list) do
			local ok, err = pcall(list[i], a1, a2, a3, a4, a5, a6, a7, a8, a9)
			if not ok then Fail(ev, err) end
		end
	end
end)

frame:SetScript("OnUpdate", function()
	local now = GetTime()
	local n = table.getn(BG.timers)
	for i = n, 1, -1 do
		local t = BG.timers[i]
		if t and now >= t.at then
			table.remove(BG.timers, i)
			local ok, err = pcall(t.fn)
			if not ok then Fail("timer", err) end
		end
	end
	for name, t in pairs(BG.tickers) do
		if now >= t.nextAt then
			t.nextAt = now + t.interval
			local ok, err = pcall(t.fn)
			if not ok then Fail("ticker " .. name, err) end
		end
	end
end)

--------------------------------------------------------------------- guild comms (addon channel)

BG.comm = {}

function BG.OnComm(kind, fn)
	BG.comm[kind] = fn
end

function BG.Send(a, b, c, d, e)
	-- BG.Send("R", x, y)  ->  "R;x;y"  (never use the pipe char: the server treats it as a chat escape)
	local parts = {}
	local list = { a, b, c, d, e }
	for i = 1, 5 do
		if list[i] == nil then break end
		parts[i] = tostring(list[i])
	end
	local msg = table.concat(parts, BG.SEP)
	if not SendAddonMessage or not IsInGuild or not IsInGuild() then return false end
	if BG.db and not BG.db.features.guildBroadcast then return false end
	if string.len(msg) > 250 then msg = string.sub(msg, 1, 250) end
	SendAddonMessage(BG.PREFIX, msg, "GUILD")
	return true
end

BG.On("CHAT_MSG_ADDON", function(prefix, msg, channel, sender)
	if prefix ~= BG.PREFIX or not msg then return end
	if sender == BG.me then return end
	local _, _, kind, rest = string.find(msg, "^(%a+);?(.*)$")
	local fn = kind and BG.comm[kind]
	if fn then fn(sender, BG.SplitBy(rest or "", BG.SEP), rest) end
end)

--------------------------------------------------------------------- chat helpers

function BG.SendChat(msg, chatType, target)
	if not msg or msg == "" then return false end
	if string.len(msg) > 255 then msg = string.sub(msg, 1, 255) end
	local ok, err
	if chatType == "WHISPER" then
		ok, err = pcall(SendChatMessage, msg, "WHISPER", nil, target)
	elseif chatType == "CHANNEL" then
		ok, err = pcall(SendChatMessage, msg, "CHANNEL", nil, target)
	else
		ok, err = pcall(SendChatMessage, msg, chatType)
	end
	if not ok then Fail("SendChat", err) end
	return ok
end

function BG.Invite(name)
	if not name or name == "" then return false end
	if not IsInGuild or not IsInGuild() then BG.Print(BG.T("not_in_guild")) return false end
	if CanGuildInvite and not CanGuildInvite() then BG.Print(BG.T("no_invite_right")) return false end
	BG.pendingInvites = BG.pendingInvites or {}
	BG.pendingInvites[BG.NormName(name)] = { by = BG.me, at = time() }
	BG.db.stats.invites = BG.db.stats.invites + 1
	local ok, err = pcall(GuildInviteByName, name)
	if not ok then Fail("GuildInviteByName", err) return false end
	BG.Send("I", name, BG.me)
	BG.AddLog("invite", BG.me, name)
	return true
end

BG.OnComm("I", function(sender, p)
	local who = BG.NormName(p[1] or "")
	if who == "" then return end
	BG.pendingInvites = BG.pendingInvites or {}
	if not BG.pendingInvites[who] then
		BG.pendingInvites[who] = { by = sender, at = time() }
		BG.AddLog("invite", sender, who)
	end
end)

--------------------------------------------------------------------- log

-- kinds: join leave kick promote demote invite levelup level60
function BG.AddLog(kind, a, b, c)
	if not BG.db then return end
	table.insert(BG.db.log, { t = time(), k = kind, a = a, b = b, c = c })
	while table.getn(BG.db.log) > 600 do table.remove(BG.db.log, 1) end
	if BG.UI and BG.UI.Refresh then BG.UI.Refresh("log") end
end

function BG.LogText(e)
	local k = e.k
	local function V(x) if x == nil or x == "" then return "?" end return x end
	local a, b, c = V(e.a), V(e.b), V(e.c)
	local key = "log_" .. tostring(k)
	return BG.T(key, a, b, c)
end

--------------------------------------------------------------------- instance detection

local INSTANCE_FRAGMENTS = {
	"ragefire", "wailing caverns", "deadmines", "shadowfang", "blackfathom", "stockade", "gnomeregan",
	"razorfen", "scarlet monastery", "uldaman", "zul'farrak", "maraudon", "sunken temple", "atal'hakkar",
	"blackrock", "dire maul", "stratholme", "scholomance", "molten core", "onyxia", "blackwing",
	"zul'gurub", "ahn'qiraj", "naxxramas", "warsong gulch", "arathi basin", "alterac valley",
	-- deDE
	"flammenschlund", "wehklagens", "todesminen", "schattenfang", "verlies", "kral der klingen",
	"klingenhauer", "kloster", "atal'hakkar", "schwarzfels", "sterbruch", "geschmolzene", "geschmolzener",
	"pechschwingen", "ahn'qiraj", "kriegshymne", "arathibecken", "alteractal",
}

function BG.InInstance()
	if IsInInstance then
		local ok, a = pcall(IsInInstance)
		if ok and a then return true end
	end
	local zone = GetRealZoneText and GetRealZoneText() or ""
	if zone == "" then return false end
	zone = string.lower(zone)
	for i = 1, table.getn(INSTANCE_FRAGMENTS) do
		if string.find(zone, INSTANCE_FRAGMENTS[i], 1, true) then return true end
	end
	return false
end

--------------------------------------------------------------------- slash commands

SLASH_BANANAGUILD1 = "/bananaguild"
SLASH_BANANAGUILD2 = "/bguild"
SLASH_BANANAGUILD3 = "/bgd"

local function Slash(msg)
	if not BG.loaded then
		if not BG.booted then pcall(Boot, nil) end
		if not BG.loaded then
			local missing = {}
			for _, f in ipairs({ "BananaPresence", "Locale", "Core", "Presence", "Roster", "Alerts", "Recruit", "UI", "SelfTest" }) do
				if not (BG.files and BG.files[f]) then table.insert(missing, f) end
			end
			DEFAULT_CHAT_FRAME:AddMessage("|cffff5555[BananaGuild] not initialised.|r folder=" .. tostring(BG.folder)
				.. " files not loaded: " .. (table.getn(missing) > 0 and table.concat(missing, ",") or "none")
				.. " last error: " .. tostring(BG.errors[table.getn(BG.errors)]))
			return
		end
	end
	msg = BG.Trim(msg or "")
	local _, _, cmd, rest = string.find(msg, "^(%S*)%s*(.-)$")
	cmd = string.lower(cmd or "")
	if cmd == "" or cmd == "show" or cmd == "toggle" then
		BG.UI.Toggle()
	elseif cmd == "selftest" or cmd == "test" then
		BG.UI.Show("selftest")
		BG.SelfTest.Run()
	elseif cmd == "recruit" then
		local sub = string.lower(rest or "")
		if sub == "start" then BG.Recruit.Start() elseif sub == "stop" then BG.Recruit.Stop() else BG.UI.Show("recruit") end
	elseif cmd == "gz" then
		BG.Alerts.SendGZ(rest ~= "" and rest or nil)
	elseif cmd == "test60" then
		BG.Alerts.ShowLevel60(rest ~= "" and BG.NormName(rest) or BG.me, true)
	elseif cmd == "testlevel" then
		BG.Alerts.LevelToast(rest ~= "" and BG.NormName(rest) or BG.me, 42, true)
	elseif cmd == "welcome" then
		if rest ~= "" then BG.Recruit.Welcome(BG.NormName(rest)) else BG.Print(BG.T("usage_welcome")) end
	elseif cmd == "who" or cmd == "scan" then
		BG.Presence.Query()
	elseif cmd == "lang" then
		BG.SetLang(string.lower(rest) == "en" and "en" or "de")
	else
		BG.Print(BG.T("help1"))
		BG.Print(BG.T("help2"))
		BG.Print(BG.T("help3"))
	end
end

SlashCmdList["BANANAGUILD"] = function(msg)
	local ok, err = pcall(Slash, msg)
	if not ok then Fail("slash", err) end
end

function BG.SetLang(lang)
	BG.db.lang = (lang == "en") and "en" or "de"
	if BG.UI and BG.UI.ApplyLocale then BG.UI.ApplyLocale() end
end

BananaGuild = BananaGuild or {}
BananaGuild.files = BananaGuild.files or {}
BananaGuild.files.Core = true
