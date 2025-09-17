local config = require("NPCs Go Home.config")
local enum = require("NPCs Go Home.enum")


local i18n = mwse.loadTranslations("NPCs Go Home")
local log = mwse.Logger.new()

local credits = {
	{
		name = "Programming by Celediel aka lemmingbas",
		url = "https://next.nexusmods.com/profile/lemmingbas/mods",
	},
	{
		name = "Programming by C3pa",
		url = "https://next.nexusmods.com/profile/C3pa/mods",
	},
	{
		name = "Inspiration from Lightweight Lua Scheduling by Opiter09",
		url = "https://next.nexusmods.com/profile/opiter09/mods",
	},
	{
		name = "Inspiration from Go Home for OpenMW by Johnnyhostile",
		url = "https://modding-openmw.com/mods/go-home/",
	}

}


--- @param self mwseMCMInfo|mwseMCMHyperlink
local function center(self)
	self.elements.info.absolutePosAlignX = 0.5
end

--- Adds default text to sidebar. Has a list of all the authors that contributed to the mod.
--- @param container mwseMCMSideBarPage
local function createSidebar(container)
	container.sidebar:createInfo({
		text = i18n("mcm.sidebar"),
		postCreate = center,
	})
	local creditsCategory = container.sidebar:createCategory({ label = i18n("mcm.Credits") })

	for _, author in ipairs(credits) do
		creditsCategory:createHyperlink({
			text = author.name,
			url = author.url,
		})
	end
end

local function registerModConfig()
	local template = mwse.mcm.createTemplate({
		name = i18n("NPCs Go Home"),
		headerImagePath = "MWSE/mods/NPCs Go Home/mcm/Header.tga",
		config = config,
		defaultConfig = config.default,
		showDefaultSetting = true,
	})
	template:register()
	template:saveOnClose(config.fileName, config)

	local page = template:createSideBarPage({
		label = i18n("mcm.settings"),
		showReset = true,
	}) --[[@as mwseMCMSideBarPage]]
	createSidebar(page)

	page:createInfo({ label = i18n("mcm.description") })

	page:createYesNoButton({
		label = i18n("mcm.lockDoors.label"),
		configKey = "lockDoors"
	})
	page:createYesNoButton({
		label = i18n("mcm.disableNPCs.label"),
		configKey = "disableNPCs"
	})
	page:createYesNoButton({
		label = i18n("mcm.disableNPCsInWilderness.label"),
		description = i18n("mcm.disableNPCsInWilderness.description"),
		configKey = "disableNPCsInWilderness"
	})
	page:createYesNoButton({
		label = i18n("mcm.moveNPCs.label"),
		description = i18n("mcm.moveNPCs.description"),
		configKey = "moveNPCs"
	})
	page:createYesNoButton({
		label = i18n("mcm.homelessWanderersToPublicHouses.label"),
		description = i18n("mcm.homelessWanderersToPublicHouses.description"),
		configKey = "homelessWanderersToPublicHouses"
	})
	page:createYesNoButton({
		label = i18n("mcm.disableInteraction.label"),
		configKey = "disableInteraction"
	})
	page:createSlider({
		label = i18n("mcm.minimumTrespassDisposition.label"),
		description = i18n("mcm.minimumTrespassDisposition.description"),
		min = 0,
		max = 100,
		step = 5,
		jump = 10,
		configKey = "minimumTrespassDisposition"
	})
	page:createDropdown({
		label = i18n("mcm.cantonCellsPolicy.label"),
		description = i18n("mcm.cantonCellsPolicy.description"),
		options = {
			{ label = i18n("mcm.cantonCellsPolicy.Exterior"), value = enum.cantonPolicy.exterior },
			{ label = i18n("mcm.cantonCellsPolicy.Public"), value = enum.cantonPolicy.public },
			{ label = i18n("mcm.cantonCellsPolicy.Interior"), value = enum.cantonPolicy.interior }
		},
		configKey = "cantonCellsPolicy"
	})
	page:createYesNoButton({
		label = i18n("mcm.keepBadWeatherNPCs.label"),
		configKey = "keepBadWeatherNPCs"
	})
	local weatherOptions = {
		{ label = tes3.findGMST(tes3.gmst.sNone).value, value = tes3.weather.blizzard + 1 }
	}
	for id, weather in pairs(tes3.worldController.weatherController.weathers) do
		table.insert(weatherOptions, {
			label = weather.name,
			value = id
		})
	end
	page:createDropdown({
		label = i18n("mcm.worstWeather.label"),
		description = i18n("mcm.worstWeather.description"),
		options = weatherOptions,
		configKey = "worstWeather"
	})
	page:createSlider({
		label = i18n("mcm.closeTime.label"),
		description = i18n("mcm.closeTime.description"),
		min = 0,
		max = 24,
		step = 1,
		jump = 2,
		configKey = "closeTime"
	})
	page:createSlider({
		label = i18n("mcm.openTime.label"),
		description = i18n("mcm.openTime.description"),
		min = 0,
		max = 24,
		step = 1,
		jump = 2,
		configKey = "openTime"
	})
	page:createSlider({
		label = i18n("mcm.minimumOccupancy.label"),
		description = i18n("mcm.minimumOccupancy.description"),
		min = 1,
		max = 20,
		step = 1,
		jump = 4,
		configKey = "minimumOccupancy"
	})
	page:createSlider({
		label = i18n("mcm.factionIgnorePercentage.label"),
		description = i18n("mcm.factionIgnorePercentage.description"),
		min = 0,
		max = 100,
		step = 5,
		jump = 10,
		decimalPlaces = 2,
		configKey = "factionIgnorePercentage"
	})
	page:createYesNoButton({
		label = i18n("mcm.showMessages.label"),
		configKey = "showMessages"
	})
	page:createLogLevelOptions({
		configKey = "logLevel"
	})
end

event.register(tes3.event.modConfigReady, registerModConfig)
