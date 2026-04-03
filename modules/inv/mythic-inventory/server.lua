local inv = {}

---@return table|nil
local function mythic()
    return exports["mythic-base"]:FetchComponent("Inventory")
end

---@return table|nil
local function fetch()
    return exports["mythic-base"]:FetchComponent("Fetch")
end

---@param inventoryId string|number
---@return number|nil owner SID or stash owner key
---@return number|nil invType
---@return number|nil src if inventoryId is a player server id
local function resolveInventory(inventoryId)
    if type(inventoryId) == "number" then
        local Fetch = fetch()
        if Fetch then
            local p = Fetch:Source(inventoryId)
            if p and p:GetData("Character") then
                return p:GetData("Character"):GetData("SID"), 1, inventoryId
            end
        end
        return inventoryId, 1, nil
    end
    if type(inventoryId) == "string" then
        local owner, typ = inventoryId:match("^(%d+)-(%d+)$")
        if owner and typ then
            return tonumber(owner), tonumber(typ), nil
        end
    end
    return nil, nil, nil
end

---@param row table
---@return table
local function decodeRow(row)
    local md = {}
    local rawMeta = row.MetaData or row.metadata
    if rawMeta and rawMeta ~= "" then
        local ok, j = pcall(json.decode, rawMeta)
        if ok and type(j) == "table" then
            md = j
        end
    end
    local name = row.Name or row.name
    local count = row.Count or row.count
    local slot = row.Slot or row.slot
    local id = row.id or row.ID
    return {
        name = name,
        count = count,
        metaData = md,
        slot = slot,
        id = id,
    }
end

---@param inventoryId string|number
---@return table<{ name: string, count: number, metaData: table?, slot: number }>
function inv.getInventoryItems(inventoryId)
    local Inventory = mythic()
    if not Inventory or not Inventory.GetInventory then
        return {}
    end
    local owner, invType, src = resolveInventory(inventoryId)
    if not owner or not invType then
        return {}
    end
    local rows = Inventory:GetInventory(src or 0, owner, invType)
    if not rows or type(rows) ~= "table" then
        return {}
    end
    local out = {}
    for _, row in ipairs(rows) do
        out[#out + 1] = decodeRow(row)
    end
    return out
end

---@param inventoryId string | number
---@return table | nil
function inv.getInventory(inventoryId)
    return { items = inv.getInventoryItems(inventoryId) }
end

---@param data InvTempStashProps
---@return string inventoryId
function inv.createTemporaryStash(data)
    local Inventory = mythic()
    if not Inventory or not Inventory.CreateDropzone then
        lib.print.error("prp-bridge mythic-inventory: CreateDropzone not available")
        return "invalid-drop"
    end
    local coords = data.coords or vector3(0, 0, 0)
    local route = (type(data) == "table" and rawget(data, "instance")) or 0
    local dzId = Inventory:CreateDropzone(route, coords)
    local items = data.items or {}
    for _, it in pairs(items) do
        Inventory:AddItem(dzId, it.name, it.count, it.metaData or {}, 10)
    end
    return tostring(dzId)
end

---@param data InvStashProps
function inv.createStash(data)
    lib.print.warn("prp-bridge mythic-inventory: createStash — configure stashes in mythic-inventory entity types; use giveItem to stock if needed.")
    if not data or not data.id then
        return
    end
    for _, item in pairs(data.items or {}) do
        inv.giveItem(data.id, item.name, item.count, item.metaData or {})
    end
end

---@param cb fun(payload: InvSwapHookPayload):boolean
---@param options? InvHookOptions
---@return number hookId
function inv.registerSwapItemsHook(cb, options)
    lib.print.warn("prp-bridge mythic-inventory: registerSwapItemsHook is not supported.")
    return 0
end

---@param cb fun(payload: InvCreateItemHookPayload):boolean
---@param options? table
---@return number hookId
function inv.registerCreateItemHook(cb, options)
    return 0
end

---@param hookId number
function inv.removeHooks(hookId) end

---@param inventoryId string
---@param keep? string | table<string>
function inv.clearInventory(inventoryId, keep)
    local owner, invType = resolveInventory(inventoryId)
    if not owner or not invType then
        return
    end
    local name = ("%s-%s"):format(owner, invType)
    if type(keep) == "string" then
        keep = { [keep] = true }
    end
    if keep and type(keep) == "table" then
        local rows = MySQL.query.await("SELECT item_id FROM inventory WHERE name = ?", { name }) or {}
        for _, row in ipairs(rows) do
            local itemId = row.item_id or row.Name
            if itemId and not keep[itemId] then
                MySQL.query.await("DELETE FROM inventory WHERE name = ? AND item_id = ?", { name, itemId })
            end
        end
        return
    end
    MySQL.query.await("DELETE FROM inventory WHERE name = ?", { name })
end

---@param src number | string
---@param inventoryId string|number
function inv.openStash(src, inventoryId)
    local Inventory = mythic()
    if not Inventory or not Inventory.OpenSecondary then
        return
    end
    local owner, invType = resolveInventory(inventoryId)
    if owner and invType then
        Inventory:OpenSecondary(tonumber(src), invType, owner, false, false, false, nil, nil, nil)
    end
end

---@param src number | string
---@param inventoryId string|number
function inv.forceOpenStash(src, inventoryId)
    inv.openStash(src, inventoryId)
end

---@param inventoryId string|number
---@param itemName string
---@param count number
---@param metadata table|nil
---@return boolean, InvGiveItemResp
function inv.giveItem(inventoryId, itemName, count, metadata)
    local Inventory = mythic()
    if not Inventory or not Inventory.AddItem then
        return false, {}
    end
    local owner, invType = resolveInventory(inventoryId)
    if not owner or not invType then
        return false, {}
    end
    local ok = Inventory:AddItem(owner, itemName, count, metadata or {}, invType)
    return ok == true or ok ~= nil and ok ~= false, {}
end

---@param inventoryId string|number
---@param itemName string
---@param count number
---@param metadata table|nil
---@param slot number|nil
---@return boolean, InvRemoveItemResp
function inv.removeItem(inventoryId, itemName, count, metadata, slot)
    local Inventory = mythic()
    if not Inventory or not Inventory.RemoveSlot then
        return false, {}
    end
    local owner, invType = resolveInventory(inventoryId)
    if not owner or not invType then
        return false, {}
    end
    if not slot then
        lib.print.warn("prp-bridge mythic-inventory: removeItem without slot — use slot when possible.")
        return false, {}
    end
    local ok = Inventory:RemoveSlot(owner, itemName, count, slot, invType)
    return ok == true, {}
end

---@param itemName string
---@return string|nil
function inv.getItemLabel(itemName)
    local data = inv.getItemData(itemName)
    return data and (data.label or data.name) or nil
end

---@param itemName string
---@return table|nil
function inv.getItemData(itemName)
    local Inventory = mythic()
    if not Inventory or not Inventory.GetItemsDatabase then
        return nil
    end
    local list = Inventory:GetItemsDatabase()
    for _, it in ipairs(list) do
        if it.name == itemName then
            return it
        end
    end
    return nil
end

---@param prefix string
---@param items table<{ name: string, count: number, metaData: table? }>
---@param coords vector3
---@param slots number?
---@param maxWeight number?
---@param instance string|number|nil
---@param model number?
function inv.createCustomDrop(prefix, items, coords, slots, maxWeight, instance, model)
    return inv.createTemporaryStash({
        label = prefix or "drop",
        coords = coords,
        items = items,
        instance = instance,
        slots = slots,
        maxWeight = maxWeight,
    })
end

local playerInventories = {}

---@param src number | string
---@param loadout table<{ name: string, count: number, metaData: table? }>
---@param excludedItems table<string, boolean>
function inv.giveLoadoutItems(src, loadout, excludedItems)
    local identifier = bridge.fw.getIdentifier(src)
    if not identifier then
        return
    end
    local current = inv.getInventoryItems(src)
    local saved = {}
    for _, item in pairs(current) do
        if not excludedItems[item.name] then
            inv.removeItem(src, item.name, item.count, item.metaData, item.slot)
            saved[#saved + 1] = item
        end
    end
    playerInventories[identifier] = saved
    for _, item in pairs(loadout) do
        inv.giveItem(src, item.name, item.count, item.metaData)
    end
end

---@param src number | string
---@param loadout table<{ name: string, count: number, metaData: table? }>
function inv.returnItems(src, loadout)
    local identifier = bridge.fw.getIdentifier(src)
    if not identifier then
        return
    end
    local stored = playerInventories[identifier]
    if not stored then
        return
    end
    for _, item in pairs(loadout) do
        inv.removeItem(src, item.name, item.count, nil, item.slot)
    end
    for _, item in pairs(stored) do
        inv.giveItem(src, item.name, item.count, item.metaData)
    end
    playerInventories[identifier] = nil
end

---@param inventoryId string|number
---@param lookFor string[] | string
---@return number | table<string, number>
function inv.count(inventoryId, lookFor)
    local Inventory = mythic()
    local owner, invType = resolveInventory(inventoryId)
    if not Inventory or not owner or not invType or not Inventory.Items or not Inventory.Items.GetCounts then
        return 0
    end
    local counts = Inventory.Items:GetCounts(owner, invType)
    if type(lookFor) == "string" then
        return counts[lookFor] or 0
    end
    local out = {}
    for _, name in ipairs(lookFor) do
        out[name] = counts[name] or 0
    end
    return out
end

---@param inventoryId string|number
---@param item string
---@param amount number
---@return boolean
function inv.hasItem(inventoryId, item, amount)
    return inv.count(inventoryId, item) >= (amount or 1)
end

---@param inventoryId string|number
---@param slot number
---@return { weight: number, name: string, metadata: table?, count: number, slot: number } | nil
function inv.getSlot(inventoryId, slot)
    local items = inv.getInventoryItems(inventoryId)
    for _, it in ipairs(items) do
        if it.slot == slot then
            return {
                weight = 0,
                name = it.name,
                metadata = it.metaData,
                metaData = it.metaData,
                count = it.count,
                slot = it.slot,
            }
        end
    end
    return nil
end

---@param inventoryId string|number
---@param slot number
---@return number|nil
function inv.getItemDurability(inventoryId, slot)
    local meta = inv.getItemMetaData(inventoryId, slot)
    if not meta then
        return nil
    end
    return meta.durability
end

---@param inventoryId string|number
---@param slot number
---@return table | nil
function inv.getItemMetaData(inventoryId, slot)
    local it = inv.getSlot(inventoryId, slot)
    return it and it.metadata or nil
end

---@param inventoryId string|number
---@param slot number
---@param metaData table
---@return boolean
function inv.setItemMetaData(inventoryId, slot, metaData)
    local Inventory = mythic()
    local owner, invType = resolveInventory(inventoryId)
    if not Inventory or not owner or not invType or not Inventory.GetSlot or not Inventory.Items or not Inventory.Items.UpdateMetaData then
        return false
    end
    local item = Inventory:GetSlot(owner, slot, invType)
    if not item or not item.id then
        return false
    end
    Inventory.Items:UpdateMetaData(item.id, metaData)
    return true
end

---@param inventoryId string|number
---@param slot number
---@param key string
---@param value any
---@return boolean
function inv.setItemMetaDataKey(inventoryId, slot, key, value)
    local meta = inv.getItemMetaData(inventoryId, slot) or {}
    meta[key] = value
    return inv.setItemMetaData(inventoryId, slot, meta)
end

---@param inventoryId string|number
---@param slot number
---@param metaData table<string, any>
---@return boolean
function inv.setItemMetaDatasByKey(inventoryId, slot, metaData)
    local meta = inv.getItemMetaData(inventoryId, slot) or {}
    for k, v in pairs(metaData) do
        meta[k] = v
    end
    return inv.setItemMetaData(inventoryId, slot, meta)
end

---@param inventoryId string|number
---@param lookFor string[] | string
---@return InvSearchItem[]
function inv.searchInventory(inventoryId, lookFor)
    local items = inv.getInventoryItems(inventoryId)
    local names = type(lookFor) == "string" and { lookFor } or lookFor
    local set = {}
    for _, n in ipairs(names) do
        set[n] = true
    end
    local out = {}
    for _, it in ipairs(items) do
        if set[it.name] then
            out[#out + 1] = it
        end
    end
    return out
end

---@param shopId string
---@param shopData InvShopData
function inv.registerShop(shopId, shopData)
    lib.print.warn("prp-bridge mythic-inventory: registerShop — shops are configured in mythic-inventory; use bridge.inv.openShop on client.")
end

---@param inventoryId string | number
---@param item string
---@param count number
---@param metaData table?
---@return boolean
function inv.canCarryItem(inventoryId, item, count, metaData)
    local Inventory = mythic()
    local owner, invType = resolveInventory(inventoryId)
    if not Inventory or not owner or not invType or not Inventory.Items or not Inventory.Items.GetWeights then
        return false
    end
    local data = inv.getItemData(item)
    if not data or not data.weight then
        return true
    end
    local cap = 100000
    local w = Inventory.Items:GetWeights(owner, invType)
    return (w + count * data.weight) <= cap
end

---@param vehType InvVehStashType
---@param plate string
---@return boolean
function inv.vehInvHasItems(vehType, plate)
    lib.print.warn("prp-bridge mythic-inventory: vehInvHasItems not implemented (plate-based lookup varies by server).")
    return false
end

---@param itemName string
---@return string
function inv.getItemImageUrl(itemName)
    return ("https://cfx-nui-mythic-inventory/ui/images/%s.png"):format(itemName)
end

---@param src? number
---@return table<string, table>
function inv.getRegisteredItems(src)
    local Inventory = mythic()
    if not Inventory or not Inventory.GetItemsDatabase then
        return {}
    end
    local list = Inventory:GetItemsDatabase()
    local map = {}
    for _, it in ipairs(list) do
        map[it.name] = it
    end
    return map
end

if bridge.name == bridge.currentResource then
    lib.callback.register("prp-bridge:mythicInv:getPlayerItems", function(pSource)
        return inv.getInventoryItems(pSource)
    end)
end

return inv
