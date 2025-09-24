local Class = {}
Class.__index = Class

function Class:new(data)
	local o = {}
	if data then
		table.copymissing(o, table.deepcopy(data))
	end

	setmetatable(o, self)
	return o
end

return Class
