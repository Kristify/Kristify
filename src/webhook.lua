local webhooks = {}
local expect = require("cc.expect").expect

---Sends a webhook to a Discord Guild
---@param URL string The webhook URL
---@param message string The message to send
---@param username string|nil The username of the webhook sender
---@param avatar string|nil The link to the avatar sender
function webhooks.discord(URL, message, username, avatar)
  expect(1, URL, "string")
  expect(2, message, "string")
  expect(3, username, "string", "nil")
  expect(4, avatar, "string", "nil")

  username = username or "Kristify shop"
  avatar = avatar or "https://media.discordapp.net/attachments/1014151202855976973/1014162892414783559/Kristify.png"

  http.post(URL, "content=" .. message .. "&username=" .. username .. "&avatar_url=" .. avatar)
end

---Sends a webhook to a Google Chat (requires Google Workspace)
---@param URL string The webhook URL
---@param message string The messge to send
function webhooks.googleChat(URL, message)
  http.post(URL, textutils.serialiseJSON({
    ["text"] = message
  }), { ["Content-Type"] = "application/json; charset=UTF-8" })
end

return webhooks
