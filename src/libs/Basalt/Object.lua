local basaltEvent = require("basaltEvent")
local utils = require("utils")
local split = utils.splitString
local numberFromString = utils.numberFromString
local xmlValue = utils.getValueFromXML

return function(name)
    -- Base object
    local objectType = "Object" -- not changeable
    local object = {}
    local zIndex = 1
    local value
    local anchor = "topLeft"
    local ignOffset = false
    local isVisible = true
    local initialized = false

    local shadow = false
    local borderColors = {
        left = false,
        right = false,
        top = false,
        bottom = false
    }

    local shadowColor = colors.black
    local isEnabled = true
    local isDragging = false
    local dragStartX, dragStartY, dragXOffset, dragYOffset = 0, 0, 0, 0

    local draw = true
    local activeEvents = {}

    local eventSystem = basaltEvent()

    object = {
        x = 1,
        y = 1,
        width = 1,
        height = 1,
        bgColor = colors.black,
        bgSymbol  = " ",
        bgSymbolColor = colors.black,
        fgColor = colors.white,
        transparentColor = false,
        name = name or "Object",
        parent = nil,

        show = function(self)
            isVisible = true
            self:updateDraw()
            return self
        end;

        hide = function(self)
            isVisible = false
            self:updateDraw()
            return self
        end,

        enable = function(self)
            isEnabled = true
            return self
        end,

        disable = function(self)
            isEnabled = false
            return self
        end,

        isEnabled = function(self)
            return isEnabled
        end,

        generateXMLEventFunction = function(self, func, val)
            local createF = function(str)
                if(str:sub(1,1)=="#")then
                    local o = self:getBaseFrame():getDeepObject(str:sub(2,str:len()))
                    if(o~=nil)and(o.internalObjetCall~=nil)then
                        func(self,function()o:internalObjetCall()end)
                    end
                else
                    func(self,self:getBaseFrame():getVariable(str))
                end
            end
            if(type(val)=="string")then
                createF(val)
            elseif(type(val)=="table")then
                for k,v in pairs(val)do
                    createF(v)
                end
            end
            return self
        end,

        setValuesByXMLData = function(self, data)
            local baseFrame = self:getBaseFrame()
            if(xmlValue("x", data)~=nil)then self:setPosition(xmlValue("x", data), self.y) end
            if(xmlValue("y", data)~=nil)then self:setPosition(self.x, xmlValue("y", data)) end
            if(xmlValue("width", data)~=nil)then self:setSize(xmlValue("width", data), self.height) end
            if(xmlValue("height", data)~=nil)then self:setSize(self.width, xmlValue("height", data)) end
            if(xmlValue("bg", data)~=nil)then self:setBackground(colors[xmlValue("bg", data)]) end
            if(xmlValue("fg", data)~=nil)then self:setForeground(colors[xmlValue("fg", data)]) end
            if(xmlValue("value", data)~=nil)then self:setValue(colors[xmlValue("value", data)]) end
            if(xmlValue("visible", data)~=nil)then if(xmlValue("visible", data))then self:show() else self:hide() end end
            if(xmlValue("enabled", data)~=nil)then if(xmlValue("enabled", data))then self:enable() else self:disable() end end
            if(xmlValue("zIndex", data)~=nil)then self:setZIndex(xmlValue("zIndex", data)) end
            if(xmlValue("anchor", data)~=nil)then self:setAnchor(xmlValue("anchor", data)) end
            if(xmlValue("shadowColor", data)~=nil)then self:setShadow(colors[xmlValue("shadowColor", data)]) end
            if(xmlValue("border", data)~=nil)then self:setBorder(colors[xmlValue("border", data)]) end
            if(xmlValue("borderLeft", data)~=nil)then borderColors["left"] = xmlValue("borderLeft", data) end
            if(xmlValue("borderTop", data)~=nil)then borderColors["top"] = xmlValue("borderTop", data) end
            if(xmlValue("borderRight", data)~=nil)then borderColors["right"] = xmlValue("borderRight", data) end
            if(xmlValue("borderBottom", data)~=nil)then borderColors["bottom"] = xmlValue("borderBottom", data) end
            if(xmlValue("borderColor", data)~=nil)then self:setBorder(colors[xmlValue("borderColor", data)]) end
            if(xmlValue("ignoreOffset", data)~=nil)then if(xmlValue("ignoreOffset", data))then self:ignoreOffset(true) end end
            if(xmlValue("onClick", data)~=nil)then self:generateXMLEventFunction(self.onClick, xmlValue("onClick", data)) end
            if(xmlValue("onClickUp", data)~=nil)then self:generateXMLEventFunction(self.onClickUp, xmlValue("onClickUp", data)) end
            if(xmlValue("onScroll", data)~=nil)then self:generateXMLEventFunction(self.onScroll, xmlValue("onScroll", data)) end
            if(xmlValue("onDrag", data)~=nil)then self:generateXMLEventFunction(self.onDrag, xmlValue("onDrag", data)) end
            if(xmlValue("onKey", data)~=nil)then self:generateXMLEventFunction(self.onKey, xmlValue("onKey", data)) end
            if(xmlValue("onKeyUp", data)~=nil)then self:generateXMLEventFunction(self.onKeyUp, xmlValue("onKeyUp", data)) end
            if(xmlValue("onChange", data)~=nil)then self:generateXMLEventFunction(self.onChange, xmlValue("onChange", data)) end
            if(xmlValue("onResize", data)~=nil)then self:generateXMLEventFunction(self.onResize, xmlValue("onResize", data)) end
            if(xmlValue("onReposition", data)~=nil)then self:generateXMLEventFunction(self.onReposition, xmlValue("onReposition", data)) end
            if(xmlValue("onEvent", data)~=nil)then self:generateXMLEventFunction(self.onEvent, xmlValue("onEvent", data)) end
            if(xmlValue("onGetFocus", data)~=nil)then self:generateXMLEventFunction(self.onGetFocus, xmlValue("onGetFocus", data)) end
            if(xmlValue("onLoseFocus", data)~=nil)then self:generateXMLEventFunction(self.onLoseFocus, xmlValue("onLoseFocus", data)) end
            self:updateDraw()
            return self
        end,

        isVisible = function(self)
            return isVisible
        end;

        setFocus = function(self)
            if (self.parent ~= nil) then
                self.parent:setFocusedObject(self)
            end
            return self
        end;

        setZIndex = function(self, index)
            zIndex = index
            if (self.parent ~= nil) then
                self.parent:removeObject(self)
                self.parent:addObject(self)
                self:updateEventHandlers()
            end
            
            return self
        end,

        updateEventHandlers = function(self)
            for k,v in pairs(activeEvents)do
                if(v)then
                    self.parent:addEvent(k, self)
                end
            end
        end,

        getZIndex = function(self)
            return zIndex;
        end;

        getType = function(self)
            return objectType
        end;

        getName = function(self)
            return self.name
        end;

        remove = function(self)
            if (self.parent ~= nil) then
                self.parent:removeObject(self)
            end
            self:updateDraw()
            return self
        end;

        setParent = function(self, frame)
            if (frame.getType ~= nil and frame:getType() == "Frame") then
                self:remove()
                frame:addObject(self)
                if (self.draw) then
                    self:show()
                end
            end
            return self
        end;

        setValue = function(self, _value)
            if (value ~= _value) then
                value = _value
                self:updateDraw()
                self:valueChangedHandler()
            end
            return self
        end;

        getValue = function(self)
            return value
        end;

        getDraw = function(self)
            return draw
        end;

        updateDraw = function(self, change)
            draw = change
            if(change == nil)then draw = true end
            if(draw)then if(self.parent~=nil)then self.parent:updateDraw() end end
            return self
        end;


        getEventSystem = function(self)
            return eventSystem
        end;


        getParent = function(self)
            return self.parent
        end;

        setPosition = function(self, xPos, yPos, rel)
            if(type(xPos)=="number")then
                self.x = rel and self:getX()+xPos or xPos
            end
            if(type(yPos)=="number")then
                self.y = rel and self:getY()+yPos or yPos
            end
            if(self.parent~=nil)then
                if(type(xPos)=="string")then
                    self.x = self.parent:newDynamicValue(self, xPos)
                end
                if(type(yPos)=="string")then
                    self.y = self.parent:newDynamicValue(self, yPos)
                end
                self.parent:recalculateDynamicValues()
            end
            eventSystem:sendEvent("basalt_reposition", self)
            self:updateDraw()
            return self
        end;

        getX = function(self)
            return type(self.x) == "number" and self.x or math.floor(self.x[1]+0.5)
        end;

        getY = function(self)
            return type(self.y) == "number" and self.y or math.floor(self.y[1]+0.5)
        end;

        getPosition = function(self)
            return self:getX(), self:getY()
        end;

        getVisibility = function(self)
            return isVisible
        end;

        setVisibility = function(self, _isVisible)
            isVisible = _isVisible or not isVisible
            self:updateDraw()
            return self
        end;

        setSize = function(self, width, height, rel)
            if(type(width)=="number")then
                self.width = rel and self.width+width or width
            end
            if(type(height)=="number")then
                self.height = rel and self.height+height or height
            end
            if(self.parent~=nil)then
                if(type(width)=="string")then
                    self.width = self.parent:newDynamicValue(self, width)
                end
                if(type(height)=="string")then
                    self.height = self.parent:newDynamicValue(self, height)
                end
                self.parent:recalculateDynamicValues()
            end
            eventSystem:sendEvent("basalt_resize", self)
            self:updateDraw()
            return self
        end;

        getHeight = function(self)
            return type(self.height) == "number" and self.height or math.floor(self.height[1]+0.5)
        end;

        getWidth = function(self)
            return type(self.width) == "number" and self.width or math.floor(self.width[1]+0.5)
        end;

        getSize = function(self)
            return self:getWidth(), self:getHeight()
        end;

        calculateDynamicValues = function(self)
            if(type(self.width)=="table")then self.width:calculate() end
            if(type(self.height)=="table")then self.height:calculate() end
            if(type(self.x)=="table")then self.x:calculate() end
            if(type(self.y)=="table")then self.y:calculate() end
            self:updateDraw()
            return self
        end,

        setBackground = function(self, color, symbol, symbolCol)
            self.bgColor = color or false
            self.bgSymbol = symbol or (self.bgColor~=false and self.bgSymbol or false)
            self.bgSymbolColor = symbolCol or self.bgSymbolColor
            self:updateDraw()
            return self
        end;

        setTransparent = function(self, color)
            self.transparentColor = color or false
            self.bgSymbol = false
            self.bgSymbolColor = false
            self:updateDraw()
            return self
        end;

        getBackground = function(self)
            return self.bgColor
        end;

        setForeground = function(self, color)
            self.fgColor = color or false
            self:updateDraw()
            return self
        end;

        getForeground = function(self)
            return self.fgColor
        end;

        setShadow = function(self, color)
            if(color==false)then
                shadow = false
            else
                shadowColor = color
                shadow = true
            end
            self:updateDraw()
            return self
        end;

        isShadowActive = function(self)
            return shadow;
        end;

        setBorder = function(self, ...)
            if(...~=nil)then
                local t = {...}
                for k,v in pairs(t)do
                    if(v=="left")or(#t==1)then
                        borderColors["left"] = t[1]
                    end
                    if(v=="top")or(#t==1)then
                        borderColors["top"] = t[1]
                    end
                    if(v=="right")or(#t==1)then
                        borderColors["right"] = t[1]
                    end
                    if(v=="bottom")or(#t==1)then
                        borderColors["bottom"] = t[1]
                    end
                end
            end
            self:updateDraw()
            return self
        end;
        
        getBorder = function(self, side)
            if(side=="left")then
                return borderLeft;
            end
            if(side=="top")then
                return borderTop;
            end
            if(side=="right")then
                return borderRight;
            end
            if(side=="bottom")then
                return borderBottom;
            end
        end;

        draw = function(self)
            if (isVisible)then
                if(self.parent~=nil)then
                    local x, y = self:getAnchorPosition()
                    local w,h = self:getSize()
                    local wP,hP = self.parent:getSize()
                    if(x+w<1)or(x>wP)or(y+h<1)or(y>hP)then return false end
                    if(self.transparentColor~=false)then
                        self.parent:drawForegroundBox(x, y, w, h, self.transparentColor)
                    end
                    if(self.bgColor~=false)then
                        self.parent:drawBackgroundBox(x, y, w, h, self.bgColor)
                    end
                    if(self.bgSymbol~=false)then
                        self.parent:drawTextBox(x, y, w, h, self.bgSymbol)
                        if(self.bgSymbol~=" ")then
                            self.parent:drawForegroundBox(x, y, w, h, self.bgSymbolColor)
                        end
                    end
                    if(shadow)then                        
                        self.parent:drawBackgroundBox(x+1, y+h, w, 1, shadowColor)
                        self.parent:drawBackgroundBox(x+w, y+1, 1, h, shadowColor)
                        self.parent:drawForegroundBox(x+1, y+h, w, 1, shadowColor)
                        self.parent:drawForegroundBox(x+w, y+1, 1, h, shadowColor)
                    end
                    if(borderColors["left"]~=false)then
                        self.parent:drawTextBox(x-1, y, 1, h, "\149")
                        self.parent:drawBackgroundBox(x-1, y, 1, h, self.bgColor)
                        self.parent:drawForegroundBox(x-1, y, 1, h, borderColors["left"])
                    end
                    if(borderColors["left"]~=false)and(borderColors["top"]~=false)then
                        self.parent:drawTextBox(x-1, y-1, 1, 1, "\151")
                        self.parent:drawBackgroundBox(x-1, y-1, 1, 1, self.bgColor)
                        self.parent:drawForegroundBox(x-1, y-1, 1, 1, borderColors["left"])
                    end
                    if(borderColors["top"]~=false)then

                        self.parent:drawTextBox(x, y-1, w, 1, "\131")
                        self.parent:drawBackgroundBox(x, y-1, w, 1, self.bgColor)
                        self.parent:drawForegroundBox(x, y-1, w, 1, borderColors["top"])
                    end
                    if(borderColors["top"]~=false)and(borderColors["right"]~=false)then
                        self.parent:drawTextBox(x+w, y-1, 1, 1, "\148")
                        self.parent:drawForegroundBox(x+w, y-1, 1, 1, self.bgColor)
                        self.parent:drawBackgroundBox(x+w, y-1, 1, 1, borderColors["right"])
                    end
                    if(borderColors["right"]~=false)then
                        self.parent:drawTextBox(x+w, y, 1, h, "\149")
                        self.parent:drawForegroundBox(x+w, y, 1, h, self.bgColor)
                        self.parent:drawBackgroundBox(x+w, y, 1, h, borderColors["right"])
                    end
                    if(borderColors["right"]~=false)and(borderColors["bottom"]~=false)then
                        self.parent:drawTextBox(x+w, y+h, 1, 1, "\133")
                        self.parent:drawForegroundBox(x+w, y+h, 1, 1, self.bgColor)
                        self.parent:drawBackgroundBox(x+w, y+h, 1, 1, borderColors["right"])
                    end
                    if(borderColors["bottom"]~=false)then
                        self.parent:drawTextBox(x, y+h, w, 1, "\143")
                        self.parent:drawForegroundBox(x, y+h, w, 1, self.bgColor)
                        self.parent:drawBackgroundBox(x, y+h, w, 1, borderColors["bottom"])
                    end
                    if(borderColors["bottom"]~=false)and(borderColors["left"]~=false)then
                        self.parent:drawTextBox(x-1, y+h, 1, 1, "\138")
                        self.parent:drawForegroundBox(x-1, y+h, 1, 1, self.bgColor)
                        self.parent:drawBackgroundBox(x-1, y+h, 1, 1, borderColors["left"])
                    end
                end
                draw = false
                return true
            end
            return false
        end;


        getAbsolutePosition = function(self, x, y)
            -- relative position to absolute position
            if (x == nil) or (y == nil) then
                x, y = self:getAnchorPosition()
            end

            if (self.parent ~= nil) then
                local fx, fy = self.parent:getAbsolutePosition()
                x = fx + x - 1
                y = fy + y - 1
            end
            return x, y
        end;

        getAnchorPosition = function(self, x, y, ignOff)
            if (x == nil) then
                x = self:getX()
            end
            if (y == nil) then
                y = self:getY()
            end
            if(self.parent~=nil)then
            local pw,ph = self.parent:getSize()
                if (anchor == "top") then
                    x = math.floor(pw/2) + x - 1
                elseif(anchor == "topRight") then
                    x = pw + x - 1
                elseif(anchor == "right") then
                    x = pw + x - 1
                    y = math.floor(ph/2) + y - 1
                elseif(anchor == "bottomRight") then
                    x = pw + x - 1
                    y = ph + y - 1
                elseif(anchor == "bottom") then
                    x = math.floor(pw/2) + x - 1
                    y = ph + y - 1
                elseif(anchor == "bottomLeft") then
                    y = ph + y - 1
                elseif(anchor == "left") then
                    y = math.floor(ph/2) + y - 1
                elseif(anchor == "center") then
                    x = math.floor(pw/2) + x - 1
                    y = math.floor(ph/2) + y - 1
                end

                local xO, yO = self.parent:getOffsetInternal()
                if not(ignOffset or ignOff) then
                    return x+xO, y+yO
                end
            end
            return x, y
        end;

        ignoreOffset = function(self, ignore)
            ignOffset = ignore
            if(ignore==nil)then ignOffset = true end
            return self
        end;

        getBaseFrame = function(self)
            if(self.parent~=nil)then
                return self.parent:getBaseFrame()
            end
            return self
        end;
        
        setAnchor = function(self, newAnchor)
            anchor = newAnchor
            self:updateDraw()
            return self
        end;

        getAnchor = function(self)
            return anchor
        end;

        onChange = function(self, ...)
            for _,v in pairs(table.pack(...))do
                if(type(v)=="function")then
                    self:registerEvent("value_changed", v)
                end
            end
            return self
        end;

        onClick = function(self, ...)
                for _,v in pairs(table.pack(...))do
                    if(type(v)=="function")then
                        self:registerEvent("mouse_click", v)
                    end
                end
                if(self.parent~=nil)then
                    self.parent:addEvent("mouse_click", self)
                    activeEvents["mouse_click"] = true
                end
            return self
        end;

        onClickUp = function(self, ...)
                for _,v in pairs(table.pack(...))do
                    if(type(v)=="function")then
                        self:registerEvent("mouse_up", v)
                    end
                end
                if(self.parent~=nil)then
                    self.parent:addEvent("mouse_up", self)
                    activeEvents["mouse_up"] = true
                end
            return self
        end;


        onScroll = function(self, ...)
                for _,v in pairs(table.pack(...))do
                    if(type(v)=="function")then
                        self:registerEvent("mouse_scroll", v)
                    end
                end
                if(self.parent~=nil)then
                    self.parent:addEvent("mouse_scroll", self)
                    activeEvents["mouse_scroll"] = true
                end
            return self
        end;

        onDrag = function(self, ...)
            for _,v in pairs(table.pack(...))do
                if(type(v)=="function")then
                    self:registerEvent("mouse_drag", v)
                end
            end
            if(self.parent~=nil)then
                self.parent:addEvent("mouse_drag", self)
                activeEvents["mouse_drag"] = true
                self.parent:addEvent("mouse_click", self)
                activeEvents["mouse_click"] = true
                self.parent:addEvent("mouse_up", self)
                activeEvents["mouse_up"] = true
            end
            return self
        end;

        onEvent = function(self, ...)
            for _,v in pairs(table.pack(...))do
                if(type(v)=="function")then
                    self:registerEvent("other_event", v)
                end
            end
            if(self.parent~=nil)then
                self.parent:addEvent("other_event", self)
                activeEvents["other_event"] = true
            end
            return self
        end;

        onKey = function(self, ...)
            if(isEnabled)then
                for _,v in pairs(table.pack(...))do
                    if(type(v)=="function")then
                        self:registerEvent("key", v)
                        self:registerEvent("char", v)
                    end
                end
                if(self.parent~=nil)then
                    self.parent:addEvent("key", self)
                    self.parent:addEvent("char", self)
                    activeEvents["key"] = true
                    activeEvents["char"] = true
                end
            end
            return self
        end;

        onResize = function(self, ...)
            for _,v in pairs(table.pack(...))do
                if(type(v)=="function")then
                    self:registerEvent("basalt_resize", v)
                end
            end
            return self
        end;

        onReposition = function(self, ...)
            for _,v in pairs(table.pack(...))do
                if(type(v)=="function")then
                    self:registerEvent("basalt_reposition", v)
                end
            end
            return self
        end;

        onKeyUp = function(self, ...)
                for _,v in pairs(table.pack(...))do
                    if(type(v)=="function")then
                        self:registerEvent("key_up", v)
                    end
                end
                if(self.parent~=nil)then
                    self.parent:addEvent("key_up", self)
                    activeEvents["key_up"] = true
                end
            return self
        end;

        isFocused = function(self)
            if (self.parent ~= nil) then
                return self.parent:getFocusedObject() == self
            end
            return false
        end;

        onGetFocus = function(self, ...)
            for _,v in pairs(table.pack(...))do
                if(type(v)=="function")then
                    self:registerEvent("get_focus", v)
                end
            end
            if(self.parent~=nil)then
                self.parent:addEvent("mouse_click", self)
                activeEvents["mouse_click"] = true
            end
            return self
        end;

        onLoseFocus = function(self, ...)
            for _,v in pairs(table.pack(...))do
                if(type(v)=="function")then
                    self:registerEvent("lose_focus", v)
                end
            end
            if(self.parent~=nil)then
                self.parent:addEvent("mouse_click", self)
                activeEvents["mouse_click"] = true
            end
            return self
        end;

        registerEvent = function(self, event, func)
            return eventSystem:registerEvent(event, func)
        end;

        removeEvent = function(self, event, index)
            return eventSystem:removeEvent(event, index)
        end;

        sendEvent = function(self, event, ...)
            return eventSystem:sendEvent(event, self, ...)
        end;

        isCoordsInObject = function(self, x, y)
            if(isVisible)and(isEnabled)then
                local objX, objY = self:getAbsolutePosition(self:getAnchorPosition())
                local w, h = self:getSize()            
                if (objX <= x) and (objX + w > x) and (objY <= y) and (objY + h > y) then
                    return true
                end
            end
            return false
        end,

        mouseHandler = function(self, button, x, y, isMon)
            if(self:isCoordsInObject(x, y))then
                local val = eventSystem:sendEvent("mouse_click", self, "mouse_click", button, x, y, isMon)
                if(val==false)then return false end
                if(self.parent~=nil)then
                    self.parent:setFocusedObject(self)
                end
                isDragging = true
                dragStartX, dragStartY = x, y 
                return true
            end
            return false
        end,

        mouseUpHandler = function(self, button, x, y)
            isDragging = false
            if(self:isCoordsInObject(x, y))then
                local val = eventSystem:sendEvent("mouse_up", self, "mouse_up", button, x, y)
                if(val==false)then return false end
                return true
            end
            return false
        end,

        dragHandler = function(self, button, x, y)
            if(isDragging)then 
                local xO, yO, parentX, parentY = 0, 0, 1, 1
                if (self.parent ~= nil) then
                    xO, yO = self.parent:getOffsetInternal()
                    xO = xO < 0 and math.abs(xO) or -xO
                    yO = yO < 0 and math.abs(yO) or -yO
                    parentX, parentY = self.parent:getAbsolutePosition(self.parent:getAnchorPosition())
                end
                local dX, dY = x + dragXOffset - (parentX - 1) + xO, y + dragYOffset - (parentY - 1) + yO
                local val = eventSystem:sendEvent("mouse_drag", self, button, dX, dY, dragStartX-x, dragStartY-y, x, y)
                local objX, objY = self:getAbsolutePosition(self:getAnchorPosition())
                dragStartX, dragStartY = x, y 
                if(val~=nil)then return val end
                if(self.parent~=nil)then
                    self.parent:setFocusedObject(self)
                end
                return true
            end

            if(self:isCoordsInObject(x, y))then
                local objX, objY = self:getAbsolutePosition(self:getAnchorPosition())
                dragStartX, dragStartY = x, y 
                dragXOffset, dragYOffset = objX - x, objY - y
            end
            return false
        end,

        scrollHandler = function(self, dir, x, y)
            if(self:isCoordsInObject(x, y))then
                local val = eventSystem:sendEvent("mouse_scroll", self, "mouse_scroll", dir, x, y)
                if(val==false)then return false end
                if(self.parent~=nil)then
                    self.parent:setFocusedObject(self)
                end
                return true
            end
            return false
        end,

        keyHandler = function(self, key, isHolding)
            if(isEnabled)and(isVisible)then
                if (self:isFocused()) then
                local val = eventSystem:sendEvent("key", self, "key", key, isHolding)
                if(val==false)then return false end
                return true
                end
            end
            return false
        end;

        keyUpHandler = function(self, key)
            if(isEnabled)and(isVisible)then
                if (self:isFocused()) then
                    local val = eventSystem:sendEvent("key_up", self, "key_up", key)
                if(val==false)then return false end
                return true
                end
            end
            return false
        end;

        charHandler = function(self, char)
            if(isEnabled)and(isVisible)then
                if (self:isFocused()) then
                    local val = eventSystem:sendEvent("char", self, "char", char)
                if(val==false)then return false end
                return true
                end
            end
            return false
        end,

        valueChangedHandler = function(self)
            eventSystem:sendEvent("value_changed", self, value)
        end;

        eventHandler = function(self, event, p1, p2, p3, p4)
            local val = eventSystem:sendEvent("other_event", self, event, p1, p2, p3, p4)
            if(val~=nil)then return val end
            return true
        end;

        getFocusHandler = function(self)
            local val = eventSystem:sendEvent("get_focus", self)
            if(val~=nil)then return val end
            return true
        end;

        loseFocusHandler = function(self)
            isDragging = false
            local val = eventSystem:sendEvent("lose_focus", self)
            if(val~=nil)then return val end
            return true
        end;

        init = function(self)
            if(self.parent~=nil)then
                for k,v in pairs(activeEvents)do
                    if(v)then
                    self.parent:addEvent(k, self)
                    end
                end
            end
            if not(initialized)then
                initialized = true
                return true
            end
        end

    }

    object.__index = object
    return object
end