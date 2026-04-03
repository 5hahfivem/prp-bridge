local vkeys = {}

---@param vehicle number Vehicle entity
---@param plate? string Vehicle plate
function vkeys.give(vehicle, plate)
    TriggerServerEvent("prp-bridge:mythic-vehicles:giveKey", NetworkGetNetworkIdFromEntity(vehicle))
end

---@param vehicle number Vehicle entity
---@param plate? string Vehicle plate
function vkeys.remove(vehicle, plate)
    TriggerServerEvent("prp-bridge:mythic-vehicles:removeKey", NetworkGetNetworkIdFromEntity(vehicle))
end

return vkeys
