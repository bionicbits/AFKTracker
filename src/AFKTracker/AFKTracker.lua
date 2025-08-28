-- Initialize DB
AFKTrackerDB = AFKTrackerDB or { records = {} }

local frame = CreateFrame("Frame")
local delayFrame = CreateFrame("Frame")
local historyExpire = 24 * 3600 -- 24 hours in seconds
local deathThreshold = 2        -- Number of deaths to not be evaluated AFK
local honorThreshold = 1386     -- Min Honor earned to be evaluated for AFK
local seenThreshold = 2         -- Number of times previously seen AFK to print to bg chat
local bgZone = "Alterac Valley"
local inBG = false

-- Register events at load
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
frame:RegisterEvent("UPDATE_BATTLEFIELD_SCORE")

frame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        local now = time()
        for i = #AFKTrackerDB.records, 1, -1 do
            if now - AFKTrackerDB.records[i].timestamp > historyExpire then
                table.remove(AFKTrackerDB.records, i)
            end
        end
        print("[AFKTracker] Loaded! " .. #AFKTrackerDB.records .. " records in history.")
    elseif event == "ZONE_CHANGED_NEW_AREA" then
        local zone = GetZoneText()
        if zone == bgZone and not inBG then
            inBG = true
            print("[AFKTracker] Entered Alterac Valley. Starting tracking.")
        elseif zone ~= bgZone and inBG then
            inBG = false
            print("[AFKTracker] Left AV. Stopping tracking.")
        end
    elseif event == "UPDATE_BATTLEFIELD_SCORE" then
        local winner = GetBattlefieldWinner()
        print("[AFKTracker] Debug: UPDATE_BATTLEFIELD_SCORE fired, winner = " .. tostring(winner))
        if inBG and winner ~= nil then
            print("[AFKTracker] Debug: BG end detected, recording stats.")
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
            print("[AFKTracker] Debug: Scores after delay: " .. numScores)
            for i = 1, numScores do
                local name, killingBlows, honorableKills, deaths, honorGained, faction, race, class, classToken, damageDone, healingDone, bonusHonor, gravesAssaulted, gravesDefended, towersAssaulted, towersDefended, minesCaptured, leadersKilled, secondaryObjectives =
                    GetBattlefieldScore(i)
                local objectives = (towersAssaulted or 0) + (towersDefended or 0) + (gravesAssaulted or 0) +
                    (gravesDefended or 0) + (minesCaptured or 0) + (leadersKilled or 0) + (secondaryObjectives or 0)
                if name and honorableKills == 0 and deaths < deathThreshold and (honorGained or 0) >= honorThreshold and objectives == 0 then
                    table.insert(AFKTrackerDB.records, {
                        name = name,
                        timestamp = time(),
                        hks = honorableKills,
                        deaths = deaths,
                        honor_gained = honorGained or 0
                    })
                    print("[AFKTracker] Recorded: " ..
                        name .. " (0 HKs, <3 deaths, " .. (honorGained or 0) .. " honor, no objectives)")
                else
                    print("[AFKTracker] Debug: Skipped " .. (name or "unknown") .. " - criteria not met")
                end
            end
        end
    end)
end

-- Simplified aggregates (no spawn/idle)
local function GetAggregates(name, now)
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
            if rec.hks == 0 and rec.deaths < 3 and (rec.honor_gained or 0) >= 1500 then
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
        afk_count =
            afk_count
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
        if name then
            members[name] = true
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

-- List potential AFKers with aggregates (for /afkt list [limit])
local function ListAFKers(limit)
    local now = time()
    local players = {}
    for _, rec in ipairs(AFKTrackerDB.records) do
        if now - rec.timestamp <= historyExpire and rec.hks == 0 and rec.deaths < deathThreshold and (rec.honor_gained or 0) >= honorThreshold then
            players[rec.name] = true
        end
    end
    if next(players) == nil then
        print("[AFKTracker] No potential AFKers matching thresholds yet.")
        return
    end
    local currentMembers = inBG and GetCurrentGroupMembers() or nil
    local sortedPlayers = {}
    for name in pairs(players) do
        if not currentMembers or currentMembers[name] then
            local aggs = GetAggregates(name, now)
            if aggs then
                table.insert(sortedPlayers, { name = name, aggs = aggs })
            end
        end
    end
    if #sortedPlayers == 0 then
        print("[AFKTracker] 0 players matching criteria in current AV match.")
        return
    end
    table.sort(sortedPlayers, sortPlayers)
    if limit and limit > 0 then
        while #sortedPlayers > limit do
            table.remove(sortedPlayers)
        end
    end
    print("[AFKTracker] Potential AFKers (last 24 hours, sorted by most seen, then total honor" ..
        (inBG and ", filtered to current AV match" or "") .. "):")
    for _, entry in ipairs(sortedPlayers) do
        local aggs = entry.aggs
        print("- " ..
            entry.name ..
            ": Seen " ..
            aggs.times_seen ..
            " times, average HKs: " ..
            aggs.avg_hks .. ", average deaths: " .. aggs.avg_deaths .. ", total honor: " .. aggs.sum_honor .. ".")
    end
end

-- Announce target's aggregates to raid chat (for /afkt history)
local function AnnounceHistory()
    if not UnitExists("target") then
        print("[AFKTracker] Error: No target selected for history.")
        return
    end
    local n = UnitName("target")
    local now = time()
    local aggs = GetAggregates(n, now)
    if aggs and aggs.afk_count > 0 then
        local msg = "AFK evidence for " ..
            n ..
            ": Seen " ..
            aggs.times_seen ..
            " times in AV last 24h, average HKs: " ..
            aggs.avg_hks .. ", average deaths: " .. aggs.avg_deaths .. ", total honor: " .. aggs.sum_honor .. "."
        local channel = (IsInInstance() and "INSTANCE_CHAT") or "RAID"
        SendChatMessage(msg, channel)
        print("[AFKTracker] Announced history for " .. n .. " to " .. channel .. " chat.")
    else
        print("[AFKTracker] No AFK history found for " .. n .. ".")
    end
end

-- Print current AV list to raid chat (for /afkt raidlist)
local function BGAfkers()
    if not inBG then
        print("[AFKTracker] Must be in AV to use bgafkers.")
        return
    end
    local now = time()
    local players = {}
    for _, rec in ipairs(AFKTrackerDB.records) do
        if now - rec.timestamp <= historyExpire and rec.hks == 0 and rec.deaths < deathThreshold and (rec.honor_gained or 0) >= honorThreshold then
            players[rec.name] = true
        end
    end
    if next(players) == nil then
        -- local channel = (IsInInstance() and "INSTANCE_CHAT") or "RAID"
        -- SendChatMessage("[AFKTracker] No potential AFKers in history.", channel)
        print("[AFKTracker] No previously seen AFKers in this bg.")
        return
    end
    local currentMembers = GetCurrentGroupMembers()
    local sortedPlayers = {}
    for name in pairs(players) do
        if currentMembers[name] then
            local aggs = GetAggregates(name, now)
            if aggs and aggs.times_seen >= seenThreshold then
                table.insert(sortedPlayers, { name = name, aggs = aggs })
            end
        end
    end
    if #sortedPlayers == 0 then
        -- local channel = (IsInInstance() and "INSTANCE_CHAT") or "RAID"
        -- SendChatMessage("[AFKTracker] 0 players matching criteria in current AV match.", channel)
        print("[AFKTracker] No previously seen AFKers in this bg.")
        return
    end
    table.sort(sortedPlayers, sortPlayers)
    local channel = (IsInInstance() and "INSTANCE_CHAT") or "RAID"
    SendChatMessage("[AFKTracker] Potential AFKers in this AV (seen in the last 24 hours):", channel)
    for _, entry in ipairs(sortedPlayers) do
        local aggs = entry.aggs
        local msg = "- " ..
            entry.name ..
            ": Seen " ..
            aggs.times_seen ..
            ", avg HKs: " ..
            aggs.avg_hks .. ", avg deaths: " .. aggs.avg_deaths .. ", total honor: " .. aggs.sum_honor .. "."
        SendChatMessage(msg, channel)
    end
end

-- Clear records list (for /afkt clear)
local function ClearRecords()
    AFKTrackerDB.records = {}
    print("[AFKTracker] Records list cleared.")
end

-- Announce function (for /afkt announce)
local function AFKAnnounce()
    print("[AFKTracker] Attempting to announce...")
    if not UnitExists("target") then
        print("[AFKTracker] Error: No target selected.")
        return
    end
    local n = UnitName("target")
    local c = select(1, UnitClass("target"))
    if not c then
        print("[AFKTracker] Error: Could not detect target's class.")
        return
    end
    local msg = "REPORT: " .. n .. " the " .. c .. " is AFK!"
    local tindex = UnitInRaid("target")
    if tindex then
        local _, _, subgroup = GetRaidRosterInfo(tindex)
        if subgroup then
            msg = msg .. " (Group " .. subgroup .. ")"
        else
            print("[AFKTracker] Debug: Target in raid but no subgroup detected.")
        end
    else
        print("[AFKTracker] Debug: Target not in raid (no group info added).")
    end
    local channel = (IsInInstance() and "INSTANCE_CHAT") or "RAID"
    local pindex = UnitInRaid("player")
    if pindex then
        local _, prank = GetRaidRosterInfo(pindex)
        if prank >= 1 then
            channel = "RAID_WARNING"
            print("[AFKTracker] Debug: Using RAID_WARNING (you have permissions).")
        else
            print("[AFKTracker] Debug: Using RAID (no leader/assist permissions).")
        end
    else
        print("[AFKTracker] Debug: Not in raid; falling back to RAID/party channel.")
    end
    SendChatMessage(msg, channel)
    print("[AFKTracker] Message sent: " .. msg)
end

-- Unified slash command handler
local function AFKTHandler(msg)
    local args = {}
    for word in msg:gmatch("%S+") do
        table.insert(args, word:lower())
    end
    local subcmd = args[1] or ""
    if subcmd == "announce" then
        AFKAnnounce()
    elseif subcmd == "list" then
        local limit = tonumber(args[2])
        ListAFKers(limit)
    elseif subcmd == "history" then
        AnnounceHistory()
    elseif subcmd == "bgafkers" then
        BGAfkers()
    elseif subcmd == "clear" then
        ClearRecords()
    else
        print("[AFKTracker] Usage: /afkt <command>")
        print(" - announce: Announce target as AFK (encourages reporting)")
        print(" - list [limit]: List potential AFKers with aggregates from last 24 hours (optional limit for top N)")
        print(" - history: Announce target's AFK evidence to bg chat")
        print(" - bgafkers: Print current AV suspects list to bg chat")
        print(" - clear: Clear the records list")
    end
end

SLASH_AFKT1 = "/afkt"
SlashCmdList["AFKT"] = AFKTHandler

-- Load message
print("[AFKTracker] Loaded successfully! Simplified version. Use /afkt <announce|list|history|raidlist|clear>.")
