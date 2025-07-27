local QBCore = exports['qb-core']:GetCoreObject()
local inOnlineBizMenu = false

-- ✅ Whitelist valid businesses add here if u added more in config thats it.
local validBusinesses = {
    ["toottalk"] = true,
    ["quickcart"] = true,
    ["memecoin"] = true,
    
}



local function SendUI(action, data)
    data = data or {}
    data.action = action
    SendNUIMessage(data)
end

-- using the bizlaptop to open menu < u have to add it to ur inventory.
RegisterNetEvent("drago-onlinebiz:useLaptop", function()
    if inOnlineBizMenu then return end
    inOnlineBizMenu = true

    SetNuiFocus(true, true)


    QBCore.Functions.TriggerCallback("drago-onlinebiz:getData", function(businesses)
        SendUI("openMenu", {
            businesses = businesses
        })
    end)
end)


RegisterNUICallback("collectIncome", function(_, cb)
    TriggerServerEvent("drago-onlinebiz:collectIncome")
    cb(true)
end)


RegisterNUICallback("buyBusiness", function(data, cb)
    if type(data) ~= "table" or not data.name or not validBusinesses[data.name] then
        cb(false)
        return
    end

    TriggerServerEvent("drago-onlinebiz:buyBusiness", data.name)
    cb(true)
end)


RegisterNUICallback("upgradeBusiness", function(data, cb)
    if type(data) ~= "table" or not data.name or not validBusinesses[data.name] then
        cb(false)
        return
    end

    TriggerServerEvent("drago-onlinebiz:upgradeBusiness", data.name)
    cb(true)
end)


RegisterNetEvent('drago-onlinebiz:client:updateBusiness')
AddEventHandler('drago-onlinebiz:client:updateBusiness', function(bizKey, bizData)
   
    SendUI('updateBusiness', { key = bizKey, data = bizData })
end)

RegisterNUICallback("close", function(_, cb)
    print("[DEBUG] Close callback triggered")
    if not inOnlineBizMenu then cb(true) return end

    SetNuiFocus(false, false)
    SendUI("closeMenu") 
    inOnlineBizMenu = false
    cb(true)
end)

-- this is also handled in server because im personally using qb-multicharacter with multiple characters
RegisterNetEvent("QBCore:Client:OnPlayerLoaded", function()
    Wait(1000) 
    TriggerServerEvent("drago-onlinebiz:checkOfflineIncome")
end)


RegisterNUICallback("refreshBusiness", function(data, cb)
    if type(data) ~= "table" or not data.bizKey or not validBusinesses[data.bizKey] then
        cb({ success = false })
        return
    end

    TriggerServerEvent("drago-onlinebiz:refreshBusiness", data.bizKey)
    cb({ success = true })
end)