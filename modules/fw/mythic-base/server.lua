local fw = {}

---@return table|nil
local function mythic()
    return exports["mythic-base"]:FetchComponent("Fetch")
end

---@return table|nil
local function component(name)
    return exports["mythic-base"]:FetchComponent(name)
end

---@param src number|string
---@return table|nil, table|nil
local function getPlayerChar(src)
    local Fetch = mythic()
    if not Fetch then
        return nil, nil
    end
    local srcNum = tonumber(src)
    if not srcNum then
        return nil, nil
    end
    local player = Fetch:Source(srcNum)
    if not player then
        return nil, nil
    end
    local char = player:GetData("Character")
    if not char then
        return player, nil
    end
    return player, char
end

---@param src number | string
---@return string?
function fw.getIdentifier(src)
    local _, char = getPlayerChar(src)
    if not char then
        return nil
    end
    local sid = char:GetData("SID")
    return sid ~= nil and tostring(sid) or nil
end

---@param identifier string
---@return number?
function fw.getSrcFromIdentifier(identifier)
    local Fetch = mythic()
    if not Fetch then
        return nil
    end
    local sid = tonumber(identifier)
    if not sid then
        return nil
    end
    local player = Fetch:SID(sid)
    if not player then
        return nil
    end
    return player:GetData("Source")
end

---@param identifier string
---@return string?
function fw.getCharacterName(identifier)
    local Fetch = mythic()
    if not Fetch then
        return nil
    end
    local sid = tonumber(identifier)
    if not sid then
        return nil
    end
    local player = Fetch:SID(sid)
    if not player then
        return nil
    end
    local char = player:GetData("Character")
    if not char then
        return nil
    end
    local first = char:GetData("First") or ""
    local last = char:GetData("Last") or ""
    local full = ("%s %s"):format(first, last)
    return (full:match("^%s*(.-)%s*$"))
end

---@param src number | string
---@param type 'inform' | 'error' | 'success'| 'warning'
---@param message string
---@param title? string
---@param duration? number
function fw.notify(src, type, message, title, duration)
    TriggerClientEvent("prp-bridge:notify", src, type, message, title, duration)
end

---@param commandName string
---@param helpText string
---@param params table<{ name: string, type: string, help: string }>?
---@param restrictedGroup string?
---@param callback fun(src: number, args: table, rawCommand: string)
function fw.registerCommand(commandName, helpText, params, restrictedGroup, callback)
    lib.addCommand(commandName, {
        help = helpText,
        params = params,
        restricted = restrictedGroup,
    }, callback)
end

---@param src string | number
---@return boolean
function fw.isAdmin(src)
    local player = select(1, getPlayerChar(src))
    if player and player.Permissions and player.Permissions.IsAdmin then
        local ok, isAdm = pcall(function()
            return player.Permissions:IsAdmin()
        end)
        if ok and isAdm then
            return true
        end
    end
    local id = type(src) == "number" and tostring(src) or src
    return IsPlayerAceAllowed(id --[[@as string]], "admin")
end

local statusMetaKeys = {
    hunger = "PLAYER_HUNGER",
    thirst = "PLAYER_THIRST",
    stress = "PLAYER_STRESS",
}

---@param src number
---@param char table
---@param mythicKey string
---@param newValue number
local function setCharStatusValue(src, char, mythicKey, newValue)
    local st = char:GetData("Status")
    if st == nil then
        st = {}
    end
    st[mythicKey] = newValue
    char:SetData("Status", st)
    TriggerClientEvent("Status:Client:Update", src, mythicKey, newValue)
end

---@param src number | string
---@param payload table<string, { type: "set" | "add" | "remove", value: any }>
function fw.setMetadata(src, payload)
    local srcNum = tonumber(src)
    local _, char = getPlayerChar(src)
    if not char or not srcNum then
        return
    end
    local st = char:GetData("Status")
    if st == nil then
        st = {}
    end

    for key, data in pairs(payload) do
        local mythicKey = statusMetaKeys[key]
        if mythicKey then
            local currentValue = st[mythicKey]
            if type(currentValue) ~= "number" then
                currentValue = 0
            end
            local newValue
            if data.type == "add" or data.type == "remove" then
                newValue = data.type == "add" and (currentValue + data.value) or (currentValue - data.value)
                if newValue > 100 then
                    newValue = 100
                elseif newValue < 0 then
                    newValue = 0
                end
            else
                newValue = data.value
            end
            setCharStatusValue(srcNum, char, mythicKey, newValue)
            st = char:GetData("Status") or st
        end
    end
end

---@param src number | string
---@param rep string
---@param amount number
---@param reason string
function fw.addRep(src, rep, amount, reason) end

---@param src number | string
---@param rep string
---@param amount number
---@param reason string
function fw.removeRep(src, rep, amount, reason) end

---@param identifier string
---@param coords vector3
function fw.updateDisconnectLocation(identifier, coords)
    local Fetch = mythic()
    if not Fetch then
        return
    end
    local sid = tonumber(identifier)
    if not sid then
        return
    end
    local player = Fetch:SID(sid)
    if not player then
        return
    end
    local char = player:GetData("Character")
    if not char then
        return
    end
    char:SetData("LastPosition", { x = coords.x, y = coords.y, z = coords.z })
end

---@param explosionType number
function fw.isExplosionAllowed(explosionType)
    return true
end

---@param explosionType number
---@param time number
function fw.allowExplosion(explosionType, time) end

---@param src number | string
---@param moneyType "cash" | "bank" | "crypto"
---@param moneyAmount number
---@param reason string | nil
---@return boolean
function fw.addMoney(src, moneyType, moneyAmount, reason)
    local Wallet = component("Wallet")
    local Banking = component("Banking")
    local _, char = getPlayerChar(src)
    if not char then
        return false
    end
    local sid = char:GetData("SID")
    if moneyType == "cash" then
        if not Wallet or not Wallet.Modify then
            return false
        end
        return Wallet:Modify(tonumber(src) --[[@as number]], moneyAmount, true) ~= false
    elseif moneyType == "bank" then
        if not Banking or not Banking.Accounts or not Banking.Balance then
            return false
        end
        local account = Banking.Accounts:GetPersonal(sid)
        if not account or not account.Account then
            return false
        end
        local newBalance = Banking.Balance:Deposit(account.Account, moneyAmount, {
            type = "deposit",
            title = reason or "Deposit",
            description = reason or "",
            transactionAccount = false,
            data = {},
        }, true)
        return newBalance ~= false and newBalance ~= nil
    end
    return false
end

---@param src number | string
---@param moneyType "cash" | "bank" | "crypto"
---@param moneyAmount number
---@param reason string | nil
---@return boolean
function fw.removeMoney(src, moneyType, moneyAmount, reason)
    local Wallet = component("Wallet")
    local Banking = component("Banking")
    local _, char = getPlayerChar(src)
    if not char then
        return false
    end
    local sid = char:GetData("SID")
    if moneyType == "cash" then
        if not Wallet or not Wallet.Modify then
            return false
        end
        return Wallet:Modify(tonumber(src) --[[@as number]], -math.abs(moneyAmount), true) ~= false
    elseif moneyType == "bank" then
        if not Banking or not Banking.Balance then
            return false
        end
        local account = Banking.Accounts:GetPersonal(sid)
        if not account or not account.Account then
            return false
        end
        local result = Banking.Balance:Charge(account.Account, moneyAmount, {
            type = "bill",
            title = reason or "Charge",
            description = reason or "",
            data = {},
        })
        return result ~= false and result ~= nil
    end
    return false
end

---@param src number | string
---@param moneyType "cash" | "bank" | "crypto"
---@return number
function fw.getMoney(src, moneyType)
    local Wallet = component("Wallet")
    local Banking = component("Banking")
    local _, char = getPlayerChar(src)
    if not char then
        return 0
    end
    local sid = char:GetData("SID")
    if moneyType == "cash" then
        if Wallet and Wallet.Get then
            return Wallet:Get(tonumber(src) --[[@as number]]) or 0
        end
        return tonumber(char:GetData("Cash")) or 0
    elseif moneyType == "bank" then
        if not Banking or not Banking.Accounts or not Banking.Balance then
            return 0
        end
        local account = Banking.Accounts:GetPersonal(sid)
        if not account or not account.Account then
            return 0
        end
        return Banking.Balance:Get(account.Account) or 0
    elseif moneyType == "crypto" then
        return tonumber(char:GetData("Crypto")) or 0
    end
    return 0
end

---@param src number | string
---@param job string
---@param grade number?
---@param duty boolean?
---@return boolean
function fw.hasJob(src, job, grade, duty)
    local Jobs = component("Jobs")
    local srcNum = tonumber(src) --[[@as number]]
    local found ---@type table|nil
    local playerJobs
    if Jobs and Jobs.Permissions and Jobs.Permissions.GetJobs then
        playerJobs = Jobs.Permissions:GetJobs(srcNum)
    end
    if playerJobs then
        for _, j in ipairs(playerJobs) do
            if j.Id == job then
                found = j
                break
            end
        end
    else
        local _, char = getPlayerChar(src)
        if not char then
            return false
        end
        for _, j in ipairs(char:GetData("Jobs") or {}) do
            if j.Id == job then
                found = j
                break
            end
        end
    end
    if not found then
        return false
    end
    if grade and (found.GradeLevel or 0) < grade then
        return false
    end
    if duty then
        local onDuty = Player(tostring(src)).state.onDuty
        if onDuty ~= job then
            return false
        end
    end
    return true
end

---@param jobName string
---@return number
function fw.getDutyCountJob(jobName)
    local Jobs = component("Jobs")
    if not Jobs or not Jobs.Duty or not Jobs.Duty.GetDutyData then
        return 0
    end
    local dutyData = Jobs.Duty:GetDutyData(jobName)
    local players = dutyData and dutyData.DutyPlayers
    return players and #players or 0
end

---@param jobName string
---@return table<number, true>
function fw.getPlayersOnDuty(jobName)
    local Jobs = component("Jobs")
    local formatted = {}
    if not Jobs or not Jobs.Duty or not Jobs.Duty.GetDutyData then
        return formatted
    end
    local dutyData = Jobs.Duty:GetDutyData(jobName)
    local players = dutyData and dutyData.DutyPlayers or {}
    for i = 1, #players do
        formatted[players[i]] = true
    end
    return formatted
end

local itemUseRegistry = 0

---@param itemName string
---@param cb fun(src: number, item: { name: string, label: string, metaData: table?, slot: number, count: number })
function fw.registerItemUse(itemName, cb)
    local Inventory = component("Inventory")
    if not Inventory or not Inventory.Items or not Inventory.Items.RegisterUse then
        lib.print.error("prp-bridge mythic-base: Inventory.Items:RegisterUse is not available")
        return
    end
    itemUseRegistry = itemUseRegistry + 1
    local regId = ("prp-bridge:%s:%s"):format(itemName, itemUseRegistry)
    Inventory.Items:RegisterUse(itemName, regId, function(src, item, itemDef)
        local data = {
            name = item.Name,
            label = (itemDef and itemDef.label) or item.Name,
            metaData = item.MetaData,
            slot = item.Slot,
            count = item.Count or 1,
        }
        local s, e = pcall(cb, src, data)
        if not s then
            print(("prp-bridge: Error in item usage handler for item '%s': %s"):format(itemName, e))
        end
    end)
end

---@param plate string
---@param veh table
---@return OwnedVehicle|nil
local function toOwnedVehicle(plate, veh)
    if not veh or not veh.Model then
        return nil
    end
    local modelName = veh.Model
    local modelHash = type(modelName) == "number" and modelName or joaat(modelName)
    if not BridgeConfig.VehicleData[modelHash] then
        lib.print.error(
            "No vehicle data in `BridgeConfig.VehicleData` for plate:",
            plate,
            " model:",
            modelHash
        )
        return nil
    end
    if not BridgeConfig.VehicleData[modelHash].class then
        lib.print.error("No vehicle class in `BridgeConfig.VehicleData` for plate:", plate, " model:", modelHash)
        return nil
    end
    local vehData = lib.table.deepclone(BridgeConfig.VehicleData[modelHash])
    return lib.table.merge(vehData, { plate = veh.RegisteredPlate or plate }, false)
end

---@param plate string
---@param returnEmpty? boolean
---@return OwnedVehicle | nil
function fw.getOwnedVehicleByPlate(plate, returnEmpty)
    local Vehicles = component("Vehicles")
    if Vehicles and Vehicles.Owned then
        local owned ---@type OwnedVehicle|nil
        if Vehicles.Owned.GetByRegisteredPlate then
            local p = promise.new()
            Vehicles.Owned:GetByRegisteredPlate(plate, function(data)
                p:resolve(data)
            end)
            local veh = Citizen.Await(p)
            if veh then
                owned = toOwnedVehicle(plate, veh)
            end
        elseif Vehicles.Owned.GetFromPlate then
            local p = promise.new()
            Vehicles.Owned:GetFromPlate(plate, function(data)
                p:resolve(data)
            end)
            local veh = Citizen.Await(p)
            if veh then
                owned = toOwnedVehicle(plate, veh)
            end
        end
        if owned then
            return owned
        end
    end

    lib.print.debug(
        "prp-bridge mythic-base: getOwnedVehicleByPlate — add Vehicles.Owned:GetByRegisteredPlate or implement a DB lookup in modules/fw/mythic-base/server.lua."
    )
    if returnEmpty then
        return {
            label = locale("UNKNOWN"),
            class = "OPEN",
            plate = plate,
        }
    end
    return nil
end

---@param identifier string | number
---@param classes? string | table<string>
---@return table<number, OwnedVehicle> | nil
function fw.getAllOwnedVehicles(identifier, classes)
    local Vehicles = component("Vehicles")
    if not Vehicles or not Vehicles.Owned or not Vehicles.Owned.GetAll then
        lib.print.error("prp-bridge mythic-base: Vehicles.Owned:GetAll not available")
        return nil
    end
    local sid = tonumber(identifier)
    if not sid then
        return nil
    end
    local p = promise.new()
    Vehicles.Owned:GetAll(0, 0, sid, function(vehicles)
        p:resolve(vehicles or {})
    end, nil, nil, false)
    local list = Citizen.Await(p)
    local filtered = {}
    for _, veh in ipairs(list) do
        local plate = veh.RegisteredPlate or ""
        local owned = toOwnedVehicle(plate, veh)
        if owned then
            if not classes then
                filtered[#filtered + 1] = owned
            else
                local c = owned.class
                if c and (type(classes) == "table" and lib.table.contains(classes, c) or c == classes) then
                    filtered[#filtered + 1] = owned
                end
            end
        end
    end
    return filtered
end

---@param src number
---@param vehicleName string
---@return integer?
---@return string?
function fw.addOwnedVehicle(src, vehicleName)
    local stateId = bridge.fw.getIdentifier(src)
    if not stateId then
        return nil, "CHARACTER_NOT_LOGGED_IN"
    end
    local Vehicles = component("Vehicles")
    if not Vehicles or not Vehicles.Owned or not Vehicles.Owned.AddToCharacter then
        return nil, "VEHICLES_COMPONENT_UNAVAILABLE"
    end
    local hash = joaat(vehicleName)
    local p = promise.new()
    Vehicles.Owned:AddToCharacter(tonumber(stateId), hash, 0, {
        make = "Unknown",
        model = vehicleName,
        class = "OPEN",
        value = 0,
    }, function(success, vehicleData)
        if success and vehicleData then
            p:resolve(vehicleData)
        else
            p:resolve(nil)
        end
    end)
    local result = Citizen.Await(p)
    if not result then
        return nil, "VEHICLE_CREATE_FAILED"
    end
    return 1
end

---@param plate string
---@param identifier string
---@return boolean
---@return string?
function fw.updateVehicleOwner(plate, identifier)
    local Vehicles = component("Vehicles")
    if Vehicles and Vehicles.Owned and Vehicles.Owned.TransferToCharacter then
        local p = promise.new()
        Vehicles.Owned:TransferToCharacter(plate, tonumber(identifier), function(ok)
            p:resolve(ok)
        end)
        local ok = Citizen.Await(p)
        if ok then
            return true
        end
    end
    lib.print.debug(
        "prp-bridge mythic-base: updateVehicleOwner — implement using your Vehicles resource (e.g. transfer by plate to SID). plate:",
        plate
    )
    return false, "NOT_IMPLEMENTED"
end

if bridge.name == bridge.currentResource then
    -- mythic-characters calls Middleware:TriggerEvent('Characters:CharacterSelected', source) after loading the
    -- Character DataStore (see server/callbacks.lua). Register here so we match upstream behavior.
    CreateThread(function()
        local deadline = GetGameTimer() + 60000
        local Middleware
        repeat
            Middleware = exports["mythic-base"]:FetchComponent("Middleware")
            if Middleware and Middleware.Add then
                break
            end
            Wait(200)
        until GetGameTimer() > deadline

        if Middleware and Middleware.Add then
            Middleware:Add("Characters:CharacterSelected", function(source)
                TriggerEvent("prp-bridge:server:playerLoad", source)
            end, 10)

            Middleware:Add("Characters:Logout", function(source)
                TriggerEvent("prp-bridge:server:playerUnload", source)
            end, 10)
        else
            lib.print.error("prp-bridge mythic-base: Middleware component not available; playerLoad will not hook. Is mythic-base started?")
        end
    end)

    -- Crash / forced quit: logout callback may not run; unload if a character was still loaded.
    AddEventHandler("playerDropped", function()
        local src = source
        local Fetch = mythic()
        if not Fetch then
            return
        end
        local player = Fetch:Source(src)
        if player and player:GetData("Character") then
            TriggerEvent("prp-bridge:server:playerUnload", src)
        end
    end)
end

return fw
