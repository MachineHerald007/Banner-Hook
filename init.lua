local core_mainmenu = require("core_mainmenu")
local lib_helpers = require("solylib.helpers")
local lib_items_list = require("solylib.items.items_list")
local cfg = require("Banner Hook.configuration")
local optionsLoaded, options = pcall(require, "Banner Hook.options")

local optionsFileName = "addons/Banner Hook/options.lua"
local ConfigurationWindow

if optionsLoaded then
    options.configurationEnableWindow = lib_helpers.NotNilOrDefault(options.configurationEnableWindow, true)
    options.enable                    = lib_helpers.NotNilOrDefault(options.enable, true)
    options.server                    = lib_helpers.NotNilOrDefault(options.server, 1)
else
    options = 
    {
        configurationEnableWindow = true,
        enable = true,
        server = 1
    }
end

local state = {
    banner_text = "",
    banner_cache = {},
    exe_path = os.getenv("PWD") or io.popen("cd"):read() .. "\\elite_force_webhook.exe "
}

lib_items_list.AddServerItems(options.server)

local function SaveOptions(options)
    local file = io.open(optionsFileName, "w")
    if file ~= nil then
        io.output(file)

        io.write("return\n")
        io.write("{\n")
        io.write(string.format("    configurationEnableWindow = %s,\n", tostring(options.configurationEnableWindow)))
        io.write(string.format("    enable = %s,\n", tostring(options.enable)))
        io.write(string.format("    server = %s,\n", tostring(options.server)))
        io.write("}\n")

        io.close(file)
    end
end

-- Soly Wrapper Function
local function TextCWrapper(newLine, col, fmt, ...)
    -- Update the color if one was specified here.
    col = col or 0xFFFFFFFF

    local rgb = bit.band(col, 0x00FFFFFF)
    local oldAlpha = bit.rshift(col, 24)
    local newAlpha = math.floor(oldAlpha * overrideAlphaPercent)
    col = bit.bor(bit.lshift(newAlpha, 24), rgb)

    return lib_helpers.TextC(newLine, col, fmt, ...)
end

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

local function process_banner()
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
            imgui.Text("Banner: " .. v)
        end
    imgui.End()
end

local function present()
    -- If the addon has never been used, open the config window
    -- and disable the config window setting
    if options.configurationEnableWindow then
        ConfigurationWindow.open = true
        options.configurationEnableWindow = false
    end

    ConfigurationWindow.Update()

    if ConfigurationWindow.changed then
        ConfigurationWindow.changed = false
        SaveOptions(options)
    end

    -- Global enable here to let the configuration window work
    if options.enable == false then
        return
    end

    process_banner()
end

local function init()
    ConfigurationWindow = cfg.ConfigurationWindow(options)

    local function mainMenuButtonHandler()
        ConfigurationWindow.open = not ConfigurationWindow.open
    end

    core_mainmenu.add_button("Banner Hook", mainMenuButtonHandler)

    return
    {
        name = "Banner Hook",
        version = "0.0.1",
        author = "Machine Herald",
        description = "Saves rare item banners and sends the banners to discord",
        present = present
    }
end

return
{
    __addon =
    {
        init = init
    }
}