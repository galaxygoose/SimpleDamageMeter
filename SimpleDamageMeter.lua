-- Create a frame to capture combat log events
local eventFrame = CreateFrame("Frame")

-- Initialize saved variables if they don't exist
SimpleDamageMeterDB = SimpleDamageMeterDB or {}
SimpleDamageMeterDB.totalDamage = 0
SimpleDamageMeterDB.startTime = nil
SimpleDamageMeterDB.targetCount = {}
SimpleDamageMeterDB.lastSummary = nil  -- Variable to hold the last summary for sharing

-- Function to calculate and return the summary message
local function CreateChatSummary()
    if SimpleDamageMeterDB.totalDamage > 0 and SimpleDamageMeterDB.startTime then
        local combatTime = GetTime() - SimpleDamageMeterDB.startTime
        local dps = combatTime > 0 and (SimpleDamageMeterDB.totalDamage / combatTime) or 0
        local targetCount = 0
        for _ in pairs(SimpleDamageMeterDB.targetCount) do
            targetCount = targetCount + 1
        end

        SimpleDamageMeterDB.lastSummary = format("SimpleDamageMeter: %.1fk DPS / %s damage / %d targets",
                      dps / 1000, SimpleDamageMeterDB.totalDamage, targetCount)
    else
        SimpleDamageMeterDB.lastSummary = "No damage data to share."
    end
end

-- Function to reset data
local function ResetData()
    SimpleDamageMeterDB.totalDamage = 0
    SimpleDamageMeterDB.startTime = nil
    SimpleDamageMeterDB.targetCount = {}
end

-- Slash command for sharing the summary
SLASH_SIMPLEDMG1 = '/sdmg'
function SlashCmdList.SIMPLEDMG(msg, editbox)
    if SimpleDamageMeterDB.lastSummary and not SimpleDamageMeterDB.lastSummary:match("^No damage") then
        if IsInGroup(LE_PARTY_CATEGORY_HOME) then
            SendChatMessage(SimpleDamageMeterDB.lastSummary, "PARTY")
        elseif IsInRaid(LE_PARTY_CATEGORY_HOME) then
            SendChatMessage(SimpleDamageMeterDB.lastSummary, "RAID")
        else
            print(SimpleDamageMeterDB.lastSummary) -- If not in a group, it will just print the summary for the player.
        end
        ResetData()
    else
        print(SimpleDamageMeterDB.lastSummary or "No damage data to share.")
    end
end

-- Event handling
local function OnEvent(self, event, ...)
    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        local timestamp, subevent, _, sourceGUID, sourceName, sourceFlags, _, destGUID, destName, destFlags, _, spellID, spellName, spellSchool, amount, overkill, school, resisted, blocked, absorbed = CombatLogGetCurrentEventInfo()

        -- Check if the source of the event is the player or something the player controls
        if amount and bit.band(sourceFlags, COMBATLOG_OBJECT_AFFILIATION_MINE) ~= 0 then
            if subevent:find("_DAMAGE") then
                -- Calculate the total amount of damage including overkill, resisted, blocked, and absorbed
                amount = amount or 0  -- Ensure amount is not nil
                overkill = overkill or 0
                resisted = resisted or 0
                blocked = blocked or 0
                absorbed = absorbed or 0

                -- Only positive damage counts, not overkill
                local totalAmount = math.max(amount - overkill, 0)

                -- Include resisted, blocked, and absorbed damage to capture the full potential damage done
                totalAmount = totalAmount + resisted + blocked + absorbed

                -- Update the total damage
                SimpleDamageMeterDB.totalDamage = SimpleDamageMeterDB.totalDamage + totalAmount
                SimpleDamageMeterDB.targetCount[destGUID] = true
            end
        end
    elseif event == "PLAYER_REGEN_DISABLED" then
        -- Player is entering combat, mark the start time and clear previous encounter data
        SimpleDamageMeterDB.startTime = GetTime()
        SimpleDamageMeterDB.totalDamage = 0
        SimpleDamageMeterDB.targetCount = {}
    elseif event == "PLAYER_REGEN_ENABLED" then
        -- Player left combat, update the last summary
        CreateChatSummary()
        print(SimpleDamageMeterDB.lastSummary)
    end
end

-- Register the event frame to listen for events
eventFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:SetScript("OnEvent", OnEvent)
