local ctx = ({ ... })[1]

local BROADCAST_CHANNEL = 9773
local BROADCAST_INTERVAL_SEC = 30
local txModem

local txMsg = {
    type = "ShopSync",
    info = {
        name = ctx.config.name,
        description = ctx.config.tagline,
        multiShop = cfg.config.shopsync.multiShop,
        software = {
            name = "Kristify"
        },
        location = {}
    },
    items = {}
}

local verFile = fs.open("version.txt", "r")
txMsg.info.software.version = verFile.readAll()
verFile.close()

if (cfg.config.shopsync.modem == nil) or (cfg.config.shopsync.modem == "") then
    txModem = peripheral.find("modem", function(name, modem)
        return modem.isWireless()
    end)
else
    txModem = peripheral.wrap(cfg.config.shopsync.modem)
end

if not ((cfg.config.shopsync.owner == nil) or (cfg.config.shopsync.owner == "")) then
    txMsg.info.owner = cfg.config.shopsync.owner
end

if (cfg.config.shopsync.location.broadcastLocation == true) then
    txMsg.info.location = cfg.config.shopsync.location
    txMsg.info.location.broadcastLocation = nil

    if (txMsg.info.location.coordinates == { 0, 0, 0 }) then
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