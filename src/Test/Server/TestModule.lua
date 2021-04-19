local RunService = game:GetService("RunService")

local TestModule = {}

function TestModule.spawnTest(channel, ...)
	task.desynchronize()

	print("spawnTest", ...)

	channel:onFired("print", function(...)
		print("print serial", ...)
	end)

	channel:onFiredParallel("print", function(...)
		print("print parallel", ...)
	end)

	channel:sync("ready")
end

function TestModule.runParallel()
	local veryStart = os.clock()
	local busyWaited = 0

	while busyWaited < 5 do
		task.synchronize()
		RunService.Heartbeat:Wait()
		task.desynchronize()
		local start = os.clock()
		while os.clock() - start < 1 / 60 do
		end
		busyWaited += os.clock() - start
	end

	return busyWaited, os.clock() - veryStart
end

function TestModule.printVmId()
	local Multithread = require(game:GetService("ReplicatedStorage").Multithread)
	print("Actor:", Multithread.VmId.getMyVmId())
end

return TestModule
