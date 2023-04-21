local installation = settings.get("kristify.path") or "kristify"
local owner,repo = "kristify","themes"
local tArgs = {...}

-- Check update
local verPath = fs.combine(installation,"src","version.txt")
local version = "0.0.0"
if fs.exists(verPath) then
  local file = fs.open(verPath, 'r')
  version = file.readAll()
  file.close()
end

local authenticate = _G._GIT_API_KEY and {Authorization = "Bearer ".._G._GIT_API_KEY}
local gitAPI = http.get("https://raw.githubusercontent.com/Kristify/Kristify/main/src/version.txt", authenticate)
if gitAPI then
    local newV = gitAPI.readAll()
    if newV ~= version then
      term.setTextColor(colors.orange)
      term.write("Update available for Kristify! ")
      term.setTextColor(colors.lightGray)
      print(version.." (current) --> ".. newV .. " (latest)")
      term.setTextColor(colors.white)
      print("Run \'kristify.lua -u\' or --update")
      sleep(0.8)
    end
    gitAPI.close()
end

-- Run Kristify normally
if #tArgs == 0 then
  local path = fs.combine(installation,"src","init.lua")
  if not fs.exists(path) then
    error("Kristify is not installed correctly!")
  end

  if term.isColor() then
    local id = shell.openTab(path)
    multishell.setTitle(id, "Kristify")
    shell.switchTab(id)
  else
    shell.run(path)
  end
end

-- Install theme
if tArgs[1] == "--theme" or tArgs[1] == "-t" then
  -- Show current theme
  if not tArgs[2] or tArgs[2] == "" then
    local name,author = "Unknown","Herobrine"
    local path = fs.combine(installation,"data","credits.json")
    if fs.exists(path) then
      local file = fs.open(verPath, 'r')
      local data = file.readAll()
      data = textutils.unserialiseJSON(data) or {}
      name = data.name or "Unknown"
      author = data.author or "Herobrine"
      file.close()
    end

    term.setTextColor(colors.lightGray)
    term.write("Theme: ")
    term.setTextColor(colors.white)
    print(name.." by "..author)
  else
    -- Change theme
    local file = http.get("https://raw.githubusercontent.com/"..owner..'/'..repo.."/main/"..tArgs[2].."/credits.json")
    if not file then printError("The given theme doesn't exist!") return end

    local data = file.readAll()
    data = textutils.unserialiseJSON(data)
    if not data then printError("The given theme doesn't exist!") return end
    local name = data.name
    local author = data.author
    file.close()

    print("Installing "..name.." by "..author)

    local function httpError(response,err,errResponse)
        if not response then
          errors = true
          justinWeHaveAProblem("Request to GitHub denied; Reason: \'.."..err.."..\' (code "..errResponse.getResponseCode()..").")
          return false
        end
        return true
    end

    local function getJSON(response)
      if not response then return {} end
      local tData = response.readAll()
      response.close()
      return textutils.unserialiseJSON(tData)
    end

    local function generateTree(name)
      sURL = "https://api.github.com/repos/"..owner..'/'..repo.."/contents/"..name.."?ref=main"
      local function convertItem(item)
          if item.type == "file" then
              return item.name, item.download_url
          elseif item.type == "dir" then
              return item.name, generateTree(item.url)
          end
      end
      local response,sErr,errResponse = http.get(sURL, authenticate)
      httpError(response,sErr,errResponse)
      local tData = getJSON(response)
      local tTree = { }
      for _,v in pairs(tData) do
          local sName,tItem = convertItem(v)
          -- Filter stuff that is not needed
          if not (sName:sub(1,1) == '.' or sName:find(".md")) then
              tTree[sName] = tItem
          end
      end
      return tTree
    end

    local function downloadBlob(sURL, sPath)
      local response,sErr,errResponse = http.get(sURL, authenticate)
      if not httpError(response,sErr,errResponse) then
        return false
      end

      local sData = response.readAll()
      response.close()

      local file = fs.open(sPath, 'w')
      file.write(sData)
      file.close()

      return true
    end

    local theme = generateTree(name)
    local function downloadItems(tree,sPath)
      sleep(0.3)
      for name,item in pairs(tree) do
        local nextPath = fs.combine(sPath,name)
        if type(item) == "table" then
          downloadItems(item,nextPath)
        else
          downloadBlob(item,nextPath)
        end
      end
    end

    local path = fs.combine(installation,"data","pages")
    fs.delete(path)
    downloadItems(theme, path)
  end

elseif tArgs[1] == "--version" or tArgs[1] == "-v" then
  print("Kristify v"..version)
  term.write("GitHub: Kristify/Kristify made with ")
  term.setTextColor(colors.red)
  print("\003")
  term.setTextColor(colors.white)

elseif tArgs[1] == "--update" or tArgs[1] == "-u" then
  local path = fs.combine(installation,"data")
  if fs.exists(path) then
    fs.delete(".kristify_data_backup")
    fs.copy(path, ".kristify_data_backup")
  end

  -- Run installer
  if not http then
    error("Holdup. How- eh whatever. You need the http API!")
  end

  local authenticate = _G._GIT_API_KEY and {Authorization = "Bearer ".._G._GIT_API_KEY}
  local response,err,errResp = http.get("https://raw.githubusercontent.com/Kristify/kristify/main/installer.lua",authenticate)

  if not response then
      error("Couldn't get the install script! Reason: \'"..err.."\' (code "..errResp.getResponseCode()..')')
  end

  local content = response.readAll()
  response.close()

  local path = load(content, "install",'t',_ENV)()

  if fs.exists(".kristify_data_backup") then
    fs.delete(fs.combine(path,"data"))
    fs.copy(".kristify_data_backup",fs.combine(path,"data"))
    fs.delete(".kristify_data_backup")
  end

elseif tArgs[1] == "--storage" or tArgs[1] == "-s" then
  os.queueEvent("kstUpdateProducts")

elseif tArgs[1] == "--exit" or tArgs[1] == "-e" then
  os.queueEvent("kristify:exit")

elseif tArgs[1] == "--nbt" or tArgs[1] == "-n" then
  print("NBT Hash of item #1: ")

  local data = turtle.getItemDetail(1, true)
  assert(data, "No data gotten from slot one")

  print(data.nbt or "No NBT data. Leave the field to `nil` or don't define it.")
elseif tArgs[1] == "--help" or tArgs[1] == "-h" then
  print("Usage: "..(tArgs[0] or "kristify.lua").." [flag:]")
  print("-u","--update","Updates Kristify.")
  print("-v","--version","Shoes the current version.")
  print("-t [name]","--theme","Shows or installs a given theme.")
  print("-s", "--storage", "Updates the storage.")
  print("-e", "--exit", "Stops the shop")
  print("-n", "--nbt", "Gets the NBT hash of the item in slot one")
end
