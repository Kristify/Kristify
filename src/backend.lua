local kristly = require("/src/libs/kristly")
local utils = require("/src/utils")
print("Starting kristify")

local config = require("/data/config")
local products = require("/data/products")

if config == nil or config.pkey == nil then
  print("Config not found!")
  return
end

if utils.endsWith(config.name, ".kst") then
  print("The krist name in config should not include `.kst`.")
  return
end

local ws = kristly.websocket(config.pkey)

local function startListening()
  ws:subscribe("transactions")
  print("Subscribed to transactions! :D")

  while true do
    local _, data = os.pullEvent("kristly")

    if data.type == "keepalive" then
      print("Keep alive packet")
    elseif data.type == "event" then
      print("Event: " .. data.event)

      if data.event == "transaction" then
        local transaction = data.transaction

        if transaction.sent_name == config.name and transaction.sent_metaname ~= nil then
          print("Transaction to: " .. transaction.sent_metaname .. "@" .. transaction.sent_name .. ".kst")

          handleTransaction(transaction)
        elseif transaction.sent_name == config.name then
          kristly.makeTransaction(config.pkey, transaction.from, transaction.value,
            "message=Refunded. No metaname found")
        end
      end

    else
      print("Ignoring packet: " .. data.type)
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

  print("Dispensing " .. amount .. " item(s).")
end

local function startKristly()
  ws:start()
end

parallel.waitForAny(startKristly, startListening)
