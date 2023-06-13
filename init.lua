local state = {
    banner_text = "",
    banner_cache = {},
    exe_path = os.getenv("PWD") or io.popen("cd"):read() .. "\\elite_force_webhook.exe "
}

local function get_banner_text()
    local addr = pso.read_u32(0x00a46c78)
    
    if addr ~= 0 then
        local text = pso.read_wstr(addr + 0x1c, 0x0200)
        return text
    end
    
    return ""
end

local function clean_pso_text(text)
    return text:gsub(string.char(9) .. "C%d", "")
end

local function present()    
    local banner_text = get_banner_text()
    banner_text = '"' .. clean_pso_text(banner_text) .. '"'

    if banner_text:find("has found") and state.banner_text ~= banner_text then
        local command = "start " .. state.exe_path .. banner_text
        state.banner_text = banner_text

        table.insert(state.banner_cache, banner_text)
        os.execute(command)
    end 

    imgui.Begin("Banner")
        for k, v in pairs(state.banner_cache) do
            imgui.Text("Rare Item Banner: " .. v)
        end
    imgui.End()
end

local function init()
    return {
        name = "Banner Hook",
        version = "0.0.1",
        author = "Machine Herald",
        description = "Saves rare item banners and sends the banners to discord",
        present = present
    }
end

return {
    __addon = {
        init = init
    }
}