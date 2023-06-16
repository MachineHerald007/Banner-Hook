local function ConfigurationWindow(configuration)
    local this =
    {
        title = "Banner Hook - Configuration",
        open = false,
        changed = false,
    }

    local _configuration = configuration

    local _showWindowSettings = function()
        local success
        local anchorList =
        {
            "Top Left (Disabled)", "Left", "Bottom Left",
            "Top", "Center", "Bottom",
            "Top Right", "Right", "Bottom Right",
        }
        local serverList =
        {
            "Vanilla",
            "Ultima",
            "Ephinea",
            "Schthack",
        }

        if imgui.TreeNodeEx("General", "DefaultOpen") then
            if imgui.Checkbox("Enable", _configuration.enable) then
                _configuration.enable = not _configuration.enable
                this.changed = true
            end

            if imgui.Checkbox("Enable Banner Window", _configuration.enableBannerWindow) then
                _configuration.enableBannerWindow = not _configuration.enableBannerWindow
                this.changed = true
            end

            if imgui.Checkbox("Enable Custom Banners", _configuration.enableCustomBanners) then
                _configuration.enableCustomBanners = not _configuration.enableCustomBanners
                this.changed = true
            end

            imgui.PushItemWidth(100)
            success, _configuration.updateThrottle = imgui.InputInt("Delay Update (seconds)", _configuration.updateThrottle)
            imgui.PopItemWidth()
            if success then
                this.changed = true
            end

            imgui.PushItemWidth(200)
            success, _configuration.server = imgui.Combo("Server", _configuration.server, serverList, table.getn(serverList))
            imgui.PopItemWidth()
            if success then
                this.changed = true
            end

            imgui.TreePop()
        end

    end

    this.Update = function()
        if this.open == false then
            return
        end

        local success

        imgui.SetNextWindowSize(500, 400, 'FirstUseEver')
        success, this.open = imgui.Begin(this.title, this.open)

        _showWindowSettings()

        imgui.End()
    end

    return this
end

return
{
    ConfigurationWindow = ConfigurationWindow,
}