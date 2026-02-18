local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local Lighting = game:GetService("Lighting")

local Library = {}
Library.Flags = {}
Library.Elements = {} 
Library.Connections = {}
Library.Settings = {
    LowPerformance = false,
    UIKey = Enum.KeyCode.RightControl,
    RainbowAccent = false
}
Library.ZIndex = 1
Library.NotificationQueue = {}
Library.IsNotificationActive = false 

Library.Theme = {
    Background = Color3.fromRGB(26, 26, 26),
    Header = Color3.fromRGB(32, 32, 32),
    Accent = Color3.fromRGB(62, 204, 204),
    Text = Color3.fromRGB(240, 240, 240),
    TextDark = Color3.fromRGB(180, 180, 180),
    Outline = Color3.fromRGB(50, 50, 50),
    Container = Color3.fromRGB(30, 30, 30)
}

--// Internal Functions
function Library:BindConnection(signal)
    local connection = signal
    table.insert(Library.Connections, connection)
    return connection
end

function Library:Cleanup()
    for _, conn in ipairs(Library.Connections) do
        if conn then conn:Disconnect() end
    end
    -- Cleanup Acrylic if exists
    if Library.Acrylic then Library.Acrylic:Destroy() end
    Library.Connections = {}
end

function Library:SetRainbow(state)
    Library.Settings.RainbowAccent = state
    if state then
        task.spawn(function()
            while Library.Settings.RainbowAccent do
                local hue = tick() % 5 / 5
                local color = Color3.fromHSV(hue, 1, 1)
                Library.Theme.Accent = color
                -- Ideally trigger a repaint or use property binding, 
                -- for now this only affects NEW elements or needs manual refresh hooks.
                -- A real system would use a signal.
                task.wait()
            end
        end)
    end
end

local ActiveTweens = {}
function Library:Tween(obj, info, props)
    if Library.Settings.LowPerformance then
        for prop, val in pairs(props) do
            obj[prop] = val
        end
        return
    end
    
    if ActiveTweens[obj] then 
        ActiveTweens[obj]:Cancel() 
        ActiveTweens[obj] = nil
    end
    
    local tween = TweenService:Create(obj, info, props)
    tween:Play()
    ActiveTweens[obj] = tween
    tween.Completed:Connect(function()
        if ActiveTweens[obj] == tween then
            ActiveTweens[obj] = nil
        end
    end)
    return tween
end

function Library:PlaySound(id, volume)
    if Library.Settings.LowPerformance then return end
    local sound = Instance.new("Sound")
    sound.SoundId = "rbxassetid://" .. tostring(id)
    sound.Volume = volume or 1
    sound.Parent = game:GetService("SoundService")
    sound:Play()
    sound.Ended:Connect(function() sound:Destroy() end)
end

--// Protected GUI
-- Singleton Pattern: Remove existing UI if present to prevent stacking
if CoreGui:FindFirstChild("ClarityUI") then
    CoreGui.ClarityUI:Destroy()
end
if Players.LocalPlayer:WaitForChild("PlayerGui"):FindFirstChild("ClarityUI") then
    Players.LocalPlayer.PlayerGui.ClarityUI:Destroy()
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "ClarityUI"
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Global

if RunService:IsStudio() then
    ScreenGui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
else
    local success, _ = pcall(function()
        ScreenGui.Parent = CoreGui
    end)
    if not success then
        ScreenGui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
    end
end

--// Global Toggles & Keybinds
Library:BindConnection(UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if not gameProcessed then
        if input.KeyCode == Library.Settings.UIKey then
            ScreenGui.Enabled = not ScreenGui.Enabled
        end
        
        for flag, val in pairs(Library.Flags) do
            if typeof(val) == "EnumItem" and val == input.KeyCode then
                local element = Library.Elements[flag]
                if element and element.Callback then
                    element.Callback()
                end
            end
        end
    end
end))

--// Utility Functions
local function Ripple(btn)
    if Library.Settings.LowPerformance then return end
    
    task.spawn(function()
        local mouse = Players.LocalPlayer:GetMouse()
        local ripple = Instance.new("Frame")
        ripple.Name = "Ripple"
        ripple.Parent = btn
        ripple.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        ripple.BackgroundTransparency = 0.9
        ripple.BorderSizePixel = 0
        ripple.Position = UDim2.new(0, mouse.X - btn.AbsolutePosition.X, 0, mouse.Y - btn.AbsolutePosition.Y)
        ripple.Size = UDim2.new(0, 0, 0, 0)
        ripple.ZIndex = btn.ZIndex + 1
        
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(1, 0)
        corner.Parent = ripple
        
        local maxSize = math.max(btn.AbsoluteSize.X, btn.AbsoluteSize.Y) * 1.5
        
        Library:Tween(ripple, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Size = UDim2.new(0, maxSize, 0, maxSize),
            Position = UDim2.new(0, mouse.X - btn.AbsolutePosition.X - (maxSize/2), 0, mouse.Y - btn.AbsolutePosition.Y - (maxSize/2)),
            BackgroundTransparency = 1
        })
        
        task.wait(0.5)
        ripple:Destroy()
    end)
end

local function MakeTooltip(element, text)
    local Tooltip = Instance.new("TextLabel")
    Tooltip.Parent = ScreenGui
    Tooltip.Visible = false
    Tooltip.BackgroundColor3 = Library.Theme.Header
    Tooltip.BorderColor3 = Library.Theme.Outline
    Tooltip.TextColor3 = Library.Theme.Text
    Tooltip.TextSize = 12
    Tooltip.Font = Enum.Font.Gotham
    Tooltip.Text = text
    Tooltip.AutomaticSize = Enum.AutomaticSize.XY
    Tooltip.ZIndex = 110
    
    local Padding = Instance.new("UIPadding")
    Padding.PaddingTop = UDim.new(0, 4)
    Padding.PaddingBottom = UDim.new(0, 4)
    Padding.PaddingLeft = UDim.new(0, 6)
    Padding.PaddingRight = UDim.new(0, 6)
    Padding.Parent = Tooltip
    
    local Corner = Instance.new("UICorner")
    Corner.CornerRadius = UDim.new(0, 4)
    Corner.Parent = Tooltip
    
    element.MouseEnter:Connect(function()
        Tooltip.Visible = true
        local mouse = UserInputService:GetMouseLocation()
        Tooltip.Position = UDim2.new(0, mouse.X + 10, 0, mouse.Y + 10)
    end)
    
    element.MouseMoved:Connect(function()
        local mouse = UserInputService:GetMouseLocation()
        Tooltip.Position = UDim2.new(0, mouse.X + 10, 0, mouse.Y + 10)
    end)
    
    element.MouseLeave:Connect(function()
        Tooltip.Visible = false
    end)
end

local function EnableDragging(frame, dragHandle)
    local dragInput
    local dragStart
    local startPos
    local dragging = false
    
    Library:BindConnection(dragHandle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position
            
            local inputChanged
            inputChanged = input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                    if inputChanged then inputChanged:Disconnect() end
                end
            end)
        end
    end))
    
    Library:BindConnection(dragHandle.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end))
    
    Library:BindConnection(UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            local newX = startPos.X.Offset + delta.X
            local newY = startPos.Y.Offset + delta.Y
            
            Library:Tween(frame, TweenInfo.new(0.05, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                Position = UDim2.new(startPos.X.Scale, newX, startPos.Y.Scale, newY)
            })
        end
    end))
end

--// Watermark Feature
function Library:CreateWatermark(scriptName)
    local Watermark = Instance.new("Frame")
    Watermark.Name = "Watermark"
    Watermark.Parent = ScreenGui
    Watermark.BackgroundColor3 = Library.Theme.Header
    Watermark.Position = UDim2.new(1, -220, 0, 20) -- Top Right default
    -- Fix for Watermark Scaling
    Watermark.Size = UDim2.new(0, 0, 0, 30) -- Let AutomaticSize handle width
    Watermark.AutomaticSize = Enum.AutomaticSize.X
    
    local Corner = Instance.new("UICorner")
    Corner.CornerRadius = UDim.new(0, 4)
    Corner.Parent = Watermark
    
    local Stroke = Instance.new("UIStroke")
    Stroke.Color = Library.Theme.Outline
    Stroke.Thickness = 1
    Stroke.Parent = Watermark
    
    local Label = Instance.new("TextLabel")
    Label.Parent = Watermark
    Label.BackgroundTransparency = 1
    Label.Position = UDim2.new(0, 10, 0, 0)
    Label.Size = UDim2.new(1, -20, 1, 0)
    Label.Font = Enum.Font.Gotham
    Label.Text = ""
    Label.TextColor3 = Library.Theme.Text
    Label.TextSize = 12
    Label.TextXAlignment = Enum.TextXAlignment.Left
    
    -- Dragging for Watermark
    EnableDragging(Watermark, Watermark)
    
    -- Update Loop
    Library:BindConnection(RunService.RenderStepped:Connect(function()
         if not Watermark.Parent then return end -- Safety check
         
         local fps = math.floor(workspace:GetRealPhysicsFPS())
         local ping = 0 
         if game:GetService("Stats"):FindFirstChild("PerformanceStats") then
             ping = math.floor(game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue())
         end
         
         local name = Players.LocalPlayer.DisplayName
         Label.Text = string.format("%s | FPS: %d | PING: %d | User: %s", scriptName, fps, ping, name)
    end))
    
    return Watermark
end


--// Notification System
local NotificationContainer = Instance.new("Frame")
NotificationContainer.Name = "Notifications"
NotificationContainer.Parent = ScreenGui
NotificationContainer.BackgroundTransparency = 1
NotificationContainer.Position = UDim2.new(1, -320, 1, -20)
NotificationContainer.Size = UDim2.new(0, 300, 1, 0)
NotificationContainer.AnchorPoint = Vector2.new(0, 1)

local UIListLayout_Notify = Instance.new("UIListLayout")
UIListLayout_Notify.Parent = NotificationContainer
UIListLayout_Notify.SortOrder = Enum.SortOrder.LayoutOrder
UIListLayout_Notify.VerticalAlignment = Enum.VerticalAlignment.Bottom
UIListLayout_Notify.Padding = UDim.new(0, 5)

function Library:ProcessNotificationQueue()
    if Library.IsNotificationActive or #Library.NotificationQueue == 0 then return end
    Library.IsNotificationActive = true
    
    local options = table.remove(Library.NotificationQueue, 1)
    local Title = options.Title or "Notification"
    local Text = options.Text or "Text"
    local Duration = options.Duration or 3
    
    local NotifyFrame = Instance.new("Frame")
    NotifyFrame.Name = "NotifyFrame"
    NotifyFrame.BackgroundColor3 = Library.Theme.Header
    NotifyFrame.Size = UDim2.new(1, 0, 0, 0) 
    NotifyFrame.AutomaticSize = Enum.AutomaticSize.Y
    NotifyFrame.BorderSizePixel = 0
    NotifyFrame.ClipsDescendants = true
    NotifyFrame.Parent = NotificationContainer
    NotifyFrame.ZIndex = 110
    
    local NotifyCorner = Instance.new("UICorner")
    NotifyCorner.CornerRadius = UDim.new(0, 4)
    NotifyCorner.Parent = NotifyFrame
    
    local NotifyStroke = Instance.new("UIStroke")
    NotifyStroke.Color = Library.Theme.Outline
    NotifyStroke.Thickness = 1
    NotifyStroke.Parent = NotifyFrame
    
    local TitleLabel = Instance.new("TextLabel")
    TitleLabel.Name = "Title"
    TitleLabel.Parent = NotifyFrame
    TitleLabel.BackgroundTransparency = 1
    TitleLabel.Position = UDim2.new(0, 10, 0, 5)
    TitleLabel.Size = UDim2.new(1, -30, 0, 20)
    TitleLabel.Font = Enum.Font.GothamBold
    TitleLabel.Text = Title
    TitleLabel.TextColor3 = Library.Theme.Accent
    TitleLabel.TextSize = 14
    TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
    TitleLabel.ZIndex = 111
    
    local CloseBtn = Instance.new("TextButton")
    CloseBtn.Parent = NotifyFrame
    CloseBtn.BackgroundTransparency = 1
    CloseBtn.Position = UDim2.new(1, -20, 0, 5)
    CloseBtn.Size = UDim2.new(0, 15, 0, 15)
    CloseBtn.Text = "X"
    CloseBtn.TextColor3 = Library.Theme.TextDark
    CloseBtn.TextSize = 11
    CloseBtn.Font = Enum.Font.Gotham
    CloseBtn.ZIndex = 112
    
    local TextLabel = Instance.new("TextLabel")
    TextLabel.Name = "Text"
    TextLabel.Parent = NotifyFrame
    TextLabel.BackgroundTransparency = 1
    TextLabel.Position = UDim2.new(0, 10, 0, 25)
    TextLabel.Size = UDim2.new(1, -20, 0, 0)
    TextLabel.AutomaticSize = Enum.AutomaticSize.Y
    TextLabel.Font = Enum.Font.Gotham
    TextLabel.Text = Text
    TextLabel.TextColor3 = Library.Theme.Text
    TextLabel.TextSize = 12
    TextLabel.TextWrapped = true
    TextLabel.TextXAlignment = Enum.TextXAlignment.Left
    TextLabel.ZIndex = 111
    
    local ProgressBar = Instance.new("Frame")
    ProgressBar.Name = "Timer"
    ProgressBar.Parent = NotifyFrame
    ProgressBar.BackgroundColor3 = Library.Theme.Accent
    ProgressBar.BorderSizePixel = 0
    ProgressBar.Position = UDim2.new(0, 0, 1, -2)
    ProgressBar.Size = UDim2.new(1, 0, 0, 2)
    ProgressBar.ZIndex = 112
    
    local UIPadding = Instance.new("UIPadding")
    UIPadding.Parent = NotifyFrame
    UIPadding.PaddingBottom = UDim.new(0, 10)
    
    local closed = false
    local function Close()
        if closed then return end
        closed = true
        Library:Tween(NotifyFrame, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Size = UDim2.new(1, 0, 0, 0), Position = UDim2.new(1.1, 0, 0, 0)})
        task.wait(0.3)
        NotifyFrame:Destroy()
        -- Allow next
        Library.IsNotificationActive = false
        Library:ProcessNotificationQueue()
    end
    
    CloseBtn.MouseButton1Click:Connect(Close)
    
    NotifyFrame.Size = UDim2.new(1, 0, 0, 0)
    local targetHeight = 50 + TextLabel.TextBounds.Y
    
    Library:Tween(NotifyFrame, TweenInfo.new(0.3), {Size = UDim2.new(1, 0, 0, targetHeight)})
    Library:Tween(ProgressBar, TweenInfo.new(Duration, Enum.EasingStyle.Linear), {Size = UDim2.new(0, 0, 0, 2)})
    
    task.delay(Duration, Close)
    
    task.delay(0.5, function()
         Library.IsNotificationActive = false
         Library:ProcessNotificationQueue()
    end)
end

function Library:Notify(options)
    table.insert(Library.NotificationQueue, options)
    if not Library.IsNotificationActive then
        Library:ProcessNotificationQueue()
    end
end

--// Config System
function Library:SaveConfig(name)
    local folder = "Clarity/Configs"
    if not isfolder("Clarity") then makefolder("Clarity") end
    if not isfolder(folder) then makefolder(folder) end
    
    local success, err = pcall(function()
        local json = HttpService:JSONEncode(Library.Flags)
        writefile(folder .. "/" .. name .. ".json", json)
    end)
    
    if success then
        Library:Notify({Title = "Config", Text = "Saved configuration: " .. name})
    else
        Library:Notify({Title = "Error", Text = "Failed to save config: " .. tostring(err)})
    end
end

function Library:LoadConfig(name)
    local file = "Clarity/Configs/" .. name .. ".json"
    if isfile(file) then
        local success, err = pcall(function()
            local json = readfile(file)
            local data = HttpService:JSONDecode(json)
            
            for flag, value in pairs(data) do
                if Library.Flags[flag] ~= nil then
                    Library.Flags[flag] = value
                    if Library.Elements[flag] and Library.Elements[flag].Set then
                        Library.Elements[flag].Set(value)
                    end
                end
            end
        end)
        
        if success then
            Library:Notify({Title = "Config", Text = "Loaded configuration: " .. name})
        else
            Library:Notify({Title = "Error", Text = "Failed to load config: " .. tostring(err)})
        end
    else
        Library:Notify({Title = "Config", Text = "Config not found!"})
    end
end

--// Main Window Creation
function Library:CreateWindow(options)
    local Name = options.Name or "Clarity UI"
    
    local MainFrame = Instance.new("Frame")
    MainFrame.Name = "MainFrame"
    MainFrame.Parent = ScreenGui
    MainFrame.BackgroundColor3 = Library.Theme.Background
    MainFrame.Position = UDim2.new(0.5, -250, 0.5, -175)
    MainFrame.Size = UDim2.new(0, 500, 0, 350)
    MainFrame.BorderSizePixel = 0
    MainFrame.ClipsDescendants = false
    
    MainFrame.BackgroundTransparency = 1
    Library:Tween(MainFrame, TweenInfo.new(0.5), {BackgroundTransparency = 0})
    
    local MainCorner = Instance.new("UICorner")
    MainCorner.CornerRadius = UDim.new(0, 6)
    MainCorner.Parent = MainFrame
    
    local MainStroke = Instance.new("UIStroke")
    MainStroke.Color = Library.Theme.Outline
    MainStroke.Thickness = 1
    MainStroke.Parent = MainFrame
    
    -- Header
    local Header = Instance.new("Frame")
    Header.Name = "Header"
    Header.Parent = MainFrame
    Header.BackgroundColor3 = Library.Theme.Header
    Header.Size = UDim2.new(1, 0, 0, 30)
    Header.BorderSizePixel = 0
    
    local HeaderCorner = Instance.new("UICorner")
    HeaderCorner.CornerRadius = UDim.new(0, 6)
    HeaderCorner.Parent = Header
    
    local TitleLabel = Instance.new("TextLabel")
    TitleLabel.Name = "Title"
    TitleLabel.Parent = Header
    TitleLabel.BackgroundTransparency = 1
    TitleLabel.Position = UDim2.new(0, 10, 0, 0)
    TitleLabel.Size = UDim2.new(1, -70, 1, 0)
    TitleLabel.Font = Enum.Font.GothamBold
    TitleLabel.Text = Name
    TitleLabel.TextColor3 = Library.Theme.Text
    TitleLabel.TextSize = 14
    TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
    
    -- Settings Button
    local SettingsButton = Instance.new("TextButton")
    SettingsButton.Name = "Settings"
    SettingsButton.Parent = Header
    SettingsButton.BackgroundTransparency = 1
    SettingsButton.Position = UDim2.new(1, -60, 0, 0)
    SettingsButton.Size = UDim2.new(0, 30, 0, 30)
    SettingsButton.Font = Enum.Font.Gotham
    SettingsButton.Text = "⚙"
    SettingsButton.TextColor3 = Library.Theme.TextDark
    SettingsButton.TextSize = 16
    
    SettingsButton.MouseEnter:Connect(function()
        Library:Tween(SettingsButton, TweenInfo.new(0.2), {TextColor3 = Library.Theme.Accent})
    end)
    SettingsButton.MouseLeave:Connect(function()
        Library:Tween(SettingsButton, TweenInfo.new(0.2), {TextColor3 = Library.Theme.TextDark})
    end)
    
    -- Close Button
    local CloseButton = Instance.new("TextButton")
    CloseButton.Name = "Close"
    CloseButton.Parent = Header
    CloseButton.BackgroundTransparency = 1
    CloseButton.Position = UDim2.new(1, -30, 0, 0)
    CloseButton.Size = UDim2.new(0, 30, 0, 30)
    CloseButton.Font = Enum.Font.Gotham
    CloseButton.Text = "X"
    CloseButton.TextColor3 = Library.Theme.Text
    CloseButton.TextSize = 14
    
    CloseButton.MouseEnter:Connect(function()
        Library:Tween(CloseButton, TweenInfo.new(0.2), {TextColor3 = Color3.fromRGB(255, 80, 80)})
    end)
    CloseButton.MouseLeave:Connect(function()
        Library:Tween(CloseButton, TweenInfo.new(0.2), {TextColor3 = Library.Theme.Text})
    end)
    
    CloseButton.MouseButton1Click:Connect(function()
        Library:Cleanup()
        ScreenGui:Destroy()
    end)
    
    -- Resize Handle
    local ResizeButton = Instance.new("TextButton")
    ResizeButton.Name = "Resize"
    ResizeButton.Parent = MainFrame
    ResizeButton.BackgroundTransparency = 1
    ResizeButton.Position = UDim2.new(1, -20, 1, -20)
    ResizeButton.Size = UDim2.new(0, 20, 0, 20)
    ResizeButton.Text = "◢"
    ResizeButton.TextColor3 = Library.Theme.TextDark
    ResizeButton.TextSize = 14
    
    local Resizing = false
    local ResizeStart
    local InitialSize
    
    Library:BindConnection(ResizeButton.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            Resizing = true
            ResizeStart = input.Position
            InitialSize = MainFrame.Size
        end
    end))
    
    Library:BindConnection(UserInputService.InputChanged:Connect(function(input)
        if Resizing and input.UserInputType == Enum.UserInputType.MouseMovement then
             local delta = input.Position - ResizeStart
             MainFrame.Size = UDim2.new(0, math.max(300, InitialSize.X.Offset + delta.X), 0, math.max(200, InitialSize.Y.Offset + delta.Y))
        end
    end))
    
    Library:BindConnection(UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            Resizing = false
        end
    end))
    
    EnableDragging(MainFrame, Header)
    
    -- Content Area
    local Content = Instance.new("Frame")
    Content.Name = "Content"
    Content.Parent = MainFrame
    Content.BackgroundColor3 = Library.Theme.Background
    Content.BackgroundTransparency = 1
    Content.Position = UDim2.new(0, 0, 0, 35)
    Content.Size = UDim2.new(1, 0, 1, -35)
    
    --// ========== SETTINGS PANEL ==========
    local SettingsOpen = false
    
    local SettingsPanel = Instance.new("Frame")
    SettingsPanel.Name = "SettingsPanel"
    SettingsPanel.Parent = MainFrame
    SettingsPanel.BackgroundColor3 = Library.Theme.Background
    SettingsPanel.Position = UDim2.new(0, 0, 0, 35)
    SettingsPanel.Size = UDim2.new(1, 0, 1, -35)
    SettingsPanel.Visible = false
    SettingsPanel.ZIndex = 50
    SettingsPanel.ClipsDescendants = true
    SettingsPanel.BackgroundTransparency = 0
    
    local SettingsCorner = Instance.new("UICorner")
    SettingsCorner.CornerRadius = UDim.new(0, 4)
    SettingsCorner.Parent = SettingsPanel
    
    -- Settings Header Label
    local SettingsTitle = Instance.new("TextLabel")
    SettingsTitle.Parent = SettingsPanel
    SettingsTitle.BackgroundTransparency = 1
    SettingsTitle.Position = UDim2.new(0, 15, 0, 8)
    SettingsTitle.Size = UDim2.new(1, -30, 0, 20)
    SettingsTitle.Font = Enum.Font.GothamBold
    SettingsTitle.Text = "⚙ Settings"
    SettingsTitle.TextColor3 = Library.Theme.Accent
    SettingsTitle.TextSize = 14
    SettingsTitle.TextXAlignment = Enum.TextXAlignment.Left
    SettingsTitle.ZIndex = 51
    
    -- Divider line under settings title
    local SettingsDivider = Instance.new("Frame")
    SettingsDivider.Parent = SettingsPanel
    SettingsDivider.BackgroundColor3 = Library.Theme.Outline
    SettingsDivider.BorderSizePixel = 0
    SettingsDivider.Position = UDim2.new(0, 10, 0, 32)
    SettingsDivider.Size = UDim2.new(1, -20, 0, 1)
    SettingsDivider.ZIndex = 51
    
    -- Scrolling content for settings
    local SettingsScroll = Instance.new("ScrollingFrame")
    SettingsScroll.Parent = SettingsPanel
    SettingsScroll.BackgroundTransparency = 1
    SettingsScroll.Position = UDim2.new(0, 0, 0, 38)
    SettingsScroll.Size = UDim2.new(1, 0, 1, -38)
    SettingsScroll.ScrollBarThickness = 2
    SettingsScroll.ScrollBarImageColor3 = Library.Theme.Accent
    SettingsScroll.ZIndex = 51
    SettingsScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    SettingsScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    
    local SettingsLayout = Instance.new("UIListLayout")
    SettingsLayout.Parent = SettingsScroll
    SettingsLayout.SortOrder = Enum.SortOrder.LayoutOrder
    SettingsLayout.Padding = UDim.new(0, 5)
    
    local SettingsPadding = Instance.new("UIPadding")
    SettingsPadding.Parent = SettingsScroll
    SettingsPadding.PaddingTop = UDim.new(0, 5)
    SettingsPadding.PaddingLeft = UDim.new(0, 10)
    SettingsPadding.PaddingRight = UDim.new(0, 10)
    SettingsPadding.PaddingBottom = UDim.new(0, 5)
    
    -- Helper: Create a settings toggle row
    local function CreateSettingsToggle(name, default, callback)
        local RowFrame = Instance.new("TextButton")
        RowFrame.Name = name
        RowFrame.Parent = SettingsScroll
        RowFrame.BackgroundColor3 = Library.Theme.Container
        RowFrame.Size = UDim2.new(1, 0, 0, 35)
        RowFrame.AutoButtonColor = false
        RowFrame.Text = ""
        RowFrame.ZIndex = 52
        
        local RowCorner = Instance.new("UICorner")
        RowCorner.CornerRadius = UDim.new(0, 4)
        RowCorner.Parent = RowFrame
        
        local RowLabel = Instance.new("TextLabel")
        RowLabel.Parent = RowFrame
        RowLabel.BackgroundTransparency = 1
        RowLabel.Position = UDim2.new(0, 10, 0, 0)
        RowLabel.Size = UDim2.new(1, -60, 1, 0)
        RowLabel.Font = Enum.Font.Gotham
        RowLabel.Text = name
        RowLabel.TextColor3 = Library.Theme.Text
        RowLabel.TextSize = 12
        RowLabel.TextXAlignment = Enum.TextXAlignment.Left
        RowLabel.ZIndex = 53
        
        local Switch = Instance.new("Frame")
        Switch.Parent = RowFrame
        Switch.BackgroundColor3 = Library.Theme.Background
        Switch.Position = UDim2.new(1, -45, 0.5, -10)
        Switch.Size = UDim2.new(0, 35, 0, 20)
        Switch.ZIndex = 53
        
        local SwitchCorner = Instance.new("UICorner")
        SwitchCorner.CornerRadius = UDim.new(1, 0)
        SwitchCorner.Parent = Switch
        
        local Dot = Instance.new("Frame")
        Dot.Parent = Switch
        Dot.BackgroundColor3 = Library.Theme.TextDark
        Dot.Position = UDim2.new(0, 2, 0.5, -8)
        Dot.Size = UDim2.new(0, 16, 0, 16)
        Dot.ZIndex = 54
        
        local DotCorner = Instance.new("UICorner")
        DotCorner.CornerRadius = UDim.new(1, 0)
        DotCorner.Parent = Dot
        
        local toggled = default
        
        local function UpdateVisual(val)
            if val then
                Library:Tween(Switch, TweenInfo.new(0.2), {BackgroundColor3 = Library.Theme.Accent})
                Library:Tween(Dot, TweenInfo.new(0.2), {Position = UDim2.new(0, 17, 0.5, -8), BackgroundColor3 = Color3.new(1,1,1)})
            else
                Library:Tween(Switch, TweenInfo.new(0.2), {BackgroundColor3 = Library.Theme.Background})
                Library:Tween(Dot, TweenInfo.new(0.2), {Position = UDim2.new(0, 2, 0.5, -8), BackgroundColor3 = Library.Theme.TextDark})
            end
        end
        
        UpdateVisual(toggled)
        
        RowFrame.MouseButton1Click:Connect(function()
            toggled = not toggled
            UpdateVisual(toggled)
            callback(toggled)
        end)
        
        RowFrame.MouseEnter:Connect(function()
            Library:Tween(RowFrame, TweenInfo.new(0.2), {BackgroundColor3 = Library.Theme.Header})
        end)
        RowFrame.MouseLeave:Connect(function()
            Library:Tween(RowFrame, TweenInfo.new(0.2), {BackgroundColor3 = Library.Theme.Container})
        end)
        
        return {SetValue = function(val) toggled = val; UpdateVisual(val) end}
    end
    
    -- Helper: Create a settings button row
    local function CreateSettingsButton(name, callback)
        local BtnFrame = Instance.new("TextButton")
        BtnFrame.Name = name
        BtnFrame.Parent = SettingsScroll
        BtnFrame.BackgroundColor3 = Library.Theme.Container
        BtnFrame.Size = UDim2.new(1, 0, 0, 35)
        BtnFrame.AutoButtonColor = false
        BtnFrame.Font = Enum.Font.Gotham
        BtnFrame.Text = name
        BtnFrame.TextColor3 = Library.Theme.Text
        BtnFrame.TextSize = 12
        BtnFrame.ZIndex = 52
        
        local BtnCorner = Instance.new("UICorner")
        BtnCorner.CornerRadius = UDim.new(0, 4)
        BtnCorner.Parent = BtnFrame
        
        BtnFrame.MouseEnter:Connect(function()
            Library:Tween(BtnFrame, TweenInfo.new(0.2), {BackgroundColor3 = Library.Theme.Header})
        end)
        BtnFrame.MouseLeave:Connect(function()
            Library:Tween(BtnFrame, TweenInfo.new(0.2), {BackgroundColor3 = Library.Theme.Container})
        end)
        
        BtnFrame.MouseButton1Click:Connect(function()
            Ripple(BtnFrame)
            callback()
        end)
    end
    
    -- Helper: Create a settings keybind row
    local function CreateSettingsKeybind(name, default, callback)
        local RowFrame = Instance.new("Frame")
        RowFrame.Name = name
        RowFrame.Parent = SettingsScroll
        RowFrame.BackgroundColor3 = Library.Theme.Container
        RowFrame.Size = UDim2.new(1, 0, 0, 35)
        RowFrame.ZIndex = 52
        
        local RowCorner = Instance.new("UICorner")
        RowCorner.CornerRadius = UDim.new(0, 4)
        RowCorner.Parent = RowFrame
        
        local RowLabel = Instance.new("TextLabel")
        RowLabel.Parent = RowFrame
        RowLabel.BackgroundTransparency = 1
        RowLabel.Position = UDim2.new(0, 10, 0, 0)
        RowLabel.Size = UDim2.new(1, -110, 1, 0)
        RowLabel.Font = Enum.Font.Gotham
        RowLabel.Text = name
        RowLabel.TextColor3 = Library.Theme.Text
        RowLabel.TextSize = 12
        RowLabel.TextXAlignment = Enum.TextXAlignment.Left
        RowLabel.ZIndex = 53
        
        local KeyBtn = Instance.new("TextButton")
        KeyBtn.Parent = RowFrame
        KeyBtn.BackgroundColor3 = Library.Theme.Background
        KeyBtn.Position = UDim2.new(1, -100, 0.5, -10)
        KeyBtn.Size = UDim2.new(0, 90, 0, 20)
        KeyBtn.AutoButtonColor = false
        KeyBtn.Font = Enum.Font.Gotham
        KeyBtn.Text = default.Name
        KeyBtn.TextColor3 = Library.Theme.Text
        KeyBtn.TextSize = 11
        KeyBtn.ZIndex = 53
        
        local KeyCorner = Instance.new("UICorner")
        KeyCorner.CornerRadius = UDim.new(0, 4)
        KeyCorner.Parent = KeyBtn
        
        local Binding = false
        
        KeyBtn.MouseButton1Click:Connect(function()
            Binding = true
            KeyBtn.Text = "..."
            KeyBtn.TextColor3 = Library.Theme.Accent
        end)
        
        Library:BindConnection(UserInputService.InputBegan:Connect(function(input)
            if Binding and input.UserInputType == Enum.UserInputType.Keyboard then
                KeyBtn.Text = input.KeyCode.Name
                KeyBtn.TextColor3 = Library.Theme.Text
                Binding = false
                callback(input.KeyCode)
            end
        end))
    end
    
    -- Helper: Create a settings color picker row (inline RGB)
    local function CreateSettingsColorPicker(name, default, callback)
        local PickerFrame = Instance.new("Frame")
        PickerFrame.Name = name
        PickerFrame.Parent = SettingsScroll
        PickerFrame.BackgroundColor3 = Library.Theme.Container
        PickerFrame.Size = UDim2.new(1, 0, 0, 35)
        PickerFrame.ClipsDescendants = true
        PickerFrame.ZIndex = 52
        
        local PCorner = Instance.new("UICorner")
        PCorner.CornerRadius = UDim.new(0, 4)
        PCorner.Parent = PickerFrame
        
        local PLabel = Instance.new("TextLabel")
        PLabel.Parent = PickerFrame
        PLabel.BackgroundTransparency = 1
        PLabel.Position = UDim2.new(0, 10, 0, 0)
        PLabel.Size = UDim2.new(1, -60, 0, 35)
        PLabel.Font = Enum.Font.Gotham
        PLabel.Text = name
        PLabel.TextColor3 = Library.Theme.Text
        PLabel.TextSize = 12
        PLabel.TextXAlignment = Enum.TextXAlignment.Left
        PLabel.ZIndex = 53
        
        local Preview = Instance.new("Frame")
        Preview.Parent = PickerFrame
        Preview.BackgroundColor3 = default
        Preview.Position = UDim2.new(1, -45, 0.5, -10)
        Preview.Size = UDim2.new(0, 35, 0, 20)
        Preview.ZIndex = 53
        
        local PreviewC = Instance.new("UICorner")
        PreviewC.CornerRadius = UDim.new(0, 4)
        PreviewC.Parent = Preview
        
        local ToggleBtn = Instance.new("TextButton")
        ToggleBtn.Parent = PickerFrame
        ToggleBtn.BackgroundTransparency = 1
        ToggleBtn.Size = UDim2.new(1, 0, 0, 35)
        ToggleBtn.Text = ""
        ToggleBtn.ZIndex = 54
        
        local SlidersContainer = Instance.new("Frame")
        SlidersContainer.Parent = PickerFrame
        SlidersContainer.BackgroundTransparency = 1
        SlidersContainer.Position = UDim2.new(0, 0, 0, 40)
        SlidersContainer.Size = UDim2.new(1, 0, 0, 80)
        SlidersContainer.Visible = false
        SlidersContainer.ZIndex = 53
        
        local r, g, b = default.R * 255, default.G * 255, default.B * 255
        
        local function UpdateColor()
            local newColor = Color3.fromRGB(r, g, b)
            Preview.BackgroundColor3 = newColor
            callback(newColor)
        end
        
        local function MakeSliderRow(label, yPos, initVal, setFunc)
            local SliderBg = Instance.new("Frame")
            SliderBg.Parent = SlidersContainer
            SliderBg.BackgroundColor3 = Library.Theme.Background
            SliderBg.Position = UDim2.new(0, 10, 0, yPos)
            SliderBg.Size = UDim2.new(1, -20, 0, 15)
            SliderBg.ZIndex = 54
            
            local SC2 = Instance.new("UICorner")
            SC2.CornerRadius = UDim.new(0, 4)
            SC2.Parent = SliderBg
            
            local Fill2 = Instance.new("Frame")
            Fill2.Parent = SliderBg
            Fill2.BackgroundColor3 = Library.Theme.Accent
            Fill2.Size = UDim2.new(initVal/255, 0, 1, 0)
            Fill2.ZIndex = 55
            
            local FC2 = Instance.new("UICorner")
            FC2.CornerRadius = UDim.new(0, 4)
            FC2.Parent = Fill2
            
            local SL2 = Instance.new("TextLabel")
            SL2.Parent = SliderBg
            SL2.BackgroundTransparency = 1
            SL2.Size = UDim2.new(1, 0, 1, 0)
            SL2.Font = Enum.Font.GothamBold
            SL2.Text = label
            SL2.TextColor3 = Color3.new(1,1,1)
            SL2.TextSize = 10
            SL2.ZIndex = 56
            
            local Btn2 = Instance.new("TextButton")
            Btn2.Parent = SliderBg
            Btn2.BackgroundTransparency = 1
            Btn2.Size = UDim2.new(1, 0, 1, 0)
            Btn2.Text = ""
            Btn2.ZIndex = 57
            
            local dragging2 = false
            
            Btn2.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 then
                    dragging2 = true
                    local pos = math.clamp((input.Position.X - SliderBg.AbsolutePosition.X) / SliderBg.AbsoluteSize.X, 0, 1)
                    Fill2.Size = UDim2.new(pos, 0, 1, 0)
                    setFunc(math.floor(pos * 255))
                end
            end)
            
            UserInputService.InputChanged:Connect(function(input)
                if dragging2 and input.UserInputType == Enum.UserInputType.MouseMovement then
                    local pos = math.clamp((input.Position.X - SliderBg.AbsolutePosition.X) / SliderBg.AbsoluteSize.X, 0, 1)
                    Fill2.Size = UDim2.new(pos, 0, 1, 0)
                    setFunc(math.floor(pos * 255))
                end
            end)
            
            UserInputService.InputEnded:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging2 = false end
            end)
        end
        
        MakeSliderRow("R", 0, r, function(val) r = val; UpdateColor() end)
        MakeSliderRow("G", 22, g, function(val) g = val; UpdateColor() end)
        MakeSliderRow("B", 44, b, function(val) b = val; UpdateColor() end)
        
        local cpOpen = false
        ToggleBtn.MouseButton1Click:Connect(function()
            cpOpen = not cpOpen
            if cpOpen then
                SlidersContainer.Visible = true
                Library:Tween(PickerFrame, TweenInfo.new(0.3), {Size = UDim2.new(1, 0, 0, 120)})
            else
                Library:Tween(PickerFrame, TweenInfo.new(0.3), {Size = UDim2.new(1, 0, 0, 35)})
                task.delay(0.3, function() SlidersContainer.Visible = false end)
            end
        end)
    end
    
    -- ===== Populate Settings =====
    
    -- 1. UI Toggle Key
    CreateSettingsKeybind("UI Toggle Key", Library.Settings.UIKey, function(keyCode)
        Library.Settings.UIKey = keyCode
    end)
    
    -- 2. Low Performance Mode
    CreateSettingsToggle("Low Performance", Library.Settings.LowPerformance, function(val)
        Library.Settings.LowPerformance = val
    end)
    
    -- 3. Rainbow Accent
    CreateSettingsToggle("Rainbow Accent", Library.Settings.RainbowAccent, function(val)
        Library:SetRainbow(val)
    end)
    
    -- 4. Accent Color
    CreateSettingsColorPicker("Accent Color", Library.Theme.Accent, function(color)
        Library.Theme.Accent = color
    end)
    
    -- 5. Destroy UI
    CreateSettingsButton("🗑 Destroy UI", function()
        Library:Cleanup()
        ScreenGui:Destroy()
    end)
    
    -- Toggle Settings Panel
    SettingsButton.MouseButton1Click:Connect(function()
        SettingsOpen = not SettingsOpen
        if SettingsOpen then
            Content.Visible = false
            SettingsPanel.Visible = true
            SettingsPanel.BackgroundTransparency = 1
            Library:Tween(SettingsPanel, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency = 0})
            Library:Tween(SettingsButton, TweenInfo.new(0.3), {Rotation = 90})
        else
            Library:Tween(SettingsPanel, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {BackgroundTransparency = 1})
            Library:Tween(SettingsButton, TweenInfo.new(0.3), {Rotation = 0})
            task.delay(0.2, function()
                SettingsPanel.Visible = false
                Content.Visible = true
            end)
        end
    end)
    --// ========== END SETTINGS PANEL ==========
    
    local TabContainer = Instance.new("ScrollingFrame")
    TabContainer.Name = "TabContainer"
    TabContainer.Parent = Content
    TabContainer.BackgroundTransparency = 1
    TabContainer.Position = UDim2.new(0, 10, 0, 0)
    TabContainer.Size = UDim2.new(0, 120, 1, -10)
    TabContainer.ScrollBarThickness = 2
    
    local UIListLayout_Tabs = Instance.new("UIListLayout")
    UIListLayout_Tabs.Parent = TabContainer
    UIListLayout_Tabs.SortOrder = Enum.SortOrder.LayoutOrder
    UIListLayout_Tabs.Padding = UDim.new(0, 5)
    
    local Pages = Instance.new("Frame")
    Pages.Name = "Pages"
    Pages.Parent = Content
    Pages.BackgroundTransparency = 1
    Pages.Position = UDim2.new(0, 140, 0, 0)
    Pages.Size = UDim2.new(1, -150, 1, -10)
    
    local Window = {}
    
    function Window:SetTitle(text)
        TitleLabel.Text = text
    end
    
    local FirstTab = true
    
    function Window:CreateTab(name)
        local TabButton = Instance.new("TextButton")
        TabButton.Name = name .. "Tab"
        TabButton.Parent = TabContainer
        TabButton.BackgroundColor3 = Library.Theme.Container
        TabButton.Size = UDim2.new(1, 0, 0, 30)
        TabButton.AutoButtonColor = false
        TabButton.Font = Enum.Font.Gotham
        TabButton.Text = name
        TabButton.TextColor3 = Library.Theme.TextDark
        TabButton.TextSize = 12
        
        local TabCorner = Instance.new("UICorner")
        TabCorner.CornerRadius = UDim.new(0, 4)
        TabCorner.Parent = TabButton
        
        local TabPage = Instance.new("ScrollingFrame")
        TabPage.Name = name .. "Page"
        TabPage.Parent = Pages
        TabPage.BackgroundTransparency = 1
        TabPage.Size = UDim2.new(1, 0, 1, 0)
        TabPage.ScrollBarThickness = 2
        TabPage.Visible = false
        
        local UIListLayout_Page = Instance.new("UIListLayout")
        UIListLayout_Page.Parent = TabPage
        UIListLayout_Page.SortOrder = Enum.SortOrder.LayoutOrder
        UIListLayout_Page.Padding = UDim.new(0, 5)
        
        local UIPadding_Page = Instance.new("UIPadding")
        UIPadding_Page.Parent = TabPage
        UIPadding_Page.PaddingTop = UDim.new(0, 5)
        UIPadding_Page.PaddingLeft = UDim.new(0, 5)
        UIPadding_Page.PaddingRight = UDim.new(0, 5)
        
        Library:BindConnection(UIListLayout_Page:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            TabPage.CanvasSize = UDim2.new(0, 0, 0, UIListLayout_Page.AbsoluteContentSize.Y + 10)
        end))
        
        if FirstTab then
            FirstTab = false
            TabPage.Visible = true
            TabButton.TextColor3 = Library.Theme.Accent
            TabButton.BackgroundColor3 = Library.Theme.Header
        end
        
        TabButton.MouseButton1Click:Connect(function()
            for _, page in pairs(Pages:GetChildren()) do
                if page:IsA("ScrollingFrame") then page.Visible = false end
            end
            TabPage.Visible = true
            
            for _, btn in pairs(TabContainer:GetChildren()) do
                if btn:IsA("TextButton") then
                    Library:Tween(btn, TweenInfo.new(0.2), {TextColor3 = Library.Theme.TextDark, BackgroundColor3 = Library.Theme.Container})
                end
            end
            Library:Tween(TabButton, TweenInfo.new(0.2), {TextColor3 = Library.Theme.Accent, BackgroundColor3 = Library.Theme.Header})
        end)
        
        local Tab = {}
        
        function Tab:CreateSection(text)
            local SectionContainer = Instance.new("Frame")
            SectionContainer.Name = text .. "Section"
            SectionContainer.Parent = TabPage
            SectionContainer.BackgroundColor3 = Library.Theme.Container
            SectionContainer.Size = UDim2.new(1, 0, 0, 30) -- starts small
            SectionContainer.AutomaticSize = Enum.AutomaticSize.Y
            SectionContainer.BackgroundTransparency = 0.5
            
            local SectionCorner = Instance.new("UICorner")
            SectionCorner.Parent = SectionContainer
            
            local SectionLabel = Instance.new("TextLabel")
            SectionLabel.Name = "SectionHeader"
            SectionLabel.Parent = SectionContainer
            SectionLabel.BackgroundTransparency = 1
            SectionLabel.Size = UDim2.new(1, 0, 0, 30)
            SectionLabel.Font = Enum.Font.GothamBold
            SectionLabel.Text = "  " .. text
            SectionLabel.TextColor3 = Library.Theme.Text
            SectionLabel.TextSize = 14
            SectionLabel.TextXAlignment = Enum.TextXAlignment.Left
        end

        function Tab:CreateLabel(text)
            local Label = Instance.new("TextLabel")
            Label.Name = "Label"
            Label.Parent = TabPage
            Label.BackgroundTransparency = 1
            Label.Size = UDim2.new(1, 0, 0, 20)
            Label.Font = Enum.Font.Gotham
            Label.Text = text
            Label.TextColor3 = Library.Theme.TextDark
            Label.TextSize = 12
            Label.TextXAlignment = Enum.TextXAlignment.Left
            return Label
        end

        function Tab:CreateImage(options)
            local ImageId = options.Image
            local Size = options.Size or UDim2.new(0, 100, 0, 100)
            
            local ImageFrame = Instance.new("ImageLabel")
            ImageFrame.Parent = TabPage
            ImageFrame.BackgroundTransparency = 1
            ImageFrame.Size = Size
            ImageFrame.Image = "rbxassetid://" .. tostring(ImageId)
            
            return ImageFrame
        end

        function Tab:CreateButton(options)
            local Text = options.Name or "Button"
            local Callback = options.Callback or function() end
            local TooltipText = options.Tooltip
            
            local ButtonFrame = Instance.new("TextButton")
            ButtonFrame.Name = Text
            ButtonFrame.Parent = TabPage
            ButtonFrame.BackgroundColor3 = Library.Theme.Container
            ButtonFrame.Size = UDim2.new(1, 0, 0, 35)
            ButtonFrame.AutoButtonColor = false
            ButtonFrame.Font = Enum.Font.Gotham
            ButtonFrame.Text = Text
            ButtonFrame.TextColor3 = Library.Theme.Text
            ButtonFrame.TextSize = 12
            
            local ButtonCorner = Instance.new("UICorner")
            ButtonCorner.CornerRadius = UDim.new(0, 4)
            ButtonCorner.Parent = ButtonFrame
            
            ButtonFrame.MouseEnter:Connect(function()
                Library:Tween(ButtonFrame, TweenInfo.new(0.2), {BackgroundColor3 = Library.Theme.Header})
                Library:PlaySound(6042053626, 0.5) -- Hover
            end)
            
            ButtonFrame.MouseLeave:Connect(function()
                Library:Tween(ButtonFrame, TweenInfo.new(0.2), {BackgroundColor3 = Library.Theme.Container})
            end)
            
            if TooltipText then MakeTooltip(ButtonFrame, TooltipText) end
            
            local Debounce = false
            ButtonFrame.MouseButton1Click:Connect(function()
                if Debounce then return end
                Debounce = true
                Ripple(ButtonFrame)
                Library:PlaySound(6042053626, 1) -- Click
                Callback()
                task.delay(0.2, function() Debounce = false end)
            end)
        end
        
        function Tab:CreateToggle(options)
            local Text = options.Name or "Toggle"
            local Flag = options.Flag or Text
            local Default = options.Default or false
            local Callback = options.Callback or function() end
            local TooltipText = options.Tooltip
            
            Library.Flags[Flag] = Default
            
            local ToggleFrame = Instance.new("TextButton")
            ToggleFrame.Name = Text
            ToggleFrame.Parent = TabPage
            ToggleFrame.BackgroundColor3 = Library.Theme.Container
            ToggleFrame.Size = UDim2.new(1, 0, 0, 35)
            ToggleFrame.AutoButtonColor = false
            ToggleFrame.Text = ""
            
            local ToggleCorner = Instance.new("UICorner")
            ToggleCorner.CornerRadius = UDim.new(0, 4)
            ToggleCorner.Parent = ToggleFrame
            
            local Label = Instance.new("TextLabel")
            Label.Parent = ToggleFrame
            Label.BackgroundTransparency = 1
            Label.Position = UDim2.new(0, 10, 0, 0)
            Label.Size = UDim2.new(1, -60, 1, 0)
            Label.Font = Enum.Font.Gotham
            Label.Text = Text
            Label.TextColor3 = Library.Theme.Text
            Label.TextSize = 12
            Label.TextXAlignment = Enum.TextXAlignment.Left
            
            local ToggleSwitch = Instance.new("Frame")
            ToggleSwitch.Parent = ToggleFrame
            ToggleSwitch.BackgroundColor3 = Library.Theme.Background
            ToggleSwitch.Position = UDim2.new(1, -45, 0.5, -10)
            ToggleSwitch.Size = UDim2.new(0, 35, 0, 20)
            
            local SwitchCorner = Instance.new("UICorner")
            SwitchCorner.CornerRadius = UDim.new(1, 0)
            SwitchCorner.Parent = ToggleSwitch
            
            local ToggleDot = Instance.new("Frame")
            ToggleDot.Parent = ToggleSwitch
            ToggleDot.BackgroundColor3 = Library.Theme.TextDark
            ToggleDot.Position = UDim2.new(0, 2, 0.5, -8)
            ToggleDot.Size = UDim2.new(0, 16, 0, 16)
            
            local DotCorner = Instance.new("UICorner")
            DotCorner.CornerRadius = UDim.new(1, 0)
            DotCorner.Parent = ToggleDot
            
            if TooltipText then MakeTooltip(ToggleFrame, TooltipText) end
            
            local function UpdateToggle(val)
                Library.Flags[Flag] = val
                if val then
                    Library:Tween(ToggleSwitch, TweenInfo.new(0.2), {BackgroundColor3 = Library.Theme.Accent})
                    Library:Tween(ToggleDot, TweenInfo.new(0.2), {Position = UDim2.new(0, 17, 0.5, -8), BackgroundColor3 = Color3.new(1,1,1)})
                else
                    Library:Tween(ToggleSwitch, TweenInfo.new(0.2), {BackgroundColor3 = Library.Theme.Background})
                    Library:Tween(ToggleDot, TweenInfo.new(0.2), {Position = UDim2.new(0, 2, 0.5, -8), BackgroundColor3 = Library.Theme.TextDark})
                end
                Callback(val)
            end
            
            Library.Elements[Flag] = {
                Set = function(val)
                     UpdateToggle(val)
                end,
                Callback = nil 
            }
            
            local Debounce = false
            ToggleFrame.MouseButton1Click:Connect(function()
                if Debounce then return end
                Debounce = true
                Library:PlaySound(6042053626, 0.8)
                UpdateToggle(not Library.Flags[Flag])
                task.delay(0.2, function() Debounce = false end)
            end)
            
            UpdateToggle(Default)
        end
        
        function Tab:CreateSlider(options)
            local Text = options.Name or "Slider"
            local Flag = options.Flag or Text
            local Min = options.Min or 0
            local Max = options.Max or 100
            local Default = options.Default or Min
            local Float = options.Float or 0 
            local Callback = options.Callback or function() end
            
            Library.Flags[Flag] = Default
            
            local SliderFrame = Instance.new("Frame")
            SliderFrame.Name = Text
            SliderFrame.Parent = TabPage
            SliderFrame.BackgroundColor3 = Library.Theme.Container
            SliderFrame.Size = UDim2.new(1, 0, 0, 45)
            
            local SliderCorner = Instance.new("UICorner")
            SliderCorner.CornerRadius = UDim.new(0, 4)
            SliderCorner.Parent = SliderFrame
            
            local Label = Instance.new("TextLabel")
            Label.Parent = SliderFrame
            Label.BackgroundTransparency = 1
            Label.Position = UDim2.new(0, 10, 0, 5)
            Label.Size = UDim2.new(1, -20, 0, 20)
            Label.Font = Enum.Font.Gotham
            Label.Text = Text
            Label.TextColor3 = Library.Theme.Text
            Label.TextSize = 12
            Label.TextXAlignment = Enum.TextXAlignment.Left
            
            local ValueLabel = Instance.new("TextLabel")
            ValueLabel.Parent = SliderFrame
            ValueLabel.BackgroundTransparency = 1
            ValueLabel.Position = UDim2.new(1, -60, 0, 5)
            ValueLabel.Size = UDim2.new(0, 50, 0, 20)
            ValueLabel.Font = Enum.Font.Gotham
            ValueLabel.Text = tostring(Default)
            ValueLabel.TextColor3 = Library.Theme.Text
            ValueLabel.TextSize = 12
            ValueLabel.TextXAlignment = Enum.TextXAlignment.Right
            
            local SliderBar = Instance.new("Frame")
            SliderBar.Parent = SliderFrame
            SliderBar.BackgroundColor3 = Library.Theme.Background
            SliderBar.Position = UDim2.new(0, 10, 0, 30)
            SliderBar.Size = UDim2.new(1, -20, 0, 6)
            
            local BarCorner = Instance.new("UICorner")
            BarCorner.CornerRadius = UDim.new(1, 0)
            BarCorner.Parent = SliderBar
            
            local SliderFill = Instance.new("Frame")
            SliderFill.Parent = SliderBar
            SliderFill.BackgroundColor3 = Library.Theme.Accent
            local Range = math.max(Max - Min, 0.01) 
            
            local function Round(num)
                if Float == 0 then return math.floor(num + 0.5) end
                local mult = 10 ^ Float
                return math.floor(num * mult + 0.5) / mult
            end
            
            local FillCorner = Instance.new("UICorner")
            FillCorner.CornerRadius = UDim.new(1, 0)
            FillCorner.Parent = SliderFill
            
            local SliderButton = Instance.new("TextButton")
            SliderButton.Parent = SliderBar
            SliderButton.BackgroundTransparency = 1
            SliderButton.Size = UDim2.new(1, 0, 1, 0)
            SliderButton.Text = ""
            
            local function UpdateSlider(val)
                local clamped = math.clamp(val, Min, Max)
                clamped = Round(clamped)
                local percent = (clamped - Min) / Range
                SliderFill.Size = UDim2.new(percent, 0, 1, 0)
                ValueLabel.Text = tostring(clamped)
                Library.Flags[Flag] = clamped
                Callback(clamped)
            end
            
             SliderFill.Size = UDim2.new((Default - Min) / Range, 0, 1, 0)
             
             Library.Elements[Flag] = {
                Set = function(val)
                    UpdateSlider(val)
                end
            }

            local dragging = false
            
            SliderButton.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                    dragging = true
                    
                    local function UpdateFromMouse()
                         local location = UserInputService:GetMouseLocation()
                         local pos = math.clamp((location.X - SliderBar.AbsolutePosition.X) / SliderBar.AbsoluteSize.X, 0, 1)
                         SliderFill.Size = UDim2.new(pos, 0, 1, 0)
                         local val = Min + (Range * pos)
                         val = Round(val)
                         ValueLabel.Text = tostring(val)
                         Library.Flags[Flag] = val
                         Callback(val)
                    end
                    
                    UpdateFromMouse()
                    
                    local inputChanged
                    inputChanged = UserInputService.InputChanged:Connect(function(moveInput)
                         if dragging and (moveInput.UserInputType == Enum.UserInputType.MouseMovement or moveInput.UserInputType == Enum.UserInputType.Touch) then
                             UpdateFromMouse()
                         end
                    end)
                    
                    local inputEnded
                    inputEnded = UserInputService.InputEnded:Connect(function(endInput)
                        if endInput.UserInputType == Enum.UserInputType.MouseButton1 or endInput.UserInputType == Enum.UserInputType.Touch then
                            dragging = false
                            inputChanged:Disconnect()
                            inputEnded:Disconnect()
                        end
                    end)
                end
            end)
        end
        
        function Tab:CreateDropdown(options)
            local Text = options.Name or "Dropdown"
            local Flag = options.Flag or Text
            local Options = options.Options or {}
            local Default = options.Default or Options[1]
            local Callback = options.Callback or function() end
            
            Library.Flags[Flag] = Default
            
            local DropdownFrame = Instance.new("Frame")
            DropdownFrame.Name = Text
            DropdownFrame.Parent = TabPage
            DropdownFrame.BackgroundColor3 = Library.Theme.Container
            DropdownFrame.Size = UDim2.new(1, 0, 0, 35)
            DropdownFrame.ClipsDescendants = false
            
            local DropdownCorner = Instance.new("UICorner")
            DropdownCorner.CornerRadius = UDim.new(0, 4)
            DropdownCorner.Parent = DropdownFrame
            
            local Label = Instance.new("TextLabel")
            Label.Parent = DropdownFrame
            Label.BackgroundTransparency = 1
            Label.Position = UDim2.new(0, 10, 0, 0)
            Label.Size = UDim2.new(1, -40, 0, 35)
            Label.Font = Enum.Font.Gotham
            Label.Text = Text .. ": " .. tostring(Default)
            Label.TextColor3 = Library.Theme.Text
            Label.TextSize = 12
            Label.TextXAlignment = Enum.TextXAlignment.Left
            
            local Arrow = Instance.new("ImageLabel")
            Arrow.Parent = DropdownFrame
            Arrow.BackgroundTransparency = 1
            Arrow.Position = UDim2.new(1, -25, 0.5, -10)
            Arrow.Size = UDim2.new(0, 20, 0, 20)
            Arrow.Image = "rbxassetid://6031091004"
            Arrow.ImageColor3 = Library.Theme.TextDark
            
            local DropdownButton = Instance.new("TextButton")
            DropdownButton.Parent = DropdownFrame
            DropdownButton.BackgroundTransparency = 1
            DropdownButton.Size = UDim2.new(1, 0, 1, 0)
            DropdownButton.Text = ""
            
            local ListFrame = Instance.new("Frame") 
            ListFrame.Parent = DropdownFrame
            ListFrame.BackgroundColor3 = Library.Theme.Container
            ListFrame.BorderSizePixel = 0
            ListFrame.Position = UDim2.new(0, 0, 1, 5)
            ListFrame.Size = UDim2.new(1, 0, 0, 0)
            ListFrame.Visible = false
            ListFrame.ZIndex = 10000 -- Force top
            ListFrame.ClipsDescendants = true
            
            local ListCorner = Instance.new("UICorner")
            ListCorner.CornerRadius = UDim.new(0, 4)
            ListCorner.Parent = ListFrame
            
            local SearchBar = Instance.new("TextBox")
            SearchBar.Parent = ListFrame
            SearchBar.BackgroundColor3 = Library.Theme.Background
            SearchBar.Size = UDim2.new(1, -10, 0, 20)
            SearchBar.Position = UDim2.new(0, 5, 0, 5)
            SearchBar.Font = Enum.Font.Gotham
            SearchBar.PlaceholderText = "Search..."
            SearchBar.Text = ""
            SearchBar.TextColor3 = Library.Theme.Text
            SearchBar.TextSize = 12
            SearchBar.ZIndex = 10002
            
            local SearchCorner = Instance.new("UICorner")
            SearchCorner.CornerRadius = UDim.new(0, 4)
            SearchCorner.Parent = SearchBar
            
            local ScrollList = Instance.new("ScrollingFrame")
            ScrollList.Parent = ListFrame
            ScrollList.BackgroundTransparency = 1
            ScrollList.Position = UDim2.new(0, 0, 0, 30)
            ScrollList.Size = UDim2.new(1, 0, 1, -30)
            ScrollList.ScrollBarThickness = 2
            ScrollList.ZIndex = 10001
            
            local UIListLayout_Drop = Instance.new("UIListLayout")
            UIListLayout_Drop.Parent = ScrollList
            UIListLayout_Drop.Padding = UDim.new(0, 2)
            
            local function Close()
                Library:Tween(ListFrame, TweenInfo.new(0.3), {Size = UDim2.new(1, 0, 0, 0)})
                Library:Tween(Arrow, TweenInfo.new(0.3), {Rotation = 0})
                task.wait(0.3)
                ListFrame.Visible = false
            end

            local function OpenList()
                -- Close others
                if Library.OpenedDropdown and Library.OpenedDropdown ~= Close then
                    Library.OpenedDropdown()
                end
                Library.OpenedDropdown = Close
                
                ListFrame.Visible = true
                Library:Tween(ListFrame, TweenInfo.new(0.3), {Size = UDim2.new(1, 0, 0, 150)})
                Library:Tween(Arrow, TweenInfo.new(0.3), {Rotation = 180})
            end
            
            local function RefreshOptions(filter)
                for _, child in pairs(ScrollList:GetChildren()) do
                    if child:IsA("TextButton") then child:Destroy() end
                end
                
                local count = 0
                for _, option in pairs(Options) do
                    if not filter or string.find(string.lower(tostring(option)), string.lower(filter)) then
                        count = count + 1
                        local OptionBtn = Instance.new("TextButton")
                        OptionBtn.Parent = ScrollList
                        OptionBtn.BackgroundColor3 = Library.Theme.Background
                        OptionBtn.Size = UDim2.new(1, -10, 0, 25)
                        OptionBtn.Position = UDim2.new(0, 5, 0, 0)
                        OptionBtn.AutoButtonColor = false
                        OptionBtn.Font = Enum.Font.Gotham
                        OptionBtn.Text = tostring(option)
                        OptionBtn.TextColor3 = Library.Theme.Text
                        OptionBtn.TextSize = 12
                        OptionBtn.ZIndex = 10003
                        
                        local OptCorner = Instance.new("UICorner")
                        OptCorner.CornerRadius = UDim.new(0, 4)
                        OptCorner.Parent = OptionBtn
                        
                        OptionBtn.MouseButton1Click:Connect(function()
                            Label.Text = Text .. ": " .. tostring(option)
                            Library.Flags[Flag] = option
                            Callback(option)
                            Close()
                            Library.OpenedDropdown = nil
                        end)
                    end
                end
                
                ScrollList.CanvasSize = UDim2.new(0, 0, 0, count * 27)
            end
            
            RefreshOptions()
            
            SearchBar:GetPropertyChangedSignal("Text"):Connect(function()
                RefreshOptions(SearchBar.Text)
            end)
            
            Library.Elements[Flag] = {
                Set = function(val)
                    if table.find(Options, val) then
                         Label.Text = Text .. ": " .. tostring(val)
                         Library.Flags[Flag] = val
                         Callback(val)
                    end
                end
            }

            local Debounce = false
            DropdownButton.MouseButton1Click:Connect(function()
                if Debounce then return end
                Debounce = true
                if ListFrame.Visible then
                    Close()
                    Library.OpenedDropdown = nil
                else
                    OpenList()
                end
                task.delay(0.2, function() Debounce = false end)
            end)
        end
        
        function Tab:CreateKeybind(options)
            local Text = options.Name or "Keybind"
            local Flag = options.Flag or Text
            local Default = options.Default or Enum.KeyCode.RightControl
            local Callback = options.Callback or function() end
            local TooltipText = options.Tooltip
            
            Library.Flags[Flag] = Default
            
            local KeybindFrame = Instance.new("Frame")
            KeybindFrame.Name = Text
            KeybindFrame.Parent = TabPage
            KeybindFrame.BackgroundColor3 = Library.Theme.Container
            KeybindFrame.Size = UDim2.new(1, 0, 0, 35)
            
            local KeybindCorner = Instance.new("UICorner")
            KeybindCorner.CornerRadius = UDim.new(0, 4)
            KeybindCorner.Parent = KeybindFrame
            
            local Label = Instance.new("TextLabel")
            Label.Parent = KeybindFrame
            Label.BackgroundTransparency = 1
            Label.Position = UDim2.new(0, 10, 0, 0)
            Label.Size = UDim2.new(1, -110, 1, 0)
            Label.Font = Enum.Font.Gotham
            Label.Text = Text
            Label.TextColor3 = Library.Theme.Text
            Label.TextSize = 12
            Label.TextXAlignment = Enum.TextXAlignment.Left
            
            local KeyButton = Instance.new("TextButton")
            KeyButton.Parent = KeybindFrame
            KeyButton.BackgroundColor3 = Library.Theme.Background
            KeyButton.Position = UDim2.new(1, -100, 0.5, -10)
            KeyButton.Size = UDim2.new(0, 90, 0, 20)
            KeyButton.AutoButtonColor = false
            KeyButton.Font = Enum.Font.Gotham
            KeyButton.Text = Default.Name
            KeyButton.TextColor3 = Library.Theme.Text
            KeyButton.TextSize = 11
            
            local KeyCorner = Instance.new("UICorner")
            KeyCorner.CornerRadius = UDim.new(0, 4)
            KeyCorner.Parent = KeyButton
            
            if TooltipText then MakeTooltip(KeybindFrame, TooltipText) end
            
            local Binding = false
            
            KeyButton.MouseButton1Click:Connect(function()
                Binding = true
                KeyButton.Text = "..."
                KeyButton.TextColor3 = Library.Theme.Accent
            end)
            
            Library:BindConnection(UserInputService.InputBegan:Connect(function(input)
                if Binding and input.UserInputType == Enum.UserInputType.Keyboard then
                    Library.Flags[Flag] = input.KeyCode
                    KeyButton.Text = input.KeyCode.Name
                    KeyButton.TextColor3 = Library.Theme.Text
                    Binding = false
                end
            end))
            
            Library.Elements[Flag] = {
                Set = function(val)
                    Library.Flags[Flag] = val
                    KeyButton.Text = val.Name
                end,
                Callback = Callback 
            }
        end
        
        function Tab:CreateColorPicker(options)
            local Text = options.Name or "Color Picker"
            local Flag = options.Flag or Text
            local Default = options.Default or Color3.fromRGB(255, 255, 255)
            local Callback = options.Callback or function() end
            local TooltipText = options.Tooltip
            
            Library.Flags[Flag] = Default
            
            local PickerFrame = Instance.new("Frame")
            PickerFrame.Name = Text
            PickerFrame.Parent = TabPage
            PickerFrame.BackgroundColor3 = Library.Theme.Container
            PickerFrame.Size = UDim2.new(1, 0, 0, 35)
            PickerFrame.ClipsDescendants = true
            
            local PickerCorner = Instance.new("UICorner")
            PickerCorner.CornerRadius = UDim.new(0, 4)
            PickerCorner.Parent = PickerFrame
            
            local Label = Instance.new("TextLabel")
            Label.Parent = PickerFrame
            Label.BackgroundTransparency = 1
            Label.Position = UDim2.new(0, 10, 0, 0)
            Label.Size = UDim2.new(1, -60, 0, 35)
            Label.Font = Enum.Font.Gotham
            Label.Text = Text
            Label.TextColor3 = Library.Theme.Text
            Label.TextSize = 12
            Label.TextXAlignment = Enum.TextXAlignment.Left
            
            local ColorPreview = Instance.new("Frame")
            ColorPreview.Parent = PickerFrame
            ColorPreview.BackgroundColor3 = Default
            ColorPreview.Position = UDim2.new(1, -45, 0.5, -10)
            ColorPreview.Size = UDim2.new(0, 35, 0, 20)
            
            local PreviewCorner = Instance.new("UICorner")
            PreviewCorner.CornerRadius = UDim.new(0, 4)
            PreviewCorner.Parent = ColorPreview
            
            local ToggleButton = Instance.new("TextButton")
            ToggleButton.Parent = PickerFrame
            ToggleButton.BackgroundTransparency = 1
            ToggleButton.Size = UDim2.new(1, 0, 0, 35)
            ToggleButton.Text = ""
            
            if TooltipText then MakeTooltip(PickerFrame, TooltipText) end
            
            -- Sliders Container
            local Container = Instance.new("Frame")
            Container.Parent = PickerFrame
            Container.BackgroundTransparency = 1
            Container.Position = UDim2.new(0, 0, 0, 40)
            Container.Size = UDim2.new(1, 0, 0, 100)
            Container.Visible = false
            
            local function CreateRGBSlider(name, yPos, colorComponent, updateFunc)
                local SliderBg = Instance.new("Frame")
                SliderBg.Parent = Container
                SliderBg.BackgroundColor3 = Library.Theme.Background
                SliderBg.Position = UDim2.new(0, 10, 0, yPos)
                SliderBg.Size = UDim2.new(1, -20, 0, 15)
                
                local SC = Instance.new("UICorner")
                SC.CornerRadius = UDim.new(0, 4)
                SC.Parent = SliderBg
                
                local Fill = Instance.new("Frame")
                Fill.Parent = SliderBg
                Fill.BackgroundColor3 = Library.Theme.Accent
                Fill.Size = UDim2.new(colorComponent/255, 0, 1, 0)
                
                local FC = Instance.new("UICorner")
                FC.CornerRadius = UDim.new(0, 4)
                FC.Parent = Fill
                
                local SLabel = Instance.new("TextLabel")
                SLabel.Parent = SliderBg
                SLabel.BackgroundTransparency = 1
                SLabel.Size = UDim2.new(1, 0, 1, 0)
                SLabel.Font = Enum.Font.GothamBold
                SLabel.Text = name
                SLabel.TextColor3 = Color3.new(1,1,1)
                SLabel.TextSize = 10
                SLabel.ZIndex = 2
                
                local Button = Instance.new("TextButton")
                Button.Parent = SliderBg
                Button.BackgroundTransparency = 1
                Button.Size = UDim2.new(1, 0, 1, 0)
                Button.Text = ""
                
                local dragging = false
                
                local function Update(input)
                    local pos = math.clamp((input.Position.X - SliderBg.AbsolutePosition.X) / SliderBg.AbsoluteSize.X, 0, 1)
                    Fill.Size = UDim2.new(pos, 0, 1, 0)
                    updateFunc(math.floor(pos * 255))
                end
                
                Button.InputBegan:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1 then
                        dragging = true
                        Update(input)
                    end
                end)
                
                UserInputService.InputChanged:Connect(function(input)
                    if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
                        Update(input)
                    end
                end)
                
                UserInputService.InputEnded:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
                end)
                
                return function(val)
                    Fill.Size = UDim2.new(val/255, 0, 1, 0)
                end
            end
            
            local r, g, b = Default.R * 255, Default.G * 255, Default.B * 255
            
            local function UpdateColor()
                local newColor = Color3.fromRGB(r, g, b)
                ColorPreview.BackgroundColor3 = newColor
                Library.Flags[Flag] = newColor
                Callback(newColor)
            end
            
            local setR = CreateRGBSlider("R", 0, r, function(val) r = val; UpdateColor() end)
            local setG = CreateRGBSlider("G", 25, g, function(val) g = val; UpdateColor() end)
            local setB = CreateRGBSlider("B", 50, b, function(val) b = val; UpdateColor() end)
            
            local Open = false
            ToggleButton.MouseButton1Click:Connect(function()
                Open = not Open
                if Open then
                     Library:Tween(PickerFrame, TweenInfo.new(0.3), {Size = UDim2.new(1, 0, 0, 130)})
                     Container.Visible = true
                else
                     Library:Tween(PickerFrame, TweenInfo.new(0.3), {Size = UDim2.new(1, 0, 0, 35)})
                     Container.Visible = false
                end
            end)
            
            Library.Elements[Flag] = {
                Set = function(val)
                     r, g, b = val.R * 255, val.G * 255, val.B * 255
                     setR(r); setG(g); setB(b)
                     UpdateColor()
                end
            }
        end
        
        -- Other components (Textbox, ColorPicker, MultiDropdown)
        
        return Tab
    end
    
    return Window
end

return Library
