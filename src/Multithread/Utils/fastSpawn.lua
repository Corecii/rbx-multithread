return function(callback, ...)
	coroutine.wrap(xpcall)(callback, function(err)
		warn(string.format("FastSpawn failed:\n%s", debug.traceback(tostring(err), 2)))
	end, ...)
end
