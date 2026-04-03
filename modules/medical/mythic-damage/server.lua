local medical = {}

---@param src number | string
---@param amount number
function medical.healPlayer(src, amount)
    TriggerClientEvent("Damage:Client:Heal", tonumber(src))
end

return medical
