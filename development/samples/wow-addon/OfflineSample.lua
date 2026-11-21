local _, addon = ...
addon = addon or {}
function addon.square(value)
    assert(type(value) == "number", "number required")
    return value * value
end
