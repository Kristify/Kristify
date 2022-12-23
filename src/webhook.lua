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

  -- http.post(URL, "content=" .. message .. "&username=" .. username .. "&avatar_url=" .. avatar)
  http.post(URL, textutils.serialiseJSON({ content = message, username = username, avatar_url = avatar }),
    { ["Content-Type"] = "application/json; charset=UTF-8" })
end

---Sends a webhook to a Discord Guild, with modern embeds!
---@param URL string The webhook URL
---@param user string The krist address that purchased
---@param item string The item that was purchased
---@param total number The total amount of krist earned
---@param transactionID number The krist transaction ID of the purchase
---@param addrs string The full address that was sent krist to
function webhooks.discordModern(URL, user, item, total, transactionID, addrs)
  expect(1, URL, "string")
  expect(2, user, "string")
  expect(3, item, "string")
  expect(4, total, "number")
  expect(5, transactionID, "number")
  expect(6, addrs, "string")

  local kristweb = "[KristWeb](https://krist.club/network/transactions/" .. transactionID .. ")"
  local openWithURI = "<krist://tx/" .. transactionID .. "> (URI)"

  local data = {
    content = "",
    username = "Kristify",
    avatar_url = "https://media.discordapp.net/attachments/1014151202855976973/1014162892414783559/Kristify.png",
    embeds = {
      {
        title = user .. " bought " .. item,
        color = "16750744",
        fields = {
          {
            name = "Ends up at",
            value = addrs
          },
          {
            name = "Transaction ID",
            value = transactionID
          },
          {
            name = "Krist earned",
            value = total
          },
          {
            name = "Open with",
            value = kristweb .. " or " .. openWithURI
          }
        },
        author = {
          name = "Someone bought something!"
        },
        thumbnail = {
          url = "https://docs.krist.dev/favicon-128x128.png"
        },
        timestamp = os.date("!%Y-%m-%dT%TZ"),
        footer = {
          text = "Powered by Kristify"
        }
      }
    }
  }

  http.post(URL, textutils.serialiseJSON(data), { ["Content-Type"] = "application/json; charset=UTF-8" })
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
