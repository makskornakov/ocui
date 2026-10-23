-- install_wireless.lua -- installs ONLY the wireless glasses HUD of ocui (12 files)
-- from the makskornakov/ocui fork. Needs an Internet Card.
--
--   wget -f https://raw.githubusercontent.com/makskornakov/ocui/test-build/install_wireless.lua /tmp/install_wireless.lua
--   /tmp/install_wireless.lua            -- branch test-build
--   /tmp/install_wireless.lua <ref>      -- another branch, tag or commit
--
-- Library -> /lib/ocui, programs -> /usr/bin (wireless, ocpool). Settings in
-- /etc/ocui are never touched. Everything is downloaded first and written
-- only if every file arrived.

local component = require("component")
local filesystem = require("filesystem")

local REPO = "makskornakov/ocui"
local ref = (...) or "test-build"
local BASE = "https://raw.githubusercontent.com/" .. REPO .. "/" .. ref .. "/"

-- { path in the repo, install path }
local FILES = {
  { "ocui/config.lua",             "/lib/ocui/config.lua" },
  { "ocui/format.lua",             "/lib/ocui/format.lua" },
  { "ocui/hud.lua",                "/lib/ocui/hud.lua" },
  { "ocui/loop.lua",               "/lib/ocui/loop.lua" },
  { "ocui/lsc.lua",                "/lib/ocui/lsc.lua" },
  { "ocui/pool.lua",               "/lib/ocui/pool.lua" },
  { "ocui/storage.lua",            "/lib/ocui/storage.lua" },
  { "ocui/util.lua",               "/lib/ocui/util.lua" },
  { "ocui/apps/wireless.lua",      "/lib/ocui/apps/wireless.lua" },
  { "ocui/services/energy.lua",    "/lib/ocui/services/energy.lua" },
  { "apps/ocpool.lua",             "/usr/bin/ocpool.lua" },
  { "apps/wireless.lua",           "/usr/bin/wireless.lua" },
}

local function fail(msg)
  io.stderr:write("install: " .. msg .. "\n")
  os.exit(1)
end

if not component.isAvailable("internet") then
  fail("this needs an Internet Card")
end
local internet = require("internet")

local function fetch(url)
  local ok, handle = pcall(internet.request, url, nil, { ["user-agent"] = "ocui-install/OpenComputers" })
  if not ok or not handle then return nil, tostring(handle) end
  local chunks = {}
  local readOk, err = pcall(function()
    for chunk in handle do chunks[#chunks + 1] = chunk end
  end)
  if not readOk then return nil, tostring(err) end
  if handle.response then
    local okResp, code, message = pcall(handle.response)
    if okResp and type(code) == "number" and code ~= 200 then
      return nil, string.format("HTTP %d %s", code, tostring(message or ""))
    end
  end
  return table.concat(chunks)
end

-- 1. download everything
print(string.format("ocui: downloading %d files from %s (%s)", #FILES, REPO, ref))
local contents = {}
for i, f in ipairs(FILES) do
  io.write(string.format("  [%2d/%d] %s ... ", i, #FILES, f[1]))
  local body, err = fetch(BASE .. f[1])
  if not body then
    print("FAILED")
    fail(f[1] .. ": " .. tostring(err) .. "\nnothing was changed")
  end
  if #body == 0 then
    print("FAILED")
    fail(f[1] .. ": empty file\nnothing was changed")
  end
  contents[i] = body
  print(string.format("%d bytes", #body))
end

-- 2. write
for i, f in ipairs(FILES) do
  local dir = filesystem.path(f[2])
  if not filesystem.exists(dir) then
    local ok, err = filesystem.makeDirectory(dir)
    if not ok then fail("cannot create " .. dir .. ": " .. tostring(err)) end
  end
  local out, err = io.open(f[2], "w")
  if not out then fail("cannot write " .. f[2] .. ": " .. tostring(err)) end
  out:write(contents[i])
  out:close()
end

-- 3. drop cached modules so the next run loads the new code (OpenOS keeps
-- required libraries in memory between programs)
for name in pairs(package.loaded) do
  if name == "ocui" or name:match("^ocui%.") then
    package.loaded[name] = nil
  end
end

print("ocui: installed to /lib/ocui and /usr/bin")
print("Run: wireless            (foreground: 1..6 / w = bar period, q = quit)")
print("     ocpool -b wireless  (background; stop with: ocpool quit)")
