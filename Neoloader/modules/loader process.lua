--[[
[metadata]
description=After setting up the environment, the loader is activated to begin executing LME plugins from the registry
version=1.0.0
owner=Neoloader|7.0.0
type=lua
created=2025-11-17
]]--

local neo = ...
local config = neo.api.config
local registry = neo.api.registry
local rs = neo.api.recovery_system
local stats = neo.stats
local lib = neo.lib

local exec_mode = neo.api.get_exec_mode() == "independent" --cooperative or independent

local checkpoint = function(msg)
	stats.checkpoint("[loader] " .. msg)
end

local cp = function(msg, lv)
	lib.log_error("[loader] " .. msg, lv)
end


--[[
	inspect
	build
	trigger
]]--

checkpoint("LME loader is starting...")



local inspect_registry = function()
	checkpoint("Finding entries in the registry list")
	local ini_list = {}
	local index = 1
	local cleanse_flag = false
	
	while true do
		local ini_entry = gkini.ReadString("Neo-registry", "reg" .. tostring(index), "")
		if ini_entry == "" then
			index = index - 1
			break
		end
		
		local ini_data, build_err = registry.build_ini(ini_entry)
		if not ini_data then
			cp("Plugin at registration index " .. tostring(index) .. " appears broken!")
			cleanse_flag = true
		else
			ini_data.new_entry = false
			ini_data.load_position = index
			ini_data.load = gkini.ReadString("Neo-pluginstate",
				ini_data.plugin_id .. "." .. ini_data.plugin_version, "NO")

			table.insert(ini_list, ini_data)
		end
		
		index = index + 1
	end
	
	cp("Found " .. tostring(#ini_list) .. " valid entries out of " .. tostring(index) .. " lines")
	if cleanse_flag then
		lib.notify("NEO_REGISTRY_DIRTY", {
			expected = #ini_list,
			total = index,
		})
	end
	
	return ini_list
end

local build_registry_from_list = function(ini_list)
	checkpoint("building internal database from list")
	
	for i, ini_data in ipairs(ini_list) do
		local ok, err = registry.add_new_plugin(ini_data)
		if not ok then
			cp("failed to import plugin to database!\n\t" .. ini_data.plugin_id .. " v" .. ini_data.plugin_version .. "\n\t" .. ini_data.plugin_regpath .. "\n\t" .. err, 4)
		end
	end
end

local trigger_plugins = function(ini_list)
    checkpoint("Queuing" .. (exec_mode and " and launching " or " ") .. "plugins...")

    local if_id = config.get_config("current_if")
    local if_ver = nil
	
	--todo: flatten exec_mode checks
	if (exec_mode) and (not neo.api.get_statelock_value()) and (if_id) and (if_id ~= "") then
        -- ask registry for the latest *active* version of the interface ID
        local status, ver = registry.get_latest_ver(if_id)
        if not status then
            cp("Interface '" .. if_id .. "' not available (" .. tostring(ver) .. "); falling back to vo-if!", 3)
            dofile("vo/if.lua")
            checkpoint("Finished launching vo-if!")
        else
            if_ver = ver
            cp("Launching interface " .. if_id .. " v" .. if_ver, 1)
            lib.activate_plugin(if_id, if_ver, neo.auth_key)

            if lib.is_ready(if_id, if_ver) then
                checkpoint("Interface loaded successfully!")
            else
                checkpoint("Failed to load interface! Falling back to vo-if!")
                dofile("vo/if.lua")
                checkpoint("Finished launching vo-if!")
            end
        end
    elseif exec_mode and (not neo.api.get_statelock_value()) then
        cp("No interface configured; falling back to vo-if!", 3)
        dofile("vo/if.lua")
        checkpoint("Finished launching vo-if!")
    end

    -- now queue all other plugins (skip disabled and skip the interface we just loaded)
    for i, ini_data in ipairs(ini_list) do
        local id  = ini_data.plugin_id
        local ver = ini_data.plugin_version

        -- 1) skip disabled
        if ini_data.load ~= "NO" then
            -- 2) skip the already-activated interface version
            if not (if_id and if_ver and id == if_id and ver == if_ver) then
                local deps = ini_data.plugin_dependencies or {}
                lib.require(deps, function()
                    lib.activate_plugin(id, ver, neo.auth_key)
                end, id, ver)
            end
        end
    end

    -- make sure any remaining dep-waiters get a chance to activate
    lib.check_queue()

    checkpoint("LME Plugin loader has finished queuing and launching plugins")
end



do
    local ini_list = inspect_registry()
    build_registry_from_list(ini_list)

    if exec_mode then
        -- independent mode: safe to schedule + activate immediately
		cp("Independent mode, plugins can be launched immediately!", 1)
        trigger_plugins(ini_list)
        ProcessEvent("LME_PLUGINS_LOADED")
	elseif neo.api.get_statelock_value() then
		trigger_plugins(ini_list)
		ProcessEvent("LME_PLUGINS_LOADED")
    else
		if neo.api.get_statelock_value() then
			cp("Late trigger setup, statelock is engaged; plugins will be launched momentarily", 1)
		else
			-- cooperative mode: schedule now, but activation will be delayed
			-- by loader_blocked() until the game's PLUGINS_LOADED.
			cp("Cooperative mode, plugins will be delayed until after default loader completes!", 1)
		end
        trigger_plugins(ini_list)

        RegisterEvent(function()
            -- At this point pathlock should be off; drain the queue and
            -- then announce that LME plugins have finished loading.
            lib.check_queue()
            ProcessEvent("LME_PLUGINS_LOADED")
        end, "LME_PLUGINS_TRIGGER")
    end
end
