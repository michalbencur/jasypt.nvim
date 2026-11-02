# jasypt.nvim

Neovim plugin for encrypting and decrypting text with a Jasypt-compatible format:

- `PBEWITHHMACSHA512ANDAES_256`
- PBKDF2-SHA512
- 1000 iterations
- AES-256-CBC
- `ENC(...)` wrapper format

The plugin uses the `openssl` CLI, so `openssl` must be available on your system.

## Installation

### packer

```lua
vim.pack.add({ 'https://github.com/michalbencur/jasypt.nvim' })

require('jasypt').setup({
    password = vim.env.JASYPT_PASSWORD,
})
```

### lazy.nvim

```lua
{
    "michalbencur/jasypt.nvim",
    config = function()
        require("jasypt").setup({
            password = vim.env.JASYPT_ENCRYPTOR_PASSWORD,
        })
    end,
}
```

## Setup

```lua
require("jasypt").setup({
    password = vim.env.JASYPT_ENCRYPTOR_PASSWORD,
    previous_password = vim.env.JASYPT_PREVIOUS_PASSWORD,
})
```

Available options:

- `password`: primary password used for encryption and decryption
- `previous_password`: reserved config value for compatibility/migration workflows

## Commands

- `:JasyptEncrypt` encrypts the current line
- `:JasyptDecrypt` decrypts the current line
- `:'<,'>JasyptEncrypt` encrypts a selected line range
- `:'<,'>JasyptDecrypt` decrypts a selected line range

Encrypted text is written back as:

```text
ENC(base64-value)
```

# Visual Mode Mappings

The plugin defines `<Plug>` mappings you can bind yourself:

```lua
vim.keymap.set("x", "<leader>je", "<Plug>(JasyptEncrypt)")
vim.keymap.set("x", "<leader>jd", "<Plug>(JasyptDecrypt)")
```

## Notes

- Multi-line ranges are joined with newline characters before encryption.
- Decryption accepts either raw base64 ciphertext or wrapped `ENC(...)` values.
- If no password is configured, the plugin raises an error.
