local popper = require("popper")

describe("integration: start() wiring", function()
  local mock_watcher
  local mock_gitignore
  local mock_tabs

  before_each(function()
    mock_watcher = {
      start_watch = function() end,
      stop_watch = function() end,
    }
    mock_gitignore = {
      parse_gitignore = function()
        return {}
      end,
    }
    mock_tabs = {
      open_or_switch = function() end,
    }

    popper._watcher = mock_watcher
    popper._gitignore = mock_gitignore
    popper._tabs = mock_tabs
  end)

  after_each(function()
    popper.stop()
    popper._watcher = require("popper.watcher")
    popper._gitignore = require("popper.gitignore")
    popper._tabs = require("popper.tabs")
  end)

  it("start() calls watcher.start_watch with watch_dir, gitignore patterns, and poll interval", function()
    local watch_dir = "/some/project"
    local patterns = { { pattern = "node_modules", negated = false, is_dir = true, is_recursive = false } }

    mock_gitignore.parse_gitignore = function(path)
      assert.equals(watch_dir .. "/.gitignore", path)
      return patterns
    end

    local called_with_dir, called_with_patterns, called_with_opts
    mock_watcher.start_watch = function(dir, pats, cb, opts)
      called_with_dir = dir
      called_with_patterns = pats
      called_with_opts = opts
    end

    popper.setup({ watch_dir = watch_dir, poll_interval_ms = 250 })
    popper.start()

    assert.equals(watch_dir, called_with_dir)
    assert.equals(patterns, called_with_patterns)
    assert.are.same({ poll_interval_ms = 250 }, called_with_opts)
  end)

  it("change callback from start_watch invokes tabs.open_or_switch", function()
    local saved_callback
    mock_watcher.start_watch = function(dir, pats, cb)
      saved_callback = cb
    end

    local received_path
    mock_tabs.open_or_switch = function(path)
      received_path = path
    end

    popper.setup({ watch_dir = "/project" })
    popper.start()

    saved_callback("/project/src/main.lua")

    assert.equals("/project/src/main.lua", received_path)
  end)

  it("stop() calls watcher.stop_watch", function()
    local stop_called = false
    mock_watcher.stop_watch = function()
      stop_called = true
    end

    popper.setup({ watch_dir = "/project" })
    popper.start()
    popper.stop()

    assert.is_true(stop_called)
  end)
end)

describe("integration: user commands", function()
  it("setup can be called repeatedly without duplicating command errors", function()
    local ok, err = pcall(function()
      popper.setup({ watch_dir = "/project" })
      popper.setup({ watch_dir = "/project" })
    end)

    assert.is_true(ok, "repeated setup errored: " .. tostring(err))
  end)

  it(":PopperStart calls require('popper').start() without error", function()
    local popper = require("popper")
    local started = false
    local orig_start = popper.start
    popper.start = function()
      started = true
    end

    local ok, err = pcall(vim.cmd, "PopperStart")

    popper.start = orig_start
    assert.is_true(ok, "PopperStart errored: " .. tostring(err))
    assert.is_true(started)
  end)

  it(":PopperStop calls require('popper').stop() without error", function()
    local popper = require("popper")
    local stopped = false
    local orig_stop = popper.stop
    popper.stop = function()
      stopped = true
    end

    local ok, err = pcall(vim.cmd, "PopperStop")

    popper.stop = orig_stop
    assert.is_true(ok, "PopperStop errored: " .. tostring(err))
    assert.is_true(stopped)
  end)
end)

describe("integration: autocmd lifecycle", function()
  it("setup always registers a VimLeavePre autocmd that stops watchers", function()
    local popper = require("popper")
    local stopped = false
    local orig_stop = popper.stop

    popper.stop = function()
      stopped = true
    end

    popper.setup({ watch_dir = "/auto/test" })
    vim.api.nvim_exec_autocmds("VimLeavePre", {})

    popper.stop = orig_stop

    assert.is_true(stopped)
  end)

  it("setup with auto_start=true registers a VimEnter autocmd", function()
    local popper = require("popper")
    popper._watcher = {
      start_watch = function() end,
      stop_watch = function() end,
    }
    popper._gitignore = {
      parse_gitignore = function() return {} end,
    }
    popper._tabs = {
      open_or_switch = function() end,
    }

    popper.setup({ watch_dir = "/auto/test", auto_start = true })

    local autocmds = vim.api.nvim_get_autocmds({ event = "VimEnter", group = "Popper" })

    popper._watcher = require("popper.watcher")
    popper._gitignore = require("popper.gitignore")
    popper._tabs = require("popper.tabs")

    assert.is_true(#autocmds > 0, "expected at least one Popper VimEnter autocmd")
  end)
end)
