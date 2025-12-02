std = "lua54"
max_line_length = false

include_files = {
    "lnko/**/*.lua",
    "bin/**/*.lua",
    "spec/**/*.lua",
}

files["spec/**/*.lua"] = {
    std = "+busted",
}
