local ArgSymbolReplacement = {}

function ArgSymbolReplacement.replace(symbols, ...)
	local args = { ... }
	local count = select("#", ...)

	for index = 1, count do
		local arg = args[index]
		if symbols[arg] then
			args[index] = symbols[arg]
		end
	end

	return unpack(args, 1, count)
end

function ArgSymbolReplacement.replaceCallback(symbols, ...)
	local args = { ... }
	local count = select("#", ...)

	for index = 1, count do
		local arg = args[index]
		if symbols[arg] then
			args[index] = symbols[arg]()
		end
	end

	return unpack(args, 1, count)
end

return ArgSymbolReplacement
