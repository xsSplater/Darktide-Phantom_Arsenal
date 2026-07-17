-- Weapon_Categories.lua
-- Centralized weapon template names for Phantom Arsenal mod.
-- Add new weapons to the appropriate lists to update the mod's behavior.

local WeaponCategories = {
	Ranged = {
	-- Weapons with a proper aim-down-sights (ADS) / brace mode
		braced = {
		-- Autoguns
			"autogun_p1_m1",			-- Infantry Autogun Agripinaa Mk I
			"autogun_p1_m2",			-- Infantry Autogun Vraks Mk V
			"autogun_p1_m3",			-- Infantry Autogun Columnus Mk VIII

			"autogun_p3_m1",			-- Vigilant Autogun Columnus MK III
			"autogun_p3_m2",			-- Vigilant Autogun Graia MK VII
			"autogun_p3_m3",			-- Vigilant Autogun Agripinaa MK IX

		-- Bolt Pistols
			"boltpistol_p1_m1",			-- Bolt Pistol Godwyn-Branx Mk IV
			"boltpistol_p1_m2",			-- Bolt Pistol Godwyn-Branx Mk VI

		-- Bolters
			"bolter_p1_m1",				-- Spearhead Boltgun Locke Mk IIb
			"bolter_p1_m2",				-- Spearhead Boltgun Locke Mk III

		-- Lasguns
			"lasgun_p1_m1",				-- Infantry Lasgun Kantrael Mk VII
			"lasgun_p1_m2",				-- Infantry Lasgun Kantrael Mk IIb
			"lasgun_p1_m3",				-- Infantry Lasgun Kantrael Mk IX

			"lasgun_p2_m3",				-- Helbore Lasgun Lucius Mk IV
			"lasgun_p2_m2",				-- Helbore Lasgun Lucius Mk V
			"lasgun_p2_m1",				-- Helbore Lasgun Lucius Mk IIIa

			"lasgun_p3_m1",				-- Recon Lasgun Accatran Mk VIc
			"lasgun_p3_m2",				-- Recon Lasgun Accatran Mk XII
			"lasgun_p3_m3",				-- Recon Lasgun Accatran Mk XIV

		-- Heavy Laspistols
			"laspistol_p1_m1",			-- Heavy Laspistol Accatran Mk II
			"laspistol_p1_m3",			-- Heavy Laspistol Kantrael Mk X

		-- Shotguns
			"shotgun_p1_m1",			-- Combat Shotgun Zarona Mk VI
			"shotgun_p1_m2",			-- Combat Shotgun Agripinaa Mk VII
			"shotgun_p1_m3",			-- Combat Shotgun Accatran Mk IX

		-- Stub Revolver
			"stubrevolver_p1_m1",		-- Quickdraw Stub Revolver Zarona Mk IIa

	-- HIVE SCUM
		-- Needle Pistols
			"needlepistol_p1_m1",		-- Needle Pistol Branx Mk VI
			"needlepistol_p1_m2",		-- Needle Pistol Branx Mk II
		--  "needlepistol_p1_m3",		-- ???

	-- SKITARII
		-- Galvanic Rifle
			"galvanic_rifle_p1_m1",		-- Galvanic Rifle Branx Mk CV

		-- Phosphor Blast Pistol
			"phosphor_pistol_p1_m1",	-- Phosphor Blast Pistol Branx Mk XI
		},

	-- Weapons without a traditional ADS/scope
		non_braced = {
		-- Autopistol
			"autopistol_p1_m1",			-- Shredder Autopistol Ius Mk IV

		-- Autoguns
			"autogun_p2_m1",			-- Braced Autogun Vraks Mk II
			"autogun_p2_m2",			-- Braced Autogun Graia Mk IV
			"autogun_p2_m3",			-- Braced Autogun Agripinaa Mk VIII

		-- Plasma Gun
			"plasmagun_p1_m1",			-- Plasma Gun Magnacore Mk II
			"plasmagun_p1_m2",			-- Plasma Gun Magnacore Mk III

		-- Shotguns
			"shotgun_p2_m1",			-- Double-Barreled Shotgun Crucis Mk XI

			"shotgun_p4_m1",			-- Exterminator Shotgun Exaction Mk III
			"shotgun_p4_m2",			-- Exterminator Shotgun Exaction Mk VIII

		-- Stub Revolver
			"stubrevolver_p1_m2",		-- Quickdraw Stub Revolver Agripinaa Mk XIV

	-- ZEALOT
		-- Flamer
			"flamer_p1_m1",				-- Purgation Flamer Artemia Mk III

	-- OGRYN
		-- Grenadier Gauntlet
			"ogryn_gauntlet_p1_m1",		-- Grenadier Gauntlet Blastoom Mk III

		-- Heavy Stubbers
			"ogryn_heavystubber_p1_m1",	-- Twin-Linked Heavy Stubber Krourk Mk V
			"ogryn_heavystubber_p1_m2",	-- Twin-Linked Heavy Stubber Gorgonum Mk IV
			"ogryn_heavystubber_p1_m3",	-- Twin-Linked Heavy Stubber Achlys Mk VII

			"ogryn_heavystubber_p2_m1",	-- Heavy Stubber Krourk Mk IIa
			"ogryn_heavystubber_p2_m2",	-- Heavy Stubber Gorgonum Mk IIIa
			"ogryn_heavystubber_p2_m3",	-- Heavy Stubber Achlys Mk II

		-- Ripper Guns
			"ogryn_rippergun_p1_m1",	-- Ripper Gun Foe-Rend Mk II
			"ogryn_rippergun_p1_m2",	-- Ripper Gun Foe-Rend Mk V
			"ogryn_rippergun_p1_m3",	-- Ripper Gun Foe-Rend Mk VI

		-- Thumpers
			"ogryn_thumper_p1_m1",		-- Kickback Lorenz Mk V
			"ogryn_thumper_p1_m2",		-- Rumbler Lorenz Mk VI

	-- HIVE SCUM
		-- Dual Autopistols
			"dual_autopistols_p1_m1",	-- Dual Autopistols Branx Mk III

		-- Dual Stub Pistols
			"dual_stubpistols_p1_m1",	-- Dual Stub Pistols Branx Mk VIII

	-- SKITARII
		-- Arc Rifle
			"arc_rifle_p1_m1",			-- Arc Rifle Branx Mk IV
		},

		staves = {
	-- PSYKER
			"forcestaff_p1_m1",			-- Trauma/Voidblast Force Staff Equinox Mk III
			"forcestaff_p2_m1",			-- Inferno Force Staff Rifthaven Mk II
			"forcestaff_p3_m1",			-- Electrokinetic Force Staff Nomanus Mk VI
			"forcestaff_p4_m1",			-- Voidstrike Force Staff Equinox Mk IV
		},
	},

	Melee = {
		shields = {
	-- ARBITES
			"powermaul_shield_p1_m1",	-- Shock Maul and Suppression Shield Branx Mk VI
			"powermaul_shield_p1_m2",	-- Shock Maul and Suppression Shield Branx Mk XI

			"shotpistol_shield_p1_m1",	-- Subductor Shotpistol and Riot Shield Judgement Mk IV

	-- OGRYN
			"ogryn_powermaul_slabshield_p1_m1", -- Battle Maul and Slab Shield Orox Mk II and Mk III
		},
	},
}

return WeaponCategories
