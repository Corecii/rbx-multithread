local None = "{ArgPack:None 086c42dc-a5c0-4c4d-a669-3c507d84494d}"

local ArgPack = {}

function ArgPack.pack(...)
	local args = { ... }
	for index = 1, select("#", ...) do
		if args[index] == nil then
			args[index] = None
		end
	end

	return args
end

function ArgPack.unpack(args)
	local count = #args

	for index, value in ipairs(args) do
		if value == None then
			args[index] = nil
		end
	end

	return unpack(args, 1, count)
end

return ArgPack
