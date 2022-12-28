local ctx = ({ ... })[1]
local storage = ctx.storage

local basalt = {}
if not fs.exists(fs.combine(ctx.path.src, "lib", "basalt")) then
    local authenticate = _G._GIT_API_KEY and { Authorization = "Bearer " .. _G._GIT_API_KEY }
    local basaltDL, err, errCode = http.get("https://raw.githubusercontent.com/Kristify/kristify/main/src/libs/basalt.lua"
        , authenticate)
    if not basaltDL then
        ctx.logger:error("Couldn't load Basalt into memory! Reason: \'" ..
            err .. "\' (code " .. errCode.getResponseCode() .. ')')
        return
    end

    basalt = load(basaltDL.readAll())()
    basaltDL.close()
else
    basalt = require("basalt")
end

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

base = basalt.createFrame()

-- Button events
local tItems = {}
local spaceW, spaceH = 1,0
local page = 1
local function updateCatalog()
    local body = searchObject(base, "_body")
    -- Clear
    for i=1,math.floor(((spaceW+1)*spaceH)*page-0.9) do
        local obj = body:getObject("_widget_"..i)
        body:removeObject(obj)
    end
    -- Get size of widget
    local dummy = body:addLayout(fs.combine(ctx.path.page, "widget.xml"))
    dummy = dummy:getObject("_widget")
    local nW, nH = body:getSize()
    local nSubW, nSubH = dummy:getSize()
    body:removeObject(dummy)
    -- Insert
    spaceW, spaceH = nW/nSubW, nH/nSubH
    local nX, nY = 0,0
    for i,item in ipairs(tItems) do
        body:addLayout(fs.combine(ctx.path.page, "widget.xml"))
        local widget = body:getObject("_widget")
            :setPosition(nSubW * nX + 1, nSubH * nY + 1)
        widget.name = "_widget_" .. i

        -- Adjust data
        local all = searchObject(widget, "_all")
        if all then
            all:setText(all:getValue():format(item.displayName, item.amount, item.metaname))
        end
        local name = searchObject(widget, "_name")
        if name then
            name:setText(item.displayName)
        end
        local amount = searchObject(widget, "_stock")
        if amount then
            amount :setText(item.amount)
        end
        local metaname = searchObject(widget, "_metaname")
        if metaname then
            metaname:setText(item.metaname)
        end

        local button = searchObject(widget, "_price")
        local _, h = button:getSize()
        local btnLabel = item.price .. "kst"
        button
            :setText(btnLabel)
            :setSize(#btnLabel + 2, h)
        -- Next grid space
        nX = nX + 1
        if nX >= spaceW then
            nX = 0
            nY = nY + 1
        end
    end
    os.queueEvent("kstUpdated")
end

basalt.setVariable("navBack", function()
    local body = searchObject(base, "_body")
    if body then
        if page > 1 then
            local _,nH = body:getSize()
            body:getScrollAmount()
            local _,nY = body:getOffset()
            body:setOffset(0,nY-nH)
            page = page-1
            lblPage = searchObject(base, "_curPage")
            if lblPage then
                lblPage:setText(""..page)
            end
        end
    end
end)
basalt.setVariable("navNext", function()
    local body = searchObject(base, "_body")
    if body then
        basalt.debug("> "..spaceW.." "..spaceH)
        if page < (#tItems/(spaceW*spaceH)) then
            local _,nH = body:getSize()
            body:getScrollAmount()
            local _,nY = body:getOffset()
            body:setOffset(0,nY+nH)
            page = page+1
            lblPage = searchObject(base, "_curPage")
            if lblPage then
                lblPage:setText(""..page)
            end
        end
    end
end)

-- Create frame
base
    :setMonitor(ctx.config.monSide)
    :setTheme(ctx.theme)
    :addLayout(fs.combine(ctx.path.page, "index.xml"))

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
            local amount = storage.getCount(item.id)
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
    end
end)

os.queueEvent("kstUpdateProducts")
basalt.autoUpdate(base)