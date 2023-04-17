local sourcePath = fs.getDir(shell.getRunningProgram())
local rootPath = fs.combine(sourcePath, "..")
local dataPath = fs.combine(rootPath, "data")
local pagesPath = fs.combine(dataPath, "pages")
local ctx = {}

local function init()
  ctx = { products = {}, theme = {}, config = {}, pages = {} }
  ctx.path = {
    page = pagesPath,
    src = sourcePath,
    data = dataPath
  }

  -- Logger
  ctx.logger = require("logger"):new({
    debugging = settings.get("kristify.debug"),
    log2file = settings.get("kristify.log2file")
  })

  -- Pages
  local pages = fs.list(pagesPath)
  for i = 1, #pages do
    local f = fs.open(fs.combine(pagesPath, pages[i]), 'r')
    ctx.pages[pages[i]] = f.readAll()
    f.close()
  end

  -- Data
  local function loadStr(str, begin, env)
    if not begin then begin = "" end
    local success, result = pcall(loadstring(begin .. str, "t", env))
    if success and type(result) == "table" then
      return result
    end
    return false
  end

  local function loadLuaFile(path, env)
    if fs.exists(path) and not fs.isDir(path) then
      local f = fs.open(path, 'r')
      local c = f.readAll()
      f.close()
      local result = loadStr(c, "", env)
      if not result then
        error("Could not load \'" .. path .. "\' properly!\n" .. tostring(result))
        sleep(1)
      end
      return result
    else
      error("Could not load \'" .. path .. "\'!")
      sleep(0.5)
    end
  end

  -- theme
  local result = loadLuaFile(fs.combine(pagesPath, "theme.lua"), { colors })
  if result then
    ctx.theme = result
  end

  -- config
  result = loadLuaFile(fs.combine(dataPath, "config.lua"))
  if result then
    ctx.config = result
  end
  -- products
  result = loadLuaFile(fs.combine(dataPath, "products.lua"))
  if result then
    ctx.products = result
  end

  -- Set debug mode
  settings.define("kristify.debug", {
    description = "If kristify should be debugging",
    default = false,
    type = "boolean"
  })

  settings.define("kristify.log2file", {
    description = "If kristify should log to a file",
    default = false,
    type = "boolean"
  })

  -- Load Basalt
  local basalt = {}
  if not fs.exists(fs.combine(ctx.path.src, "lib", "basalt")) then
    local authenticate = _G._GIT_API_KEY and { Authorization = "Bearer " .. _G._GIT_API_KEY }
    local basaltDL, err, errCode = http.get(
      "https://raw.githubusercontent.com/Kristify/kristify/main/src/libs/basalt.lua"
      , authenticate)
    if not basaltDL then
      ctx.logger:error("Couldn't load Basalt into memory! Reason: \'" ..
        err .. "\' (code " .. errCode.getResponseCode() .. ')')
      return
    end

    basalt = load(basaltDL.readAll())()
    basaltDL.close()
  else
    basalt = require("basalt")
  end
  ctx.basalt = basalt

  -- Load scripts
  ctx.kristly = require(fs.combine("libs", "kristly"))
  ctx.utils = require("utils")
  ctx.webhooks = require("webhook")

  -- Check errors
  local function bAssert(condition, errormsg)
    if condition then
      error(errormsg)
    end
  end

  local function configExpect(name, typ)
    local curTyp = type(ctx.config[name])
    if curTyp ~= typ then
      error("Bad value for \'" .. name .. "\' in config; Expected \'" .. typ .. "\', got \'" .. curTyp ..
        "\'.")
    elseif curTyp == "string" and ctx.config[name] == "" then
      ctx.logger:warn("Value \'" .. name .. "\' in config should not be empty.")
    end
    return true
  end

  configExpect("pkey", "string")
  if configExpect("name", "string") then
    bAssert(ctx.utils.endsWith(ctx.config.name or "", ".kst"), "Remove \'.kst\' from the name.")
  end
  configExpect("webhooks", "table")
  configExpect("sounds", "table")

  if string.find(_HOST, "CraftOS-PC", 1, true) then
    error("CraftOS-PC does not support turtles, and thus Kristify cannot run on it.")
  end

  ctx.logger:debug("CraftOS-PC not detected")

  local modem = peripheral.find("modem")
  if not modem then
    error("Kristify is not connected to a network! (aka. wired modem)")
  elseif type(ctx.config.self) == "string" and modem.getNameLocal() ~= (ctx.config.self or "") then
    error("Given turtle in config does not exist!")
  else
    configExpect("self", "string")
  end

  if configExpect("storage", "table") then
    bAssert(#ctx.config.storage == 0 or ctx.config.storage[1] == "", "Storage table in config is empty or invalid!")
    for _, inv in pairs(ctx.config.storage) do
      if not peripheral.wrap(inv) then
        error("Inventory \'" .. inv .. "\' does not exist!")
        nErrors = nErrors + 1
      end
    end
  end
  if configExpect("monSide", "string") then
    bAssert(not peripheral.wrap(ctx.config.monSide), "Given monitor side does not exist!")
  end


  -- Load libs, related to peripherals
  ctx.speakerLib = require("speaker")
  ctx.speakerLib.config = ctx.config
  ctx.logger:debug("Loading inventory library")
  ctx.logger:debug("Configured storage: " .. textutils.serialize(ctx.config.storage))
  ctx.storage = require(fs.combine("libs", "inv"))(ctx.config.storage or {})
  ctx.logger:info("Passed initiating")
  return ctx
end

print("Starting initiating process.")

local function xpcaller(toRun)
  local msg = false
  xpcall(toRun, function(err)
    msg = err
    ctx.logger:error(err)
    ctx.logger:warn("Error detected. Press a key to exit.")
    sleep(0.5)
  end)
  return msg
end

local err = xpcaller(init)
if err then os.pullEvent("key") end

local function runFile(path)
  local script, err = loadfile(path, "t", _ENV)

  if not script then
    error("Could not load script. " + err)
  end

  -- xpcall(script, function(err) error(err) end, ctx)
  -- pcall(script, ctx)
  script(ctx)
end


err = xpcaller(function()
  parallel.waitForAny(
    function()
      runFile(fs.combine(sourcePath, "backend.lua"))
      ctx.logger:warn("Backend exited")
    end,
    function()
      runFile(fs.combine(sourcePath, "frontend.lua"))
      ctx.logger:warn("Frontend exited")
    end
  )
end)

-- Clear monitor so nobody donates money
local mon = peripheral.wrap(ctx.config.monSide)
local width, height = mon.getSize()
mon.setBackgroundColor(colors.black)
mon.setTextColor(colors.white)
mon.clear()
mon.setTextScale(0.5)
mon.setCursorPos(math.floor(width / 2 - (#ctx.config.name + 4) / 2 + 1), math.floor(height / 2))
mon.write(ctx.config.name .. ".kst")
mon.setCursorPos(math.floor(width / 2 - 7), math.floor(height / 2) + 1)
mon.setTextColor(colors.lightGray)
mon.write("Shop is offline")

ctx.logger:error("A process exited.")
if err then ctx.logger:warn("Error detected. Press a key to exit.") end
sleep(0.5)
os.pullEvent("key")
