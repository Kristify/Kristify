-- make a copy of package.path
local sSrc = fs.getDir(shell.getRunningProgram())
local sRoot = fs.combine(sSrc,"..")
local sData = fs.combine(sRoot,"data")
local sFont = fs.combine(sData,"fonts")
local sImg = fs.combine(sData,"images")
local sPage = fs.combine(sData,"pages")

local basalt = require("basalt")
local bdf = require("basalt/libraries/miniBDF")
local ctx

local function purchase(self,event,button,x,y)
    if event == "mouse_click" and button == 1 then
        local metadata = self:getMetadata()
        if metadata.id then
            -- TODO Open popup that tells user where to send krist to get item
            basalt.debug("Item: "..ctx.products[metadata.id].displayName)
        end
    end
end

local function init(...)
    -- [Context]
    ctx = {gui={},image={},products={},theme={},config={},pages={},current=1,scroll=0,redraw=true}

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
    local function loadStr(str, begin, env)
        if not begin then begin = "" end
        local success,result = pcall( loadstring(begin..str, "t", env) )
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
                printError("Could not load \'"..path.."\' properly!\n"..tostring(result))
                sleep(1)
            end
            return result
        else
            printError("Could not load \'"..path.."\'!")
            sleep(0.5)
        end
        return false
    end
    -- theme
    local col = {white=0x1,orange=0x2,magenta=0x4,lightBlue=0x8,yellow=0x10,lime=0x20,pink=0x40,grey=0x80,lightGrey=0x100,cyan=0x200,purple=0x400,blue=0x800,brown=0x1000,green=0x2000,red=0x4000,black=0x8000}
    local inferiorcol=col; inferiorcol.gray=col.grey; inferiorcol.lightGray=col.lightGrey
    local result = loadLuaFile(fs.combine(sPage,"theme.lua"), {colours=col,colors=inferiorcol})
    if result then
        ctx.theme = result
    end
    -- bimg
    local files = fs.list(sImg)
    for i=1,#files do
        if files[i]:sub(-4) == "bimg" then
            local f = fs.open(fs.combine(sImg,files[i]), 'r')
            local c = f.readAll()
            f.close()
            local result = loadStr(c, "return ", {colours=col,colors=inferiorcol})
            if result then
                ctx.image[files[i] or (#ctx.image+1)] = result
            end
        end
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

    -- [Purchase]
    basalt.setVariable("purchase", purchase)

    return ctx
end


---Saves the current proucts states into the file
---and loads them into the interface.
local function updateProducts()
end

---Checks if a given table has all keys inside it, building a chain with each other.
---@param ctx table The table to inspect
---@param ... any The keys to check
---@return boolean status true if all keys are there and false if not
local function checkTableTree(ctx, ...)
    local tmp = ctx
    for _,key in pairs({...}) do
        if tmp[key] then
            tmp = tmp[key]
        else
            return false
        end
    end
    return true
end

---Go through layout and replace stuff with our content
---@param page table The Basalt frame layout
local function insertData(page,ctx)
    local layout = page:getLastLayout()
    local function repalceContent(layout)
        for _,object in pairs(layout) do
            -- Is frame?
            if object.addLayout then
                id = object:getName()
                -- Is frame for products?
                if id:find("products") then
                    local listHeight = 1
                    local nW,nH = object:getSize()
                    for i,product in pairs(ctx.products) do
                        if product.displayName and product.price and product.description then
                            local item = object:addFrame(tostring(i))
                            :setPosition(1,listHeight)
                            :setSize(nW,3)
                            :setBackground(colors.gray)
                            local offX = 0
                            -- Image
                            local bimg = {}
                            for k,v in pairs(ctx.image["missing.bimg"]) do
                                bimg[k] = v
                            end
                            if product.bimg then
                                if type(product.bimg) == "table" then
                                    bimg[1] = product.bimg
                                elseif type(product.bimg) == "string" then
                                    bimg = fs.combine(sImg,product.bimg)
                                end
                            end
                            if bimg then
                                local img = item:addBimg()
                                    :setPosition(1,1)
                                    :loadImage(bimg)
                                local x,y = img:getSize()
                                offX = x+2
                            end
                            -- Title
                            item:addLabel()
                                :setText(product.displayName)
                                :setPosition(2+offX,1)
                                :setSize(1,nW-(6+offX),1)
                                :setBackground(colors.gray)
                            -- Description
                            item:addLabel()
                                :setText(product.description)
                                :setPosition(2+offX,2)
                                :setSize(2,nW-(6+offX),1)
                                :setForeground(colors.lightGray)
                                :setBackground(colors.gray)
                            -- Button
                            item:addButton()
                                :setText("BUY")
                                :setPosition(nW-6,1)
                                :setSize(7,3)
                                :setForeground(colors.white)
                                :setBackground(colors.green)
                                :setMetadata({
                                    id = i
                                })
                                :onClick(purchase)


                            listHeight = listHeight+4
                        end
                    end
                    object:setSize(nW,listHeight)
                -- Look into frame for other stuff
                else
                    local subLayout = object:getLastLayout()
                    repalceContent(subLayout)
                end
            -- Is something else we are looking for?
            elseif object.setText then
                local id = object:getName()
                local txt = object:getValue()
                if id:find("subtitle") then
                    if checkTableTree(ctx,"config","details","description") then
                        object:setText(string.format(txt,ctx.config.details.description))
                    end
                elseif id:find("title") then
                    if checkTableTree(ctx,"config","details","title") then
                        object:setText(string.format(txt,ctx.config.details.title))
                    end
                end
            end
        end
    end
    repalceContent(layout)
end


local function main(ctx)
    local base = basalt.createFrame()
        :setTheme(ctx.theme)
        :addLayout(fs.combine(sPage,"index.xml"))

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
                    insertData(displayPage,ctx)
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

