if type(lib) == "table" and lib[0] == "LME" then
	console_print("Neoloader setup should not run while Neoloader is running")
	
	return
end




local button_scalar = function()
	local val = ""
	if gkinterface.IsTouchModeEnabled() then
		val = tostring(Font.Default * 2)
	end
	return val
end

local gkrs	= gkini.ReadString --less typing
local gkri	= gkini.ReadInt
local gkws	= gkini.WriteString
local gkwi	= gkini.WriteInt
local cp	= console_print

gkwi("Neoloader", "Init", 3)
gkws("Neoloader", "mgr", "neomgr")
gkws("Neoloader", "uninstalled", "NO")

local counter = 1
while true do
	if gkrs("Neo-registry", "reg" .. tostring(counter), "") ~= "" then
		counter = counter + 1
	else
		--No entry here
		break
	end
end
for i=counter, 1, -1 do
	gkini.gkws("Neo-registry", "reg" .. tostring(i), "")
end

local plugin_counter = 0
local register_plugin = function(id, version, ini, state)
	plugin_counter = plugin_counter + 1
	gkws("Neo-registry", "reg" .. tostring(plugin_counter), ini)
	gkws("Neo-pluginstate", id .. "." .. version, state)
	cp("[LME Setup] Added bundled plugin: " .. id .. " v" .. version)
	cp("	plugin located in registry at position " .. tostring(plugin_counter))
end

register_plugin("neomgr", "2.0.0", "plugins/Neoloader/neomgr.ini", "YES")



local function create_subdlg(ctrl)
	local dlg = iup.dialog{
		border="NO",
		menubox="NO",
		resize="NO",
		expand = "YES",
		shrink = "YES",
		bgcolor="0 0 0 0 *",
		ctrl,
	}
	
	return dlg
end

local ctl_create = function()
	
	local lockstate = false
	local contents = {}
	local actual_items = {}
	
	local ctl = iup.stationsublist {
		{},
		control = "YES",
		expand = "YES",
	}
	
	ctl.unlock = function(self)
		ctl[1] = nil
		lockstate = false
	end
	
	ctl.lock = function(self)
		ctl[1] = 1
		lockstate = true
	end
	
	ctl.add_item = function(self, obj)
		table.insert(contents, obj)
	end
	
	ctl.clear_items = function(self)
		contents = {}
	end
	
	ctl.update = function(self, sorttype)
		if lockstate then
			self:unlock()
		end
		
		for k, v in ipairs(actual_items) do
			v:detach()
			if iup.IsValid(iup.GetNextChild(v)) then
				iup.GetNextChild(v):detach()
			end
			--v:destroy()
		end
		actual_items = {}
		
		--prepare items
		local x_size = string.match(ctl.size, "%d+") or "480"
		for k, v in ipairs(contents) do
			local obj = create_subdlg(v)
			actual_items[k] = obj
			obj:map()
			
			local sizes = {}
			for value in string.gmatch(obj.size, "%d+") do
				value = tonumber(value)
				table.insert(sizes, value)
			end
			obj.size = tostring(tonumber(x_size) - Font.Default) .. "x" .. tostring(sizes[2])
		end
		
		for k, v in ipairs(actual_items) do
			iup.Append(self, v)
		end
		
		self:lock()
		
		iup.Refresh(self)
	end
	
	iup.Append(ctl, create_subdlg(iup.hbox {}))
	
	return ctl
end



local config = {
	defaultLoadState = "NO",
	first_run = "",
	
	if_option = "replace",
	--[[
		replace: if will be Neoloader
		adapt: if will be Neoloader, old if will be imported
			--not yet implemented
		keep: if will be kept; Neoloader will not run
	]]--
}

local setup_creator = function()
	local ctl_basic = ctl_create()
	ctl_basic.expand = "NO"
	ctl_basic.size = "%30x%30"
	
	--rDefaultLoadState
	ctl_basic:add_item(iup.stationsubframe {
		iup.vbox {
			iup.hbox {
				alignment = "AMIDDLE",
				iup.label {
					title = "Load plugins by default: ",
				},
				iup.fill { },
				iup.stationsublist {
					dropdown = "YES",
					size = "200x" .. button_scalar(),
					action = function(self, t, i, cv)
						if cv == 1 then
							config.defaultLoadState = t
						end
					end,
					"YES",
					"NO",
					value = 2,
				},
			},
			iup.label {
				title = "YES: New plugins will automatically be enabled",
			},
			iup.label {
				title = "NO: New plugins must be manually enabled",
			},
			iup.label {
				title = "Default is NO",
			},
		},
	})
	
	--first-run
	ctl_basic:add_item( iup.stationsubframe {
		iup.vbox {
			iup.hbox {
				alignment = "AMIDDLE",
				iup.label {
					title = "Open manager after install: ",
				},
				iup.fill { },
				iup.stationsublist {
					dropdown = "YES",
					size = "200x" .. button_scalar(),
					action = function(self, t, i, cv)
						if cv == 1 then
							t = t == "YES" and "neo" or ""
							config.first_run = t
						end
					end,
					"YES",
					"NO",
					value = 1,
				},
			},
			iup.label {
				title = "Completely Optional, enable to manage your LME after setup",
			},
		},
	})
	
	local ctl_adv = ctl_create()
	ctl_adv.expand = "NO"
	ctl_adv.size = "%30x%30"
	ctl_adv.visible = "NO"
	
	--IF replacement style
	ctl_adv:add_item( iup.stationsubframe {
		iup.vbox {
			iup.hbox {
				alignment = "AMIDDLE",
				iup.label {
					title = "IF replacement method: ",
				},
				iup.fill { },
				iup.stationsublist {
					dropdown = "YES",
					size = "200x" .. button_scalar(),
					action = function(self, t, i, cv)
						if cv == 1 then
							config.if_option = t
						end
					end,
					"replace",
					"adapt",
					"keep",
					value = 1,
				},
			},
			iup.label {
				title = "Default is 'replace'",
			},
			iup.label {
				title = "DO NOT CHANGE unless you know what you're doing!",
			},
		},
	})
	
	local setup_diag = iup.dialog {
		topmost = "YES",
		fullscreen = "YES",
		bgcolor = "0 0 0",
		iup.vbox {
			iup.fill { },
			iup.hbox {
				iup.fill { },
				iup.stationsubframe {
					iup.vbox {
						alignment = "ACENTER",
						iup.label {
							title = "Neoloader Setup",
						},
						iup.stationsubframe {
							iup.hbox {
								iup.vbox {
									alignment = "ALEFT",
									iup.stationbutton {
										--to keep alignment
										title = "secret",
										visible = "NO",
									},
									ctl_basic,
								},
								iup.vbox {
									alignment = "ARIGHT",
									iup.stationbutton {
										title = "Show advanced options",
										action = function()
											ctl_adv.visible = "YES"
											ctl_adv:update()
										end,
									},
									ctl_adv,
								},
							},
						},
						iup.fill {
							size = Font.Default,
						},
						iup.stationbutton {
							title = "Apply settings and reload Vendetta Online",
							action = function(self)
								gkws("Neoloader", "rDefaultLoadState", config.defaultLoadState)
								gkws("Neoloader", "run_command", config.run_command)
								
								if config.if_option == "replace" then
									cp("IF option was REPLACE; value will be Neoloader")
									gkws("Vendetta", "if", "plugins/Neoloader/init.lua")
								elseif config.if_option == "adapt" then
									cp("IF option was ADAPT; value is " .. "NOT IMPLEMENTED")
									error("ADAPTION NOT IMPLEMENTED YET")
								elseif config.if_option == "keep" then
									cp("IF option was KEPT; value is " .. gkrs("Vendetta", "if", "vo-if"))
								end
								
								gkwi("Neoloader", "Init", 3)
								
								ReloadInterface()
							end,
						},
						iup.fill { },
					},
				},
				iup.fill { },
			},
			iup.fill { },
		},
	}
	
	setup_diag:map()
	ctl_basic:update()
	ctl_adv:update()
	
	ShowDialog(setup_diag)
end

setup_creator()