local logger = {}

function logger:new(o)
  o = o or {} -- create object if user does not provide one
  setmetatable(o, self)
  self.__index = self
  term.clear()
  return o
end

-- Inspiration by "Kingdaro"
-- Inspiration source: https://www.computercraft.info/forums2/index.php?/topic/6201-changing-colours-of-text-in-a-single-printwrite/
local function colorPrint(...)
  local curColor
  for i = 1, #arg do
    if type(arg[i]) == 'number' then
      curColor = arg[i]
    else
      if curColor then term.setTextColor(curColor) end
      write(arg[i])
    end
  end
  print()
  term.setTextColor(colors.white)
end

function logger:info(...)
  colorPrint(colors.lightGray, "[", colors.green, "INFO", colors.lightGray, "] ", colors.white, table.unpack(arg))
end

function logger:warn(...)
  colorPrint(colors.lightGray, "[", colors.orange, "WARN", colors.lightGray, "] ", colors.white, table.unpack(arg))
end

function logger:error(...)
  colorPrint(colors.lightGray, "[", colors.red, "ERROR", colors.lightGray, "] ", colors.red, table.unpack(arg))
end

function logger:debug(...)
  if self.debugging ~= true then return end
  colorPrint(colors.lightGray, "[", colors.gray, "DEBUG", colors.lightGray, "] ", colors.gray, table.unpack(arg))
end

return logger
