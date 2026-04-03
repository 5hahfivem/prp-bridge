local inv = {}

---@return table|nil
local function inventory()
    return exports["mythic-base"]:FetchComponent("Inventory")
end

---@param item string
---@param count number
---@return boolean
function inv.hasItem(item, count)
    local Inventory = inventory()
    if Inventory and Inventory.Check and Inventory.Check.Player and Inventory.Check.Player.HasItem then
        return Inventory.Check.Player:HasItem(item, count or 1)
    end
    return false
end

---@param itemName string
---@param minDurabilityAmount number | nil
---@return number | nil
function inv.findItemSlot(itemName, minDurabilityAmount)
    local items = inv.getAllItems()
    for _, it in ipairs(items) do
        if it.name == itemName then
            if minDurabilityAmount and it.metaData and it.metaData.durability and it.metaData.durability < minDurabilityAmount then
                goto continue
            end
            return it.slot
        end
        ::continue::
    end
    return nil
end

---@param itemName string
---@param metadata table|nil
---@return table | nil
function inv.getSlotWithItem(itemName, metadata)
    local items = inv.getAllItems()
    for _, it in ipairs(items) do
        if it.name == itemName then
            if not metadata then
                return { name = it.name, count = it.count, metadata = it.metaData, slot = it.slot }
            end
            local match = true
            for k, v in pairs(metadata) do
                if not it.metaData or it.metaData[k] ~= v then
                    match = false
                    break
                end
            end
            if match then
                return { name = it.name, count = it.count, metadata = it.metaData, slot = it.slot }
            end
        end
    end
    return nil
end

---@param data table<string, string>
function inv.registerDisplayMetaData(data)
    lib.print.warn("prp-bridge mythic-inventory: registerDisplayMetaData — use mythic-inventory item definitions.")
end

---@param name string
function inv.openShop(name)
    local Inventory = inventory()
    if Inventory and Inventory.Shop and Inventory.Shop.Open then
        Inventory.Shop:Open(name)
    end
end

---@return table<{ name: string, count: number, metadata: table?, slot: number }>
function inv.getAllItems()
    local ok, items = pcall(function()
        return lib.callback.await("prp-bridge:mythicInv:getPlayerItems", false)
    end)
    if not ok or not items then
        return {}
    end
    local out = {}
    for _, it in ipairs(items) do
        out[#out + 1] = {
            name = it.name,
            count = it.count,
            metadata = it.metaData,
            slot = it.slot,
        }
    end
    return out
end

---@param itemName string
---@return number
function inv.getItemCount(itemName)
    local Inventory = inventory()
    if Inventory and Inventory.Items and Inventory.Items.GetCount then
        return Inventory.Items:GetCount(itemName) or 0
    end
    return 0
end

---@param itemName string
---@return string
function inv.getItemImageUrl(itemName)
    return ("https://cfx-nui-mythic-inventory/ui/images/%s.png"):format(itemName)
end

function inv.disarm()
    TriggerEvent("Weapons:Client:ForceUnequip")
end

return inv
