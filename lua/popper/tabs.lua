local M = {}

function M.open_or_switch(file_path)
  local resolved_path = vim.fn.resolve(vim.fn.fnamemodify(file_path, ":p"))
  for _, tabpage in ipairs(vim.api.nvim_list_tabpages()) do
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tabpage)) do
      local buf = vim.api.nvim_win_get_buf(win)
      local name = vim.fn.resolve(vim.api.nvim_buf_get_name(buf))
      if name == resolved_path then
        vim.api.nvim_set_current_tabpage(tabpage)
        return
      end
    end
  end
  vim.cmd("tabedit " .. vim.fn.fnameescape(resolved_path))
end

return M