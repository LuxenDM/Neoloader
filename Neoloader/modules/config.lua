--[[
[metadata]
description=This is the configuration manager for Neoloader
]]--

--[[
these configuration options have been deprecated:

allow_delayed_load: Now always yes: preparing for VFS-based plugin support, which may be downloaded post-game load. NLMPE v7+ should explicitly make loading these seamless without reload.
list_presorted: New loading system automagically handles load order regardless of input order, no need to support or handle hardcoded load orders.
echo_logging: logging will always occur now. No need to induce confusion for logs not being added to the game console by user-facing switch.

These configuration options are supported:

override_disabled_plugin_state: YES to load Neoloader even if plugins are disabled by the game client. Default to NO.
allow_bad_api_version: YES to load plugins that don't match the LME API version of Neoloader. *might* cause bugs. This can also be a per-plugin switch, by using load state of "YES -API"
default_load_state: YES or NO, are plugins allowed to load when they are first registered. defaults to YES (previously no), make sure to import existing config on user choice
do_err_popup: 
]]--

