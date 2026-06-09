-- Phantom_Arsenal.lua
local mod = get_mod("Phantom_Arsenal")

-- ===========================================================================
-- Cache for mod settings (updated on change)
-- ===========================================================================
local cached_settings = {
	-- primary
	mode_primary = mod:get("mode_slot_primary") or "never",
	opacity_primary = (mod:get("opacity_slot_primary") or 100) / 100,
	-- secondary
	mode_secondary = mod:get("mode_slot_secondary") or "never",
	opacity_secondary = (mod:get("opacity_slot_secondary") or 100) / 100,
	-- grenade
	mode_grenade = mod:get("mode_slot_grenade") or "never",
	opacity_grenade = (mod:get("opacity_slot_grenade") or 100) / 100,
	-- special items
	mode_special = mod:get("mode_slot_special") or "never",
	opacity_special = (mod:get("opacity_slot_special") or 100) / 100,
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

-- ===========================================================================
-- Action states
-- ===========================================================================
local is_blocking = false
local is_aiming = false
local is_charging = false
local is_non_braced_action = false

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

-- Target visibility for primary or secondary slot (uses cached settings and flags)
local function target_alpha_for_slot(slot_name)
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
		return (is_aiming or is_charging or is_non_braced_action) and target_opacity or 1
	elseif mode == "aim_braced" then
		return ((is_aiming or is_charging) and flags.is_braced) and target_opacity or 1
	elseif mode == "aim_non_braced" then
		return (is_non_braced_action and not flags.is_braced and not flags.is_staff) and target_opacity or 1
	elseif mode == "aim_staves" then
		return (is_charging and flags.is_staff) and target_opacity or 1
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

-- Primary and secondary weapons
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
	-- Reset previous unit if any
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

	-- Aiming / charging / non-braced
	local alternate_fire = unit_data_ext:read_component("alternate_fire")
	is_aiming = alternate_fire and alternate_fire.is_active or false

	local charge_component = unit_data_ext:read_component("action_module_charge")
	is_charging = charge_component and charge_component.charge_level > 0

	local input_extension = ScriptUnit.has_extension(player_unit, "input_system")
	is_non_braced_action = (input_extension and input_extension:get("action_two_hold")) or false

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

	-- Primary and secondary
	for slot_name, unit in pairs(weapon_units) do
		if is_valid(unit) then
			local target = target_alpha_for_slot(slot_name)
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

	-- Special slots (grenade, pocketable, luggable)
	local inventory_component = unit_data_ext:read_component("inventory")
	local wielded_slot = inventory_component and inventory_component.wielded_slot

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
			-- (удалили проверку на wielded_slot)
			local current = entry.alpha
			if is_inspecting then target = 1 end
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
		else
			-- Cleanup invalid unit
			special_units[slot_name] = nil
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
	end
end
