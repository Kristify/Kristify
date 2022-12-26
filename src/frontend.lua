local ctx = ({...})[1]
local basalt = require("libs/basalt")

local storage = require(fs.combine("libs", "inv"))(ctx.config.storage)
storage.refreshStorage()

local function searchObject(base, id)
    local obj = base:getObject(id)
    if not obj then
        local tAll = base:getLastLayout()
        for _,obj in pairs(tAll) do
            if obj and obj.getType and obj.getType() == "Frame" then
                local found = searchObject(obj, id)
                if found then
                    return found
                end
            end
        end
    end
    return obj
end

-- Button functoins
basalt.setVariable("openHelpDialog", function()
    basalt.debug("But nobody came.")
end)

-- Create frame
local base = basalt.createFrame()
    :setMonitor(ctx.config.monSide)
    :setTheme(ctx.theme)
    :addLayout(fs.combine(ctx.path.page, "index.xml"))

-- Adjust theme
local title = searchObject(base, "_title")
    :setText("@"..ctx.config.name)
local nW = title:getSize()
local nX = title:getPosition()

local titleEnd = searchObject(base, "_title_end")
local _,nY = titleEnd:getPosition()
titleEnd:setPosition(nX+nW*title:getFontSize(), nY)

local watermark = searchObject(base, "_watermark")
    :setText("Kristify")

local helpBtn = searchObject(base, "_helpButton")
    :setText("?")

local subtitle = searchObject(base, "_subtitle")

local moveSubtitle = base:addThread()
    :start(function()
        local nW = subtitle:getSize()
        if #ctx.config.tagline <= nW then return end
        
        local i,cooldown = 1,7
        while true do
            if cooldown <= 0 then
                i = i+1
                if i > (#ctx.config.tagline)+5 then
                    i = 1
                    cooldown = 7
                end
            else
                cooldown = cooldown-1
            end
            subtitle:setText(ctx.config.tagline:sub(i))
            sleep(0.2)
        end 
    end
)

-- Events
basalt.onEvent(function(event)
    if event == "kstUpdateProducts" then
        local body = searchObject(base, "_body")
        -- Clear
        repeat
            local obj = body:getObject("_widget")
            body:removeObject(obj)
        until not obj
        -- Sort
        local tItems = {}
        for _,item in ipairs(ctx.products) do
            local amount = storage.getCount(item.id)
            if amount ~= 0 then
                local newItem = {
                    amount = amount
                }
                for k,v in pairs(item) do
                    newItem[k] = v
                end
                tItems[#tItems+1] = newItem
            end
        end
        table.sort(tItems, function(a,b)
            return a.amount > b.amount
        end)
        -- Get size of widget
        local dummy = body:addLayout(fs.combine(ctx.path.page, "widget.xml"))
        dummy = dummy:getObject("_widget")
        local nW,nH = body:getSize()
        local nSubW,nSubH = dummy:getSize()
        body:removeObject(dummy)
        -- Insert
        local spaceW,spaceH = nW/nSubW-1, nH/nSubH-1
        local nYOff = (spaceH <= 1) and (nH/2)-(nSubH/2) or 0
 
        local nX,nY = 0,0
        for i,item in ipairs(tItems) do
            body:addLayout(fs.combine(ctx.path.page, "widget.xml"))
            local widget = body:getObject("_widget")
                :setPosition(nSubW*nX+1, nSubH*nY+1+nYOff)
            widget.name = "_widget_"..i

            -- Adjust data
            local name = searchObject(widget, "_name")
                :setText(item.displayName)

            local amount = searchObject(widget, "_stock")
                :setText(item.amount)
            local metaname = searchObject(widget, "_metaname")
                :setText(item.metaname)

            local button = searchObject(widget, "_price")
            local _,h = button:getSize()
            local btnLabel = item.price.."kst"
            button
                :setText(btnLabel)
                :setSize(#btnLabel+2,h)

            -- Next grid space
            nX = nX+1
            if nX > spaceW then
                nX = 0
                nY = nY+1
                if nY >= spaceH then
                    break
                end
            end
        end
    end
end)

os.queueEvent("kstUpdateProducts")
basalt.autoUpdate(base)