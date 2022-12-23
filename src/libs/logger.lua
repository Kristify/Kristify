local logger = {}

---Create a new logger object
---@param o table
---@return table
function logger:new(o)
  o = o or {} -- create object if user does not provide one
  setmetatable(o, self)
  self.__index = self
  term.clear()
  return o
end

-- Inspiration by "Kingdaro"
-- Inspiration source: https://www.computercraft.info/forums2/index.php?/topic/6201-changing-colours-of-text-in-a-single-printwrite/
---Print as a color to the terminal
---@param ... any
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

---Print to the terminal with log level `info`
---@param ... any
function logger:info(...)
  colorPrint(colors.lightGray, "[", colors.green, "INFO", colors.lightGray, "] ", colors.white, table.unpack(arg))
end

---Print to the terminal with log level `warn`
---@param ... any
function logger:warn(...)
  colorPrint(colors.lightGray, "[", colors.orange, "WARN", colors.lightGray, "] ", colors.white, table.unpack(arg))
end

---Print to the terminal with log level `error`
---@param ... any
function logger:error(...)
  colorPrint(colors.lightGray, "[", colors.red, "ERROR", colors.lightGray, "] ", colors.red, table.unpack(arg))
end

---Print to the terminal with log level `debug`
---@param ... any
function logger:debug(...)
  if self.debugging ~= true then return end
  colorPrint(colors.lightGray, "[", colors.gray, "DEBUG", colors.lightGray, "] ", colors.gray, table.unpack(arg))
end

return logger
