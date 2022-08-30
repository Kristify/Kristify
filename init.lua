-- make a copy of package.path
local old_path = package.path

package.path = string.format(
    "/%s/?.lua;/rom/modules/main/?.lua",
    fs.getDir(shell.getRunningProgram())
)

local function main(...)
    -- main init code
end

local args = table.pack(...)
xpcall(function()
    main(table.unpack(args,1,args.n))
end,function(err)
    -- error display

    printError(err)
end)

-- restores package path to original
package.path = old_path
