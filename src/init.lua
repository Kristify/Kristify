-- make a copy of package.path
local sSrc = fs.getDir(shell.getRunningProgram())
local sRoot = fs.combine(sSrc, "..")
local sData = fs.combine(sRoot, "data")
local sPage = fs.combine(sData, "pages")

local ctx

local nErrors = 0
local function init(...)
    -- [Context]
    ctx = { products = {}, theme = {}, config = {}, pages = {} }
    ctx.path = {
        page = sPage,
        src = sSrc,
        data = sData
    }

    -- Logger
    ctx.logger = require("logger"):new({ debugging = settings.get("kristify.debug"),
        log2file = settings.get("kristify.log2file") })


    -- [Pages]
    local pages = fs.list(sPage)
    for i = 1, #pages do
        local f = fs.open(fs.combine(sPage, pages[i]), 'r')
        ctx.pages[pages[i]] = f.readAll()
        f.close()
    end

    -- [Data] (config,theme,products, etc.)
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
                ctx.logger:error("Could not load \'" .. path .. "\' properly!\n" .. tostring(result))
                sleep(1)
            end
            return result
        else
            ctx.logger:error("Could not load \'" .. path .. "\'!")
            sleep(0.5)
        end
        return false
    end

    -- theme
    local col = { white = 0x1, orange = 0x2, magenta = 0x4, lightBlue = 0x8, yellow = 0x10, lime = 0x20, pink = 0x40,
        grey = 0x80, lightGrey = 0x100, cyan = 0x200, purple = 0x400, blue = 0x800, brown = 0x1000, green = 0x2000,
        red = 0x4000, black = 0x8000 }
    local inferiorcol = col;
    inferiorcol.gray = col.grey;
    inferiorcol.lightGray = col.lightGrey
    local result = loadLuaFile(fs.combine(sPage, "theme.lua"), { colours = col, colors = inferiorcol })
    if result then
        ctx.theme = result
    end
    -- config
    result = loadLuaFile(fs.combine(sData, "config.lua"))
    if result then
        ctx.config = result
    end
    -- products
    result = loadLuaFile(fs.combine(sData, "products.lua"))
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
        local basaltDL, err, errCode = http.get("https://raw.githubusercontent.com/Kristify/kristify/main/src/libs/basalt.lua"
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
        ctx.logger:error(errormsg)
        nErrors = nErrors+1
        return false
      end
      return true
    end
    
    local function configExpect(name, typ)
        local curTyp = type(ctx.config[name])
        if curTyp ~= typ then
            ctx.logger:error("Bad value for \'"..name.."\' in config; Expected \'"..typ.."\', got \'"..curTyp.."\'.")
            nErrors = nErrors+1
            return false
        elseif curTyp == "string" and ctx.config[name] == "" then
            ctx.logger:warn("Value \'"..name.."\' in config should not be empty.")

        end
        return true
    end
    
    configExpect("pkey", "string")
    if configExpect("name", "string") then
        bAssert(ctx.utils.endsWith(ctx.config.name or "", ".kst"), "Remove \'.kst\' from the name.")
    end
    configExpect("webhooks", "table")
    configExpect("sounds", "table")

    local modem = peripheral.find("modem")
    if not modem then
       ctx.logger:error("Kristify is not connected to a network! (aka. wired modem)")
    elseif type(ctx.config.self) == "string" and modem.getNameLocal() ~= (ctx.config.self or "") then
        ctx.logger:error("Given turtle in config does not exist!")
    else configExpect("self", "string")
    end

    if configExpect("storage", "table") then
        bAssert(#ctx.config.storage==0 or ctx.config.storage[1] == "", "Storage table in config is empty or invalid!")
        for _,inv in pairs(ctx.config.storage) do
            if not peripheral.wrap(inv) then
                ctx.logger:error("Inventory \'"..inv.."\' does not exist!")
                nErrors = nErrors+1
            end
        end
    end
    if configExpect("monSide", "string") then
      bAssert(not peripheral.wrap(ctx.config.monSide), "Given monitor side does not exist!")
    end
    

    -- Load libs, related to peripherals
    ctx.speakerLib = require("speaker")
    ctx.speakerLib.config = ctx.config

    ctx.logger.debug("Loading in inv lib")
    ctx.logger.debug("Configured storage: " .. textutils.serialize(ctx.config.storage))
    ctx.storage = require(fs.combine("libs", "inv"))(ctx.config.storage or {})

    return ctx
end

-- INIT
term.clear()
term.setCursorPos(1, 1)
local args = table.pack(...)
xpcall(function()
    init(table.unpack(args, 1, args.n))
end, function(err)
    ctx.logger:error(err)
end)

-- MAIN
local function execFile(sPath)
    local script, err = loadfile(sPath, "t", _ENV)
    if not script then
        ctx.logger:error(err)
        nErrors = nErrors+1
        return
    end
    local result,output = pcall(script, ctx)
    if not result then
        if output == "terminated" then
            -- Close websockets
            return
        end
        ctx.logger:error(output)
        nErrors = nErrors+1
    end
end

if nErrors == 0 then
    parallel.waitForAny(
        function()
            execFile(fs.combine(sSrc, "backend.lua"))
        end,
        function()
            execFile(fs.combine(sSrc, "frontend.lua"))
        end
    )
end

if nErrors > 0 then
    ctx.logger:warn("\'"..nErrors.."\' error(s). Press any key to exit.")
    sleep(0.5)
    os.pullEvent("key")
end