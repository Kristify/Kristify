local installation = settings.get("kristify.path") or "kristify"
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

-- Wait for chests to be indexed
os.pullEvent("kristify:storageRefreshed")

-- Continously broadcast ShopSync message
while true do
    -- Refresh products list
    txMsg.items = {}
    for i, product in ipairs(ctx.products) do
        table.insert(txMsg.items, {
            prices = {
                value = product.price,
                currency = "KST",
                address = product.metaname .. "@" .. ctx.config.name .. ".kst"
            },
            item = {
                name = product.id,
                nbt = product.nbt,
                displayName = product.displayName
            },
            stock = ctx.storage.getCount(product.id, product.nbt),
            madeOnDemand = false,
            requiresInteraction = false
        })
    end

    -- Transmit & wait
    txModem.transmit(BROADCAST_CHANNEL, os.getComputerID(), txMsg)
    sleep(BROADCAST_INTERVAL_SEC)
end
