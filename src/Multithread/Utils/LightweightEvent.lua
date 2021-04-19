local resumeWithErrorHandling = require(script.Parent.resumeWithErrorHandling)
local fastSpawn = require(script.Parent.fastSpawn)

local Connection = {}
Connection.__mode = "v"
-- __mode v prevents this connection from keeping the event around. If nothing
-- else refers to the event, then it can't be fired anymore, and we are
-- in-effect disconnected. also, this mirrors the behavior of built-in events!
-- when they're garbage collected, the connections Connected property becomes
-- false!

function Connection.new(parent)
	return setmetatable({ parent }, Connection)
end

function Connection:disconnect()
	if not self[1] then
		return
	end

	for _, callbacks in ipairs(self[1]) do
		callbacks[self] = nil
	end

	self[1] = nil
end

function Connection:__index(key)
	if key == "connected" or key == "Connected" then
		return self[1] and self[1][1] and self[1][1][self] and true or false
	elseif key == "disconnect" or key == "Disconnect" then
		return Connection.disconnect
	end
end

local Event = {}
Event.__index = Event

function Event.new()
	local self = {}
	setmetatable(self, Event)

	self._callbacks = {}
	self._callbacksStack = {
		self._callbacks,
	}

	self._requiresCopyOnWriteStackHeight = 0

	return self
end

function Event:_copyOnWriteIfRequired()
	if self._requiresCopyOnWriteStackHeight == 0 then
		return
	end
	self._requiresCopyOnWriteStackHeight = 0

	local newCallbacks = {}
	for key, value in pairs(self._callbacks) do
		newCallbacks[key] = value
	end

	self._callbacks = newCallbacks
	table.insert(self._callbacksStack, 1, newCallbacks)
end

function Event:connect(callback)
	assert(self._callbacks, "Event has been destroyed")
	self:_copyOnWriteIfRequired()

	local connection = Connection.new(self._callbacksStack)
	self._callbacks[connection] = callback
	return connection
end

Event.Connect = Event.connect

function Event:wait()
	assert(self._callbacks, "Event has been destroyed")
	local coroutineToResume = coroutine.running()
	local eventArgs
	local eventArgsLength
	local connection
	connection = self:connect(function(...)
		eventArgs = { ... }
		eventArgsLength = select("#", ...)

		connection:disconnect()
		resumeWithErrorHandling(coroutineToResume)
	end)

	coroutine.yield()
	return unpack(eventArgs, 1, eventArgsLength)
end

Event.Wait = Event.wait

function Event:fire(...)
	local callbacks = self._callbacks
	assert(callbacks, "Event has been destroyed")

	self._requiresCopyOnWriteStackHeight += 1

	for _, callback in pairs(callbacks) do
		fastSpawn(callback, ...)
	end

	if not self._callbacks then
		-- Destroyed during fire
		return
	end

	if #self._callbacksStack > 1 and self._callbacksStack[#self._callbacksStack] == callbacks then
		-- Connection added during fire
		table.remove(self._callbacksStack)
	end

	if self._requiresCopyOnWriteStackHeight ~= 0 then
		self._requiresCopyOnWriteStackHeight -= 1
	end
end

Event.Fire = Event.fire

function Event:destroy()
	table.clear(self._callbacks) -- instantly mark any events as disconnected
	self._callbacks = nil

	table.clear(self._callbacksStack)
	self._callbacksStack = nil
end

Event.Destroy = Event.destroy

return Event
