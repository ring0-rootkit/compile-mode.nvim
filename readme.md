# Compile-Mode

My own implementation of Emac's Compilation Mode in Neovim.
This implementation is based on the one made by [libzfran's](https://github.com/lbzfran)

## Functionality

Contains 3 functions:

`:Compile [args]`

Calls a temporary buffer that executes the arguments its given.
If no args is provided you will get nice prompt.

`:Recompile`

Re-executes the last arguments passed to the Compile command.

`:ToggleCompileSplit`

By default, the window of the temporary buffer spawns vertically.
Running this will toggle it between horizontal and vertical window.

In compilation buffer <file>:<line>:<character> pattern is highlighted
when you hover your cursor over it and press enter, the <file> will be oppened
and you cursor will be placed on the character referenced by this pattern.

> 📝 *Note:* if you have multiple buffers oppened in split the file will be oppened in the first 
not compilation-mode buffer it will find. If you have only one buffer oppened the new one
will be created and placed in vertical split.

## Installation

Simply add using your favorite package manager:

```lua
-- lazy.nvim
return {
    "ring0-rootkit/compile-mode.nvim",
    config function()
        local compile = require("compile-mode")
        compile.setup({
            -- DEFAULT; no need to include these.
            vertical_split = true,
            save_args = true,
        })
    end,
}
```
