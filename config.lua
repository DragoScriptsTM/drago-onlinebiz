Config = {}

Config.Businesses = {
    ["toottalk"] = {
        label = "Social Media App",
        description = "Launch a social media app or steal a big idea.. either way ",
        baseCost = 1000,            -- Price to buy business
        baseIncome = 50,            -- Income each interval (look bottom settings)
        upgradeMultiplier = 2.1,    -- Each level costs 2.1x more
        maxLevel = 5,
        upgradeTime = 3600,        -- Upgrade time in seconds
        image = "toottalk.png"      -- image name in html/images/
    },
    ["quickcart"] = {
        label = "Marketing Company",
        description = "Launch a marketing company that actually scams people because they're useless",
        baseCost = 5000,
        baseIncome = 200,           
        upgradeMultiplier = 2.1,
        maxLevel = 5,
        upgradeTime = 43200,        
        image = "quickcart.png"     
    },
    ["memecoin"] = {
        label = "Meme Coin",
        description = "Launch a memecoin and become like 99% of the irl celebs :)",
        baseCost = 12000,           
        baseIncome = 350,           
        upgradeMultiplier = 2.2,    
        maxLevel = 5,
        upgradeTime = 43200,        
        image = "memecoin.png"      -- image in html/images/
    }
}


Config.IncomeInterval = 3600  -- Interval of payment to bank

