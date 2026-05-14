if vim.g.loaded_jasypt == 1 then
    return
end

vim.g.loaded_jasypt = 1
require("jasypt.command").setup()
