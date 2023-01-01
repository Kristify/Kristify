-- Kristify shop manager

local w, h = term.getSize()

if not (#arg >= 1) then
  print("Not enogth arguments")
  return
end

if arg[1] == "theme" then
  if #arg == 1 then
    print("The current theme is: ")
    return
  end

  print("Installing theme: " .. arg[2])
  return
end

print("Action `" .. arg[1] .. "` is not available.")
