local logger = {}

function logger:new(o)
  o = o or {} -- create object if user does not provide one
  setmetatable(o, self)
  self.__index = self
  term.clear()
  return o
end

-- Inspiration by "Mads"
-- Inspiration source: http://www.computercraft.info/forums2/index.php?/topic/11771-print-coloured-text-easily/
local function printWithFormat(...)
  local s = "&1"
  for k, v in ipairs(arg) do
    s = s .. v
  end
  s = s .. "&0"

  local fields = {}
  local lastcolor, lastpos = "0", 0
  for pos, clr in s:gmatch "()&(%x)" do
    table.insert(fields, { s:sub(lastpos + 2, pos - 1), lastcolor })
    lastcolor, lastpos = clr, pos
  end

  for i = 2, #fields do
    term.setTextColor(2 ^ (tonumber(fields[i][2], 16)))
    io.write(fields[i][1])
  end
end

local function fixup()
  print(" ")
  term.setTextColor(colors.white)
  term.setBackgroundColor(colors.black)
end

function logger:info(...)
  local args = { ... }

  printWithFormat("&8[&dINFO&8] &0", table.unpack(args))
  fixup()
end

function logger:warn(...)
  local args = { ... }

  printWithFormat("&8[&1WARN&8] &0", table.unpack(args))
  fixup()
end

function logger:error(...)
  local args = { ... }

  printWithFormat("&8[&eERROR&8] &e", table.unpack(args))
  fixup()
end

function logger:debug(...)
  if self.debugging == nil or self.debugging == false then
    return
  end

  local args = { ... }

  printWithFormat("&8[&7DEBUG&8] &0", table.unpack(args))
  fixup()
end

return logger
