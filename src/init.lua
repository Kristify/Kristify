-- make a copy of package.path
local old_path = package.path
local sSrc = fs.getDir(shell.getRunningProgram())
local sRoot = fs.combine(sSrc,"..")
local sData = fs.combine(sRoot,"data")
local basalt = require("basalt")
local ctx

package.path = string.format(
    "/%s/?.lua;/rom/modules/main/?.lua", sSrc
)
local function init(...)
    ctx = {gui={},pages={},current=1,scroll=0,redraw=true}
    
    -- load pages
    local pages = fs.list(fs.combine(sData,"pages"))
    for i=1,#pages do
        local f = fs.open(fs.combine(sData,"pages",pages[i]), 'r')
        ctx.pages[pages[i]] = f.readAll()
        f.close()
    end

    -- load products


    return ctx
end

-- INIT
local args = table.pack(...)
xpcall(function()
    init(table.unpack(args,1,args.n))
end,function(err)
    printError(err)
end)

-- Create basalt index page
local base = basalt.createFrame()
    :setTheme({
        FrameBG = colors.black,
        MenubarBG = colors.cyan,
        MenubarText = colors.white,
        SelectionText = colors.white,
        SelectionBG = colors.black,
        ListBG = colors.gray,
        ListText = colors.black,
        LabelBG = colors.black,
        LabelText = colors.white,
        ScrollbarText = colors.black,
        ScrollbarBG = colors.gray,
        ScrollbarSymbolColor = colors.lightGray
    })
    :addLayout(fs.combine(sData,"index.xml"))

---Saves the current proucts states into the file
---and loads them into the interface.
local function updateProducts()

end

local sCurPage = ""
-- MAIN LOOP
parallel.waitForAny(
    basalt.autoUpdate,
    function()
        local scrollbar = base:getDeepObject("main-scroll")
        local menubar = base:getDeepObject("main-menubar")
        local displayPage = base:getDeepObject("main-content")

        -- Background
        local bg = ""
        local updateContent = true
        local w,h = term.getSize()
        for y=1,h do
            bg = bg..('\127'):rep(w-1)..' '
        end
        bg = displayPage:addLabel()
            :setBackground(colors.black)
            :setForeground(colors.gray)
            :setText(bg)
            :setSize(w-1,h-1)
            :setPosition(1,1)

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
            end

            -- Update products
            if updateContent then
                
                updateContent = false
            end

            -- Scrolling
            bg:setPosition(1, scrollbar:getIndex()-1)
            displayPage:setOffset(0, scrollbar:getIndex()-1)
            sleep()
        end
    end
)


-- restores package path to original
package.path = old_path