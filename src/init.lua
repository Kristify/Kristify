-- make a copy of package.path
local sSrc = fs.getDir(shell.getRunningProgram())
local sRoot = fs.combine(sSrc, "..")
local sData = fs.combine(sRoot, "data")
local sPage = fs.combine(sData, "pages")

local ctx

local function init(...)
    -- [Context]
    ctx = { products = {}, theme = {}, config = {}, pages = {} }
    ctx.path = {
        page = sPage,
        src = sSrc,
        data = sData
    }

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
                printError("Could not load \'" .. path .. "\' properly!\n" .. tostring(result))
                sleep(1)
            end
            return result
        else
            printError("Could not load \'" .. path .. "\'!")
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
    local result = loadLuaFile(fs.combine(sPage,"theme.lua"), { colours = col, colors = inferiorcol })
    if result then
        ctx.theme = result
    end
    -- config
    result = loadLuaFile(fs.combine(sData,"config.lua"))
    if result then
        ctx.config = result
    end
    -- products
    result = loadLuaFile(fs.combine(sData,"products.lua"))
    if result then
        ctx.products = result
    end

    -- Set debug mode
    settings.define("kristify.debug", {
        description = "If kristify should be debugging",
        default = false,
        type = "boolean"
    })

    -- Load scripts
    ctx.kristly = require(fs.combine("libs","kristly"))
    ctx.utils = require("utils")
    ctx.logger = require("logger"):new({ debugging = settings.get("kristify.debug") })
    ctx.webhooks = require("webhook")
    ctx.speakerLib = require("speaker")
    ctx.storage = require(fs.combine("libs","inv"))(ctx.config.storage)

    return ctx
end

-- INIT
local args = table.pack(...)
xpcall(function()
    init(table.unpack(args, 1, args.n))
end, function(err)
    printError(err)
    return
end)

-- MAIN
local function execFile(sPath)
    local script, err = loadfile(sPath, "t", _ENV)
    if not script then
        ctx.logger:error(err)
    end
    script(ctx)
end

parallel.waitForAny(
    function()
        execFile(fs.combine(sSrc, "backend.lua"))
    end,
    function()
        execFile(fs.combine(sSrc, "frontend.lua"))
    end
)