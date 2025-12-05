--[[
[metadata]
description=Send a unified notification to the current notifier front-end
version=1.0.0
owner=Neoloader|7.0.0
type=lua
created=2025-11-09
]]--

local neo = ...
local lib = neo.lib
local get_conf = neo.api.config.get_config

lib.notify = function(status, ...)
  -- capture payload now to avoid vararg lifetime issues in closures
  local payload = { ... }

  -- which notifier are we targeting?
  local notifier_id = get_conf("current_notif")
  if not notifier_id or notifier_id == "" then
    -- no notifier configured; silently ignore
    return
  end

  -- if ready, dispatch immediately
  if lib.is_ready(notifier_id, "0") then
    lib.execute(notifier_id, "0", "notif", status, table.unpack(payload))
    return
  end

  -- else, wait for the notifier to become available, then retry once
  lib.require({ { id = notifier_id, version = "0" } }, function()
    lib.execute(notifier_id, "0", "notif", status, table.unpack(payload))
  end)
end
