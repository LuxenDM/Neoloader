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
		size = "x" .. tostring(Font.Default + 6),
		action = function(self)
			callback(neo.auth_key)
			HideDialog(iup.GetDialog(self))
		end,
	}
	
	local deny = iup.stationbutton {
		title = lget("core", "AUTH", "DENY_AUTH", "Deny Access"),
		size = "x" .. tostring(Font.Default + 6),
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
					size = "%40x%30",
					iup.hbox {
						iup.fill { },
						iup.vbox {
							alignment = "ACENTER",
							iup.fill { },
							iup.fill { },
							iup.label {
								title = "",
								image = neo.path .. "assets/auth_request.png",
								size = tostring(Font.Default * 4) .. "x" .. tostring(Font.Default * 4)
							},
							iup.fill { },
							iup.label {
								title = name .. " " .. lget("core", "AUTH", "REQUEST_AUTH", "is requesting management permission over Neoloader!"),
								wordwrap = "YES",
								size = "%35x",
								font = Font.Default + 4,
							},
							iup.fill { },
							iup.hbox {
								iup.label {
									title = "",
									image = neo.path .. "assets/auth_key.png",
									size = tostring(Font.Default + 6) .. "x" .. tostring(Font.Default + 6),
								},
								grant,
								iup.fill {
									size = "%4",
								},
								iup.label {
									title = "",
									image = neo.path .. "assets/auth_deny.png",
									size = tostring(Font.Default + 6) .. "x" .. tostring(Font.Default + 6),
								},
								deny,
							},
							iup.fill { },
							iup.fill { },
						},
						iup.fill { },
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
