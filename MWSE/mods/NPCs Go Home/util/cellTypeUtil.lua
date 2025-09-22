local enum = require("NPCs Go Home.enum")

local cellType = {}

-- TODO: consider consolidating with nameUtil module
-- TODO: pick this better, i18n
---@param cell tes3cell
---@return NPCsGoHome.publicHouseType|integer
function cellType.pickPublicHouseType(cell)
	local id = cell.id:lower()
	if id:match("guild") then
		return enum.publicHouse.guildhalls
	elseif id:match("temple") then
		return enum.publicHouse.temples
	elseif id:match("canalworks") or cell.id:match("waistworks") then
		return enum.publicHouse.cantons
	elseif (id:match("house") and not id:match("trade"))
		or id:match("manor")
		or id:match("tower") then
		return enum.publicHouse.homes
	end
	return enum.publicHouse.inns
end

return cellType
