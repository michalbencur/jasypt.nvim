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

function M.encrypt(text, password)
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
    }, salt .. text, false)

    return base64_encode(salt .. encrypted)
end

function M.decrypt(text, password)
    local decoded = base64_decode(text)
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

return M
