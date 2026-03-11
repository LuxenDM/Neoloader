--[[
[metadata]
description=Find a file with pathlock awareness; returns first hit and a list of candidate triplets
version=1.1.0
owner=Neoloader|7.0.0
type=lua
created=2025-11-08
]]--

local neo = ...
local lib = neo.lib


lib.find_file = function(file, ...)
	if lib.err_handle(type(file) ~= "string", "lib.find_file expected a string as argument 1, got " .. type(file)) then
		return false, "file not a string"
	end

	local path_checks = {}
	local pathlist = { ... }

	-- v6 compatibility: resolve_file(file, nil, path) => (file, path)
	if pathlist[2] and not pathlist[1] then
		table.remove(pathlist, 1)
	end

	lib.log_error("Attempting to find " .. file, 1)

	-- If 'file' includes a path, split it and seed checks
	local last_slash_index = string.find(file, "/[^/]*$")
	if last_slash_index then
		local base = string.sub(file, 1, last_slash_index)	 -- keeps trailing slash
		local name = string.sub(file, last_slash_index + 1)
		file = name
		table.insert(path_checks, { base .. file, "../" .. base .. file, "../../" .. base .. file })
	end

	-- Add provided bases
	for _, base in ipairs(pathlist) do
		table.insert(path_checks, { base .. file, "../" .. base .. file, "../../" .. base .. file })
	end

	-- Pathlock-aware fallbacks
	-- Independent mode (pathlock=false): same as v6 root-relative attempts
	-- Pathlock=true: CWD is already sandboxed; ../ and ../../ serve as the “escape attempts”
	if neo.pathlock then
		table.insert(path_checks, { file, "../" .. file, "../../" .. file })
	else
		table.insert(path_checks, { file, "../" .. file, "../../" .. file })
	end

	local first_valid_path = false
	local valid_path_table = {}

	for _, triplet in ipairs(path_checks) do
		local p = triplet[1]
		lib.log_error("				" .. p, 1)

		if gksys.IsExist(p) then
			first_valid_path = first_valid_path or p
			table.insert(valid_path_table, triplet)
		end
	end

	return first_valid_path, valid_path_table
end
