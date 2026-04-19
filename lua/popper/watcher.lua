local M = {}
local gitignore = require("popper.gitignore")

local handles = {}

local function scan_directories(dir, callback)
  local handle = vim.loop.fs_scandir(dir)
  if not handle then return end

  while true do
    local name, type = vim.loop.fs_scandir_next(handle)
    if not name then break end

    local full_path = dir .. "/" .. name
    if name:sub(1, 1) == "." then goto continue end
    if type == "directory" then
      callback(full_path)
      scan_directories(full_path, callback)
    end
    ::continue::
  end
end

function M.start_watch(dir, gitignore_patterns, on_change_callback)
  M.stop_watch()
  gitignore_patterns = gitignore_patterns or {}

  local function watch_dir(path)
    local handle = vim.loop.new_fs_event()
    handle:start(path, {}, function(err, filename, events)
      if err then return end
      if not filename then return end

      local absolute_path = path .. "/" .. filename

      if events and (events.change or events.rename) then
        if filename:sub(1, 1) == "." then return end
        if not gitignore.is_ignored(absolute_path, gitignore_patterns, dir) then
          vim.schedule(function()
            on_change_callback(absolute_path)
          end)
        end
      end
    end)
    table.insert(handles, handle)
  end

  watch_dir(dir)

  scan_directories(dir, function(subdir)
    if not gitignore.is_ignored(subdir, gitignore_patterns, dir) then
      watch_dir(subdir)
    end
  end)
end

function M.stop_watch()
  for _, handle in ipairs(handles) do
    handle:stop()
    handle:close()
  end
  handles = {}
end

return M