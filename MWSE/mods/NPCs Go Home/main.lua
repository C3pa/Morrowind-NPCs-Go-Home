local config = require("NPCs Go Home.config")

local log = mwse.Logger.new({
	name = "NPCs Go Home",
	logLevel = config.logLevel,
})

local cellTypeUtil = require("NPCs Go Home.util.cellTypeUtil")
local enum = require("NPCs Go Home.enum")
local goHome = require("NPCs Go Home.components.goHome")
local lockDoors = require("NPCs Go Home.components.lockDoors")
local runtimeData = require("NPCs Go Home.components.runtimeData")
local util = require("NPCs Go Home.util")
dofile("NPCs Go Home.mcm")


local function message(...)
	if config.showMessages then
		tes3.messageBox(...)
	end
end

-- TODO: this is only a debugging function.
---@param cell tes3cell
local function checkEnteredNPCHome(cell)
	if log.level < mwse.logLevel.info then return end
	local home = runtimeData.homes.byCell[cell.id]
	if not home then return end
	log:info("Entering home of %s, %s", home.name, home.homeName)
end

-- TODO: more robust trespass checking... maybe take faction and rank into account?
-- maybe something like faction members you outrank don't mind you being in their house
-- also whether guildhalls are public or not, members can come and go as they please
-- TODO maybe an esp with keys for guildhalls that are added when player joins or reaches a certain rank?
-- TODO: maybe re-implement some or all features of Trespasser
---@param cell tes3cell
---@param previousCell tes3cell
local function updatePlayerTrespass(cell, previousCell)
	cell = cell or tes3.player.cell

	local inCity = previousCell and (previousCell.id:match(cell.id) or cell.id:match(previousCell.id))

	if util.isInteriorCell(cell) and not util.isIgnoredCell(cell) and not util.isPublicHouse(cell) and inCity then
		if util.isNight() then
			tes3.player.data.NPCsGoHome.intruding = true
		else
			tes3.player.data.NPCsGoHome.intruding = false
		end
	else
		tes3.player.data.NPCsGoHome.intruding = false
	end
	log:info("Updating player trespass status to %s", tes3.player.data.NPCsGoHome.intruding)
end

---@param cell tes3cell
---@param city string
local function checkEnteredPublicHouse(cell, city)
	local typeOfPub = cellTypeUtil.pickPublicHouseType(cell)

	-- TODO: this probably needs to index the .byType table instead.
	local publicHouse = runtimeData.publicHouses.byName[city] and
		runtimeData.publicHouses.byName[city][cell.id]

	if publicHouse then
		local pubTypeName = table.find(enum.publicHouse, typeOfPub) --[[@as string]]
		local msg = string.format("Entering public space %s, a%s %s in the town of %s.", publicHouse.name,
			util.vowel(pubTypeName), pubTypeName:gsub("s$", ""), publicHouse.city)

		-- TODO: check for more servicers, not just proprietor
		local handle = publicHouse.proprietor
		if handle and handle:valid() and util.isServicer(handle:getObject()) then
			local npc = handle:getObject().object
			msg = msg .. string.format(" Talk to %s, %s for services.", npc.name, npc.class)
		end

		log:info(msg)
		-- This one is more informative, and not entirely for debugging, and reminiscent of Daggerfall's messages.
		message(msg)
	end
end

---@param e activateEventData
local function onActivate(e)
	if e.activator ~= tes3.player or e.target.object.objectType ~= tes3.objectType.npc or not config.disableInteraction then
		return
	end

	local npcRef = e.target
	local npc = npcRef.object

	if not tes3.player.data.NPCsGoHome.intruding or util.isIgnoredNPC(npcRef) then
		return
	end

	if npc.disposition and npc.disposition > config.minimumTrespassDisposition then
		return
	end

	log:debug("Disabling dialogue with %s because trespass and disposition: %s", npc.name, npc.disposition)
	-- TODO: i18n
	tes3.messageBox(string.format("%s: Get out before I call the guards!", npc.name))
	-- Block activation
	return false
end
event.register(tes3.event.activate, onActivate)

local TIMER_INTERVAL = 7
local updateTimer

---@param cell tes3cell
local function applyChanges(cell)
	cell = cell or tes3.getPlayerCell()

	if util.isIgnoredCell(cell) then return end

	-- Interior cells, except Canton cells, don't do anything
	if util.isInteriorCell(cell) and
		not (config.cantonCellsPolicy == enum.cantonPolicy.exterior and util.isCantonWorksCell(cell)) then
		return
	end

	-- Don't do anything to public houses
	if util.isPublicHouse(cell) then return end

	-- Deal with NPCs and mounts/pets in cell
	goHome.processNPCs(cell)
	goHome.processPets(cell)
	goHome.processSiltStriders(cell)

	-- Check doors in the cell, locking those that aren't inns/clubs
	lockDoors.processDoors(cell)
end

local function updateCells()
	log:debug("Updating active cells!")
	for _, cell in pairs(tes3.getActiveCells()) do
		log:trace("Applying changes to cell %s", cell.id)

		for _, t in pairs(runtimeData.NPCs) do
			t[cell.id] = t[cell.id] or {}
		end

		applyChanges(cell)
	end
end

local function onLoaded()
	tes3.player.data.NPCsGoHome = tes3.player.data.NPCsGoHome or {}

	if not updateTimer or updateTimer.state ~= timer.active then
		updateTimer = timer.start({
			type = timer.simulate,
			duration = TIMER_INTERVAL,
			iterations = -1,
			callback = updateCells
		})
	end
end
event.register(tes3.event.loaded, onLoaded)



---@param e cellChangedEventData
local function onCellChanged(e)
	updateCells()
	goHome.searchCellsForPositions()
	goHome.loadRuntimeDataFromNPCData()
	updatePlayerTrespass(e.cell, e.previousCell)
	checkEnteredNPCHome(e.cell)
	-- Exterior wilderness cells don't have name
	if not e.cell.name then return end
	checkEnteredPublicHouse(e.cell, string.split(e.cell.name, ",")[1])
end
event.register(tes3.event.cellChanged, onCellChanged)

-- Debug event
---@param e keyDownEventData
local function onKeyDown(e)
	if log.level < mwse.logLevel.debug then return end
	if tes3.isKeyEqual({ actual = e, expected = { keyCode = tes3.scanCode.c, isAltDown = true } }) then
		-- ! this crashes my fully modded setup and I dunno why
		-- ? doesn't crash my barely modded testing setup though
		-- log(common.logLevels.none, json.encode(common.runtimeData, { indent = true }))
		-- inspect handles userdata and tables within tables badly
		log:debug("runtimeData = %s", runtimeData)
		return
	end
	if tes3.isKeyEqual({ actual = e, expected = { keyCode = tes3.scanCode.c, isControlDown = true } }) then
		local pos = tostring(tes3.player.position):gsub("%(", "{"):gsub("%)", "}")
		local ori = tostring(tes3.player.orientation):gsub("%(", "{"):gsub("%)", "}")

		log:debug("[POSITIONS] {position = %s, orientation = %s},", pos, ori)
	end
end
event.register(tes3.event.keyDown, onKeyDown)
