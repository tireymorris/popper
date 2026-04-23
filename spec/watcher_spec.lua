local watcher = require("popper.watcher")
local gitignore = require("popper.gitignore")

describe("watcher", function()
  local tmpdir
  local watch_opts = { poll_interval_ms = 50 }

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

    watcher.start_watch(tmpdir, {}, callback, watch_opts)
    vim.wait(150, function()
      return false
    end, 10)

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

    watcher.start_watch(tmpdir, patterns, callback, watch_opts)
    vim.wait(150, function()
      return false
    end, 10)

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

  it("watches files created in newly created directories", function()
    local received_paths = {}
    local callback = function(path)
      table.insert(received_paths, path)
    end

    watcher.start_watch(tmpdir, {}, callback, watch_opts)
    vim.wait(150, function()
      return false
    end, 10)

    local subdir = tmpdir .. "/new_subdir"
    vim.fn.mkdir(subdir, "p")

    local watched = vim.wait(2000, function()
      local nested_file = subdir .. "/nested.lua"
      local f = io.open(nested_file, "w")
      if f then
        f:write("print('hi')")
        f:close()
      end

      for _, p in ipairs(received_paths) do
        if p == nested_file then return true end
      end
      return false
    end, 100)

    assert.is_true(watched, "expected callback for file inside newly created directory, got: " .. vim.inspect(received_paths))
  end)

  it("detects files created in pre-existing deep directories even in large trees", function()
    for i = 1, 3000 do
      vim.fn.mkdir(tmpdir .. "/x" .. i, "p")
    end
    local deep_dir = tmpdir .. "/target/a/b/c"
    vim.fn.mkdir(deep_dir, "p")

    local received_paths = {}
    watcher.start_watch(tmpdir, {}, function(path)
      table.insert(received_paths, path)
    end, watch_opts)

    local target = deep_dir .. "/file.lua"
    vim.defer_fn(function()
      local f = io.open(target, "w")
      f:write("hello")
      f:close()
    end, 10)

    local ok = vim.wait(3000, function()
      for _, p in ipairs(received_paths) do
        if p == target then return true end
      end
      return false
    end, 50)

    assert.is_true(ok, "expected callback for deep file in large tree, got: " .. vim.inspect(received_paths))
  end)

  it("does not watch newly created gitignored directories", function()
    local received_paths = {}
    local callback = function(path)
      table.insert(received_paths, path)
    end

    local patterns = {
      { pattern = "node_modules", negated = false, is_dir = true, is_recursive = false },
    }

    watcher.start_watch(tmpdir, patterns, callback, watch_opts)
    vim.wait(150, function()
      return false
    end, 10)

    local ignored_dir = tmpdir .. "/node_modules"
    vim.fn.mkdir(ignored_dir, "p")

    local ignored_file = ignored_dir .. "/ignored.lua"
    local f = io.open(ignored_file, "w")
    f:write("print('ignored')")
    f:close()

    vim.wait(1000, function()
      return false
    end, 100)

    for _, p in ipairs(received_paths) do
      assert.is_not_true(p == ignored_file, "gitignored file in new directory should not trigger callback: " .. p)
    end
  end)

  it("starts directory scanning asynchronously", function()
    local nested_dir = tmpdir .. "/a/b/c"
    vim.fn.mkdir(nested_dir, "p")

    local original_fs_scandir = vim.loop.fs_scandir
    local scanned_paths = {}
    vim.loop.fs_scandir = function(path)
      table.insert(scanned_paths, path)
      return original_fs_scandir(path)
    end

    local ok, err = pcall(function()
      watcher.start_watch(tmpdir, {}, function() end, watch_opts)
    end)

    assert.is_true(ok, err)
    assert.are.same({}, scanned_paths)

    local scanned = vim.wait(2000, function()
      return vim.tbl_contains(scanned_paths, tmpdir)
    end, 20)

    vim.loop.fs_scandir = original_fs_scandir

    assert.is_true(scanned, "expected root directory to be scanned on the event loop")
  end)

  it("does not scan into gitignored directories", function()
    local ignored_dir = tmpdir .. "/node_modules"
    local nested_dir = ignored_dir .. "/pkg"
    vim.fn.mkdir(nested_dir, "p")

    local original_fs_scandir = vim.loop.fs_scandir
    local scanned_paths = {}
    vim.loop.fs_scandir = function(path)
      table.insert(scanned_paths, path)
      return original_fs_scandir(path)
    end

    local patterns = {
      { pattern = "node_modules", negated = false, is_dir = true, is_recursive = false },
    }

    local ok, err = pcall(function()
      watcher.start_watch(tmpdir, patterns, function() end, watch_opts)
    end)

    local scanned = vim.wait(2000, function()
      return vim.tbl_contains(scanned_paths, tmpdir)
    end, 20)

    vim.loop.fs_scandir = original_fs_scandir

    assert.is_true(ok, err)
    assert.is_true(scanned, "expected root directory to be scanned")
    assert.is_not_true(vim.tbl_contains(scanned_paths, ignored_dir), "ignored directory should not be scanned")
    assert.is_not_true(vim.tbl_contains(scanned_paths, nested_dir), "nested ignored directory should not be scanned")
  end)

  it("stop_watch prevents further callbacks", function()
    local received_paths = {}
    local callback = function(path)
      table.insert(received_paths, path)
    end

    watcher.start_watch(tmpdir, {}, callback, watch_opts)
    vim.wait(150, function()
      return false
    end, 10)

    local filepath = tmpdir .. "/before_stop.lua"
    local f = io.open(filepath, "w")
    f:write("before")
    f:close()

    local ok = vim.wait(2000, function()
      for _, p in ipairs(received_paths) do
        if p == filepath then return true end
      end
      return false
    end, 50)
    assert.is_true(ok, "expected callback before stop")

    watcher.stop_watch()

    local after_path = tmpdir .. "/after_stop.lua"
    local g = io.open(after_path, "w")
    g:write("after")
    g:close()

    vim.wait(500, function()
      return false
    end, 50)

    for _, p in ipairs(received_paths) do
      assert.is_not_true(p == after_path, "callback should not fire after stop_watch: " .. p)
    end
  end)
end)
