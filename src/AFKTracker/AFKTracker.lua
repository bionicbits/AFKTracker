-- Initialize DB
AFKTrackerDB = AFKTrackerDB or { records = {} }

local frame = CreateFrame("Frame")
local delayFrame = CreateFrame("Frame")
local bgZone = "Alterac Valley"
local inBG = false

local descriptions = {
    deathThreshold = "Number of deaths below which a player is considered AFK (e.g., deaths < this value)",
    honorThreshold = "Minimum honor gained to consider a player for AFK tracking",
    seenThreshold = "Minimum number of times seen AFK to include in lists or announcements",
    redeemThreshold = "Number of honorable kills in a single match to remove from tracking",
    historyExpireHours = "Hours after which AFK records expire",
    debug = "Enable debug messages 1 enables, 0 disables (DEFAULT)"
}

-- Debug function
local function Debug(msg)
    if AFKTrackerDB.config and AFKTrackerDB.config.debug then
        print("|cFF4A90E2[AFK Tracker]|r " .. msg)
    end
end

-- Register events at load
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
frame:RegisterEvent("UPDATE_BATTLEFIELD_SCORE")

frame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        AFKTrackerDB.config = AFKTrackerDB.config or {}
        AFKTrackerDB.ui = AFKTrackerDB.ui or {}
        local defaults = {
            deathThreshold = 2,
            honorThreshold = 1386,
            seenThreshold = 2,
            redeemThreshold = 1,
            historyExpireHours = 24,
            debug = false
        }
        for k, v in pairs(defaults) do
            if AFKTrackerDB.config[k] == nil then
                AFKTrackerDB.config[k] = v
            end
        end
        local now = time()
        local historyExpire = AFKTrackerDB.config.historyExpireHours * 3600
        for i = #AFKTrackerDB.records, 1, -1 do
            if now - AFKTrackerDB.records[i].timestamp > historyExpire then
                table.remove(AFKTrackerDB.records, i)
            end
        end
        print("|cFF4A90E2[AFK Tracker]|r Loaded! " .. #AFKTrackerDB.records .. " records in history.")
    elseif event == "ZONE_CHANGED_NEW_AREA" then
        local zone = GetZoneText()
        if zone == bgZone and not inBG then
            inBG = true
            Debug("Entered Alterac Valley. Starting tracking.")
        elseif zone ~= bgZone and inBG then
            inBG = false
            Debug("Left AV. Stopping tracking.")
        end
    elseif event == "UPDATE_BATTLEFIELD_SCORE" then
        local winner = GetBattlefieldWinner()
        Debug("UPDATE_BATTLEFIELD_SCORE fired, winner = " .. tostring(winner))
        if inBG and winner ~= nil then
            Debug("BG end detected, recording stats.")
            self:RecordStatsAtEnd()
        end
    end
end)

-- Record stats at BG end (only players meeting criteria)
function frame:RecordStatsAtEnd()
    RequestBattlefieldScoreData()
    delayFrame.startTime = GetTime()
    delayFrame:SetScript("OnUpdate", function(dfself, elapsed)
        if GetTime() - dfself.startTime >= 1 then
            dfself:SetScript("OnUpdate", nil)
            local numScores = GetNumBattlefieldScores()
            Debug("Scores after delay: " .. numScores)
            for i = 1, numScores do
                local name, killingBlows, honorableKills, deaths, honorGained, faction, race, class, classToken, damageDone, healingDone, bonusHonor, gravesAssaulted, gravesDefended, towersAssaulted, towersDefended, minesCaptured, leadersKilled, secondaryObjectives =
                    GetBattlefieldScore(i)
                local objectives = (towersAssaulted or 0) + (towersDefended or 0) + (gravesAssaulted or 0) +
                    (gravesDefended or 0) + (minesCaptured or 0) + (leadersKilled or 0) + (secondaryObjectives or 0)
                if name and honorableKills == 0 and deaths < AFKTrackerDB.config.deathThreshold and (honorGained or 0) >= AFKTrackerDB.config.honorThreshold and objectives == 0 then
                    table.insert(AFKTrackerDB.records, {
                        name = name,
                        timestamp = time(),
                        hks = honorableKills,
                        deaths = deaths,
                        honor_gained = honorGained or 0
                    })
                    print("|cFF4A90E2[AFK Tracker]|r Recorded: " ..
                        name ..
                        " (0 HKs, <" ..
                        AFKTrackerDB.config.deathThreshold ..
                        " deaths, " .. (honorGained or 0) .. " honor, no objectives)")
                else
                    Debug("Skipped " .. (name or "unknown") .. " - criteria not met")
                end

                -- Check for redemption
                if name and honorableKills >= AFKTrackerDB.config.redeemThreshold then
                    local removed = false
                    for j = #AFKTrackerDB.records, 1, -1 do
                        if AFKTrackerDB.records[j].name == name then
                            table.remove(AFKTrackerDB.records, j)
                            removed = true
                        end
                    end
                    if removed then
                        print("|cFF4A90E2[AFK Tracker]|r Redeemed: " ..
                            name .. " with " .. honorableKills .. " HKs, removed from tracking list.")
                    end
                end
            end
        end
    end)
end

-- Simplified aggregates (no spawn/idle)
local function GetAggregates(name, now)
    local historyExpire = AFKTrackerDB.config.historyExpireHours * 3600
    local times_seen = 0
    local sum_hks = 0
    local sum_deaths = 0
    local sum_honor = 0
    local afk_count = 0
    for _, rec in ipairs(AFKTrackerDB.records) do
        if rec.name == name and now - rec.timestamp <= historyExpire then
            times_seen = times_seen + 1
            sum_hks = sum_hks + rec.hks
            sum_deaths = sum_deaths + rec.deaths
            sum_honor = sum_honor + (rec.honor_gained or 0)
            if rec.hks == 0 and rec.deaths < AFKTrackerDB.config.deathThreshold and (rec.honor_gained or 0) >= AFKTrackerDB.config.honorThreshold then
                afk_count = afk_count + 1
            end
        end
    end
    if times_seen == 0 then return nil end
    local avg_hks = math.floor((sum_hks / times_seen) * 10 + 0.5) / 10
    local avg_deaths = math.floor((sum_deaths / times_seen) * 10 + 0.5) / 10
    return {
        times_seen = times_seen,
        avg_hks = avg_hks,
        avg_deaths = avg_deaths,
        sum_honor = sum_honor,
        afk_count = afk_count
    }
end

-- Get current group members
local function GetCurrentGroupMembers()
    local members = {}
    local numMembers, prefix
    if type(GetNumGroupMembers) == "function" then
        numMembers = GetNumGroupMembers()
        prefix = IsInRaid() and "raid" or "party"
    else
        numMembers = GetNumRaidMembers() > 0 and GetNumRaidMembers() or GetNumPartyMembers()
        prefix = GetNumRaidMembers() > 0 and "raid" or "party"
    end
    for i = 1, numMembers do
        local unit = prefix .. i
        local name = UnitName(unit)
        local level = UnitLevel(unit)
        if name then
            members[name] = level
        end
    end
    return members
end

local function sortPlayers(a, b)
    if a.aggs.times_seen ~= b.aggs.times_seen then
        return a.aggs.times_seen > b.aggs.times_seen -- Most seen first (descending)
    else
        return a.aggs.sum_honor > b.aggs.sum_honor   -- Then highest honor first (descending)
    end
end

-- List potential AFKers with aggregates (for /afkt list [limit] [bg])
local function ListAFKers(limit, useBG)
    local now = time()
    local historyExpire = AFKTrackerDB.config.historyExpireHours * 3600
    local players = {}
    for _, rec in ipairs(AFKTrackerDB.records) do
        if now - rec.timestamp <= historyExpire and rec.hks == 0 and rec.deaths < AFKTrackerDB.config.deathThreshold and (rec.honor_gained or 0) >= AFKTrackerDB.config.honorThreshold then
            players[rec.name] = true
        end
    end
    if next(players) == nil then
        print("|cFF4A90E2[AFK Tracker]|r No potential AFKers matching thresholds yet.")
        return
    end
    local currentMembers = inBG and GetCurrentGroupMembers() or nil
    local sortedPlayers = {}
    for name in pairs(players) do
        if not currentMembers or (currentMembers[name] and currentMembers[name] >= 60) then
            local aggs = GetAggregates(name, now)
            if aggs and aggs.afk_count >= AFKTrackerDB.config.seenThreshold then
                table.insert(sortedPlayers, { name = name, aggs = aggs })
            end
        end
    end
    if #sortedPlayers == 0 then
        print("|cFF4A90E2[AFK Tracker]|r 0 players matching criteria in current AV match.")
        return
    end
    table.sort(sortedPlayers, sortPlayers)
    if limit and limit > 0 then
        while #sortedPlayers > limit do
            table.remove(sortedPlayers)
        end
    end
    local channel = (useBG and inBG) and "INSTANCE_CHAT" or nil
    local header_plain = "[AFK Tracker] Potential AFKers (tracked last " ..
        AFKTrackerDB.config.historyExpireHours .. " hours):"
    local header_colored = "|cFF4A90E2[AFK Tracker]|r Potential AFKers (tracked last |cFF4A90E2" ..
        AFKTrackerDB.config.historyExpireHours .. "|r hours):"
    if channel then
        SendChatMessage(header_plain, channel)
    else
        print(header_colored)
    end
    for _, entry in ipairs(sortedPlayers) do
        local aggs = entry.aggs
        local msg_plain = "- " ..
            entry.name ..
            ": Seen " ..
            aggs.times_seen ..
            " times, avg HKs: " ..
            aggs.avg_hks ..
            ", avg deaths: " .. aggs.avg_deaths .. ", total objectives: 0, total honor: " .. aggs.sum_honor .. "."
        if channel then
            SendChatMessage(msg_plain, channel)
        else
            local msg_colored = "- |cFF00FF00" ..
                entry.name ..
                "|r: Seen |cFF4A90E2" ..
                aggs.times_seen ..
                "|r times, avg HKs: |cFF4A90E2" ..
                aggs.avg_hks ..
                "|r, avg deaths: |cFF4A90E2" ..
                aggs.avg_deaths ..
                "|r, total objectives: |cFF4A90E20|r, total honor: |cFF4A90E2" .. aggs.sum_honor .. "|r."
            print(msg_colored)
        end
    end
end

-- Announce target's aggregates to raid chat (for /afkt history)
local function AnnounceHistory()
    if not UnitExists("target") then
        print("|cFF4A90E2[AFK Tracker]|r Error: No target selected for history.")
        return
    end
    local n = UnitName("target")
    local now = time()
    local aggs = GetAggregates(n, now)
    if aggs and aggs.afk_count > 0 then
        local msg = "[AFK Tracker] for " ..
            n ..
            ": Seen " ..
            aggs.times_seen ..
            " times in AV last " .. AFKTrackerDB.config.historyExpireHours .. "h, avg HKs: " ..
            aggs.avg_hks ..
            ", avg deaths: " .. aggs.avg_deaths .. ", total objectives: 0, total honor: " .. aggs.sum_honor .. "."
        local channel = (IsInInstance() and "INSTANCE_CHAT") or "RAID"
        SendChatMessage(msg, channel)
        Debug("Announced history for " .. n .. " to " .. channel .. " chat.")
    else
        print("|cFF4A90E2[AFK Tracker]|r No AFK history found for " .. n .. ".")
    end
end

-- Clear records list (for /afkt clear)
local function ClearRecords()
    AFKTrackerDB.records = {}
    print("|cFF4A90E2[AFK Tracker]|r Records list cleared.")
end

-- Announce function (for /afkt announce)
local function AFKAnnounce()
    Debug("Attempting to announce...")
    if not UnitExists("target") then
        Debug("Error: No target selected.")
        return
    end
    local n = UnitName("target")
    local c = select(1, UnitClass("target"))
    if not c then
        Debug("Error: Could not detect target's class.")
        return
    end
    local msg = "REPORT: " .. n .. " the " .. c .. " is AFK!"
    local tindex = UnitInRaid("target")
    if tindex then
        local _, _, subgroup = GetRaidRosterInfo(tindex)
        if subgroup then
            msg = msg .. " (Group " .. subgroup .. ")"
        else
            Debug("Target in raid but no subgroup detected.")
        end
    else
        Debug("Target not in raid (no group info added).")
    end
    local channel = (IsInInstance() and "INSTANCE_CHAT") or "RAID"
    local pindex = UnitInRaid("player")
    if pindex then
        local _, prank = GetRaidRosterInfo(pindex)
        if prank >= 1 then
            channel = "RAID_WARNING"
            Debug("Using RAID_WARNING (you have permissions).")
        else
            Debug("Using RAID (no leader/assist permissions).")
        end
    else
        Debug("Not in raid; falling back to RAID/party channel.")
    end
    SendChatMessage(msg, channel)
    print("|cFF4A90E2[AFK Tracker]|r Message sent: " .. msg)
end

-- Config handler
local function HandleConfig(args)
    local configCmd = string.lower(args[2] or "list")
    if configCmd == "list" then
        print("|cFF4A90E2[AFK Tracker]|r Current configuration:")
        for k, desc in pairs(descriptions) do
            local value = AFKTrackerDB.config[k]
            if type(value) == "boolean" then
                value = tostring(value)
            end
            print(" - |cFFFFD700" .. k .. "|r: |cFF4A90E2" .. value .. "|r - " .. desc)
        end
    elseif configCmd == "get" then
        local inputKey = string.lower(args[3] or "")
        if inputKey == "" then
            print("|cFF4A90E2[AFK Tracker]|r Invalid key. Use /afkt config list to see available keys.")
            return
        end
        local foundKey = nil
        for k in pairs(descriptions) do
            if string.lower(k) == inputKey then
                foundKey = k
                break
            end
        end
        if foundKey then
            local value = AFKTrackerDB.config[foundKey]
            if type(value) == "boolean" then
                value = tostring(value)
            end
            print("|cFF4A90E2[AFK Tracker]|r |cFFFFD700" ..
                foundKey .. "|r: |cFF4A90E2" .. value .. "|r - " .. descriptions[foundKey])
        else
            print("|cFF4A90E2[AFK Tracker]|r Invalid key. Use /afkt config list to see available keys.")
        end
    elseif configCmd == "set" then
        local inputKey = string.lower(args[3] or "")
        local value = tonumber(args[4])
        if inputKey == "" or value == nil then
            print("|cFF4A90E2[AFK Tracker]|r Invalid key or value. Use /afkt config set <key> <value>.")
            return
        end
        -- Allow 0 or 1 for debug option, positive numbers for others
        if inputKey ~= "debug" and (not value or value <= 0) then
            print("|cFF4A90E2[AFK Tracker]|r Invalid value. Value must be a positive number.")
            return
        end
        if inputKey == "debug" and value ~= 0 and value ~= 1 then
            print("|cFF4A90E2[AFK Tracker]|r Invalid value for debug. Use 0 (false) or 1 (true).")
            return
        end
        local foundKey = nil
        for k in pairs(descriptions) do
            if string.lower(k) == inputKey then
                foundKey = k
                break
            end
        end
        if foundKey then
            -- Special handling for debug option
            if foundKey == "debug" then
                AFKTrackerDB.config[foundKey] = (value == 1)
                print("|cFF4A90E2[AFK Tracker]|r Set |cFFFFD700" ..
                    foundKey .. "|r to |cFF4A90E2" .. tostring(AFKTrackerDB.config[foundKey]) .. "|r")
            else
                AFKTrackerDB.config[foundKey] = value
                print("|cFF4A90E2[AFK Tracker]|r Set |cFFFFD700" .. foundKey .. "|r to |cFF4A90E2" .. value .. "|r")
            end
        else
            print("|cFF4A90E2[AFK Tracker]|r Invalid key. Use /afkt config list to see available keys.")
        end
    else
        print("|cFF4A90E2[AFK Tracker]|r Invalid config command. Use list, get <key>, or set <key> <value>.")
    end
end

-- Unified slash command handler
local function AFKTHandler(msg)
    local args = {}
    for word in msg:gmatch("%S+") do
        table.insert(args, word)
    end
    local subcmd = string.lower(args[1] or "")
    if subcmd == "announce" then
        AFKAnnounce()
    elseif subcmd == "list" then
        local limit = nil
        local useBG = false
        local arg2 = args[2] and string.lower(args[2]) or nil
        local arg3 = args[3] and string.lower(args[3]) or nil
        if arg2 == "bg" then
            useBG = true
        elseif arg2 then
            limit = tonumber(arg2)
            if arg3 == "bg" then
                useBG = true
            end
        end
        ListAFKers(limit, useBG)
    elseif subcmd == "history" then
        AnnounceHistory()
    elseif subcmd == "clear" then
        ClearRecords()
    elseif subcmd == "config" then
        HandleConfig(args)
    elseif subcmd == "ui" or subcmd == "settings" then
        if AFKTrackerUI then
            AFKTrackerUI:ToggleSettingsFrame()
        else
            print("|cFF4A90E2[AFK Tracker]|r UI module not loaded.")
        end
    elseif subcmd == "battleui" then
        local action = string.lower(args[2] or "show")
        if AFKTrackerUI then
            if action == "show" then
                AFKTrackerUI:ShowBattleFrame()
                print("|cFF4A90E2[AFK Tracker]|r Battle UI shown")
            elseif action == "hide" then
                AFKTrackerUI:HideBattleFrame()
                print("|cFF4A90E2[AFK Tracker]|r Battle UI hidden")
            elseif action == "reset" then
                AFKTrackerUI:ResetBattlePosition()
                print("|cFF4A90E2[AFK Tracker]|r Battle UI position reset to default")
            else
                print("|cFF4A90E2[AFK Tracker]|r Usage: /afkt battleui [show|hide|reset]")
            end
        else
            print("|cFF4A90E2[AFK Tracker]|r UI module not loaded.")
        end
    else
        print("|cFF4A90E2[AFK Tracker]|r Usage: /afkt <command>")
        print(" - |cFFFFD700announce|r: Announce target as AFK (encourages reporting)")
        print(
            " - |cFFFFD700list|r [limit] [bg]: List potential AFKers with aggregates from last 24 hours (optional limit for top N, bg to display in bg chat if in AV)")
        print(" - |cFFFFD700history|r: Announce target's AFK evidence to bg chat")
        print(" - |cFFFFD700clear|r: Clear the records list")
        print(" - |cFFFFD700config|r [list|get <key>|set <key> <value>]: Manage configuration")
        print(" - |cFFFFD700ui|r or |cFFFFD700settings|r: Toggle the settings window")
        print(
        " - |cFFFFD700battleui|r [show|hide|reset]: Show, hide, or reset position of the battle UI (auto-shows in AV if enabled)")
    end
end

SLASH_AFKT1 = "/afkt"
SlashCmdList["AFKT"] = AFKTHandler

-- Load message
print(
    "|cFF4A90E2[AFK Tracker]|r Loaded successfully! Simplified version. Use /afkt <announce|list|history|clear|config>.")
