## **This module is a work-in-progress and has not been thoroughly tested!**

## **This module's name is not decided! Its current name is a placeholder.**

---

# Multithread
A module with utilities for multithreaded Lua on Roblox

Features:
* Utilities for running code under new actors
* Utilities for communicating between spawned actor code and the spawner / main VM
* Coroutine-based Event object which can be used while a VM is desynchronized
* Get a unique id for a VM, or get other properties of the current VM
* Pack arguments to safely handle holes / nil values

See [src/Multithread/init.lua](src/Multithread/init.lua) for documentation.