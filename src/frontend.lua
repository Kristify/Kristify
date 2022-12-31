local ctx = ({ ... })[1]
local storage = ctx.storage

local basalt = ctx.basalt

local function searchObject(base, id)
    local obj = base:getObject(id)
    if not obj then
        local tAll = base:getLastLayout()
        for _, obj in pairs(tAll) do
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

-- Button functions
local base
--[[
local bubbles = {}
basalt.setVariable("openHelpDialog", function(self)
    ctx.logger:info("Opening help dialog")
    local nW = base:getSize()
    local nX, nY = self:getPosition()
    local nSubW = self:getSize()


    local bubble = base:addLayout(fs.combine(ctx.path.page, "bubble.xml"))
    bubble = searchObject(base, "_bubble")
    bubbles[#bubbles + 1] = bubble
    bubble.name = "_bubble" .. #bubble

    bubble:setSize(10, 2)
    local nBSubW = bubble:getSize()
    bubble
        :setPosition(nX + ((nX > nW / 2) and (-(nBSubW + 1)) or (nSubW + 1)), nY)
        :addThread("_lifetimeTask")
        :start(function()
            for _ = 1, 4 do
                sleep(1)
            end
            base:removeObject(bubble)
            for i, obj in pairs(bubbles) do
                if obj == bubble then
                    table.remove(bubbles, i)
                    break
                end
            end
        end
        )
end)
]]

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

base = basalt.createFrame()

-- Button events
local tItems = {}
local page = 1
local function updateCatalog()
    local body = searchObject(base, "_body")
    local nParW,nParH = body:getSize()
    -- Clear
    local obj = body:getObject("_widget_1")
    local i=2
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
        local widget = searchObject(body, "_widget")
        widget.name = (widget.name).."_"..i

        local nW,nH = widget:getSize()

        local function fill(name,value)
            value = tostring(value)
            local obj = searchObject(widget, name)
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

        local button = searchObject(widget, "_price")
        local _, h = button:getSize()
        local btnLabel = item.price .. "kst"
        button
            :setText(btnLabel)
            :setSize(#btnLabel + 2, h)

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

basalt.setVariable("navBack", function()
    local body = searchObject(base, "_body")
    if page > 1 then
        local _,nH = body:getSize()
        local _,nY = body:getOffset()
        body:setOffset(0,nY-nH+1)
        page = page-1
        lblPage = searchObject(base, "_curPage")
        if lblPage then
            lblPage:setText(""..page)
        end
    end
end)
basalt.setVariable("navNext", function()
    local body = searchObject(base, "_body")
    local nMax = body:getScrollAmount()
    local _,nH = body:getSize()
    local _,nY = body:getOffset()

    if nY > nMax then return end
    body:setOffset(0,nY+nH-1)
    page = page+1
    lblPage = searchObject(base, "_curPage")
    if lblPage then
        lblPage:setText(""..page)
    end
end)

-- Create frame
base:setMonitor(ctx.config.monSide)
    :setTheme(ctx.theme)
smartLoadLayout(base, "index")

-- Adjust theme
local title = searchObject(base, "_title")
local nW,nX = 51,20
if title then
    title:setText(ctx.config.name)
    nW = title:getSize()
    nX = title:getPosition()
end

local titleEnd = searchObject(base, "_title_end")
if titleEnd then
    local _, nY = titleEnd:getPosition()
    titleEnd:setPosition(nX + nW * title:getFontSize(), nY)
end

local watermark = searchObject(base, "_watermark")
if watermark then
    watermark:setText("Kristify")
end

local helpBtn = searchObject(base, "_helpButton")
if helpBtn then
    helpBtn:setText("?")
end

local page = searchObject(base, "_curPage")
if page then
    page:setText("1")
end

local msg = searchObject(base, "_importantMSG")
if msg then
    msg:setText("Pay to <metaname>@"..ctx.config.name..".kst for a purchase!")
end

local subtitle = searchObject(base, "_subtitle")
if subtitle then
    base:addThread("_moveSubtitle")
        :start(function()
            local nW = subtitle:getSize()
            if #ctx.config.tagline <= nW then
                subtitle:setText(ctx.config.tagline)
                return
            end

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
                subtitle:setText(ctx.config.tagline:sub(i))
                sleep(0.2)
            end
        end
    )
end

-- Event
basalt.onEvent(function(event)
    if event == "kstUpdateProducts" then
        ctx.logger:debug("Received event: kstUpdateProducts. Will refresh cache")
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
        os.queueEvent("kstUpdated")
    end
end)

os.queueEvent("kstUpdateProducts")
basalt.autoUpdate(base)