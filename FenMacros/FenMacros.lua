--[[
    Fenrir's Macro:

    Set of different Macros

]]
----------------------------------------------------------------
-- "UP VALUES" FOR SPEED ---------------------------------------
----------------------------------------------------------------

----------------------------------------------------------------
-- CONSTANTS THAT SHOULD BE GLOBAL PROBABLY --------------------
----------------------------------------------------------------

local SCRIPTHANDLER_ON_EVENT = "OnEvent"

----------------------------------------------------------------
-- HELPER FUNCTIONS --------------------------------------------
----------------------------------------------------------------

local function merge(left, right)
    local t = {}

    if type(left) ~= "table" or type(right) ~= "table" then
        error("Usage: merge(left <table>, right <table>)")
    end

    -- copy left into temp table.
    for k, v in pairs(left) do
        t[k] = v
    end

    -- Add or overwrite right values.
    for k, v in pairs(right) do
        t[k] = v
    end

    return t
end

--------

local function toColourisedString(value)
    local val

    if type(value) == "string" then
        val = "|cffffffff" .. value .. "|r"
    elseif type(value) == "number" then
        val = "|cffffff33" .. tostring(value) .. "|r"
    elseif type(value) == "boolean" then
        val = "|cff9999ff" .. tostring(value) .. "|r"
    end

    return val
end

--------

local function prt(message)
    if (message and message ~= "") then
        if type(message) ~= "string" then
            message = tostring(message)
        end

        DEFAULT_CHAT_FRAME:AddMessage(message)
    end
end

--------

function strsplit(s, sep)
    if sep == nil then
        sep = "%s"
    end
    local t = {}
    for str in string.gmatch(s, "([^"..sep.."]+)") do
        table.insert(t, str)
        end
    return t
end

--------

function strtrim(s)
   return string.match(s, "^%s*(.-)%s*$" )
end


----------------------------------------------------------------
-- FENMACRO ADDON ------------------------------------------------
----------------------------------------------------------------

FenMacros = CreateFrame("FRAME", "FenMacro", UIParent)

local this = FenMacro

----------------------------------------------------------------
-- INTERNAL CONSTANTS ------------------------------------------
----------------------------------------------------------------

----------------------------------------------------------------
-- DATABASE KEYS -----------------------------------------------
----------------------------------------------------------------

local DB_VERSION = "db_version"
local IS_DEBUGGING = "is_debugging"

local _defaultDB = {
    [DB_VERSION] = 8,
    [IS_DEBUGGING] = false,
}

----------------------------------------------------------------
-- PRIVATE VARIABLES -------------------------------------------
----------------------------------------------------------------

local initialisationEvent = "ADDON_LOADED"

local _db

local unitName
local realmName
local profileId

local eventHandlers
local commandList

local isDebugging = false

----------------------------------------------------------------
-- PRIVATE FUNCTIONS -------------------------------------------
----------------------------------------------------------------

local function report(label, message)
    label = tostring(label)
    message = tostring(message)

    local str = "|cff22ff22FenMacros|r - |cff999999" .. label .. ":|r " .. message

    DEFAULT_CHAT_FRAME:AddMessage(str)
end

--------

local function debugLog(message)
    if _db[IS_DEBUGGING] then
        report("DEBUG", message)
    end
end

--------

local function addEvent(eventName, eventHandler)
    if (not eventName) or (eventName == "") or (not eventHandler) or (type(eventHandler) ~= "function") then
        error("Usage: addEvent(eventName <string>, eventHandler <function>)")
    end

    eventHandlers[eventName] = eventHandler
    this:RegisterEvent(eventName)
end

--------

local function removeEvent(eventName)
    local eventHandler = eventHandlers[eventName]
    if eventHandler then
        -- GC should pick this up when a new assignment happens
        eventHandlers[eventName] = nil
    end

    this:UnregisterEvent(eventName)
end

--------

local function addSlashCommand(name, command, commandDescription, dbProperty)
    -- prt("Adding a slash command");
    if
        (not name) or (name == "") or (not command) or (type(command) ~= "function") or (not commandDescription) or
            (commandDescription == "")
     then
        error(
            "Usage: addSlashCommand(name <string>, command <function>, commandDescription <string> [, dbProperty <string>])"
        )
    end

    -- prt("Creating a slash command object into the command list");
    commandList[name] = {
        ["execute"] = command,
        ["description"] = commandDescription
    }

    if (dbProperty) then
        if (type(dbProperty) ~= "string" or dbProperty == "") then
            error("dbProperty must be a non-empty string.")
        end

        if (_db[dbProperty] == nil) then
            error('The internal database property: "' .. dbProperty .. '" could not be found.')
        end
        -- prt("Add the database property to the command list");
        commandList[name]["value"] = dbProperty
    end
end

--------

local function loadProfileID()
    unitName = UnitName("player")
    realmName = GetRealmName()
    profileId = unitName .. "-" .. realmName
end

--------

local function printSlashCommandList()
    report("Listing", "Slash commands")

    local str
    local description

    for name, cmdObject in pairs(commandList) do
        description = cmdObject.description

        if (not description) then
            error('Attempt to print slash command with name:"' .. name .. '" without valid description')
        end

        str = "/fm " .. name .. " " .. description

        -- If the slash command sets a value we should have
        if (cmdObject.value) then
            str = str .. " (|cff666666Currently:|r " .. toColourisedString(_db[cmdObject.value]) .. ")"
        end

        prt(str)
    end
end

--------

local function slashCmdHandler(message, chatFrame)
    local _, _, commandName, params = string.find(message, "^(%S+) *(.*)")

    -- Stringify it
    commandName = tostring(commandName)

    -- Pull the given command from our list.
    local command = commandList[commandName]
    if (command) then
        -- Run the command we found.
        if (type(command.execute) ~= "function") then
            error("Attempt to execute slash command without execution function.")
        end

        command.execute(params)
    else
        -- prt("Print our available command list.");
        printSlashCommandList()
    end
end

--------

local function storeLocalDatabaseToSavedVariables()
    -- #OPTION: We could have local variables for lots of DB
    --          stuff that we can load into the _db Object
    --          before we store it.
    --
    --          Should probably make a list of variables to keep
    --          track of which changed and should be updated.
    --          Something we can just loop through so load and
    --          unload never desync.

    -- Commit to local storage
    FenMacrosDB[profileId] = _db
end

--------

local function loadSavedVariables()
    -- First time install
    if not FenMacrosDB then
        FenMacrosDB = {}
    end

    -- this should produce an error if profileId is not yet set, as is intended.
    _db = FenMacrosDB[profileId]

    -- This means we have a new char.
    if not _db then
        _db = _defaultDB
    end

    -- In this case we have a player with an older version DB.
    if (not _db[DB_VERSION]) or (_db[DB_VERSION] < _defaultDB[DB_VERSION]) then
        -- For now we just blindly attempt to merge.
        _db = merge(_defaultDB, _db)
    end
end

--------

local function find_ctrl(s)
    sp, ep = string.find(s, "^%s*%[[^%]]*%]", p)
    if sp ~= nil then
        c = string.sub(strtrim(string.sub(s, sp, ep)), 2, -2)

        debugLog("find_ctrl: Found control: " .. c .. " at pos: " .. sp)
    end

    return c, sp, ep
end

local function parse_ctrl(ctrl)
    local m = nil
    local c = -1

    ctrls = strsplit(ctrl, ',')

    for k,v in ctrls do
        if v == 'nomod' then
            m = v
        end

        if v == 'combat' then
            c = 1
        end

        if v == 'nocombat' then
            c = nil
        end

        t = strsplit(v, ':')

        if t[1] == 'mod' then
            m = t[2]
        end
    end

    return m, c
end

local function check_ctrl(modifier, combat)
    local c = combat
    local m = modifier

    if (c ~= -1 and c ~= UnitAffectingCombat("Player"))
        or ((m == 'ctrl' or m == 'control') and not IsControlKeyDown())
        or (m == 'alt' and not IsAltKeyDown())
        or (m == 'shift' and not IsShiftKeyDown())
        or (m == 'nomod' and (IsControlKeyDown() or IsAltKeyDown() or IsShiftKeyDown())) then
        return false
    else
        return true
    end
end

--------

local function search_bags(item)
	local bagStart,bagEnd = 0,4
    local bag,slot=nil,nil

	for i=bagStart,bagEnd do
		for j=1,GetContainerNumSlots(i) do
			itemLink = GetContainerItemLink(i,j)

            if itemLink ~= nil then
                _,_,id = string.find(itemLink,"(item:%d+:%d+:%d+:%d+)")
                _,_,itemID = string.find(id or "","item:(%d+:%d+:%d+):%d+")
                itemName,_,_,_,_,_,_,itemSlot,itemTexture = GetItemInfo(id)

                if item == itemName then
                    debugLog("search_bags: found: " .. item .. " (" .. itemLink .. ")")
                    bag=i
                    slot=j
                    break
                end
            end
		end
	end

    return bag,slot
end

----------------------------------------------------------------
-- PUBLIC METHODS ----------------------------------------------
----------------------------------------------------------------

local function toggleDebugging()
    if not _db[IS_DEBUGGING] then
        _db[IS_DEBUGGING] = true
    else
        _db[IS_DEBUGGING] = false
    end

    report("Debugging", (_db[IS_DEBUGGING] and "Yes" or "No"))
end

--------

local function equipslot(s)
    p = 0
    l = string.len(s)

    while p < l do
        sp, ep = string.find(s, "^%s*%[[^%]]*%]", p)
        if sp ~= nil then
            p = ep+1
            c = string.sub(strtrim(string.sub(s, sp, ep)), 2, -2)

            debugLog("equipslot: Found control: " .. c .. " at pos: " .. sp)
        end

        slot, item = string.match(s, "(%d+) ([^,]+)", p)

        if slot ~= nil then
            debugLog("equipslot: slot: " .. slot)
        end
        if item ~= nil then
            debugLog("equipslot: item: " .. item)
        end

        b, i = search_bags(item)
        if b ~= nil then
            PickupContainerItem(b, i)
            PickupInventoryItem(slot)
        end

        sp, ep = string.find(s, ",", p)
        if ep ~= nil then
            p = ep+1
        else
            debugLog("equipslot: break from pos: " .. p .. " with str: " .. string.sub(s, p, l))
            break
        end
    end
end

local function cast(s)
    p = 0
    l = string.len(s)

    while p < l do
        m = nil

        debugLog("Parsing: at pos: " .. p .. ": " .. string.sub(s, p))

        c, sp, ep = find_ctrl(s)
        if sp ~= nil then
            p = ep+1
            m, c = parse_ctrl(c)
        end

        sp, ep = string.find(s, "[^,]+", p)
        if ep ~= nil then
            spell = strtrim(string.sub(s, sp, ep))
            p = ep+2

            debugLog("cast: Found spell: '" .. spell .. "' at pos: " .. sp)

            continue = true
            while continue do
                continue = false

                if false == check_ctrl(m, c) then
                    debugLog("cast: break1")
                    break
                end

                CastSpellByName(spell)
            end
        else
            debugLog("cast: break from pos: " .. p .. " with str: " .. string.sub(s, p, l))
            break
        end
    end
end

local function startattack(s)
    s, _, _ = find_ctrl(s)
    m, c = parse_ctrl(s)

    debugLog("startattack: m:" .. m)
    debugLog("startattack: c:" .. c)

    if true == check_ctrl(m, c) then
        if not PlayerFrame.inCombat then
            AttackTarget()
        end
    end
end

local function stopattack(s)
    s, _, _ = find_ctrl(s)
    m, c = parse_ctrl(s)

    debugLog("stopattack: m:" .. m)
    debugLog("stopattack: c:" .. c)

    if true == check_ctrl(m, c) then
        if PlayerFrame.inCombat then
            AttackTarget()
        end
    end
end

local function petattack(s)
    s, _, _ = find_ctrl(s)
    m, c = parse_ctrl(s)

    if true == check_ctrl(m, c) then
        debugLog("petattack: check_ctrl is true")
        PetAttack()
    else
        debugLog("petattack: check_ctrl is false")
    end
end

local function petfollow(s)
    s, _, _ = find_ctrl(s)
    m, c = parse_ctrl(s)

    debugLog("petfollow: m:" .. m)
    debugLog("petfollow: c:" .. c)

    if true == check_ctrl(m, c) then
        debugLog("petfollow: check_ctrl is true")
        PetFollow()
    else
        debugLog("petfollow: check_ctrl is false")
    end
end

--------

local function populateSlashCommandList()
    -- For now we just reset this thing.
    commandList = {}

    addSlashCommand(
        "cast",
        cast,
        "[|cffffff330+|r] |cff999999\n\t-- Cast a spell.|r",
        nil
    )

    addSlashCommand(
        "startattack",
        startattack,
        "[|cffffff330+|r] |cff999999\n\t-- Start attacking.|r",
        nil
    )

    addSlashCommand(
        "stopattack",
        stopattack,
        "[|cffffff330+|r] |cff999999\n\t-- Stop attacking.|r",
        nil
    )

    addSlashCommand(
        "petattack",
        petattack,
        "[|cffffff330+|r] |cff999999\n\t-- Tell the pet to attack.|r",
        nil
    )

    addSlashCommand(
        "petfollow",
        petfollow,
        "[|cffffff330+|r] |cff999999\n\t-- Tell the pet to follow.|r",
        nil
    )

    addSlashCommand(
        "equipslot",
        equipslot,
        "[|cffffff330+|r] |cff999999\n\t-- Equip an item in a specific inventory slot.|r",
        nil
    )

    addSlashCommand(
        "debug",
        toggleDebugging,
        "<|cff9999fftoggle|r> |cff999999\n\t-- Toggle whether debug messages are shown.|r",
        IS_DEBUGGING
    )
end

--------

local function initialise()
    loadProfileID()
    loadSavedVariables()

    this:UnregisterEvent(initialisationEvent)

    eventHandlers = {}

    populateSlashCommandList()
    this:SetScript(SCRIPTHANDLER_ON_EVENT, eventCoordinator)

    addEvent("PLAYER_LOGOUT", storeLocalDatabaseToSavedVariables)
end

-- Add slashcommand match entries into the global namespace for the client to pick up.
SLASH_FENMACROS1 = "/fm"
SLASH_FENMACROS2 = "/fmacro"

-- And add a handler to react on the above matches.
SlashCmdList["FENMACROS"] = slashCmdHandler

this:SetScript(SCRIPTHANDLER_ON_EVENT, initialise)
this:RegisterEvent(initialisationEvent)