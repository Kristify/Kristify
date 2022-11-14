---Converts a given table to a blit char.
---@param str string Something like: "100110" for \153
---@return string sChar Matching counter part
---@return boolean bReversed Swaped text & background color?
local function toBlit(str)
    if type(str) ~= "string" or #str < 6 then
        str = "000000"
    elseif str:sub(1,1) == '#' then
        return str:sub(2,2), false
    end
    local t = {}
    for i=1,6 do
        t[#t+1] = tonumber(str:sub(i,i)) or 0
    end

    if t[6]==1 then
        for i=1,5 do
            t[i] = 1-t[i]
    end end
    local n = 128
    for i=0,4 do
        n = n+t[i+1]*2^i
    end

    return string.char(n), (t[6] == 1)
end

---Converts a given char to a table,
---representing pixels in the current font.
---@param font table The font, generated with bdf.loadBDF(...)
---@param char string The char (e.g. "f")
---@return table char The char in the current font, as table
local function drawChar(font, char)
    local char = font.bitmap[char:byte()]
    -- Return empty
    if not char then
        if not font.bitmap[63] then
            local width,height = font.width,font.height
            local tmp = (' '):rep(width)
            local char = {}
            for y=1,height do
                char[#char+1] = tmp
            end
            return char
        else
            char = font.bitmap[63]
        end
    end

    -- Get bitmap
    local result = {}
    local j=0
    for i=#char,1,-1 do
        result[font.width-j-char.bound.offy-font.offy] = char[i]
        j=j+1
    end
    -- Fill gaps
    for i=1,font.height do
        if not result[i] then
            result[i] = ('0'):rep(font.width)
        else
            if char.bound.offx > 0 then
                result[i] = ('0'):rep(char.bound.offx)..result[i]
            end
            if #result[i] < font.width then
                result[i] =result[i]..('0'):rep(font.width-#result[i])
            end
        end
    end

    return result
end

---Same as drawChar but with strings.
---@param font The font, generated with bdf.loadBDF(...)
---@param str string The string (e.g. "Hello")
---@return table str The string in the current font, as table
local function drawString(font, str)
    local string = {}
    for x=1,#str do
        local char = font:drawChar(str:sub(x))
        for y=1,#char do
            if not string[y] then string[y] = "" end
            string[y] = string[y]..char[y]
        end
    end
    return string
end

local function needsSpace(len,expected)
    local add = 0
    while math.floor((len+add)/expected) ~= ((len+add)/expected) do
        add = add+1
    end
    return add
end

local blit = {[1]='0',[2]='1',[4]='2',[8]='3',[16]='4',[32]='5',[64]='6',[128]='7',[256]='8',[512]='9',[1024]='a',[2048]='b',[4096]='c',[8192]='d',[16384]='e',[32768]='f' }
---Converts a bitmap table into a one represented by box chars.
---@param str table The bitmap (could be via font:drawChar("..."))
---@param bg number The Background color
---@param fg number The Background color
---@return table blits The result
local function compress(str, bg,fg)
    local addX = needsSpace(#str[1],2)
    local addY = needsSpace(#str,3)
    if addX > 0 then
        for i=1,#str do
            str[i] = str[i]..('0'):rep(addX)
        end
    end
    if addY > 0 then
        for i=1,addY do
            str[#str+1] = ('0'):rep(#str[1])
        end
    end

    local blits = {
        ch={},
        bg={},
        fg={}
    }
    for y=1,#str/3 do
        blits.ch[y] = ""
        blits.bg[y] = ""
        blits.fg[y] = ""
    end

    for x=1,#str[1]/2 do
        for y=1,#str/3 do
            local char,invert = toBlit(
                str[y*3-2]:sub(x*2-1,x*2)..
                str[y*3-1]:sub(x*2-1,x*2)..
                str[y*3-0]:sub(x*2-1,x*2)
            )
            blits.ch[y] = blits.ch[y]..char
            local c1,c2 = blit[bg],blit[fg]
            if invert then
                c2,c1 = blit[bg],blit[fg]
            end
            blits.bg[y] = blits.bg[y]..c1
            blits.fg[y] = blits.fg[y]..c2
        end
    end
    return blits
end


local data = {
    FONT = function(font,line)
        font.name = line
    end,
    FONTBOUNDINGBOX = function(font,line)
        local type={"width","height","offx","offy"}
        local i=1
        for word in string.gmatch(line, '([^ ]+)') do
            if i > #type then return end
            font[type[i]] = tonumber(word) or 0
            i=i+1
        end
    end,
    CHARSET_REGISTRY = function(font,line)
        if line:find("ISO") and line:find("8859") then
            font.validCharReg = font.validCharReg+1
        end
    end,
    CHARSET_ENCODING = function(font,line)
        if line:find("\"1\"") then
            font.validCharReg = font.validCharReg+1
        end
    end,
    CHARS = function(font,line)
        local num = tonumber(line) or 0
        if num == 256 then
            font.validCharReg = font.validCharReg+1
        end
    end,
    STARTCHAR = function(font,line)
        font._CUR_CHAR = {name=line}
    end,
    ENCODING = function(font,line)
        if not font._CUR_CHAR then return end
        font._CUR_CHAR.byte = tonumber(line) or 0
    end,
    BBX = function(font, line)
        local i=1
        local b = {"width","height","offx","offy"}
        font._CUR_CHAR.bound = {}
        for word in string.gmatch(line, '([^ ]+)') do
            if i > #b then return end
            font._CUR_CHAR.bound[b[i]] = tonumber(word) or 0
            i=i+1
        end
    end,
    BITMAP = function(font,_)
        font.isBitmap = true
    end
}

---Parses a .BDF font file into a in lua readable table.
---@param path string The path to the .BDF file
---@return table font The result
local function loadBDF(path)
    if not (fs.exists(path) and not fs.isDir(path)) then
        return printError("Could not load: \'"..path.."\'!")
    end

    local f = fs.open(path, 'r')
    local font = {bitmap={},validCharReg=0,isBitmap=false}

    local line = f.readLine()
    repeat
        if font.isBitmap then
            if line:find("ENDCHAR") then
                -- Finishing
                font.isBitmap = false
                local byte = font._CUR_CHAR.byte
                font._CUR_CHAR.byte = nil
                font.bitmap[byte] = {}
                for k,v in pairs(font._CUR_CHAR) do
                    font.bitmap[byte][k] = v
                end
                font._CUR_CHAR = nil
            else
                local num = tonumber("0x"..line)
                if not num then return end

                local function ffs(value)
                    if value == 0 then return 0 end
                    local pos = 0;
                    while bit32.band(value, 1) == 0 do
                        value = bit32.rshift(value, 1);
                        pos = pos + 1
                    end
                    return pos
                end

                local l = ""
                local w = math.ceil(math.floor(math.log(num) / math.log(2)) / 8) * 8
                for i = ffs(num) or 0, w do
                    l = l..bit32.band(bit32.rshift(num, i-1), 1)
                end
                l = l:reverse()
                local w = font._CUR_CHAR.bound.width
                if #l > w then
                    l = l:sub(1,w)
                elseif #l < w then
                    l = l..('0'):rep(w-#l)
                end

                font._CUR_CHAR[#font._CUR_CHAR+1] = l
            end
        else
            local label = line:match('([^ ]+)')
            if data[label] then
                data[label](font, line:sub(#label+2))
            end
        end
        line = f.readLine()
    until line == nil

    f.close()
    font.isBitmap = nil
    font.validCharReg = (font.validCharReg == 3)
    font.drawChar = drawChar
    font.drawString = drawString
    return font
end

---Checks for errors a font may have. Should return 0.
---The bigger the results number, the more errors it has.
---@param font table The font that will be checked.
---@return number errors The amount of errors the font has.
---@return table messages The error messages
local function checkFont(font)
    local msg = {}
    local errorCounter = 0
    if type(font.name) ~= "string" then
        errorCounter = errorCounter+1
        table.insert(msg,"Font has no name.")
    elseif type(font.width) ~= "number" then
        errorCounter = errorCounter+1
        table.insert(msg,"Font has no global width.")
    elseif type(font.height) ~= "number" then
        errorCounter = errorCounter+1
        table.insert(msg,"Font has no global height.")
    elseif not font.validCharReg then
        errorCounter = errorCounter+1
        table.insert(msg,"Font uses not supported format.")
    elseif type(font.bitmap) ~= "table" then
        errorCounter = errorCounter+1
        table.insert(msg,"Font has no bitmaps (nothing to render)")
    elseif #font.bitmap ~= 255 then
        errorCounter = errorCounter+1
        table.insert(msg,"Font may have missing chars.")
    end
    return errorCounter,msg
end

return {
    loadBDF = loadBDF,
    checkFont = checkFont,
    compress = compress
}