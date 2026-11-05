local addonName, addon = ...

addon = addon or {}

-- =========================================================
-- DIARIO DE AVENTURAS - EVENTOS
-- =========================================================

local DB
local eventFrame = CreateFrame("Frame")

local currentPlace = ""
local sessionStarted = false

local lastQuestID, lastQuestAt
local lastAcceptedQuestID, lastAcceptedQuestAt
local lastCompletedQuestTitle, lastCompletedQuestAt

local pendingQuestTitles = {}

local lastAttackerName
local lastNPCName

local knownGuildName
local knownFriendsCount = 0

local currentTransportMethod = "ON_FOOT"
local transportGeneration = 0
local transportExpiresAt = 0
local pendingTaxiDestination

local lastBossName
local lastBossAt = 0

local taxiHookInstalled = false

-- =========================================================
-- UTILIDADES
-- =========================================================

local function SafeString(value, fallback)
    if type(value) == "string" and value ~= "" then
        return value
    end

    return fallback or "algo desconocido"
end

local function SafeCall(func, ...)
    if type(func) ~= "function" then
        return false
    end

    local ok, a, b, c, d, e = pcall(func, ...)
    return ok, a, b, c, d, e
end

local function ContainsText(text, pattern)
    if type(text) ~= "string" or type(pattern) ~= "string" then
        return false
    end

    return string.find(string.lower(text), pattern, 1, true) ~= nil
end

local function GetPlayerGUID()
    if UnitGUID then
        local ok, guid = SafeCall(UnitGUID, "player")
        if ok then return guid end
    end

    return nil
end

-- =========================================================
-- COMPATIBILIDAD DE HECHIZOS
-- =========================================================

local function GetSpellName(spellID)
    if not spellID then return nil end

    if C_Spell and C_Spell.GetSpellInfo then
        local ok, info = SafeCall(C_Spell.GetSpellInfo, spellID)

        if ok and type(info) == "table" then
            return info.name
        end
    end

    if GetSpellInfo then
        local ok, name = SafeCall(GetSpellInfo, spellID)

        if ok and type(name) == "string" then
            return name
        end
    end

    return nil
end

-- =========================================================
-- COMPATIBILIDAD DE MISIONES
-- =========================================================

local function GetQuestTitle(questID)
    if not questID then return nil end

    if C_QuestLog and C_QuestLog.GetTitleForQuestID then
        local ok, title = SafeCall(
            C_QuestLog.GetTitleForQuestID,
            questID
        )

        if ok and type(title) == "string" and title ~= "" then
            return title
        end
    end

    if GetQuestLogTitle and GetNumQuestLogEntries then
        local ok, count = SafeCall(GetNumQuestLogEntries)

        if ok and tonumber(count) then
            for index = 1, count do
                local success, title, _, _, _, _, _, id =
                    SafeCall(GetQuestLogTitle, index)

                if success and tonumber(id) == tonumber(questID) then
                    return title
                end
            end
        end
    end

    return pendingQuestTitles[questID]
end

local function GetQuestFrameTitle()
    if GetTitleText then
        local ok, title = SafeCall(GetTitleText)

        if ok and type(title) == "string" and title ~= "" then
            return title
        end
    end

    return nil
end

-- =========================================================
-- HERMANDADES Y AMIGOS
-- =========================================================

local function GetCurrentGuild()
    if GetGuildInfo then
        local ok, guildName = SafeCall(GetGuildInfo, "player")

        if ok then
            return guildName
        end
    end

    return nil
end

local function GetCurrentFriendsCount()
    if C_FriendList and C_FriendList.GetNumFriends then
        local ok, count = SafeCall(C_FriendList.GetNumFriends)

        if ok then
            return tonumber(count) or 0
        end
    end

    if GetNumFriends then
        local ok, count = SafeCall(GetNumFriends)

        if ok then
            return tonumber(count) or 0
        end
    end

    return 0
end

-- =========================================================
-- NPC
-- =========================================================

local function GetTargetNPCName()
    if UnitExists and UnitName then
        if UnitExists("npc") then
            local ok, name = SafeCall(UnitName, "npc")

            if ok and name and name ~= "" then
                return name
            end
        end

        if UnitExists("target") then
            local isPlayer = false

            if UnitIsPlayer then
                local ok, result = SafeCall(UnitIsPlayer, "target")
                isPlayer = ok and result
            end

            if not isPlayer then
                local ok, name = SafeCall(UnitName, "target")

                if ok and name and name ~= "" then
                    return name
                end
            end
        end
    end

    return nil
end

local function CaptureNPC()
    local npcName = GetTargetNPCName()

    if npcName then
        lastNPCName = npcName
    end
end

-- =========================================================
-- LOCALIZACIÓN
-- =========================================================

function addon.GetPlace()
    local zone = SafeString(
        GetRealZoneText and GetRealZoneText(),
        "tierras desconocidas"
    )

    local sub = SafeString(
        GetSubZoneText and GetSubZoneText(),
        ""
    )

    if sub ~= "" and sub ~= zone then
        return sub .. ", " .. zone
    end

    return zone
end

-- =========================================================
-- BASE DE DATOS
-- =========================================================

function addon.EnsureDatabase()
    if type(AdventureJournalDB) ~= "table" then
        AdventureJournalDB = {
            version = 2,
            currentDay = 0,
            days = {},
            visitedZones = {},
            knownMounts = {},
            knownAchievements = {}
        }
    end

    DB = AdventureJournalDB

    DB.version = tonumber(DB.version) or 1
    DB.currentDay = tonumber(DB.currentDay) or 0

    if type(DB.days) ~= "table" then
        DB.days = {}
    end

    if type(DB.visitedZones) ~= "table" then
        DB.visitedZones = {}
    end

    if type(DB.knownMounts) ~= "table" then
        DB.knownMounts = {}
    end

    if type(DB.knownAchievements) ~= "table" then
        DB.knownAchievements = {}
    end

    for dayNumber, day in pairs(DB.days) do
        if type(day) ~= "table" then
            DB.days[dayNumber] = {
                events = {},
                dateLabel = "Fecha desconocida"
            }
        else
            if type(day.events) ~= "table" then
                day.events = {}
            end
        end
    end

    DB.version = 2
end

-- =========================================================
-- CONTROL DE JORNADAS
-- =========================================================

local function EnsureSessionStarted()
    if sessionStarted then
        return
    end

    addon.EnsureDatabase()

    sessionStarted = true
    DB.currentDay = DB.currentDay + 1

    local n = DB.currentDay

    DB.days[n] = {
        startedAt = date("%Y-%m-%d %H:%M:%S"),
        dateLabel = date("%d/%m/%Y"),
        events = {},
        mainZone = addon.GetPlace()
    }

    print(string.format(
        "|cFFFFD700[Diario]|r Comienza la jornada %d. Tu historia continúa.",
        n
    ))
end

-- =========================================================
-- REGISTRO DE ENTRADAS
-- =========================================================

function addon.AddEntry(eventType, description, extra)
    EnsureSessionStarted()

    local day = DB.days[DB.currentDay]

    if not day then
        return
    end

    day.events = day.events or {}

    local entry = {
        type = eventType,

        text = SafeString(
            description,
            "Acontecimiento sin descripción"
        ),

        place = addon.GetPlace(),

        time = date("%H:%M:%S"),

        timestamp = time(),

        contextualTone = (
            addon.GetRandomMood
            and addon.GetRandomMood(eventType)
        ) or "con el ánimo firme",

        seed = #day.events + 1 + math.random(1, 100)
    }

    if type(extra) == "table" then
        for key, value in pairs(extra) do
            entry[key] = value
        end
    end

    entry.type = eventType
    entry.text = SafeString(entry.text, "Acontecimiento sin descripción")
    entry.place = SafeString(entry.place, addon.GetPlace())

    local header, bodyText

    if addon.ComposeEntry then
        local ok, generatedHeader, generatedBody =
            pcall(addon.ComposeEntry, entry)

        if ok then
            header = generatedHeader
            bodyText = generatedBody
        end
    end

    entry.header = header
    entry.prose = bodyText or entry.text

    table.insert(day.events, entry)

    if addon.RefreshUI then
        addon:RefreshUI()
    end

    print(string.format(
        "|cFF00FF00[Diario]|r %s",
        entry.text
    ))
end

-- =========================================================
-- TRANSPORTES
-- =========================================================

local function SetTransportMethod(method)
    transportGeneration = transportGeneration + 1

    currentTransportMethod = method

    local now = GetTime and GetTime() or time()
    transportExpiresAt = now + 60
end

local function ClearTransportMethod()
    transportGeneration = transportGeneration + 1

    currentTransportMethod = "ON_FOOT"
    transportExpiresAt = 0
    pendingTaxiDestination = nil
end

local function IsPlayerOnTaxi()
    if UnitOnTaxi then
        local ok, result = SafeCall(UnitOnTaxi, "player")

        if ok then
            return result and true or false
        end
    end

    return false
end

local function GetTaxiNodeName(index)
    if not index or not GetTaxiNodeInfo then
        return nil
    end

    local ok, name = SafeCall(GetTaxiNodeInfo, index)

    if ok and type(name) == "string" and name ~= "" then
        return name
    end

    return nil
end

local function InstallTaxiHook()
    -- Hook desactivado temporalmente.
    -- Ya hemos comprobado que su desactivación no elimina el bloqueo.
    taxiHookInstalled = true
end

-- =========================================================
-- INICIALIZACIÓN
-- =========================================================

local function InitSessionState()
    addon.EnsureDatabase()

    currentPlace = addon.GetPlace()

    if currentPlace ~= "" and
       currentPlace ~= "tierras desconocidas" then

        DB.visitedZones[currentPlace] = true
    end

    knownFriendsCount = GetCurrentFriendsCount()
    knownGuildName = GetCurrentGuild()

    InstallTaxiHook()
end

-- =========================================================
-- ZONAS
-- =========================================================

local function HandleZoneChange()
    local newPlace = addon.GetPlace()

    if newPlace == currentPlace then
        return
    end

    if newPlace == "" or
       newPlace == "tierras desconocidas" then
        return
    end

    currentPlace = newPlace

    addon.EnsureDatabase()

    if IsPlayerOnTaxi() then
        currentTransportMethod = "TAXI"
    end

    local methodUsed = currentTransportMethod

    ClearTransportMethod()

    if not DB.visitedZones[newPlace] then
        DB.visitedZones[newPlace] = true

        addon.AddEntry(
            "DISCOVERY",
            newPlace,
            {
                travelMethod = methodUsed
            }
        )
    else
        addon.AddEntry(
            "REVISIT",
            newPlace,
            {
                travelMethod = methodUsed
            }
        )
    end
end

-- =========================================================
-- MISIONES
-- =========================================================

local function HandleQuestTurnedIn(questID, suppliedTitle)
    local title

    if questID then
        title = GetQuestTitle(questID)
    end

    if not title and suppliedTitle then
        title = suppliedTitle
    end

    if not title then
        title = GetQuestFrameTitle()
    end

    -- Evita duplicados por eventos equivalentes.
    if questID and
       questID == lastQuestID and
       lastQuestAt and
       time() - lastQuestAt <= 3 then
        return
    end

    if title and
       title == lastCompletedQuestTitle and
       lastCompletedQuestAt and
       time() - lastCompletedQuestAt <= 3 then
        return
    end

    lastQuestID = questID
    lastQuestAt = time()

    lastCompletedQuestTitle = title
    lastCompletedQuestAt = time()

    addon.AddEntry(
        "QUEST",
        title or (
            questID and ("misión " .. tostring(questID))
        ) or "una misión completada"
    )

    if questID then
        pendingQuestTitles[questID] = nil
    end
end

local function HandleQuestAccepted(...)
    local args = { ... }

    local questID
    local title

    for i = 1, #args do
        if type(args[i]) == "number" and not questID then
            questID = args[i]
        end

        if type(args[i]) == "string" and args[i] ~= "" then
            title = args[i]
        end
    end

    if questID then
        title = GetQuestTitle(questID) or title

        if title then
            pendingQuestTitles[questID] = title
        end
    end

    if not title then
        title = GetQuestFrameTitle()
    end

    if questID and
       questID == lastAcceptedQuestID and
       lastAcceptedQuestAt and
       time() - lastAcceptedQuestAt <= 3 then
        return
    end

    lastAcceptedQuestID = questID
    lastAcceptedQuestAt = time()

    CaptureNPC()

    local npcGiver = lastNPCName or "un habitante local"

    addon.AddEntry(
        "QUEST_ACCEPT",
        title or "una nueva misión",
        {
            npc = npcGiver,
            questID = questID
        }
    )

    lastNPCName = nil
end

-- =========================================================
-- COMBATE Y MUERTES
-- =========================================================

local function HandleCombatEvent(event, unit)
    if event == "PLAYER_REGEN_DISABLED" then
        if UnitExists("target") and
           UnitName("target") and
           not (UnitIsPlayer and UnitIsPlayer("target")) then

            lastAttackerName = UnitName("target")
        end
    end
end

local function HandlePlayerDeath()
    local killer = lastAttackerName or "un enemigo despiadado"

    addon.AddEntry(
        "DEATH",
        "He caído en combate",
        {
            killer = killer
        }
    )

    lastAttackerName = nil
end

-- =========================================================
-- JEFES
-- =========================================================

local function HandleBossKill(bossName)
    bossName = SafeString(bossName, "un jefe poderoso")

    -- BOSS_KILL y ENCOUNTER_END pueden informar del mismo combate.
    if lastBossName == bossName and
       time() - lastBossAt <= 5 then
        return
    end

    lastBossName = bossName
    lastBossAt = time()

    addon.AddEntry(
        "BOSS",
        bossName
    )
end

-- =========================================================
-- BOTÍN ÉPICO Y LEGENDARIO
-- =========================================================

local function HandleLoot(message)
    if type(message) ~= "string" or message == "" then
        return
    end

    local itemLink = string.match(
        message,
        "(|c%x+|Hitem:.-|h%[.-%]|h|r)"
    )

    if not itemLink then
        itemLink = string.match(
            message,
            "(|c%x+|Hitem:.-|h%[.-%]|h)"
        )
    end

    if not itemLink then
        return
    end

    local color = string.match(
        itemLink,
        "|c(%x%x%x%x%x%x%x%x)"
    )

    if not color then
        return
    end

    color = string.lower(color)

    -- Épico: a335ee
    -- Legendario: ff8000
    if color ~= "ffa335ee" and color ~= "ffff8000" then
        return
    end

    addon.AddEntry(
        "LOOT",
        itemLink
    )
end
-- =========================================================
-- MONTURAS
-- =========================================================

local function GetMountNameByID(mountID)
    if not mountID then return nil end

    if C_MountJournal and C_MountJournal.GetMountInfoByID then
        local ok, name = SafeCall(
            C_MountJournal.GetMountInfoByID,
            mountID
        )

        if ok and type(name) == "string" then
            return name
        end
    end

    return nil
end

local function RegisterMount(mountID, mountName)
    if not mountID and not mountName then
        return
    end

    addon.EnsureDatabase()

    local key = tostring(mountID or mountName)

    if DB.knownMounts[key] then
        return
    end

    DB.knownMounts[key] = true

    addon.AddEntry(
        "MOUNT",
        mountName or "una nueva montura",
        {
            mountID = mountID
        }
    )
end

local function ScanMounts(firstScan)
    addon.EnsureDatabase()

    local discovered = {}

    -- API moderna de Mount Journal.
    if C_MountJournal and C_MountJournal.GetMountIDs then
        local ok, mountIDs = SafeCall(C_MountJournal.GetMountIDs)

        if ok and type(mountIDs) == "table" then
            for _, mountID in ipairs(mountIDs) do
                local name = GetMountNameByID(mountID)

                local collected = false

                if C_MountJournal.GetMountInfoByID then
                    local success, _, _, _, _, _, _, _, _, isCollected =
                        SafeCall(
                            C_MountJournal.GetMountInfoByID,
                            mountID
                        )

                    if success then
                        collected = isCollected and true or false
                    end
                end

                if collected then
                    discovered[#discovered + 1] = {
                        id = mountID,
                        name = name
                    }
                end
            end
        end
    end

    -- API clásica de compañeros.
    if GetNumCompanions and GetCompanionInfo then
        local ok, count = SafeCall(GetNumCompanions, "MOUNT")

        if ok and tonumber(count) then
            for index = 1, count do
                local success, creatureID, creatureName =
                    SafeCall(GetCompanionInfo, "MOUNT", index)

                if success and creatureID then
                    discovered[#discovered + 1] = {
                        id = creatureID,
                        name = creatureName
                    }
                end
            end
        end
    end

    for _, mount in ipairs(discovered) do
        local key = tostring(mount.id or mount.name)

        if firstScan then
            DB.knownMounts[key] = true
        elseif not DB.knownMounts[key] then
            RegisterMount(mount.id, mount.name)
        end
    end
end

local function HandleNewMount(mountID)
    local mountName = GetMountNameByID(mountID)

    RegisterMount(
        mountID,
        mountName or "una nueva montura"
    )
end

-- =========================================================
-- LOGROS
-- =========================================================

local function GetAchievementName(achievementID)
    if not achievementID then return nil end

    if C_AchievementInfo and C_AchievementInfo.GetAchievementInfo then
        local ok, info = SafeCall(
            C_AchievementInfo.GetAchievementInfo,
            achievementID
        )

        if ok then
            if type(info) == "table" then
                return info.name
            elseif type(info) == "string" then
                return info
            end
        end
    end

    if GetAchievementInfo then
        local ok, name = SafeCall(
            GetAchievementInfo,
            achievementID
        )

        if ok then
            return name
        end
    end

    return nil
end

local function HandleAchievement(achievementID)
    if not achievementID then
        return
    end

    addon.EnsureDatabase()

    local key = tostring(achievementID)

    if DB.knownAchievements[key] then
        return
    end

    local achievementName = GetAchievementName(achievementID)

    DB.knownAchievements[key] = true

    addon.AddEntry(
        "ACHIEVEMENT",
        achievementName or (
            "logro " .. tostring(achievementID)
        ),
        {
            achievementID = achievementID
        }
    )
end

-- =========================================================
-- HERMANDADES
-- =========================================================

local function HandleGuildUpdate()
    local newGuildName = GetCurrentGuild()

    if newGuildName == knownGuildName then
        return
    end

    if newGuildName and newGuildName ~= "" then
        addon.AddEntry(
            "GUILD",
            newGuildName
        )
    elseif knownGuildName then
        addon.AddEntry(
            "GUILD",
            "He abandonado la hermandad " .. knownGuildName
        )
    end

    knownGuildName = newGuildName
end

-- =========================================================
-- AMIGOS
-- =========================================================

local function HandleFriendsUpdate()
    local newCount = GetCurrentFriendsCount()

    knownFriendsCount = newCount
end

-- =========================================================
-- TRANSPORTES Y HECHIZOS
-- =========================================================

local function HandleSpellcast(unit, castGUID, spellID)
    if unit ~= "player" then
        return
    end

    local spellName = GetSpellName(spellID)

    if not spellName then
        return
    end

    local lowerName = string.lower(spellName)

    if ContainsText(lowerName, "piedra de hogar") or
       ContainsText(lowerName, "hearthstone") then

        SetTransportMethod("HEARTHSTONE")

    elseif ContainsText(lowerName, "teletransporte") or
           ContainsText(lowerName, "teleport") or
           ContainsText(lowerName, "portal") then

        SetTransportMethod("TELEPORT")
    end
end

-- =========================================================
-- EVENTOS
-- =========================================================

local EVENTS = {
    "ADDON_LOADED",
    "PLAYER_LOGIN",
    "PLAYER_LOGOUT",
    "PLAYER_ENTERING_WORLD",

    "UNIT_SPELLCAST_SUCCEEDED",
    "UNIT_SPELLCAST_START",

    "QUEST_TURNED_IN",
    "QUEST_ACCEPTED",
    "QUEST_FINISHED",

    "BOSS_KILL",
    "ENCOUNTER_END",

    "PLAYER_DEAD",
    "CHAT_MSG_LOOT",

    "ZONE_CHANGED_NEW_AREA",
    "ZONE_CHANGED",
    "ZONE_CHANGED_INDOORS",
    "MINIMAP_ZONE_CHANGED",

    "GOSSIP_SHOW",
    "QUEST_DETAIL",
    "QUEST_PROGRESS",

    "PLAYER_LEVEL_UP",

    "NEW_MOUNT_ADDED",
    "COMPANION_UPDATE",

    "TAXI_PATH_UPDATE",
    "TAXIMAP_OPENED",
    "TAXIMAP_CLOSED",

    "FRIENDLIST_UPDATE",
    "GUILD_ROSTER_UPDATE",

    "ACHIEVEMENT_EARNED",


"PLAYER_REGEN_DISABLED",

}

for _, eventName in ipairs(EVENTS) do
    pcall(
        eventFrame.RegisterEvent,
        eventFrame,
        eventName
    )
end

-- =========================================================
-- CONTROLADOR DE EVENTOS
-- =========================================================

eventFrame:SetScript("OnEvent", function(self, event, ...)
    local arg1, arg2, arg3 = ...

    if event == "ADDON_LOADED" then
        if arg1 == addonName then
            addon.EnsureDatabase()
        end

    elseif event == "PLAYER_LOGIN" then
        InitSessionState()

        -- Primera exploración de monturas.
        ScanMounts(true)

    elseif event == "PLAYER_ENTERING_WORLD" then
        HandleZoneChange()

    elseif event == "PLAYER_DEAD" then
        HandlePlayerDeath()

elseif event == "PLAYER_REGEN_DISABLED" then
    HandleCombatEvent(event, arg1)

    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        HandleSpellcast(arg1, arg2, arg3)

    elseif event == "QUEST_ACCEPTED" then
        HandleQuestAccepted(...)

    elseif event == "QUEST_TURNED_IN" then
        HandleQuestTurnedIn(arg1, arg2)

    elseif event == "QUEST_DETAIL" then
        CaptureNPC()

    elseif event == "BOSS_KILL" then
        HandleBossKill(arg1)

    elseif event == "ENCOUNTER_END" then
        if arg5 == 1 then
            HandleBossKill(arg2)
        end

    elseif event == "CHAT_MSG_LOOT" then
        HandleLoot(arg1)

    elseif event == "ZONE_CHANGED_NEW_AREA"
        or event == "ZONE_CHANGED"
        or event == "ZONE_CHANGED_INDOORS"
        or event == "MINIMAP_ZONE_CHANGED" then

        HandleZoneChange()

    elseif event == "NEW_MOUNT_ADDED" then
        HandleNewMount(arg1)

    elseif event == "COMPANION_UPDATE" then
        ScanMounts(false)

    elseif event == "ACHIEVEMENT_EARNED" then
        HandleAchievement(arg1)

    elseif event == "GUILD_ROSTER_UPDATE" then
        HandleGuildUpdate()

    elseif event == "FRIENDLIST_UPDATE" then
        HandleFriendsUpdate()

    elseif event == "TAXI_PATH_UPDATE" then
        if IsPlayerOnTaxi() then
            SetTransportMethod("TAXI")
        end
    end
end)