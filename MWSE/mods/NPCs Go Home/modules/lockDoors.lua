local config = require("NPCs Go Home.config")
local nameUtil = require("NPCs Go Home.util.nameUtil")
local publicHouse = require("NPCs Go Home.components.publicHouse")
local util = require("NPCs Go Home.util")


local log = mwse.Logger.new()
local lockDoors = {}

local prisonMarkerId = "PrisonMarker"
local cityMatch = "^(%w+), (.*)"
local lockLow = 5
local lockHigh = 20

---@param internalCellId string
---@param externalCellId string
local function isCityCell(internalCellId, externalCellId)
	-- Easy mode
	if string.match(internalCellId, externalCellId) then
		log:trace("Easy mode city: %s in %s", internalCellId, externalCellId)
		return true
	end

	-- Check for "advanced" cities
	local _, _, internalCity = string.find(internalCellId, cityMatch)
	local _, _, externalCity = string.find(externalCellId, cityMatch)

	if externalCity and externalCity == internalCity then
		log:trace("Hard mode city: %s in %s, %s == %s", internalCellId, externalCellId, externalCity, internalCity)
		return true
	end

	log:trace("Hard mode not city: %s not in %s, %s ~= %s or both are nil",
		internalCellId, externalCellId, externalCity, internalCity)
	return false
end

-- Doors that lead to ignored, exterior, canton, unoccupied, or public cells, and doors that aren't in cities.
---@param door tes3reference
---@param homeCellId string
local function isIgnoredDoor(door, homeCellId)
	-- Don't lock non-cell change doors.
	if not util.isTeleportDoor(door) then
		return true
	end

	if tes3.getLocked({ reference = door }) then
		return true
	end

	-- Don't lock prison markers.
	if door.id == prisonMarkerId then
		return true
	end


	-- We use this a lot, so set a reference to it.
	local dest = door.destination.cell

	-- Only doors in cities and towns (interior cells with names that contain the exterior cell).
	local inCity = isCityCell(dest.id, homeCellId)

	-- Peek inside doors to look for guild halls, inns and clubs.
	local leadsToPublicCell = publicHouse.isPublicHouse(dest)

	-- Don't lock unoccupied cells.
	local hasOccupants = false
	for npc in dest:iterateReferences(tes3.objectType.npc) do
		if not util.isIgnoredNPC(npc) then
			hasOccupants = true
			break
		end
	end

	-- Don't lock doors to canton cells.
	local isCantonWorks = nameUtil.isCantonWorksCell(dest)

	log:trace("%s is %s, (%sin a city, is %spublic, %soccupied)",
		dest.id, util.isIgnoredCell(dest) and "ignored" or "not ignored",
		inCity and "" or "not ", leadsToPublicCell and "" or "not ", hasOccupants and "" or "un")

	return util.isIgnoredCell(dest) or
		not util.isInteriorCell(dest) or
		isCantonWorks or
		not inCity or
		leadsToPublicCell or
		not hasOccupants
end


---@param cell tes3cell
local function lockDoorsInCell(cell)
	for door in cell:iterateReferences(tes3.objectType.door, false) do
		if isIgnoredDoor(door, cell.id) then
			goto continue
		end
		local data = table.getset(door.data, "NPCsGoHome", {}) --[[@as NPCsGoHome.doorReferenceData]]
		data.locked = true
		tes3.lock({ reference = door, level = math.random(lockLow, lockHigh) * 5 })
		log:debug("Locking: %s to %s", door.object.name, door.destination.cell.id)

		:: continue ::
	end
end

-- Returns `true` if the door was locked by this module.
---@param reference tes3reference
local function isLocked(reference)
	if reference.data and reference.data.NPCsGoHome and reference.data.NPCsGoHome.locked then
		return true
	end
	return false
end

---@param cell tes3cell
local function processDoors(cell)
	log:debug("Looking for doors to process in cell: %s", cell.id)

	local isNight = util.isNight()

	if config.lockDoors and isNight then
		lockDoorsInCell(cell)
		return
	end

	-- Unlock, don't need all the extra overhead that comes along with isIgnoredDoor() here
	for door in cell:iterateReferences(tes3.objectType.door) do
		-- Only unlock doors that we locked before
		if isLocked(door) then
			door.data.NPCsGoHome = nil

			tes3.setLockLevel({ reference = door, level = 0 })
			tes3.unlock({ reference = door })

			log:debug("Unlocking: %s to %s", door.object.name, door.destination.cell.id)
		end
	end
end

function lockDoors.update()
	for _, cell in ipairs(tes3.getActiveCells()) do
		if not cell.isInterior then
			processDoors(cell)
		end
	end
end

local tooltipId = tes3ui.registerID("NPCsGoHome_tooltip_label")

---@param e uiObjectTooltipEventData
function lockDoors.onUiObjectTooltip(e)
	if e.object.objectType ~= tes3.objectType.door or not isLocked(e.reference) then return end
	local tooltip = e.tooltip
	tooltip:createLabel({
		id = tooltipId,
		text = string.format("Closed. Open from %s to %s.", config.openTime, config.closeTime)
	})
end

return lockDoors
