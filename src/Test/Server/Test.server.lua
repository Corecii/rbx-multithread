local Multithread = require(game.ReplicatedStorage.Multithread)

print("Main:", Multithread.VmId.getMyVmId())

for _ = 1, 100 do
	Multithread.Runner.run(script.Parent.TestModule, "printVmId")
end
