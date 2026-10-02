
Global( "SyntaxHighlighter", {
    tags_map = {
        ["def"] = "console_text",
        ["keyword"] = "console_keyword",
        ["string"] = "console_string",
        ["comment"] = "console_comment",
        ["number"] = "console_number",
        ["number_hex"] = "console_number",
        ["function"] = "console_function",
        ["variable"] = "console_variable",
        ["boolean"] = "console_boolean",
        ["type"] = "console_type",
        ["operator"] = "console_operator",
    }
} )

-- Конструкции
local lua_keywords = {
    ["and"] = true, ["or"] = true,
    ["break"] = true,
    ["do"] = true, ["for"] = true, ["in"] = true, ["repeat"] = true, ["until"] = true, ["while"] = true,
    ["if"] = true, ["then"] = true, ["elseif"] = true, ["else"] = true, ["end"] = true,
    ["function"] = true, ["return"] = true,
    ["goto"] = true,
    ["local"] = true,
    ["not"] = true,
}

-- boolean и nil
local lua_booleans = {
    ["true"] = true,
    ["false"] = true,
    ["nil"] = true
}

-- Типы
local lua_types = {
    ["table"] = true,
    ["userdata"] = true, ["WString"] = true,
    ["number"] = true,
    ["string"] = true,
    ["boolean"] = true,
    ["function"] = true,
    ["thread"] = true
}

-- Последовательная подсветка скобочек ([{}]) в рекурсии (Желтый -> Сиреневый -> Синий)
local bracket_colors = {
    [1] = "console_bracket_1",
    [2] = "console_bracket_2",
    [3] = "console_bracket_3",
}
local bracket_colors_count = #bracket_colors

--- [I] Токенизатор
--- @param code string
--- @return string tokens
local function tokenize( code )
    local tokens = {}
    local i = 1
    local len = #code
    local bracket_level = 0

    while i <= len do
        local c = code:sub( i, i )

        -- Пробелы и переносы строк
        if c:match( "%s" ) then
            local start = i
            while i <= len and code:sub( i, i ):match( "%s" ) do
                i = i + 1
            end
            table.insert( tokens, { type = "whitespace", value = code:sub( start, i - 1 ) } )

        -- Комментарии
        elseif c == "-" and code:sub( i, i + 1 ) == "--" then
            local start = i
            if code:sub( i, i + 3 ) == "--[[" then
                local _, end_pos = code:find( "%]%]", i + 4 )
                i = end_pos and ( end_pos + 2 ) or ( len + 1 )
            else
                local _, end_pos = code:find( "\n", i )
                i = end_pos or ( len + 1 )
            end
            table.insert( tokens, { type = "comment", value = code:sub( start, i - 1 ) } )

        -- Строки ( '', "", [[]] )
        elseif c == '"' or c == "'" then
            local start = i
            local quote = c
            i = i + 1
            while i <= len do
                if code:sub( i, i ) == "\\" then
                    i = i + 2
                elseif code:sub( i, i ) == quote then
                    i = i + 1
                    break
                else
                    i = i + 1
                end
            end
            table.insert( tokens, { type = "string", value = code:sub( start, i - 1 ) } )

        elseif c == "[" and code:sub( i, i + 1 ) == "[[" then
            local start = i
            local _, end_pos = code:find( "%]%]", i + 2 )
            i = end_pos and ( end_pos + 2 ) or ( len + 1 )
            table.insert( tokens, { type = "string", value = code:sub( start, i - 1 ) } )

        -- Числа (integer, double, hex)
        elseif c:match( "%d" ) or ( c == "." and code:sub( i + 1, i + 1 ):match( "%d" ) ) then
            local start = i
            local is_hex = false
            if c == "0" and code:sub( i + 1, i + 1 ):lower() == "x" then
                is_hex = true
                i = i + 2
                while i <= len and code:sub( i, i ):match( "%x" ) do
                    i = i + 1
                end
            else
                while i <= len and ( code:sub( i, i ):match( "[%d%.eE]" ) or
                    ( code:sub( i, i ):match( "[%+%-]" ) and code:sub( i - 1, i - 1 ):match( "[eE]" ) ) )
                do
                    i = i + 1
                end
            end
            table.insert( tokens, { type = is_hex and "number_hex" or "number", value = code:sub( start, i - 1 ) } )

        -- lua_keywords, lua_booleans, lua_types
        elseif c:match( "[%a_]" ) then
            local start = i
            while i <= len and code:sub( i, i ):match( "[%w_]" ) do
                i = i + 1
            end
            local word = code:sub( start, i - 1 )

            -- is_func
            local j = i
            while j <= len and code:sub( j, j ):match( "%s" ) do
                j = j + 1
            end
            local is_func = ( j <= len and code:sub( j, j ) == "(" )

            local token_type = "variable"
            if lua_keywords[ word ] then
                token_type = "keyword"
            elseif lua_booleans[ word ] then
                token_type = "boolean"
            elseif lua_types[ word ] then
                token_type = "type"
            elseif is_func then
                token_type = "function"
            end

            table.insert( tokens, { type = token_type, value = word } )

        -- bracket, operator
        else
            if c == "(" or c == "[" or c == "{" then
                bracket_level = bracket_level + 1
                local color_level = ( ( bracket_level - 1 ) % bracket_colors_count ) + 1
                table.insert( tokens, { type = "bracket", value = c, bracket_tag = bracket_colors[ color_level ] } )
            elseif c == ")" or c == "]" or c == "}" then
                local color_level = ( ( bracket_level - 1 ) % bracket_colors_count ) + 1
                table.insert( tokens, { type = "bracket", value = c, bracket_tag = bracket_colors[ color_level ] } )
                bracket_level = math.max( 0, bracket_level - 1 )
            else
                table.insert( tokens, { type = "operator", value = c } )
            end
            i = i + 1
        end
    end

    return tokens
end



--- [P] Метод. Стилизирование текста.
--- @param code string
--- @return string
function SyntaxHighlighter:highlight( code )
    local type_code = type( code )
    assert( type_code == "string", "SyntaxHighlighter:highlight FATAL: must be a \"string\", got = " .. type_code )

    local tokens = tokenize( code )
    local result = {}

    for _, token in ipairs( tokens ) do
        local tag = self.tags_map[ token.type ] or self.tags_map[ "def" ]

        -- escape HTML
        local safe_value = token.value
            -- "&", "&amp;"
            :gsub( "<", "&lt;" )
            :gsub( ">", "&gt;" )

        if token.type == "whitespace" then
            table.insert( result, safe_value )
        else
            table.insert( result, string.format( "<%s>%s</%s>", tag, safe_value, tag ) )
        end
    end

    return table.concat( result )
end