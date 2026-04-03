local vkeys = {}

---@return table|nil
local function vehicles()
    return exports["mythic-base"]:FetchComponent("Vehicles")
end

---@param vehicle number
---@return string|nil
local function getVin(vehicle)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then
        return nil
    end
    local ent = Entity(vehicle)
    if ent and ent.state and ent.state.VIN then
        return ent.state.VIN
    end
    return nil
end

---@param src number | string Player server id
---@param vehicle number Vehicle entity
---@param plate? string Vehicle plate
function vkeys.give(src, vehicle, plate)
    local V = vehicles()
    if not V or not V.Keys or not V.Keys.Add then
        lib.print.error("prp-bridge mythic-vehicles: Vehicles.Keys.Add not available.")
        return
    end
    local vin = getVin(vehicle)
    if not vin then
        lib.print.warn("prp-bridge mythic-vehicles: vehicle has no state.VIN; keys not given.")
        return
    end
    V.Keys:Add(tonumber(src), vin)
end

---@param src number | string Player server id
---@param vehicle number Vehicle entity
---@param plate? string Vehicle plate
function vkeys.remove(src, vehicle, plate)
    local V = vehicles()
    if not V or not V.Keys or not V.Keys.Remove then
        lib.print.error("prp-bridge mythic-vehicles: Vehicles.Keys.Remove not available.")
        return
    end
    local vin = getVin(vehicle)
    if not vin then
        return
    end
    V.Keys:Remove(tonumber(src), vin)
end

if bridge.name == bridge.currentResource then
    RegisterNetEvent("prp-bridge:mythic-vehicles:giveKey", function(netId)
        local src = source
        local veh = NetworkGetEntityFromNetworkId(netId)
        vkeys.give(src, veh, nil)
    end)

    RegisterNetEvent("prp-bridge:mythic-vehicles:removeKey", function(netId)
        local src = source
        local veh = NetworkGetEntityFromNetworkId(netId)
        vkeys.remove(src, veh, nil)
    end)
end

return vkeys
