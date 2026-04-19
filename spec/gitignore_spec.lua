local gitignore = require("popper.gitignore")
local tmpdir = vim.fn.tempname()

describe("parse_gitignore()", function()
  it("reads a .gitignore file and returns parsed patterns", function()
    local file = tmpdir .. "_gitignore_1"
    local f = io.open(file, "w")
    f:write("node_modules/\n")
    f:write("*.log\n")
    f:close()

    local patterns = gitignore.parse_gitignore(file)
    assert.is_not_nil(patterns)
    assert.is_table(patterns)
    assert.equals(2, #patterns)
  end)

  it("converts directory pattern node_modules/ to a Lua pattern", function()
    local file = tmpdir .. "_gitignore_2"
    local f = io.open(file, "w")
    f:write("node_modules/\n")
    f:close()

    local patterns = gitignore.parse_gitignore(file)
    assert.equals(1, #patterns)
    local entry = patterns[1]
    assert.is_false(entry.negated)
    assert.is_true(entry.is_dir)

    -- Test via is_ignored
    assert.is_true(gitignore.is_ignored("src/node_modules/foo.js", patterns, "/project"))
    assert.is_true(gitignore.is_ignored("node_modules/foo.js", patterns, "/project"))
    assert.is_false(gitignore.is_ignored("node_modules_foo", patterns, "/project"))
  end)

  it("converts glob pattern *.log to a Lua pattern", function()
    local file = tmpdir .. "_gitignore_3"
    local f = io.open(file, "w")
    f:write("*.log\n")
    f:close()

    local patterns = gitignore.parse_gitignore(file)
    assert.equals(1, #patterns)
    local entry = patterns[1]
    assert.is_false(entry.negated)
    assert.is_false(entry.is_dir)

    -- Test via is_ignored
    assert.is_true(gitignore.is_ignored("debug.log", patterns, "/project"))
    assert.is_true(gitignore.is_ignored("src/debug.log", patterns, "/project"))
    assert.is_false(gitignore.is_ignored("debug.lua", patterns, "/project"))
  end)
end)

describe("is_ignored()", function()
  it("handles negation patterns", function()
    local file = tmpdir .. "_gitignore_4"
    local f = io.open(file, "w")
    f:write("*.log\n")
    f:write("!important.log\n")
    f:close()

    local patterns = gitignore.parse_gitignore(file)
    assert.equals(2, #patterns)
    assert.is_false(patterns[1].negated)
    assert.is_true(patterns[2].negated)

    -- Regular .log files should be ignored
    assert.is_true(gitignore.is_ignored("debug.log", patterns, "/project"))
    -- But important.log should not be ignored due to negation
    assert.is_false(gitignore.is_ignored("important.log", patterns, "/project"))
  end)

  it("returns false for paths that should not be ignored", function()
    local file = tmpdir .. "_gitignore_5"
    local f = io.open(file, "w")
    f:write("node_modules/\n")
    f:write("*.log\n")
    f:close()

    local patterns = gitignore.parse_gitignore(file)

    -- These paths should NOT be ignored
    assert.is_false(gitignore.is_ignored("src/main.lua", patterns, "/project"))
    assert.is_false(gitignore.is_ignored("src/app.js", patterns, "/project"))
    assert.is_false(gitignore.is_ignored("README.md", patterns, "/project"))
  end)
end)
