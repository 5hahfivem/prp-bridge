local target = {}

---@return table|nil
local function targeting()
    return exports["mythic-base"]:FetchComponent("Targeting")
end

---@param options TargetOptions[]
---@param zoneName string?
---@return table[]
local function toMythicMenu(options, zoneName)
    local menu = {}
    for _, opt in ipairs(options) do
        local entry = {
            text = opt.label,
            event = opt.event,
        }
        if opt.icon then
            entry.icon = opt.icon
        end
        if opt.onSelect and not opt.event then
            local ev = ("__prp_bridge_mythic_tgt_%s"):format(opt.name or tostring(math.random(1, 999999)))
            entry.event = ev
            AddEventHandler(ev, function(entityData, _)
                if opt.onSelect then
                    opt.onSelect({
                        entity = entityData and entityData.entity,
                        distance = entityData and #(GetEntityCoords(PlayerPedId()) - entityData.endCoords),
                        coords = entityData and entityData.endCoords,
                        zone = zoneName,
                    })
                end
            end)
        end
        menu[#menu + 1] = entry
    end
    return menu
end

---@param zoneId number | string
function target.removeZone(zoneId)
    local T = targeting()
    if T and T.Zones and T.Zones.RemoveZone then
        T.Zones:RemoveZone(zoneId)
    end
end

---@param payload TargetBoxZone
---@return number | string
function target.addBoxZone(payload)
    local T = targeting()
    if not T or not T.Zones or not T.Zones.AddBox then
        return payload.name or "invalid"
    end
    local coords = payload.coords
    local size = payload.size or vector3(1.5, 1.5, 2.0)
    local menu = toMythicMenu(payload.options or {}, payload.name)
    T.Zones:AddBox(payload.name, false, coords, size.x, size.y, { heading = payload.rotation or 0, debugPoly = payload.debug }, menu, 10.0, true)
    if T.Zones.Refresh then
        T.Zones:Refresh()
    end
    return payload.name
end

---@param payload TargetSphereZone
---@return number | string
function target.addSphereZone(payload)
    local T = targeting()
    if not T or not T.Zones or not T.Zones.AddCircle then
        return payload.name or "invalid"
    end
    local menu = toMythicMenu(payload.options or {}, payload.name)
    T.Zones:AddCircle(payload.name, false, payload.coords, payload.radius or 1.5, { debugPoly = payload.debug }, menu, 10.0, true)
    if T.Zones.Refresh then
        T.Zones:Refresh()
    end
    return payload.name
end

---@param entities number | number[]
---@param options TargetOptions[]
function target.addLocalEntity(entities, options)
    local T = targeting()
    if not T or not T.AddEntity then
        return
    end
    local list = type(entities) == "table" and entities or { entities }
    local menu = toMythicMenu(options, nil)
    for _, ent in ipairs(list) do
        T:AddEntity(ent --[[@as integer]], false, menu, 3.0)
    end
end

---@param entities number | number[]
---@param optionNames string | string[]
function target.removeLocalEntity(entities, optionNames)
    local T = targeting()
    if not T or not T.RemoveEntity then
        return
    end
    local list = type(entities) == "table" and entities or { entities }
    for _, ent in ipairs(list) do
        T:RemoveEntity(ent)
    end
end

---@param netIds number | number[]
---@param options TargetOptions[]
function target.addEntity(netIds, options)
    local ids = type(netIds) == "table" and netIds or { netIds }
    local entities = {}
    for i = 1, #ids do
        local ent = NetworkGetEntityFromNetworkId(ids[i] --[[@as integer]])
        if ent and ent ~= 0 then
            entities[#entities + 1] = ent
        end
    end
    target.addLocalEntity(entities, options)
end

---@param netIds number | number[]
---@param optionNames string | string[] | nil
function target.removeEntity(netIds, optionNames)
    local ids = type(netIds) == "table" and netIds or { netIds }
    local entities = {}
    for i = 1, #ids do
        local ent = NetworkGetEntityFromNetworkId(ids[i] --[[@as integer]])
        if ent and ent ~= 0 then
            entities[#entities + 1] = ent
        end
    end
    target.removeLocalEntity(entities, optionNames)
end

---@param options TargetOptions[]
function target.addGlobalPed(options)
    lib.print.warn("prp-bridge mythic-targeting: addGlobalPed — use mythic Config interactable peds or model targets.")
end

---@param optionNames string | string[]
function target.removeGlobalPed(optionNames) end

---@param options TargetOptions[]
function target.addGlobalPlayer(options)
    lib.print.warn("prp-bridge mythic-targeting: addGlobalPlayer — player interactions are configured in mythic-targeting Config.")
end

---@param optionNames string | string[]
function target.removeGlobalPlayer(optionNames) end

---@param options TargetOptions[]
function target.addGlobalVehicle(options)
    lib.print.warn("prp-bridge mythic-targeting: addGlobalVehicle — vehicle menu is configured in mythic-targeting Config.")
end

---@param optionNames string | string[]
function target.removeGlobalVehicle(optionNames) end

---@param models number | string | (number | string)[]
---@param options TargetOptions[]
function target.addModel(models, options)
    local T = targeting()
    if not T or not T.AddObject then
        return
    end
    local list = type(models) == "table" and models or { models }
    local menu = toMythicMenu(options, nil)
    for _, m in ipairs(list) do
        local hash = type(m) == "string" and joaat(m) or m
        T:AddObject(hash, false, menu, 3.0)
    end
end

---@param models number | string | (number | string)[]
---@param optionNames string | string[]
function target.removeModel(models, optionNames)
    local T = targeting()
    if not T or not T.RemoveObject then
        return
    end
    local list = type(models) == "table" and models or { models }
    for _, m in ipairs(list) do
        local hash = type(m) == "string" and joaat(m) or m
        T:RemoveObject(hash)
    end
end

---@param disable boolean
function target.disableTargeting(disable)
    lib.print.warn("prp-bridge mythic-targeting: disableTargeting not mapped — toggle targeting in mythic-base Keybinds if needed.")
end

return target
