return {
  pkey = "",
  name = "localDealer",
  tagline = "Test message",
  monSide = "moanitor_0",
  storage = {
    "minecraft:chest_4",
    "minecraft:chest_5",
  },
  speakers = {
    "minecraft:speaker_0",
    "minecraft:chest_1",
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
      url = ""
    }
  },
  sounds = {
    started = "minecraft:block.note_block.harp",
    purchase = "minecraft:entity.villager.yes",
    error = "minecraft:block.anvil.land"
  }
}
