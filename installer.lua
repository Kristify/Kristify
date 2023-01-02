if not http then
    error("This installer does not work without http API!")
  end
  print("Please wait...")
  
  local authenticate = _G._GIT_API_KEY and {Authorization = "Bearer ".._G._GIT_API_KEY}
  local basaltDL = http.get("https://raw.githubusercontent.com/Kristify/kristify/main/src/libs/basalt.lua", authenticate)
  assert(basaltDL, "Couldn't load Basalt into memory!")
  local basaltFile = basaltDL.readAll()
  local basalt = load(basaltFile)()
  basaltDL.close()
  local errors = false
  
  -- Disk space
  local nBarW = 0
  local nLen = 0
  local nStartPos = 0
  
  -- Basic frame construction
  local base = basalt.createFrame()
  local title = base:addLabel("_title")
    :setText("Kristify")
    :setPosition(2,2)
    :setFontSize(2)
  local page = base:addLabel("_page")
    :setText("1/4")
    :setPosition("parent.w-self.w-1",4)
  base:addPane()
    :setPosition(2,5)
    :setSize("parent.w-2",1)
    :setBackground(false, '\140', colors.gray)
  local content = base:addFrame("_content")
    :setPosition(2,6)
    :setSize("parent.w-2","parent.h-5")
    :setBackground(colors.lightGray)
  
  -- En- or disable keyboard input
  local blockInput = false
  basalt.onEvent(function(event, value)
    if not blockInput then return end
    if event == "char"
    or (event:find("key") and value == keys.backspace or value == keys.enter) then
        return false
    end
  end)
  
  local welcome,licence,destination,install,done = 
    content:addFrame("_welcome")    :setBackground(colors.lightGray):show(),
    content:addFrame("_licence")    :setBackground(colors.lightGray):hide(),
    content:addFrame("_destination"):setBackground(colors.lightGray):hide(),
    content:addFrame("_install")    :setBackground(colors.lightGray):hide(),
    content:addFrame("_done")       :setBackground(colors.lightGray):hide()
  
  local function justinWeHaveAProblem(err)
    error(err)
  end
  
  --[[ Actuall installer ]]
  local nRequired = 0
  
  local tURLs = {}
  tURLs.owner = "Kristify"
  tURLs.repo = "kristify"
  tURLs.branch = "main"
  tURLs.tree = "https://api.github.com/repos/"..tURLs.owner.."/"..tURLs.repo.."/contents/?ref="..tURLs.branch
  tURLs.infos = "https://api.github.com/repos/"..tURLs.owner.."/"..tURLs.repo
  
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
  
  local function generateTree(sURL)
      sURL = sURL or tURLs.tree
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
          if not (sName:sub(1,1) == '.' or sName:find(".md") or sName == "installer.lua" or sName:find("basalt") or sName == "docs") then
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
  
  -- Installs kristify
  local pathToInstall = ""
  local function installKristify(install)
    sleep(0.2)
    if pathToInstall == "" then pathToInstall = "/" end
  
    local status = install:getObject("_status")
    status:editLine(1,"Status: Create folder..")
    
    justinWeHaveAProblem = function(errMsg)
      status:editLine(2,"ERROR! "..errMsg)
      return true
    end
  
    fs.delete(pathToInstall)
    fs.makeDir(pathToInstall)
    
    status:editLine(1,"Status: Generating tree..")
    status:addLine("")
    status:addLine(" \026 "..(pathToInstall:sub(1,1) == "/" and pathToInstall:sub(2) or pathToInstall))
    local tree = generateTree()
    
    local function listItems(tree,depth)
      local size = 0
      for _,_ in pairs(tree) do size = size+1 end
      
      local index = 1
      for name,item in pairs(tree) do
        local begin = "   "..("\149 "):rep(depth-1)..(index>=size and '\141' or '\157'):rep(depth-(depth-1))..' '
        
        status:addLine(begin..name)
        if type(item) == "table" then
          listItems(item, depth+1)
        end
        index = index+1
      end
    end
  
    listItems(tree, 1)
  
    status:editLine(1,"Status: Download files..")
    local index = 3
    local function nextStep(char)
      local line = status:getLine(index)
      if line then
        line = " "..char.." "..line:sub(4)
        status:editLine(index, line)
      end
  
      index = index+1
      line = status:getLine(index)
      if line then
        line = " \026 "..line:sub(4)
        status:editLine(index, line)
      end
    end
    nextStep(' ')
    
    local function downloadItems(tree,sPath)
      sleep(0.3)
      for name,item in pairs(tree) do
        local nextPath = fs.combine(sPath,name)
        if type(item) == "table" then
          nextStep(' ')
          downloadItems(item,nextPath)
        else
          nextStep(downloadBlob(item,nextPath) and '\183' or '\019')
        end
      end
    end
  
    downloadItems(tree,pathToInstall)
  
    for _=1,3 do
      status:addLine("")
    end
  
    -- Next page
    install:addButton()
    :setPosition("parent.w-9","parent.h-1")
    :setSize(10,1)
    :setText("Done")
    :setBackground(colors.green)
    :setForeground(colors.white)
    :onClick(function()
      if errors then
        os.queueEvent("terminate")
        return
      end
      install:hide()
      title:setText("Done")
      page:setText(" :)")
      done:show()
      blockInput = false
    end)
  end
  
  
  local function addFrame(frame,nX,nY, nW)
    frame:addLabel()
      :setPosition(nX,nY)
      :setBackground(colors.gray)
      :setForeground(colors.lightGray)
      :setText('\159')
    frame:addPane()
      :setPosition(nX,nY)
      :setSize(nX+nW,1)
      :setBackground(colors.gray, '\143', colors.lightGray)
    frame:addLabel()
      :setPosition(nX+nW+1,nY)
      :setBackground(colors.lightGray)
      :setForeground(colors.gray)
      :setText('\144')
    frame:addLabel()
      :setPosition(nX,nY+1)
      :setBackground(colors.gray)
      :setForeground(colors.lightGray)
      :setText("\149")
    frame:addLabel()
      :setPosition(nX+nW+1,nY+1)
      :setBackground(colors.lightGray)
      :setForeground(colors.gray)
      :setText("\149")
    frame:addPane()
      :setPosition(nX,nY+2)
      :setSize(nX+nW,1)
      :setBackground(colors.lightGray, '\131', colors.gray)
    frame:addLabel()
      :setPosition(nX,nY+2)
      :setBackground(colors.lightGray)
      :setForeground(colors.gray)
      :setText('\130')
    frame:addLabel()
      :setPosition(nX+nW+1,nY+2)
      :setBackground(colors.lightGray)
      :setForeground(colors.gray)
      :setText('\129')
  end
  
  --[[ Welcome ]]
  welcome:addLabel()
    :setPosition(1,1)
    :setSize("parent.w-2","4")
    :setText("Welcome! Thank you for choosing this product! With Kristify you are able to set up a shop easily and comfortable!")
  welcome:addLabel()
    :setPosition(1,5)
    :setSize("parent.w-10","3")
    :setText("To continue, click on \"Next\". To cancel, press CTRL+T at any time.")
  -- Next page
    welcome:addButton()
    :setPosition("parent.w-9","parent.h-1")
    :setSize(10,1)
    :setText("Next")
    :setBackground(colors.green)
    :setForeground(colors.white)
    :onClick(function()
      welcome:hide()
      title:setText("Licence")
      page:setText("2/4")
      licence:show()
      blockInput = true
    end)
  
  --[[ Licence agreement ]]
  local textfield = licence:addTextfield()
    :setPosition(1,2)
    :setSize("parent.w","parent.h-4")
    :setForeground(colors.white)
  do
    local sKristifyLicence = http.get("https://raw.githubusercontent.com/Kristify/kristify/main/LICENSE")
    repeat
      local line = sKristifyLicence.readLine()
      if line then
        textfield:addLine(line)
      end
    until not line
    sKristifyLicence.close()
  end
  -- Checkbox frame
  local nW,nH = licence:getSize()
  addFrame(licence, 1, nH-2, 1)
  -- Checkbox label
  licence:addLabel()
    :setPosition(4,"parent.h-1")
    :setText("I accept the agreement")
  -- Instruction
  licence:addLabel()
    :setPosition(1,1)
    :setText("Scroll to read the licence agreement.")
  -- Checkbox
  local checkbox = licence:addCheckbox()
  :setPosition(2,"parent.h-1")
  :setBackground(colors.white)
  :setSymbol('x')
  -- Next page
  local nextBtn = licence:addButton()
    :setPosition("parent.w-9","parent.h-1")
    :setSize(10,1)
    :setText("Next")
    :setBackground(colors.gray)
    :setForeground(colors.black)
    :onClick(function()
      if checkbox:getValue() then
        licence:hide()
        title:setText("Destination")
        page:setText("3/4")
        destination:show()
        blockInput = false
  
        local note = destination:getObject("_note")
        justinWeHaveAProblem = function(err)
          note:setText(err)
          destination:removeObject("_next")
        end
      
        local response,sErr,errResponse = http.get(tURLs.infos, authenticate)
        httpError(response,sErr,errResponse)
      
        local tData = getJSON(response)
        nRequired = math.floor(tData.size-(#basaltFile/1000)/100*70) or 0
        if nRequired <= 0 then
          destination:removeObject("_next")
          note:setText("Something went wrong! Reason: \'"..sErr.."\' ("..errResponse.getResponseCode()..')')
        end
        -- Required space
        local nRequiredLen = (nRequired*1000)/fs.getCapacity('/')*100
        destination:addFrame()
          :setPosition(nStartPos,6)
          :setSize(nRequiredLen,1)
          :setBackground(colors.lightGray)
          :addPane()
            :setPosition(1,1)
            :setSize("parent.w",1)
            :setBackground(false, '\140', colors.lime)
        destination:addLabel()
          :setPosition(nStartPos+1,9)
          :setText("\024Required")
        if nRequiredLen+nLen >= 65 then
          destination:removeObject("_freeLabel")
        end
        if nRequiredLen+nLen >= 95 then
          destination:removeObject("_next")
          note:setText("Not enough space! At least ~"..nRequired.."kb must be free.")
        end
  
        -- Cooldown
        if destination:getObject("_next") then
          destination:addThread()
          :start(function()
            local btn = destination:getObject("_next")
            for i=3,1,-1 do
              btn:setText(tostring(i))
              sleep(0.8)
            end
            btn:setText("install")
              :setBackground(colors.green)
              :setForeground(colors.white)
          end)
        end
      end
    end)
  -- Checkbox
  checkbox:onChange(function(self)
    if self:getValue() then
      nextBtn
        :setBackground(colors.green)
        :setForeground(colors.white)
    else
      nextBtn
        :setBackground(colors.gray)
        :setForeground(colors.black)
    end
  end)
  
  --[[ Destination ]]
  local nW = destination:getSize()
  destination:addLabel()
    :setPosition(1,1)
    :setText("Select the installation location:")
  -- Input frame
  addFrame(destination, 2,2, nW-4)
  -- Input
  local input = destination:addInput()
    :setPosition(3,3)
    :setSize("parent.w-4")
    :setBackground(colors.white)
    :setInputType("text")
    :setDefaultText("/")
    :setValue("/kristify")
  -- (from/to)
  destination:addLabel()
    :setPosition(1,6)
    :setText("0b")
  local maxMb = destination:addLabel()
    :setPosition("parent.w-self.w+1",6)
    :setText(math.floor(fs.getCapacity('/')/1000000).."mb")
  -- Disk Space
  local spaceLeft = destination:addProgressbar()
    :setPosition(3,6)
    :setSize(nW-(2+maxMb:getSize()),1)
    :setDirection(0)
    :setProgressBar(colors.lightGray, "\140", colors.green)
    :setBackground(colors.lightGray)
    :setForeground(colors.gray)
    :setBackgroundSymbol('\140')
    :setProgress( (fs.getCapacity('/')-fs.getFreeSpace('/'))/fs.getCapacity('/')*100+1 )
  -- Disk space labels
  nBarW = spaceLeft:getSize()
  nLen = math.floor(spaceLeft:getProgress()-0.9)
  nStartPos = 3+(nBarW/100*nLen)
  destination:addLabel()
    :setPosition(nStartPos-1+(nLen<=1 and 1 or 0),5)
    :setForeground(colors.gray)
    :setText("\025Used")
  destination:addLabel("_freeLabel")
    :setPosition("parent.w-8",5)
    :setForeground(colors.gray)
    :setText("Free\025")
  -- Note
  destination:addLabel("_note")
    :setPosition(1,"parent.h-1")
    :setSize("parent.w-10",3)
    :setForeground(colors.red)
    :setText("\026Note: The choosen folder will be completely erased during install!")
  -- Next page
  destination:addButton("_next")
  :setPosition("parent.w-8","parent.h-1")
  :setSize(9,1)
  :setText("")
  :setBackground(colors.gray)
  :setForeground(colors.black)
  :onClick(function(self)
    if self:getBackground() ~= colors.gray then
      destination:hide()
      title:setText("Installing")
      page:setText("4/4")
      install:show()
      blockInput = true
  
      pathToInstall = input:getValue()
  
      -- Install script
      destination:addThread()
        :start(function()
          installKristify(install)
        end)
    end
  end)
  
  --[[ Install ]]
  install:addLabel()
    :setPosition(1,1)
    :setSize("parent.w",1)
    :setText("Take a seat and wait until the magic happened!")
  install:addTextfield("_status")
    :setPosition(1,2)
    :setSize("parent.w","parent.h-2")
    :setForeground(colors.white)
    :addKeywords(colors.red, {"ERROR!"})
    :addRule("[\149\157\141]", colors.lightGray)
    :addRule("\183", colors.green)
    :addRule("\019", colors.red)
  
  --[[ Done ]]
  done:addLabel()
    :setPosition(1,1)
    :setText("And thats it! You now own a shop! ")
  -- Checkbox label
  local _,nH = done:getSize()
  addFrame(done, 1, nH-2, 1)
  done:addLabel()
    :setPosition(4,"parent.h-1")
    :setText("Enable start on boot")
  -- Checkbox
  local checkbox = done:addCheckbox()
    :setPosition(2,"parent.h-1")
    :setBackground(colors.white)
    :setSymbol('x')
    :setValue(true)
  
  -- Exit
  done:addButton()
    :setPosition("parent.w-9","parent.h-1")
    :setSize(10,1)
    :setText("Exit")
    :setBackground(colors.green)
    :setForeground(colors.white)
    :onClick(function()
      local script = "shell.openTab( \""..fs.combine(pathToInstall,"src","init.lua").."\" )"
      local file = "kristify.lua"
      if checkbox:getValue() then
        if fs.exists("/startup.lua") then
          file = fs.open("/startup.lua",'a')
        else
          fs.makeDir("startup")
          file = fs.open(fs.combine("startup","kristify.lua"),'w')
        end
      else
        file = fs.open(file, 'w')
      end
      file.write(script)
      file.close()
  
      basalt.stopUpdate()
    end)
  
  basalt.autoUpdate()
return pathToInstall
