local ctx = ({...})[1]
local basalt = require("libs/basalt")

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
    --basalt.debug("But nobody came.")
    os.queueEvent("kstUpdateProducts")
end)
basalt.setVariable("selectNewCategory", function()
    basalt.debug("<Insert content>")
end)

-- Create frame
local base = basalt.createFrame()
    :setTheme(ctx.theme)
    :addLayout(fs.combine(ctx.path.page, "index.xml"))

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
            if --[[INSERT CHECK IF IT IS AVAILABLE]] true then
                local newItem = {
                    amount = 1, -- INSERT AVAILABLE AMOUNT
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
        local nW,_ = body:getSize()
        local nSubW,nSubH = dummy:getSize()
        body:removeObject(dummy)
        -- Insert
        local spaceW = nW/nSubW-1
        local nX,nY = 0,0
        for i,item in ipairs(tItems) do
            body:addLayout(fs.combine(ctx.path.page, "widget.xml"))
            local widget = body:getObject("_widget")
                :setPosition(nSubW*nX+1, nSubH*nY+1)
            widget.name = "_widget_"..i

            -- Adjust data
            local name = searchObject(widget, "_name")
                :setText(item.displayName)

            local amount = searchObject(widget, "_onStock")
                :setText(item.amount.."x")

            local button = searchObject(widget, "_purchase")
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
            end
        end
    end
end)

basalt.autoUpdate(base)