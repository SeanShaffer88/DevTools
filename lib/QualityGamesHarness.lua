local root = arg[1]
local chained, now, current, frame = 0, 0, nil, nil
local original = function(message) chained = chained + 1; return "prior:" .. message end
geterrorhandler = function() return current end
seterrorhandler = function(handler) current = handler end
current = original
SlashCmdList = {}
GetBuildInfo = function() return "3.3.5", "12340", "synthetic", 30300 end
GetTime = function() now = now + 1; return now end
date = function() return "2026-11-03T00:00:00Z" end
GetCVar = function() return "0" end
GetAddOnCPUUsage = function() error("must not query disabled profiling") end
CreateFrame = function()
 frame = { events = {} }
 function frame:RegisterEvent(event) self.events[event] = true end
 function frame:SetScript(_, handler) self.handler = handler end
 function frame:UnregisterAllEvents() self.events = {} end
 return frame
end
assert(loadfile(root .. "/Fixture.lua"))()
assert(FixtureDiagnostics.client.source == "GetBuildInfo")
assert(FixtureDiagnostics.cpuProfiling.status == "Unavailable")
for i = 1, 200 do frame.handler(frame, "PLAYER_LOGIN"); assert(current(string.rep("x", 900)) == "prior:" .. string.rep("x", 900)) end
assert(chained == 200 and #FixtureDiagnostics.events == 64 and #FixtureDiagnostics.errors == 32 and #FixtureDiagnostics.timings == 64)
assert(#FixtureDiagnostics.errors[1].message == 512)
SlashCmdList.FixtureDIAGNOSTICS("disable")
assert(current == original and FixtureDiagnostics.errorHook == "Restored" and FixtureDiagnostics.diagnosticsState == "Disabled")
local samples = FixtureDiagnostics.counters.samples
SlashCmdList.FixtureDIAGNOSTICS("sample")
assert(FixtureDiagnostics.counters.samples == samples and next(frame.events) == nil)
assert(loadfile(root .. "/Fixture.lua"))()
local later = function() return "later" end
current = later
SlashCmdList.FixtureDIAGNOSTICS("disable")
assert(current == later and FixtureDiagnostics.errorHook == "PreservedLaterHandler")
current = function() error("prior failure") end
assert(loadfile(root .. "/Fixture.lua"))()
local ok, message = pcall(current, "error sample")
assert(not ok and string.find(message, "prior failure"))
SlashCmdList.FixtureDIAGNOSTICS("disable")
geterrorhandler, seterrorhandler, GetTime, GetBuildInfo, CreateFrame, GetCVar, GetAddOnCPUUsage, date = nil, nil, nil, nil, nil, nil, nil, nil
assert(loadfile(root .. "/Fixture.lua"))()
assert(FixtureDiagnostics.client.status == "Unavailable" and FixtureDiagnostics.cpuProfiling.status == "Unavailable")
assert(FixtureDiagnostics.timings[1].status == "Unavailable" and FixtureDiagnostics.timings[1].seconds == nil)
assert(FixtureDiagnostics.errorHook == "Unavailable" and FixtureDiagnostics.eventSource == "Unavailable")
assert(FixtureDiagnostics.timestamps.started == "Unavailable")
SlashCmdList.FixtureDIAGNOSTICS("disable")
print("Synthetic event dispatch, error chaining/restore/later handler, prior errors, sample caps and absent APIs passed")
