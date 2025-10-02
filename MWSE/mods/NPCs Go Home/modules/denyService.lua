local config = require("NPCs Go Home.config")
local publicHouse = require("NPCs Go Home.components.publicHouse")
local util = require("NPCs Go Home.util")


local log = mwse.Logger.new()

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
	log:debug("Updating player trespass status to %s", tes3.player.data.NPCsGoHome.intruding)
end

local denyService = {}

---@param e cellChangedEventData
function denyService.onCellChanged(e)
	updatePlayerTrespass(e.cell, e.previousCell)
end

-- TODO this can be implemented with dialogue.
---@param e activateEventData
function denyService.onActivate(e)
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

return denyService
