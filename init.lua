local core_mainmenu = require("core_mainmenu")
local lib_helpers = require("solylib.helpers")
local lib_items = require("solylib.items.items")
local lib_characters = require("solylib.characters")
local lib_items_cfg = require("solylib.items.items_configuration")
local custom_list = require("Banner Hook.custom_list")
local cfg = require("Banner Hook.configuration")
local optionsLoaded, options = pcall(require, "Banner Hook.options")

local optionsFileName = "addons/Banner Hook/options.lua"
local ConfigurationWindow

if optionsLoaded then
    options.configurationEnableWindow = lib_helpers.NotNilOrDefault(options.configurationEnableWindow, true)
    options.enable                    = lib_helpers.NotNilOrDefault(options.enable, true)
    options.enableCustomBanners       = lib_helpers.NotNilOrDefault(options.enableCustomBanners, true)
    options.server                    = lib_helpers.NotNilOrDefault(options.server, 1)
    options.updateThrottle            = lib_helpers.NotNilOrDefault(options.updateThrottle, 0)
else
    options =
    {
        configurationEnableWindow = true,
        enable = true,
        enableCustomBanners = true,
        server = 1,
        updateThrottle = 0
    }
end

local update_delay = (options.updateThrottle * 1000)
local current_time = 0
local last_inventory_index = -1
local last_inventory_time = 0
local cache_inventory = nil
local last_floor_time = 0
local cache_floor = nil

local state = {
    banner_text = "",
    banner_cache = {},
    inventoried_cache = {},
    white_listed_drops = {},
    exe_path = os.getenv("PWD") or io.popen("cd"):read() .. "\\elite_force_webhook.exe "
}

local function wrap_as_single_arg(banner)
    return '"' .. banner .. '"'
end

local function process_weapon(item, floor)
    if floor then
        for k, v in pairs(custom_list) do
            if
                item.name == v.name and
                item.weapon.stats[6] >= v.hit_threshold
            then
                local white_list_count = table.getn(state.white_listed_drops)
                local white_listed = false

                for i=1, white_list_count, 1 do
                    if state.white_listed_drops[i].id == item.id then
                        white_listed = true
                    end
                end

                if white_listed == false and state.inventoried_cache[item.id] == nil then
                    item.from_inventory = false
                    table.insert(state.white_listed_drops, item)
                end
            end
        end
    else
        state.inventoried_cache[item.id] = item
        local white_list_count = table.getn(state.white_listed_drops)
        for i=1, white_list_count, 1 do
            for inventoried_id, _v in pairs(state.inventoried_cache) do
                if
                    inventoried_id ~= item.id and
                    state.white_listed_drops[i].id == item.id and
                    state.white_listed_drops[i].from_inventory == false
                then
                    state.white_listed_drops[i].from_inventory = true
                    local player_address = lib_characters.GetSelf()
                    local player_name = lib_characters.GetPlayerName(player_address)
                    local banner = "**".. player_name .. "** has found " .. "**" .. item.name .. "** with " .. item.weapon.stats[6] .. "hit!"                    
                    local command = "start " .. state.exe_path .. wrap_as_single_arg(banner)
                    os.execute(command)   
                end
            end
        end
    end
end

local function process_tool(item, floor) end
local function process_unit(item, floor) end
local function process_frame(item, floor) end
local function process_barrier(item, floor) end

local function process_item(item, floor)
    floor = floor or false

    if item.data[1] == 0 then
        process_weapon(item, floor)
    elseif item.data[1] == 1 then
        if item.data[2] == 1 then
            process_frame(item, floor)
        elseif item.data[2] == 2 then
            process_barrier(item, floor)
        elseif item.data[2] == 3 then
            process_unit(item, floor)
        end
    elseif item.data[1] == 3 then
        process_tool(item, floor)
    end
end

local function process_inventory(index)
    index = index or lib_items.Me
    if last_inventory_time + update_delay < current_time or last_inventory_index ~= index or cache_inventory == nil then
        cache_inventory = lib_items.GetInventory(index)
        last_inventory_index = index
        last_inventory_time = current_time
    end

    local itemCount = table.getn(cache_inventory.items)
    for i=1,itemCount,1 do
        process_item(cache_inventory.items[i], false)
    end
end

local function process_floor()
    if last_floor_time + update_delay < current_time or cache_floor == nil then
        cache_floor = lib_items.GetItemList(lib_items.NoOwner, options.invertItemList)
        last_floor_time = current_time
    end

    local itemCount = table.getn(cache_floor)
    for i=1,itemCount,1 do
        process_item(cache_floor[i], true)
    end
end

local function save_options(options)
    local file = io.open(optionsFileName, "w")
    if file ~= nil then
        io.output(file)

        io.write("return\n")
        io.write("{\n")
        io.write(string.format("    configurationEnableWindow = %s,\n", tostring(options.configurationEnableWindow)))
        io.write(string.format("    enable = %s,\n", tostring(options.enable)))
        io.write(string.format("    enableCustomBanners = %s,\n", tostring(options.enableCustomBanners)))
        io.write(string.format("    server = %s,\n", tostring(options.server)))
        io.write(string.format("    updateThrottle = %s,\n", tostring(options.updateThrottle)))
        io.write("}\n")

        io.close(file)
    end
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

local function present_banner()
    local banner_text = get_banner_text()
    banner_text = wrap_as_single_arg(clean_pso_text(banner_text))
    
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
        save_options(options)
    end

    --- Update timer for update throttle
    current_time = pso.get_tick_count()

    if options.enable then
        present_banner()
    end

    if options.enableCustomBanners then
        process_inventory(lib_items.Me)
        process_floor()
    else
        state.inventoried_cache = {}
        state.white_listed_drops = {}
    end
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