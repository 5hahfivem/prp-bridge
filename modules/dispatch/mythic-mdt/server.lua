local dispatch = {}

---@return table|nil
local function callbacks()
    return exports["mythic-base"]:FetchComponent("Callbacks")
end

---@return table|nil
local function emergencyAlerts()
    return exports["mythic-base"]:FetchComponent("EmergencyAlerts")
end

---@param jobs string[]
---@return number typeIndex 1 = police, 2 = EMS, 3 = tow
local function jobsToAlertType(jobs)
    for _, j in ipairs(jobs) do
        local lower = string.lower(j)
        if lower:find("ems") or lower:find("ambulance") or lower == "medic" then
            return 2
        end
        if lower:find("tow") then
            return 3
        end
    end
    return 1
end

---@param src number | string
---@param coords vector3
---@param jobs string[]
---@param data AlertData
---@param blip AlertBlip
---@param alertFlash? boolean
function dispatch.sendAlert(src, jobs, coords, data, blip, alertFlash)
    local EA = emergencyAlerts()
    local CB = callbacks()
    if not EA or not EA.Create or not CB or not CB.ClientCallback then
        lib.print.error("prp-bridge mythic-mdt: EmergencyAlerts or Callbacks not available (start mythic-mdt / mythic-base).")
        return
    end

    local alertType = jobsToAlertType(jobs or { "police" })
    local code = data.code or "10-31"
    local title = data.title or data.description or "Alert"
    local description = data.description or ""
    ---@type boolean|table
    local blipPayload = false
    if blip then
        blipPayload = {
            icon = blip.sprite or 66,
            size = blip.scale or 0.9,
            color = blip.colour or 30,
            duration = (blip.length or 5) * 60,
            flashing = blip.flash or false,
        }
    end

    CB:ClientCallback(tonumber(src), "EmergencyAlerts:GetStreetName", coords, function(location)
        if not location then
            return
        end
        EA:Create(
            code,
            title,
            alertType,
            location,
            description,
            alertFlash or false,
            blipPayload,
            nil,
            false,
            false,
            false
        )
    end)
end

return dispatch
