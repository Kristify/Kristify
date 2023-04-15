local ctx = ({ ... })[1]

local logger = ctx.logger
local kristly = ctx.kristly
local utils = ctx.utils
local config = ctx.config
local products = ctx.products
local webhooks = ctx.webhooks
local speakerLib = ctx.speakerLib

local pulseID = -1

logger:info("Starting Kristify! Thanks for choosing Kristify. <3")
logger:debug("Debugging mode is enabled!")

local speaker = speakerLib:new({
  config = config
})

if config.messages == nil then
  config.messages = {
    noMetaname      = "message=No metaname found! Refunding.",
    nonexistantItem = "message=The item you requested is not available for purchase",
    notEnoughMoney  = "message=Insufficient amount of krist sent.",
    notEnoughStock  = "message=We don't have that much stock!",
    change          = "message=Here is your change! Thanks for using our shop."
  }

  logger:info("Message field not found in config. Defaulting to default values.")
end

logger:info("Configuration loaded. Waiting for chests to be indexed.")

os.pullEvent("kristify:storageRefreshed")

local storage = ctx.storage
logger:info("Chests indexed according to frontend.")

local ws = kristly.websocket(config.pkey)
logger:debug("WebSocket started")

local function startListening()
  ws:subscribe("transactions")
  logger:info("Subscribed to transactions.")

  speaker:play("started")
  if config.redstonePulse ~= nil and config.redstonePulse.delay ~= nil and #config.redstonePulse.sides ~= nil then
    logger:debug("Starting redstone timer")
    pulseID = os.startTimer(config.redstonePulse.delay)
    logger:debug("Timer ID is: " .. pulseID)
  end

  while true do
    local e, data = os.pullEvent()

    if e == "kristly" then
      kristlyEvent(data)
    elseif e == "timer" then
      timerEvent(data)
    end
  end
end

function timerEvent(id)
  if pulseID == id then
    redstonePulse()
  end
end

function redstonePulse()
  for index, s in ipairs(config.redstonePulse.sides) do
    local current = rs.getAnalogOutput(s)
    if current == nil or current == 0 then
      rs.setAnalogOutput(s, 15)
    else
      rs.setAnalogOutput(s, 0)
    end
  end

  pulseID = os.startTimer(config.redstonePulse.delay)
end

local function refund(pkey, transaction, amountToPay, message, isError)
  isError = isError or true

  local meta = utils.parseCommonmeta(transaction.metadata)
  local returnTo = meta["meta"]["return"] or transaction.from
  logger:debug("Refunding to: " .. returnTo)
  kristly.makeTransaction(pkey, returnTo, amountToPay, message)

  if isError then
    speaker:play("error")

    for _, value in ipairs(config.webhooks) do
      if utils.tableIncludes(value.events, "invalid") then
        print("Webhook : Invalid : " .. value.type)

        if value.type == "discord" then
          webhooks.discord(value.URL,
            "Invalid purchase by `" .. returnTo .. "`. Refunding with meta: `" .. message .. "`.")
        elseif value.type == "googleChat" then
          webhooks.googleChat(value.URL,
            "Invalid purchase by `" .. returnTo .. "`. Refunding with meta: `" .. message .. "`.")
        elseif value.type == "discord-modern" then
          webhooks.discordModernInvalid(value.URL, returnTo, transaction.id, message)
        end
      end
    end
  end
end

function kristlyEvent(data)
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
        logger:info("No metaname found. Refunding.")
        refund(config.pkey, transaction, transaction.value, config.messages.noMetaname)
      end
    end
  elseif data.type == "KRISTLY-ERROR" then
    logger:error("Received kristly error: " .. data.error)
    return
  else
    logger:debug("Ignoring packet: " .. data.type)
  end
end

function handleTransaction(transaction)
  logger:debug("Handle Transaction...")

  if config.refreshCacheBeforePurchase == true or config.refreshCacheBeforePurchase == nil then
    os.queueEvent("kstUpdateProducts")
    os.pullEvent("kristify:storageRefreshed")
    logger:debug("Storage refreshed!")
  end

  local product = utils.getProduct(products, transaction.sent_metaname)

  if product == false or product == nil then
    logger:info("Item does not exist. Refunding. Was from: " .. transaction.from)
    refund(config.pkey, transaction, transaction.value, config.messages.nonexistantItem)
    return
  end


  if transaction.value < product.price then
    logger:info("Not enough money sent. Refunding.")
    refund(config.pkey, transaction, transaction.value, config.messages.notEnoughMoney)
    return
  end

  local amount = math.floor(transaction.value / product.price)
  local change = math.floor(transaction.value - (amount * product.price))

  logger:debug("Amount: " .. amount .. " Change: " .. change)

  local itemsInStock = storage.getCount(product.id, product.nbt)
  logger:debug("Managed to get stock: " .. itemsInStock)

  if amount > itemsInStock then
    logger:info("Not enough in stock. Refunding")
    logger:debug("Stock for " .. product.displayName .. " was " .. itemsInStock .. ", requested " .. amount)
    refund(config.pkey, transaction, transaction.value, config.messages.notEnoughStock)
    return
  end

  if change ~= 0 then
    logger:debug("Sending out change")
    refund(config.pkey, transaction, change, config.messages.change, false)
  end

  logger:info("Dispensing " .. amount .. "x " .. product.displayName .. " (s).")

  local stackSize = storage.getItem(product.id, product.nbt).item.maxCount
  local turns = math.ceil(amount / stackSize / 16)
  local lastTurn = amount - ((turns - 1) * stackSize * 16)

  logger:debug("Taking " .. turns .. " turn(s), last one has " .. lastTurn)

  for turn = 1, turns do
    logger:debug("Turn: " .. turn .. ". Turns needed: " .. turns)
    if turns == turn then
      logger:debug("Last turn.")
      logger:debug("Arguments passed: " .. config.self, " | ", product.id, " | ", tostring(lastTurn))
      storage.pushItems(config.self, product.id, lastTurn, nil, product.nbt, { optimal = false })
    else
      logger:debug("Not last turn")
      storage.pushItems(config.self, product.id, stackSize * 16, nil, product.nbt, { optimal = false })

    end
    for i = 1, 16 do
      turtle.select(i)
      turtle.drop()
    end
  end

  local message = "Kristify: `" ..
      transaction.from .. "` bought " .. amount .. "x " .. product.displayName .. " (" .. transaction.value .. "kst)"

  logger:debug("Running webhooks")

  if config.webhooks ~= nil then
    for _, webhook in ipairs(config.webhooks) do
      logger:debug("Webhook: ", webhook.type, webhook.URL)

      if webhook.type == "discord" then
        webhooks.discord(webhook.URL, message)
      elseif webhook.type == "discord-modern" then
        webhooks.discordModernPurchase(
          webhook.URL, transaction.from, product.displayName, amount * product.price,
          transaction.id,
          transaction.to
        )

      elseif webhook.type == "googleChat" then
        webhooks.googleChat(webhook.URL, message)
      end
    end
  end

  os.queueEvent("kstUpdateProducts")
  speaker:play("purchase")
end

local function startKristly()
  ws:start()
end

parallel.waitForAny(startKristly, startListening)
