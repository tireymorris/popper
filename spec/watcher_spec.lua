local watcher = require("popper.watcher")
local gitignore = require("popper.gitignore")

describe("watcher", function()
  local tmpdir

  before_each(function()
    tmpdir = vim.fn.tempname()
    vim.fn.mkdir(tmpdir, "p")
  end)

  after_each(function()
    watcher.stop_watch()
  end)

  it("calls on_change_callback when a file is created in a watched directory", function()
    local received_paths = {}
    local callback = function(path)
      table.insert(received_paths, path)
    end

    watcher.start_watch(tmpdir, {}, callback)
    vim.loop.sleep(100)

    local filepath = tmpdir .. "/test_file.lua"
    local f = io.open(filepath, "w")
    f:write("hello")
    f:close()

    local ok = vim.wait(2000, function()
      for _, p in ipairs(received_paths) do
        if p == filepath then return true end
      end
      return false
    end, 50)

    assert.is_true(ok, "expected callback for " .. filepath .. ", got: " .. vim.inspect(received_paths))
  end)
end)