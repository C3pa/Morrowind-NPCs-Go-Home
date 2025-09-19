local config = require("NPCs Go Home.config")
local util = require("NPCs Go Home.util")


local log = mwse.Logger.new()
local lockDoors = {}

local prisonMarkerId = "PrisonMarker"
local cityMatch = "^(%w+), (.*)"

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
	-- Don't lock prison markers.
	if door.id == prisonMarkerId then
		return true
	end

	-- Don't lock non-cell change doors.
	if not door.destination then
		log:trace("Non-Cell-change door %s, ignoring", door.id)
		return true
	end

	-- We use this a lot, so set a reference to it.
	local dest = door.destination.cell

	-- Only doors in cities and towns (interior cells with names that contain the exterior cell).
	local inCity = isCityCell(dest.id, homeCellId)

	-- Peek inside doors to look for guild halls, inns and clubs.
	local leadsToPublicCell = util.isPublicHouse(dest)

	-- Don't lock unoccupied cells.
	local hasOccupants = false
	for npc in dest:iterateReferences(tes3.objectType.npc) do
		if not util.isIgnoredNPC(npc) then
			hasOccupants = true
			break
		end
	end

	-- Don't lock doors to canton cells.
	local isCantonWorks = util.isCantonWorksCell(dest)

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
	for door in cell:iterateReferences(tes3.objectType.door) do
		if isIgnoredDoor(door, cell.id) then
			goto continue
		end

		if not door.data.NPCsGoHome then
			door.data.NPCsGoHome = {}
		end

		-- Don't mess around with doors that are already locked
		-- the one time I specifically don't want to use [ if not thing ]
		if door.data.NPCsGoHome.alreadyLocked == nil then
			door.data.NPCsGoHome.alreadyLocked = tes3.getLocked({ reference = door })
		end

		log:trace("Found %slocked %s with destination %s",
			door.data.NPCsGoHome.alreadyLocked and "" or "un", door.id, door.destination.cell.id)

		-- It's not a door that's already locked or one we've already touched, so lock it.
		if not door.data.NPCsGoHome.alreadyLocked and not door.data.NPCsGoHome.modified then
			log:debug("Locking: %s to %s", door.object.name, door.destination.cell.id)

			-- TODO: pick this better
			tes3.lock({ reference = door, level = math.random(25, 100) })
			door.data.NPCsGoHome.modified = true
		end

		log:trace("New lock status: %s", tes3.getLocked({ reference = door }))

		:: continue ::
	end
end

---@param cell tes3cell
function lockDoors.processDoors(cell)
	log:info("Looking for doors to process in cell: %s", cell.id)

	local isNight = util.isNight()

	if config.lockDoors and isNight then
		lockDoorsInCell(cell)
		return
	end

	-- Unlock, don't need all the extra overhead that comes along with isIgnoredDoor() here
	for door in cell:iterateReferences(tes3.objectType.door) do
		-- Only unlock doors that we locked before
		if door.data and door.data.NPCsGoHome and door.data.NPCsGoHome.modified then
			door.data.NPCsGoHome.modified = false

			tes3.setLockLevel({ reference = door, level = 0 })
			tes3.unlock({ reference = door })

			log:debug("Unlocking: %s to %s", door.object.name, door.destination.cell.id)
		end
	end

	log:trace("Done with doors")
end

return lockDoors
