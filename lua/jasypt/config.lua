local config = {}

local defaults = {
    password = vim.env.JASYPT_ENCRYPTOR_PASSWORD,
    previous_password = vim.env.JASYPT_PREVIOUS_PASSWORD,
}

config.values = vim.deepcopy(defaults)

function config.set_defaults(user_defaults)
    config.values = vim.tbl_deep_extend("force", vim.deepcopy(defaults), user_defaults or {})
end

function config.get()
    return config.values
end

return config
