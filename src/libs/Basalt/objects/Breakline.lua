local Object = require("Object")
local xmlValue = require("utils").getValueFromXML

return function(name)
    local base = Object(name)
    local objectType = "Breakline"

    base.width = 15
    base.height = 1

    base:setValue(1)
    base:setZIndex(2)

    local dirType = "vertical"
    local length = 1

    local function mouseEvent(self, button, x, y)
        local obx, oby = self:getAbsolutePosition(self:getAnchorPosition())
        local w,h = self:getSize()
        if (dirType == "horizontal") then
            for _index = 0, w do
                if (obx + _index == x) and (oby <= y) and (oby + h > y) then
                    index = math.min(_index + 1, w - (symbolSize - 1))
                    self:setValue(maxValue / w * (index))
                    self:updateDraw()
                end
            end
        end
        if (dirType == "vertical") then
            for _index = 0, h do
                if (oby + _index == y) and (obx <= x) and (obx + w > x) then
                    index = math.min(_index + 1, h - (symbolSize - 1))
                    self:setValue(maxValue / h * (index))
                    self:updateDraw()
                end
            end
        end
    end

    local object = {
        getType = function(self)
            return objectType
        end;

        setValuesByXMLData = function(self, data)
            base.setValuesByXMLData(self, data)
            if(xmlValue("length", data)~=nil)then self:setLength(xmlValue("length", data)) end
            if(xmlValue("dirType", data)~=nil)then self:setDirType(xmlValue("dirType", data):lower()) end
        end,

        getLength = function(self)
            return length
        end,

        setLength = function(self, newLen)
            if type(newLen)=="number" then
                length = newLen
            elseif type(newLen)=="string" then
                length = self.parent:newDynamicValue(self, newLen)
                self.parent:recalculateDynamicValues()
            end
            self:updateDraw()
            return self
        end;

        getDirType = function(self)
            return dirType
        end;

        setDirType = function(self, _typ)
            if _typ:lower() == "horizontal"
            or _typ:lower() == "vertical" then
                dirType = _typ:lower()
            end
            self:updateDraw()
            return self
        end;

        draw = function(self)
            if (base.draw(self)) then
                if (self.parent ~= nil) then
                    self.bgColor = self.parent:getBackground()

                    local obx, oby = self:getAnchorPosition()
                    local length = length
                    if type(length) == "table" then
                        length = length[1]
                    end
                    if (dirType == "horizontal") then
                        self:getSize(length,1)
                        self.parent:writeText(obx, oby, ('\140'):rep(length), self.bgColor, self.fgColor)
                    elseif (dirType == "vertical") then
                        self:getSize(1,length)
                        for i=1,length do
                            self.parent:writeText(obx, oby+i-1, '\149', self.bgColor, self.fgColor)
                        end
                    end
                end
            end
        end,

        init = function(self)
            self.bgColor = self.parent:getBackground()
            self.fgColor = self.parent:getTheme("Breakline")
        end,
    }

    return setmetatable(object, base)
end