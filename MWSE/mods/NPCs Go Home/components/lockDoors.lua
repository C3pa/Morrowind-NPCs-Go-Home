local config = require("NPCs Go Home.config")
local util = require("NPCs Go Home.util")


local log = mwse.Logger.new()
local lockDoors = {}

---@param cell tes3cell
---@return fun(): tes3reference
local function iterateDoors(cell)
	local function iterator()
		for door in cell:iterateReferences(tes3.objectType.door) do
			if not util.isIgnoredDoor(door, cell.id) then
				coroutine.yield(door)
			end
		end
	end
	return coroutine.wrap(iterator)
end

---@param cell tes3cell
function lockDoors.processDoors(cell)
	log:info("Looking for doors to process in cell: %s", cell.id)

	local isNight = util.isNight()

	if config.lockDoors and isNight then
		for door in iterateDoors(cell) do
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
		end
		return
	end

	-- Unlock, don't need all the extra overhead that comes along with util.isIgnoredDoor() here
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
