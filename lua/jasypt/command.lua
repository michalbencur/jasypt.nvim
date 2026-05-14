local config = require("jasypt.config")

local M = {}

local SALT_SIZE = 16
local ITERATIONS = 1000
local KEY_SIZE = 32
local IV_SIZE = 16
local DERIVED_SIZE = KEY_SIZE + IV_SIZE

local function system(cmd, input, text)
    local result = vim.system(cmd, { stdin = input, text = text }):wait()
    if result.code ~= 0 then
        local err = result.stderr or result.stdout or "command failed"
        error(err:gsub("%s+$", ""))
    end

    return result.stdout
end

local function bytes_to_hex(bytes)
    local parts = {}
    for i = 1, #bytes do
        parts[i] = string.format("%02x", string.byte(bytes, i))
    end

    return table.concat(parts)
end

local function random_bytes(length)
    return system({ "openssl", "rand", tostring(length) }, nil, false)
end

local function derive_key_iv(password, salt)
    local output = system({
        "openssl",
        "kdf",
        "-binary",
        "-keylen",
        tostring(DERIVED_SIZE),
        "-kdfopt",
        "digest:SHA512",
        "-kdfopt",
        "pass:" .. password,
        "-kdfopt",
        "hexsalt:" .. bytes_to_hex(salt),
        "-kdfopt",
        "iter:" .. tostring(ITERATIONS),
        "PBKDF2",
    }, nil, false)

    return output:sub(1, KEY_SIZE), output:sub(KEY_SIZE + 1, KEY_SIZE + IV_SIZE + 1)
end

local function base64_encode(data)
    return system({ "openssl", "base64", "-A" }, data, false)
end

local function base64_decode(data)
    return system({ "openssl", "base64", "-A", "-d" }, data, true)
end

local function encrypt_raw(plaintext, password)
    local salt = random_bytes(SALT_SIZE)
    local key, iv = derive_key_iv(password, salt)
    local encrypted = system({
        "openssl",
        "enc",
        "-aes-256-cbc",
        "-K",
        bytes_to_hex(key),
        "-iv",
        bytes_to_hex(iv),
    }, salt .. plaintext, false)

    return base64_encode(salt .. encrypted)
end

local function decrypt_raw(ciphertext, password)
    local decoded = base64_decode(ciphertext)
    local salt = decoded:sub(1, SALT_SIZE)
    local encrypted = decoded:sub(SALT_SIZE + 1)
    local key, iv = derive_key_iv(password, salt)
    local decrypted = system({
        "openssl",
        "enc",
        "-d",
        "-aes-256-cbc",
        "-K",
        bytes_to_hex(key),
        "-iv",
        bytes_to_hex(iv),
    }, encrypted, false)

    return decrypted:sub(SALT_SIZE + 1)
end

local function get_password(password)
    local resolved = password or config.get().password
    if not resolved or resolved == "" then
        error("jasypt password is not configured")
    end

    return resolved
end

local function notify_error(err)
    vim.notify(err, vim.log.levels.ERROR, { title = "jasypt.nvim" })
end

local function set_lines(bufnr, start_line, end_line, replacement)
    vim.api.nvim_buf_set_lines(bufnr, start_line - 1, end_line, false, vim.split(replacement, "\n", { plain = true }))
end

local function get_visual_range()
    local start_pos = vim.fn.getpos("'<")
    local end_pos = vim.fn.getpos("'>")
    return math.min(start_pos[2], end_pos[2]), math.max(start_pos[2], end_pos[2])
end

local function transform_range(start_line, end_line, transform)
    local bufnr = vim.api.nvim_get_current_buf()
    local lines = vim.api.nvim_buf_get_lines(bufnr, start_line - 1, end_line, false)
    local text = table.concat(lines, "\n")
    local replacement = transform(text)
    set_lines(bufnr, start_line, end_line, replacement)
end

function M.encrypt_text(text, password)
    return "ENC(" .. encrypt_raw(text, get_password(password)) .. ")"
end

function M.decrypt_text(text, password)
    local encrypted = text:match("^ENC%((.*)%)$") or text
    return decrypt_raw(encrypted, get_password(password))
end

function M.encrypt_range(opts)
    local ok, err = pcall(transform_range, opts.line1, opts.line2, function(text)
        return M.encrypt_text(text)
    end)

    if not ok then
        notify_error(err)
    end
end

function M.decrypt_range(opts)
    local ok, err = pcall(transform_range, opts.line1, opts.line2, function(text)
        return M.decrypt_text(text)
    end)

    if not ok then
        notify_error(err)
    end
end

function M.encrypt_visual()
    local start_line, end_line = get_visual_range()
    M.encrypt_range({ line1 = start_line, line2 = end_line })
end

function M.decrypt_visual()
    local start_line, end_line = get_visual_range()
    M.decrypt_range({ line1 = start_line, line2 = end_line })
end

function M.setup()
    vim.api.nvim_create_user_command("JasyptEncrypt", function(opts)
        M.encrypt_range(opts)
    end, { range = true, desc = "Encrypt selected lines with Jasypt" })

    vim.api.nvim_create_user_command("JasyptDecrypt", function(opts)
        M.decrypt_range(opts)
    end, { range = true, desc = "Decrypt selected lines with Jasypt" })

    vim.keymap.set("x", "<Plug>(JasyptEncrypt)", function()
        local start_line, end_line = get_visual_range()
        M.encrypt_range({ line1 = start_line, line2 = end_line })
    end, { desc = "Encrypt visual selection with Jasypt" })

    vim.keymap.set("x", "<Plug>(JasyptDecrypt)", function()
        local start_line, end_line = get_visual_range()
        M.decrypt_range({ line1 = start_line, line2 = end_line })
    end, { desc = "Decrypt visual selection with Jasypt" })
end

return M
