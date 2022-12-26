settings.define("kristify.debug", {
  description = "If kristify should be debugging",
  default = false,
  type = "boolean"
})

local kristly = require("/src/libs/kristly")
local utils = require("/src/utils")
local logger = require("/src/logger"):new({ debugging = settings.get("kristify.debug") })
local webhooks = require("/src/webhook")
local speakerLib = require("/src/speaker")

logger:info("Starting Kristify! Thanks for choosing Kristify. <3")
logger:debug("Debugging mode is enabled!")

local config = require("/data/config")
local products = require("/data/products")

if config == nil or config.pkey == nil then
  logger:error("Config not found! Check documentation for more info.")
  return
end

local speaker = speakerLib:new({
  config = config
})

if config.storage == nil or #config.storage == 0 then
  logger:error("Missing storage chests")
  speaker:play("error")
  return
end

if config.monSide == nil then
  logger:error("Missing monitor side in config")
  speaker:play("error")
  return
end

if config.self == nil then
  logger:error("Config does not include self field")
  speaker:play("error")
  return
end

if utils.endsWith(config.name, ".kst") then
  logger:error("The krist name that is configured either contains `.kst`, which it should not, or is not defined.")
  speaker:play("error")
  return
end

logger:info("Configuration loaded. Indexing chests")

local storage = require("/src/libs/inv")(config.storage)
storage.refreshStorage()
logger:info("Chests indexed.")

local ws = kristly.websocket(config.pkey)

local function startListening()
  ws:subscribe("transactions")
  logger:info("Subscribed to transactions.")

  speaker:play("started")

  while true do
    local _, data = os.pullEvent("kristly")

    if data.type == "keepalive" then
      logger:debug("Keepalive packet")
    elseif data.type == "event" then
      logger:debug("Krist event: " .. data.event)

      if data.event == "transaction" then
        local transaction = data.transaction

        if transaction.sent_name == config.name and transaction.sent_metaname ~= nil then
          logger:info("Received transaction to: " .. transaction.sent_metaname .. "@" .. transaction.sent_name .. ".kst")

          handleTransaction(transaction)
        elseif transaction.sent_name == config.name then
          logger.info("No metaname found. Refunding.")
          kristly.makeTransaction(config.pkey, transaction.from, transaction.value,
            config.messages.noMetaname)
          speaker:play("error")
        end
      end

    else
      logger:debug("Ignoring packet: " .. data.type)
    end
  end
end

function handleTransaction(transaction)
  logger:debug("Handle Transaction")
  local product = utils.getProduct(products, transaction.sent_metaname)

  if product == false or product == nil then
    kristly.makeTransaction(config.pkey, transaction.from, transaction.value,
      config.messages.nonexistantItem)
    logger:debug("Item does not exist.")
    speaker:play("error")
    return
  end


  if transaction.value < product.price then
    logger:info("Not enough money sent. Refunding.")
    kristly.makeTransaction(config.pkey, transaction.from, transaction.value,
      config.messages.notEnoughMoney)
    speaker:play("error")
    return
  end

  local amount = math.floor(transaction.value / product.price)
  local change = math.floor(transaction.value - (amount * product.price))

  logger:debug("Amount: " .. amount .. " Change: " .. change)

  local itemsInStock = storage.getCount(product.id)
  logger:debug("Managed to get stock: " .. itemsInStock)
  if amount > itemsInStock then
    logger:info("Not enough in stock. Refunding")
    logger:debug("Stock for " .. product.id .. " was " .. itemsInStock .. ", requested " .. amount)
    kristly.makeTransaction(config.pkey, transaction.from, amount * product.price,
      config.messages.notEnoughStock)
    speaker:play("error")
    return
  end

  if change ~= 0 then
    logger:debug("Sending out change")
    kristly.makeTransaction(config.pkey, transaction.from, change, config.messages.change)
  end

  logger:info("Dispensing " .. amount .. "x " .. product.id .. " (s).")

  local turns = math.ceil(amount / 64 / 16)
  local lastTurn = amount - ((turns - 1) * 64 * 16)

  logger:debug("Taking " .. turns .. " turn(s), last one has " .. lastTurn)

  for turn = 1, turns do
    logger:debug("Turn: " .. turn .. ". Turns needed: " .. turns)
    if turns == turn then
      logger:debug("Last turn.")
      logger:debug("Arguments passed: " .. config.self, " | ", product.id, " | ", tostring(lastTurn))
      storage.pushItems(config.self, product.id, lastTurn, nil, nil, { optimal = false })
    else
      logger:debug("Not last turn")
      storage.pushItems(config.self, product.id, 64 * 16, nil, nil, { optimal = false })

    end
    for i = 1, 16 do
      turtle.select(i)
      turtle.drop()
    end
  end

  local message = "Kristify: `" ..
      transaction.from .. "` bought " .. amount .. "x " .. product.id .. " (" .. transaction.value .. "kst)"

  logger:debug("Running webhooks")
  for _, webhook in ipairs(config.webhooks) do
    logger:debug("Webhook: ", webhook.type, webhook.URL)
    if webhook.type == "discord" then
      webhooks.discord(webhook.URL, message)
    elseif webhook.type == "discord-modern" then
      webhooks.discordModern(webhook.URL, transaction.from, product.id, amount * product.price, transaction.id,
        transaction.to)
    elseif webhook.type == "googleChat" then
      webhooks.googleChat(webhook.URL, message)
    end
  end

  speaker:play("purchase")
end

local function startKristly()
  ws:start()
end

parallel.waitForAny(startKristly, startListening)
