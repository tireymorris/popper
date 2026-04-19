local popper = require("popper")
popper.setup()

vim.api.nvim_create_user_command("PopperStart", function()
  popper.start()
end, {})

vim.api.nvim_create_user_command("PopperStop", function()
  popper.stop()
end, {})
