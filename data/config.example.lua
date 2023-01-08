-- This is a example config. Items not labeled with `Required.` at the end of the comment, are not required, and can be removed.

return {
  -- Krist private key in raw format. Do not share this with anyone. Required.
  -- If you're using Kristwallet format, this should typically be lowercase and end in -000.
  pkey = "",

  -- The Krist name you want to use for the shop. The need for this will be removed later on. Required.
  name = "",

  -- The networkID of your turtle. To get this click the modem your turtle is connected to.
  self = "",

  -- The tagline for your shop! This is a string, and is optional. Your theme is able to get this field.
  tagline = "",

  -- Where your monitor is located. This can either be a side releative from the turtle, or a network ID. Required.
  monSide = "",

  -- The scale you want on your monitor. 1 is normal size, 0.5 is half the sise. Defaults to 0.5.
  monScale = 0.5,

  -- If the storage should be refreshed once there comes in a purchase. This will slow down your shop. Only use this if you are inserting items into the storage without reloading manually.
  refreshCacheBeforePurchase = false,

  -- A tablearray of storage units. This is parsed by AbstractInvLib. Required.
  storage = {
    ""
  },

  -- A tablearray of speakers. This can in the format of network ID or adjectent peripheral. Defaults to no speakers
  speakers = {
    ""
  },

  -- Redstone pulses. This can be used with forexample a redstone lamp. The redstone item must be adjectent to the turtle.
  redstonePulse = {

    -- The delay in seconds between the redstone switching on/off.
    delay = 3,

    -- A tablearray of sides to have redstone output on.
    sides = {
      "right",
    }
  },

  -- A table of messages that are sent along with different refunds.
  messages = {
    noMetaname      = "message=No metaname found! Refunding.",
    nonexistantItem = "message=The item you requested is not available for purchase",
    notEnoughMoney  = "message=Insufficient amount of krist sent.",
    notEnoughStock  = "message=We don't have that much stock!",
    change          = "message=Here is your change! Thanks for using our shop."
  },

  -- A tablearray of messages
  webhooks = {
    {
      -- The type of webhook. Can be: discord-modern, discord, googleChat
      type = "discord-modern",

      -- The webhook URL
      URL = "",

      -- The events that the webhook should trigger on
      events = { "purchase", "invalid", "error" }
    }
  },

  -- A table of sound effects that are played on events.
  sounds = {
    started = "minecraft:block.note_block.harp",
    purchase = "minecraft:entity.villager.yes",
    error = "minecraft:block.anvil.land",
    click = "minecraft:block.wooden_button.click_on",
    volume = 0.6
  }
}
