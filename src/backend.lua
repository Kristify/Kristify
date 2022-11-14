local kristly = require("libs.kristly")

local name = "cats"

local ws = kristly.websocket()

local function startListening()
  ws:subscribe("transactions")
  print("Subscribed")

  while true do
    local _, data = os.pullEvent("kristly")

    if data.type == "keepalive" then
      print("Keep alive packet")
    elseif data.type == "event" then
      print("Event: " .. data.event)

      if data.event == "transaction" then
        local transaction = data.transaction

        if transaction.sent_name == name and transaction.sent_metaname ~= nil then
          print("Sent to: " .. transaction.sent_metaname .. "@" .. transaction.sent_name .. ".kst")
        end
      end

    else
      print("Ignoring packet: " .. data.type)
    end
  end
end

local function startKristly()
  ws:start()
end

parallel.waitForAny(startKristly, startListening)
