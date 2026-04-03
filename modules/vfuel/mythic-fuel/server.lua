local vfuel = {}

---@param source number
---@param vehicle number
---@param amount number
---@return boolean
function vfuel.set(source, vehicle, amount)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then
        return false
    end
    local ent = Entity(vehicle)
    if not ent or not ent.state then
        return false
    end
    local v = math.max(0, math.min(100, amount))
    ent.state:set("Fuel", v, true)
    return true
end

return vfuel
