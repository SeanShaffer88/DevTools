-- Original bounded diagnostics, Lua 5.1. Author: Malikor.
local addonName = "__NAME__"
local function bounded(value)
    if type(value) ~= "string" then return "Unavailable" end
    return string.sub(value, 1, 512)
end
local function stamp()
    if type(date) == "function" then
        local ok, value = pcall(date, "!%Y-%m-%dT%H:%M:%SZ")
        if ok and type(value) == "string" then return bounded(value) end
    end
    return "Unavailable"
end
local function finite(value)
    return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end
local data = {
    schemaVersion = 1, interfaceVersion = __INTERFACE__,
    source = { profile = "__PROFILE__", generator = "DevTools.New-WowDiagnosticsAddon/1" },
    client = { status = "Unavailable" }, timestamps = { started = stamp() },
    counters = { events = 0, errors = 0, samples = 0 },
    events = {}, errors = {}, timings = {},
    diagnosticsState = "Enabled", cpuProfiling = { status = "Unavailable" }
}
_G[addonName .. "Diagnostics"] = data
if type(GetBuildInfo) == "function" then
    local ok, version, build, buildDate, interface = pcall(GetBuildInfo)
    if ok then
        data.client = { status = "Observed", version = bounded(version), build = bounded(build), buildDate = bounded(buildDate), source = "GetBuildInfo" }
        if finite(interface) then data.client.observedInterface = interface end
    end
end
local function count(key)
    data.counters[key] = math.min(data.counters[key] + 1, 1000000000)
end
local function append(list, value, maximum)
    if #list >= maximum then table.remove(list, 1) end
    list[#list + 1] = value
end
local enabled, busy = true, false
local previous, ownHandler, frame
local function sample()
    if not enabled then return end
    count("samples")
    local entry = { source = "GetTime", status = "Unavailable" }
    if type(GetTime) == "function" then
        local ok, value = pcall(GetTime)
        if ok and finite(value) and value >= 0 then entry.status = "Observed"; entry.seconds = value end
    end
    append(data.timings, entry, 64)
    data.cpuProfiling = { status = "Unavailable" }
    if type(GetCVar) == "function" and type(GetAddOnCPUUsage) == "function" then
        local ok, active = pcall(GetCVar, "scriptProfile")
        if ok and active == "1" then
            local success, value = pcall(GetAddOnCPUUsage, addonName)
            if success and finite(value) and value >= 0 then
                data.cpuProfiling = { status = "Observed", milliseconds = value, source = "GetAddOnCPUUsage" }
            end
        end
    end
    data.timestamps.lastSample = stamp()
end
if type(geterrorhandler) == "function" and type(seterrorhandler) == "function" then
    local ok, handler = pcall(geterrorhandler)
    if ok and type(handler) == "function" then
        previous = handler
        ownHandler = function(message)
            if not busy then
                busy = true
                if enabled then
                    count("errors")
                    append(data.errors, { message = bounded(message), timestamp = stamp() }, 32)
                end
                busy = false
                -- Keep busy during the prior handler so reentrant errors are not logged repeatedly.
                busy = true
                local success, result = pcall(previous, message)
                busy = false
                if not success then error(result, 0) end
                return result
            end
            -- Reentrant invocation must not call the same handler recursively forever.
            error(message, 0)
        end
        local installed = pcall(seterrorhandler, ownHandler)
        data.errorHook = installed and "Installed" or "Unavailable"
    else data.errorHook = "Unavailable" end
else data.errorHook = "Unavailable" end
local function disable()
    enabled = false
    data.diagnosticsState = "Disabled"
    data.timestamps.disabled = stamp()
    if frame then frame:UnregisterAllEvents() end
    if ownHandler and type(geterrorhandler) == "function" and type(seterrorhandler) == "function" then
        local ok, current = pcall(geterrorhandler)
        if ok and current == ownHandler then
            local restored = pcall(seterrorhandler, previous)
            data.errorHook = restored and "Restored" or "RestoreFailed"
        else data.errorHook = "PreservedLaterHandler" end
    end
end
if type(CreateFrame) == "function" then
    local ok, value = pcall(CreateFrame, "Frame")
    if ok and value and type(value.RegisterEvent) == "function" and type(value.SetScript) == "function" and type(value.UnregisterAllEvents) == "function" then
        frame = value
        frame:SetScript("OnEvent", function(_, event)
            if not enabled then return end
            count("events")
            append(data.events, { name = bounded(event), timestamp = stamp() }, 64)
            sample()
        end)
        for _, event in ipairs({"ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD"}) do pcall(frame.RegisterEvent, frame, event) end
        data.eventSource = "CreateFrame.OnEvent"
    else data.eventSource = "Unavailable" end
else data.eventSource = "Unavailable" end
local function command(text)
    local action = string.lower(type(text) == "string" and text or "status")
    if action == "disable" then disable() elseif action == "sample" then sample() end
    if type(print) == "function" then print(addonName .. " Diagnostics: " .. data.diagnosticsState .. "; CPU Profiling: " .. data.cpuProfiling.status) end
end
if type(SlashCmdList) == "table" then
    _G["SLASH___NAME__DIAGNOSTICS1"] = "/" .. string.lower(addonName)
    SlashCmdList["__NAME__DIAGNOSTICS"] = command
end
sample()
