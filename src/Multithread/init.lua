local Multithread = {}

Multithread.Runner = require(script.Utils.Runner)
Multithread.ParallelChannel = require(script.Utils.ParallelChannel)
Multithread.Event = require(script.Utils.LightweightEvent)

Multithread.fastSpawn = require(script.Utils.fastSpawn)
Multithread.resumeWithErrorHandling = require(script.Utils.resumeWithErrorHandling)

Multithread.VmId = require(script.Utils.VmId)
Multithread.ArgPack = require(script.Utils.ArgPack)
Multithread.ArgSymbolReplacement = require(script.Utils.ArgSymbolReplacement)

return Multithread

--[[
	# Multithread
	A module with utilities for multithreaded Lua on Roblox

	## Runner
		Utilities for spawning code in new threads.

		Runner.TheirChannel: string
			A constant representing the channel object on the other side of the channel.

		Runner.spawn(moduleScript: ModuleScript, functionName: string, ...any) -> channel: ParallelChannel, runner: Script | LocalScript, actor: Actor
			Spawns a new actor in ServerScriptService or PlayerScripts that will run
			the function in the given module script with the given args.

			If you pass in Runner.TheirChannel as one of the arguments,
			it will be replaced with the corresponding ParallelChannel on their side,
			allowing you to communicate with the function in the new thread.

			The actor will be destroyed as soon as the main coroutine for the spawned
			function finishes. If you want the actor to run forever, use spawnDestroyless.

		Runner.run(moduleScript: ModuleScript, functionName: string, ...any) -> ...any
			Same as Runner.spawn, except:

			Returns the results of the function after it has completed, allowing you to
			delegate computations to a different thread as needed.

		Runner.spawnEmpty() -> channel: ParallelChannel, runner: Script | LocalScript, actor: Actor
			Spawns a new actor in ServerScriptService or PlayerScripts.
			You can use the ParallelChannel to tell this empty runner what to do.

		Runner.newRunner(actor: Actor, name: Name) -> channel: ParallelChannel, runner: Script | LocalScript, actor: Actor
			Places a runner script in an actor, then returns the ParallelChannel that
			you can use to communicate with it. This lets you spawn module function
			calls into Actors in the world.

		Runner.spawnDestroyless(moduleScript: ModuleScript, functionName: string, ...any) -> channel: ParallelChannel, runner: Script | LocalScript, actor: Actor
			See Runner.spawn.
			Does not destroy the actor when the main coroutine finishes.

		Runner.runDestroyless(moduleScript: ModuleScript, functionName: string, ...any) -> ...any
			See Runner.run.
			Does not destroy the actor when the main coroutine finishes. There is no
			way to communicate with the spawned function call, so this has little use
			compared to Runner.run or Runner.spawnDestroyless.

	## ParallelChannel
		A utility for communicating between VMs that:
		* wraps around bindables
		* handles potential holes in values sent through bindables
		* has appropriate task.(de)synchronize calls.

		Treat this channel as you would a Remote-based network channel.

		You still must be aware of bindable limitations, like how tables are copied
		and how mixed array/dictionaries are not allowed. These restrictions cannot
		be easily worked around due to each side of the channel being in different
		VMs: we *must* make a copy of all data, and trying to custom-serialize
		tables for compatibility with mixed tables is too slow to be worth doing.

		ParallelChannel.TheirChannel: string
			A constant representing the channel object on the other side of the
			channel.

		ParallelChannel.makeParallelCommunicationChannels(actorScript: Instance) -> void
			Creates Bindables for communication. Can be done once on a template
			object than re-used by Cloning.

		ParallelChannel.start(options: {
			myEvent: BindableEvent,
			theirEvent: BindableEvent,
			myFunction: BindableFunction,
			theirFunction: BindableFunction,
			allowModuleRun?: boolean,
		}) -> ParallelChannel
			Creates a ParallelChannel and starts listening to it for instructions.

			allowModuleRun determines whether the other side is allowed to trigger
			us to invoke functions on arbitrary modules. This is typically used
			on startup of a new thread to tell a script what modularized code to
			run.

		ParallelChannel:onFired(eventName: string, callback: (...any) -> void) -> EventConnection
			Listens for an event to be fired from the other side of the channel.
			Runs the callback synchronized, so it can make changes to the datamodel.

		ParallelChannel:onFiredParallel(eventName: string, callback: (...any) -> void) -> EventConnection
			Listens for an event to be fired from the other siee of the channel.
			Runs the callback desynchronized, so it can do work in parallel.

		ParallelChannel:awaitFiredUnsafe(eventName: string) -> ...any
			Waits for this event to fire, then resumes (synchronized).
			Potentially unsafe since coroutine.resume is used internally which does
			not play nice with the Roblox task scheduler.

		ParallelChannel:awaitFiredParallelUnsafe(eventName: string) -> ...any
			Waits for this event to fire, then resumes (desynchronized).
			Potentially unsafe since coroutine.resume is used internally which does
			not play nice with the Roblox task scheduler.

		ParallelChannel:fire(eventName: string, ...any) -> void
			Fires the event on the other side of the channel with the
			provided arguments. Keep in mind BindableEvent limitations.

			The event will be fired as soon as this thread is synchronized with
			the main thread and will not block the caller while waiting for
			synchronization.

		ParalllelChannel:invoke(funcName: string, ...any) -> ...any
			Invokes the function on the other side of the channel, then returns
			the results.

			The function will be fired as soon as this thread is synchronized with
			the main thread, and **will** block the caller while waiting for
			synchronization.

		ParallelChannel:onInvoked(funcName: string, callback: (...any) -> ...any)
			Run the given callback when the other side of the channel invokes
			the given function name, then returns the result to the other side.

			Starts the callback synchronized.

		ParallelChannel:sync(syncName: string, ...any) -> ...any
			Waits for the other side to call :sync(syncName) or :signalSync(syncName)
			Returns the arguments that the other side provided.

			This can be used to wait until both sides are ready for processing,
			or to exchange data required for next steps.

			For example, a common pattern is to :sync("ready") after you have
			connected all events and functions, but before firing and invoking
			any yourself, so that both sides will surely be prepared for event
			and function invocations.

			Which side will return first from :sync is undefined.

		ParallelChannel:signalSync(syncName: string, ...any) -> void
			Calls :sync(syncName, ...) in the background, without yielding
			the caller. This is solely to tell the other side "you can continue",
			as if the other side is *not* ready, we don't wait for them to be,
			unlike :sync

		ParallelChannel:spawnModule(moduleScript: ModuleScript, functionName: string, ...any) -> void
			Tells the other side of the channel to run the given function in the
			given module, and does not return the result.

			This does not work if allowModuleRun is false on the other side.

		ParallelChannel:runModule(moduleScript: ModuleScript, functionName: string, ...any) -> ...any
			Tells the other side of the channel to run the given function in the
			given module, then waits for and returns the result.

			This does not work if allowModuleRun is false on the other side.

	## Event
		An Event AKA Signal object:
		* Supports camelCase and PascalCase for API compatibility
		* Doesn't use Bindables, so it works when a VM is desynchronized
		* Unordered
		* Properly handles connections and disconnections while firing
		* Connections are fast unless Event is firing
		* Connections hold weak references to the parent Event
		* Connections do not hold references to their associated callback
		* Event:Destroy() loses reference to all Connections and callbacks
		* If an event is GCed, Connections properly show as disconnected
		* Event errors when use is attempted after destroyed

		Event.new() -> Event
			Creates a new event object

		Event:connect(callback: (...any) -> void) -> EventConnection
			Connects the callback to this event.
			If connected during an event fire, callback will not be called.

		Event:waitUnsafe() -> ...any
			Waits for this event to fire, then returns the args.
			If the event is destroyed while waiting, the internal callback
			should be GCed, and as a result the calling coroutine should
			also be GCed. It should be safe to Destroy while :wait()ing.
			Potentially unsafe since coroutine.resume is used internally which does
			not play nice with the Roblox task scheduler.

		Event:fire(...any) -> void
			Fires this event.

		Event:destroy() -> void
			Destroys this event.
			Loses connection to all callbacks and connections.
			Attempted use of this event from here on out will error.

		EventConnection:disconnect()
			Disconnects an event connection.
			If disconnected during an event fire, the callback will
			not run for any active event fire that it has not already
			ran for.

		EventConnection.connected
			Returns whether this connection is connected
			If the parent event has been garbage collected, this
			property will eventually return false.

	## fastSpawn
		Coroutine-based fast spawn.
		Essentially `coroutine.wrap(callback)(...)` with built-in error
		handling.

		fastSpawn(callback: (...any) -> void, ...any) -> void
			Spawns callback in a new coroutine with the given arguments.

	## resumeWithErrorHandling
		`coroutine.resume` with error handling.
		Particularly useful in a multithreaded context since you
		can't use BindableEvents for Roblox error handling.

		resumeWithErrorHandling(coroutine: Coroutine, ...any) -> void
			Resumes the target coroutine and warns if any errors occurred.
			Does not return any results, such as arguments to
			coroutine.yield. If you need those, you will need to handle
			errors yourself.

	## VmId
		A utility for getting a unique id for the current VM, and
		getting other VM info.

		VmId.getMyVmId() -> string
			Returns a unique ID for this vm. This ID is shared with other
			copies of this module, and is unique to this session and VM
			context.

			Everything except the guid is for human readability:
			* VmId lets you know what this string is for
			* The number tells you in what order this VM was discovered.
			  Numbers for elevated context are separate.
			  Typically the main thread will be number 1.
			* "(Elevated) Main/Actor" gives you context for what VM this is.

			Example IDs:
				{VmId:1 Main 136DACAB-5721-4BBD-ABA1-CCA835FBF7E0}
				{VmId:2 Actor 136DACAB-5721-4BBD-ABA1-CCA835FBF7E0}
				{VmId:1 Elevated Main 136DACAB-5721-4BBD-ABA1-CCA835FBF7E0}

		VmId.getCurrentVmCount() -> number
			Returns the number of VMs that have required this module or
			copies of this module.

		VmId.isActorThread() -> boolean
			Returns whether this VM is in an actor thread and can be
			desynchronized. There may be multiple VMs in a single
			actor thread.

		VmId.isMainThread() -> boolean
			Returns whether this VM is in the main thread and can't be
			desynchronized. There may be multiple VMs in the main thread.

		VmId.isElevatedContext() -> boolean
			Returns whether this VM has access to the CoreGui.

	## ArgPack
		Tools for packing an unpacking an argument list, replacing
		holes in the list with a placeholder value.

		ArgPack.pack(...any) -> { ...any }
			Packs the args into a table, replacing nil values with a
			string placeholder that's safe to travel across threads.

		ArgPack.unpack(args: { ...any }) -> ...any
			Unpacks the args table, replacing any nil placeholders
			with actual nils.

	## ArgSymbolReplacement
		Tools for replacing "symbols" in arguments with actual values,
		or vice versa.

		ArgSymbolReplacement.replace(replaceMap: { [any]: any }, ...any) -> ...any
			Replaces arguments matching keys in the replaceMap with
			values from the replaceMap.

		ArgSymbolReplacement.replaceCallback(replaceMap: { [any]: () -> any }, ...any) -> ...any
			Replaces arguments matching keys in the replaceMap with
			the result of calls to values from the replaceMap.


--]]
