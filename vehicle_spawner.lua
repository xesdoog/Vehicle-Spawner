---@diagnostic disable: undefined-global, lowercase-global

local vehicle_spawner  = gui.get_tab("Vehicle Spawner")
local vehicles         = require ("vehicleList")
local is_typing        = false
local ped              = nil
local searchQuery      = ""
local player_name      = ""
local selected_vehicle = 0
local spawned_vehicle  = 0
script.register_looped("disableInput", function()
	if is_typing then
		PAD.DISABLE_ALL_CONTROL_ACTIONS(0)
	end
end)
vehicle_spawner:add_imgui(function()
	ImGui.PushItemWidth(250)
	searchQuery, used = ImGui.InputTextWithHint("##searchVehicles", "Search", searchQuery, 32)
	ImGui.PopItemWidth()
	if ImGui.IsItemActive() then
	is_typing = true
	else
		is_typing = false
	end
    ImGui.PushItemWidth(270)
end)
local filtered_vehicles = {}
local function updateFilteredVehicles()
	filtered_vehicles = {}
	for _, item in ipairs(vehicles) do
		if string.find(string.lower(item.name), string.lower(searchQuery)) then
			table.insert(filtered_vehicles, item)
		end
	end
end
local function displayFilteredList()
	updateFilteredVehicles()
	local vehicle_names = {}
	for _, item in ipairs(filtered_vehicles) do
		table.insert(vehicle_names, item.name)
	end
	selected_vehicle, used = ImGui.ListBox("", selected_vehicle, vehicle_names, #filtered_vehicles)
end
vehicle_spawner:add_imgui(displayFilteredList)
vehicle_spawner:add_separator()
vehicle_spawner:add_imgui(function()
	spawnInside, used = ImGui.Checkbox("Spawn Inside", spawnInside, true)
	if ImGui.Button("    Spawn   ") then
		script.run_in_fiber(function (script)
			if NETWORK.NETWORK_IS_SESSION_ACTIVE() then
				ped = PLAYER.GET_PLAYER_PED(network.get_selected_player())
			else
				ped = self.get_ped()
			end
			if not NETWORK.NETWORK_IS_SESSION_ACTIVE() then
				local playerModel = ENTITY.GET_ENTITY_MODEL(ped)
				if playerModel == 2602752943 then
					player_name = "Franklin"
				elseif playerModel == 225514697 then
					player_name = "Michael"
				elseif playerModel == 2608926626 then
					player_name = "Trevor"
				else
					player_name = "Custom Character"
				end
			else
				local myPed = self.get_ped()
				if ped == myPed then
					player_name = "Your Online Character"
				else
					player_name = PLAYER.GET_PLAYER_NAME(ped)
				end
			end
			local plyrCoords   = ENTITY.GET_ENTITY_COORDS(ped, false)
			local plyrForwardX = ENTITY.GET_ENTITY_FORWARD_X(ped)
			local plyrForwardY = ENTITY.GET_ENTITY_FORWARD_Y(ped)
			local vehicle  		 = filtered_vehicles[selected_vehicle + 1]
			local counter  		 = 0
			while not STREAMING.HAS_MODEL_LOADED(vehicle.hash) do
				STREAMING.REQUEST_MODEL(vehicle.hash)
				script:yield()
				if counter > 100 then
					return
				else
					counter = counter + 1
				end
			end
			spawned_vehicle = VEHICLE.CREATE_VEHICLE(vehicle.hash, plyrCoords.x + (plyrForwardX * 5), plyrCoords.y + (plyrForwardY * 5), plyrCoords.z, ENTITY.GET_ENTITY_HEADING(ped), true, false, false)
			DECORATOR.DECOR_SET_INT(spawned_vehicle, "MPBitset", 0)
			VEHICLE.SET_VEHICLE_IS_STOLEN(spawned_vehicle, false)
			if spawnInside then
				local controlled = entities.take_control_of(ped, 350)
				if not controlled then
					gui.show_message("Spawn Inside", "Failed to set the player inside the vehicle!\nMaybe they have protections enabled?")
				else
					PED.SET_PED_INTO_VEHICLE(ped, spawned_vehicle, -1)
				end
			end
			ENTITY.SET_ENTITY_AS_NO_LONGER_NEEDED(spawned_vehicle)
			gui.show_message("Vehicle Spawner", "Spawned ' "..vehicle.name.." ' for "..player_name)
		end)
	end
	ImGui.SameLine() ImGui.Spacing() ImGui.SameLine() ImGui.Spacing() ImGui.SameLine() ImGui.SameLine() ImGui.Spacing() ImGui.SameLine() ImGui.Spacing() ImGui.SameLine() ImGui.SameLine() ImGui.Spacing() ImGui.SameLine()
	if ImGui.Button("   Delete  ") then
		script.run_in_fiber(function(del)
			if PED.IS_PED_SITTING_IN_ANY_VEHICLE(ped) then
				pedVeh = PED.GET_VEHICLE_PED_IS_USING(ped)
				local controlled = entities.take_control_of(pedVeh, 350)
				if controlled then
					ENTITY.SET_ENTITY_AS_MISSION_ENTITY(spawned_vehicle, true, true)
					del:sleep(200)
					VEHICLE.DELETE_VEHICLE(spawned_vehicle)
					gui.show_message("Vehicle Spawner",""..player_name.."'s vehicle has been yeeted.")
				else
					gui.show_error("Vehicle Spawner", "Failed to delete the vehicle! "..player_name.." probably has protections on.")
				end
			else
				gui.show_warning("Vehicle Spawner", ""..player_name.." must be inside a vehicle in order to delete it.")
			end
		end)
	end
end)