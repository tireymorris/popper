local M = {}
local gitignore = require("popper.gitignore")

local handles = {}
local watched_paths = {}
local scan_generation = 0

local function scan_directories_async(dir, callback, should_descend)
  local queue = { dir }
  local queue_index = 1
  local generation = scan_generation
  local batch_size = 64

  local function step()
    if generation ~= scan_generation then return end

    local processed = 0
    while queue_index <= #queue and processed < batch_size do
      local current_dir = queue[queue_index]
      queue_index = queue_index + 1
      processed = processed + 1

      local handle = vim.loop.fs_scandir(current_dir)
      if handle then
        while true do
          local name, type = vim.loop.fs_scandir_next(handle)
          if not name then break end

          local full_path = current_dir .. "/" .. name
          if name:sub(1, 1) == "." then goto continue end
          if type == "directory" then
            local descend = true
            if should_descend then
              descend = should_descend(full_path)
            end

            if descend then
              callback(full_path)
              queue[#queue + 1] = full_path
            end
          end
          ::continue::
        end
      end
    end

    if generation ~= scan_generation then return end
    if queue_index <= #queue then
      vim.schedule(step)
    end
  end

  vim.schedule(step)
end

function M.start_watch(dir, gitignore_patterns, on_change_callback)
  M.stop_watch()
  gitignore_patterns = gitignore_patterns or {}
  scan_generation = scan_generation + 1

  local function should_watch(path)
    return not gitignore.is_ignored(path, gitignore_patterns, dir)
  end

  local function watch_dir(path)
    if watched_paths[path] then return end
    watched_paths[path] = true

    local handle = vim.loop.new_fs_event()
    handle:start(path, {}, function(err, filename, events)
      if err then return end
      if not filename then return end
      if filename:sub(1, 1) == "." then return end
      if not (events and (events.change or events.rename)) then return end

      local absolute_path = path .. "/" .. filename
      if not should_watch(absolute_path) then return end

      local stat = vim.loop.fs_stat(absolute_path)
      if stat and stat.type == "directory" then
        watch_dir(absolute_path)
        scan_directories_async(absolute_path, watch_dir, should_watch)
        return
      end

      vim.schedule(function()
        on_change_callback(absolute_path)
      end)
    end)
    table.insert(handles, handle)
  end

  watch_dir(dir)

  scan_directories_async(dir, watch_dir, should_watch)
end

function M.stop_watch()
  scan_generation = scan_generation + 1

  for _, handle in ipairs(handles) do
    handle:stop()
    handle:close()
  end
  handles = {}
  watched_paths = {}
end

return M