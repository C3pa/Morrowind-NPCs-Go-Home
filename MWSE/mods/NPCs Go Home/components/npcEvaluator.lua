local log = mwse.Logger.new()
local npcEvaluator = {}


-- todo: check type of clothing/armour equipped: common, expensive, etc.
-- NPCs barter gold + value of all inventory items
---@param npc tes3reference
---@param merchantCell? tes3cell
function npcEvaluator.calculateWorth(npc, merchantCell)
	local worth = {
		barter = npc.object.barterGold,
		equipment = 0,
		inventory = 0
	}

	-- Add currently equipped items
	for _, item in pairs(npc.object.equipment or {}) do
		-- TODO: this doesn't take into account the value of equipped stacks (only ammunition).
		worth.equipment = worth.equipment + (item.object.value or 0)
	end

	-- Add items in inventory
	for _, item in pairs(npc.object.inventory or {}) do
		worth.inventory = worth.inventory + (item.object.value or 0)
	end


	-- calculate value of objects sold by NPC in the cell, and add it to barter
	if merchantCell then -- if we pass a cell argument
		for box in merchantCell:iterateReferences(tes3.objectType.container) do -- loop over each container
			for item in tes3.iterate(box.inventory or {}) do
				---@cast item tes3itemStack
				if npc.object:tradesItemType(item.objectType) then
					worth.barter = worth.barter + item.object.value -- add its value to the NPCs total value
				end
			end
		end
	end

	-- Calculate the total
	local total = 0
	for _, v in pairs(worth) do
		total = total + v
	end
	log:debug("Calculated worth of %s for %s", total, npc.object.name)

	-- Then add it to the table
	worth.total = total

	return worth
end


return npcEvaluator
