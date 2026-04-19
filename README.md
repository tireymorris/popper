# Popper

Neovim plugin that watches a directory for file changes and auto-opens/switches to those files in tabs. Respects `.gitignore` patterns.

## Setup

### lazy.nvim

```lua
{
  dir = "/path/to/popper",
  opts = {
    watch_dir = vim.loop.cwd(),
    poll_interval_ms = 1000,
    auto_start = false,
  },
}
```

### packer.nvim

```lua
use "/path/to/popper"
```

### Manual

Symlink into your Neovim runtime path:

```bash
ln -s /path/to/popper ~/.local/share/nvim/site/pack/plugins/start/popper
```

Then add to your config:

```lua
require("popper").setup()
```

## Configuration

```lua
require("popper").setup({
  watch_dir = vim.loop.cwd(),  -- directory to watch (default: cwd)
  poll_interval_ms = 1000,      -- polling interval in ms (default: 1000)
  auto_start = false,           -- auto-start on VimEnter (default: false)
})
```

## Commands

- `:PopperStart` — start watching for file changes
- `:PopperStop` — stop watching

## Testing

Requires [plenary.nvim](https://github.com/nvim-lua/plenary.nvim).

```bash
nvim --headless -u spec/minimal_init.lua -c "PlenaryBustedDirectory spec/ {minimal_init = 'spec/minimal_init.lua'}" +quit
```