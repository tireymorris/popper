local M = {}

function M.setup(config)
  config = config or {}
  config.watch_dir = config.watch_dir or vim.loop.cwd()
  config.poll_interval_ms = config.poll_interval_ms or 1000

  return {
    start = function() end,
    stop = function() end,
  }
end

return M
