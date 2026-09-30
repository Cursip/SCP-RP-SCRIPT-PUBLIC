-- loader.lua - stable entry point, always loads the newest revision.
--
-- GitHub's raw CDN, and some executors' HttpGet proxies, keep serving stale
-- copies for a while. This loader works around that:
--   1. read the newest commit SHA from the GitHub API (not CDN cached),
--   2. read the expected file size for that revision from the contents API,
--   3. try several URLs - revision pinned first, branch with a unique stamp
--      second - and accept the first body whose size matches the API value.
-- If the API is unreachable, the stamped branch URL is used unverified.
--
-- Usage (executor):
--   loadstring(game:HttpGet("https://raw.githubusercontent.com/Cursip/SCP-RP-SCRIPT-PUBLIC/main/loader.lua"))()
-- If that URL is cached itself, add a stamp:
--   loadstring(game:HttpGet("https://raw.githubusercontent.com/Cursip/SCP-RP-SCRIPT-PUBLIC/main/loader.lua?t=" .. os.time()))()

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

local RAW = "https://raw.githubusercontent.com/" .. REPO .. "/"
local API = "https://api.github.com/repos/" .. REPO .. "/"
local stamp = tostring(os.time()) .. tostring(math.random(100000, 999999))

-- 1) newest commit SHA
local rev
local commitBody = httpGet(API .. "commits/" .. BRANCH)
if commitBody then
    rev = string.match(commitBody, '"sha"%s*:%s*"(%x+)"')
end

-- 2) expected size of that revision (used to detect a stale body)
local expected
local contentsBody = httpGet(API .. "contents/" .. FILE .. "?ref=" .. (rev or BRANCH))
if contentsBody then
    local size = string.match(contentsBody, '"size"%s*:%s*(%d+)')
    if size then expected = tonumber(size) end
end

-- 3) candidates: pinned revision first, then the branch with a unique stamp
local candidates = {}
if rev then
    table.insert(candidates, RAW .. rev .. "/" .. FILE .. "?t=" .. stamp)
end
table.insert(candidates, RAW .. BRANCH .. "/" .. FILE .. "?t=" .. stamp)
table.insert(candidates, RAW .. BRANCH .. "/" .. FILE)

local source, usedUrl, verified
for _, url in ipairs(candidates) do
    local body = httpGet(url)
    if body then
        if not expected or #body == expected then
            source, usedUrl, verified = body, url, expected ~= nil
            break
        end
        -- stale body: remember it and keep looking for the right size
        if not source then
            source, usedUrl, verified = body, url, false
        end
    end
end

if not source then
    warn("[loader] download failed for " .. REPO .. " (" .. BRANCH .. ")")
    return
end

print(("[loader] revision %s | %d bytes | %s"):format(
    rev and rev:sub(1, 7) or (BRANCH .. " (API unavailable)"),
    #source,
    expected and (verified and "size verified" or ("size MISMATCH, expected " .. expected)) or "unverified"
))

if expected and not verified then
    warn("[loader] served copy differs from revision " .. tostring(rev) .. " - a cache is interfering")
end

local chunk, err = loadstring(source)
if not chunk then
    warn("[loader] syntax error in downloaded script: " .. tostring(err))
    return
end

local ok, runErr = pcall(chunk)
if not ok then
    warn("[loader] script error: " .. tostring(runErr))
end
