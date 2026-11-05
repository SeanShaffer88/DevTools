-- Original small trusted test harness, Lua 5.1-compatible. Not genuine game APIs.
local root = assert(arg[1], "addon directory required")
local callbacks = {}
local events = {}
function RegisterFixtureEvent(name, callback)
  assert(type(name) == "string" and type(callback) == "function", "bad fixture registration")
  callbacks[name] = callback
end
function EmitFixtureEvent(name, ...)
  assert(callbacks[name], "Missing fixture mock/event: " .. tostring(name))
  events[#events + 1] = name
  callbacks[name](...)
end
assert(loadfile(root .. "/main.lua"))()
EmitFixtureEvent("ADDON_LOADED", "SampleAddon")
assert(FixtureLoaded == true, "expected fixture event state")
print("mock event passed; this is not in-game API validation")
