local installation = settings.get("kristify.path") or "kristify"
local ctx = ({ ... })[1]

local BROADCAST_CHANNEL = 9773
local BROADCAST_INTERVAL_SEC = 30
local txModem

local txMsg = {
    type = "ShopSync",
    info = {
        name = ctx.config.name,
        description = ctx.config.tagline,
        multiShop = ctx.config.shopSync.multiShop,
        software = {
            name = "Kristify"
        },
        location = {}
    },
    items = {}
}

local verFile = fs.open(fs.combine(installation, "src", "version.txt"), "r")
txMsg.info.software.version = verFile.readAll()
verFile.close()

if (ctx.config.shopSync.modem == nil) or (ctx.config.shopSync.modem == "") then
    txModem = peripheral.find("modem", function(name, modem)
        return modem.isWireless()
    end)
else
    txModem = peripheral.wrap(ctx.config.shopSync.modem)
end

if not ((ctx.config.shopSync.owner == nil) or (ctx.config.shopSync.owner == "")) then
    txMsg.info.owner = ctx.config.shopSync.owner
end

if (ctx.config.shopSync.location.broadcastLocation == true) then
    txMsg.info.location = ctx.config.shopSync.location
    txMsg.info.location.broadcastLocation = nil

    if (txMsg.info.location.coordinates[2] == 0) then
        local gps_x, gps_y, gps_z = gps.locate()
        if (gps_x ~= nil) then
            txMsg.info.location.coordinates = { gps_x, gps_y, gps_z }
        else
            txMsg.info.location.coordinates = nil
        end
    end
end

-- Set up modem
txModem.open(BROADCAST_CHANNEL)

if (ctx.config.shopSync.enabled) then
    while true do 
        -- TODO: Reset & populate items list

        txModem.transmit(BROADCAST_CHANNEL, BROADCAST_CHANNEL, txMsg)
        print(textutils.serialise(txMsg))
        sleep(BROADCAST_INTERVAL_SEC)
    end
else
    sleep(604800) -- sleep for 1 real-world week if ShopSync is not enabled (if I understand the code correctly everything will breakdown and cry if we cleanly exit)
end