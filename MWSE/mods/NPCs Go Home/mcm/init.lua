local config = require("NPCs Go Home.config")
local log = mwse.Logger.new()

local i18n = mwse.loadTranslations("NPCs Go Home")

local authors = {
	{
		name = "C3pa",
		url = "https://next.nexusmods.com/profile/C3pa/mods",
	},
	-- TODO: format these differently:
	{
		name = "Celediel aka lemmingbas",
		url = "https://next.nexusmods.com/profile/lemmingbas/mods",
	},
	{
		name = "Opiter09",
		url = "https://next.nexusmods.com/profile/opiter09/mods",
	},
	{
		name = "Johnnyhostile",
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
	for _, author in ipairs(authors) do
		container.sidebar:createHyperlink({
			text = author.name,
			url = author.url,
			postCreate = center,
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

	page:createSlider({
		label = i18n("mcm.asetting.label"),
		description = i18n("mcm.asetting.description"),
		min = 200,
		max = 500,
		step = 50,
		jump = 100,
		configKey = "asetting",
	})

	page:createKeyBinder({
		label = i18n("mcm.someKey.label"),
		description = i18n("mcm.someKey.description"),
		allowCombinations = true,
		allowMouse = true,
		configKey = "someKey",
		callback = function()
			mwse.log("Callback!")
			tes3.messageBox("Callback!")
		end
	})

	page:createLogLevelOptions({
		configKey = "logLevel"
	})
end

event.register(tes3.event.modConfigReady, registerModConfig)
