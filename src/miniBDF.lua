local data = {
    FONT = function(font,line)
        font.name = line
    end,
    FONTBOUNDINGBOX = function(font,line)
        local type={"width","height"}--,"offx","offy"}
        local i=1
        for word in string.gmatch(line, '([^ ]+)') do
            if i > #type then return end
            font[type[i]] = tonumber(word) or 0
            i=i+1
        end
        print(font.width,font.height)
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

    return font
end

---Checks for errors a font may have. Should return 0.
---The bigger the results number, the more errors it has.
---@param font table The font that will be checked.
---@return number errors The amount of errors the font has.
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
    checkFont = checkFont
}