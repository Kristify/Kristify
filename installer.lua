local basaltDL = http.get("https://basalt.madefor.cc/versions/latest.lua", _G._GIT_API_KEY and {Authorization = "token " .. _G._GIT_API_KEY})
assert(basaltDL, "Basalt could not download into memory")
local basalt = load(basaltDL.readAll())()

local main = basalt.createFrame():setBackground(colors.gray):show()
local steps = basalt.createFrame():setBackground(colors.gray):hide()
local loading = basalt.createFrame():setBackground(colors.gray):hide()

local w, h = term.getSize()

main:addLabel():setText("Kristify Installer"):setPosition(w / 2 - 8, 3):setForeground(colors.purple):show()
main:addButton():setText("Accept license & Continue"):setPosition(w / 2 - 14, 7):setSize(30, 5):setBackground(colors.lightBlue):onClick(function()
  main:hide()
  steps:show()
end):show()
main:addLabel():setText("License: MIT"):setPosition(w / 2 - 5, 13):setForeground(colors.purple):show()

local status = loading:addLabel():setText("Status: Init"):setPosition(w / 2 - 7, math.floor(h / 2)):setForeground(colors.purple):show()

steps:addLabel():setText("Steps to be run:"):setPosition(w / 2 - 7, 3):setForeground(colors.purple):show()
steps:addLabel():setText("1. Wipe computer"):setPosition(w / 2 - 7, 5):setForeground(colors.purple):show()
steps:addLabel():setText("2. Create folders"):setPosition(w / 2 - 7, 6):setForeground(colors.purple):show()
steps:addLabel():setText("3. Download source"):setPosition(w / 2 - 7, 7):setForeground(colors.purple):show()
steps:addButton():setText("Confirm installation"):setPosition(w / 2 - 11, 10):setSize(27, 3):setBackground(colors.purple):onClick(function()
  steps:hide()
  loading:show()

  status:setText("Status: Wiping")
  shell.run("rm *")

  status:setText("Creating directories")
  fs.makeDir("/src")
  fs.makeDir("/data")
  fs.makeDir("/data/pages")
  
  status:setText("Downloading files")
  shell.run("wget [singlefileKristify] /src/kristify.lua")
  shell.run("wget [configExample] /data/config.lua")
  shell.run("wget [productsExample] /data/products.lua")
  shell.run("wget [index.xml] /data/pages/index.xml")
  shell.run("wget [widget.xml] /data/pages/widget.xml")
  shell.run("wget [theme.lua] /data/pages/theme.lua")

  status:setText("Done. Exiting soon.\nPlease change the config\nPlease create a startup that runs `/src/kristify.lua`")
end):show()

basalt.autoUpdate()