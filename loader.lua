-- loader.lua - stabiler Einstiegspunkt: laedt immer die aktuelle Version
-- aus diesem Repository. Im Executor einfach diese Datei ausfuehren:
--   loadstring(game:HttpGet("https://raw.githubusercontent.com/Cursip/SCP-RP-SCRIPT-PUBLIC/main/loader.lua"))()
-- Cursip/SCP-RP-SCRIPT-PUBLIC unten eintragen.

local RAW = "https://raw.githubusercontent.com/Cursip/SCP-RP-SCRIPT-PUBLIC/main/silent_aim_esp_merged.lua"

local ok, err = pcall(function()
    loadstring(game:HttpGet(RAW))()
end)

if not ok then
    warn("[loader] " .. RAW .. " konnte nicht geladen werden: " .. tostring(err))
end
