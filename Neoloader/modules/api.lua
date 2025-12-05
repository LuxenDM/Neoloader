--[[
[metadata]
description=Neoloader is an LME API provider. This file is responsible for loading the individual parts of that api.
version=1.0.0
owner=Neoloader|7.0.0
type=lua
created=2025-11-5
]]--

local neo = ...
--lib is declared global by init.lua already

local file_list = {
	"activate_plugin.lua",
	"block_trap.lua",
	"build_ini.lua",
	"check_queue.lua",
	"compare_sem_ver.lua",
	"err_handle.lua",
	"execute.lua",
	"find_file.lua",
	"generate_key.lua",
	"get_API.lua",
	"get_class.lua",
	"get_gstate.lua",
	"get_latest.lua",
	"get_minor.lua",
	"get_patch.lua",
	"get_path.lua",
	"get_state.lua",
	"get_whole_ver.lua",
	"is_exist.lua",
	"is_ready.lua",
	"lme_configure.lua",
	"lme_get_config.lua",
	"lock_class.lua",
	"log_error.lua",
	"notify.lua",
	"open_config.lua",
	"open_if_config.lua",
	"pass_ini_identifier.lua",
	"plugin_read_str.lua",
	"register.lua",
	"reload.lua",
	"request_auth.lua",
	"require.lua",
	"resolve_dep_table.lua",
	"resolve_file.lua",
	"set_class.lua",
	"set_load.lua",
	"set_waiting.lua",
	"uninstall.lua",
	"unlock_class.lua",
	"update_state.lua",
}

for index, api_file in ipairs(file_list) do
	local resolution_path = "API/" .. api_file
	neo.load_module(resolution_path)
end

