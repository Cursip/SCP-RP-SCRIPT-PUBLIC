-- loader.lua - stable entry point, always loads the newest revision.
--
-- GitHub's raw CDN (and some executors cache HttpGet responses) can serve an
-- outdated copy for a few minutes. This loader avoids that:
--   1. read the current commit SHA from the GitHub API (never cached),
--   2. fetch the script pinned to that exact revision,
--   3. append a unique stamp so no cache can answer the request.
-- If the API is unreachable it falls back to the branch URL plus a stamp.
--
-- Usage (executor):
--   loadstring(game:HttpGet("https://raw.githubusercontent.com/Cursip/SCP-RP-SCRIPT-PUBLIC/main/loader.lua"))()

local REPO = "Cursip/SCP-RP-SCRIPT-PUBLIC"
local BRANCH = "main"
local FILE = "silent_aim_esp_merged.lua"

local function httpGet(url)
    -- some executors accept a second "no cache" argument, some do not
    local ok, body = pcall(function() return game:HttpGet(url, true) end)
    if not (ok and type(body) == "string" and #body > 100) then
        ok, body = pcall(function() return game:HttpGet(url) end)
    end
    if ok and type(body) == "string" and #body > 100 then
        return body
    end
    return nil
end

local stamp = tostring(os.time()) .. tostring(math.random(100000, 999999))

-- 1) newest commit SHA from the API
local rev
local apiBody = httpGet("https://api.github.com/repos/" .. REPO .. "/commits/" .. BRANCH)
if apiBody then
    rev = string.match(apiBody, '"sha"%s*:%s*"(%x+)"')
end

-- 2) candidates: pinned revision first, branch as fallback
local candidates = {}
if rev then
    table.insert(candidates, "https://raw.githubusercontent.com/" .. REPO .. "/" .. rev .. "/" .. FILE .. "?t=" .. stamp)
end
table.insert(candidates, "https://raw.githubusercontent.com/" .. REPO .. "/" .. BRANCH .. "/" .. FILE .. "?t=" .. stamp)

local source
for _, url in ipairs(candidates) do
    source = httpGet(url)
    if source then break end
end

if not source then
    warn("[loader] download failed for " .. REPO .. " (" .. BRANCH .. ")")
    return
end

print(("[loader] revision %s | %d bytes"):format(rev and rev:sub(1, 7) or (BRANCH .. " (API unavailable)"), #source))

local chunk, err = loadstring(source)
if not chunk then
    warn("[loader] syntax error in downloaded script: " .. tostring(err))
    return
end

local ok, runErr = pcall(chunk)
if not ok then
    warn("[loader] script error: " .. tostring(runErr))
end
