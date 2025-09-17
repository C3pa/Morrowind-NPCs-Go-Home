return {
	-- NOTE:
	-- If your string has string.format formatting codes such as %s, %.2f, etc.
	-- You need to escape them with another `%` (%%s, %%.2f, %%). A special case is
	-- their percentage (%) sign inside a label string in a MCM slider: you need to
	-- escape it twice, so four percentages (%%%%).

	-- The mod's name
	["NPCs Go Home"] = "NPCs Go Home",

	-- Put all the mcm strings here.
	["mcm"] = {
		-- General strings.
		["settings"] = "Settings",

		-- The default sidebar text. Shown when NO button, slider, etc. is hovered over.
		["sidebar"] = "\nWelcome to NPCs Go Home!\n\nHover over a feature for more info.\n",
		["Credits"] = "Credits",
		["description"] = "Move NPCs to their homes, or public houses (or just disable them), lock doors, \z
							and prevent interaction after hours, selectively disable NPCs in inclement weather",

		-- Strings for inidividual settings:
		["lockDoors"] = {
			["label"] = "Lock doors and containers at night?",
		},
		["disableNPCs"] = {
			["label"] = "Disable non-Guard NPCs at night?",
		},
		["disableNPCsInWilderness"] = {
			["label"] = "Disable NPCs in wilderness?",
			["description"] = "Cells that are legal to rest in are considered 'wilderness' cells."
		},
		-- TODO: change the tone of "if you feel like it"
		["moveNPCs"] = {
			["label"] = "Move NPCs into their homes at night and in bad weather instead of disabling them?",
			["description"] = "NOTE: Without the proper positions in data/positions.lua this could result in bad placement!\n\n\z
								Make a PR on GitHub with some more positions if you feel like it."
		},
		["homelessWanderersToPublicHouses"] = {
			["label"] = "Move \"homeless\" NPCs to public spaces at night and in bad weather instead of disabling them?",
			["description"] = "NOTE: Without the proper positions in data/positions.lua this could result in bad placement, \z
								and if multiple NPCs are placed in the same spot, they might DIE!\n\n\z
								Make a PR on GitHub with some more positions if you feel like it."
		},
		["disableInteraction"] = {
			["label"] = "Prevent dialogue in interiors at night?",
		},
		["minimumTrespassDisposition"] = {
			["label"] = "NPC Disposition at which dialogue is prevented.",
			["description"] = "If the player's disposition with an NPC is less than this value, dialogue will be prevented \z
        						(if configured to do so). Set to 0 to effectively disable disposition checking, \z
								and disable dialogue for all NPCs when applicable."
		},
		["cantonCellsPolicy"] = {
			["label"] = "Treat canton plaza and waistworks cells as exteriors, public spaces, or neither",
			["description"] = "If canton cells are treated as exterior, inside NPCs will be disabled, and doors will \z
			be locked.\nIf they're treated as public spaces, inside NPCs won't be disabled, and homeless NPCs will \z
			be moved inside (if configured to do so).\n\nIf neither, canton cells will be treated as any other.",
			["Exterior"] = "Exterior",
			["Public"] = "Public",
			["Interior"] = "Interior",
		},
		["keepBadWeatherNPCs"] = {
			["label"] = "Keep Caravaners, their Silt Striders, and configured races/classes enabled in inclement weather?",
		},
		["worstWeather"] = {
			["label"] = "NPC Inclement Weather Cutoff Point",
			["description"] = "NPCs \"go home\" in this weather or worse",
		},
		["closeTime"] = {
			["label"] = "Close Time",
			["description"] = "Time when people go home and doors lock",
		},
		["openTime"] = {
			["label"] = "Open Time",
			["description"] = "Time when people wake up and doors unlock",
		},
		["minimumOccupancy"] = {
			["label"] = "Minimum number of occupants for public house",
			["description"] = "Cells with less than this number of occupants won't even be considered for \z
								\"public house\" status.\n\nBlades (if on the ignore list) are an exception \z
								to this rule, because Blades trainers don't mind if you come in.",
		},
		["factionIgnorePercentage"] = {
			["label"] = "Faction Ignore Percentage: %%s%%%%",
			["description"] = "Cells whose occupants are this percentage or more of one faction will be marked public if that faction is on the ignored list.",
		},
		["showMessages"] = {
			["label"] = "Show messages when entering public spaces/NPC homes?",
		}
	},
}
