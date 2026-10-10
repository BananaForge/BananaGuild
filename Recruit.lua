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
	if BG.Trim(db.texts.recruitMsg) == "" then BG.Print(BG.T("rec_nomsg")) return end
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
	local line = BG.RandomLine(BG.db.texts.funny)
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

function Recruit.PostNow()
	local id, n, inst = Recruit.PickChannel()
	if not id then
		Recruit.lastChannelText = BG.T("rec_no_channel", n or "?")
		BG.Print(BG.T("rec_no_channel", n or "?"))
		return false
	end
	local msg = BG.Fill(BG.db.texts.recruitMsg, {})
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

function Recruit.RepliesList()
	return BG.Lines(BG.db.texts.replies)
end

local function ReplyWhisper(name, text, invite)
	BG.SendChat(BG.Fill(text, { name = name }), "WHISPER", name)
	if invite then
		BG.After(1.2, function() BG.Invite(name) end)
	end
end

local function WhisperPopup(sender, msg)
	local buttons = {}
	local replies = Recruit.RepliesList()
	local nr = table.getn(replies)
	if nr >= 1 then
		table.insert(buttons, { text = BG.T("btn_reply_invite"), tip = replies[1], fn = function() ReplyWhisper(sender, replies[1], true) end })
	end
	for i = 2, math.min(nr, 3) do
		local text = replies[i]
		table.insert(buttons, { text = BG.T("btn_reply_n", i), tip = text, fn = function() ReplyWhisper(sender, text, false) end })
	end
	table.insert(buttons, { text = BG.T("btn_invite_only"), fn = function() BG.Invite(sender) end })
	table.insert(buttons, { text = BG.T("btn_ignore"), fn = function() end })
	if string.len(msg) > 160 then msg = string.sub(msg, 1, 157) .. "..." end
	BG.Popup.Push({
		key = "whisper-" .. sender,
		title = BG.T("pop_whisper_title", sender),
		body = "|cffffffff\"" .. msg .. "\"|r",
		buttons = buttons,
	})
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
	WhisperPopup(sender, msg or "")
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

local function ScannerPopup(author, msg, lang, chan)
	local text = (lang == "en") and BG.db.texts.contactEN or BG.db.texts.contactDE
	local function whisper() BG.SendChat(BG.Fill(text, { name = author }), "WHISPER", author) end
	local shown = msg
	if string.len(shown) > 150 then shown = string.sub(shown, 1, 147) .. "..." end
	BG.Popup.Push({
		key = "scan-" .. author,
		title = BG.T("pop_scan_title", author),
		body = "|cff999999[" .. tostring(chan) .. "]|r |cffffffff" .. shown .. "|r",
		buttons = {
			{ text = BG.T("btn_contact_invite"), tip = BG.Fill(text, { name = author }),
			  fn = function() whisper() BG.After(1.2, function() BG.Invite(author) end) end },
			{ text = BG.T("btn_contact"), tip = BG.Fill(text, { name = author }), fn = whisper },
			{ text = BG.T("btn_invite_only"), fn = function() BG.Invite(author) end },
			{ text = BG.T("btn_ignore"), fn = function() end },
		},
	})
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

function Recruit.Welcome(name)
	local db = BG.db
	if not name or name == "" then return end
	BG.SendChat(BG.Fill(db.texts.welcomeMsg, { name = name }), "WHISPER", name)
	if db.features.welcomeGuild and BG.Trim(db.texts.welcomeGuild) ~= "" then
		BG.SendChat(BG.Fill(db.texts.welcomeGuild, { name = name }), "GUILD")
	end
	db.stats.welcomes = db.stats.welcomes + 1
end

function Recruit.OnJoin(name)
	local db = BG.db
	if name == BG.me then return end
	if db.features.autoWelcome then
		BG.After(3, function() Recruit.Welcome(name) end)
	elseif db.features.welcomePopup then
		BG.Popup.Push({
			key = "join-" .. name,
			title = BG.T("pop_join_title", name),
			body = BG.T("pop_join_body", name),
			buttons = {
				{ text = BG.T("btn_welcome"), tip = BG.Fill(db.texts.welcomeMsg, { name = name }), fn = function() Recruit.Welcome(name) end },
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
