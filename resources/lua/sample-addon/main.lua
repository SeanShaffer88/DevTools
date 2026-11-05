-- Original test-owned sample; mock registration supplied by event-harness.lua.
RegisterFixtureEvent("ADDON_LOADED", function(name)
  FixtureLoaded = name == "SampleAddon"
end)
