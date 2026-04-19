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
end)
