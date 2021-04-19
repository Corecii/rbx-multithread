task.synchronize()

local RunService = game:GetService("RunService")

local ParallelChannel = require(script.Parent.ParallelChannel)
local fastSpawn = require(script.Parent.fastSpawn)

local Runner = {}
Runner.TheirChannel = ParallelChannel.TheirChannel

local threadRunner
local miscActorParents

if RunService:IsClient() then
	threadRunner = script.ThreadRunnerClient:Clone()
	miscActorParents = game:GetService("Players").LocalPlayer.PlayerScripts
else
	threadRunner = script.ThreadRunnerServer:Clone()
	miscActorParents = game:GetService("ServerScriptService")
end

threadRunner.Disabled = false

local moduleReference = Instance.new("ObjectValue")
moduleReference.Name = "MultithreadModule"
moduleReference.Value = script.Parent.Parent
moduleReference.Parent = threadRunner

ParallelChannel.makeParallelCommunicationChannels(threadRunner)

function Runner.newRunner(actor, name)
	local runner = threadRunner:Clone()
	if name then
		runner.Name = name
	end

	local channel = ParallelChannel.start({
		allowModuleRun = false,
		myEvent = runner.parentParallelEvent,
		myFunction = runner.parentParallelFunction,
		theirEvent = runner.childParallelEvent,
		theirFunction = runner.childParallelFunction,
	})

	runner.Parent = actor

	return channel, runner
end

function Runner.spawn(moduleScript, functionName, ...)
	local actor = Instance.new("Actor")
	actor.Name = "RunnerActor"

	local channel, runner = Runner.newRunner(actor)
	actor.Parent = miscActorParents

	fastSpawn(function(...)
		channel:invokeModule(moduleScript, functionName, ...)
		actor:Destroy()
	end, ...)

	return channel, runner, actor
end

function Runner.run(moduleScript, functionName, ...)
	local actor = Instance.new("Actor")
	actor.Name = "RunnerActor"

	local channel, _runner = Runner.newRunner(actor)
	actor.Parent = miscActorParents

	local result = table.pack(channel:invokeModule(moduleScript, functionName, ...))
	actor:Destroy()

	return unpack(result, 1, result.n)
end

function Runner.spawnDestroyless(moduleScript, functionName, ...)
	local actor = Instance.new("Actor")
	actor.Name = "RunnerActor"

	local channel, runner = Runner.newRunner(actor)
	actor.Parent = miscActorParents

	channel:spawnModule(moduleScript, functionName, ...)

	return channel, runner, actor
end

function Runner.runDestroyless(moduleScript, functionName, ...)
	local actor = Instance.new("Actor")
	actor.Name = "RunnerActor"

	local channel, _runner = Runner.newRunner(actor)
	actor.Parent = miscActorParents

	local result = table.pack(channel:invokeModule(moduleScript, functionName, ...))

	return unpack(result, 1, result.n)
end

function Runner.spawnEmpty()
	local actor = Instance.new("Actor")
	actor.Name = "RunnerActor"

	local channel, runner = Runner.newRunner(actor)
	actor.Parent = miscActorParents

	return channel, runner, actor
end

return Runner
