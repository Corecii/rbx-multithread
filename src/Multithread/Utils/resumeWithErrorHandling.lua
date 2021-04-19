return function(targetCoroutine, ...)
	local success, err = coroutine.resume(targetCoroutine, ...)
	if not success then
		warn(string.format("Coroutine failed after resume:\n%s", debug.traceback(targetCoroutine, tostring(err))))
	end
end
