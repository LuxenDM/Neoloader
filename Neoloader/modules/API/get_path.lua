--[[
[metadata]
description=Get a plugin's folder path, or infer the caller's own folder from traceback
version=1.1.0
owner=Neoloader|7.0.0
type=lua
created=2025-11-08
]]--

local neo = ...
local lib = neo.lib
local reg = neo.api.registry

-- Return "plugins/<id>/" from a file path-like string; keeps trailing slash.
-- Example:
--	"plugins/Reskin/reskin.lua" -> "plugins/Reskin/"
local extract_folder = function(path)
	return (path:match("^(.-/)[^/]-$"))
end

-- Normalize a relative path by resolving "." and ".." segments.
-- Example:
--	"plugins/!Neoloader/../../plugins/Reskin/reskin.lua" -> "plugins/Reskin/reskin.lua"
local normalize_path = function(path)
	local parts = {}

	for part in path:gmatch("[^/]+") do
		if part == ".." then
			if #parts > 0 then
				table.remove(parts)
			end
		elseif part ~= "." and part ~= "" then
			table.insert(parts, part)
		end
	end

	return table.concat(parts, "/")
end

lib.get_path = function(plugin_id, version)
	----------------------------------------------------------------
	-- CASE A: explicit plugin lookup
	----------------------------------------------------------------
	if type(plugin_id) == "string" then
		plugin_id, version = lib.pass_ini_identifier(plugin_id, version)
		version = tostring(version or "0")

		-- Version "0" means: latest active, or fallback behavior handled by registry.
		if version == "0" then
			local resolved = reg.substitute_zero(plugin_id, "0")
			if not resolved or resolved == "?" then
				return false, "plugin provided doesn't appear to exist"
			end
			version = resolved
		end

		local ok, _, rec = reg.find_plugin(plugin_id, version)
		if not ok or not rec then
			return false, "plugin provided doesn't appear to exist"
		end

		return rec.plugin_folder
	end

	--[[
		CASE B: infer caller's own folder from the Lua traceback
		Policy:
			Anything under neo.path is "internal" (including bundled tools)
			We return the first plugins/<...>/ folder NOT under neo.path
			If traceback paths (not including neoloader) are truncated ("..."), we fail (unreliable)
	]]--
	local trace = debug.traceback()
	local neo_root = tostring(neo.path or "")
	
	--console_print("\n\n" .. trace .. "\n\n")
	
	for line in trace:gmatch("[^\n]+") do
		local file_path = line:match("^%s*(.-):%d+")
		--console_print("file_path: " .. tostring(file_path))
		if line:match("^%s*%.%.%.") then
			if file_path and file_path:find(neo_root, 1, true) then
				-- Safe to ignore: truncated internal Neoloader frame
			else
				lib.log_error("Path inference failed (traceback truncated). Call lib.get_path(id, ver) instead, or reduce length of plugin path.", 1)
				return false, "traceback_truncated_use_explicit_id"
			end

		elseif file_path and file_path:find("plugins/", 1, true) == 1 then
			file_path = file_path:match("^%s*(.-)%s*$") -- trim
			--console_print("trimmed: " .. tostring(file_path))
			-- Ignore anything inside Neoloader's own folder
			if not (file_path:find(neo_root, 1, true) == 1) then
				local folder = extract_folder(file_path)
				if folder then
					return folder
				end
			end
		end
	end

	lib.log_error("Path inference failed (unable to determine caller's path).", 1)
	return false, "unable_to_determine_caller_use_explicit_id"
	
end
