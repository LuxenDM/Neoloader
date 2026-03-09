--[[
[metadata]
description=Request manager authorization key (UAC-style; stub)
version=1.0.0
owner=Neoloader|7.0.0
type=lua
created=2026-03-08
]]--

local neo = ...
local lib = neo.lib

local lget = neo.api.lget

-- cb(key) on approval; not called on denial
lib.request_auth = function(name, callback)
	if lib.err_handle( type(callback) ~= "function", "lib.request_auth requires a callback function to recieve the auth key!") then
		return false
	end
	
	name = tostring(name or "<untitled>")
	
	local grant = iup.stationbutton {
		title = lget("core", "AUTH", "GRANT_AUTH", "Give Access"),
		action = function(self)
			callback(neo.auth_key)
			HideDialog(iup.GetDialog(self))
		end,
	}
	
	local deny = iup.stationbutton {
		title = lget("core", "AUTH", "DENY_AUTH", "Deny Access"),
		action = function(self)
			HideDialog(iup.GetDialog(self))
		end,
	}
	
	local auth_diag = iup.dialog {
		topmost = "YES",
		fullscreen = "YES",
		bgcolor = "0 0 0 200 *",
		default_esc = deny,
		iup.vbox {
			iup.fill { },
			iup.hbox {
				iup.fill { },
				iup.stationsubframe {
					iup.vbox {
						alignment = "ACENTER",
						iup.fill {
							size = "%2",
						},
						iup.label {
							title = name .. " " .. lget("core", "AUTH", "REQUEST_AUTH", "is requesting management permission over Neoloader!"),
						},
						iup.fill {
							size = "%2",
						},
						iup.hbox {
							grant,
							iup.fill {
								size = "%4",
							},
							deny,
						},
						iup.fill {
							size = "%2",
						},
					},
				},
				iup.fill { },
			},
			iup.fill { },
		},
	}
	
	auth_diag:map()
	ShowDialog(auth_diag)
end
