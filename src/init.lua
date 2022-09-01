-- make a copy of package.path
local old_path = package.path
local sPath = fs.getDir(shell.getRunningProgram())
local sData = fs.combine(sPath,"data")
local basalt = require("basalt")
local ctx

package.path = string.format(
    "/%s/?.lua;/rom/modules/main/?.lua", sPath
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

    -- load colors
    local f = fs.open(fs.combine(sData,"color.table"), 'r')
    local content = f.readAll()
    f.close()

    local col = {white=0x1,orange=0x2,magenta=0x4,lightBlue=0x8,yellow=0x10,lime=0x20,pink=0x40,grey=0x80,lightGrey=0x100,cyan=0x200,purple=0x400,blue=0x800,brown=0x1000,green=0x2000,red=0x4000,black=0x8000}
    local inferiorcol=col; inferiorcol.gray=col.grey; inferiorcol.lightGray=col.lightGrey
    local b,colors = pcall( load("return "..content,"","t",{colours=col,colors=inferiorcol}) )
    if type(colors) == "table" and b then
        ctx.color = colors
    end

    return ctx
end

-- INIT
local args = table.pack(...)
xpcall(function()
    init(table.unpack(args,1,args.n))
end,function(err)
    printError(err)
end)

-- MAIN
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
        LabelText = colors.white
    })
    :addLayout(fs.combine(sData,"index.xml"))

local displayPage =base:getDeepObject("main-content")
local sCurPage = ""
parallel.waitForAny(
    basalt.autoUpdate,
    function()
        while true do
            local scrollbar = base:getDeepObject("main-scroll")
            local menubar = base:getDeepObject("main-menubar")
            
            local tmpPage = menubar:getItem(menubar:getItemIndex()).text
            if tmpPage ~= sCurPage then
                sCurPage = tmpPage
                local oldLayout = displayPage:getLastLayout()
                for _,v in pairs(oldLayout) do
                    displayPage:removeObject(v)
                end
                displayPage:addLayoutFromString(ctx.pages[sCurPage:lower()..".xml"])
            end

            displayPage:setOffset(0, scrollbar:getIndex()-1)
            sleep()
        end
    end
)


-- restores package path to original
package.path = old_path