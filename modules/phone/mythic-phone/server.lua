local phone = {}

---@return table|nil
local function fetch()
    return exports["mythic-base"]:FetchComponent("Fetch")
end

---@return table|nil
local function mythicPhone()
    return exports["mythic-base"]:FetchComponent("Phone")
end

---@return table|nil
local function database()
    return exports["mythic-base"]:FetchComponent("Database")
end

---@param src number
---@param from number
---@param message string
function phone.sendMessage(src, from, message)
    local Database = database()
    local Fetch = fetch()
    if not Database or not Fetch then
        return
    end
    local target = Fetch:Source(tonumber(src))
    if not target then
        return
    end
    local char = target:GetData("Character")
    if not char then
        return
    end
    local targetPhone = char:GetData("Phone")
    local time = os.time() * 1000
    local doc = {
        owner = targetPhone,
        number = from,
        message = message,
        time = time,
        method = 0,
        unread = true,
    }
    local doc2 = {
        owner = from,
        number = targetPhone,
        message = message,
        time = time + 1,
        method = 0,
        unread = true,
    }
    Database.Game:insert({
        collection = "phone_messages",
        documents = { doc, doc2 },
    }, function(success)
        if success then
            local n = tonumber(src)
            if n then
                TriggerClientEvent("Phone:Client:Messages:Notify", n, doc, false)
            end
        end
    end)
end

---@param src number
---@param from number
---@param coords vector3
function phone.sendCoords(src, from, coords)
    local text = string.format("Shared location: %.2f, %.2f, %.2f", coords.x, coords.y, coords.z)
    phone.sendMessage(src, from, text)
end

---@param src number
---@param title string
---@param content? string
function phone.sendNotification(src, title, content)
    local Phone = mythicPhone()
    if Phone and Phone.Notification and Phone.Notification.Add then
        Phone.Notification:Add(tonumber(src), title or "", content or "", os.time() * 1000, 6000, nil, false, false)
    end
end

return phone
