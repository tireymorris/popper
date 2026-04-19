local root = vim.fn.fnamemodify("./.repro", ":p")

for _, name in ipairs({ "config", "data", "state", "cache" }) do
  vim.env[("XDG_%s_HOME"):format(name:upper())] = root .. "/" .. name
end

vim.opt.rtp:prepend("~/.local/share/nvim/site/pack/packer/start/plenary.nvim")

require("plenary.busted")
