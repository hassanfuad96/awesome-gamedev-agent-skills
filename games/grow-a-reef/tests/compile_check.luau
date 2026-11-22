-- Compiles every .luau file under the given folder; exits 1 on a syntax error.
-- Usage (from games/grow-a-reef): lune run tests/compile_check.luau src
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local failures = 0
local function walk(dir)
	for _, name in fs.readDir(dir) do
		local path = dir .. "/" .. name
		if fs.isDir(path) then walk(path)
		elseif string.match(name, "%.luau$") then
			local ok, err = pcall(luau.compile, fs.readFile(path))
			if ok then print("ok   " .. path) else failures += 1; print("FAIL " .. path .. "\n  " .. tostring(err)) end
		end
	end
end
walk(process.args[1])
process.exit(if failures > 0 then 1 else 0)
