local enum = require("NPCs Go Home.enum")

local fileName = "NPCs Go Home"


---@class NPCsGoHome.config
---@field version string A [semantic version](https://semver.org/).
---@field default NPCsGoHome.config Access to the default config can be useful in the MCM.
---@field fileName string
local default = {
	logLevel = mwse.logLevel.info,

	lockDoors = true,
	disableNPCs = true,
	disableNPCsInWilderness = false,
	moveNPCs = true,
	homelessWanderersToPublicHouses = false, -- move NPCs to public houses if they don't have a home
	disableInteraction = true,
	minimumTrespassDisposition = 50,
	cantonCellsPolicy = enum.cantonPolicy.exterior,
	keepBadWeatherNPCs = true,
	worstWeather = tes3.weather.thunder,
	closeTime = 21,
	openTime = 7,
	minimumOccupancy = 4,
	factionIgnorePercentage = math.round((2 / 3) * 100, 2),
	showMessages = true,


	-- TODO: no exclusions page to configure these yet.
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
}

local config = mwse.loadConfig(fileName, default)
config.version = "0.1.0"
config.default = default
config.fileName = fileName

return config
