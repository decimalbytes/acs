local LolliPrint = {}
LolliPrint.Enabled = true 

function LolliPrint:Print(...)
    if not self.Enabled then
        return
    end

    local args = { ... }
    local parts = {}
    for i, v in ipairs(args) do
        parts[#parts + 1] = tostring(v)
    end
    local message = table.concat(parts, "\t")
    local timestamp = os.date("%Y-%m-%d %H:%M:%S")
    local output = string.format("[%s] %s", timestamp, message)

    if type(rconsoleprint) == "function" then
        rconsoleprint(output .. "\n")
    else
        print(output)
    end
end

return LolliPrint
