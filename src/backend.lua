local kristly = require("/src/libs/kristly")
local utils = require("/src/utils")
local logger = require("/src/libs/logger"):new({ debugging = true })

logger:info("Starting Kristify! Thanks for choosing Kristify. <3")
logger:debug("Debugging mode is enabled!")

local config = require("/data/config")
local products = require("/data/products")

if config == nil or config.pkey == nil then
  logger:error("Config not found! Check documentation for more info.")
  return
end

-- TODO Make autofix
if utils.endsWith(config.name, ".kst") then
  logger:error("The krist name configured contains `.kst`, which it should not.")
  return
end

local ws = kristly.websocket(config.pkey)

local function startListening()
  ws:subscribe("transactions")
  logger:info("Subscribed to transactions.")

  while true do
    local _, data = os.pullEvent("kristly")

    if data.type == "keepalive" then
      logger:debug("Keepalive packet")
    elseif data.type == "event" then
      logger:debug("Event: " .. data.event)

      if data.event == "transaction" then
        local transaction = data.transaction

        if transaction.sent_name == config.name and transaction.sent_metaname ~= nil then
          logger:info("Received transaction to: " .. transaction.sent_metaname .. "@" .. transaction.sent_name .. ".kst")

          handleTransaction(transaction)
        elseif transaction.sent_name == config.name then
          kristly.makeTransaction(config.pkey, transaction.from, transaction.value,
            "message=Refunded. No metaname found")
        end
      end

    else
      logger:debug("Ignoring packet: " .. data.type)
    end
  end
end

function handleTransaction(transaction)
  if not utils.productsIncludes(products, transaction.sent_metaname) then
    kristly.makeTransaction(config.pkey, transaction.from, transaction.value,
      "message=Hey! The item `" .. transaction.sent_metaname .. "` is not available.")
    return
  end

  local product = utils.getProduct(products, transaction.sent_metaname)

  if transaction.value < product.price then
    kristly.makeTransaction(config.pkey, transaction.from, transaction.value,
      "message=Insufficient amount of krist sent.")
    return
  end

  local amount = math.floor(transaction.value / product.price)
  local change = transaction.value - (amount * product.price)

  if change ~= 0 then
    kristly.makeTransaction(config.pkey, transaction.from, change,
      "message=Here is your change! Thanks for using our shop.")
  end

  logger:info("Dispensing " .. amount .. " item(s).")
end

local function startKristly()
  ws:start()
end

parallel.waitForAny(startKristly, startListening)
