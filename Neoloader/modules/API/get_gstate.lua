--[[
[metadata]
description=Obtains the LME global state
version=1.1.0
owner=Neoloader|7.0.0
type=lua
created=2025-11-08
]]--

local neo = ...
local reg = neo.api.registry
local get_cfg = neo.api.config.get_config
local cp = console_print

-- v7 get_gstate: snapshot of runtime + registry + selectable managers/IF/notif
neo.lib.get_gstate = function()
	local data = {}

	-- versions / identifiers
	data.version = neo.version		--will be version_provider
	data.lmever_table = neo.lme_ver 	--will be version_lme
	data.lmever = neo.lme_ver.strver	--will be deprecated in favor of table
	data.major = neo.lme_ver[1]		--will be deprecated in favor of table
	data.minor = neo.lme_ver[2]		--will be deprecated in favor of table
	data.patch = neo.lme_ver[3]		--will be deprecated in favor of table
	
	data.version_provider = neo.version
	data.version_lme = neo.lme_ver

	-- locks (through your API getters)
	data.pathlock = neo.api.get_pathlock_value()
	data.statelock = neo.api.get_statelock_value()

	-- current selections from config
	data.manager 		 = get_cfg("current_mgr")   -- deprecated alias
	data.ifmgr   		 = get_cfg("current_if")    -- deprecated alias
	data.current_mgr   = get_cfg("current_mgr")
	data.current_if    = get_cfg("current_if")
	data.current_notif = get_cfg("current_notif")

	-- fallback if IF missing (kept from your draft)
	if not lib.is_exist(data.current_if or "") then
		data.ifmgr = "vo-if"
		data.current_if = "vo-if"
	end

	-- force IF to vo-if if mode is cooperative
	if neo.api.get_exec_mode() == "cooperative" then
		data.ifmgr = "vo-if"
		data.current_if = "vo-if"
	end

	-- logging config/state
	data.log = neo.log
	data.newstate   = get_cfg("default_load_state")		--deprecated alias
	data.format_log = "YES"	--deprecated alias and value, always YES now
	data.log_level  = get_cfg("hide_log_message_level")	--deprecated alias

	-- build plugin list + role lists
	data.pluginlist = {} --list of ALL plugins
	data.mgr_list   = {} --list of LME managers, latest active versions only
	data.if_list    = {"vo-if"} --list of interfaces, latest active versions only
	data.notif_list = {} --list of notifiers, latest active versions only
	local ids_seen = 0
	local list_versions = reg.get_versions_map()
	for id, vers in pairs(list_versions) do
		ids_seen = ids_seen + 1
		
		-- secondary loop: all known versions, active or not
		for _, v in ipairs(vers) do
			data.pluginlist[#data.pluginlist + 1] = { id, v }
			
			local class_tbl = reg.get_container(id, v) or {}
			
			--cp("check: " .. id .. " v" .. v .. ": IF = " .. tostring(class_tbl.IF))
			-- v6 compatibility: roles are simple booleans on the class table
			if class_tbl.mgr then
				table.insert(data.mgr_list, id)
			end
			if class_tbl.IF then
				table.insert(data.if_list, id)
			end
			if class_tbl.notif_handler then
				table.insert(data.notif_list, id)
			end
		end
	end

	return data
end
