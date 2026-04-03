local fw = {}

---@return table|nil
local function hud(name)
    return exports["mythic-base"]:FetchComponent(name)
end

local textUiOpen = false

---@return table|nil
local function character()
    return LocalPlayer.state.Character
end
---@return table|nil
local function status()
    return exports["mythic-base"]:FetchComponent("Status")
end

---@param key string
---@return number|nil
local function statusValue(key)
    local Status = status()
    if not Status or not Status.Get or not Status.Get.Single then
        return nil
    end
    local ok, entry = pcall(function()
        return Status.Get:Single(key)
    end)
    if ok and entry and entry.value ~= nil then
        return tonumber(entry.value)
    end
    return nil
end

---@param key string
---@param value number
local function statusSetSingle(key, value)
    local Status = status()
    if not Status or not Status.Set or not Status.Set.Single then
        return
    end
    local ok = pcall(function()
        Status.Set:Single(key, value)
    end)
    if not ok then
        return
    end
    TriggerEvent("Status:Client:Update", key, value)
    TriggerServerEvent("Status:Server:Update", { status = key, value = value })
end

---@return number
function fw.getStress()
    local v = statusValue("PLAYER_STRESS")
    if v ~= nil then
        return v
    end
    local s = LocalPlayer.state["status:PLAYER_STRESS"]
    if s ~= nil then
        return tonumber(s) or 0
    end
    return LocalPlayer.state.stress or 0
end

---@return number
function fw.getHunger()
    local v = statusValue("PLAYER_HUNGER")
    if v ~= nil then
        return v
    end
    return LocalPlayer.state.hunger or 100
end

---@return number
function fw.getThirst()
    local v = statusValue("PLAYER_THIRST")
    if v ~= nil then
        return v
    end
    return LocalPlayer.state.thirst or 100
end

---@param statusType string
---@param value number
function fw.setStatus(statusType, value)
    if statusType == "hunger" then
        statusSetSingle("PLAYER_HUNGER", value)
        return
    end
    if statusType == "thirst" then
        statusSetSingle("PLAYER_THIRST", value)
        return
    end
    if statusType == "stress" then
        statusSetSingle("PLAYER_STRESS", value)
        return
    end
end

function fw.applyBuff(buff, data) end

function fw.clearBuffs() end

---@param type 'inform' | 'error' | 'success'| 'warning'
---@param message string
---@param title? string
---@param duration? number
function fw.notify(type, message, title, duration)
    local Notification = hud("Notification")
    local dur = duration or 3000
    local text = message or ""
    if title and title ~= "" then
        text = ("%s\n%s"):format(title, text)
    end

    if Notification then
        local t = type or "inform"
        if t == "success" then
            Notification:Success(text, dur)
        elseif t == "error" then
            Notification:Error(text, dur)
        elseif t == "warning" then
            Notification:Warn(text, dur)
        elseif t == "inform" then
            Notification:Info(text, dur)
        else
            Notification:Standard(text, dur)
        end
        return
    end

    lib.notify({
        type = type or "inform",
        title = title or nil,
        description = message or "",
        duration = dur,
    })
end

---@param text string
---@param options? { position?: ShowTextUIPos, icon?: string | table<string>, iconColor?: string, iconAnimation?: ShowTextUIAnims, alignIcon?: "top" | "center" }
function fw.showTextUI(text, options)
    local Action = hud("Action")
    if Action and Action.Show then
        textUiOpen = true
        Action:Show(text, nil)
        return
    end
    lib.showTextUI(text, options)
end

function fw.hideTextUI()
    local Action = hud("Action")
    if Action and Action.Hide then
        textUiOpen = false
        Action:Hide()
        return
    end
    lib.hideTextUI()
end

---@return boolean
---@return string | nil
function fw.isTextUIOpen()
    local Action = hud("Action")
    if Action and Action.Hide then
        return textUiOpen, nil
    end
    return lib.isTextUIOpen()
end

---@param payload FWProgressBar
---@return boolean?
function fw.progressBar(payload)
    local Progress = hud("Progress")
    if not Progress or not Progress.Progress then
        local options = {
            duration = payload.duration or 5000,
            label = payload.label,
            useWhileDead = false,
            allowRagdoll = payload.allowRagdoll or false,
            allowSwimming = payload.allowSwimming or false,
            allowCuffed = payload.allowCuffed or false,
            allowFalling = payload.allowFalling or false,
            canCancel = payload.canCancel or false,
            disable = {},
        }
        if payload.controlDisables then
            if payload.controlDisables.disableMovement then
                options.disable.move = true
            end
            if payload.controlDisables.disableCarMovement then
                options.disable.car = true
            end
            if payload.controlDisables.disableMouse then
                options.disable.mouse = true
            end
            if payload.controlDisables.disableCombat then
                options.disable.combat = true
            end
            if payload.controlDisables.disableSprint then
                options.disable.sprint = true
            end
        end
        if payload.animation and payload.animation.animDict and payload.animation.animClip then
            options.anim = {
                dict = payload.animation.animDict,
                clip = payload.animation.animClip,
            }
            if payload.animation.animFlag then
                options.anim.flag = payload.animation.animFlag
            end
        elseif payload.animation and payload.animation.scenario then
            options.anim = { scenario = payload.animation.scenario }
        end
        return lib.progressBar(options)
    end

    local cd = payload.controlDisables
    local action = {
        name = "prp-bridge",
        duration = payload.duration or 5000,
        label = payload.label or "",
        useWhileDead = payload.useWhileDead == true,
        canCancel = payload.canCancel ~= false,
        ignoreModifier = false,
        disarm = true,
        vehicle = payload.vehicle,
        controlDisables = {
            disableMovement = cd and cd.disableMovement or false,
            disableCarMovement = cd and cd.disableCarMovement or false,
            disableMouse = cd and cd.disableMouse or false,
            disableCombat = cd and cd.disableCombat or false,
        },
    }

    if payload.animation and payload.animation.animDict and payload.animation.animClip then
        action.animation = {
            animDict = payload.animation.animDict,
            anim = payload.animation.animClip,
            flags = payload.animation.animFlag or 1,
        }
    elseif payload.animation and payload.animation.scenario then
        action.animation = {
            task = payload.animation.scenario,
        }
    end

    local p = promise.new()
    Progress:Progress(action, function(wasCancelled)
        p:resolve(not wasCancelled)
    end)
    return Citizen.Await(p)
end

---@param header string
---@param content string
---@param labels? {cancel?: string, confirm?: string}
---@param timeout? number Force the window to timeout after `x` milliseconds.
---@return 'cancel'|'confirm'|nil
function fw.confirmDialog(header, content, labels, timeout)
    local Confirm = hud("Confirm")
    if not Confirm or not Confirm.Show then
        return lib.alertDialog({
            header = header,
            content = content,
            centered = true,
            cancel = true,
            labels = labels or { cancel = locale("Cancel"), confirm = locale("Confirm") },
        }, timeout)
    end

    local p = promise.new()
    local token = ("%s-%s"):format(GetGameTimer(), math.random(100000, 999999))
    local yesEv = ("prp-bridge:confirm:%s:yes"):format(token)
    local noEv = ("prp-bridge:confirm:%s:no"):format(token)
    local resolved = false

    local function finish(value)
        if resolved then
            return
        end
        resolved = true
        Confirm:Close()
        p:resolve(value)
    end

    AddEventHandler(yesEv, function()
        finish("confirm")
    end)
    AddEventHandler(noEv, function()
        finish("cancel")
    end)

    Confirm:Show(
        header,
        { yes = yesEv, no = noEv },
        content,
        {},
        labels and labels.cancel,
        labels and labels.confirm
    )

    if timeout then
        SetTimeout(timeout, function()
            finish(nil)
        end)
    end

    return Citizen.Await(p)
end

---@param heading string
---@param rows string[] | InputDialogRowProps[]
---@param options InputDialogOptionsProps[]?
---@return string[] | number[] | boolean[] | nil
function fw.inputDialog(heading, rows, options)
    return lib.inputDialog(heading, rows, options)
end

---@param payload FWContextMenuProps | FWContextMenuProps[]
function fw.contextMenu(payload)
    lib.registerContext(payload)
end

---@param contextId string
function fw.showContext(contextId)
    lib.showContext(contextId)
end

---@return boolean
function fw.isOnDuty()
    local onDuty = LocalPlayer.state.onDuty
    return onDuty ~= nil and onDuty ~= false
end

---@param job string
---@param grade number? do they require a minimum grade
---@param duty boolean? do they need to be on duty
---@return boolean
function fw.hasJob(job, grade, duty)
    local char = character()
    if not char then
        return false
    end
    local jobs = char:GetData("Jobs") or {}
    local found ---@type table|nil
    for _, j in ipairs(jobs) do
        if j.Id == job then
            found = j
            break
        end
    end
    if not found then
        return false
    end
    if grade and (found.GradeLevel or 0) < grade then
        return false
    end
    if duty then
        return LocalPlayer.state.onDuty == job
    end
    return true
end

---@return string?
function fw.getIdentifier()
    local char = character()
    if not char then
        return nil
    end
    local sid = char:GetData("SID")
    return sid ~= nil and tostring(sid) or nil
end

---@return string?
function fw.getCharacterName()
    local char = character()
    if not char then
        return nil
    end
    local first = char:GetData("First") or ""
    local last = char:GetData("Last") or ""
    local name = ("%s %s"):format(first, last)
    name = name:gsub("^%s+", ""):gsub("%s+$", "")
    return name ~= "" and name or nil
end

if bridge.name == bridge.currentResource then
    RegisterNetEvent("Characters:Client:Spawned", function()
        TriggerEvent("prp-bridge:client:playerLoad")
    end)

    RegisterNetEvent("Characters:Client:Logout", function()
        TriggerEvent("prp-bridge:client:playerUnload")
    end)
end

return fw
