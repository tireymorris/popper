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

  it("start() calls watcher.start_watch with watch_dir and gitignore patterns", function()
    local watch_dir = "/some/project"
    local patterns = { { pattern = "node_modules", negated = false, is_dir = true, is_recursive = false } }

    mock_gitignore.parse_gitignore = function(path)
      assert.equals(watch_dir .. "/.gitignore", path)
      return patterns
    end

    local called_with_dir, called_with_patterns
    mock_watcher.start_watch = function(dir, pats, cb)
      called_with_dir = dir
      called_with_patterns = pats
    end

    popper.setup({ watch_dir = watch_dir })
    popper.start()

    assert.equals(watch_dir, called_with_dir)
    assert.equals(patterns, called_with_patterns)
  end)
end)