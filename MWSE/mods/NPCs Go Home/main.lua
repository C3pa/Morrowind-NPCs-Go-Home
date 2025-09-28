local config = require("NPCs Go Home.config")

local log = mwse.Logger.new({
	logLevel = config.logLevel,
})

local enum = require("NPCs Go Home.enum")
local housing = require("NPCs Go Home.components.housing")
local publicHouse = require("NPCs Go Home.components.publicHouse")
local nameUtil = require("NPCs Go Home.util.nameUtil")
local util = require("NPCs Go Home.util")
dofile("NPCs Go Home.mcm")

local goHome = require("NPCs Go Home.modules.goHome")
local lockDoors = require("NPCs Go Home.modules.lockDoors")


local inspect = require("inspect")
local inspect_METATABLE = inspect.METATABLE
-- Taken from core\lib\logger\formatters.lua
-- The default formatter will print the inspect result on the same line since it also sets indent to "" and
-- newline to " ". The default options provide more human-readable, but also more verbose messages.
local INSPECT_PARAMS = {
	process = function(item, path)
		if path[#path] == inspect_METATABLE then
			-- ignore metatables
			return
		end


		local ty, subtype = type(item)

		-- Check if it's a `table` or `userdata` with a `__tostring` metamethod
		if ty == "table" or ty == "userdata" then
			-- sol types have this magic property we can (ab)use
			if subtype then
				return string.format('%s("%s")', subtype, item)
			end

			-- Some things incorrectly define the `__tostring` method on the object instead of its metatable.
			-- But we'll play nice and support them anyway.
			local tostr = item.__tostring
			if not tostr then
				---@type metatable|nil
				local meta = getmetatable(item)

				tostr = meta and meta.__tostring
			end

			if tostr then
				-- sometimes people define their `__tostring` metamethods in a way that causes errors.
				local status, str = pcall(tostr, item)

				if status then
					return str
				end
			end
		end

		return item
	end
}

event.register(tes3.event.keyDown, function(e)
	if log.level < mwse.logLevel.debug then return end
	if not tes3.isKeyEqual({ actual = e, expected = { keyCode = tes3.scanCode.c, isAltDown = true } }) then return end
	log:debug("publicHouses = %s", inspect(publicHouse.getAll(), INSPECT_PARAMS))
	log:debug("homes = %s", inspect(housing.getAll(), INSPECT_PARAMS))
end)

local function message(...)
	if config.showMessages then
		tes3.messageBox(...)
	end
end

-- TODO: this is only a debugging function.
---@param cell tes3cell
local function checkEnteredNPCHome(cell)
	if log.level < mwse.logLevel.info then return end
	local npcId = housing.getHome(cell.id)
	if not npcId then return end
	log:info("Entering home of %s, %s", npcId, cell.id)
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

	if util.isInteriorCell(cell) and not util.isIgnoredCell(cell) and not publicHouse.isPublicHouse(cell) and inCity then
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
local function checkEnteredPublicHouse(cell)
	local publicCell = publicHouse.getPublicHouse(cell)
	if not publicCell then return end

	local typeOfPub = publicCell.type
	local pubTypeName = table.find(enum.publicHouse, typeOfPub) --[[@as string]]
	local msg = string.format("Entering public space %s, a%s %s in the town of %s.", publicCell.name,
		util.vowel(pubTypeName), pubTypeName:gsub("s$", ""), publicCell.city)

	-- TODO: check for more servicers, not just proprietor
	local handle = publicCell.proprietor
	if handle and handle:valid() and util.isServicer(handle:getObject()) then
		local npc = handle:getObject().object
		msg = msg .. string.format(" Talk to %s, %s for services.", npc.name, npc.class)
	end

	log:info(msg)
	-- This one is more informative, and not entirely for debugging, and reminiscent of Daggerfall's messages.
	message(msg)
end

-- TODO this can be implemented with dialogue.
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

-- TODO reimplement these checks
---@param cell tes3cell
local function applyChanges(cell)
	cell = cell or tes3.getPlayerCell()

	if util.isIgnoredCell(cell) then return end

	-- Interior cells, except Canton cells, don't do anything
	if util.isInteriorCell(cell) and
		not (config.cantonCellsPolicy == enum.cantonPolicy.exterior and nameUtil.isCantonWorksCell(cell)) then
		return
	end

	-- Don't do anything to public houses
	if publicHouse.isPublicHouse(cell) then return end

	-- Deal with NPCs and mounts/pets in cell
	goHome.processNPCs(cell)
	goHome.processPets(cell)
	goHome.processSiltStriders(cell)

	-- Check doors in the cell, locking those that aren't inns/clubs
	lockDoors.processDoors(cell)
end


local function onWeatherChanged()
	goHome.update()
end
event.register(tes3.event.weatherChangedImmediate, onWeatherChanged)
event.register(tes3.event.weatherTransitionFinished, onWeatherChanged)

local function onLoaded()
	tes3.player.data.NPCsGoHome = tes3.player.data.NPCsGoHome or {}

	goHome.onLoaded()

	if not updateTimer or updateTimer.state ~= timer.active then
		updateTimer = timer.start({
			type = timer.game,
			duration = 1 / 4,
			iterations = -1,
			callback = goHome.update
		})
	end
end
event.register(tes3.event.loaded, onLoaded)

---@param e cellChangedEventData
local function onCellChanged(e)
	updatePlayerTrespass(e.cell, e.previousCell)
	checkEnteredNPCHome(e.cell)
	checkEnteredPublicHouse(e.cell)
end
event.register(tes3.event.cellChanged, onCellChanged)
