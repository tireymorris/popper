local M = {}

M._watcher = require("popper.watcher")
M._gitignore = require("popper.gitignore")
M._tabs = require("popper.tabs")

local config = {}
local augroup = vim.api.nvim_create_augroup("Popper", { clear = false })

function M.setup(opts)
  opts = opts or {}
  config = {
    watch_dir = opts.watch_dir or vim.loop.cwd(),
    poll_interval_ms = opts.poll_interval_ms or 1000,
    auto_start = opts.auto_start or false,
  }

  vim.api.nvim_create_user_command("PopperStart", function()
    M.start()
  end, {})
  vim.api.nvim_create_user_command("PopperStop", function()
    M.stop()
  end, {})

  vim.api.nvim_clear_autocmds({ group = augroup })

  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = augroup,
    callback = function()
      M.stop()
    end,
    desc = "Stop Popper file watchers before Neovim exits",
  })

  if config.auto_start then
    vim.api.nvim_create_autocmd("VimEnter", {
      group = augroup,
      once = true,
      callback = function()
        M.start()
      end,
      desc = "Start Popper on VimEnter",
    })
  end

  return M
end

function M.start()
  local gitignore_path = config.watch_dir .. "/.gitignore"
  local patterns = M._gitignore.parse_gitignore(gitignore_path)
  M._watcher.start_watch(config.watch_dir, patterns, function(path)
    M._tabs.open_or_switch(path)
  end, {
    poll_interval_ms = config.poll_interval_ms,
  })
end

function M.stop()
  M._watcher.stop_watch()
end

return M
