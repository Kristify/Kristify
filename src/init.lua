-- make a copy of package.path
local sSrc = fs.getDir(shell.getRunningProgram())
local sRoot = fs.combine(sSrc,"..")
local sData = fs.combine(sRoot,"data")
local sFont = fs.combine(sData,"font")
local sPage = fs.combine(sData,"pages")

local basalt = require("basalt")
local bdf = require("basalt/libraries/miniBDF")
local ctx

local function init(...)
    -- [Context]
    ctx = {gui={},theme={},config={},pages={},current=1,scroll=0,redraw=true}
    
    -- [Fonts]
    fontBDF = {}
    if fs.exists(sFont) and fs.isDir(sFont) then
        local fonts = fs.list(sFont)
        for i=1,#fonts do
            local tmp = bdf.loadBDF(fs.combine(sFont,fonts[i]))
            local count,msg = bdf.checkFont(tmp)
            if count > 0 then
                printError("Could not load font \'"..fonts[i].."\'!")
                for j=1,#msg do
                    printError(" * "..msg[j])
                end
                sleep(1)
            else
                fontBDF[tmp.name] = tmp
            end
        end
    end

    -- [Pages]
    local pages = fs.list(sPage)
    for i=1,#pages do
        local f = fs.open(fs.combine(sPage,pages[i]), 'r')
        ctx.pages[pages[i]] = f.readAll()
        f.close()
    end

    -- [Data] (config,theme,products, etc.)
    local function loadLuaFile(path, env)
        if fs.exists(path) and not fs.isDir(path) then
            
            local success,result = pcall( loadfile(path, "t", env) )
            if success and type(result) == "table" then
                return result
            else
                printError("Could not load \'"..fs.getName(path).."\' properly!\n"..tostring(theme))
                sleep(1)
            end
        end
        return false
    end
    -- theme
    local col = {white=0x1,orange=0x2,magenta=0x4,lightBlue=0x8,yellow=0x10,lime=0x20,pink=0x40,grey=0x80,lightGrey=0x100,cyan=0x200,purple=0x400,blue=0x800,brown=0x1000,green=0x2000,red=0x4000,black=0x8000}
    local inferiorcol=col; inferiorcol.gray=col.grey; inferiorcol.lightGray=col.lightGrey
    local result = loadLuaFile(fs.combine(sPage,"theme.lua"), {colours=col,colors=inferiorcol})
    if not result then return end
    ctx.theme = result
    -- config
    local result = loadLuaFile(fs.combine(sData,"config.lua"))
    if not result then return end
    ctx.config = result


    return ctx
end

local function main(ctx)
    local base = basalt.createFrame()
        :setTheme(ctx.theme)
        :addLayout(fs.combine(sPage,"index.xml"))

    ---Saves the current proucts states into the file
    ---and loads them into the interface.
    local function updateProducts()

    end

    local sCurPage = ""
    parallel.waitForAny(
    basalt.autoUpdate,
        function()
            local menubar = base:getDeepObject("main-menubar")
            local displayPage = base:getDeepObject("main-content")

            if not (menubar or displayPage) then
                return printError("Content is missing in index.xml!\nMake sure the following things are there:\n * Menubar | id=\"main-menubar\"\n * Frame   | id=\"main-content\"")
            end

            while true do
                -- Change pages
                local tmpPage = menubar:getItem(menubar:getItemIndex()).text
                if tmpPage ~= sCurPage then
                    sCurPage = tmpPage
                    local oldLayout = displayPage:getLastLayout()
                    for _,v in pairs(oldLayout) do
                        displayPage:removeObject(v)
                    end

                    displayPage:addLayoutFromString(ctx.pages[sCurPage:lower()..".xml"])
                    -- Go through layout and replace stuff with our content
                    local function repalceContent(layout)
                        for _,object in pairs(layout) do
                            -- Is frame?
                            if object.addLayout then
                                local subLayout = object:getLastLayout()
                                repalceContent(subLayout)
                            -- Is something we are looking for?
                            elseif object.setText then
                                local id = object:getName()
                                local txt = object:getValue()
                                if id:find("subtitle") then
                                    object:setText(string.format(txt,ctx.config.details.description))
                                elseif id:find("title") then
                                    object:setText(string.format(txt,ctx.config.details.title))
                                end
                            end
                        end
                    end

                    local layout = displayPage:getLastLayout()
                    repalceContent(layout)
                end

                -- Update products
                if updateContent then

                    updateContent = false
                end
                sleep()
            end
        end
    )
end


-- INIT
local noErrors = true
local args = table.pack(...)
xpcall(function()
    init(table.unpack(args,1,args.n))
end,function(err)
    printError(err)
    noErrors=false
end)

-- MAIN
if noErrors then
    xpcall(function()
        main(ctx)
    end,function(err)
        printError(err)
    end)
end