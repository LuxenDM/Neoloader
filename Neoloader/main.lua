--[[
[metadata]
description=Default loader entrypoint for Neoloader
version=2.1.0
owner=Neoloader|7.0.0
type=lua
created=2025-7-1
]]--

local lme_flag = false

if type(lib) == "table" and lib[0] == "LME" then
	lme_flag = true
end

local launch_mode_cfg = gkini.ReadString("Neoloader", "launch_mode", "cooperative-first-run")
local local_path = "plugins/Neoloader/"
if not gksys.IsExist(local_path .. "init.lua") then
	local_path = gkini.ReadString("Neoloader", "home_path_override", "plugins/!Neoloader/")
end
if not gksys.IsExist(local_path .. "init.lua") then
	--attempt to get path by sniffing error()

	local ok, err = pcall(function()
		error("Path lookup")
	end)

	if not ok and type(err) == "string" then
		-- Try to extract the filename prefix
		local path = err:match("([^:]+):%d+: Path lookup")
		if path then
			-- Strip filename if needed
			local_path = path:match("^(.-/)[^/]-$")
		end
	end
	
	if not gksys.IsExist(local_path .. "init.lua") then
		--We have NO idea where this file is executing from, and that is a PROBLEM! launch the default interface and inform the user that Neoloader is being run in a very unusual manner. We cannot launch the recovery interface or handle any translations if we cannot guarantee its location
		
		print("Catastrophic error: unable to determine Neoloader directory!")
		print("Please verify you have downloaded the latest version of Neoloader, and attempt reinstallation.")
		
		return
	end
end


local lget = function(key, def)
	local lang_code = gkini.ReadString("Vendetta", "locale", "en")
	return gkini.ReadString2("main", key, def, local_path .. "lang/" .. lang_code .. "/core.ini")
end

--[[ launch_mode_cfg
	cooperative-first-run	- first time, will use cooperative mode.
	cooperative				- running in cooperative mode.
	independent				- running in independent mode.
	removed					- User uninstalled Neoloader
]]--

local stop_error = gkini.ReadString("Neoloader", "STOP", "")

if not lme_flag then
	if stop_error ~= "" then
		print(lget("STOP_PRINT", "Neoloader had a catastrophic error the last time it ran and further execution has been aborted. The stated STOP code was") .. " " .. stop_error)
		print(lget("STOP_PRINT_2", "To remove this message and reinitialize Neoloader, use the /neo command."))
		
		RegisterUserCommand("neo", function()
			console_print("Neoloader re-enabling after a stop-error")
			gkini.WriteString("Neoloader", "STOP", "")
			dofile(local_path .. "init.lua")
		end)
		
		return
	elseif launch_mode_cfg == "removed" then
		print(lget("REM_PRINT", "Neoloader was recently uninstalled, so it will not run. To set it up again, use the /neo command. Otherwise, you can remove this plugin when convenient.")) --make this more approachable?
		
		RegisterUserCommand("neo", function()
			console_print("Neoloader re-enabling after being 'removed'")
			gkini.WriteString("Neoloader", "launch_mode", "cooperative")
			dofile(local_path .. "init.lua")
		
			dofile(local_path .. "setup.lua")
		end)
		
		return
	elseif launch_mode_cfg == "cooperative-first-run" then
		console_print("First-time run of Neoloader")
		
		dofile("init.lua")
		
		dofile("setup.lua")
		
	elseif launch_mode_cfg == "independent" then
		if gkini.ReadString("Vendetta", "if", "") == "" then
			gkini.WriteString("Vendetta", "if", local_path .. "init.lua")
		end
	else
		if not (launch_mode_cfg == "cooperative") then
			console_print("unknown operating mode, defaulting to cooperative")
		end
	
		console_print("Starting Neoloader in cooperative mode!")
		dofile("init.lua")
	end
end