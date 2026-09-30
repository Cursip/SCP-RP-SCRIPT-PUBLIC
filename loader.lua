-- loader.lua - stable entry point, always loads the newest revision.
--
-- Why this is more involved than one HttpGet:
--   * raw.githubusercontent.com serves a cached copy for a few minutes after
--     a push, and a query-string stamp does NOT bypass that cache.
--   * the GitHub API is rate limited (60/h per IP) and lags after a push.
--   * a URL pinned to a commit SHA is immutable, so it is always fresh.
-- So: read the newest SHA from the commit atom feed (no rate limit, not
-- cached), then load the script pinned to that revision. The branch URL is
-- only a fallback for when GitHub is unreachable.
--
-- Usage (executor):
--   loadstring(game:HttpGet("https://raw.githubusercontent.com/Cursip/SCP-RP-SCRIPT-PUBLIC/main/loader.lua"))()
-- If this loader URL itself is cached, run it once pinned to a revision:
--   loadstring(game:HttpGet("https://raw.githubusercontent.com/Cursip/SCP-RP-SCRIPT-PUBLIC/<sha>/loader.lua"))()

local REPO = "Cursip/SCP-RP-SCRIPT-PUBLIC"
local BRANCH = "main"
local FILE = "silent_aim_esp_merged.lua"

local RAW = "https://raw.githubusercontent.com/" .. REPO .. "/"

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

-- 1) newest revision from the atom feed
local rev
local feed = httpGet("https://github.com/" .. REPO .. "/commits/" .. BRANCH .. ".atom")
if feed then
    rev = string.match(feed, "Grit::Commit/(%x+)")
end

-- 2) candidates: pinned revision first (always fresh), branch as fallback
local candidates = {}
if rev then
    table.insert(candidates, RAW .. rev .. "/" .. FILE)
end
table.insert(candidates, RAW .. BRANCH .. "/" .. FILE)
table.insert(candidates, RAW .. BRANCH .. "/" .. FILE .. "?t=" .. tostring(os.time()))

local source, pinned
for _, url in ipairs(candidates) do
    source = httpGet(url)
    if source then
        pinned = rev ~= nil and string.find(url, rev, 1, true) ~= nil
        break
    end
end

if not source then
    warn("[loader] download failed for " .. REPO .. " (" .. BRANCH .. ")")
    return
end

print(("[loader] revision %s | %d bytes | %s"):format(
    rev and rev:sub(1, 7) or (BRANCH .. " (feed unavailable)"),
    #source,
    pinned and "pinned, always fresh" or "branch fallback, may be a cached copy"
))

if not pinned then
    warn("[loader] could not read the commit feed, so a cached copy may be loaded")
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
