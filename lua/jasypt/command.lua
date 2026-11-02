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

local function get_line_end_col(bufnr, line)
    return #vim.api.nvim_buf_get_lines(bufnr, line - 1, line, false)[1]
end

local function in_visual_mode()
    local mode = vim.fn.mode(1)
    return mode:sub(1, 1) == "v" or mode:sub(1, 1) == "V" or mode:sub(1, 1) == "\22"
end

-- Resolve the region a command applies to. Column-precise when the user
-- selected text charwise (either still in visual mode via a <Cmd> mapping, or
-- after typing ':' which leaves visual mode but records the '< and '> marks),
-- whole lines otherwise.
local function resolve_region(opts)
    local bufnr = vim.api.nvim_get_current_buf()
    local start_line, start_col, end_line, end_col

    if in_visual_mode() then
        local mode = vim.fn.mode(1):sub(1, 1)
        local start_pos = vim.fn.getpos("v")
        local end_pos = vim.fn.getcurpos()
        start_line, start_col = start_pos[2], start_pos[3]
        end_line, end_col = end_pos[2], end_pos[3]
        if start_line > end_line or (start_line == end_line and start_col > end_col) then
            start_line, end_line = end_line, start_line
            start_col, end_col = end_col, start_col
        end
        if mode ~= "v" then
            start_col, end_col = 1, nil
        end
    elseif opts.range == 2 and vim.fn.visualmode() == "v" then
        local start_pos = vim.fn.getpos("'<")
        local end_pos = vim.fn.getpos("'>")
        start_line, start_col = start_pos[2], start_pos[3]
        end_line, end_col = end_pos[2], end_pos[3]
        if start_line ~= opts.line1 or end_line ~= opts.line2 then
            -- range was typed by hand, not from the last visual selection
            start_line, start_col, end_line, end_col = opts.line1, 1, opts.line2, nil
        end
    else
        start_line, start_col, end_line, end_col = opts.line1, 1, opts.line2, nil
    end

    local line_len = get_line_end_col(bufnr, end_line)
    if end_col == nil or end_col > line_len then
        end_col = line_len
    end

    return bufnr, start_line, start_col, end_line, end_col
end

local function transform_region(opts, transform)
    local bufnr, start_line, start_col, end_line, end_col = resolve_region(opts)
    local text = table.concat(vim.api.nvim_buf_get_text(bufnr, start_line - 1, start_col - 1, end_line - 1, end_col, {}), "\n")
    local replacement = transform(text)
    vim.api.nvim_buf_set_text(bufnr, start_line - 1, start_col - 1, end_line - 1, end_col, vim.split(replacement, "\n", { plain = true }))
end

function M.encrypt_text(text, password)
    return "ENC(" .. crypto.encrypt(text, get_password(password)) .. ")"
end

function M.decrypt_text(text, password)
    local trimmed = vim.trim(text)
    local encrypted = trimmed:match("^ENC%((.*)%)$") or trimmed
    if encrypted == "" or not encrypted:match("^[%w+/]+=*$") then
        error("not a valid ENC(...) or base64 value: " .. trimmed)
    end

    return crypto.decrypt(encrypted, get_password(password))
end

function M.encrypt_range(opts)
    local ok, err = pcall(transform_region, opts, function(text)
        return M.encrypt_text(text)
    end)

    if not ok then
        notify_error(err)
    end
end

function M.decrypt_range(opts)
    local ok, err = pcall(transform_region, opts, function(text)
        return M.decrypt_text(text)
    end)

    if not ok then
        notify_error(err)
    end
end

function M.setup()
    vim.api.nvim_create_user_command("JasyptEncrypt", M.encrypt_range, { range = true, desc = "Encrypt selection with Jasypt" })
    vim.api.nvim_create_user_command("JasyptDecrypt", M.decrypt_range, { range = true, desc = "Decrypt selection with Jasypt" })

    vim.keymap.set("x", "<Plug>(JasyptEncrypt)", "<Cmd>JasyptEncrypt<CR><Esc>", { desc = "Encrypt selection with Jasypt" })
    vim.keymap.set("x", "<Plug>(JasyptDecrypt)", "<Cmd>JasyptDecrypt<CR><Esc>", { desc = "Decrypt selection with Jasypt" })
end

return M
