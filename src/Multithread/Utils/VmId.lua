--# selene: allow(global_usage)

-- We *need* use use _G so we don't increment the VM count if a *duplicate* of
-- this module cause it to increase (instead this own module itself).

local HttpService = game:GetService("HttpService")

local isElevatedContext = false
local isActorThread = false

local vmIdValueParent

pcall(function()
	-- Elevated context / plugin
	local _ = game:GetService("CoreGui").Name -- Test security context

	vmIdValueParent = game:GetService("CoreGui")
	isElevatedContext = true
end)

if not vmIdValueParent then
	-- ServerStorage exists and works on clients as a non-replicated container!
	vmIdValueParent = game:GetService("ServerStorage")
end

local vmIdValue = vmIdValueParent:FindFirstChild("__VmCount")

if not vmIdValue then
	-- We're using a Value object so that we can set it to Archivable false so
	-- it won't save.
	vmIdValue = Instance.new("IntValue")
	vmIdValue.Name = "__VmCount"
	vmIdValue.Archivable = false
	vmIdValue.Parent = vmIdValueParent
end

local function testIsActorThread()
	pcall(function()
		local bindable = Instance.new("BindableEvent")
		bindable.Event:ConnectParallel(function()
			-- Errors if in main vm
			-- Also errors if called right away while still requiring.
		end)

		isActorThread = true
	end)
end

local myVmId

-- We have to delay generating the id until called from a dependent, otherwise
-- testIsActorThread will error.
-- TODO: find a better and more predictable way to handle that.
-- TODO: test if there are other edge cases where ConnectParallel errors.
local function getOrGenerateVmId()
	if myVmId then
		return myVmId
	end

	if not _G.__MY_VM_ID then
		vmIdValue.Value += 1

		testIsActorThread()

		-- We use a GUID so VMs made in different security contexts or different
		-- sessions do not count as the same VM. We could *just* use a GUID, but
		-- knowing the VM "index" and total number of VMs is nice and easy to read.
		_G.__MY_VM_ID = string.format(
			"{VmId:%d%s%s %s}",
			vmIdValue.Value,
			isElevatedContext and " Elevated" or "",
			isActorThread and " Actor" or " Main",
			HttpService:GenerateGUID(false):upper()
		)
	end

	myVmId = _G.__MY_VM_ID

	return myVmId
end

local VmId = {}

function VmId.getMyVmId()
	return getOrGenerateVmId()
end

function VmId.getCurrentVmCount()
	return vmIdValue.Value
end

function VmId.isActorThread()
	-- Trigger isActorThread test first:
	getOrGenerateVmId()

	return isActorThread
end

function VmId.isMainThread()
	return not isActorThread
end

function VmId.isElevatedContext()
	return isElevatedContext
end

return VmId
