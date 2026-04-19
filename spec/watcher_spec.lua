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

  it("does not call callback for gitignored files", function()
    local received_paths = {}
    local callback = function(path)
      table.insert(received_paths, path)
    end

    local patterns = gitignore.parse_gitignore("/dev/null")
    local extra = { pattern = "[^/]*%.log", negated = false, is_dir = false, is_recursive = false }
    table.insert(patterns, extra)

    watcher.start_watch(tmpdir, patterns, callback)
    vim.loop.sleep(100)

    local logpath = tmpdir .. "/debug.log"
    local f = io.open(logpath, "w")
    f:write("log content")
    f:close()

    local lua_path = tmpdir .. "/main.lua"
    local g = io.open(lua_path, "w")
    g:write("code")
    g:close()

    local ok = vim.wait(2000, function()
      for _, p in ipairs(received_paths) do
        if p == lua_path then return true end
      end
      return false
    end, 50)

    assert.is_true(ok, "expected callback for " .. lua_path .. ", got: " .. vim.inspect(received_paths))

    for _, p in ipairs(received_paths) do
      assert.is_not_true(p == logpath, "gitignored file should not trigger callback: " .. p)
    end
  end)
end)