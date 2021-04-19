local ParallelChannel = require(script.Parent.ParallelChannel)

return function(actorScript)
	ParallelChannel.start({
		allowModuleRun = true,
		myEvent = actorScript.childParallelEvent,
		theirEvent = actorScript.parentParallelEvent,
		myFunction = actorScript.childParallelFunction,
		theirFunction = actorScript.parentParallelFunction,
	})
	-- The runModule methods and events of the channel take over from here.
end
