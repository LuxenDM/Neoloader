--[[
[metadata]
description=Uninstall Neoloader (stub; requires auth)
version=0.1.0
owner=Neoloader|7.0.0
type=lua
created=2025-11-09
]]--

local neo = ...
local lib = neo.lib

lib.uninstall = function(au)
	if not neo.api.check_auth(au) then
		lib.log_error("uninstall: unauthorized caller", 1)
		return false, "unauthorized"
	end
	
	neo.api.validity_override = true
	lib.lme_configure("override_disabled_plugin_state", "", au)
	lib.lme_configure("allow_bad_api_version", "", au)
	lib.lme_configure("default_load_state", "", au)
	lib.lme_configure("do_err_popup", "", au)
	lib.lme_configure("clear_commands_on_reload", "", au)
	lib.lme_configure("hide_log_message_level", "", au)
	lib.lme_configure("current_if", "", au)
	lib.lme_configure("current_mgr", "", au)
	lib.lme_configure("current_notif", "", au)
	lib.lme_configure("stat_graphing", "", au)
	lib.lme_configure("launch_mode", "removed", au)
	
	local plist = lib.get_gstate().pluginlist
	for _, idvpairs in ipairs(plist) do
		lib.set_load(au, idvpairs[1], idvpairs[2], "REM")
	end
	
	local counter = 0
	local empty_count = 0

	while empty_count < 10 do
		counter = counter + 1

		local reg_entry = gkini.ReadString(
			"Neo-registry",
			"reg" .. tostring(counter),
			""
		)

		if reg_entry == "" then
			empty_count = empty_count + 1
		else
			empty_count = 0
			gkini.WriteString(
				"Neo-registry",
				"reg" .. tostring(counter),
				""
			)
		end
	end
	
	if gkini.ReadString("Vendetta", "if", "") == (neo.path .. "init.lua") then
		gkini.WriteString("Vendetta", "if", "")
	end
	
	gkinterface.GKSaveCfg()
	
	Game.Quit()
end
