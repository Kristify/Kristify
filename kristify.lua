local installation = settings.get("kristify.path") or "kristify"
local owner, themeRepo = "kristify", "themes"
local args = { ... }

-- Check installed version
local versionPath = fs.combine(installation, "src", "version.txt")
local version = "0.0.0"
if fs.exists(versionPath) then
  local file = fs.open(versionPath, 'r')
  version = file.readAll()
  file.close()
end

-- Check upstream version
local authenticate = _G._GIT_API_KEY and { Authorization = "Bearer " .. _G._GIT_API_KEY }
local gitAPI = http.get("https://raw.githubusercontent.com/Kristify/Kristify/main/src/version.txt", authenticate)

if gitAPI then
  local upstreamVersion = gitAPI.readAll()

  if upstreamVersion ~= version then
    term.setTextColor(colors.orange)
    print("Update available for Kristify! ")
    term.setTextColor(colors.lightGray)
    print(("%s (installed) --> %s (latest)"):format(version, upstreamVersion))
    term.setTextColor(colors.white)
    print("Run \'kristify.lua -u\' or --update")
    sleep(1)
  end

  gitAPI.close()
end

-- Run Kristify normally
if #args == 0 then
  local initPath = fs.combine(installation, "src", "init.lua")
  if not fs.exists(initPath) then
    error("Kristify is not installed correctly!")
  end

  if term.isColor() then
    local id = shell.openTab(initPath)
    multishell.setTitle(id, "Kristify")
    shell.switchTab(id)
  else
    print("Note: Kristify works best with advanced devices, as they have color and multishell")
    shell.run(initPath)
  end
end

-- Install theme
if args[1] == "--theme" or args[1] == "-t" then
  -- Show current theme

  if not args[2] or args[2] == "" then
    local name, author = "Unknown", "Herobrine"
    local path = fs.combine(installation, "data", "credits.json")

    if fs.exists(path) then
      local file = fs.open(versionPath, 'r')
      local data = file.readAll()
      file.close()

      data = textutils.unserialiseJSON(data) or {}
      name = data.name or "Unknown"
      author = data.author or "Herobrine"
    end

    term.setTextColor(colors.lightGray)
    term.write("Theme: ")
    term.setTextColor(colors.white)
    print(name .. " by " .. author)
  else
    -- Change theme

    local file = http.get(("https://raw.githubusercontent.com/%s/%s/main/%s/credits.json")
      :format(owner, themeRepo, args[2]))

    if not file then
      error("The given theme doesn't exist!")
    end

    local data = file.readAll()
    file.close()

    data = textutils.unserialiseJSON(data)
    if not data then
      error("The given theme doesn't exist!")
    end

    local name = data.name
    local author = data.author

    print(("Installing %s theme by %s"):format(name, author))

    local function httpError(response, err, errResponse)
      if not response then
        error("Request to GitHub denied; Reason: \'.." ..
          err .. "..\' (code " .. errResponse.getResponseCode() .. ").")
      end
    end

    local function getJSON(response)
      if not response then return {} end

      local rawData = response.readAll()
      response.close()
      return textutils.unserialiseJSON(rawData)
    end

    local function generateTree(name)
      sURL = "https://api.github.com/repos/" .. owner .. '/' .. themeRepo .. "/contents/" .. name .. "?ref=main"

      local function convertItem(item)
        if item.type == "file" then
          return item.name, item.download_url
        elseif item.type == "dir" then
          return item.name, generateTree(item.url)
        end
      end

      local response, sErr, errResponse = http.get(sURL, authenticate)
      httpError(response, sErr, errResponse)

      local tData = getJSON(response)
      local tTree = {}

      for _, v in pairs(tData) do
        local sName, tItem = convertItem(v)
        -- Filter stuff that is not needed
        if not (sName:sub(1, 1) == '.' or sName:find(".md")) then
          tTree[sName] = tItem
        end
      end
      return tTree
    end

    local function downloadBlob(sURL, sPath)
      local response, sErr, errResponse = http.get(sURL, authenticate)
      if not httpError(response, sErr, errResponse) then
        return false
      end

      local sData = response.readAll()
      response.close()

      local blobFile = fs.open(sPath, 'w')
      blobFile.write(sData)
      blobFile.close()

      return true
    end

    local theme = generateTree(name)
    local function downloadItems(tree, sPath)
      sleep(0.3)

      for treeItemName, item in pairs(tree) do
        local nextPath = fs.combine(sPath, treeItemName)
        if type(item) == "table" then
          downloadItems(item, nextPath)
        else
          downloadBlob(item, nextPath)
        end
      end
    end

    local path = fs.combine(installation, "data", "pages")
    fs.delete(path)
    downloadItems(theme, path)
  end
elseif args[1] == "--version" or args[1] == "-v" then
  print("Kristify v" .. version)
  term.write("GitHub: Kristify/Kristify made with ")
  term.setTextColor(colors.red)
  print("\003")
  term.setTextColor(colors.white)
elseif args[1] == "--update" or args[1] == "-u" then
  local path = fs.combine(installation, "data")
  if fs.exists(path) then
    fs.delete(".kristify_data_backup")
    fs.copy(path, ".kristify_data_backup")
  end

  -- Run installer
  if not http then
    error("Holdup. How- eh whatever. You need the http API!")
  end

  local authenticate = _G._GIT_API_KEY and { Authorization = "Bearer " .. _G._GIT_API_KEY }
  local response, err, errResp = http.get("https://raw.githubusercontent.com/Kristify/kristify/main/installer.lua",
    authenticate)

  if not response then
    error("Couldn't get the install script! Reason: \'" .. err .. "\' (code " .. errResp.getResponseCode() .. ')')
  end

  local content = response.readAll()
  response.close()

  local path = load(content, "install", 't', _ENV)()

  if fs.exists(".kristify_data_backup") then
    fs.delete(fs.combine(path, "data"))
    fs.copy(".kristify_data_backup", fs.combine(path, "data"))
    fs.delete(".kristify_data_backup")
  end
elseif args[1] == "--storage" or args[1] == "-s" then
  os.queueEvent("kstUpdateProducts")
  print("Requested storage update.")
  os.pullEvent("kristify:storageRefreshed")
  print("Refreshed storage.")
elseif args[1] == "--exit" or args[1] == "-e" then
  os.queueEvent("kristify:exit")
  print("Requested kristify exit")
elseif args[1] == "--nbt" or args[1] == "-n" then
  print("NBT Hash of item #1: ")

  local data = turtle.getItemDetail(1, true)
  assert(data, "No data gotten from slot one")

  print(data.nbt or "No NBT data. Leave the field to `nil` or don't define it.")
elseif args[1] == "--help" or args[1] == "-h" then
  print("Usage: " .. (args[0] or "kristify.lua") .. " [flag:]")
  print("-u", "--update", "Updates Kristify.")
  print("-v", "--version", "Shoes the current version.")
  print("-t [name]", "--theme", "Shows or installs a given theme.")
  print("-s", "--storage", "Updates the storage.")
  print("-e", "--exit", "Stops the shop")
  print("-n", "--nbt", "Gets the NBT hash of the item in slot one")
end
