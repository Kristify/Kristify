local logger = {}

---Create a new logger object
---@param o table
---@return table
function logger:new(o)
  o = o or {} -- create object if user does not provide one
  if o.log2file ~= nil and o.log2file == true then
    print("Logging to file is enabled.")
    o.f = fs.open("/kristify-latest.log", "w")
  end

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

  if self.log2file == true then
    self.f.write("\n" .. textutils.serialize(arg))
    self.f.flush()
  end

  colorPrint(colors.lightGray, "[", colors.green, "INFO", colors.lightGray, "] ", colors.white, table.unpack(arg))
end

---Print to the terminal with log level `warn`
---@param ... any
function logger:warn(...)

  if self.log2file == true then
    self.f.write("\n" .. textutils.serialize(arg))
    self.f.flush()
  end

  colorPrint(colors.lightGray, "[", colors.orange, "WARN", colors.lightGray, "] ", colors.white, table.unpack(arg))
end

---Print to the terminal with log level `error`
---@param ... any
function logger:error(...)

  if self.log2file == true then
    self.f.write("\n" .. textutils.serialize(arg))
    self.f.flush()
  end

  colorPrint(colors.lightGray, "[", colors.red, "ERROR", colors.lightGray, "] ", colors.red, table.unpack(arg))
end

---Print to the terminal with log level `debug`
---@param ... any
function logger:debug(...)
  if self.debugging ~= true then return end

  if self.log2file == true then
    self.f.write("\n" .. textutils.serialize(arg))
    self.f.flush()
  end

  colorPrint(colors.lightGray, "[", colors.gray, "DEBUG", colors.lightGray, "] ", colors.gray, table.unpack(arg))
end

return logger
