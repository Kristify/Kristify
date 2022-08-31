return {
    new = function(str)
        return {
            type="label",
            content=str
        }
    end,
    draw = function(label,ctx)
        local w,_ = term.getSize()
        local _,y = term.getCursorPos()
        term.setTextColor(ctx.color.secondary)

        -- split words
        local content = {}
        for word in label.content:gmatch('([^ ]+)') do
            table.insert(content,word)
        end

        -- Split lines
        local len = 0
        local splits = {}
        for i=1,#content do
            len = len+#content[i]+1
            if len > w/2 or i==#content then
                table.insert(splits,{i,len})
                len = 0
            end
        end

        -- Render
        for i=1,#splits do
            term.setCursorPos((w-splits[i][2])/2,y+i-1)
            local begin = 1
            if i > 1 then 
                begin = splits[i-1][1]+1
            end

            for j=begin,splits[i][1] do
                term.write(' '..content[j])
            end
        end
    end
}