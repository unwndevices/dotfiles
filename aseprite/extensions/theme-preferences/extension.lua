local Template = dofile("./Template.lua")
local ThemeManager = dofile("./ThemeManager.lua")
local FontsProvider = dofile("./FontsProvider.lua")

local THEME_ID = "custom"
local DIALOG_WIDTH = 240
local DIALOG_TITLE = "Theme Preferences"

local ExtensionsDirectory = app.fs.joinPath(app.fs.userConfigPath, "extensions")
local ThemePreferencesDirectory = app.fs.joinPath(ExtensionsDirectory,
                                                  "theme-preferences")
local SheetTemplatePath = app.fs.joinPath(ThemePreferencesDirectory,
                                          "sheet-template.png")
local SheetPath = app.fs.joinPath(ThemePreferencesDirectory, "sheet.png")
local ThemeXmlTemplatePath = app.fs.joinPath(ThemePreferencesDirectory,
                                             "theme-template.xml")
local ThemeXmlPath = app.fs.joinPath(ThemePreferencesDirectory, "theme.xml")

function ReadAll(filePath)
    local file = assert(io.open(filePath, "rb"))
    local content = file:read("*all")
    file:close()
    return content
end

function WriteAll(filePath, content)
    local file = io.open(filePath, "w")
    if file then
        file:write(content)
        file:close()
    end
end

function ColorToHex(color)
    return string.format("#%02x%02x%02x", color.red, color.green, color.blue)
end

function RgbaPixelToColor(rgbaPixel)
    return Color {
        red = app.pixelColor.rgbaR(rgbaPixel),
        green = app.pixelColor.rgbaG(rgbaPixel),
        blue = app.pixelColor.rgbaB(rgbaPixel),
        alpha = app.pixelColor.rgbaA(rgbaPixel)
    }
end

function CopyColor(originalColor)
    return Color {
        red = originalColor.red,
        green = originalColor.green,
        blue = originalColor.blue,
        alpha = originalColor.alpha
    }
end

-- Color Definitions
local Theme = {name = "", colors = {}, parameters = {}}

-- Copy template to theme
Theme.name = Template.name

for id, color in pairs(Template.colors) do Theme.colors[id] = CopyColor(color) end

for id, parameter in pairs(Template.parameters) do
    Theme.parameters[id] = parameter
end

-- Dialog
local ThemePreferencesDialog = {
    isModified = false,
    lastRefreshState = false,
    isDialogOpen = false,
    onClose = nil,
    dialog = nil
}

ThemePreferencesDialog.dialog = Dialog {
    title = DIALOG_TITLE,
    onclose = function() ThemePreferencesDialog:onClose() end
}

function ThemePreferencesDialog:SetInitialWidth()
    self.dialog:show{wait = false}
    self.dialog:close()

    local uiScale = app.preferences.general["ui_scale"]

    local bounds = self.dialog.bounds
    bounds.x = bounds.x - (DIALOG_WIDTH - bounds.width) / 2
    bounds.width = DIALOG_WIDTH * uiScale

    self.dialog.bounds = bounds
end

function ThemePreferencesDialog:RefreshTheme(template, theme)
    -- Prepare color lookup
    local Map = {}

    for id, templateColor in pairs(template.colors) do
        -- Map the template color to the theme color
        Map[ColorToHex(templateColor)] = theme.colors[id]
    end

    -- Prepare sheet.png
    local image = Image {fromFile = SheetTemplatePath}
    local pixelValue, newColor, pixelData, pixelColor, pixelValueKey,
          resultColor

    -- Save references to function to improve performance
    local getPixel, drawPixel = image.getPixel, image.drawPixel

    local cache = {}

    for x = 0, image.width - 1 do
        for y = 0, image.height - 1 do
            pixelValue = getPixel(image, x, y)

            if pixelValue > 0 then
                pixelValueKey = tostring(pixelValue)
                pixelData = cache[pixelValueKey]

                if not pixelData then
                    pixelColor = RgbaPixelToColor(pixelValue)

                    cache[pixelValueKey] = {
                        id = ColorToHex(pixelColor),
                        color = pixelColor
                    }

                    pixelData = cache[pixelValueKey]
                end

                resultColor = Map[pixelData.id]

                if resultColor ~= nil then
                    newColor = CopyColor(resultColor)
                    newColor.alpha = pixelData.color.alpha -- Restore the original alpha value

                    drawPixel(image, x, y, newColor)
                end
            end
        end
    end

    image:saveAs(SheetPath)

    -- Update the XML theme file
    ThemePreferencesDialog:UpdateThemeXml(theme)

    app.command.Refresh()
end

function ThemePreferencesDialog:UpdateThemeXml(theme)
    -- Prepare theme.xml
    local xmlContent = ReadAll(ThemeXmlTemplatePath)

    for id, color in pairs(theme.colors) do
        xmlContent = xmlContent:gsub("<" .. id .. ">", ColorToHex(color))
    end

    local font = FontsProvider:GetCurrentFont()

    -- Setting fonts for these just in case it's a system font
    xmlContent = xmlContent:gsub("<system_font_default>",
                                 FontsProvider:GetFontDeclaration(font.default))
    xmlContent = xmlContent:gsub("<default_font>", font.default.name)
    xmlContent = xmlContent:gsub("<default_font_size>", font.default.size)

    xmlContent = xmlContent:gsub("<system_font_mini>",
                                 FontsProvider:GetFontDeclaration(font.mini))
    xmlContent = xmlContent:gsub("<mini_font>", font.mini.name)
    xmlContent = xmlContent:gsub("<mini_font_size>", font.mini.size)

    -- TODO: If using system fonts - ask user if they want to switch default scaling percentages

    WriteAll(ThemeXmlPath, xmlContent)
end

function ThemePreferencesDialog:Refresh()
    self.lastRefreshState = self.isModified

    self:RefreshTheme(Template, Theme)
    ThemeManager:SetCurrentTheme(Theme)

    -- Switch Aseprite to the custom theme
    if app.preferences.theme.selected ~= THEME_ID then
        app.preferences.theme.selected = THEME_ID
    end
end

function ShiftRGB(value, modifier)
    return math.max(math.min(value + modifier, 255), 0)
end

function ShiftColor(color, redModifier, greenModifer, blueModifier)
    return Color {
        red = ShiftRGB(color.red, redModifier),
        green = ShiftRGB(color.green, greenModifer),
        blue = ShiftRGB(color.blue, blueModifier),
        alpha = color.alpha
    }
end

function ThemePreferencesDialog:MarkThemeAsModified()
    self.isModified = true

    self.dialog --
    :modify{id = "save-configuration", enabled = true} --
    :modify{title = DIALOG_TITLE .. ": " .. Theme.name .. " (modified)"}
end

function ThemePreferencesDialog:SetThemeColor(id, color)
    Theme.colors[id] = color
    if self.dialog.data[id] then self.dialog:modify{id = id, color = color} end
end

function ThemePreferencesDialog:ChangeMode(options)
    -- Set default options
    options = options or {}
    options.force = options.force ~= nil and options.force or false

    local isSimple = self.dialog.data["mode-simple"]

    if isSimple then
        if not options.force then
            local confirmation = app.alert {
                title = "Warning",
                text = "Switching to Simple Mode will modify your theme, do you want to continue?",
                buttons = {"Yes", "No"}
            }

            if confirmation == 2 then
                self.dialog:modify{id = "mode-simple", selected = false}
                self.dialog:modify{id = "mode-advanced", selected = true}
                return
            end
        end

        -- Set new simple values when switching to Simple Mode
        self.dialog --
        :modify{id = "simple-link", color = Theme.colors["text_link"]} --
        :modify{id = "simple-button", color = Theme.colors["button_background"]} --
        :modify{id = "simple-tab", color = Theme.colors["tab_background"]} --
        :modify{id = "simple-window", color = Theme.colors["window_background"]} --
        :modify{id = "editor_icons", color = Theme.colors["text_regular"]}
    end

    self.dialog --
    :modify{id = "simple-link", visible = isSimple} --
    :modify{id = "simple-button", visible = isSimple} --
    :modify{id = "simple-tab", visible = isSimple} --
    :modify{id = "simple-window", visible = isSimple}

    local advancedWidgetIds = {
        "button_highlight", "button_background", "button_shadow",
        "tab_corner_highlight", "tab_highlight", "tab_background", "tab_shadow",
        "window_highlight", "window_background", "window_shadow", "text_link",
        "text_separator", "editor_icons"
    }

    for _, id in ipairs(advancedWidgetIds) do
        self.dialog:modify{id = id, visible = self.dialog.data["mode-advanced"]}
    end

    Theme.parameters.isAdvanced = self.dialog.data["mode-advanced"]
    self:MarkThemeAsModified()
end

function ThemePreferencesDialog:LoadTheme(theme)
    -- Copy theme to the current theme
    Theme.name = theme.name
    Theme.parameters = theme.parameters

    -- Chanage mode
    self.dialog --
    :modify{id = "mode-simple", selected = not theme.parameters.isAdvanced} --
    :modify{id = "mode-advanced", selected = theme.parameters.isAdvanced}

    self:ChangeMode{force = true}

    -- Load simple versions first to then overwrite advanced colors
    local simpleButtons = {
        ["simple-link"] = theme.colors["text_link"],
        ["simple-button"] = theme.colors["button_background"],
        -- ["simple-field"] = Theme.colors["field_background"],
        ["simple-tab"] = theme.colors["tab_background"],
        ["simple-window"] = theme.colors["window_background"]
    }

    for id, color in pairs(simpleButtons) do
        self.dialog:modify{id = id, color = color}
    end

    -- Finally, copy colors
    for id, color in pairs(theme.colors) do
        -- Copy color just in case
        self:SetThemeColor(id, CopyColor(color))
    end

    self.dialog:modify{title = DIALOG_TITLE .. ": " .. theme.name} --
    self.dialog:modify{id = "save-configuration", enabled = false}

    self.isModified = false
end

function ThemePreferencesDialog:ThemeColor(options)
    self.dialog:color{
        id = options.id,
        label = options.label,
        color = Theme.colors[options.id],
        visible = options.visible,
        onchange = function()
            local color = self.dialog.data[options.id]
            Theme.colors[options.id] = color

            if options.onchange then options.onchange(color) end

            self:MarkThemeAsModified()
        end
    }
end

function ThemePreferencesDialog:ChangeCursorColors()
    local color = self.dialog.data["editor_cursor"]
    local outlinecolor = self.dialog.data["editor_cursor_outline"]

    local shadowColor = Color {
        red = (color.red + outlinecolor.red) / 2,
        green = (color.green + outlinecolor.green) / 2,
        blue = (color.blue + outlinecolor.blue) / 2,
        alpha = color.alpha
    }

    Theme.colors["editor_cursor"] = color
    Theme.colors["editor_cursor_shadow"] = shadowColor
    Theme.colors["editor_cursor_outline"] = outlinecolor

    self:MarkThemeAsModified()
end

function ThemePreferencesDialog:LoadCurrentTheme()
    local currentTheme = ThemeManager:GetCurrentTheme()
    if currentTheme then self:LoadTheme(currentTheme) end
end

function ThemePreferencesDialog:Init()
    -- Colors = Tint, Highlight, Tooltip (label as Hover)

    -- Link/Separator = Tint Color
    -- Simple Tab Color = 50/50 Tint Color/Window Background Color
    -- Highlight = Highlight
    -- Tooltip = Tooltip
    -- Hover = 50/50 Tooltip/Window Background Color

    self.dialog --
    -- :radio{
    --     id = "mode-tint",
    --     label = "Mode",
    --     text = "Tint",
    --     selected = true,
    --     onclick = ChangeMode
    -- } --
    :radio{
        id = "mode-simple",
        label = "Mode",
        text = "Simple",
        selected = true,
        onclick = function() self:ChangeMode() end
    } --
    :radio{
        id = "mode-advanced",
        text = "Advanced",
        selected = false,
        onclick = function() self:ChangeMode() end
    }

    self.dialog:separator{text = "Text"}

    self:ThemeColor{
        label = "Active/Regular",
        id = "text_active",
        visible = true
    }
    self:ThemeColor{
        id = "text_regular",
        visible = true,
        onchange = function(color)
            if self.dialog.data["mode-simple"] then
                self:SetThemeColor("editor_icons", color)
            end
        end
    }
    self:ThemeColor{label = "Link/Separator", id = "text_link", visible = false}
    self:ThemeColor{id = "text_separator", visible = false}

    self.dialog:color{
        id = "simple-link",
        label = "Link/Separator",
        color = Theme.colors["text_link"],
        onchange = function()
            local color = self.dialog.data["simple-link"]

            self:SetThemeColor("text_link", color)
            self:SetThemeColor("text_separator", color)

            self:MarkThemeAsModified()
        end
    }

    self.dialog:separator{text = "Input Fields"}

    self:ThemeColor{label = "Highlight", id = "field_highlight", visible = true}

    -- FUTURE: Allow for separate chaning of the "field_background"
    -- dialog:color{
    --     id = "simple-field",
    --     label = "Background",
    --     color = Theme.colors["field_background"],
    --     onchange = function()
    --         local color = dialog.data["simple-field"]

    --         local shadowColor = Color {
    --             red = ShiftRGB(color.red, -57),
    --             green = ShiftRGB(color.green, -57),
    --             blue = ShiftRGB(color.blue, -57),
    --             alpha = color.alpha
    --         }

    --         local cornerShadowColor = Color {
    --             red = ShiftRGB(color.red, -74),
    --             green = ShiftRGB(color.green, -74),
    --             blue = ShiftRGB(color.blue, -74),
    --             alpha = color.alpha
    --         }

    --         Theme.colors["field_background"] = color
    --         Theme.colors["field_shadow"] = shadowColor
    --         Theme.colors["field_corner_shadow"] = cornerShadowColor
    --     end
    -- }

    self.dialog:separator{text = "Editor"}

    self:ThemeColor{
        label = "Background",
        id = "editor_background",
        onchange = function(color)
            local shadowColor = ShiftColor(color, -36, -20, -53)
            Theme.colors["editor_background_shadow"] = shadowColor
        end
    }

    self:ThemeColor{label = "Icons", id = "editor_icons", visible = false}

    self:ThemeColor{
        label = "Tooltip",
        id = "editor_tooltip",
        onchange = function(color)
            local shadowColor = ShiftColor(color, -100, -90, -32)
            local cornerShadowColor = ShiftColor(color, -125, -152, -94)

            Theme.colors["editor_tooltip_shadow"] = shadowColor
            Theme.colors["editor_tooltip_corner_shadow"] = cornerShadowColor
        end
    }

    self.dialog --
    :color{
        id = "editor_cursor",
        label = "Cursor",
        color = Theme.colors["editor_cursor"],
        onchange = function() self:ChangeCursorColors() end
    } --
    :color{
        id = "editor_cursor_outline",
        color = Theme.colors["editor_cursor_outline"],
        onchange = function() self:ChangeCursorColors() end
    }

    self.dialog:separator{text = "Button"}

    self:ThemeColor{id = "button_highlight", visible = false}
    self:ThemeColor{id = "button_background", visible = false}
    self:ThemeColor{id = "button_shadow", visible = false}

    self.dialog:color{
        id = "simple-button",
        color = Theme.colors["button_background"],
        onchange = function()
            local color = self.dialog.data["simple-button"]
            local highlightColor = ShiftColor(color, 57, 57, 57)
            local shadowColor = ShiftColor(color, -74, -74, -74)

            self:SetThemeColor("button_highlight", highlightColor)
            self:SetThemeColor("button_background", color)
            self:SetThemeColor("button_shadow", shadowColor)

            self:MarkThemeAsModified()
        end
    }

    self:ThemeColor{label = "Selected", id = "button_selected", visible = true}

    self.dialog:separator{text = "Tab"}

    self:ThemeColor{id = "tab_corner_highlight", visible = false}
    self:ThemeColor{id = "tab_highlight", visible = false}
    self:ThemeColor{id = "tab_background", visible = false}
    self:ThemeColor{id = "tab_shadow", visible = false}

    self.dialog:color{
        id = "simple-tab",
        color = Theme.colors["tab_background"],
        onchange = function()
            local color = self.dialog.data["simple-tab"]
            local cornerHighlightColor = ShiftColor(color, 131, 110, 98)
            local highlightColor = ShiftColor(color, 49, 57, 65)
            local shadowColor = ShiftColor(color, -24, -61, -61)

            self:SetThemeColor("tab_corner_highlight", cornerHighlightColor)
            self:SetThemeColor("tab_highlight", highlightColor)
            self:SetThemeColor("tab_background", color)
            self:SetThemeColor("tab_shadow", shadowColor)

            self:MarkThemeAsModified()
        end
    }

    self.dialog:separator{text = "Window"}

    self:ThemeColor{
        id = "window_highlight",
        visible = false,
        onchange = function(color)
            Theme.colors["window_highlight"] = color

            -- FUTURE: Remove this when setting a separate value for the "field_background" is possible

            local fieldShadowColor = ShiftColor(color, -57, -57, -57)
            local filedCornerShadowColor = ShiftColor(color, -74, -74, -74)

            Theme.colors["field_background"] = color
            Theme.colors["field_shadow"] = fieldShadowColor
            Theme.colors["field_corner_shadow"] = filedCornerShadowColor
        end
    }

    self:ThemeColor{id = "window_background", visible = false}

    self:ThemeColor{
        id = "window_shadow",
        visible = false,
        onchange = function(color)
            local cornerShadowColor = ShiftColor(color, -49, -44, -20)
            self:SetThemeColor("window_corner_shadow", cornerShadowColor)
        end
    }

    self.dialog:color{
        id = "simple-window",
        color = Theme.colors["window_background"],
        onchange = function()
            local color = self.dialog.data["simple-window"]
            local highlightColor = ShiftColor(color, 45, 54, 66)
            local shadowColor = ShiftColor(color, -61, -73, -73)
            local cornerShadowColor = ShiftColor(color, -110, -117, -93)

            self:SetThemeColor("window_highlight", highlightColor)
            self:SetThemeColor("window_background", color)
            self:SetThemeColor("window_shadow", shadowColor)
            self:SetThemeColor("window_corner_shadow", cornerShadowColor)

            -- FUTURE: Remove this when setting a separate value for the "field_background" is possible

            local fieldShadowColor = ShiftColor(highlightColor, -57, -57, -57)
            local filedCornerShadowColor =
                ShiftColor(highlightColor, -74, -74, -74)

            Theme.colors["field_background"] = highlightColor
            Theme.colors["field_shadow"] = fieldShadowColor
            Theme.colors["field_corner_shadow"] = filedCornerShadowColor

            self:MarkThemeAsModified()
        end
    } --

    self:ThemeColor{label = "Hover", id = "window_hover", visible = true}

    self.dialog --
    :separator() --
    :button{
        id = "save-configuration",
        label = "Configuration",
        text = "Save",
        enabled = false,
        onclick = function()
            local onsave = function(theme)
                self.dialog:modify{title = DIALOG_TITLE .. ": " .. theme.name}
                self.dialog:modify{id = "save-configuration", enabled = false}

                self.isModified = false
                self.lastRefreshState = false
            end

            ThemeManager:Save(Theme, onsave)
        end
    } --
    :button{
        text = "Load",
        onclick = function()
            local onload = function(theme)
                self:LoadTheme(theme)
                self:Refresh()
            end

            local onreset = function()
                self:LoadTheme(Template)
                self:Refresh()
            end

            -- Hide the Theme Preferences dialog
            ThemePreferencesDialog.dialog:close()

            ThemeManager:Load(onload, onreset)

            -- Reopen the dialog
            ThemePreferencesDialog.dialog:show{wait = false}
        end
    } --
    :button{
        text = "Font",
        onclick = function()
            local onconfirm = function() self:Refresh() end

            -- Hide the Theme Preferences dialog
            ThemePreferencesDialog.dialog:close()

            FontsProvider:OpenDialog(onconfirm)

            -- Reopen the dialog
            ThemePreferencesDialog.dialog:show{wait = false}
        end
    }

    self.dialog --
    :separator() --
    :button{
        text = "OK",
        onclick = function()
            self:Refresh()
            self.dialog:close()
        end
    } --
    :button{text = "Apply", onclick = function() self:Refresh() end} -- 
    :button{text = "Cancel", onclick = function() self.dialog:close() end} --
end

function init(plugin)
    -- Do nothing when UI is not available
    if not app.isUIAvailable then return end

    -- Initialize plugin preferences data for backwards compatibility
    plugin.preferences.themePreferences =
        plugin.preferences.themePreferences or {}
    local storage = plugin.preferences.themePreferences

    ThemeManager:Init{storage = storage}
    FontsProvider:Init{storage = storage}

    -- Initialize the diaog
    ThemePreferencesDialog:Init()

    -- Initialize data from plugin preferences
    ThemePreferencesDialog:LoadCurrentTheme()
    ThemePreferencesDialog.isModified = plugin.preferences.themePreferences
                                            .isThemeModified
    if ThemePreferencesDialog.isModified then
        ThemePreferencesDialog:MarkThemeAsModified()
    end

    -- Treat the "Modified" state as the last known refresh state 
    ThemePreferencesDialog.lastRefreshState = ThemePreferencesDialog.isModified

    -- Setup function to be called on close
    ThemePreferencesDialog.onClose = function()
        ThemePreferencesDialog:LoadCurrentTheme()

        ThemePreferencesDialog.isModified =
            ThemePreferencesDialog.lastRefreshState
        if ThemePreferencesDialog.isModified then
            ThemePreferencesDialog:MarkThemeAsModified()
        end

        ThemePreferencesDialog.isDialogOpen = false
    end

    -- Set the initial width of the dialog
    ThemePreferencesDialog:SetInitialWidth()

    plugin:newCommand{
        id = "ThemePreferences",
        title = DIALOG_TITLE .. "...",
        group = "view_screen",
        onenabled = function()
            return not ThemePreferencesDialog.isDialogOpen
        end,
        onclick = function()
            -- Refreshing the UI on open to fix the issue where the dialog would keep parts of the old theme
            app.command.Refresh()

            -- Show Theme Preferences dialog
            ThemePreferencesDialog.dialog:show{wait = false}

            -- Treat the "Modified" state as the last known refresh state 
            ThemePreferencesDialog.lastRefreshState =
                ThemePreferencesDialog.isModified

            -- Update the dialog if the theme is modified
            if ThemePreferencesDialog.isModified then
                ThemePreferencesDialog:MarkThemeAsModified()
            end

            ThemePreferencesDialog.isDialogOpen = true
        end
    }
end

function exit(plugin)
    plugin.preferences.themePreferences.isThemeModified =
        ThemePreferencesDialog.isModified
end
