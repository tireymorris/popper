local M = {}
local gitignore = require("popper.gitignore")

local timer = nil
local scan_generation = 0
local known_files = {}
local scan_in_progress = false
local rescan_requested = false

local function file_fingerprint(stat)
  local mtime = stat.mtime or {}
  return table.concat({
    stat.size or 0,
    mtime.sec or 0,
    mtime.nsec or 0,
  }, ":")
end

local function scan_files_async(dir, on_file, should_descend, on_done, generation)
  local queue = { dir }
  local queue_index = 1
  local batch_size = 512

  local function step()
    if generation ~= scan_generation then return end

    local processed = 0
    while queue_index <= #queue and processed < batch_size do
      if generation ~= scan_generation then return end

      local current_dir = queue[queue_index]
      queue_index = queue_index + 1
      processed = processed + 1

      local handle = vim.loop.fs_scandir(current_dir)
      if handle then
        while true do
          if generation ~= scan_generation then return end

          local name, type = vim.loop.fs_scandir_next(handle)
          if not name then break end
          if name:sub(1, 1) == "." then goto continue end

          local full_path = current_dir .. "/" .. name
          if type == "directory" then
            local descend = true
            if should_descend then
              descend = should_descend(full_path)
            end
            if descend then
              queue[#queue + 1] = full_path
            end
          elseif type == "file" then
            on_file(full_path)
          end

          ::continue::
        end
      end
    end

    if generation ~= scan_generation then return end
    if queue_index <= #queue then
      vim.schedule(step)
    else
      on_done()
    end
  end

  vim.schedule(step)
end

local function stop_timer()
  if not timer then return end
  pcall(function()
    timer:stop()
  end)
  pcall(function()
    timer:close()
  end)
  timer = nil
end

function M.start_watch(dir, gitignore_patterns, on_change_callback, opts)
  M.stop_watch()

  gitignore_patterns = gitignore_patterns or {}
  opts = opts or {}

  scan_generation = scan_generation + 1
  local generation = scan_generation
  local poll_interval_ms = opts.poll_interval_ms or 1000
  local baseline_complete = false

  local function should_watch(path)
    return not gitignore.is_ignored(path, gitignore_patterns, dir)
  end

  local function schedule_scan(run_scan)
    if generation ~= scan_generation then return end
    stop_timer()
    timer = vim.loop.new_timer()
    timer:start(poll_interval_ms, 0, vim.schedule_wrap(function()
      run_scan()
    end))
  end

  local function run_scan()
    if generation ~= scan_generation then return end
    if scan_in_progress then
      rescan_requested = true
      return
    end

    scan_in_progress = true
    local next_known_files = {}

    scan_files_async(dir, function(path)
      if generation ~= scan_generation then return end
      if not should_watch(path) then return end

      local stat = vim.loop.fs_stat(path)
      if not stat or stat.type ~= "file" then return end

      local fingerprint = file_fingerprint(stat)
      next_known_files[path] = fingerprint

      local previous = known_files[path]
      if baseline_complete and previous ~= fingerprint then
        vim.schedule(function()
          if generation ~= scan_generation then return end
          on_change_callback(path)
        end)
      end
    end, should_watch, function()
      if generation ~= scan_generation then return end

      known_files = next_known_files
      scan_in_progress = false

      if not baseline_complete then
        baseline_complete = true
      end

      if rescan_requested then
        rescan_requested = false
        vim.schedule(run_scan)
        return
      end

      schedule_scan(run_scan)
    end, generation)
  end

  known_files = {}
  scan_in_progress = false
  rescan_requested = false
  run_scan()
end

function M.stop_watch()
  scan_generation = scan_generation + 1
  stop_timer()
  known_files = {}
  scan_in_progress = false
  rescan_requested = false
end

return M
