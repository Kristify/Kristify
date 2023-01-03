return {
  pkey = "",
  name = "",
  tagline = "",
  monSide = "",
  monScale = 0.5,
  storage = {
    ""
  },
  speakers = {
    ""
  },
  redstonePulse = {
    {
      delay = 3,
      side = "right",
    }
  },
  self = "",
  messages = {
    noMetaname      = "message=No metaname found! Refunding.",
    nonexistantItem = "message=The item you requested is not available for purchase",
    notEnoughMoney  = "message=Insufficient amount of krist sent.",
    notEnoughStock  = "message=We don't have that much stock!",
    change          = "message=Here is your change! Thanks for using our shop."
  },
  webhooks = {
    {
      type = "discord-modern",
      url = "",
      events = { "purchase", "invalid", "error" }
    }
  },
  sounds = {
    started = "minecraft:block.note_block.harp",
    purchase = "minecraft:entity.villager.yes",
    error = "minecraft:block.anvil.land",
    click = "minecraft:block.wooden_button.click_on",
    volume = 0.6
  }
}
