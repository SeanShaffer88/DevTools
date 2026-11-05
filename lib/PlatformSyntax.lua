-- Compile one explicit file without executing its chunk. Lua 5.1+.
if not arg[1] then io.stderr:write("A source path is required\n"); os.exit(2) end
local chunk, message = loadfile(arg[1])
if not chunk then io.stderr:write(message, "\n"); os.exit(1) end
