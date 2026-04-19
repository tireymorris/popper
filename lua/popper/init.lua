local M = {}

M._watcher = require("popper.watcher")
M._gitignore = require("popper.gitignore")
M._tabs = require("popper.tabs")

local config = {}

function M.setup(opts)
  opts = opts or {}
  config = {
    watch_dir = opts.watch_dir or vim.loop.cwd(),
    poll_interval_ms = opts.poll_interval_ms or 1000,
    auto_start = opts.auto_start or false,
  }
  return M
end

function M.start()
  local gitignore_path = config.watch_dir .. "/.gitignore"
  local patterns = M._gitignore.parse_gitignore(gitignore_path)
  M._watcher.start_watch(config.watch_dir, patterns, function(path)
    M._tabs.open_or_switch(path)
  end)
end

function M.stop()
  M._watcher.stop_watch()
end

return M
