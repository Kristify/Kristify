local ctx = ({ ... })[1]
local shopSync = ctx.config.shopSync

local BROADCAST_CHANNEL = 9773
local BROADCAST_INTERVAL_SEC = 30

-- Find the modem to broadcast over
local txModem
if ctx.utils.isNullish(shopSync.modem) then
    txModem = peripheral.find("modem", function(name, modem)
        return modem.isWireless()
    end)
else
    txModem = peripheral.wrap(shopSync.modem)
end
txModem.open(BROADCAST_CHANNEL)

-- Construct the message (excluding product & location information)
local txMsg = {
    type = "ShopSync",
    info = {
        name = ctx.config.name .. ".kst",
        description = ctx.config.tagline,
        computerID = os.getComputerID(),
        multiShop = shopSync.multiShop,
        software = {
            name = "Kristify",
            version = ctx.version
        },
        location = {}
    },
    items = {}
}

if not ctx.utils.isNullish(shopSync.owner) then
    txMsg.info.owner = shopSync.owner
end

-- Fetch shop location via GPS (if required)
if shopSync.location.broadcastLocation then
    txMsg.info.location = shopSync.location
    txMsg.info.location.broadcastLocation = nil

    if txMsg.info.location.coordinates[2] == 0 then
        local location = { gps.locate() }
        if (location[3] ~= nil) then
            txMsg.info.location.coordinates = location
        else
            txMsg.info.location.coordinates = nil
        end
    end
end

-- Function to broadcast message
function broadcastShopSync() 
    -- Refresh products list
    txMsg.items = {}
    for i, product in ipairs(ctx.products) do
        table.insert(txMsg.items, {
            prices = {
                {
                    value = product.price,
                    currency = "KST",
                    address = product.metaname .. "@" .. ctx.config.name .. ".kst"
                }
            },
            item = {
                name = product.id,
                nbt = product.nbt,
                displayName = product.displayName
            },
            dynamicPrice = false,
            stock = ctx.storage.getCount(product.id, product.nbt),
            madeOnDemand = false,
            requiresInteraction = false
        })
    end

    -- Transmit & wait
    txModem.transmit(BROADCAST_CHANNEL, os.getComputerID() % 65536, txMsg)
end

-- Wait for chests to be indexed
os.pullEvent("kristify:storageRefreshed")

-- Wait 15-30s before inital broadcast
math.randomseed(os.epoch())
os.startTimer(15 + (math.random() * 15))
os.pullEvent("timer")

-- Inital ShopSync broadcast ('Situation 1')
broadcastShopSync() 

-- Broadcast after each purchase (or in this case, storage refresh) ('Situation 2')
while true do
    os.pullEvent("kristify:storageRefreshed")
    broadcastShopSync()
end
