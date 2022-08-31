-- make a copy of package.path
local old_path = package.path
local sPath = fs.getDir(shell.getRunningProgram())
local ctx

package.path = string.format(
    "/%s/?.lua;/rom/modules/main/?.lua", sPath
)
local function init(...)
    ctx = {gui={},pages={},current=1,scroll=0,redraw=true}
    local sGui = fs.combine(sPath,"gui")
    local sData = fs.combine(sPath,"data")
    local sPages = fs.combine(sData,"pages")
    
    -- load widgets
    local widgets = fs.list(sGui)
    for i=1,#widgets do
        local _,nX = widgets[i]:find('%.')
        if nX then widgets[i] = widgets[i]:sub(1,nX-1) end

        local tmp = require(fs.combine(sGui,widgets[i]))
        ctx.gui[widgets[i]] = {}
        for k,v in pairs(tmp) do
            ctx.gui[widgets[i]][k] = v
        end
    end

    -- load pages
    local pages = fs.list(sPages)
    for i=1,#pages do
        local f = fs.open(fs.combine(sPages,pages[i]), 'r')
        local content = f.readAll()
        f.close()

        content = textutils.unserialise(content)
        if type(content) == "table" then
            content.length = 0
            if pages[i] == "index.table" then
                table.insert(ctx.pages, 1, content)
            else
                table.insert(ctx.pages, content)
            end
        end
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
xpcall(function()
    parallel.waitForAny(
        function()
            while true do
                ctx.gui.render.draw(ctx.pages[1],ctx)
                sleep()
            end
        end,
        function()
            while true do
                local _,h = term.getSize()
                local event = {os.pullEvent()} -- CHANGE TO pullEventRaw later!!!!!
                ctx.redraw = true
                if event[1] == "mouse_scroll" then
                    if ctx.pages[1].length > h then
                        ctx.scroll = ctx.scroll-event[2]
                        if ctx.scroll > 0 then
                            ctx.scroll = 0
                        elseif ctx.scroll < -(ctx.pages[1].length) then
                            ctx.scroll = -(ctx.pages[1].length)
                        end
                    end
                end
            end
        end
    )
end,function(err)
    printError(err)
end)

-- restores package path to original
package.path = old_path