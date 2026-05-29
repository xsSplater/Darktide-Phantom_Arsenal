return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`Phantom_Arsenal` encountered an error loading the Darktide Mod Framework.")

		new_mod("Phantom_Arsenal", {
			mod_script       = "Phantom_Arsenal/Phantom_Arsenal",
			mod_data         = "Phantom_Arsenal/Phantom_Arsenal_data",
			mod_localization = "Phantom_Arsenal/Phantom_Arsenal_localization",
		})
	end,
	packages = {},
}
