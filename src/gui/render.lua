return {
    new = function(name)
        return {name=name}
    end,
    draw = function(page,ctx)
        local w,h = term.getSize()

        if ctx.redraw then
            term.setBackgroundColor(ctx.color.bg)
            term.clear()
            ctx.redraw = false
        end

        -- Widgets
        term.setBackgroundColor(ctx.color.bg)
        local y = 3+ctx.scroll
        for i=1,#page do
            term.setCursorPos(0,y+2)
            if page[i].type then
                if ctx.gui[page[i].type] then
                    ctx.gui[page[i].type].draw(page[i], ctx)
                end
            end
            _,y = term.getCursorPos()
        end

        page.length = y-(4+ctx.scroll)
        if page.length < 3 then page.length = 3 end

        -- Header
        local line = (' '):rep(w)
        term.setBackgroundColor(ctx.color.primary)
        for y=1,3 do
            term.setCursorPos(1,y+ctx.scroll)
            term.write(line)
        end
    end
}