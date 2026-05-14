local jasypt = {}

function jasypt.setup(opts)
    require("jasypt.config").set_defaults(opts or {})
end

function jasypt.encrypt(text, password)
    return require("jasypt.command").encrypt_text(text, password)
end

function jasypt.decrypt(text, password)
    return require("jasypt.command").decrypt_text(text, password)
end

return jasypt
