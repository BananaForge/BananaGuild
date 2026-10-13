--[[
  BananaGuild - Self test
  Walks through everything the addon depends on and reports OK / WARN / FAIL.
  Open it via the button bottom right in the window or with /bgd selftest
]]

local BG = BananaGuild
local ST = { text = "", summary = "", results = {} }
BG.SelfTest = ST

local function Add(status, name, detail)
	table.insert(ST.results, { s = status, n = name, d = detail or "" })
end

local function HasFn(name) return type(getglobal(name)) == "function" end

local function CheckApi()
	local need = {
		{ "SendAddonMessage", "FAIL", "st_api_addonmsg" },
		{ "SendChatMessage", "FAIL", "" },
		{ "GetNumGuildMembers", "FAIL", "" },
		{ "GetGuildRosterInfo", "FAIL", "" },
		{ "GuildRoster", "FAIL", "" },
		{ "GuildInviteByName", "FAIL", "" },
		{ "CanGuildInvite", "WARN", "" },
		{ "GetChannelName", "FAIL", "" },
		{ "PlaySoundFile", "WARN", "" },
		{ "GetAddOnMetadata", "WARN", "" },
		{ "IsAddOnLoaded", "WARN", "" },
		{ "GetAddOnInfo", "WARN", "" },
	}
	local missing, warn = {}, {}
	for i = 1, table.getn(need) do
		if not HasFn(need[i][1]) then
			if need[i][2] == "FAIL" then table.insert(missing, need[i][1]) else table.insert(warn, need[i][1]) end
		end
	end
	if table.getn(missing) > 0 then
		Add("FAIL", BG.T("st_api"), BG.T("st_missing") .. " " .. table.concat(missing, ", "))
	elseif table.getn(warn) > 0 then
		Add("WARN", BG.T("st_api"), BG.T("st_missing") .. " " .. table.concat(warn, ", "))
	else
		Add("OK", BG.T("st_api"), "")
	end
end

function ST.Run()
	ST.results = {}
	local db = BG.db

	-- 1. load state / folder name (the logo path needs the folder to be called exactly BananaGuild)
	Add("OK", BG.T("st_version"), BG.version)
	local folder = BG.folder or "?"
	if string.lower(folder) == "bananaguild" then Add("OK", BG.T("st_folder"), "Interface\\AddOns\\" .. folder)
	else Add("WARN", BG.T("st_folder"), BG.T("st_folder_bad", folder)) end
	local missing = {}
	for _, f in ipairs({ "BananaPresence", "Locale", "Core", "Presence", "Roster", "Alerts", "Recruit", "UI", "SelfTest" }) do
		if not (BG.files and BG.files[f]) then table.insert(missing, f) end
	end
	if table.getn(missing) > 0 then Add("FAIL", BG.T("st_files"), table.concat(missing, ", "))
	else Add("OK", BG.T("st_files"), "") end

	-- 2. saved variables
	if type(BananaGuildDB) == "table" and BananaGuildDB == db then
		Add("OK", BG.T("st_db"), BG.T("st_db_info", BG.Count(db.chars), BG.Count(db.presence), table.getn(db.log)))
	else
		Add("FAIL", BG.T("st_db"), BG.T("st_db_bad"))
	end

	-- 3. API
	CheckApi()

	-- 4. guild
	if IsInGuild and IsInGuild() then
		local gname, grank = GetGuildInfo("player")
		Add("OK", BG.T("st_guild"), tostring(gname) .. " / " .. tostring(grank))
		if CanGuildInvite then
			if CanGuildInvite() then Add("OK", BG.T("st_invite_right"), "")
			else Add("WARN", BG.T("st_invite_right"), BG.T("no_invite_right")) end
		end
		local n = BG.Roster.Count()
		if n > 0 then Add("OK", BG.T("st_roster"), BG.T("st_roster_info", n, BG.Roster.scans))
		else Add("WARN", BG.T("st_roster"), BG.T("st_roster_empty")) end
	else
		Add("FAIL", BG.T("st_guild"), BG.T("not_in_guild"))
	end

	-- 5. invisible comm channel
	if not db.features.guildBroadcast then
		Add("WARN", BG.T("st_comm"), BG.T("comm_disabled"))
	elseif not SendAddonMessage then
		Add("FAIL", BG.T("st_comm"), BG.T("no_addon_msg"))
	else
		Add("OK", BG.T("st_comm"), "prefix " .. BG.PREFIX)
	end

	-- 6. presence library
	if BananaPresence and BananaPresence.libVersion then
		local payload = BananaPresence.Payload()
		Add("OK", BG.T("st_presence"), "lib v" .. BananaPresence.libVersion .. " | " .. payload)
		if BananaPresence.hooked then Add("OK", BG.T("st_presence_hook"), "")
		else Add("WARN", BG.T("st_presence_hook"), "") end
	else
		Add("FAIL", BG.T("st_presence"), BG.T("st_presence_missing"))
	end

	-- 7. tracked addons found locally
	for i = 1, table.getn(BG.TRACKED) do
		local e = BG.TRACKED[i]
		local state, ver = BG.Presence.Detect(e)
		if e.key == "guild" then state, ver = 2, BG.version end
		local txt = (state == 2) and (BG.T("st_running") .. " " .. tostring(ver)) or ((state == 1) and BG.T("st_disabled") or BG.T("st_notfound"))
		Add((state == 0) and "INFO" or "OK", e.label, txt)
	end

	-- 8. channels
	local joined = {}
	if GetChannelList then
		local t = { GetChannelList() }
		local i = 1
		while t[i] do
			table.insert(joined, tostring(t[i]) .. "=" .. tostring(t[i + 1]))
			i = i + 2
		end
	end
	Add("INFO", BG.T("st_channels"), (table.getn(joined) > 0) and table.concat(joined, ", ") or BG.T("st_none"))
	local function ChanCheck(label, n)
		n = tonumber(n)
		local id = n and GetChannelName and GetChannelName(n)
		if id and id > 0 then Add("OK", label, "/" .. n)
		else Add("WARN", label, BG.T("rec_no_channel", n or "?")) end
	end
	ChanCheck(BG.T("st_chan_main"), db.recruit.chMain)
	ChanCheck(BG.T("st_chan_inst"), db.recruit.chInstance)
	Add("INFO", BG.T("st_zone"), tostring(GetRealZoneText and GetRealZoneText() or "?") .. " | " .. (BG.InInstance() and BG.T("st_in_instance") or BG.T("st_outside")))

	-- 9. recruiting texts
	local msg = db.texts.recruitMsg or ""
	if BG.Trim(msg) == "" then Add("FAIL", BG.T("st_recmsg"), BG.T("rec_nomsg"))
	elseif string.len(msg) > 255 then Add("FAIL", BG.T("st_recmsg"), BG.T("st_too_long", string.len(msg)))
	else Add("OK", BG.T("st_recmsg"), string.len(msg) .. "/255") end
	local longest = 0
	local emptyKinds = {}
	for _, kind in ipairs(BG.VARIANT_KINDS) do
		local filled = 0
		for i = 1, BG.VARIANTS do
			local t = db.variants[kind] and db.variants[kind][i] or ""
			if BG.Trim(t) ~= "" then filled = filled + 1 end
			local n = string.len(BG.Fill(t, { name = "Playername", level = 60 }))
			if n > longest then longest = n end
		end
		if filled == 0 then table.insert(emptyKinds, kind) end
	end
	if table.getn(emptyKinds) > 0 then Add("WARN", BG.T("st_variants"), BG.T("st_variants_empty") .. " " .. table.concat(emptyKinds, ", "))
	else Add("OK", BG.T("st_variants"), "") end
	if longest > 255 then Add("WARN", BG.T("st_textlen"), BG.T("st_too_long", longest))
	else Add("OK", BG.T("st_textlen"), BG.T("longest_line", longest)) end
	if string.find(db.discord or "", "DEIN-LINK", 1, true) or BG.Trim(db.discord or "") == "" then
		Add("WARN", BG.T("st_discord"), BG.T("st_discord_default"))
	else
		Add("OK", BG.T("st_discord"), db.discord)
	end
	local iv = tonumber(db.recruit.interval) or 0
	if iv < 3 then Add("WARN", BG.T("st_interval"), BG.T("st_interval_low", iv))
	else Add("OK", BG.T("st_interval"), iv .. " min") end

	-- 10. scanner
	local hit = BG.Recruit.Classify("Suche eine nette deutsche Gilde, kann mich jemand aufnehmen?") or BG.Recruit.Classify("Looking for a guild, anyone know a casual one?")
	local miss = BG.Recruit.Classify("<Foo> recruiting new members! Join us!")
	if hit and not miss then Add("OK", BG.T("st_scanner"), "")
	else Add("WARN", BG.T("st_scanner"), BG.T("st_scanner_bad")) end

	-- 11. chat menu
	if UnitPopupButtons and UnitPopupButtons["BG_GUILD_INVITE"] then
		local found = false
		local menu = UnitPopupMenus and UnitPopupMenus["FRIEND"]
		if menu then for i = 1, table.getn(menu) do if menu[i] == "BG_GUILD_INVITE" then found = true end end end
		if found then Add("OK", BG.T("st_menu"), "") else Add("WARN", BG.T("st_menu"), BG.T("st_menu_bad")) end
	else
		Add("WARN", BG.T("st_menu"), BG.T("st_menu_bad"))
	end

	-- instance / raid mode
	do
		local q = db.quiet
		local state = (not q.enabled) and BG.T("quiet_status_disabled") or (BG.QuietActive() and BG.T("quiet_status_on") or BG.T("quiet_status_off"))
		Add("INFO", BG.T("st_quiet"), state)
	end

	-- 12. locale parity
	local missing = {}
	for k in pairs(BG.L.en) do if BG.L.de[k] == nil then table.insert(missing, "de:" .. k) end end
	for k in pairs(BG.L.de) do if BG.L.en[k] == nil then table.insert(missing, "en:" .. k) end end
	if table.getn(missing) > 0 then Add("WARN", BG.T("st_locale"), table.concat(missing, ", "))
	else Add("OK", BG.T("st_locale"), "") end

	-- 13. runtime errors collected so far
	if table.getn(BG.errors) > 0 then
		Add("FAIL", BG.T("st_errors"), BG.errors[table.getn(BG.errors)])
		for i = math.max(1, table.getn(BG.errors) - 3), table.getn(BG.errors) - 1 do
			Add("INFO", "   ", BG.errors[i])
		end
	else
		Add("OK", BG.T("st_errors"), BG.T("st_none"))
	end

	-- build text + summary
	local lines, ok, warn, fail = {}, 0, 0, 0
	for i = 1, table.getn(ST.results) do
		local r = ST.results[i]
		if r.s == "OK" then ok = ok + 1 elseif r.s == "WARN" then warn = warn + 1 elseif r.s == "FAIL" then fail = fail + 1 end
		table.insert(lines, "[" .. r.s .. "] " .. r.n .. ((r.d ~= "") and (": " .. r.d) or ""))
	end
	ST.text = "BananaGuild " .. BG.version .. "\n" .. table.concat(lines, "\n")
	if fail > 0 then ST.summary = "|cffff5555" .. BG.T("st_summary", ok, warn, fail) .. "|r"
	elseif warn > 0 then ST.summary = "|cffffff66" .. BG.T("st_summary", ok, warn, fail) .. "|r"
	else ST.summary = "|cff40ff40" .. BG.T("st_summary", ok, warn, fail) .. "|r" end
	BG.Print(ST.summary)
	if BG.UI then BG.UI.Refresh("selftest") end
end

BananaGuild = BananaGuild or {}
BananaGuild.files = BananaGuild.files or {}
BananaGuild.files.SelfTest = true
