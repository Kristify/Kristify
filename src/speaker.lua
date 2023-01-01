local speaker = {}

function speaker:new(o)
  o = o or {} -- create object if user does not provide one
  setmetatable(o, self)
  self.__index = self
  return o
end

---Plays sounds!
---@param event string The event that happend 
function speaker:play(event)
  if self.config.sounds[event] == nil then
    return
  end

  if self.config.speakers == nil then
    return
  end

  if #self.config.speakers == 0 then
    return
  end

  for _, sp in ipairs(self.config.speakers) do
    pcall(peripheral.call(sp, "playSound", self.config.sounds[event], self.config.sounds.volume or 1))
  end
end

return speaker