--[[
[metadata]
description=Patching system for Neoloader; after an update, this edits configuration values and behaviors that would otherwise be incompatible.
version=1.0.0
owner=Neoloader|7.0.0
type=lua
created=2026-3-10
]]--

local neo = ...

--executes before config loads; can edit config directly without being 'unwritten' by game-end catch

local update_check_num = gkini.ReadInt("Neoloader", "update_check", 0)
local total_patch_count = 2

--update check
if update_check_num < total_patch_count then
	if update_check_num == 0 then --Update pre-existing config from Neoloader 6.1.x -> 6.2.0
		lib.log_error("Neoloader was updated from v6.1.x or earlier - applying configuration fixes for v6.2.0", 3)
		
		local registry_fixes = {
			["plugins/Neoloader/neomgr.ini"] = neo.path .. "modules/neomgr/neomgr.lua",
			["plugins/Neoloader/neo_notif.ini"] = neo.path .. "modules/neomgr/neo_notif.lua",
		}

		local counter = 0
		while true do
			counter = counter + 1
			local reg = gkini.ReadString("Neo-registry", "reg" .. tostring(counter), "")
			if reg == "" then
				break
			end

			if registry_fixes[reg] then
				gkini.WriteString("Neo-registry", "reg" .. tostring(counter), registry_fixes[reg])
				lib.log_error("patched registration entry for " .. reg .. " >> " .. registry_fixes[reg], 1)
			end
		end

		update_check_num = 1
		gkini.WriteInt("Neoloader", "update_check", 1)
	end
	
	if update_check_num == 1 then
		lib.log_error("Neoloader was updated from v6.3.x or earlier - applying configuration fixes for v7.0.0", 3)
		
		gkini.WriteString("Neoloader", "current_if", "vosi-bridge")
		
		--update_check_num = 2
		--gkini.WriteInt("Neoloader", "update_check", 2)
	end
end