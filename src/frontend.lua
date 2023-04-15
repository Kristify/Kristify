local ctx = ({ ... })[1]
local storage = ctx.storage
local speaker = ctx.speakerLib
local basalt = ctx.basalt

-- Button functions
local base
local function smartLoadLayout(frame, path)
    local pathLUA = fs.combine(ctx.path.page, path..".lua")
    local pathXML = fs.combine(ctx.path.page, path..".xml")
    if fs.exists(pathLUA) then
        local file = fs.open(pathLUA, "r")
        local data = file.readAll()
        file.close()
        local func,err = load(data, path, "bt", _ENV)
        if not func then
            ctx.logger:error("Could not load layout \'data/"..path..".lua\'! ("..err..")")
            return
        end
        local success,obj = pcall(func,ctx,frame)
        if not success then
            ctx.logger:error(obj)
            return
        end
        frame:addObject(obj)
    elseif fs.exists(pathXML) then
        frame:addLayout(pathXML)
    else
        ctx.logger:error("Layout \'data/"..path.."\' does not exist!")
    end
    return frame
end

-- Create frame
ctx.logger:debug("Attatching monitor and loading layout.")
base = basalt.createFrame()
local mon = peripheral.wrap(ctx.config.monSide)
mon.setTextScale(ctx.config.monScale or 0.5)

base:setMonitor(ctx.config.monSide)
    :setTheme(ctx.theme)
smartLoadLayout(base, "index")

-- Catalog refresh
local tItems = {}
local page = 1
local function updateCatalog()
    local body = base:getDeepObject("_body")
    local nParW,nParH = body:getSize()
    -- Clear
    local obj = body:getObject("_widget_1")
    local i=1
    repeat
        if obj then
            body:removeObject(obj)
        end
        obj = body:getObject("_widget_"..i)
        i = i+1
    until obj == nil

    basalt.drawFrames()

    -- Refill
    local nScreenX, nScreenY = 1,1
    for i,item in ipairs(tItems) do
        -- Load widget template
        smartLoadLayout(body, "widget")
        local widget = base:getDeepObject("_widget")
        widget.name = (widget.name).."_"..i

        local nW,nH = widget:getSize()

        local function fill(name,value)
            value = tostring(value)
            local obj = widget:getDeepObject(name)
            if not obj then return end
            obj:setValue(value)

            local nX,_ = obj:getPosition()
            value = tostring(obj:getValue())
            if #value+nX+1 >= nW then
                widget:setSize(#value+nX+1, nH)
                nW,nH = #value+nX+1, nH
            end

            return obj
        end

        -- Fill data
        local name = fill("_name",item.displayName)
        fill("_stock",item.amount)
        fill("_metaname",item.metaname)

        -- Name color
        if type(item.color) == "string" then
            name:setForeground(colors[item.color])
        end

        -- Price
        local button = widget:getDeepObject("_price")
        local _, h = button:getSize()
        local btnLabel = item.price .. "kst"
        button
            :setText(btnLabel)
            :setSize(#btnLabel + 2, h)

        -- Frame clicking
        widget:onClick(function()
            local info = base:getDeepObject("_importantMSG")
            if info then
                info:setText("Pay to "..item.metaname.."@"..ctx.config.name..".kst for a purchase!")
                speaker:play("click")
            end
        end)

        widget:setPosition(nScreenX,nScreenY)
        -- Next Position
        nScreenX = nScreenX+nW
        if nScreenX > nParW then
            nScreenY = nScreenY+nH
            nScreenX = 1+nW
            widget:setPosition(1,nScreenY)
        end
    end
end

--Button events
basalt.setVariable("navBack", function()
    local body = base:getDeepObject("_body")
    if page > 1 then
        speaker:play("click")
        local _,nH = body:getSize()
        local _,nY = body:getOffset()
        body:setOffset(0,nY-nH+1)
        page = page-1
        lblPage = base:getDeepObject("_curPage")
        if lblPage then
            lblPage:setText(""..page)
        end
    end
end)
basalt.setVariable("navNext", function()
    local body = base:getDeepObject("_body")
    local nMax = body:getScrollAmount()
    local _,nH = body:getSize()
    local _,nY = body:getOffset()

    if nY > nMax then return end
    speaker:play("click")
    body:setOffset(0,nY+nH-1)
    page = page+1
    lblPage = base:getDeepObject("_curPage")
    if lblPage then
        lblPage:setText(""..page)
    end
end)

-- Adjust theme
ctx.logger:debug("Adjust theme by config file")
local title = base:getDeepObject("_title")
local factor = 1
local nW,nX = 51,20
if title then
    factor = title:getFontSize()
    title:setText(ctx.config.name)
    nW = title:getSize()
    nX = title:getPosition()
    basalt.drawFrames()
end

local titleEnd = base:getDeepObject("_title_end")
if titleEnd then
    local _, nY = titleEnd:getPosition()
    titleEnd:setPosition(nX+(math.floor(nW*factor)), nY)
end

local watermark = base:getDeepObject("_watermark")
if watermark then
    watermark:setText("Kristify")
end

local helpBtn = base:getDeepObject("_helpButton")
if helpBtn then
    helpBtn:setText("?")
end

local page = base:getDeepObject("_curPage")
if page then
    page:setText("1")
end

local msg = base:getDeepObject("_importantMSG")
if msg then
    msg:setText("Pay to <metaname>@"..ctx.config.name..".kst for a purchase!")
end

-- Subtitle scrolling/repositioning
local subtitle = base:getDeepObject("_subtitle")
local scroller = function() while true do sleep(10) end end
local nW,nH = subtitle:getSize()
if subtitle and nH > 1 and #(ctx.config.tagline) >= nW then
    scroller = function()
        local i, cooldown = 1, 7
        while true do
            if cooldown <= 0 then
                i = i + 1
                if i > (#ctx.config.tagline) + 5 then
                    i = 1
                    cooldown = 7
                end
            else
                cooldown = cooldown - 1
            end
            subtitle:setText((ctx.config.tagline):sub(i))
            sleep(0.12)
        end
    end
else
    subtitle:setText((' '):rep(nW/2-(#ctx.config.tagline)/2)..ctx.config.tagline)
end
os.queueEvent("kristify:IndexLoaded")

-- Event
basalt.onEvent(function(event)
    if event == "kstUpdateProducts" then
        ctx.logger:debug("Received event: kstUpdateProducts; Refresh cache")
        storage.refreshStorage(true)
        os.queueEvent("kristify:storageRefreshed")
        -- Sort
        tItems = {}
        for _, item in ipairs(ctx.products) do
            local amount = storage.getCount(item.id, item.nbt)
            if amount ~= 0 then
                local newItem = {
                    amount = amount
                }
                for k, v in pairs(item) do
                    newItem[k] = v
                end
                tItems[#tItems + 1] = newItem
            end
        end
        table.sort(tItems, function(a, b)
            return a.amount > b.amount
        end)

        updateCatalog()
        os.queueEvent("kristify:CatalogUpdated")
    elseif event == "kristify:exit" then
        basalt.stopUpdate()
        mon.clear()
    end
end)

os.queueEvent("kstUpdateProducts")
parallel.waitForAny(
    function()
        basalt.autoUpdate(base)
    end,
    scroller
)