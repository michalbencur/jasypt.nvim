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

local function get_visual_range()
    -- local start_pos = vim.fn.getpos("'<")
    -- local end_pos = vim.fn.getpos("'>")
    local start_pos = vim.fn.getpos("'.")
    local end_pos = vim.fn.getpos("'v")

    local start_line = start_pos[2]
    local start_col = start_pos[3]
    local end_line = end_pos[2]
    local end_col = end_pos[3]

    if start_line > end_line or (start_line == end_line and start_col > end_col) then
        start_line, end_line = end_line, start_line
        start_col, end_col = end_col, start_col
    end

    return start_line, start_col, end_line, end_col
end

local function has_visual_selection()
    local bufnr = vim.api.nvim_get_current_buf()
    local mode = vim.fn.mode(bufnr)
    return mode == "v" or mode == "V" or mode == "\22"
end

local function get_line_end_col(bufnr, line)
    return #vim.api.nvim_buf_get_lines(bufnr, line - 1, line, false)[1]
end

local function transform_range(start_line, start_col, end_line, end_col, transform)
    local bufnr = vim.api.nvim_get_current_buf()
    local text = table.concat(vim.api.nvim_buf_get_text(bufnr, start_line - 1, start_col - 1, end_line - 1, end_col, {}), "\n")
    local replacement = transform(text)
    vim.api.nvim_buf_set_text(bufnr, start_line - 1, start_col - 1, end_line - 1, end_col, vim.split(replacement, "\n", { plain = true }))
end

function M.encrypt_text(text, password)
    return "ENC(" .. crypto.encrypt(text, get_password(password)) .. ")"
end

function M.decrypt_text(text, password)
    local encrypted = text:match("^ENC%((.*)%)$") or text
    return crypto.decrypt(encrypted, get_password(password))
end

function M.encrypt_range(opts)
    local start_col = opts.col1 or 1
    local end_col = opts.col2 or get_line_end_col(0, opts.line2)
    local ok, err = pcall(transform_range, opts.line1, start_col, opts.line2, end_col, function(text)
        return M.encrypt_text(text)
    end)

    if not ok then
        notify_error(err)
    end
end

function M.decrypt_range(opts)
    local start_col = opts.col1 or 1
    local end_col = opts.col2 or get_line_end_col(0, opts.line2)
    local ok, err = pcall(transform_range, opts.line1, start_col, opts.line2, end_col, function(text)
        return M.decrypt_text(text)
    end)

    if not ok then
        notify_error(err)
    end
end

function M.setup()
    vim.api.nvim_create_user_command("JasyptEncrypt", function(opts)
        if has_visual_selection() then
            local start_line, start_col, end_line, end_col = get_visual_range()
            M.encrypt_range({ line1 = start_line, col1 = start_col, line2 = end_line, col2 = end_col })
        else
            M.encrypt_range(opts)
        end
    end, { range = true, desc = "Encrypt selection with Jasypt" })

    vim.api.nvim_create_user_command("JasyptDecrypt", function(opts)
        if has_visual_selection() then
            local start_line, start_col, end_line, end_col = get_visual_range()
            M.decrypt_range({ line1 = start_line, col1 = start_col, line2 = end_line, col2 = end_col })
        else
            M.decrypt_range(opts)
        end
    end, { range = true, desc = "Decrypt selection with Jasypt" })
end

return M
