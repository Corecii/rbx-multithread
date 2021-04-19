local resumeWithErrorHandling = require(script.Parent.resumeWithErrorHandling)

return function(callback, ...)
	resumeWithErrorHandling(coroutine.create(callback), ...)
end
