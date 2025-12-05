--[[
[metadata]
description=Get a plugin's folder path, or infer the caller's own folder from traceback
version=1.0.0
owner=Neoloader|7.0.0
type=lua
created=2025-11-08
]]--

local neo = ...
local lib = neo.lib
local reg = neo.api.registry

-- return "plugins/<id>/" from a file path-like string; keeps trailing slash
local function extract_folder(p)
  return (p:match("^(.-/)[^/]-$"))
end

-- normalize "plugins/!Neoloader/../../plugins/Reskin/reskin.lua"
-- into       "plugins/Reskin/reskin.lua"
local function normalize_path(p)
  local parts = {}
  for part in p:gmatch("[^/]+") do
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

local cp = console_print

lib.get_path = function(plugin_id, version)
  ----------------------------------------------------------------
  -- CASE A: explicit plugin lookup (legacy behavior)
  ----------------------------------------------------------------
  if type(plugin_id) == "string" then
    plugin_id, version = lib.pass_ini_identifier(plugin_id, version)
    version = tostring(version or "0")
    if version == "0" then
      local sub = reg.substitute_zero(plugin_id, "0")
      if not sub or sub == "?" then
        return false, "plugin provided doesn't appear to exist"
      end
      version = sub
    end

    local ok, _, rec = reg.find_plugin(plugin_id, version)
    if not ok or not rec then
      return false, "plugin provided doesn't appear to exist"
    end
    return rec.plugin_folder
  end

  ----------------------------------------------------------------
  -- CASE B: infer caller's own folder from the Lua traceback
  ----------------------------------------------------------------
  local trace = debug.traceback()

  local loader_root = neo.path or "plugins/!Neoloader/"  -- e.g., "plugins/!Neoloader/"
  loader_root = loader_root:gsub("([^%w])", "%%%1")      -- escape for Lua patterns

  local skipped_loader = false
  for line in trace:gmatch("[^\n]+") do
    -- typical traceback line: "plugins/<...>/file.lua:123: in function ..."
    local path = line:match("([^\":]+):%d+")
    if path then
      path = path:match("^%s*(.-)%s*$")   -- trim
      if path:find("^plugins/") then
        path = normalize_path(path)       -- <<< NEW: resolve "../" segments

        -- first frame belonging to Neoloader itself gets skipped once
        if (not skipped_loader) and path:find("^" .. loader_root) then
          skipped_loader = true
        else
          local folder = extract_folder(path)
          if folder then
            return folder
          end
        end
      end
    end
  end

  return false, "unable to determine caller's directory!?"
end
