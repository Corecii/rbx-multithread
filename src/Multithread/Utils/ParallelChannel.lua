local ArgPack = require(script.Parent.ArgPack)
local ArgSymbolReplacement = require(script.Parent.ArgSymbolReplacement)
local LightweightEvent = require(script.Parent.LightweightEvent)
local resumeWithErrorHandling = require(script.Parent.resumeWithErrorHandling)
local fastSpawn = require(script.Parent.fastSpawn)

local ParallelChannel = {}
ParallelChannel.__index = ParallelChannel

ParallelChannel.TheirChannel = "{ParallelChannel:TheirChannel 1eaac727-7bf0-464e-afde-a475d3478233}"

function ParallelChannel.makeParallelCommunicationChannels(actorScript)
	local parentEvent = Instance.new("BindableEvent")
	parentEvent.Name = "parentParallelEvent"
	parentEvent.Parent = actorScript

	local parentFunction = Instance.new("BindableFunction")
	parentFunction.Name = "parentParallelFunction"
	parentFunction.Parent = actorScript

	local childEvent = Instance.new("BindableEvent")
	childEvent.Name = "childParallelEvent"
	childEvent.Parent = actorScript

	local childFunction = Instance.new("BindableFunction")
	childFunction.Name = "childParallelFunction"
	childFunction.Parent = actorScript
end

function ParallelChannel.start(options)
	local self = {}
	setmetatable(self, ParallelChannel)

	self._allowModuleRun = options.allowModuleRun and true or false

	self._theirSyncs = {}
	self._mySyncs = {}

	self._theirEvent = options.theirEvent
	self._myEvent = options.myEvent

	self._theirFunction = options.theirFunction
	self._myFunction = options.myFunction

	self._events = {}
	self._eventsParallel = {}
	self._funcs = {}

	task.synchronize()

	self._myEvent.Event:Connect(function(eventName, args)
		if not self._events[eventName] then
			if not self._eventsParallel[eventName] then
				error(string.format("Event %s is not connected", tostring(eventName)))
			end
			return
		end

		self._events[eventName]:fire(ArgPack.unpack(args))
	end)

	-- There is no way to tell if we're under an actor / able to connect
	-- parallel right now
	pcall(function()
		self._myEvent.Event:ConnectParallel(function(eventName, args)
			if not self._eventsParallel[eventName] then
				if not self._events[eventName] then
					error(string.format("Event %s is not connected", tostring(eventName)))
				end
				return
			end

			self._eventsParallel[eventName]:fire(ArgPack.unpack(args))
		end)
	end)

	self._myFunction.OnInvoke = function(funcName, args)
		if not self._funcs[funcName] then
			error(string.format("Function %s is not defined", tostring(funcName)))
		end
		return self._funcs[funcName](ArgPack.unpack(args))
	end

	self:onFired("__sync", function(syncName, ...)
		local coroutineToResume = self._theirSyncs[syncName]

		self._theirSyncs[syncName] = table.pack(...)

		if coroutineToResume then
			resumeWithErrorHandling(coroutineToResume)
		end
	end)

	if self._allowModuleRun then
		self:onFired("__spawnModule", function(moduleScript, functionName, ...)
			local module = require(moduleScript)
			if typeof(module) == "function" then
				module(ArgSymbolReplacement.replace({ [ParallelChannel.TheirChannel] = self }, functionName, ...))
			else
				module[functionName](ArgSymbolReplacement.replace({ [ParallelChannel.TheirChannel] = self }, ...))
			end
		end)

		self:onInvoked("__invokeModule", function(moduleScript, functionName, ...)
			local module = require(moduleScript)
			if typeof(module) == "function" then
				return module(ArgSymbolReplacement.replace({ [ParallelChannel.TheirChannel] = self }, functionName, ...))
			else
				return module[functionName](ArgSymbolReplacement.replace({ [ParallelChannel.TheirChannel] = self }, ...))
			end
		end)
	end

	return self
end

function ParallelChannel:_getEvent(eventName)
	if not self._events[eventName] then
		self._events[eventName] = LightweightEvent.new()
	end

	return self._events[eventName]
end

function ParallelChannel:_getParallelEvent(eventName)
	if not self._eventsParallel[eventName] then
		self._eventsParallel[eventName] = LightweightEvent.new()
	end

	return self._eventsParallel[eventName]
end

function ParallelChannel:onFired(eventName, callback)
	return self:_getEvent(eventName):connect(callback)
end

function ParallelChannel:onFiredParallel(eventName, callback)
	return self:_getParallelEvent(eventName):connect(callback)
end

function ParallelChannel:awaitFiredUnsafe(eventName)
	return self:_getEvent(eventName):waitUnsafe()
end

function ParallelChannel:awaitFiredParallelUnsafe(eventName)
	return self:_getParallelEvent(eventName):waitUnsafe()
end

function ParallelChannel:fire(eventName, ...)
	fastSpawn(function(...)
		task.synchronize()
		self._theirEvent:Fire(eventName, ArgPack.pack(...))
	end, ...)
end

function ParallelChannel:onInvoked(funcName, callback)
	assert(self._funcs[funcName] == nil, "Function already defined")

	self._funcs[funcName] = callback
end

function ParallelChannel:invoke(funcName, ...)
	task.synchronize()
	return self._theirFunction:Invoke(funcName, ArgPack.pack(...))
end

function ParallelChannel:spawnModule(moduleScript, functionName, ...)
	self:fire("__spawnModule", moduleScript, functionName, ...)
end

function ParallelChannel:invokeModule(moduleScript, functionName, ...)
	return self:invoke("__invokeModule", moduleScript, functionName, ...)
end

function ParallelChannel:sync(syncName, ...)
	assert(typeof(syncName) == "string", "Expected string for syncName")
	if self._mySyncs[syncName] then
		error(string.format("An active sync for %s already exists. Do you have a concurrency bug?", syncName))
	end

	self._mySyncs[syncName] = true
	self:fire("__sync", syncName, ...)

	if not self._theirSyncs[syncName] then
		self._theirSyncs[syncName] = coroutine.running()
		coroutine.yield()
	end

	local theirSyncArgs = self._theirSyncs[syncName]

	self._theirSyncs[syncName] = nil
	self._mySyncs[syncName] = nil

	return unpack(theirSyncArgs, 1, theirSyncArgs.n)
end

function ParallelChannel:signalSync(syncName, ...)
	coroutine.wrap(function(...)
		self:sync(syncName, ...)
	end)(...)
end

return ParallelChannel
