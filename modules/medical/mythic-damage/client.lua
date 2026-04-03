local medical = {}

---@param serverId number
---@return boolean
function medical.isPlayerDead(serverId)
    local st = Player(serverId).state
    return st and (st.isDead == true or st.isHospitalized == true) or false
end

---@param value number
function medical.overrideMaxHealth(value) end

return medical
