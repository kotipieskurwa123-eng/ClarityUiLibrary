local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")

local Library = {}
Library.Flags = {}
Library.Elements = {} 
Library.Connections = {}
Library.Settings = {
    LowPerformance = false,
    UIKey = Enum.KeyCode.RightControl
}
Library.ZIndex = 1

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
    Library.Connections = {}
end

local ActiveTweens = {}
function Library:Tween(obj, info, props)
    if Library.Settings.LowPerformance then
        for prop, val in pairs(props) do
            obj[prop] = val
        end
        return
    end
    
    -- basic caching logic could be complex, for now we ensure we don't spam
    -- if ActiveTweens[obj] then ActiveTweens[obj]:Cancel() end
    
    local tween = TweenService:Create(obj, info, props)
    tween:Play()
    -- ActiveTweens[obj] = tween
    return tween
end

--// Protected GUI
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
        -- UI Toggle
        if input.KeyCode == Library.Settings.UIKey then
            ScreenGui.Enabled = not ScreenGui.Enabled
        end
        
        -- Keybind System
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
            
            -- Bounds Check (Simple)
            local viewport = workspace.CurrentCamera.ViewportSize
            -- Optional: Clamp to screen
            -- newX = math.clamp(newX, 0, viewport.X - frame.AbsoluteSize.X)
            -- newY = math.clamp(newY, 0, viewport.Y - frame.AbsoluteSize.Y)
            
            Library:Tween(frame, TweenInfo.new(0.05, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                Position = UDim2.new(startPos.X.Scale, newX, startPos.Y.Scale, newY)
            })
        end
    end))
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

function Library:Notify(options)
    local Title = options.Title or "Notification"
    local Text = options.Text or "Text"
    local Duration = options.Duration or 3
    
    local NotifyFrame = Instance.new("Frame")
    NotifyFrame.Name = "NotifyFrame"
    NotifyFrame.BackgroundColor3 = Library.Theme.Header
    NotifyFrame.Size = UDim2.new(1, 0, 0, 0) -- Auto Size later
    NotifyFrame.AutomaticSize = Enum.AutomaticSize.Y
    NotifyFrame.BorderSizePixel = 0
    NotifyFrame.ClipsDescendants = true
    NotifyFrame.Parent = NotificationContainer
    NotifyFrame.ZIndex = 100
    
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
    TitleLabel.ZIndex = 101
    
    local CloseBtn = Instance.new("TextButton")
    CloseBtn.Parent = NotifyFrame
    CloseBtn.BackgroundTransparency = 1
    CloseBtn.Position = UDim2.new(1, -20, 0, 5)
    CloseBtn.Size = UDim2.new(0, 15, 0, 15)
    CloseBtn.Text = "X"
    CloseBtn.TextColor3 = Library.Theme.TextDark
    CloseBtn.TextSize = 11
    CloseBtn.Font = Enum.Font.Gotham
    CloseBtn.ZIndex = 102
    
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
    TextLabel.ZIndex = 101
    
    local ProgressBar = Instance.new("Frame")
    ProgressBar.Name = "Timer"
    ProgressBar.Parent = NotifyFrame
    ProgressBar.BackgroundColor3 = Library.Theme.Accent
    ProgressBar.BorderSizePixel = 0
    ProgressBar.Position = UDim2.new(0, 0, 1, -2)
    ProgressBar.Size = UDim2.new(1, 0, 0, 2)
    ProgressBar.ZIndex = 101
    
    -- Padding for bottom
    local UIPadding = Instance.new("UIPadding")
    UIPadding.Parent = NotifyFrame
    UIPadding.PaddingBottom = UDim.new(0, 10)
    
    local function Close()
        Library:Tween(NotifyFrame, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Size = UDim2.new(1, 0, 0, 0), Position = UDim2.new(1.1, 0, 0, 0)})
        task.wait(0.3)
        NotifyFrame:Destroy()
    end
    
    CloseBtn.MouseButton1Click:Connect(Close)
    
    -- Animation In (Slide from right or fadeup? Slide up)
    -- Start size 0, auto resizes but we tween Size
    -- Because AutomaticSize acts instantly, we might just tween Transparency or use a container
    -- For simplicity, let's just tween visual properties or assume height is ok
    -- Better: Tween container size from 0 to target
    
    -- Just ensure it's visible
    NotifyFrame.Size = UDim2.new(1, 0, 0, 0)
    local targetHeight = 50 + TextLabel.TextBounds.Y
    Library:Tween(NotifyFrame, TweenInfo.new(0.3), {Size = UDim2.new(1, 0, 0, targetHeight)})
    
    Library:Tween(ProgressBar, TweenInfo.new(Duration, Enum.EasingStyle.Linear), {Size = UDim2.new(0, 0, 0, 2)})
    
    task.delay(Duration, Close)
end

--// Config System (Robust)
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
    MainFrame.ClipsDescendants = true -- Support Fade logic if needed, but might break dropdowns if they go out. 
    -- Actually for dropdowns to work, ClipsDescendants must be false or the dropdown must be in Overlay.
    MainFrame.ClipsDescendants = false 
    
    -- Fade In
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
    TitleLabel.Size = UDim2.new(1, -20, 1, 0)
    TitleLabel.Font = Enum.Font.GothamBold
    TitleLabel.Text = Name
    TitleLabel.TextColor3 = Library.Theme.Text
    TitleLabel.TextSize = 14
    TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
    
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
    
    CloseButton.MouseButton1Click:Connect(function()
        Library:Cleanup()
        ScreenGui:Destroy()
    end)
    
    EnableDragging(MainFrame, Header)
    
    -- Content Area
    local Content = Instance.new("Frame")
    Content.Name = "Content"
    Content.Parent = MainFrame
    Content.BackgroundColor3 = Library.Theme.Background
    Content.BackgroundTransparency = 1
    Content.Position = UDim2.new(0, 0, 0, 35)
    Content.Size = UDim2.new(1, 0, 1, -35)
    
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
        
        -- Auto Canvas Resize
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
            local SectionLabel = Instance.new("TextLabel")
            SectionLabel.Name = "Section"
            SectionLabel.Parent = TabPage
            SectionLabel.BackgroundTransparency = 1
            SectionLabel.Size = UDim2.new(1, 0, 0, 25)
            SectionLabel.Font = Enum.Font.GothamBold
            SectionLabel.Text = text
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
        end

        function Tab:CreateButton(options)
            local Text = options.Name or "Button"
            local Callback = options.Callback or function() end
            
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
            end)
            
            ButtonFrame.MouseLeave:Connect(function()
                Library:Tween(ButtonFrame, TweenInfo.new(0.2), {BackgroundColor3 = Library.Theme.Container})
            end)
            
            local Debounce = false
            ButtonFrame.MouseButton1Click:Connect(function()
                if Debounce then return end
                Debounce = true
                Ripple(ButtonFrame)
                Callback()
                task.delay(0.2, function() Debounce = false end)
            end)
        end
        
        function Tab:CreateToggle(options)
            local Text = options.Name or "Toggle"
            local Flag = options.Flag or Text
            local Default = options.Default or false
            local Callback = options.Callback or function() end
            
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
            local Range = math.max(Max - Min, 1)
            SliderFill.Size = UDim2.new((Default - Min) / Range, 0, 1, 0)
            
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
                local percent = (clamped - Min) / Range
                SliderFill.Size = UDim2.new(percent, 0, 1, 0)
                ValueLabel.Text = tostring(clamped)
                Library.Flags[Flag] = clamped
                Callback(clamped)
            end
            
            Library.Elements[Flag] = {
                Set = function(val)
                    UpdateSlider(val)
                end
            }

            local dragging = false
            
            SliderButton.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                    dragging = true
                    
                    local InitialPos = UserInputService:GetMouseLocation().X
                    -- Calculate relative
                    -- GetMouseLocation is screen space (absolute), but we need to map to bar
                    -- For consistent drag, we use mouse location always
                    
                    local function UpdateFromMouse()
                         local location = UserInputService:GetMouseLocation()
                         local pos = math.clamp((location.X - SliderBar.AbsolutePosition.X) / SliderBar.AbsoluteSize.X, 0, 1)
                         SliderFill.Size = UDim2.new(pos, 0, 1, 0)
                         local val = math.floor(Min + (Range * pos))
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
            
            Library.ZIndex = Library.ZIndex + 1
            local CurrentZIndex = Library.ZIndex
            
            local DropdownFrame = Instance.new("Frame")
            DropdownFrame.Name = Text
            DropdownFrame.Parent = TabPage
            DropdownFrame.BackgroundColor3 = Library.Theme.Container
            DropdownFrame.Size = UDim2.new(1, 0, 0, 35)
            DropdownFrame.ClipsDescendants = false
            DropdownFrame.ZIndex = CurrentZIndex
            
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
            
            local ListFrame = Instance.new("ScrollingFrame")
            ListFrame.Parent = DropdownFrame
            ListFrame.BackgroundColor3 = Library.Theme.Container
            ListFrame.BorderSizePixel = 0
            ListFrame.Position = UDim2.new(0, 0, 1, 5)
            ListFrame.Size = UDim2.new(1, 0, 0, 0)
            ListFrame.Visible = false
            ListFrame.ScrollBarThickness = 2
            ListFrame.ZIndex = CurrentZIndex + 10 -- Ensure list is above
            
            local ListCorner = Instance.new("UICorner")
            ListCorner.CornerRadius = UDim.new(0, 4)
            ListCorner.Parent = ListFrame
            
            local UIListLayout_Drop = Instance.new("UIListLayout")
            UIListLayout_Drop.Parent = ListFrame
            UIListLayout_Drop.SortOrder = Enum.SortOrder.LayoutOrder
            UIListLayout_Drop.Padding = UDim.new(0, 2)
            
            local UIPadding_Drop = Instance.new("UIPadding")
            UIPadding_Drop.Parent = ListFrame
            UIPadding_Drop.PaddingTop = UDim.new(0, 5)
            UIPadding_Drop.PaddingBottom = UDim.new(0, 5)
            UIPadding_Drop.PaddingLeft = UDim.new(0, 5)
            UIPadding_Drop.PaddingRight = UDim.new(0, 5)
            
            local Open = false
            
            local function RefreshOptions()
                for _, child in pairs(ListFrame:GetChildren()) do
                    if child:IsA("TextButton") then child:Destroy() end
                end
                
                for _, option in pairs(Options) do
                    local OptionBtn = Instance.new("TextButton")
                    OptionBtn.Parent = ListFrame
                    OptionBtn.BackgroundColor3 = Library.Theme.Background
                    OptionBtn.Size = UDim2.new(1, 0, 0, 25)
                    OptionBtn.AutoButtonColor = false
                    OptionBtn.Font = Enum.Font.Gotham
                    OptionBtn.Text = tostring(option)
                    OptionBtn.TextColor3 = Library.Theme.Text
                    OptionBtn.TextSize = 12
                    OptionBtn.ZIndex = ListFrame.ZIndex
                    
                    local OptCorner = Instance.new("UICorner")
                    OptCorner.CornerRadius = UDim.new(0, 4)
                    OptCorner.Parent = OptionBtn
                    
                    OptionBtn.MouseButton1Click:Connect(function()
                        Open = false
                        Label.Text = Text .. ": " .. tostring(option)
                        Library.Flags[Flag] = option
                        Callback(option)
                        Library:Tween(ListFrame, TweenInfo.new(0.3), {Size = UDim2.new(1, 0, 0, 0)})
                        Library:Tween(Arrow, TweenInfo.new(0.3), {Rotation = 0})
                        task.wait(0.3)
                        ListFrame.Visible = false
                    end)
                end
            end
            
            RefreshOptions()
            
            -- Sync Registry
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
                Open = not Open
                if Open then
                    ListFrame.Visible = true
                    Library:Tween(ListFrame, TweenInfo.new(0.3), {Size = UDim2.new(1, 0, 0, math.min(#Options * 27 + 10, 150))})
                    Library:Tween(Arrow, TweenInfo.new(0.3), {Rotation = 180})
                else
                    Library:Tween(ListFrame, TweenInfo.new(0.3), {Size = UDim2.new(1, 0, 0, 0)})
                    Library:Tween(Arrow, TweenInfo.new(0.3), {Rotation = 0})
                    task.wait(0.3)
                    ListFrame.Visible = false
                end
                task.delay(0.2, function() Debounce = false end)
            end)
        end
        
        function Tab:CreateMultiDropdown(options)
            local Text = options.Name or "Multi Dropdown"
            local Flag = options.Flag or Text
            local Options = options.Options or {}
            local Default = options.Default or {} -- Table of strings
            local Callback = options.Callback or function() end
            
            Library.Flags[Flag] = Default
            
            Library.ZIndex = Library.ZIndex + 1
            local CurrentZIndex = Library.ZIndex
            
            local DropdownFrame = Instance.new("Frame")
            DropdownFrame.Name = Text
            DropdownFrame.Parent = TabPage
            DropdownFrame.BackgroundColor3 = Library.Theme.Container
            DropdownFrame.Size = UDim2.new(1, 0, 0, 35)
            DropdownFrame.ClipsDescendants = false
            DropdownFrame.ZIndex = CurrentZIndex
            
            local DropdownCorner = Instance.new("UICorner")
            DropdownCorner.CornerRadius = UDim.new(0, 4)
            DropdownCorner.Parent = DropdownFrame
            
            local Label = Instance.new("TextLabel")
            Label.Parent = DropdownFrame
            Label.BackgroundTransparency = 1
            Label.Position = UDim2.new(0, 10, 0, 0)
            Label.Size = UDim2.new(1, -40, 0, 35)
            Label.Font = Enum.Font.Gotham
            Label.Text = Text .. ": ..."
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
            
            local ListFrame = Instance.new("ScrollingFrame")
            ListFrame.Parent = DropdownFrame
            ListFrame.BackgroundColor3 = Library.Theme.Container
            ListFrame.BorderSizePixel = 0
            ListFrame.Position = UDim2.new(0, 0, 1, 5)
            ListFrame.Size = UDim2.new(1, 0, 0, 0)
            ListFrame.Visible = false
            ListFrame.ScrollBarThickness = 2
            ListFrame.ZIndex = CurrentZIndex + 10
            
            local ListCorner = Instance.new("UICorner")
            ListCorner.CornerRadius = UDim.new(0, 4)
            ListCorner.Parent = ListFrame
            
            local UIListLayout_Drop = Instance.new("UIListLayout")
            UIListLayout_Drop.Parent = ListFrame
            UIListLayout_Drop.SortOrder = Enum.SortOrder.LayoutOrder
            UIListLayout_Drop.Padding = UDim.new(0, 2)
            
            local UIPadding_Drop = Instance.new("UIPadding")
            UIPadding_Drop.Parent = ListFrame
            UIPadding_Drop.PaddingTop = UDim.new(0, 5)
            UIPadding_Drop.PaddingBottom = UDim.new(0, 5)
            UIPadding_Drop.PaddingLeft = UDim.new(0, 5)
            UIPadding_Drop.PaddingRight = UDim.new(0, 5)
            
            -- Helper to check if option is selected
            local function IsSelected(opt)
                for _, v in pairs(Library.Flags[Flag]) do
                    if v == opt then return true end
                end
                return false
            end
            
            local function UpdateLabel()
                local count = #Library.Flags[Flag]
                if count == 0 then
                    Label.Text = Text .. ": None"
                else
                    Label.Text = Text .. ": " .. table.concat(Library.Flags[Flag], ", ")
                end
            end
            
            -- Refresh list
            local function RefreshOptions()
                for _, child in pairs(ListFrame:GetChildren()) do
                    if child:IsA("TextButton") then child:Destroy() end
                end
                
                for _, option in pairs(Options) do
                    local OptionBtn = Instance.new("TextButton")
                    OptionBtn.Parent = ListFrame
                    OptionBtn.BackgroundColor3 = IsSelected(option) and Library.Theme.Accent or Library.Theme.Background
                    OptionBtn.Size = UDim2.new(1, 0, 0, 25)
                    OptionBtn.AutoButtonColor = false
                    OptionBtn.Font = Enum.Font.Gotham
                    OptionBtn.Text = tostring(option)
                    OptionBtn.TextColor3 = IsSelected(option) and Color3.new(1,1,1) or Library.Theme.Text
                    OptionBtn.TextSize = 12
                    OptionBtn.ZIndex = ListFrame.ZIndex
                    
                    local OptCorner = Instance.new("UICorner")
                    OptCorner.CornerRadius = UDim.new(0, 4)
                    OptCorner.Parent = OptionBtn
                    
                    OptionBtn.MouseButton1Click:Connect(function()
                        if IsSelected(option) then
                            -- Remove
                            for i, v in pairs(Library.Flags[Flag]) do
                                if v == option then
                                    table.remove(Library.Flags[Flag], i)
                                    break
                                end
                            end
                            TweenService:Create(OptionBtn, TweenInfo.new(0.2), {BackgroundColor3 = Library.Theme.Background, TextColor3 = Library.Theme.Text}):Play()
                        else
                            -- Add
                            table.insert(Library.Flags[Flag], option)
                            TweenService:Create(OptionBtn, TweenInfo.new(0.2), {BackgroundColor3 = Library.Theme.Accent, TextColor3 = Color3.new(1,1,1)}):Play()
                        end
                        UpdateLabel()
                        Callback(Library.Flags[Flag])
                    end)
                end
            end
            
            RefreshOptions()
            UpdateLabel()
            
            local Open = false
            local Debounce = false
            DropdownButton.MouseButton1Click:Connect(function()
                if Debounce then return end
                Debounce = true
                Open = not Open
                if Open then
                     ListFrame.Visible = true
                    Library:Tween(ListFrame, TweenInfo.new(0.3), {Size = UDim2.new(1, 0, 0, math.min(#Options * 27 + 10, 150))})
                    Library:Tween(Arrow, TweenInfo.new(0.3), {Rotation = 180})
                else
                    Library:Tween(ListFrame, TweenInfo.new(0.3), {Size = UDim2.new(1, 0, 0, 0)})
                    Library:Tween(Arrow, TweenInfo.new(0.3), {Rotation = 0})
                    task.wait(0.3)
                    ListFrame.Visible = false
                end
                task.delay(0.2, function() Debounce = false end)
            end)
        end
        
        function Tab:CreateKeybind(options)
            local Text = options.Name or "Keybind"
            local Flag = options.Flag or Text
            local Default = options.Default or Enum.KeyCode.RightControl
            local Callback = options.Callback or function() end
            
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
        
        function Tab:CreateTextbox(options)
            local Text = options.Name or "Textbox"
            local Flag = options.Flag or Text
            local Default = options.Default or ""
            local Callback = options.Callback or function() end
            
            Library.Flags[Flag] = Default
            
            local TextboxFrame = Instance.new("Frame")
            TextboxFrame.Name = Text
            TextboxFrame.Parent = TabPage
            TextboxFrame.BackgroundColor3 = Library.Theme.Container
            TextboxFrame.Size = UDim2.new(1, 0, 0, 35)
            
            local Corner = Instance.new("UICorner")
            Corner.CornerRadius = UDim.new(0, 4)
            Corner.Parent = TextboxFrame
            
            local Label = Instance.new("TextLabel")
            Label.Parent = TextboxFrame
            Label.BackgroundTransparency = 1
            Label.Position = UDim2.new(0, 10, 0, 0)
            Label.Size = UDim2.new(0, 100, 1, 0)
            Label.Font = Enum.Font.Gotham
            Label.Text = Text
            Label.TextColor3 = Library.Theme.Text
            Label.TextSize = 12
            Label.TextXAlignment = Enum.TextXAlignment.Left
            
            local Input = Instance.new("TextBox")
            Input.Parent = TextboxFrame
            Input.BackgroundColor3 = Library.Theme.Background
            Input.Position = UDim2.new(1, -160, 0.5, -10)
            Input.Size = UDim2.new(0, 150, 0, 20)
            Input.Font = Enum.Font.Gotham
            Input.Text = Default
            Input.TextColor3 = Library.Theme.Text
            Input.TextSize = 12
            Input.PlaceholderText = "Type here..."
            
            local InputCorner = Instance.new("UICorner")
            InputCorner.CornerRadius = UDim.new(0, 4)
            InputCorner.Parent = Input
            
            Input.FocusLost:Connect(function(enterPressed)
                Library.Flags[Flag] = Input.Text
                Callback(Input.Text)
            end)
            
            Library.Elements[Flag] = {
                Set = function(val)
                    Library.Flags[Flag] = val
                    Input.Text = val
                    Callback(val)
                end
            }
        end
        
        function Tab:CreateColorPicker(options)
            local Text = options.Name or "Color Picker"
            local Flag = options.Flag or Text
            local Default = options.Default or Color3.fromRGB(255, 255, 255)
            local Callback = options.Callback or function() end
            
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
            Label.Size = UDim2.new(1, -50, 0, 35)
            Label.Font = Enum.Font.Gotham
            Label.Text = Text
            Label.TextColor3 = Library.Theme.Text
            Label.TextSize = 12
            Label.TextXAlignment = Enum.TextXAlignment.Left
            
            local ColorPreview = Instance.new("TextButton")
            ColorPreview.Parent = PickerFrame
            ColorPreview.BackgroundColor3 = Default
            ColorPreview.Position = UDim2.new(1, -40, 0, 7)
            ColorPreview.Size = UDim2.new(0, 30, 0, 21)
            ColorPreview.Text = ""
            ColorPreview.AutoButtonColor = false
            
            local PreviewCorner = Instance.new("UICorner")
            PreviewCorner.CornerRadius = UDim.new(0, 4)
            PreviewCorner.Parent = ColorPreview
            
            -- Picker Logic
            local ColorPickerContainer = Instance.new("Frame")
            ColorPickerContainer.Parent = PickerFrame
            ColorPickerContainer.BackgroundColor3 = Library.Theme.Background
            ColorPickerContainer.Position = UDim2.new(0, 10, 0, 40)
            ColorPickerContainer.Size = UDim2.new(1, -20, 0, 150)
            ColorPickerContainer.Visible = true 
            
            local ContainerCorner = Instance.new("UICorner")
            ContainerCorner.CornerRadius = UDim.new(0, 4)
            ContainerCorner.Parent = ColorPickerContainer
            
            -- SV Image
            local SVImage = Instance.new("ImageButton")
            SVImage.Parent = ColorPickerContainer
            SVImage.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
            SVImage.Position = UDim2.new(0, 10, 0, 10)
            SVImage.Size = UDim2.new(1, -40, 0, 130)
            SVImage.Image = "rbxassetid://4155801252"
            
            local SVCursor = Instance.new("Frame")
            SVCursor.Parent = SVImage
            SVCursor.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
            SVCursor.BorderColor3 = Color3.fromRGB(0,0,0)
            SVCursor.Size = UDim2.new(0, 4, 0, 4)
            SVCursor.AnchorPoint = Vector2.new(0.5, 0.5)
            SVCursor.Position = UDim2.new(0.5, 0, 0.5, 0)
            
            -- Hue Bar
            local HueImage = Instance.new("ImageButton")
            HueImage.Parent = ColorPickerContainer
            HueImage.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
            HueImage.Position = UDim2.new(1, -20, 0, 10)
            HueImage.Size = UDim2.new(0, 10, 0, 130)
            HueImage.ImageTransparency = 1 
            
            local HueGradient = Instance.new("UIGradient")
            HueGradient.Rotation = 90
            HueGradient.Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0.00, Color3.fromRGB(255, 0, 0)),
                ColorSequenceKeypoint.new(0.17, Color3.fromRGB(255, 0, 255)),
                ColorSequenceKeypoint.new(0.33, Color3.fromRGB(0, 0, 255)),
                ColorSequenceKeypoint.new(0.50, Color3.fromRGB(0, 255, 255)),
                ColorSequenceKeypoint.new(0.67, Color3.fromRGB(0, 255, 0)),
                ColorSequenceKeypoint.new(0.83, Color3.fromRGB(255, 255, 0)),
                ColorSequenceKeypoint.new(1.00, Color3.fromRGB(255, 0, 0))
            })
            HueGradient.Parent = HueImage
            
            local HueCursor = Instance.new("Frame")
            HueCursor.Parent = HueImage
            HueCursor.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
            HueCursor.BorderColor3 = Color3.fromRGB(0,0,0)
            HueCursor.Size = UDim2.new(1, 0, 0, 2)
            HueCursor.AnchorPoint = Vector2.new(0, 0.5)
            
            local Hue, Sat, Val = Color3.toHSV(Default)
            
            local function UpdateColor()
                local NewColor = Color3.fromHSV(Hue, Sat, Val)
                ColorPreview.BackgroundColor3 = NewColor
                SVImage.ImageColor3 = Color3.fromHSV(Hue, 1, 1)
                SVCursor.BackgroundColor3 = NewColor
                Library.Flags[Flag] = NewColor
                Callback(NewColor)
            end
            
            local function UpdateSV(input)
                local pos = Vector2.new(
                    math.clamp((input.Position.X - SVImage.AbsolutePosition.X) / SVImage.AbsoluteSize.X, 0, 1),
                    math.clamp((input.Position.Y - SVImage.AbsolutePosition.Y) / SVImage.AbsoluteSize.Y, 0, 1)
                )
                SVCursor.Position = UDim2.new(pos.X, 0, pos.Y, 0)
                Sat = pos.X
                Val = 1 - pos.Y
                UpdateColor()
            end
            
            local function UpdateHue(input)
                local pos = math.clamp((input.Position.Y - HueImage.AbsolutePosition.Y) / HueImage.AbsoluteSize.Y, 0, 1)
                HueCursor.Position = UDim2.new(0, 0, pos, 0)
                Hue = 1 - pos
                UpdateColor()
            end
            
            Library.Elements[Flag] = {
                Set = function(val)
                    Hue, Sat, Val = Color3.toHSV(val)
                    UpdateColor()
                end
            }

            local draggingSV = false
            local draggingHue = false
            
            SVImage.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                    draggingSV = true
                    UpdateSV(input)
                    
                    local inputChanged
                    inputChanged = UserInputService.InputChanged:Connect(function(moveInput)
                         if draggingSV and (moveInput.UserInputType == Enum.UserInputType.MouseMovement or moveInput.UserInputType == Enum.UserInputType.Touch) then
                            UpdateSV(moveInput)
                         end
                    end)
                    
                    local inputEnded
                    inputEnded = UserInputService.InputEnded:Connect(function(endInput)
                         if endInput.UserInputType == Enum.UserInputType.MouseButton1 or endInput.UserInputType == Enum.UserInputType.Touch then
                            draggingSV = false
                            inputChanged:Disconnect()
                            inputEnded:Disconnect()
                         end
                    end)
                end
            end)
            
            HueImage.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                    draggingHue = true
                    UpdateHue(input)
                    
                    local inputChanged
                     inputChanged = UserInputService.InputChanged:Connect(function(moveInput)
                         if draggingHue and (moveInput.UserInputType == Enum.UserInputType.MouseMovement or moveInput.UserInputType == Enum.UserInputType.Touch) then
                            UpdateHue(moveInput)
                         end
                    end)
                    
                    local inputEnded
                    inputEnded = UserInputService.InputEnded:Connect(function(endInput)
                         if endInput.UserInputType == Enum.UserInputType.MouseButton1 or endInput.UserInputType == Enum.UserInputType.Touch then
                            draggingHue = false
                            inputChanged:Disconnect()
                            inputEnded:Disconnect()
                         end
                    end)
                end
            end)
            
            local Open = false
            ColorPreview.MouseButton1Click:Connect(function()
                Open = not Open
                if Open then
                    Library:Tween(PickerFrame, TweenInfo.new(0.3), {Size = UDim2.new(1, 0, 0, 200)})
                else
                    Library:Tween(PickerFrame, TweenInfo.new(0.3), {Size = UDim2.new(1, 0, 0, 35)})
                end
            end)
            
            UpdateColor()
        end
        
        return Tab
    end
    
    return Window
end

return Library
