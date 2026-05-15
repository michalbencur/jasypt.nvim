local config = require("jasypt.config")
local crypto = require("jasypt.crypto")

local M = {}

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
    return "ENC(" .. crypto.encrypt(text, get_password(password)) .. ")"
end

function M.decrypt_text(text, password)
    local encrypted = text:match("^ENC%((.*)%)$") or text
    return crypto.decrypt(encrypted, get_password(password))
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
