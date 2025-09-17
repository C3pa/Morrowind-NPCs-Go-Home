local runtimeData = require("NPCs Go Home.components.runtimeData")

local interop = {}

-- TODO: maybe external mods shouldn't have access to runtimeData?
function interop.setRuntimeData(t)
	runtimeData = t
end

function interop.getRuntimeData() return
	runtimeData
end

return interop
