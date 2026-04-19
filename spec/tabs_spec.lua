local tabs = require("popper.tabs")

describe("open_or_switch()", function()
  after_each(function()
    vim.cmd("tabonly!")
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_loaded(buf) then
        vim.api.nvim_buf_delete(buf, { force = true })
      end
    end
  end)

  it("is an exported function", function()
    assert.is_function(tabs.open_or_switch)
  end)

  it("switches to existing tab when file is already open", function()
    local tmp = vim.fn.tempname()
    local f = io.open(tmp, "w")
    f:write("hello")
    f:close()

    vim.cmd("tabedit " .. tmp)
    local file_tab = vim.api.nvim_get_current_tabpage()
    vim.cmd("tabprev")

    tabs.open_or_switch(tmp)

    assert.equals(file_tab, vim.api.nvim_get_current_tabpage())
  end)

  it("opens file in a new tab when file is not already open", function()
    local tmp = vim.fn.tempname()
    local f = io.open(tmp, "w")
    f:write("world")
    f:close()

    local before_count = #vim.api.nvim_list_tabpages()

    tabs.open_or_switch(tmp)

    local after_count = #vim.api.nvim_list_tabpages()
    assert.equals(before_count + 1, after_count)

    local cur_buf = vim.api.nvim_win_get_buf(0)
    local buf_name = vim.fn.resolve(vim.api.nvim_buf_get_name(cur_buf))
    local expected = vim.fn.resolve(vim.fn.fnamemodify(tmp, ":p"))
    assert.equals(expected, buf_name)
  end)
end)