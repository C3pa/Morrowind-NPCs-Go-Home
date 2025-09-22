-- TODO: multiple functions in this module need i18n

local nameUtil = {}

-- Removes "the whatever" from the NPCs name. For example for M'Aiq the Liar it returns M'Aiq.
---@param name string
function nameUtil.removeTitle(name)
	return name:gsub(" the .*$", "")
end


---@param cell tes3cell
---@return string cityName
---@return string buildingName
function nameUtil.getCityAndBuildingName(cell)
	local cellName = cell.name
	local city, buildingName

	if cellName and string.match(cellName, ",") then
		local result = string.split(cellName, ",")
		city = result[1]
		-- Tribunal has a cell named "Sotha Sil,". Sigh.
		buildingName = result[2] and string.trim(result[2])
	else
		city = "Wilderness"
		buildingName = cell.id
	end
	return city, buildingName
end


local plazaPattern = {
	"waistworks", "vivec, .* plaza", -- Vvardenfell
	"almas thirr, plaza",         -- Tamriel Rebuilt
	"molag mar, plaza"            -- No-frills closed Molag Mar
}

-- Waistworks and plaza cells.
---@param lowerId string
function nameUtil.isPublicCantonCell(lowerId)
	for _, pattern in ipairs(plazaPattern) do
		if lowerId:match(pattern) then
			return true
		end
	end
	return false
end

local otherCantonPattern = {
	"canalworks", "underworks"
}

-- Any interior canton cell
---@param cell tes3cell
function nameUtil.isCantonWorksCell(cell)
	local lowerId = cell.id:lower()
	if nameUtil.isPublicCantonCell(lowerId) then
		return true
	end

	for _, pattern in ipairs(otherCantonPattern) do
		if lowerId:match(pattern) then
			return true
		end
	end
	return false
end

return nameUtil
