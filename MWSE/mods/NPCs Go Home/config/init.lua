local enum = require("NPCs Go Home.enum")

local fileName = "NPCs Go Home"


---@class NPCsGoHome.config
---@field version string A [semantic version](https://semver.org/).
---@field default NPCsGoHome.config Access to the default config can be useful in the MCM.
---@field fileName string
local default = {
	logLevel = mwse.logLevel.info,
	asetting = 300,
	---@type mwseKeyMouseCombo
	someKey = {
		keyCode = tes3.scanCode.p,
		isShiftDown = false,
		isAltDown = true,
		isControlDown = false,
	},

	disableInteraction = true,
	minimumTrespassDisposition = 50,
	cantonCellsPolicy = enum.cantonPolicy.exterior,
	factionIgnorePercentage = (2 / 3) * 100,
	minimumOccupancy = 4,
	closeTime = 21,
	openTime = 7,
	disableNPCs = true,
	disableNPCsInWilderness = false,
	moveNPCs = true,
	keepBadWeatherNPCs = true,
	worstWeather = tes3.weather.thunder,
    homelessWanderersToPublicHouses = false, -- move NPCs to public houses if they don't have a home
	ignoresBadWeatherRace = {
		["argonian"] = true,
	},
	ignoresBadWeatherClass = {
		["t_pya_seaelf"] = true,
		["pilgrim"] = true,
		["t_cyr_pilgrim"] = true,
		["t_sky_pilgrim"] = true
	},
	npcBlacklist = {},
	pluginBlacklist = {
		-- Ignore abot's creature mods by default
		["abotwhereareallbirdsgoing.esp"] = true,
		["abotwaterlife.esm"] = true,
	},
	classBlacklist = {
		["dreamers"] = true,
	},
	factionBlacklist = {},
	cellBlacklist = {},
	lockDoors = true,
	showMessages = true,
}

local config = mwse.loadConfig(fileName, default)
config.version = "0.1.0"
config.default = default
config.fileName = fileName

return config
