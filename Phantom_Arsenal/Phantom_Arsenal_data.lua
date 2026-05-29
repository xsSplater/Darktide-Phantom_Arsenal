-- Phantom_Arsenal_data
local mod = get_mod("Phantom_Arsenal")

return {
	name = mod:localize("mod_name"),
	description = mod:localize("mod_description"),
	is_togglable = true,
	options = {
		widgets = {
			{ -- Fade
				setting_id = "fade_speed",
				type = "numeric",
				default_value = 2.0,
				decimals_number = 1,
				range = {0.5, 5.0},
			},
			{ -- Primary Weapon
				setting_id = "mode_slot_primary",
				type = "dropdown",
				default_value = "never",
				options = {
					{ text = "setting_always",					value = "always" },
					{ text = "setting_on_block_all",			value = "block_all" },
					{ text = "setting_on_block_shields",		value = "block_shields" },
					{ text = "setting_on_block_no_shields",		value = "block_no_shields" },
					{ text = "setting_never",					value = "never" },
				},
			},
			{ -- Primary Weapon Visibility
				setting_id = "opacity_slot_primary",
				type = "numeric",
				default_value = 100,
				decimals_number = 0,
				range = {1, 100},
			},
			{ -- Secondary Weapon
				setting_id = "mode_slot_secondary",
				type = "dropdown",
				default_value = "never",
				options = {
					{ text = "setting_always",					value = "always" },
					{ text = "setting_on_aim_all",				value = "aim_all" },
					{ text = "setting_on_aim_braced",			value = "aim_braced" },
					{ text = "setting_on_aim_non_braced",		value = "aim_non_braced" },
					{ text = "setting_on_aim_staves",			value = "aim_staves" },
					{ text = "setting_on_aim_except_staves",	value = "aim_except_staves" },
					{ text = "setting_never",					value = "never" },
				},
			},
			{ -- Secondary Weapon Visibility
				setting_id = "opacity_slot_secondary",
				type = "numeric",
				default_value = 100,
				decimals_number = 0,
				range = {1, 100},
			},
			{ -- Grenade slot
				setting_id = "mode_slot_grenade",
				type = "dropdown",
				default_value = "never",
				options = {
					{ text = "setting_always",					value = "always" },
					{ text = "setting_never",					value = "never" },
				},
			},
			{ -- Grenades Visibility
				setting_id = "opacity_slot_grenade",
				type = "numeric",
				default_value = 100,
				decimals_number = 0,
				range = {1, 100},
			},
			-- Special items slot (pocketable, luggable, etc.)
			{
				setting_id = "mode_slot_special",
				type = "dropdown",
				default_value = "never",
				options = {
					{ text = "setting_always",					value = "always" },
					{ text = "setting_never",					value = "never" },
				},
			},
			{ -- Special items Visibility
				setting_id = "opacity_slot_special",
				type = "numeric",
				default_value = 100,
				decimals_number = 0,
				range = {1, 100},
			},
		},
	},
}
