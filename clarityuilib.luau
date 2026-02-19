-- Clarity UI Library
-- Made for Roblox Executors (Luau)
-- Focus: Beautiful, Clean, Smooth Animations, Developer Friendly

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local LocalPlayer = game:GetService("Players").LocalPlayer
local Mouse = LocalPlayer:GetMouse()
local HttpService = game:GetService("HttpService")

local Clarity = {
    Settings = {
        Name = "Clarity UI",
        Theme = {
            Main = Color3.fromRGB(25, 25, 25),
            Secondary = Color3.fromRGB(35, 35, 35),
            Stroke = Color3.fromRGB(50, 50, 50),
            Divider = Color3.fromRGB(45, 45, 45),
            Text = Color3.fromRGB(240, 240, 240),
            TextDark = Color3.fromRGB(150, 150, 150),
            Accent = Color3.fromRGB(0, 120, 215), -- Default Blue
            Success = Color3.fromRGB(40, 200, 80),
            Warning = Color3.fromRGB(220, 180, 40),
            Error = Color3.fromRGB(220, 50, 50)
        },
        Font = Enum.Font.Gotham,
        FontBold = Enum.Font.GothamBold,
        TextSize = 14,
        CornerRadius = UDim.new(0, 6)
    },
    Opened = true,
    Config = {}
}

-- Utility Functions
local function GetService(service)
    return game:GetService(service)
end

local function Create(class, properties)
    local instance = Instance.new(class)
    for property, value in pairs(properties) do
        instance[property] = value
    end
    return instance
end

local function MakeDraggable(gui)
    local dragging
    local dragInput
    local dragStart
    local startPos

    local function update(input)
        local delta = input.Position - dragStart
        gui.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end

    gui.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = gui.Position

            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    gui.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            update(input)
        end
    end)
end

local function Tween(instance, properties, duration, direction, style)
    local tweenInfo = TweenInfo.new(
        duration or 0.3,
        style or Enum.EasingStyle.Quart,
        direction or Enum.EasingDirection.Out
    )
    local tween = TweenService:Create(instance, tweenInfo, properties)
    tween:Play()
    return tween
end

-- Core UI Creation
function Clarity:CreateWindow(options)
    options = options or {}
    local windowName = options.Name or "Clarity UI"
    local configConfig = options.Configuration or {} 
    
    -- Main ScreenGui
    local ScreenGui = Create("ScreenGui", {
        Name = "ClarityLib",
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        IgnoreGuiInset = true
    })

    -- Parent to safe container
    if gethui then
        ScreenGui.Parent = gethui()
    elseif game:GetService("CoreGui") then
        ScreenGui.Parent = game:GetService("CoreGui")
    else
        ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    end

    -- Main Container
    local MainFrame = Create("Frame", {
        Name = "MainFrame",
        Parent = ScreenGui,
        BackgroundColor3 = Clarity.Settings.Theme.Main,
        BorderSizePixel = 0,
        Position = UDim2.new(0.5, -275, 0.5, -175),
        Size = UDim2.new(0, 550, 0, 350),
        ClipsDescendants = true
    })
    
    Create("UICorner", { CornerRadius = Clarity.Settings.CornerRadius, Parent = MainFrame })
    Create("UIStroke", {
        Parent = MainFrame,
        Color = Clarity.Settings.Theme.Stroke,
        Thickness = 1
    })

    MakeDraggable(MainFrame)

    -- Sidebar (Left)
    local Sidebar = Create("Frame", {
        Name = "Sidebar",
        Parent = MainFrame,
        BackgroundColor3 = Clarity.Settings.Theme.Secondary,
        BorderSizePixel = 0,
        Size = UDim2.new(0, 160, 1, 0)
    })
    
    Create("UICorner", { CornerRadius = Clarity.Settings.CornerRadius, Parent = Sidebar })
    
    -- Fix Sidebar Corner (Right Side needs to be straight mostly, but we can just overlay)
    local SidebarCover = Create("Frame", {
        Name = "Cover",
        Parent = Sidebar,
        BackgroundColor3 = Clarity.Settings.Theme.Secondary,
        BorderSizePixel = 0,
        Position = UDim2.new(1, -10, 0, 0),
        Size = UDim2.new(0, 10, 1, 0),
        ZIndex = 1
    })

    -- Title
    local TitleLabel = Create("TextLabel", {
        Name = "Title",
        Parent = Sidebar,
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 15, 0, 15),
        Size = UDim2.new(1, -30, 0, 25),
        Font = Clarity.Settings.FontBold,
        Text = windowName,
        TextColor3 = Clarity.Settings.Theme.Text,
        TextSize = 18,
        TextXAlignment = Enum.TextXAlignment.Left
    })

    -- Tab Container
    local TabContainer = Create("ScrollingFrame", {
        Name = "TabContainer",
        Parent = Sidebar,
        Active = true,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Position = UDim2.new(0, 0, 0, 60),
        Size = UDim2.new(1, 0, 1, -70),
        CanvasSize = UDim2.new(0, 0, 0, 0),
        ScrollBarThickness = 2,
        ScrollBarImageColor3 = Clarity.Settings.Theme.Accent
    })
    
    Create("UIListLayout", {
        Parent = TabContainer,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 5)
    })
    
    Create("UIPadding", {
        Parent = TabContainer,
        PaddingLeft = UDim.new(0, 10),
        PaddingRight = UDim.new(0, 10)
    })

    -- Content Area (Right)
    local ContentArea = Create("Frame", {
        Name = "ContentArea",
        Parent = MainFrame,
        BackgroundColor3 = Clarity.Settings.Theme.Main,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Position = UDim2.new(0, 160, 0, 0),
        Size = UDim2.new(1, -160, 1, 0)
    })
    
    local PagesFolder = Create("Folder", { Name = "Pages", Parent = ContentArea })

    -- Window Object
    local Window = {}
    local FirstTab = true

    function Window:CreateTab(name, icon)
        local Tab = {}
        
        -- Tab Button
        local TabButton = Create("TextButton", {
            Name = name .. "Tab",
            Parent = TabContainer,
            BackgroundColor3 = Clarity.Settings.Theme.Main,
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Size = UDim2.new(1, 0, 0, 32),
            Font = Clarity.Settings.Font,
            Text = "",
            AutoButtonColor = false
        })
        
        Create("UICorner", { CornerRadius = UDim.new(0, 4), Parent = TabButton })

        local TabLabel = Create("TextLabel", {
            Name = "Label",
            Parent = TabButton,
            BackgroundTransparency = 1,
            Position = UDim2.new(0, 10, 0, 0), -- Icon offset here if needed
            Size = UDim2.new(1, -10, 1, 0),
            Font = Clarity.Settings.Font,
            Text = name,
            TextColor3 = Clarity.Settings.Theme.TextDark,
            TextSize = 13,
            TextXAlignment = Enum.TextXAlignment.Left
        })

        if icon then
            -- Implement icon logic if needed
            -- Adjust TabLabel position
        end

        -- Page Container
        local Page = Create("ScrollingFrame", {
            Name = name .. "Page",
            Parent = PagesFolder,
            Active = true,
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Position = UDim2.new(0, 0, 0, 0),
            Size = UDim2.new(1, 0, 1, 0),
            CanvasSize = UDim2.new(0, 0, 0, 0),
            ScrollBarThickness = 3,
            ScrollBarImageColor3 = Clarity.Settings.Theme.Accent,
            Visible = false
        })
        
        Create("UIPadding", {
            Parent = Page,
            PaddingTop = UDim.new(0, 15),
            PaddingLeft = UDim.new(0, 15),
            PaddingRight = UDim.new(0, 15),
            PaddingBottom = UDim.new(0, 15)
        })
        
        local PageLayout = Create("UIListLayout", {
            Parent = Page,
            SortOrder = Enum.SortOrder.LayoutOrder,
            Padding = UDim.new(0, 10)
        })

        -- Auto resize canvas
        PageLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            Page.CanvasSize = UDim2.new(0, 0, 0, PageLayout.AbsoluteContentSize.Y + 30)
        end)

        -- Tab Selection Logic
        local function Activate()
            for _, p in pairs(PagesFolder:GetChildren()) do
                p.Visible = false
            end
            Page.Visible = true

            for _, t in pairs(TabContainer:GetChildren()) do
                if t:IsA("TextButton") then
                    Tween(t.Label, {TextColor3 = Clarity.Settings.Theme.TextDark}, 0.2)
                    Tween(t, {BackgroundTransparency = 1}, 0.2)
                end
            end
            
            Tween(TabLabel, {TextColor3 = Clarity.Settings.Theme.Text}, 0.2)
            Tween(TabButton, {BackgroundTransparency = 0}, 0.2)
            Tween(TabButton, {BackgroundColor3 = Color3.fromRGB(40, 40, 40)}, 0.2) -- Active Tab BG
        end

        TabButton.MouseButton1Click:Connect(Activate)

        if FirstTab then
            FirstTab = false
            Activate()
        end

        -- Section Logic
        function Tab:CreateSection(sectionName)
            local Section = {}
            
            local SectionFrame = Create("Frame", {
                Name = sectionName .. "Section",
                Parent = Page,
                BackgroundColor3 = Clarity.Settings.Theme.Secondary,
                BorderSizePixel = 0,
                Size = UDim2.new(1, 0, 0, 0), -- Auto Resize
                ClipsDescendants = true
            })

            Create("UICorner", { CornerRadius = UDim.new(0, 6), Parent = SectionFrame })
            Create("UIStroke", {
                Parent = SectionFrame,
                Color = Clarity.Settings.Theme.Stroke,
                Thickness = 1
            })

            local SectionTitle = Create("TextLabel", {
                Name = "Title",
                Parent = SectionFrame,
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 10, 0, 8),
                Size = UDim2.new(1, -20, 0, 20),
                Font = Clarity.Settings.FontBold,
                Text = sectionName,
                TextColor3 = Clarity.Settings.Theme.Text,
                TextSize = 14,
                TextXAlignment = Enum.TextXAlignment.Left
            })

            local Container = Create("Frame", {
                Name = "Container",
                Parent = SectionFrame,
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 0, 0, 35),
                Size = UDim2.new(1, 0, 0, 0)
            })

            local ContainerLayout = Create("UIListLayout", {
                Parent = Container,
                SortOrder = Enum.SortOrder.LayoutOrder,
                Padding = UDim.new(0, 6)
            })

            Create("UIPadding", {
                Parent = Container,
                PaddingLeft = UDim.new(0, 10),
                PaddingRight = UDim.new(0, 10),
                PaddingBottom = UDim.new(0, 10)
            })

            -- Resize Section Height
            local function UpdateSize()
                local contentSize = ContainerLayout.AbsoluteContentSize.Y
                Container.Size = UDim2.new(1, 0, 0, contentSize)
                Tween(SectionFrame, {Size = UDim2.new(1, 0, 0, contentSize + 45)}, 0.2)
            end
            
            ContainerLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(UpdateSize)
            
            -- ELEMENTS
            
            -- Button
            function Section:CreateButton(cfg)
                local btnName = cfg.Name or "Button"
                local callback = cfg.Callback or function() end

                local ButtonFrame = Create("TextButton", {
                    Name = "Button",
                    Parent = Container,
                    BackgroundColor3 = Clarity.Settings.Theme.Main,
                    BorderSizePixel = 0,
                    Size = UDim2.new(1, 0, 0, 32),
                    Font = Clarity.Settings.Font,
                    Text = "",
                    AutoButtonColor = false
                })

                Create("UICorner", { CornerRadius = UDim.new(0, 4), Parent = ButtonFrame })
                Create("UIStroke", {
                    Parent = ButtonFrame,
                    Color = Clarity.Settings.Theme.Stroke,
                    Thickness = 1
                })

                local BtnStartColor = Clarity.Settings.Theme.Main
                local BtnHoverColor = Color3.fromRGB(30, 30, 30)

                local Title = Create("TextLabel", {
                    Parent = ButtonFrame,
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 1, 0),
                    Font = Clarity.Settings.Font,
                    Text = btnName,
                    TextColor3 = Clarity.Settings.Theme.Text,
                    TextSize = 13
                })

                ButtonFrame.MouseEnter:Connect(function()
                     Tween(ButtonFrame, {BackgroundColor3 = BtnHoverColor}, 0.2)
                end)

                ButtonFrame.MouseLeave:Connect(function()
                    Tween(ButtonFrame, {BackgroundColor3 = BtnStartColor}, 0.2)
                end)

                ButtonFrame.MouseButton1Click:Connect(function()
                    Tween(Title, {TextSize = 11}, 0.1)
                    wait(0.1)
                    Tween(Title, {TextSize = 13}, 0.1)
                    callback()
                end)
            end

            -- Toggle
            function Section:CreateToggle(cfg)
                local toggleName = cfg.Name or "Toggle"
                local default = cfg.Default or false
                local callback = cfg.Callback or function() end
                local flag = cfg.Flag

                local currentState = default
                if flag then
                    if Clarity.Config[flag] ~= nil then
                        currentState = Clarity.Config[flag]
                    else
                        Clarity.Config[flag] = currentState
                    end
                end

                local ToggleFrame = Create("TextButton", {
                    Name = "Toggle",
                    Parent = Container,
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 0, 32),
                    Text = "",
                    AutoButtonColor = false
                })

                local Title = Create("TextLabel", {
                    Parent = ToggleFrame,
                    BackgroundTransparency = 1,
                    Position = UDim2.new(0, 0, 0, 0),
                    Size = UDim2.new(0.8, 0, 1, 0),
                    Font = Clarity.Settings.Font,
                    Text = toggleName,
                    TextColor3 = Clarity.Settings.Theme.Text,
                    TextSize = 13,
                    TextXAlignment = Enum.TextXAlignment.Left
                })

                local SwitchBg = Create("Frame", {
                    Parent = ToggleFrame,
                    BackgroundColor3 = currentState and Clarity.Settings.Theme.Accent or Color3.fromRGB(60, 60, 60),
                    BorderSizePixel = 0,
                    Position = UDim2.new(1, -40, 0.5, -10),
                    Size = UDim2.new(0, 40, 0, 20)
                })
                
                Create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = SwitchBg })

                local SwitchCircle = Create("Frame", {
                    Parent = SwitchBg,
                    BackgroundColor3 = Color3.fromRGB(255, 255, 255),
                    BorderSizePixel = 0,
                    Position = currentState and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8),
                    Size = UDim2.new(0, 16, 0, 16)
                })
                
                Create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = SwitchCircle })

                local function UpdateToggle()
                    Tween(SwitchBg, {BackgroundColor3 = currentState and Clarity.Settings.Theme.Accent or Color3.fromRGB(60, 60, 60)}, 0.2)
                    Tween(SwitchCircle, {Position = currentState and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)}, 0.2)
                    if flag then Clarity.Config[flag] = currentState end
                    callback(currentState)
                end

                ToggleFrame.MouseButton1Click:Connect(function()
                    currentState = not currentState
                    UpdateToggle()
                end)
                
                -- Initialize (run callback initially if needed, usually better not to unless explicit)
                -- callback(currentState)
            end

            -- Slider
            function Section:CreateSlider(cfg)
                local sliderName = cfg.Name or "Slider"
                local minVal = cfg.Min or 0
                local maxVal = cfg.Max or 100
                local defaultVal = cfg.Default or minVal
                local callback = cfg.Callback or function() end
                local flag = cfg.Flag

                local Value = defaultVal
                if flag then
                    if Clarity.Config[flag] ~= nil then
                        Value = Clarity.Config[flag]
                    else
                        Clarity.Config[flag] = Value
                    end
                end

                local SliderFrame = Create("Frame", {
                    Name = "Slider",
                    Parent = Container,
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 0, 45)
                })

                local Title = Create("TextLabel", {
                    Parent = SliderFrame,
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 0, 20),
                    Font = Clarity.Settings.Font,
                    Text = sliderName,
                    TextColor3 = Clarity.Settings.Theme.Text,
                    TextSize = 13,
                    TextXAlignment = Enum.TextXAlignment.Left
                })

                local ValueLabel = Create("TextLabel", {
                    Parent = SliderFrame,
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 0, 20),
                    Font = Clarity.Settings.Font,
                    Text = tostring(Value),
                    TextColor3 = Clarity.Settings.Theme.TextDark,
                    TextSize = 13,
                    TextXAlignment = Enum.TextXAlignment.Right
                })

                local SliderBg = Create("Frame", {
                    Parent = SliderFrame,
                    BackgroundColor3 = Color3.fromRGB(60, 60, 60),
                    BorderSizePixel = 0,
                    Position = UDim2.new(0, 0, 0, 28),
                    Size = UDim2.new(1, 0, 0, 6)
                })
                
                Create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = SliderBg })

                local SliderFill = Create("Frame", {
                    Parent = SliderBg,
                    BackgroundColor3 = Clarity.Settings.Theme.Accent,
                    BorderSizePixel = 0,
                    Size = UDim2.new((Value - minVal) / (maxVal - minVal), 0, 1, 0)
                })
                
                Create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = SliderFill })

                local dragging = false

                local function UpdateSlider(input)
                    local pos = UDim2.new(math.clamp((input.Position.X - SliderBg.AbsolutePosition.X) / SliderBg.AbsoluteSize.X, 0, 1), 0, 1, 0)
                    local preciseValue = minVal + ((maxVal - minVal) * pos.X.Scale)
                    Value = math.floor(preciseValue) -- Integer slider by default
                    
                    Tween(SliderFill, {Size = pos}, 0.1)
                    ValueLabel.Text = tostring(Value)
                    if flag then Clarity.Config[flag] = Value end
                    callback(Value)
                end

                SliderBg.InputBegan:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                        dragging = true
                        UpdateSlider(input)
                    end
                end)

                UserInputService.InputChanged:Connect(function(input)
                    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                        UpdateSlider(input)
                    end
                end)

                UserInputService.InputEnded:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                        dragging = false
                    end
                end)
            end

            -- Textbox
            function Section:CreateInput(cfg)
                local inputName = cfg.Name or "Input"
                local placeholder = cfg.Placeholder or "Type here..."
                local callback = cfg.Callback or function() end
                local flag = cfg.Flag
                
                local InputFrame = Create("Frame", {
                    Name = "Input",
                    Parent = Container,
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 0, 45)
                })

                local Title = Create("TextLabel", {
                    Parent = InputFrame,
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 0, 20),
                    Font = Clarity.Settings.Font,
                    Text = inputName,
                    TextColor3 = Clarity.Settings.Theme.Text,
                    TextSize = 13,
                    TextXAlignment = Enum.TextXAlignment.Left
                })

                local InputBg = Create("Frame", {
                    Parent = InputFrame,
                    BackgroundColor3 = Clarity.Settings.Theme.Main,
                    BorderSizePixel = 0,
                    Position = UDim2.new(0, 0, 0, 25),
                    Size = UDim2.new(1, 0, 0, 30)
                })
                
                Create("UICorner", { CornerRadius = UDim.new(0, 4), Parent = InputBg })
                Create("UIStroke", { Parent = InputBg, Color = Clarity.Settings.Theme.Stroke, Thickness = 1 })

                local TextBox = Create("TextBox", {
                    Parent = InputBg,
                    BackgroundTransparency = 1,
                    Position = UDim2.new(0, 8, 0, 0),
                    Size = UDim2.new(1, -16, 1, 0),
                    Font = Clarity.Settings.Font,
                    PlaceholderText = placeholder,
                    Text = "",
                    TextColor3 = Clarity.Settings.Theme.Text,
                    PlaceholderColor3 = Clarity.Settings.Theme.TextDark,
                    TextSize = 13,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    ClearTextOnFocus = false
                })

                TextBox.FocusLost:Connect(function(enterPressed)
                    if flag then Clarity.Config[flag] = TextBox.Text end
                    callback(TextBox.Text)
                end)
            end
            
            -- Dropdown
            function Section:CreateDropdown(cfg)
                local dropdownName = cfg.Name or "Dropdown"
                local options = cfg.Options or {}
                local default = cfg.Default or options[1]
                local multi = cfg.Multi or false
                local callback = cfg.Callback or function() end
                local flag = cfg.Flag
                
                local Dropdown = {}
                local expanded = false
                local selected = multi and (type(default) == "table" and default or {default}) or default

                if flag then
                    if Clarity.Config[flag] ~= nil then
                        selected = Clarity.Config[flag]
                    else
                        Clarity.Config[flag] = selected
                    end
                end

                local DropdownFrame = Create("Frame", {
                    Name = "Dropdown",
                    Parent = Container,
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 0, 50),
                    ClipsDescendants = true
                })
                
                local Title = Create("TextLabel", {
                    Parent = DropdownFrame,
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 0, 20),
                    Font = Clarity.Settings.Font,
                    Text = dropdownName,
                    TextColor3 = Clarity.Settings.Theme.Text,
                    TextSize = 13,
                    TextXAlignment = Enum.TextXAlignment.Left
                })

                local MainBtn = Create("TextButton", {
                    Parent = DropdownFrame,
                    BackgroundColor3 = Clarity.Settings.Theme.Main,
                    BorderSizePixel = 0,
                    Position = UDim2.new(0, 0, 0, 25),
                    Size = UDim2.new(1, 0, 0, 30),
                    AutoButtonColor = false,
                    Text = ""
                })
                
                Create("UICorner", { CornerRadius = UDim.new(0, 4), Parent = MainBtn })
                Create("UIStroke", { Parent = MainBtn, Color = Clarity.Settings.Theme.Stroke, Thickness = 1 })
                
                local SelectedLabel = Create("TextLabel", {
                    Parent = MainBtn,
                    BackgroundTransparency = 1,
                    Position = UDim2.new(0, 10, 0, 0),
                    Size = UDim2.new(1, -30, 1, 0),
                    Font = Clarity.Settings.Font,
                    Text = multi and table.concat(selected, ", ") or selected,
                    TextColor3 = Clarity.Settings.Theme.Text,
                    TextSize = 13,
                    TextXAlignment = Enum.TextXAlignment.Left
                })
                
                local Icon = Create("ImageLabel", {
                    Parent = MainBtn,
                    BackgroundTransparency = 1,
                    Position = UDim2.new(1, -25, 0.5, -10),
                    Size = UDim2.new(0, 20, 0, 20),
                    Image = "rbxassetid://6034818372", -- Arrow down
                    ImageColor3 = Clarity.Settings.Theme.TextDark
                })
                
                local OptionsContainer = Create("Frame", {
                    Parent = DropdownFrame,
                    BackgroundTransparency = 1,
                    Position = UDim2.new(0, 0, 0, 60),
                    Size = UDim2.new(1, 0, 0, 0),
                    ClipsDescendants = true
                })
                
                local OptionsLayout = Create("UIListLayout", {
                    Parent = OptionsContainer,
                    SortOrder = Enum.SortOrder.LayoutOrder,
                    Padding = UDim.new(0, 2)
                })
                
                local function RenderOptions()
                    for _, child in pairs(OptionsContainer:GetChildren()) do
                        if child:IsA("TextButton") then child:Destroy() end
                    end
                    
                    for _, opt in pairs(options) do
                        local OptBtn = Create("TextButton", {
                            Parent = OptionsContainer,
                            BackgroundColor3 = Clarity.Settings.Theme.Main,
                            BackgroundTransparency = 0.5,
                            BorderSizePixel = 0,
                            Size = UDim2.new(1, 0, 0, 25),
                            Font = Clarity.Settings.Font,
                            Text = opt,
                            TextColor3 = Clarity.Settings.Theme.TextDark,
                            TextSize = 13
                        })
                        Create("UICorner", { CornerRadius = UDim.new(0, 4), Parent = OptBtn })
                        
                        OptBtn.MouseButton1Click:Connect(function()
                            if multi then
                                if table.find(selected, opt) then
                                    table.remove(selected, table.find(selected, opt))
                                else
                                    table.insert(selected, opt)
                                end
                                SelectedLabel.Text = table.concat(selected, ", ")
                                if flag then Clarity.Config[flag] = selected end
                                callback(selected)
                            else
                                selected = opt
                                SelectedLabel.Text = opt
                                expanded = false
                                Tween(DropdownFrame, {Size = UDim2.new(1, 0, 0, 50)}, 0.2)
                                Tween(Icon, {Rotation = 0}, 0.2)
                                if flag then Clarity.Config[flag] = selected end
                                callback(opt)
                            end
                        end)
                    end
                end
                
                RenderOptions()
                
                MainBtn.MouseButton1Click:Connect(function()
                    expanded = not expanded
                    if expanded then
                        local optionsHeight = (#options * 27)
                        Tween(DropdownFrame, {Size = UDim2.new(1, 0, 0, 60 + optionsHeight)}, 0.2)
                        OptionsContainer.Size = UDim2.new(1, 0, 0, optionsHeight)
                        Tween(Icon, {Rotation = 180}, 0.2)
                    else
                        Tween(DropdownFrame, {Size = UDim2.new(1, 0, 0, 50)}, 0.2)
                        Tween(Icon, {Rotation = 0}, 0.2)
                    end
                end)
                
                function Dropdown:Refresh(newOptions)
                    options = newOptions
                    RenderOptions()
                end
                
                return Dropdown
            end
            
            -- Color Picker
            function Section:CreateColorPicker(cfg)
                 local cpName = cfg.Name or "Color"
                 local default = cfg.Default or Color3.new(1,1,1)
                 local callback = cfg.Callback or function() end
                 local flag = cfg.Flag
                 
                 local currentColor = default
                 if flag then
                     if Clarity.Config[flag] ~= nil then
                        local colCfg = Clarity.Config[flag]
                        if typeof(colCfg) == "table" then
                            currentColor = Color3.fromRGB(colCfg[1], colCfg[2], colCfg[3])
                        else
                            currentColor = colCfg
                        end
                     else
                        Clarity.Config[flag] = {math.floor(currentColor.R*255), math.floor(currentColor.G*255), math.floor(currentColor.B*255)}
                     end
                 end
                 
                 local PickerFrame = Create("Frame", {
                     Parent = Container,
                     BackgroundTransparency = 1,
                     Size = UDim2.new(1, 0, 0, 32),
                     ClipsDescendants = true
                 })
                 
                 local Title = Create("TextLabel", {
                     Parent = PickerFrame,
                     BackgroundTransparency = 1,
                     Size = UDim2.new(0.6, 0, 0, 32),
                     Font = Clarity.Settings.Font,
                     Text = cpName,
                     TextColor3 = Clarity.Settings.Theme.Text,
                     TextSize = 13,
                     TextXAlignment = Enum.TextXAlignment.Left
                 })
                 
                 local ColorButton = Create("TextButton", {
                     Parent = PickerFrame,
                     BackgroundColor3 = currentColor,
                     Position = UDim2.new(1, -40, 0, 4),
                     Size = UDim2.new(0, 40, 0, 24),
                     Text = "",
                     AutoButtonColor = false
                 })
                 
                 Create("UICorner", { CornerRadius = UDim.new(0, 4), Parent = ColorButton })
                 Create("UIStroke", { Parent = ColorButton, Color = Clarity.Settings.Theme.Stroke, Thickness = 1 })

                 -- Expanded logic
                 local expanded = false
                 local SlidersFrame = Create("Frame", {
                     Parent = PickerFrame,
                     BackgroundTransparency = 1,
                     Position = UDim2.new(0, 0, 0, 35),
                     Size = UDim2.new(1, 0, 0, 100),
                     Visible = true
                 })
                 
                 local function CreateRGBSlider(name, yPos, colorVal, updateFunc)
                     local SFrame = Create("Frame", {
                         Parent = SlidersFrame,
                         BackgroundTransparency = 1,
                         Position = UDim2.new(0, 0, 0, yPos),
                         Size = UDim2.new(1, 0, 0, 30)
                     })
                     
                     local SLabel = Create("TextLabel", {
                         Parent = SFrame,
                         BackgroundTransparency = 1,
                         Size = UDim2.new(0, 20, 1, 0),
                         Text = name,
                         TextColor3 = Clarity.Settings.Theme.Text,
                         Font = Clarity.Settings.Font,
                         TextSize = 12
                     })
                     
                     local SBg = Create("Frame", {
                         Parent = SFrame,
                         BackgroundColor3 = Color3.fromRGB(60,60,60),
                         BorderSizePixel = 0,
                         Position = UDim2.new(0, 25, 0.5, -2),
                         Size = UDim2.new(1, -30, 0, 4)
                     })
                     Create("UICorner", { CornerRadius = UDim.new(1,0), Parent = SBg })
                     
                     local SFill = Create("Frame", {
                         Parent = SBg,
                         BackgroundColor3 = name == "R" and Color3.new(1,0.2,0.2) or (name == "G" and Color3.new(0.2,1,0.2) or Color3.new(0.2,0.2,1)),
                         BorderSizePixel = 0,
                         Size = UDim2.new(colorVal, 0, 1, 0)
                     })
                     Create("UICorner", { CornerRadius = UDim.new(1,0), Parent = SFill })
                     
                     local sDragging = false
                     
                     local function update(input)
                         local pos = math.clamp((input.Position.X - SBg.AbsolutePosition.X) / SBg.AbsoluteSize.X, 0, 1)
                         SFill.Size = UDim2.new(pos, 0, 1, 0)
                         updateFunc(pos)
                     end
                     
                     SBg.InputBegan:Connect(function(input)
                         if input.UserInputType == Enum.UserInputType.MouseButton1 then sDragging = true; update(input) end
                     end)
                     UserInputService.InputChanged:Connect(function(input)
                         if sDragging and input.UserInputType == Enum.UserInputType.MouseMovement then update(input) end
                     end)
                     UserInputService.InputEnded:Connect(function(input)
                         if input.UserInputType == Enum.UserInputType.MouseButton1 then sDragging = false end
                     end)
                     
                     return SFill -- Return to update externally if needed
                 end

                 local rVal, gVal, bVal = currentColor.R, currentColor.G, currentColor.B

                 local function UpdateColor()
                     currentColor = Color3.new(rVal, gVal, bVal)
                     ColorButton.BackgroundColor3 = currentColor
                     
                     if flag then 
                        Clarity.Config[flag] = {math.floor(rVal*255), math.floor(gVal*255), math.floor(bVal*255)}
                     end
                     callback(currentColor)
                 end

                 CreateRGBSlider("R", 0, rVal, function(v) rVal = v; UpdateColor() end)
                 CreateRGBSlider("G", 35, gVal, function(v) gVal = v; UpdateColor() end)
                 CreateRGBSlider("B", 70, bVal, function(v) bVal = v; UpdateColor() end)
                 
                 ColorButton.MouseButton1Click:Connect(function()
                     expanded = not expanded
                     if expanded then
                         Tween(PickerFrame, {Size = UDim2.new(1, 0, 0, 140)}, 0.2)
                     else
                         Tween(PickerFrame, {Size = UDim2.new(1, 0, 0, 32)}, 0.2)
                     end
                 end)
            end

            -- Keybind
            function Section:CreateKeybind(cfg)
                local keybindName = cfg.Name or "Keybind"
                local default = cfg.Default or Enum.KeyCode.E
                local callback = cfg.Callback or function() end

                local waiting = false
                local currentKey = default

                local KeybindFrame = Create("Frame", {
                    Name = "Keybind",
                    Parent = Container,
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 0, 32)
                })

                local Title = Create("TextLabel", {
                    Parent = KeybindFrame,
                    BackgroundTransparency = 1,
                    Size = UDim2.new(0.6, 0, 1, 0),
                    Font = Clarity.Settings.Font,
                    Text = keybindName,
                    TextColor3 = Clarity.Settings.Theme.Text,
                    TextSize = 13,
                    TextXAlignment = Enum.TextXAlignment.Left
                })

                local KeyDisplay = Create("TextButton", {
                    Parent = KeybindFrame,
                    BackgroundColor3 = Clarity.Settings.Theme.Main,
                    Position = UDim2.new(0.63, 0, 0.15, 0),
                    Size = UDim2.new(0.37, 0, 0.7, 0),
                    Font = Clarity.Settings.Font,
                    Text = currentKey.Name,
                    TextColor3 = Clarity.Settings.Theme.TextDark,
                    TextSize = 12,
                    AutoButtonColor = false
                })
                
                Create("UICorner", { CornerRadius = UDim.new(0, 4), Parent = KeyDisplay })
                Create("UIStroke", { Parent = KeyDisplay, Color = Clarity.Settings.Theme.Stroke, Thickness = 1 })

                KeyDisplay.MouseButton1Click:Connect(function()
                    waiting = true
                    KeyDisplay.Text = "..."
                end)

                UserInputService.InputBegan:Connect(function(input)
                    if waiting then
                       if input.UserInputType == Enum.UserInputType.Keyboard then
                           if input.KeyCode ~= Enum.KeyCode.Escape then
                               currentKey = input.KeyCode
                               KeyDisplay.Text = currentKey.Name
                               callback(currentKey)
                           else
                               KeyDisplay.Text = currentKey.Name
                           end
                           waiting = false
                       end
                    end
                end)
            end

            return Section
        end

        return Tab
    end

    -- Close Logic
    UserInputService.InputBegan:Connect(function(input)
        if input.KeyCode == Enum.KeyCode.RightControl then
            Clarity.Opened = not Clarity.Opened
            ScreenGui.Enabled = Clarity.Opened
        end
    end)

    return Window
end

-- Notification System
function Clarity:Notify(options)
    -- To be implemented: A nice notification appearing at bottom right
    options = options or {}
    local Title = options.Title or "Notification"
    local Content = options.Content or "Message"
    local Duration = options.Duration or 3
    
    -- Check for existing container
    local NotifyGui = game.CoreGui:FindFirstChild("ClarityNotify")
    if not NotifyGui then
        NotifyGui = Create("ScreenGui", { Name = "ClarityNotify", Parent = game.CoreGui })
    end
    
    local container = NotifyGui:FindFirstChild("Container")
    if not container then
        container = Create("Frame", {
            Name = "Container",
            Parent = NotifyGui,
            BackgroundTransparency = 1,
            Position = UDim2.new(1, -320, 1, -20),
            Size = UDim2.new(0, 300, 1, 0),
            AnchorPoint = Vector2.new(0, 1)
        })
        Create("UIListLayout", {
            Parent = container,
            SortOrder = Enum.SortOrder.LayoutOrder,
            VerticalAlignment = Enum.VerticalAlignment.Bottom,
            Padding = UDim.new(0, 10)
        })
    end
    
    local NotifyFrame = Create("Frame", {
        Parent = container,
        BackgroundColor3 = Clarity.Settings.Theme.Main,
        Size = UDim2.new(1, 0, 0, 0), -- Start Height 0
        ClipsDescendants = true,
        BackgroundTransparency = 1 -- Start transparent
    })
    
    Create("UICorner", { CornerRadius = UDim.new(0, 6), Parent = NotifyFrame })
    Create("UIStroke", { Parent = NotifyFrame, Color = Clarity.Settings.Theme.Stroke, Thickness = 1 })
    
    local NotifyTitle = Create("TextLabel", {
        Parent = NotifyFrame,
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 10, 0, 8),
        Size = UDim2.new(1, -20, 0, 20),
        Font = Clarity.Settings.FontBold,
        Text = Title,
        TextColor3 = Clarity.Settings.Theme.Text,
        TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTransparency = 1
    })
    
    local NotifyContent = Create("TextLabel", {
        Parent = NotifyFrame,
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 10, 0, 28),
        Size = UDim2.new(1, -20, 0, 40),
        Font = Clarity.Settings.Font,
        Text = Content,
        TextColor3 = Clarity.Settings.Theme.TextDark,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextWrapped = true,
        TextTransparency = 1
    })
    
    -- Animation In
    Tween(NotifyFrame, {Size = UDim2.new(1, 0, 0, 80), BackgroundTransparency = 0}, 0.4)
    Tween(NotifyTitle, {TextTransparency = 0}, 0.4)
    Tween(NotifyContent, {TextTransparency = 0}, 0.4)
    
    task.delay(Duration, function()
        -- Animation Out
        Tween(NotifyTitle, {TextTransparency = 1}, 0.4)
        Tween(NotifyContent, {TextTransparency = 1}, 0.4)
        local t = Tween(NotifyFrame, {Size = UDim2.new(1, 0, 0, 0), BackgroundTransparency = 1}, 0.4)
        
        t.Completed:Connect(function()
            NotifyFrame:Destroy()
        end)
    end)
end

function Clarity:SaveConfig(ConfigName)
    if not isfolder("ClarityConfigs") then
        makefolder("ClarityConfigs")
    end
    writefile("ClarityConfigs/" .. ConfigName .. ".json", HttpService:JSONEncode(Clarity.Config))
    Clarity:Notify({Title = "Config", Content = "Saved config: " .. ConfigName, Duration = 3})
end

function Clarity:LoadConfig(ConfigName)
    if isfile("ClarityConfigs/" .. ConfigName .. ".json") then
        local success, decoded = pcall(function()
            return HttpService:JSONDecode(readfile("ClarityConfigs/" .. ConfigName .. ".json"))
        end)
        if success then
            Clarity.Config = decoded
            Clarity:Notify({Title = "Config", Content = "Loaded config: " .. ConfigName, Duration = 3})
            -- Note: To apply config visibly, UI often needs a refresh logic or checking config on creation.
            -- With this system, creating the window AFTER loading config works best.
        else
             Clarity:Notify({Title = "Config", Content = "Failed to decode config", Duration = 3})
        end
    else
        Clarity:Notify({Title = "Config", Content = "Config not found", Duration = 3})
    end
end

return Clarity
