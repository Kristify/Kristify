local Object = require("Object")
local utils = require("utils")
local xmlValue = utils.getValueFromXML
local createText = utils.createText
local tHex = require("tHex")
local bdf = require("miniBDF")

return function(name)
    -- Bimg
    local base = Object(name)
    local objectType = "Bimg"
    base:setZIndex(2)
    local image
    local index = 1

    local object = {
        getType = function(self)
            return objectType
        end;

        setIndex = function(self, i)
            index = i
            self:updateDraw()
            return self
        end;

        loadImage = function(self, path)
            if type(path) == "table" then
                image = path
            elseif type(path) == "string" then
                if fs.exists(path) and not fs.isDir(path) then
                    local f = fs.open(path, 'r')
                    local str =     f.readAll()
                    f.close()

                    local col = {white=0x1,orange=0x2,magenta=0x4,lightBlue=0x8,yellow=0x10,lime=0x20,pink=0x40,grey=0x80,lightGrey=0x100,cyan=0x200,purple=0x400,blue=0x800,brown=0x1000,green=0x2000,red=0x4000,black=0x8000}
                    local inferiorcol=col; inferiorcol.gray=col.grey; inferiorcol.lightGray=col.lightGrey
                    local b,tBimg = pcall( load("return "..str,"bimg","t",{colours=col,colors=inferiorcol}) )

                    if b and type(tBimg) == "table" then
                        image = tBimg
                    end
                end
            end
            self:updateDraw()
            return self
        end;

        unloadImage = function(self)
            image = nil
            self:updateDraw()
            return self
        end;

        setValuesByXMLData = function(self, data)
            base.setValuesByXMLData(self, data)
            if(xmlValue("path", data)~=nil)then self:loadImage(xmlValue("path", data)) end
            return self
        end,

        draw = function(self)
            if (base.draw(self)) then
                if (self.parent ~= nil) then
                    local blits = {[1]='0',[2]='1',[4]='2',[8]='3',[16]='4',[32]='5',[64]='6',[128]='7',[256]='8',[512]='9',[1024]='a',[2048]='b',[4096]='c',[8192]='d',[16384]='e',[32768]='f' }
                    if image and image[index] then
                        local obx, oby = self:getAnchorPosition()

                        local width = 1
                        for i=1,#image[index] do
                            local line = image[index][i]

                            if #line[1] > width then
                                width = #line[1]
                            end

                            if line[2]:find(' ') then
                                local c = blits[self.parent:getBackground()]
                                line[2] = (line[2]):gsub(' ', c)
                            end
                            if line[3]:find(' ') then
                                local c = blits[self.parent:getBackground()]
                                line[3] = (line[3]):gsub(' ', c)
                            end

                            self.parent:setText(obx, oby+i-1, line[1])
                            self.parent:setFG(obx, oby+i-1, line[2])
                            self.parent:setBG(obx, oby+i-1, line[3])
                        end
                        self:setSize(width, #image[index])
                    end
                end
            end
        end,

        init = function(self) end

    }

    return setmetatable(object, base)
end

