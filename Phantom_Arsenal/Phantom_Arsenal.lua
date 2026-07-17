-- Phantom_Arsenal.lua
local mod = get_mod("Phantom_Arsenal")

local Action = require("scripts/utilities/action/action")
local WeaponTemplate = require("scripts/utilities/weapon/weapon_template")

-- ===========================================================================
-- Cache for mod settings (updated on change)
-- ===========================================================================
local cached_settings = {
	-- Primary
	mode_primary = mod:get("mode_slot_primary") or "never",
	opacity_primary = (mod:get("opacity_slot_primary") or 100) / 100,
	-- Secondary
	mode_secondary = mod:get("mode_slot_secondary") or "never",
	opacity_secondary = (mod:get("opacity_slot_secondary") or 100) / 100,
	-- Grenade
	mode_grenade = mod:get("mode_slot_grenade") or "never",
	opacity_grenade = (mod:get("opacity_slot_grenade") or 100) / 100,
	-- Special items
	mode_special = mod:get("mode_slot_special") or "never",
	opacity_special = (mod:get("opacity_slot_special") or 100) / 100,
	-- Arms
	hide_arms = mod:get("hide_arms") or false,
	-- Servo Skull
	mode_servo_skull = mod:get("mode_slot_servo_skull") or "never",
	opacity_servo_skull = (mod:get("opacity_slot_servo_skull") or 100) / 100,
}

local fade_speed = mod:get("fade_speed")

-- ===========================================================================
-- Weapon units by slot (primary and secondary)
-- ===========================================================================
local weapon_units = {
	slot_primary = nil,
	slot_secondary = nil,
}

-- Current transparency values for primary and secondary
local current_alphas = {
	slot_primary = 1,
	slot_secondary = 1,
}

-- Special weapon units (grenades, pocketables, luggables)
-- keyed by slot name, each stores { unit = Unit, alpha = number }
local special_units = {}

-- First person unit for arms hiding
local first_person_unit_cached = nil

-- Arms hiding state tracking
local last_wielded_slot_for_arms = nil

-- Servo Skull check timer (periodic update)
local servo_skull_check_timer = 0
local servo_skull_check_time = 0.2

-- ===========================================================================
-- Global action states (only for blocking, shared)
-- ===========================================================================
local is_blocking = false

-- ===========================================================================
-- Weapon category flags for the current weapons
-- ===========================================================================
local primary_weapon_flags = { is_shield = false, is_staff = false, is_braced = false }
local secondary_weapon_flags = { is_shield = false, is_staff = false, is_braced = false }

-- ===========================================================================
-- Category cache: map of weapon_template_name -> flags
-- ===========================================================================
local weapon_category_cache = {}

local WeaponCategories = mod:io_dofile("Phantom_Arsenal/Weapon_Categories")

local function build_category_cache()
	table.clear(weapon_category_cache)
	for _, name in ipairs(WeaponCategories.Melee.shields) do
		weapon_category_cache[name] = { is_shield = true, is_staff = false, is_braced = false }
	end
	for _, name in ipairs(WeaponCategories.Ranged.staves) do
		weapon_category_cache[name] = { is_shield = false, is_staff = true, is_braced = false }
	end
	for _, name in ipairs(WeaponCategories.Ranged.non_braced) do
		weapon_category_cache[name] = { is_shield = false, is_staff = false, is_braced = false }
	end
	for _, name in ipairs(WeaponCategories.Ranged.braced) do
		weapon_category_cache[name] = { is_shield = false, is_staff = false, is_braced = true }
	end
end

build_category_cache()

local function get_weapon_flags(template_name)
	if not template_name then
		return { is_shield = false, is_staff = false, is_braced = false }
	end
	local cached = weapon_category_cache[template_name]
	if cached then return cached end
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

-- Helper to get servo skull units for the given player unit
local function get_servo_skull_units(player_unit)
	if not player_unit or not ALIVE[player_unit] then return nil end
	local companion_ext = ScriptUnit.has_extension(player_unit, "companion_spawner_system")
	if not companion_ext then return nil end
	return companion_ext:companion_units()
end

-- ===========================================================================
-- Target visibility for a given slot (now accepts aiming/charging states)
-- ===========================================================================
local function target_alpha_for_slot(slot_name, is_aiming, is_charging, is_non_braced_action)
	local mode, opacity
	if slot_name == "slot_primary" then
		mode = cached_settings.mode_primary
		opacity = cached_settings.opacity_primary
	else
		mode = cached_settings.mode_secondary
		opacity = cached_settings.opacity_secondary
	end

	local flags = slot_name == "slot_primary" and primary_weapon_flags or secondary_weapon_flags
	local target_opacity = opacity

	if mode == "never" then
		return 1
	elseif mode == "always" then
		return target_opacity
	elseif mode == "block_all" then
		return is_blocking and target_opacity or 1
	elseif mode == "block_shields" then
		return (is_blocking and flags.is_shield) and target_opacity or 1
	elseif mode == "block_no_shields" then
		return (is_blocking and not flags.is_shield) and target_opacity or 1
	elseif mode == "aim_all" then
		if flags.is_braced then
			return (is_aiming or is_charging) and target_opacity or 1
		else
			return (is_aiming or is_charging or is_non_braced_action) and target_opacity or 1
		end
	elseif mode == "aim_braced" then
		return ((is_aiming or is_charging) and flags.is_braced) and target_opacity or 1
	elseif mode == "aim_non_braced" then
		return (is_non_braced_action and not flags.is_braced and not flags.is_staff) and target_opacity or 1
	elseif mode == "aim_staves" then
		return (is_charging and flags.is_staff) and target_opacity or 1
	elseif mode == "aim_except_staves" then
		if flags.is_staff then return 1 end
		if flags.is_braced then
			return (is_aiming or is_charging) and target_opacity or 1
		else
			return (is_aiming or is_charging or is_non_braced_action) and target_opacity or 1
		end
	else
		return 1
	end
end

-- ===========================================================================
-- Hooks for blocking
-- ===========================================================================
mod:hook_safe("ActionBlock", "start", function()
	is_blocking = true
end)

mod:hook_safe("ActionBlock", "finish", function()
	is_blocking = false
end)

mod:hook_safe("ActionPush", "start", function()
	is_blocking = true
end)
mod:hook_safe("ActionPush", "finish", function()
	is_blocking = false
end)

mod:hook_safe("ActionWeaponShout", "start", function()
	is_blocking = true
end)
mod:hook_safe("ActionWeaponShout", "finish", function()
	is_blocking = false
end)

-- ===========================================================================
-- Primary and secondary weapons (сброс при смене оружия)
-- ===========================================================================
mod:hook_safe("PlayerUnitWeaponExtension", "_wielded_weapon", function(self, inventory_component, weapons)
	local primary = weapons.slot_primary and weapons.slot_primary.weapon_unit
	local secondary = weapons.slot_secondary and weapons.slot_secondary.weapon_unit

	if weapon_units.slot_primary ~= primary then
		if is_valid(weapon_units.slot_primary) then
			set_unit_transparency(weapon_units.slot_primary, 1)
		end
		weapon_units.slot_primary = primary
		current_alphas.slot_primary = 1

		local weapon_object = weapons.slot_primary
		local template_name = weapon_object and weapon_object.weapon_template and weapon_object.weapon_template.name
		primary_weapon_flags = get_weapon_flags(template_name)
	end

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

-- Special slots (grenade, pocketable, luggable) tracking via official events
local special_slot_names = {
	slot_grenade_ability = true,
	slot_pocketable = true,
	slot_pocketable_small = true,
	slot_luggable = true,
}

mod:hook_safe("PlayerUnitWeaponExtension", "on_wieldable_slot_equipped", function(self, item, slot_name, weapon_unit, ...)
	if not special_slot_names[slot_name] then return end
	local entry = special_units[slot_name]
	if entry and is_valid(entry.unit) then
		set_unit_transparency(entry.unit, 1)
	end
	special_units[slot_name] = { unit = weapon_unit, alpha = 1 }
end)

mod:hook_safe("PlayerUnitWeaponExtension", "on_slot_unwielded", function(self, slot_name, t)
	if not special_slot_names[slot_name] then return end
	local entry = special_units[slot_name]
	if entry and is_valid(entry.unit) then
		set_unit_transparency(entry.unit, 1)
	end
	special_units[slot_name] = nil
end)

-- ===========================================================================
-- State reset hooks (fix permanent invisibility)
-- ===========================================================================
local function reset_all_transparency_states()
	is_blocking = false
	-- Reset all units to fully visible
	for _, unit in pairs(weapon_units) do
		if is_valid(unit) then set_unit_transparency(unit, 1) end
	end
	for _, entry in pairs(special_units) do
		if entry and is_valid(entry.unit) then set_unit_transparency(entry.unit, 1) end
	end
	table.clear(special_units)
	servo_skull_check_timer = 0
	current_alphas.slot_primary = 1
	current_alphas.slot_secondary = 1
end

mod:hook_safe("PlayerUnitWeaponExtension", "on_player_unit_spawn", function()
	reset_all_transparency_states()
end)

mod:hook_safe("PlayerUnitWeaponExtension", "on_player_unit_respawn", function()
	reset_all_transparency_states()
end)

-- ===========================================================================
-- Update
-- ===========================================================================
mod.update = function(dt)
	local local_player = Managers.player:local_player_safe(1)
	if not local_player then return end

	local player_unit = local_player.player_unit
	if not player_unit or not ALIVE[player_unit] then return end

	local unit_data_ext = ScriptUnit.has_extension(player_unit, "unit_data_system")
	if not unit_data_ext then return end

	-- Inspect state
	local weapon_lock_view = unit_data_ext:read_component("weapon_lock_view")
	local is_inspecting = weapon_lock_view and weapon_lock_view.state ~= "in_active"

	-- Get weapon action component for action_kind (shared for both slots)
	local weapon_action_component = unit_data_ext:read_component("weapon_action")
	local action_kind = nil
	if weapon_action_component then
		local weapon_template = WeaponTemplate.current_weapon_template(weapon_action_component)
		if weapon_template then
			local _, action_settings = Action.current_action(weapon_action_component, weapon_template)
			if action_settings then
				action_kind = action_settings.kind
			end
		end
	end

	-- Get alternate_fire component (for braced weapons)
	local alternate_fire = unit_data_ext:read_component("alternate_fire")
	local alt_fire_active = alternate_fire and alternate_fire.is_active or false

	-- Get input for non-braced action (shared)
	local input_extension = ScriptUnit.has_extension(player_unit, "input_system")
	local is_non_braced_action = (input_extension and input_extension:get("action_two_hold")) or false

	-- Determine action-based states (for non-braced and staff)
	local action_is_aim = false
	local action_is_charge = false
	if action_kind then
		action_is_aim = (action_kind == "aim" or action_kind == "aim_projectile" or
		                 action_kind == "aim_force_field" or action_kind == "block_aiming")
		action_is_charge = (action_kind == "charge" or action_kind == "charge_ammo")
	end

	-- Helper to apply fading transparency to a unit with a cached alpha value
	local function apply_fade(unit, target_alpha, current_alpha_var_name, slot_key)
		local current = current_alpha_var_name
		if is_inspecting then target_alpha = 1 end
		if math.abs(current - target_alpha) > 0.001 then
			if current < target_alpha then
				current = math.min(target_alpha, current + fade_speed * dt)
			else
				current = math.max(target_alpha, current - fade_speed * dt)
			end
			if slot_key then
				special_units[slot_key].alpha = current
			else
				current_alpha_var_name = current
			end
			set_unit_transparency(unit, current)
		elseif current ~= target_alpha then
			current = target_alpha
			if slot_key then
				special_units[slot_key].alpha = current
			else
				current_alpha_var_name = current
			end
			set_unit_transparency(unit, target_alpha)
		end
	end

	-- Process primary and secondary slots
	for slot_name, unit in pairs(weapon_units) do
		if is_valid(unit) then
			local flags = (slot_name == "slot_primary") and primary_weapon_flags or secondary_weapon_flags
			local is_braced = flags.is_braced

			-- Determine aiming state for this slot
			local is_aiming
			if is_braced then
				-- For braced weapons, use alternate_fire.is_active (supports toggle)
				is_aiming = alt_fire_active
			else
				-- For non-braced, use action_kind
				is_aiming = action_is_aim
			end

			-- Charging state (same for all, based on action_kind)
			local is_charging = action_is_charge

			local target = target_alpha_for_slot(slot_name, is_aiming, is_charging, is_non_braced_action)
			local current = current_alphas[slot_name]
			if is_inspecting then target = 1 end
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

	-- Hide Arms: sync transparency with currently wielded weapon
	if cached_settings.hide_arms then
		local inventory_component = unit_data_ext:read_component("inventory")
		local wielded_slot = inventory_component and inventory_component.wielded_slot

		if wielded_slot ~= last_wielded_slot_for_arms then
			first_person_unit_cached = nil
			last_wielded_slot_for_arms = wielded_slot
		end

		if not is_valid(first_person_unit_cached) then
			local fp_ext = ScriptUnit.has_extension(player_unit, "first_person_system")
			first_person_unit_cached = fp_ext and fp_ext:first_person_unit()
		end

		if is_valid(first_person_unit_cached) then
			local arms_alpha = 1
			local apply_arms = false

			if wielded_slot == "slot_primary" or wielded_slot == "slot_secondary" then
				arms_alpha = current_alphas[wielded_slot]
				apply_arms = true
			elseif special_slot_names[wielded_slot] then
				local entry = special_units[wielded_slot]
				if entry and is_valid(entry.unit) then
					arms_alpha = entry.alpha
					apply_arms = true
				end
			end

			if apply_arms then
				set_unit_transparency(first_person_unit_cached, arms_alpha)
			end
		end
	end

	-- Servo Skull transparency: apply periodically when mode is "always"
	if cached_settings.mode_servo_skull == "always" then
		servo_skull_check_timer = servo_skull_check_timer + dt
		if servo_skull_check_timer >= servo_skull_check_time then
			servo_skull_check_timer = 0
			local units = get_servo_skull_units(player_unit)
			if units then
				local target_alpha = cached_settings.opacity_servo_skull
				for _, unit in pairs(units) do
					if is_valid(unit) then
						set_unit_transparency(unit, target_alpha)
					end
				end
			end
		end
	end

	-- Process each special slot that has a stored unit
	for slot_name, entry in pairs(special_units) do
		if is_valid(entry.unit) then
			local mode, opacity
			if slot_name == "slot_grenade_ability" then
				mode = cached_settings.mode_grenade
				opacity = cached_settings.opacity_grenade
			else
				mode = cached_settings.mode_special
				opacity = cached_settings.opacity_special
			end
			local target = (mode == "always") and opacity or 1
			if is_inspecting then target = 1 end

			if target == 1 and entry.alpha == 1 then
				-- already fully visible
			else
				local current = entry.alpha
				if math.abs(current - target) > 0.001 then
					if current < target then
						current = math.min(target, current + fade_speed * dt)
					else
						current = math.max(target, current - fade_speed * dt)
					end
					entry.alpha = current
					set_unit_transparency(entry.unit, current)
				elseif current ~= target then
					entry.alpha = target
					set_unit_transparency(entry.unit, target)
				end
			end
		else
			special_units[slot_name] = nil
		end
	end
end

-- ===========================================================================
-- Reset transparency states when entering hub or title screen
-- ===========================================================================
mod.on_game_state_changed = function(status, state_name)
	if status == "enter" and (state_name == "StateHub" or state_name == "StateTitle" or state_name == "StateMainMenu") then
		reset_all_transparency_states()
		if is_valid(first_person_unit_cached) then
			set_unit_transparency(first_person_unit_cached, 1)
			first_person_unit_cached = nil
		end
	end
end

-- ===========================================================================
-- Settings change handler
-- ===========================================================================
mod.on_setting_changed = function(setting_name)
	if setting_name == "fade_speed" then
		fade_speed = mod:get("fade_speed")
	elseif setting_name == "mode_slot_primary" then
		cached_settings.mode_primary = mod:get("mode_slot_primary")
	elseif setting_name == "opacity_slot_primary" then
		cached_settings.opacity_primary = (mod:get("opacity_slot_primary") or 100) / 100
	elseif setting_name == "mode_slot_secondary" then
		cached_settings.mode_secondary = mod:get("mode_slot_secondary")
	elseif setting_name == "opacity_slot_secondary" then
		cached_settings.opacity_secondary = (mod:get("opacity_slot_secondary") or 100) / 100
	elseif setting_name == "mode_slot_grenade" then
		cached_settings.mode_grenade = mod:get("mode_slot_grenade")
	elseif setting_name == "opacity_slot_grenade" then
		cached_settings.opacity_grenade = (mod:get("opacity_slot_grenade") or 100) / 100
	elseif setting_name == "mode_slot_special" then
		cached_settings.mode_special = mod:get("mode_slot_special")
	elseif setting_name == "opacity_slot_special" then
		cached_settings.opacity_special = (mod:get("opacity_slot_special") or 100) / 100
	elseif setting_name == "mode_slot_servo_skull" or setting_name == "opacity_slot_servo_skull" then
		cached_settings.mode_servo_skull = mod:get("mode_slot_servo_skull")
		cached_settings.opacity_servo_skull = (mod:get("opacity_slot_servo_skull") or 100) / 100
		local local_player = Managers.player:local_player_safe(1)
		if local_player then
			local player_unit = local_player.player_unit
			if player_unit and ALIVE[player_unit] then
				local units = get_servo_skull_units(player_unit)
				if units then
					local target_alpha = cached_settings.mode_servo_skull == "always" and cached_settings.opacity_servo_skull or 1
					for _, unit in pairs(units) do
						if is_valid(unit) then
							set_unit_transparency(unit, target_alpha)
						end
					end
				end
			end
		end
	elseif setting_name == "hide_arms" then
		cached_settings.hide_arms = mod:get("hide_arms")
		if not cached_settings.hide_arms and is_valid(first_person_unit_cached) then
			set_unit_transparency(first_person_unit_cached, 1)
			first_person_unit_cached = nil
		end
	end
end

-- ===========================================================================
-- Enabled / Disabled handlers
-- ===========================================================================
mod.on_enabled = function()
	if cached_settings.mode_servo_skull == "always" then
		local local_player = Managers.player:local_player_safe(1)
		if local_player then
			local player_unit = local_player.player_unit
			if player_unit and ALIVE[player_unit] then
				local units = get_servo_skull_units(player_unit)
				if units then
					local target_alpha = cached_settings.opacity_servo_skull
					for _, unit in pairs(units) do
						if is_valid(unit) then
							set_unit_transparency(unit, target_alpha)
						end
					end
				end
			end
		end
	end
end

mod.on_disabled = function()
	if is_valid(first_person_unit_cached) then
		set_unit_transparency(first_person_unit_cached, 1)
		first_person_unit_cached = nil
	end
	for slot_name, entry in pairs(special_units) do
		if entry and is_valid(entry.unit) then
			set_unit_transparency(entry.unit, 1)
		end
	end
	table.clear(special_units)
	for slot_name, unit in pairs(weapon_units) do
		if is_valid(unit) then
			set_unit_transparency(unit, 1)
		end
	end
	local local_player = Managers.player:local_player_safe(1)
	if local_player then
		local player_unit = local_player.player_unit
		if player_unit and ALIVE[player_unit] then
			local units = get_servo_skull_units(player_unit)
			if units then
				for _, unit in pairs(units) do
					if is_valid(unit) then
						set_unit_transparency(unit, 1)
					end
				end
			end
		end
	end
end

mod:on_enabled()
