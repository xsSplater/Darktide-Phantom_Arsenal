-- Phantom_Arsenal
local mod = get_mod("Phantom_Arsenal")

-- Weapon units by slot
local weapon_units = {
	slot_primary			= nil,
	slot_secondary			= nil,
}
local grenade_weapon_unit	= nil
local special_weapon_unit	= nil

-- Current transparency values (0 = transparent, 1 = visible)
local current_alphas = {
	slot_primary			= 1,
	slot_secondary			= 1,
}
local current_alpha_grenade = 1
local current_alpha_special = 1

local fade_speed = mod:get("fade_speed")

-- Action states
local is_blocking			= false
local is_aiming				= false
local is_charging			= false
local is_non_braced_action	= false
local is_inspecting			= false

-- Weapon category flags for the current weapons
local primary_weapon_flags = {
	is_shield				= false,
	is_staff				= false,
	is_braced				= false
}
local secondary_weapon_flags = {
	is_shield				= false,
	is_staff				= false,
	is_braced				= false
}

-- ===========================================================================
-- Category cache: map of weapon_template_name -> flags
-- ===========================================================================
local weapon_category_cache = {}

-- Load centralized weapon lists
local WeaponCategories = mod:io_dofile("Phantom_Arsenal/Weapon_Categories")

-- Build cache from the centralized lists
local function build_category_cache()
	table.clear(weapon_category_cache)

-- Shields
	for _, name in ipairs(WeaponCategories.Melee.shields) do
		weapon_category_cache[name] = { is_shield = true, is_staff = false, is_braced = false }
	end
-- Staves
	for _, name in ipairs(WeaponCategories.Ranged.staves) do
		weapon_category_cache[name] = { is_shield = false, is_staff = true, is_braced = false }
	end
-- Non-braced ranged
	for _, name in ipairs(WeaponCategories.Ranged.non_braced) do
		weapon_category_cache[name] = { is_shield = false, is_staff = false, is_braced = false }
	end
-- Braced ranged
	for _, name in ipairs(WeaponCategories.Ranged.braced) do
		weapon_category_cache[name] = { is_shield = false, is_staff = false, is_braced = true }
	end
-- All other templates (e.g., non-shield melee) will get default flags from get_weapon_flags
end

build_category_cache()

local function get_weapon_flags(template_name)
	if not template_name then
		return { is_shield = false, is_staff = false, is_braced = false }
	end
	local cached = weapon_category_cache[template_name]
	if cached then
		return cached
	end
-- Default for unknown templates (e.g., non-shield melee, gadgets, etc.)
	return { is_shield = false, is_staff = false, is_braced = true }
end

-- ===========================================================================
-- Utility functions
-- ===========================================================================
local function is_valid(unit)
	return unit and Unit.is_valid(unit)
end

local function set_unit_transparency(unit, alpha)
	if not is_valid(unit) then return end
	Unit.set_shader_pass_flag_for_meshes(unit, "one_bit_alpha", true, true)
	Unit.set_scalar_for_materials(unit, "inv_jitter_alpha", 1 - alpha, true)
	Unit.set_scalar_for_materials(unit, "alpha_multiplier", alpha, true)
end

-- Target visibility for slot (0..1)
local function target_alpha_for_slot(slot_name)
	local mode_setting = slot_name == "slot_primary" and "mode_slot_primary" or "mode_slot_secondary"
	local opacity_setting = slot_name == "slot_primary" and "opacity_slot_primary" or "opacity_slot_secondary"

	local mode = mod:get(mode_setting) or "never"
	local visibility_percent = mod:get(opacity_setting) or 100
	local target_opacity = visibility_percent / 100

	local flags = slot_name == "slot_primary" and primary_weapon_flags or secondary_weapon_flags

-- Never
	if mode == "never" then
		return 1
-- Always
	elseif mode == "always" then
		return target_opacity
-- On Block (all melee)
	elseif mode == "block_all" then
		return is_blocking and target_opacity or 1
-- On Block (shields only)
	elseif mode == "block_shields" then
		return (is_blocking and flags.is_shield) and target_opacity or 1
-- On Block (except shields)
	elseif mode == "block_no_shields" then
		return (is_blocking and not flags.is_shield) and target_opacity or 1
-- On Aim (all ranged)
	elseif mode == "aim_all" then
		return (is_aiming or is_charging or is_non_braced_action) and target_opacity or 1
-- On Aim (braced only)
	elseif mode == "aim_braced" then
		return ((is_aiming or is_charging) and flags.is_braced) and target_opacity or 1
-- On Aim (non-braced only)
	elseif mode == "aim_non_braced" then
	-- non-braced AND not a staff
		return (is_non_braced_action and not flags.is_braced and not flags.is_staff) and target_opacity or 1
-- On Aim (staves only)
	elseif mode == "aim_staves" then
		-- Staves use is_charging
		return (is_charging and flags.is_staff) and target_opacity or 1
-- On Aim (except staves)
	elseif mode == "aim_except_staves" then
		return ((is_aiming or is_charging or is_non_braced_action) and not flags.is_staff) and target_opacity or 1
	else
		return 1
	end
end

-- ===========================================================================
-- Hooks
-- ===========================================================================
mod:hook_safe("ActionBlock", "start", function()
	is_blocking = true
end)

mod:hook_safe("ActionBlock", "finish", function()
	is_blocking = false
end)

-- Weapon Swap Hook
mod:hook_safe("PlayerUnitWeaponExtension", "_wielded_weapon", function(self, inventory_component, weapons)
	local primary = weapons.slot_primary and weapons.slot_primary.weapon_unit
	local secondary = weapons.slot_secondary and weapons.slot_secondary.weapon_unit

	-- Update primary slot
	if weapon_units.slot_primary ~= primary then
		if is_valid(weapon_units.slot_primary) then
			set_unit_transparency(weapon_units.slot_primary, 1)
		end
		weapon_units.slot_primary = primary
		current_alphas.slot_primary = 1

		-- Get template name from weapon object
		local weapon_object = weapons.slot_primary
		local template_name = weapon_object and weapon_object.weapon_template and weapon_object.weapon_template.name
		primary_weapon_flags = get_weapon_flags(template_name)
	end

	-- Update secondary slot
	if weapon_units.slot_secondary ~= secondary then
		if is_valid(weapon_units.slot_secondary) then
			set_unit_transparency(weapon_units.slot_secondary, 1)
		end
		weapon_units.slot_secondary = secondary
		current_alphas.slot_secondary = 1

		local weapon_object = weapons.slot_secondary
		local template_name = weapon_object and weapon_object.weapon_template and weapon_object.weapon_template.name
		secondary_weapon_flags = get_weapon_flags(template_name)
	end
end)

-- ===========================================================================
-- Update
-- ===========================================================================
mod.update = function(dt)
	local local_player = Managers.player:local_player_safe(1)
	if local_player then
		local player_unit = local_player.player_unit
		if player_unit and ALIVE[player_unit] then
			local unit_data_ext = ScriptUnit.has_extension(player_unit, "unit_data_system")
			if unit_data_ext then
			-- Inspect state
				local weapon_lock_view = unit_data_ext:read_component("weapon_lock_view")
				is_inspecting = weapon_lock_view and weapon_lock_view.state ~= "in_active"

			-- Aiming
				local alternate_fire = unit_data_ext:read_component("alternate_fire")
				is_aiming = alternate_fire and alternate_fire.is_active or false

			-- Charging
				local charge_component = unit_data_ext:read_component("action_module_charge")
				is_charging = charge_component and charge_component.charge_level > 0

			-- Non-braced action
				local input_extension = ScriptUnit.has_extension(player_unit, "input_system")
				local secondary_held = input_extension and input_extension:get("action_two_hold")
				is_non_braced_action = secondary_held or false

			-- Wielded slot tracking
				local inventory_component = unit_data_ext:read_component("inventory")
				local wielded_slot = inventory_component and inventory_component.wielded_slot

			-- Grenade slot
				if wielded_slot == "slot_grenade_ability" then
					local weapon_ext = ScriptUnit.has_extension(player_unit, "weapon_system")
					if weapon_ext then
						local weapons = weapon_ext._weapons
						local grenade_weapon = weapons and weapons["slot_grenade_ability"]
						local new_unit = grenade_weapon and grenade_weapon.weapon_unit
						if grenade_weapon_unit ~= new_unit then
							if is_valid(grenade_weapon_unit) then
								set_unit_transparency(grenade_weapon_unit, 1)
							end
							grenade_weapon_unit = new_unit
							current_alpha_grenade = 1
						end
					end
				else
					if is_valid(grenade_weapon_unit) then
						set_unit_transparency(grenade_weapon_unit, 1)
						grenade_weapon_unit = nil
						current_alpha_grenade = 1
					end
				end

			-- Special items slots (pocketable, luggable, etc.), but NOT device or unarmed
				local special_slots = { slot_pocketable = true, slot_pocketable_small = true, slot_luggable = true }
				if wielded_slot and special_slots[wielded_slot] then
					local weapon_ext = ScriptUnit.has_extension(player_unit, "weapon_system")
					if weapon_ext then
						local weapons = weapon_ext._weapons
						local special_weapon = weapons and weapons[wielded_slot]
						local new_unit = special_weapon and special_weapon.weapon_unit
						if special_weapon_unit ~= new_unit then
							if is_valid(special_weapon_unit) then
								set_unit_transparency(special_weapon_unit, 1)
							end
							special_weapon_unit = new_unit
							current_alpha_special = 1
						end
					end
				else
					if is_valid(special_weapon_unit) then
						set_unit_transparency(special_weapon_unit, 1)
						special_weapon_unit = nil
						current_alpha_special = 1
					end
				end
			end
		end
	end

-- Apply transparency to primary and secondary
	for slot_name, unit in pairs(weapon_units) do
		if is_valid(unit) then
			local target = is_inspecting and 1 or target_alpha_for_slot(slot_name)
			local current = current_alphas[slot_name]
			if math.abs(current - target) > 0.001 then
				if current < target then
					current = math.min(target, current + fade_speed * dt)
				else
					current = math.max(target, current - fade_speed * dt)
				end
				current_alphas[slot_name] = current
				set_unit_transparency(unit, current)
			elseif current ~= target then
				current_alphas[slot_name] = target
				set_unit_transparency(unit, target)
			end
		end
	end

-- Grenade weapon transparency
	if is_valid(grenade_weapon_unit) then
		local mode = mod:get("mode_slot_grenade") or "never"
		local visibility_percent = mod:get("opacity_slot_grenade") or 100
		local target_opacity = visibility_percent / 100
		local target = is_inspecting and 1 or ((mode == "always") and target_opacity or 1)
		local current = current_alpha_grenade
		if math.abs(current - target) > 0.001 then
			if current < target then
				current = math.min(target, current + fade_speed * dt)
			else
				current = math.max(target, current - fade_speed * dt)
			end
			current_alpha_grenade = current
			set_unit_transparency(grenade_weapon_unit, current)
		elseif current ~= target then
			current_alpha_grenade = target
			set_unit_transparency(grenade_weapon_unit, target)
		end
	end

-- Special items transparency
	if is_valid(special_weapon_unit) then
		local mode = mod:get("mode_slot_special") or "never"
		local visibility_percent = mod:get("opacity_slot_special") or 100
		local target_opacity = visibility_percent / 100
		local target = is_inspecting and 1 or ((mode == "always") and target_opacity or 1)
		local current = current_alpha_special
		if math.abs(current - target) > 0.001 then
			if current < target then
				current = math.min(target, current + fade_speed * dt)
			else
				current = math.max(target, current - fade_speed * dt)
			end
			current_alpha_special = current
			set_unit_transparency(special_weapon_unit, current)
		elseif current ~= target then
			current_alpha_special = target
			set_unit_transparency(special_weapon_unit, target)
		end
	end
end

mod.on_setting_changed = function(setting_name)
	if setting_name == "fade_speed" then
		fade_speed = mod:get("fade_speed")
	end
end
