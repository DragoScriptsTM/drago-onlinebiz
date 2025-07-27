local QBCore = exports['qb-core']:GetCoreObject()
local PlayerBusinesses = {}
local hasPaidOfflineIncome = {}
local lastPayoutTime = {} -- [citizenid] = timestamp
Config = Config or {}
local lastCollectTime = {}


-- Load from DB
local function loadPlayerBusinessesAsync(identifier, cb)
    MySQL.Async.fetchAll('SELECT * FROM player_online_businesses WHERE identifier = ?', {identifier}, function(result)
        local businesses = {}
        for bizName, config in pairs(Config.Businesses) do
            businesses[bizName] = {
                level = 0,
                balance = 0,
                last_income_timestamp = 0,
                upgrade_ready_at = 0, 
            }
        end
        for _, row in ipairs(result) do
            if businesses[row.business_key] then
                businesses[row.business_key].level = row.level
                businesses[row.business_key].balance = tonumber(row.balance) or 0
                businesses[row.business_key].last_income_timestamp = tonumber(row.last_income_timestamp) or 0
                businesses[row.business_key].upgrade_ready_at = tonumber(row.upgrade_ready_at) or 0
            end
        end
        cb(businesses)
    end)
end


-- Save to DB
local function savePlayerBusiness(identifier, bizName, data)
    MySQL.Async.execute([[ 
        INSERT INTO player_online_businesses (identifier, business_key, level, balance, last_income_timestamp, upgrade_ready_at)
        VALUES (?, ?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE 
            level = VALUES(level), 
            balance = VALUES(balance), 
            last_income_timestamp = VALUES(last_income_timestamp),
            upgrade_ready_at = VALUES(upgrade_ready_at)
    ]], {
        identifier, 
        bizName, 
        data.level, 
        data.balance, 
        data.last_income_timestamp,
        data.upgrade_ready_at or 0
    })
end


QBCore.Functions.CreateCallback('drago-onlinebiz:getData', function(source, cb)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then cb({}) return end
    local identifier = Player.PlayerData.citizenid

    
    local function enrichBusinesses(businesses)
        for bizKey, bizData in pairs(businesses) do
            local config = Config.Businesses[bizKey]
            if config then
                local isOwned = bizData.level > 0
                bizData.owned = isOwned
                bizData.maxLevel = config.maxLevel

                if isOwned then
                    bizData.price = nil
                    local upgradeLevel = bizData.level
                    bizData.upgradeCost = math.floor(config.baseCost * (config.upgradeMultiplier ^ upgradeLevel))
                else
                    bizData.price = config.baseCost
                    bizData.upgradeCost = nil
                end
            end
        end
        return businesses
    end

    if not PlayerBusinesses[source] then
        loadPlayerBusinessesAsync(identifier, function(businesses)
            PlayerBusinesses[source] = enrichBusinesses(businesses)
            cb(PlayerBusinesses[source])
        end)
    else
        cb(enrichBusinesses(PlayerBusinesses[source]))
    end
end)


CreateThread(function()
    while true do
        Wait((Config.IncomeInterval or 60) * 1000)
        local now = os.time()
        for src, businesses in pairs(PlayerBusinesses) do
            local Player = QBCore.Functions.GetPlayer(src)
            if Player then
                local identifier = Player.PlayerData.citizenid
                for bizName, bizData in pairs(businesses) do
                    local config = Config.Businesses[bizName]
                    if config and bizData.level > 0 then
                        
                        local effectiveLevel = bizData.level
                        if bizData.upgrade_ready_at and bizData.upgrade_ready_at > now then
                            effectiveLevel = effectiveLevel - 1
                        end
                        if effectiveLevel < 1 then effectiveLevel = 1 end

                        
                        local income = math.floor(config.baseIncome * effectiveLevel)
                        bizData.balance = bizData.balance + income
                        bizData.last_income_timestamp = now
                        savePlayerBusiness(identifier, bizName, bizData)
                    end
                end
            end
        end
    end
end)





local function PayOfflineIncome(src)
    if hasPaidOfflineIncome[src] then
        print("[DEBUG] PayOfflineIncome: Al betaald voor src=" .. tostring(src))
        return
    end

    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local identifier = Player.PlayerData.citizenid
    local businesses = PlayerBusinesses[src]
    if not businesses then return end

    local now = os.time()

    for bizName, bizData in pairs(businesses) do
        local config = Config.Businesses[bizName]
        if config and bizData.level > 0 and bizData.last_income_timestamp then
            if bizData.last_income_timestamp == 0 then
                print("⏱ No timestamp for", bizName, "- stel nu in op", now)
                bizData.last_income_timestamp = now
                savePlayerBusiness(identifier, bizName, bizData)
                goto continue
            end

            local maxElapsed = 86400 -- max 24 hour of income saved up if player doesnt come online (seconds)
            local elapsed = math.min(now - bizData.last_income_timestamp, maxElapsed)
            local incomePerSecond = (config.baseIncome * bizData.level) / (Config.IncomeInterval or 60)
            local incomeToAdd = math.floor(incomePerSecond * elapsed)

            print(("💼 %s: %ss offline → $%s"):format(bizName, elapsed, incomeToAdd))

            if incomeToAdd > 0 then
                bizData.balance = bizData.balance + incomeToAdd
                bizData.last_income_timestamp = now
                savePlayerBusiness(identifier, bizName, bizData)
            end
        end
        ::continue::
    end

    TriggerClientEvent("drago-onlinebiz:updateBusiness", src, businesses)

    
    hasPaidOfflineIncome[src] = true
end



AddEventHandler('playerDropped', function(reason)
    local src = source
    hasPaidOfflineIncome[src] = nil
    
end)


RegisterNetEvent('drago-onlinebiz:collectIncome', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    local identifier = Player.PlayerData.citizenid

    
    local cooldown = Config.CollectCooldown or 60   --<< collect cooldown to prevent spam
    local now = os.time()
    if lastCollectTime[src] and now - lastCollectTime[src] < cooldown then
        local timeLeft = cooldown - (now - lastCollectTime[src])
        TriggerClientEvent('QBCore:Notify', src, "⏳ Wait another " .. timeLeft .. "s before you can collect again.", "error")
        return
    end
    lastCollectTime[src] = now

    local totalCollected = 0
    if PlayerBusinesses[src] then
        for bizName, bizData in pairs(PlayerBusinesses[src]) do
            totalCollected += bizData.balance
            bizData.balance = 0
            savePlayerBusiness(identifier, bizName, bizData)
            TriggerClientEvent('drago-onlinebiz:client:updateBusiness', src, bizName, bizData)
        end
    end

    if totalCollected > 0 then
        Player.Functions.AddMoney("bank", totalCollected, "online bedrijfsinkomsten")
        TriggerClientEvent('QBCore:Notify', src, "\u{1F4B0} You collected $"..totalCollected.." total", "success")
    else
        TriggerClientEvent('QBCore:Notify', src, "\u{1F4ED} Nothing to collect.", "error")
    end
end)

RegisterNetEvent('drago-onlinebiz:buyBusiness', function(bizKey)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    local identifier = Player.PlayerData.citizenid

    local business = Config.Businesses[bizKey]
    if not business then return end
    local businesses = PlayerBusinesses[src]
    if not businesses then return end
    local playerBiz = businesses[bizKey]
    if not playerBiz then return end

    if playerBiz.level > 0 then
        TriggerClientEvent('QBCore:Notify', src, "You already own this company", "error")
        return
    end

    local price = business.baseCost
    if Player.Functions.RemoveMoney("bank", price) then
        playerBiz.level = 1
        playerBiz.balance = 0
        playerBiz.last_income_timestamp = os.time()
        playerBiz.upgrade_ready_at = nil

        playerBiz.upgradeCost = math.floor(business.baseCost * (business.upgradeMultiplier ^ playerBiz.level))

        savePlayerBusiness(identifier, bizKey, playerBiz)

        
        TriggerClientEvent('drago-onlinebiz:client:updateBusiness', src, bizKey, playerBiz)

        TriggerClientEvent('QBCore:Notify', src, "\u{1F389} You bought "..business.label.." !", "success")
    else
        TriggerClientEvent('QBCore:Notify', src, "Not enough money brokey", "error")
    end
end)


RegisterNetEvent('drago-onlinebiz:upgradeBusiness', function(bizKey)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    local identifier = Player.PlayerData.citizenid
    local now = os.time()

    local business = Config.Businesses[bizKey]
    if not business then return end

    local businesses = PlayerBusinesses[src]
    if not businesses then return end
    local playerBiz = businesses[bizKey]

    if not playerBiz or playerBiz.level <= 0 then
        TriggerClientEvent('QBCore:Notify', src, "You have to buy this company first", "error")
        return
    end

    
    if playerBiz.upgrade_ready_at and playerBiz.upgrade_ready_at > 0 and now >= playerBiz.upgrade_ready_at then
        if playerBiz.level < business.maxLevel then
            playerBiz.level = playerBiz.level + 1
        end
        playerBiz.upgrade_ready_at = nil

       
        if playerBiz.level < business.maxLevel then
            playerBiz.upgradeCost = math.floor(business.baseCost * (business.upgradeMultiplier ^ (playerBiz.level + 1)))
        else
            playerBiz.upgradeCost = nil
        end

        savePlayerBusiness(identifier, bizKey, playerBiz)
        TriggerClientEvent('drago-onlinebiz:client:updateBusiness', src, bizKey, playerBiz)
        TriggerClientEvent('QBCore:Notify', src, "✅ Upgrade completed for "..business.label.." (level "..playerBiz.level..")", "success")

       
        return
    end

    
    if playerBiz.upgrade_ready_at and playerBiz.upgrade_ready_at > now then
        local remaining = playerBiz.upgrade_ready_at - now
        local mins = math.floor(remaining / 60)
        local secs = remaining % 60
        TriggerClientEvent('QBCore:Notify', src, ("⏳ Upgrade in progress, please wait for %dm %ds"):format(mins, secs), "error")
        return
    end

    
    if playerBiz.level >= business.maxLevel then
        TriggerClientEvent('QBCore:Notify', src, "Maximum level reached!", "error")
        return
    end

    
    local price = math.floor(business.baseCost * (business.upgradeMultiplier ^ playerBiz.level))

    if Player.Functions.RemoveMoney("bank", price) then
        
        if business.upgradeTime and business.upgradeTime > 0 then
            playerBiz.upgrade_ready_at = now + business.upgradeTime
        else
            playerBiz.level = playerBiz.level + 1
            playerBiz.upgrade_ready_at = nil
        end

      
        if playerBiz.level < business.maxLevel then
            playerBiz.upgradeCost = math.floor(business.baseCost * (business.upgradeMultiplier ^ (playerBiz.level + 1)))
        else
            playerBiz.upgradeCost = nil
        end

        savePlayerBusiness(identifier, bizKey, playerBiz)
        TriggerClientEvent('drago-onlinebiz:client:updateBusiness', src, bizKey, playerBiz)

        if business.upgradeTime and business.upgradeTime > 0 then
            TriggerClientEvent('QBCore:Notify', src, "⏳ Upgrade started for "..business.label..", it will be done sone!", "success")
        else
            TriggerClientEvent('QBCore:Notify', src, "⬆️ "..business.label.." direct upgrade to "..playerBiz.level, "success")
        end
    else
        TriggerClientEvent('QBCore:Notify', src, "Not enough money to upgrade brokey.", "error")
    end
end)




AddEventHandler('playerDropped', function(reason)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if Player and PlayerBusinesses[src] then
        local identifier = Player.PlayerData.citizenid
        for bizName, bizData in pairs(PlayerBusinesses[src]) do
            savePlayerBusiness(identifier, bizName, bizData)
        end
        PlayerBusinesses[src] = nil
    end
end)


QBCore.Functions.CreateUseableItem("bizlaptop", function(source, item)
    TriggerClientEvent("drago-onlinebiz:useLaptop", source)
end)

local function enrichBusinesses(businesses)
    local now = os.time()

    for bizKey, bizData in pairs(businesses) do
        local config = Config.Businesses[bizKey]
        if config then
            
            bizData.label = config.label or bizKey
            bizData.description = config.description or "Geen beschrijving beschikbaar."
            bizData.image = config.image or "default.png"
            bizData.maxLevel = config.maxLevel or 5
            bizData.upgrade_duration = config.upgradeTime or 43200 -- Progress bar

            
            bizData.level = bizData.level or 0
            local isOwned = bizData.level > 0
            bizData.owned = isOwned

            -- Display level 
            if bizData.upgrade_ready_at and bizData.upgrade_ready_at > now then
                bizData.displayLevel = math.max(0, bizData.level - 1)
            else
                bizData.displayLevel = bizData.level
            end

            -- UpgradeCost
            if isOwned then
                bizData.price = nil
                local upgradeLevel = bizData.level
                bizData.upgradeCost = math.floor(config.baseCost * (config.upgradeMultiplier ^ upgradeLevel))
            else
                bizData.price = config.baseCost
                bizData.upgradeCost = nil
            end
        else
            print("⚠️ Geen config gevonden voor business:", bizKey)
        end
    end

    return businesses
end

-- this handles the data if you using qb-multicharacter, if u using something else please look how it loads player data en redirect it to that.
-- if you dont use qb-multicharacter and your character loads in directly check on client how its done i think that will work, try playing with the wait timer
RegisterNetEvent('qb-multicharacter:server:loadUserData')
AddEventHandler('qb-multicharacter:server:loadUserData', function(cData)
    local src = source

    
    local attempts = 0
    local Player = QBCore.Functions.GetPlayer(src)
    while not Player and attempts < 50 do
        Wait(100)
        attempts = attempts + 1
        Player = QBCore.Functions.GetPlayer(src)
    end

    if not Player then
        print("[DEBUG] loadUserData: No player found", src)
        return
    end

    local identifier = Player.PlayerData.citizenid
    print("[DEBUG] loadUserData: src=" .. tostring(src) .. " identifier=" .. tostring(identifier))

    loadPlayerBusinessesAsync(identifier, function(businesses)
        local enriched = enrichBusinesses(businesses)
        PlayerBusinesses[src] = enriched

        print("[DEBUG] loadUserData: Bedrijven geladen en verrijkt voor src=" .. tostring(src))
        for bizKey, bizData in pairs(enriched) do
            print(string.format("[DEBUG] Business: %s Level: %d Balance: %d LastIncomeTS: %d", 
                bizKey, bizData.level, bizData.balance, bizData.last_income_timestamp or 0))
        end

        
        print("[DEBUG] loadUserData: PayOfflineIncome called for src=" .. tostring(src))
        PayOfflineIncome(src)

        
        TriggerClientEvent("drago-onlinebiz:updateBusiness", src, enriched)
    end)
end)


RegisterNetEvent("drago-onlinebiz:checkOfflineIncome", function()
    local src = source
    PayOfflineIncome(src)
end)

-- 🔄 Refresh specifiek bedrijf (bijv. na upgrade)
RegisterNetEvent('drago-onlinebiz:refreshBusiness', function(bizKey)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    local identifier = Player.PlayerData.citizenid

    local businesses = PlayerBusinesses[src]
    if not businesses or not businesses[bizKey] then return end

    local bizData = businesses[bizKey]
    local config = Config.Businesses[bizKey]
    if not config then return end

    local now = os.time()

    
    if bizData.upgrade_ready_at and bizData.upgrade_ready_at > 0 and bizData.upgrade_ready_at <= now then
        if bizData.level < config.maxLevel then
            bizData.level = bizData.level + 1
        end
        bizData.upgrade_ready_at = nil

        if bizData.level < config.maxLevel then
            bizData.upgradeCost = math.floor(config.baseCost * (config.upgradeMultiplier ^ bizData.level))
        else
            bizData.upgradeCost = nil
        end

        
        savePlayerBusiness(identifier, bizKey, bizData)

        
        TriggerClientEvent('drago-onlinebiz:client:updateBusiness', src, bizKey, bizData)
        TriggerClientEvent('QBCore:Notify', src, ("✅ Upgrade completed for %s (level %d)"):format(config.label or bizKey, bizData.level), "success")
    else
        
        TriggerClientEvent('drago-onlinebiz:client:updateBusiness', src, bizKey, bizData)
    end
end)

CreateThread(function()
    while true do
        Wait(60000) -- 60 seconds

        local now = os.time()

        for src, businesses in pairs(PlayerBusinesses) do
            local Player = QBCore.Functions.GetPlayer(src)
            if Player then
                local identifier = Player.PlayerData.citizenid

                for bizKey, bizData in pairs(businesses) do
                    local config = Config.Businesses[bizKey]
                    if config and bizData.upgrade_ready_at and bizData.upgrade_ready_at > 0 and bizData.upgrade_ready_at <= now then
                        -- Upgrade uitvoeren als nog niet gedaan en level niet max
                        if bizData.level < config.maxLevel then
                            bizData.level = bizData.level + 1
                        end
                        bizData.upgrade_ready_at = nil

                        if bizData.level < config.maxLevel then
                            bizData.upgradeCost = math.floor(config.baseCost * (config.upgradeMultiplier ^ bizData.level))
                        else
                            bizData.upgradeCost = nil
                        end

                        savePlayerBusiness(identifier, bizKey, bizData)

                        TriggerClientEvent('drago-onlinebiz:client:updateBusiness', src, bizKey, bizData)
                        TriggerClientEvent('QBCore:Notify', src, ("✅ Upgrade completed for %s (level %d)"):format(config.label or bizKey, bizData.level), "success")
                    end
                end
            end
        end
    end
end)

