print("[CloverStartup] Starting camera, skill, and health update")
local env = getgenv()
local savedConfig = type(env.VampireFarmConfig) == "table"
    and env.VampireFarmConfig or {}
local savedNoRender = savedConfig.NoRender
local savedAutoStat = savedConfig.AutoStatEnabled
local savedAutoSkill = savedConfig.AutoSkillEnabled
local previousStop = env.StopVampireFarm
if type(previousStop) == "function" then
    pcall(previousStop)
end
env.VampireFarmConfig = savedConfig
savedConfig.NoRender = savedNoRender
savedConfig.AutoStatEnabled = savedAutoStat
savedConfig.AutoSkillEnabled = savedAutoSkill
local launchToken = {}
env.VampireFarmLaunchToken = launchToken

if not game:IsLoaded() then
    repeat task.wait() until game:IsLoaded()
end
if env.VampireFarmLaunchToken ~= launchToken then return end

-- Auto Attach distance and offsets can be changed in the Attach tab.
-- Toggle 3D rendering: getgenv().ToggleVampireNoRender()
-- Choose a stat and toggle Auto Stat in the on-screen controls.
-- Select weapon skills and owned grimoire spells in the skill dropdown.
-- Set the mob HP threshold and toggle local instant-kill attempts in the UI.
-- Drag the title bar to move the UI. Bind a key in the UI to show/hide it.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
-- Input handling belongs to the UI adapter.
local player = Players.LocalPlayer
local entities = workspace:WaitForChild("Entities")
local enemies = entities:WaitForChild("Enemies")
local spawns = entities:WaitForChild("Spawns")
local spawn = spawns:WaitForChild("VampireSoldierSpawn")
local action = game:GetService("ReplicatedStorage")
    :WaitForChild("ReplicatedPackage")
    :WaitForChild("Remotes")
    :WaitForChild("action")
local fetch = action.Parent:WaitForChild("fetch")
local CheckService = require(game.ReplicatedStorage.ReplicatedPackage.LocalServices.CheckService)
local spellCatalog = game.ReplicatedStorage.ReplicatedPackage.LocalServices.Database:WaitForChild("Spell")
if env.VampireFarmLaunchToken ~= launchToken then return end
local spellNames = {}
for _, entry in ipairs(spellCatalog:GetDescendants()) do
    if entry:IsA("ModuleScript") then
        spellNames[entry.Name] = true
    end
end

local ATTACK_INTERVAL = 0.65
local SKILL_RETRY_INTERVAL = 1.5
local DEFAULT_FOLLOW_DISTANCE = 5
local DEFAULT_KILL_THRESHOLD_PERCENT = 89
local DEFAULT_APEX_KILL_THRESHOLD_PERCENT = 50
local DEFAULT_PRIME_APEX_KILL_THRESHOLD_PERCENT = 35
local golem = {
    Name = "Aetherstone Golem",
    DefaultKillThreshold = 50,
    NextSummonAt = 0,
    LastWarningAt = -math.huge,
    Candidates = setmetatable({}, {__mode = "k"}),
}
local SIMULATION_RADIUS = 3000
local RADIUS_INTERVAL = 0.05

local PRIORITY = {
    ["Corrupted Elder Vampire"] = 4,
    ["Elder Vampire"] = 3,
    ["Vampire Elite"] = 2,
    ["Vampire Soldier"] = 1,
}

-- SealCatalog marks bosses for automatic Boss Farm targeting.
-- Only regular enemies enter the Mob Farm dropdown.
local SealCatalog = require(game.ReplicatedStorage.ReplicatedPackage.Modules
    :WaitForChild("SealCatalog"))
local MOB_NAME_SEED = {}
local MOB_NAMES = {}
local BOSS_NAME_SEED = {}
local BOSS_NAMES = {}
local APEX_NAMES = {Apex = true, ["Prime Apex"] = true}
for _, entry in ipairs(SealCatalog.Seals) do
    if APEX_NAMES[entry.name] or entry.name == golem.Name then
        -- Apex targets have their own farm section in the Boss tab.
    elseif entry.boss == true then
        if not BOSS_NAMES[entry.name] then
            BOSS_NAMES[entry.name] = true
            table.insert(BOSS_NAME_SEED, entry.name)
        end
    elseif not PRIORITY[entry.name] and not MOB_NAMES[entry.name] then
        MOB_NAMES[entry.name] = true
        table.insert(MOB_NAME_SEED, entry.name)
    end
end
table.sort(MOB_NAME_SEED)
table.sort(BOSS_NAME_SEED)

local MOB_SPAWN_NAMES = {
    ["Bandit"] = "Bandit2Spawn",
    ["Desert Claw"] = "DesertClaw1",
    ["Lowly Goblin"] = "LowlyGoblin",
    ["Mage Apprentice"] = "FireMageSpawn",
    ["Seasoned Mercenary"] = "SeasonedMercenarySpawn",
    ["Werewolf Soldier"] = "WerewolfSoldierSpawn",
    ["Wolf"] = "WolfSpawn",
}

if type(env.VampireFarmConfig) ~= "table" then
    env.VampireFarmConfig = {}
end
if tonumber(env.VampireFarmConfig.FollowDistance) == nil then
    env.VampireFarmConfig.FollowDistance = DEFAULT_FOLLOW_DISTANCE
end
if tonumber(env.VampireFarmConfig.XOffset) == nil then
    env.VampireFarmConfig.XOffset = 0
end
if tonumber(env.VampireFarmConfig.YOffset) == nil then
    env.VampireFarmConfig.YOffset = 0
end
if type(env.VampireFarmConfig.IgnoreRotation) ~= "boolean" then
    env.VampireFarmConfig.IgnoreRotation = false
end
if type(env.VampireFarmConfig.RotateTowards) ~= "boolean" then
    env.VampireFarmConfig.RotateTowards = true
end
if type(env.VampireFarmConfig.PreventVoiding) ~= "boolean" then
    env.VampireFarmConfig.PreventVoiding = false
end
if type(env.VampireFarmConfig.AutoAttachEnabled) ~= "boolean" then
    env.VampireFarmConfig.AutoAttachEnabled = true
end
if type(env.VampireFarmConfig.AIBreakerEnabled) ~= "boolean" then
    env.VampireFarmConfig.AIBreakerEnabled = false
end
local AI_BREAKER_TYPES = {
    Aggressive = true,
    Circular = true,
    OPassive = true,
    Passive = true,
}
if not AI_BREAKER_TYPES[env.VampireFarmConfig.AIBreakerType] then
    env.VampireFarmConfig.AIBreakerType = "OPassive"
end
if type(env.VampireFarmConfig.AutoChestLootEnabled) ~= "boolean" then
    env.VampireFarmConfig.AutoChestLootEnabled = true
end
local savedChestRadius = tonumber(env.VampireFarmConfig.ChestLootRadius)
if not savedChestRadius or savedChestRadius ~= savedChestRadius
    or savedChestRadius == math.huge or savedChestRadius == -math.huge then
    savedChestRadius = 120
end
env.VampireFarmConfig.ChestLootRadius = math.clamp(savedChestRadius, 10, 500)
if type(env.VampireFarmConfig.NoRender) ~= "boolean" then
    env.VampireFarmConfig.NoRender = false
end
local VALID_STATS = {STR = true, DEX = true, INT = true, CON = true}
if not VALID_STATS[env.VampireFarmConfig.AutoStatTarget] then
    env.VampireFarmConfig.AutoStatTarget = "STR"
end
if type(env.VampireFarmConfig.AutoStatEnabled) ~= "boolean" then
    env.VampireFarmConfig.AutoStatEnabled = false
end
if type(env.VampireFarmConfig.AutoSkillEnabled) ~= "boolean" then
    env.VampireFarmConfig.AutoSkillEnabled = false
end
if type(env.VampireFarmConfig.SelectedSkills) ~= "table" then
    env.VampireFarmConfig.SelectedSkills = {}
end
if type(env.VampireFarmConfig.BossFarmEnabled) ~= "boolean" then
    env.VampireFarmConfig.BossFarmEnabled = true
end
if type(env.VampireFarmConfig.ApexFarmEnabled) ~= "boolean" then
    env.VampireFarmConfig.ApexFarmEnabled = true
end
if type(env.VampireFarmConfig.PrimeApexFarmEnabled) ~= "boolean" then
    env.VampireFarmConfig.PrimeApexFarmEnabled = env.VampireFarmConfig.ApexFarmEnabled
end
if type(env.VampireFarmConfig.GolemFarmEnabled) ~= "boolean" then
    env.VampireFarmConfig.GolemFarmEnabled = true
end
if type(env.VampireFarmConfig.SelectedBosses) ~= "table" then
    env.VampireFarmConfig.SelectedBosses = {}
    for _, name in ipairs(BOSS_NAME_SEED) do
        env.VampireFarmConfig.SelectedBosses[name] = true
    end
end
for name in pairs(env.VampireFarmConfig.SelectedBosses) do
    if not BOSS_NAMES[name] then
        env.VampireFarmConfig.SelectedBosses[name] = nil
    end
end
if type(env.VampireFarmConfig.SelectedMobs) ~= "table" then
    env.VampireFarmConfig.SelectedMobs = {}
end
for name in pairs(env.VampireFarmConfig.SelectedMobs) do
    if not MOB_NAMES[name] then
        env.VampireFarmConfig.SelectedMobs[name] = nil
    end
end
if type(env.VampireFarmConfig.MobPriorities) ~= "table" then
    env.VampireFarmConfig.MobPriorities = {}
end
if type(env.VampireFarmConfig.MobSpawnOverrides) ~= "table" then
    env.VampireFarmConfig.MobSpawnOverrides = {}
end
if env.VampireFarmConfig.FarmMode ~= "Vampire"
    and env.VampireFarmConfig.FarmMode ~= "Mob"
    and env.VampireFarmConfig.FarmMode ~= "Off" then
    env.VampireFarmConfig.FarmMode = "Vampire"
end
local configuredToggleKey = env.VampireFarmConfig.ToggleKeybind
if type(configuredToggleKey) ~= "string"
    or not Enum.KeyCode[configuredToggleKey]
    or Enum.KeyCode[configuredToggleKey] == Enum.KeyCode.Unknown then
    env.VampireFarmConfig.ToggleKeybind = "RightShift"
end
if type(env.VampireFarmConfig.InstantKillEnabled) ~= "boolean" then
    env.VampireFarmConfig.InstantKillEnabled = false
end
do
local savedKillThreshold = tonumber(env.VampireFarmConfig.KillThresholdPercent)
if not savedKillThreshold or savedKillThreshold ~= savedKillThreshold
    or savedKillThreshold == math.huge or savedKillThreshold == -math.huge then
    savedKillThreshold = DEFAULT_KILL_THRESHOLD_PERCENT
end
env.VampireFarmConfig.KillThresholdPercent = math.clamp(
    math.floor(savedKillThreshold + 0.5), 0, 100)
local savedApexKillThreshold = tonumber(env.VampireFarmConfig.ApexKillThresholdPercent)
if not savedApexKillThreshold or savedApexKillThreshold ~= savedApexKillThreshold
    or savedApexKillThreshold == math.huge or savedApexKillThreshold == -math.huge then
    savedApexKillThreshold = DEFAULT_APEX_KILL_THRESHOLD_PERCENT
end
env.VampireFarmConfig.ApexKillThresholdPercent = math.clamp(
    math.floor(savedApexKillThreshold + 0.5), 0, 100)
local savedPrimeApexKillThreshold = tonumber(env.VampireFarmConfig.PrimeApexKillThresholdPercent)
if not savedPrimeApexKillThreshold
    or savedPrimeApexKillThreshold ~= savedPrimeApexKillThreshold
    or savedPrimeApexKillThreshold == math.huge
    or savedPrimeApexKillThreshold == -math.huge then
    savedPrimeApexKillThreshold = DEFAULT_PRIME_APEX_KILL_THRESHOLD_PERCENT
end
env.VampireFarmConfig.PrimeApexKillThresholdPercent = math.clamp(
    math.floor(savedPrimeApexKillThreshold + 0.5), 0, 100)
local savedGolemKillThreshold = tonumber(env.VampireFarmConfig.GolemKillThresholdPercent)
if not savedGolemKillThreshold
    or savedGolemKillThreshold ~= savedGolemKillThreshold
    or savedGolemKillThreshold == math.huge
    or savedGolemKillThreshold == -math.huge then
    savedGolemKillThreshold = golem.DefaultKillThreshold
end
env.VampireFarmConfig.GolemKillThresholdPercent = math.clamp(
    math.floor(savedGolemKillThreshold + 0.5), 0, 100)
end

-- Clover UI: local, self-contained interface adapter.
local function createCloverLibrary()
    local UIS = game:GetService("UserInputService")
    local Tween = game:GetService("TweenService")
    local toggles, options, connections = {}, {}, {}
    local lib = {Unloaded = false, ToggleKeybind = false :: any}
    local colors = {bg = Color3.fromRGB(15,17,16), panel = Color3.fromRGB(23,25,23),
        field = Color3.fromRGB(34,37,32), line = Color3.fromRGB(49,53,44),
        text = Color3.fromRGB(239,242,231), muted = Color3.fromRGB(155,162,147),
        accent = Color3.fromRGB(190,219,65)}
    local function make(class, props, parent)
        local object = Instance.new(class)
        for key, value in pairs(props or {}) do object[key] = value end
        object.Parent = parent
        return object
    end
    local function connect(signal, callback)
        local c = signal:Connect(callback)
        table.insert(connections, c)
        return c
    end
    local function round(object, radius)
        make("UICorner", {CornerRadius = UDim.new(0, radius or 10)}, object)
    end
    local function label(parent, text, size)
        return make("TextLabel", {BackgroundTransparency=1, Text=text,
            TextColor3=colors.text, Font=Enum.Font.Gotham, TextSize=size or 13,
            TextXAlignment=Enum.TextXAlignment.Left, Size=UDim2.new(1,0,0,22)}, parent)
    end
    local function button(parent, text)
        local b = make("TextButton", {Text=text, BackgroundColor3=colors.field,
            TextColor3=colors.text, Font=Enum.Font.Gotham, TextSize=12,
            AutoButtonColor=true, BorderSizePixel=0}, parent)
        round(b, 8)
        return b
    end
    local function observable(initial)
        local o = {Value=initial}
        function o:OnChanged(callback) self.callback=callback; callback(self.Value) end
        function o:SetValue(value)
            if self.Value == value then return end
            self.Value=value
            if self.render then self.render() end
            if self.callback then self.callback(value) end
        end
        return o
    end
    local screen = make("ScreenGui", {Name="CloverDashboard", ResetOnSpawn=false,
        ZIndexBehavior=Enum.ZIndexBehavior.Sibling, DisplayOrder=80}, player:WaitForChild("PlayerGui"))
    local window
    function lib:Toggle() if window then window.Visible=not window.Visible end end
    function lib:OnUnload(callback) self.unloadCallback=callback end
    function lib:Unload()
        if self.Unloaded then return end
        self.Unloaded=true
        for _, c in ipairs(connections) do c:Disconnect() end
        screen:Destroy()
        if self.unloadCallback then self.unloadCallback() end
    end
    function lib:CreateWindow(settings)
        window=make("Frame", {Size=UDim2.fromOffset(820,550), AnchorPoint=Vector2.new(.5,.5),
            Position=UDim2.fromScale(.5,.5), BackgroundColor3=colors.bg, BorderSizePixel=0}, screen)
        round(window,14)
        make("UIStroke", {Color=colors.line, Thickness=1}, window)
        local scale=make("UIScale", {}, window)
        local function resize()
            local camera=workspace.CurrentCamera
            if camera then scale.Scale=math.min(1, (camera.ViewportSize.X-24)/820, (camera.ViewportSize.Y-24)/550) end
        end
        resize()
        local viewportConnection
        local function bindCamera()
            if viewportConnection then viewportConnection:Disconnect() end
            local camera=workspace.CurrentCamera
            if camera then viewportConnection=connect(camera:GetPropertyChangedSignal("ViewportSize"), resize) end
            resize()
        end
        bindCamera()
        connect(workspace:GetPropertyChangedSignal("CurrentCamera"), bindCamera)
        local sidebar=make("Frame", {BackgroundColor3=colors.panel, BorderSizePixel=0,
            Position=UDim2.fromOffset(8,8), Size=UDim2.new(0,174,1,-16)}, window)
        round(sidebar,10)
        local brand=label(sidebar,"CLOVER",18)
        brand.Position=UDim2.fromOffset(16,15); brand.TextColor3=colors.accent
        local subtitle=label(sidebar,"RETRIBUTION  /  CONTROL",9)
        subtitle.Position=UDim2.fromOffset(16,39); subtitle.TextColor3=colors.muted
        local nav=make("Frame", {BackgroundTransparency=1, Position=UDim2.fromOffset(10,80),
            Size=UDim2.new(1,-20,1,-134)}, sidebar)
        make("UIListLayout", {Padding=UDim.new(0,7), SortOrder=Enum.SortOrder.LayoutOrder}, nav)
        local hint=label(sidebar,"RightShift to show / hide",10)
        hint.Position=UDim2.new(0,16,1,-34); hint.TextColor3=colors.muted
        local header=label(window,"CONTROL CENTER",12)
        header.Position=UDim2.fromOffset(200,16); header.Size=UDim2.new(1,-260,0,26)
        header.TextColor3=colors.muted
        local close=button(window,"×")
        close.Position=UDim2.new(1,-44,0,14); close.Size=UDim2.fromOffset(28,28)
        connect(close.Activated,function() self:Toggle() end)
        local drag=make("TextButton", {Text="", BackgroundTransparency=1,
            Position=UDim2.fromOffset(195,0), Size=UDim2.new(1,-250,0,45)},window)
        local dragging, start, original
        connect(drag.InputBegan,function(input)
            if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
                dragging=true; start=input.Position; original=window.Position
            end
        end)
        connect(UIS.InputEnded,function(input)
            if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then dragging=false end
        end)
        connect(UIS.InputChanged,function(input)
            if dragging and (input.UserInputType==Enum.UserInputType.MouseMovement or input.UserInputType==Enum.UserInputType.Touch) then
                local delta=input.Position-start
                window.Position=UDim2.new(original.X.Scale,original.X.Offset+delta.X,original.Y.Scale,original.Y.Offset+delta.Y)
            end
        end)
        local pages, first={},true
        local function group(parent,title)
            local section=make("Frame", {BackgroundColor3=colors.panel, BorderSizePixel=0,
                Size=UDim2.new(1,0,0,0), AutomaticSize=Enum.AutomaticSize.Y},parent)
            round(section,12); make("UIStroke",{Color=colors.line},section)
            make("UIPadding",{PaddingTop=UDim.new(0,12),PaddingBottom=UDim.new(0,12),
                PaddingLeft=UDim.new(0,12),PaddingRight=UDim.new(0,12)},section)
            make("UIListLayout",{Padding=UDim.new(0,8),SortOrder=Enum.SortOrder.LayoutOrder},section)
            local titleLabel=label(section,string.upper(title),10); titleLabel.TextColor3=colors.muted
            local g={}
            local order=0
            local function row(height)
                order+=1
                return make("Frame",{BackgroundTransparency=1,Size=UDim2.new(1,0,0,height or 34),LayoutOrder=order},section)
            end
            function g:AddLabel(text,wrap)
                local r=row(wrap and 48 or 24)
                local l=label(r,text,11); l.Size=UDim2.fromScale(1,1); l.TextWrapped=true; l.TextColor3=colors.muted
                local result={}
                function result:AddKeyPicker(id,data)
                    local o=observable(data.Default); options[id]=o
                    local b=button(r,tostring(o.Value)); b.Size=UDim2.fromOffset(94,24); b.Position=UDim2.new(1,-94,0,0)
                    local listening=false
                    o.render=function() b.Text=tostring(o.Value); hint.Text=tostring(o.Value).." to show / hide" end
                    connect(b.Activated,function() listening=true; b.Text="Press a key" end)
                    connect(UIS.InputBegan,function(input,processed)
                        if input.UserInputType~=Enum.UserInputType.Keyboard then return end
                        if listening then listening=false; o:SetValue(input.KeyCode.Name); return end
                        if not processed and not UIS:GetFocusedTextBox() and lib.ToggleKeybind==o and input.KeyCode.Name==o.Value then lib:Toggle() end
                    end)
                    o.render(); return o
                end
                return result
            end
            function g:AddButton(text,callback)
                if type(text)=="table" then callback=text.Func; text=text.Text end
                local b=button(row(32),text); b.Size=UDim2.fromScale(1,1)
                connect(b.Activated,callback); return b
            end
            function g:AddToggle(id,data)
                local r=row(); local l=label(r,data.Text); l.Size=UDim2.new(1,-50,1,0)
                local b=button(r,""); b.Size=UDim2.fromOffset(38,22); b.Position=UDim2.new(1,-38,.5,-11)
                local dot=make("Frame",{Size=UDim2.fromOffset(16,16),BackgroundColor3=colors.text,BorderSizePixel=0},b); round(dot,20)
                local o=observable(data.Default==true); toggles[id]=o
                o.render=function()
                    b.BackgroundColor3=o.Value and colors.accent or colors.field
                    Tween:Create(dot,TweenInfo.new(.12),{Position=UDim2.fromOffset(o.Value and 19 or 3,3)}):Play()
                end
                o.render(); connect(b.Activated,function() o:SetValue(not o.Value) end); return o
            end
            function g:AddInput(id,data)
                local r=row(57); label(r,data.Text,11)
                local b=make("TextBox",{Text=tostring(data.Default or ""),PlaceholderText=data.Placeholder or "Enter value",
                    ClearTextOnFocus=false,BackgroundColor3=colors.field,TextColor3=colors.text,
                    PlaceholderColor3=colors.muted,Font=Enum.Font.Gotham,TextSize=12,
                    Size=UDim2.new(1,0,0,29),Position=UDim2.fromOffset(0,25),BorderSizePixel=0},r); round(b,8)
                local o=observable(tostring(data.Default or "")); options[id]=o
                o.render=function() if b.Text~=tostring(o.Value) then b.Text=tostring(o.Value) end end
                local function changed() o:SetValue(b.Text) end
                if data.Finished==false then connect(b:GetPropertyChangedSignal("Text"),changed) else connect(b.FocusLost,changed) end
                return o
            end
            function g:AddSlider(id,data)
                local r=row(50); local sliderLabel=label(r,data.Text,11); sliderLabel.Size=UDim2.new(.7,0,0,22)
                local valueLabel=label(r,"",11); valueLabel.Size=UDim2.new(.3,0,0,22); valueLabel.Position=UDim2.fromScale(.7,0); valueLabel.TextXAlignment=Enum.TextXAlignment.Right
                local track=button(r,""); track.Size=UDim2.new(1,0,0,8); track.Position=UDim2.fromOffset(0,34)
                local fill=make("Frame",{BackgroundColor3=colors.accent,BorderSizePixel=0,Size=UDim2.fromScale(0,1)},track); round(fill,8)
                local o=observable(data.Default or data.Min); options[id]=o
                o.render=function()
                    valueLabel.Text=tostring(o.Value)
                    fill.Size=UDim2.fromScale(math.clamp((o.Value-data.Min)/(data.Max-data.Min),0,1),1)
                end
                local sliding=false
                local function update(x)
                    local ratio=math.clamp((x-track.AbsolutePosition.X)/track.AbsoluteSize.X,0,1)
                    local factor=10^(data.Rounding or 0)
                    o:SetValue(math.floor((data.Min+ratio*(data.Max-data.Min))*factor+.5)/factor)
                end
                connect(track.InputBegan,function(input)
                    if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then sliding=true; update(input.Position.X) end
                end)
                connect(UIS.InputChanged,function(input)
                    if sliding and (input.UserInputType==Enum.UserInputType.MouseMovement or input.UserInputType==Enum.UserInputType.Touch) then update(input.Position.X) end
                end)
                connect(UIS.InputEnded,function(input)
                    if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then sliding=false end
                end)
                o.render(); return o
            end
            function g:AddDropdown(id,data)
                local r=row(57); label(r,data.Text,11)
                local b=button(r,""); b.Position=UDim2.fromOffset(0,25); b.Size=UDim2.new(1,0,0,29)
                local list=make("ScrollingFrame",{Visible=false,BackgroundColor3=colors.field,BorderSizePixel=0,
                    Size=UDim2.new(1,0,0,160),CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.Y,
                    ScrollBarThickness=3,LayoutOrder=order},section); round(list,8)
                make("UIListLayout",{Padding=UDim.new(0,3),SortOrder=Enum.SortOrder.LayoutOrder},list)
                local initial=data.Default
                if data.Multi then
                    local selected={}
                    if type(initial)=="table" then for k,v in pairs(initial) do if type(k)=="number" then selected[v]=true elseif v then selected[k]=true end end end
                    initial=selected
                elseif type(initial)=="number" then initial=(data.Values or {})[initial] end
                local o=observable(initial); o.Values=table.clone(data.Values or {}); options[id]=o
                local choices={}
                function o:Display()
                    if data.Multi then
                        local names={}; for name,v in pairs(self.Value or {}) do if v then table.insert(names,name) end end
                        table.sort(names); b.Text=#names==0 and "Select...  ▾" or (#names==1 and names[1].."  ▾" or tostring(#names).." selected  ▾")
                    else b.Text=tostring(self.Value or "Select...").."  ▾" end
                    for name,choice in pairs(choices) do
                        local selected=data.Multi and (self.Value or {})[name] or self.Value==name
                        choice.TextColor3=selected and colors.accent or colors.text
                    end
                end
                o.render=function() o:Display() end
                function o:SetValues(values)
                    self.Values=table.clone(values or self.Values)
                    for _,child in ipairs(list:GetChildren()) do if child:IsA("TextButton") then child:Destroy() end end
                    choices={}
                    for index,name in ipairs(self.Values) do
                        local choice=button(list,tostring(name)); choice.Size=UDim2.new(1,-6,0,28); choice.LayoutOrder=index; choices[name]=choice
                        -- Instance-owned connection is released when this choice is destroyed.
                        choice.Activated:Connect(function()
                            if data.Multi then local selected=table.clone(self.Value or {}); selected[name]=not selected[name] or nil; self:SetValue(selected)
                            else self:SetValue(name); list.Visible=false end
                        end)
                    end
                    self:Display()
                end
                o:SetValues(o.Values); connect(b.Activated,function() list.Visible=not list.Visible end)
                return o
            end
            return g
        end
        local result={}
        function result:AddTab(name)
            local tabButton=button(nav,name); tabButton.Size=UDim2.new(1,0,0,36); tabButton.TextXAlignment=Enum.TextXAlignment.Left
            make("UIPadding",{PaddingLeft=UDim.new(0,12)},tabButton)
            local page=make("ScrollingFrame",{BackgroundTransparency=1,BorderSizePixel=0,
                Position=UDim2.fromOffset(200,52),Size=UDim2.new(1,-218,1,-68),ScrollBarThickness=3,
                ScrollBarImageColor3=colors.accent,CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.Y,Visible=first},window)
            local columns={}
            for i=1,2 do
                columns[i]=make("Frame",{BackgroundTransparency=1,Position=UDim2.new((i-1)*.5,(i-1)*6,0,2),
                    Size=UDim2.new(.5,-8,0,0),AutomaticSize=Enum.AutomaticSize.Y},page)
                make("UIListLayout",{Padding=UDim.new(0,14),SortOrder=Enum.SortOrder.LayoutOrder},columns[i])
            end
            local entry={page=page,button=tabButton,name=name}; table.insert(pages,entry)
            local function activate()
                header.Text=string.upper(name).."  /  CLOVER RETRIBUTION"
                for _,item in ipairs(pages) do
                    local selected=item==entry; item.page.Visible=selected
                    item.button.BackgroundColor3=selected and Color3.fromRGB(39,46,24) or colors.panel
                    item.button.TextColor3=selected and colors.accent or colors.muted
                end
            end
            connect(tabButton.Activated,activate)
            if first then first=false; activate() else tabButton.BackgroundColor3=colors.panel; tabButton.TextColor3=colors.muted end
            local tab={}
            function tab:AddLeftGroupbox(title) return group(columns[1],title) end
            function tab:AddRightGroupbox(title) return group(columns[2],title) end
            return tab
        end
        return result
    end
    return lib,toggles,options
end
local Library, Toggles, Options = createCloverLibrary()

local function setNoRender(enabled)
    local ok, err = pcall(function()
        RunService:Set3dRenderingEnabled(not enabled)
    end)
    if ok then
        env.VampireFarmConfig.NoRender = enabled
    else
        warn("[VampireFarm] NoRender failed: " .. tostring(err))
    end
    return env.VampireFarmConfig.NoRender
end

local function followDistance()
    local distance = tonumber(env.VampireFarmConfig.FollowDistance)
    if not distance or distance ~= distance or distance <= 0
        or distance == math.huge then
        return DEFAULT_FOLLOW_DISTANCE
    end
    return distance
end

local function boundedOffset(value)
    local number = tonumber(value)
    if not number or number ~= number or number == math.huge
        or number == -math.huge then
        return 0
    end
    return math.clamp(number, -150, 150)
end

local function currentKillThreshold()
    local value = tonumber(env.VampireFarmConfig.KillThresholdPercent)
    if not value or value ~= value or value == math.huge
        or value == -math.huge then
        return DEFAULT_KILL_THRESHOLD_PERCENT
    end
    return math.clamp(math.floor(value + 0.5), 0, 100)
end

local function currentApexKillThreshold()
    local value = tonumber(env.VampireFarmConfig.ApexKillThresholdPercent)
    if not value or value ~= value or value == math.huge
        or value == -math.huge then
        return DEFAULT_APEX_KILL_THRESHOLD_PERCENT
    end
    return math.clamp(math.floor(value + 0.5), 0, 100)
end

local function currentPrimeApexKillThreshold()
    local value = tonumber(env.VampireFarmConfig.PrimeApexKillThresholdPercent)
    if not value or value ~= value or value == math.huge
        or value == -math.huge then
        return DEFAULT_PRIME_APEX_KILL_THRESHOLD_PERCENT
    end
    return math.clamp(math.floor(value + 0.5), 0, 100)
end

function golem.killThreshold()
    local value = tonumber(env.VampireFarmConfig.GolemKillThresholdPercent)
    if not value or value ~= value or value == math.huge
        or value == -math.huge then
        return golem.DefaultKillThreshold
    end
    return math.clamp(math.floor(value + 0.5), 0, 100)
end

local running = true
local teleportPaused = false
local activeMode = env.VampireFarmConfig.FarmMode
local target
local targetSource
local bossTarget
local apexTarget
local radiusConnection
local attachConnection
local breakerHeartbeatConnection
local breakerRenderConnection
local breakerSimulationConnection
local breakerRoot, breakerSavedVelocity
local antiAfkConnection
local bossAddedConnection
local chestAddedConnection
local cameraBinding = "VampireFarmCamera"
local previousCameraType, previousCameraSubject

local function restoreBreakerVelocity()
    if breakerRoot and breakerRoot.Parent and breakerSavedVelocity then
        breakerRoot.AssemblyLinearVelocity = breakerSavedVelocity
    end
    breakerRoot, breakerSavedVelocity = nil, nil
end

local function restoreCamera()
    local camera = workspace.CurrentCamera
    if camera and previousCameraType then
        camera.CameraType = previousCameraType
        local fallbackSubject = player.Character
            and player.Character:FindFirstChildOfClass("Humanoid")
        if previousCameraSubject and previousCameraSubject.Parent then
            camera.CameraSubject = previousCameraSubject
        elseif fallbackSubject then
            camera.CameraSubject = fallbackSubject
        end
    end
    previousCameraType, previousCameraSubject = nil, nil
end

env.StopVampireFarm = function()
    if not running then return end
    running = false
    if radiusConnection then radiusConnection:Disconnect() end
    if attachConnection then attachConnection:Disconnect() end
    if breakerHeartbeatConnection then breakerHeartbeatConnection:Disconnect() end
    if breakerRenderConnection then breakerRenderConnection:Disconnect() end
    if breakerSimulationConnection then breakerSimulationConnection:Disconnect() end
    restoreBreakerVelocity()
    if antiAfkConnection then antiAfkConnection:Disconnect() end
    if bossAddedConnection then bossAddedConnection:Disconnect() end
    if chestAddedConnection then chestAddedConnection:Disconnect() end
    RunService:UnbindFromRenderStep(cameraBinding)
    restoreCamera()
    if env.VampireFarmConfig.NoRender then setNoRender(false) end
    env.VampireFarmConfig.AutoStatEnabled = false
    env.VampireFarmConfig.AutoSkillEnabled = false
    env.ToggleVampireNoRender = nil
    if Library and not Library.Unloaded then
        pcall(function() Library:Unload() end)
    end
    warn("[VampireFarm] Stopped")
end

env.ToggleVampireNoRender = function()
    local nextValue = not env.VampireFarmConfig.NoRender
    if Toggles and Toggles.VampireNoRender then
        Toggles.VampireNoRender:SetValue(nextValue)
    else
        setNoRender(nextValue)
    end
    return env.VampireFarmConfig.NoRender
end

Library.MainColor = Color3.fromHex("1b2b34")
Library.BackgroundColor = Color3.fromHex("16232a")
Library.AccentColor = Color3.fromHex("6699cc")
Library.OutlineColor = Color3.fromHex("343d46")
Library.FontColor = Color3.fromHex("d8dee9")

local Window = Library:CreateWindow({
    Title = "Clover Retribution",
    Center = true,
    AutoShow = true,
    Size = UDim2.fromOffset(560, 520),
    MenuFadeTime = 0.2,
})
local farmTab = Window:AddTab("Overview")
local mobTab = Window:AddTab("Mobs")
local bossTab = Window:AddTab("Bosses")
local teleportTab = Window:AddTab("Teleport")
local lootTab = Window:AddTab("Loot")
local attachTab = Window:AddTab("Movement")
local skillsTab = Window:AddTab("Skills")
do
    local healthTab = Window:AddTab("Health")
    local box = healthTab:AddLeftGroupbox("Low HP Reset")
    local info = healthTab:AddRightGroupbox("Reset settings")
    if type(env.VampireFarmConfig.AutoResetEnabled) ~= "boolean" then env.VampireFarmConfig.AutoResetEnabled = false end
    local threshold = tonumber(env.VampireFarmConfig.AutoResetHealthPercent)
    if not threshold or threshold ~= threshold then threshold = 20 end
    env.VampireFarmConfig.AutoResetHealthPercent = math.clamp(threshold, 1, 90)
    box:AddToggle("CloverAutoReset", {Text="Auto reset at low HP", Default=env.VampireFarmConfig.AutoResetEnabled})
    Toggles.CloverAutoReset:OnChanged(function(value) env.VampireFarmConfig.AutoResetEnabled=value end)
    box:AddSlider("CloverResetHealth", {Text="Reset below HP (%)", Default=env.VampireFarmConfig.AutoResetHealthPercent, Min=1, Max=90, Rounding=0})
    Options.CloverResetHealth:OnChanged(function(value) env.VampireFarmConfig.AutoResetHealthPercent=value end)
    info:AddLabel("Resets once per character at or below the selected HP percentage. Monitoring resumes after respawn.", true)
    info:AddLabel("Resetting in combat may apply the game's death penalties.", true)
end
local uiTab = Window:AddTab("Settings")
local combatBox = farmTab:AddLeftGroupbox("Combat")
local statBox = farmTab:AddRightGroupbox("Stats")
local vampireBox = farmTab:AddLeftGroupbox("Vampire Farm")
local mobBox = mobTab:AddLeftGroupbox("Mob Farm")
local mobSettingsBox = mobTab:AddRightGroupbox("Priority and Spawn")
local bossBox = bossTab:AddLeftGroupbox("Boss Farm")
local apexBox = bossTab:AddRightGroupbox("Apex Farm")
local primeApexBox = bossTab:AddRightGroupbox("Prime Apex Farm")
local placeTeleportBox = teleportTab:AddLeftGroupbox("Places")
local npcTeleportBox = teleportTab:AddRightGroupbox("NPCs")
local mobTeleportBox = teleportTab:AddRightGroupbox("Mobs")
local teleportControlBox = teleportTab:AddLeftGroupbox("Farm Control")
local lootBox = lootTab:AddLeftGroupbox("Auto Chest Loot")
local attachBox = attachTab:AddLeftGroupbox("Auto Attach")
local aiBreakerBox = attachTab:AddRightGroupbox("AI Breaker")
local skillsBox = skillsTab:AddLeftGroupbox("Auto Skill")
do
    env.VampireFarmConfig.CoffinAimDistance = math.clamp(tonumber(env.VampireFarmConfig.CoffinAimDistance) or 5, 2, 12)
    env.VampireFarmConfig.FarmCameraDistance = math.clamp(tonumber(env.VampireFarmConfig.FarmCameraDistance) or 14, 8, 24)
    skillsBox:AddSlider("CoffinAimDistance", {Text="Coffin aim ahead (studs)", Default=env.VampireFarmConfig.CoffinAimDistance, Min=2, Max=12, Rounding=1})
    Options.CoffinAimDistance:OnChanged(function(value) env.VampireFarmConfig.CoffinAimDistance=value end)
    skillsBox:AddSlider("FarmCameraDistance", {Text="Camera distance", Default=env.VampireFarmConfig.FarmCameraDistance, Min=8, Max=24, Rounding=0})
    Options.FarmCameraDistance:OnChanged(function(value) env.VampireFarmConfig.FarmCameraDistance=value end)
end
local uiBox = uiTab:AddLeftGroupbox("Window")

local function addDropdownSearch(groupbox, dropdownId, label)
    local dropdown = Options[dropdownId]
    local originalSetValues = dropdown.SetValues
    local originalSetValue = dropdown.SetValue
    local allValues = table.clone(dropdown.Values)
    local query = ""

    local function applySearch()
        local filtered = {}
        local needle = string.lower(query):match("^%s*(.-)%s*$")
        for _, value in ipairs(allValues) do
            if needle == "" or string.find(string.lower(value), needle, 1, true) then
                table.insert(filtered, value)
            end
        end
        originalSetValues(dropdown, filtered)
        dropdown:Display()
    end

    function dropdown:SetValues(values)
        if values then allValues = table.clone(values) end
        applySearch()
    end

    function dropdown:SetValue(value)
        -- Linoria validates against visible values. Restore the full list
        -- first so hidden multi-select values survive a filtered search.
        originalSetValues(dropdown, allValues)
        originalSetValue(dropdown, value)
        applySearch()
    end

    local searchId = "Search" .. dropdownId
    groupbox:AddInput(searchId, {
        Text = "Search " .. label,
        Default = "",
        Placeholder = "Type to filter...",
        Finished = false,
        Tooltip = "Filters choices; selections remain active when hidden.",
    })
    Options[searchId]:OnChanged(function(value)
        query = tostring(value or "")
        applySearch()
    end)
end

bossBox:AddToggle("BossFarmEnabled", {
    Text = "Auto Boss Farm",
    Default = env.VampireFarmConfig.BossFarmEnabled,
    Tooltip = "Interrupts the current farm for any live listed boss, then resumes it.",
})
Toggles.BossFarmEnabled:OnChanged(function(enabled)
    env.VampireFarmConfig.BossFarmEnabled = enabled
    if not enabled and targetSource == "Boss" then
        bossTarget = nil
        target = nil
        targetSource = nil
        restoreCamera()
    end
end)
local initialBossSelection = {}
for _, name in ipairs(BOSS_NAME_SEED) do
    if env.VampireFarmConfig.SelectedBosses[name] then
        table.insert(initialBossSelection, name)
    end
end
bossBox:AddDropdown("BossTargets", {
    Text = "Bosses to farm",
    Values = BOSS_NAME_SEED,
    Default = initialBossSelection,
    Multi = true,
    AllowNull = true,
})
addDropdownSearch(bossBox, "BossTargets", "bosses")
Options.BossTargets:OnChanged(function(selected)
    selected = type(selected) == "table" and selected or {}
    for _, name in ipairs(BOSS_NAME_SEED) do
        env.VampireFarmConfig.SelectedBosses[name] = selected[name] == true or nil
    end
    if bossTarget and not env.VampireFarmConfig.SelectedBosses[bossTarget.Name] then
        bossTarget = nil
        if targetSource == "Boss" then
            target = nil
            targetSource = nil
            restoreCamera()
        end
    end
end)
bossBox:AddButton("Select All", function()
    local selected = {}
    for _, name in ipairs(BOSS_NAME_SEED) do
        selected[name] = true
    end
    Options.BossTargets:SetValue(selected)
end)
bossBox:AddButton("Deselect All", function()
    Options.BossTargets:SetValue({})
end)
bossBox:AddLabel("Selected bosses interrupt the current farm; it resumes afterward.", true)

apexBox:AddToggle("ApexFarmEnabled", {
    Text = "Apex Farm",
    Default = env.VampireFarmConfig.ApexFarmEnabled,
    Tooltip = "Farm Apex separately from Prime Apex and selected bosses.",
})
Toggles.ApexFarmEnabled:OnChanged(function(enabled)
    env.VampireFarmConfig.ApexFarmEnabled = enabled
    if not enabled and targetSource == "Apex" then
        apexTarget = nil
        target = nil
        targetSource = nil
        restoreCamera()
    end
end)
apexBox:AddLabel("Target: Apex", true)
apexBox:AddSlider("ApexKillThreshold", {
    Text = "Apex kill HP threshold",
    Default = currentApexKillThreshold(),
    Min = 0,
    Max = 100,
    Rounding = 0,
    Suffix = "%",
})
apexBox:AddInput("ApexKillThresholdText", {
    Text = "Apex threshold number (0-100)",
    Default = tostring(currentApexKillThreshold()),
    Numeric = true,
    Finished = true,
})
local syncingApexThreshold = false
local function updateApexThreshold(value, origin)
    if syncingApexThreshold then return end
    local number = tonumber(value)
    if not number or number ~= number or number == math.huge
        or number == -math.huge then
        number = currentApexKillThreshold()
    end
    number = math.clamp(math.floor(number + 0.5), 0, 100)
    env.VampireFarmConfig.ApexKillThresholdPercent = number
    syncingApexThreshold = true
    if origin ~= "slider" then
        Options.ApexKillThreshold:SetValue(number)
    end
    if origin ~= "input" then
        Options.ApexKillThresholdText:SetValue(tostring(number))
    end
    syncingApexThreshold = false
end
Options.ApexKillThreshold:OnChanged(function(value)
    updateApexThreshold(value, "slider")
end)
Options.ApexKillThresholdText:OnChanged(function(value)
    updateApexThreshold(value, "input")
end)

primeApexBox:AddToggle("PrimeApexFarmEnabled", {
    Text = "Prime Apex Farm",
    Default = env.VampireFarmConfig.PrimeApexFarmEnabled,
    Tooltip = "Farm Prime Apex separately from Apex and selected bosses.",
})
Toggles.PrimeApexFarmEnabled:OnChanged(function(enabled)
    env.VampireFarmConfig.PrimeApexFarmEnabled = enabled
    if not enabled and targetSource == "PrimeApex" then
        apexTarget = nil
        target = nil
        targetSource = nil
        restoreCamera()
    end
end)
primeApexBox:AddLabel("Target: Prime Apex", true)
primeApexBox:AddSlider("PrimeApexKillThreshold", {
    Text = "Prime Apex kill HP threshold",
    Default = currentPrimeApexKillThreshold(),
    Min = 0,
    Max = 100,
    Rounding = 0,
    Suffix = "%",
})
primeApexBox:AddInput("PrimeApexKillThresholdText", {
    Text = "Prime Apex threshold number (0-100)",
    Default = tostring(currentPrimeApexKillThreshold()),
    Numeric = true,
    Finished = true,
})
local syncingPrimeApexThreshold = false
local function updatePrimeApexThreshold(value, origin)
    if syncingPrimeApexThreshold then return end
    local number = tonumber(value)
    if not number or number ~= number or number == math.huge
        or number == -math.huge then
        number = currentPrimeApexKillThreshold()
    end
    number = math.clamp(math.floor(number + 0.5), 0, 100)
    env.VampireFarmConfig.PrimeApexKillThresholdPercent = number
    syncingPrimeApexThreshold = true
    if origin ~= "slider" then
        Options.PrimeApexKillThreshold:SetValue(number)
    end
    if origin ~= "input" then
        Options.PrimeApexKillThresholdText:SetValue(tostring(number))
    end
    syncingPrimeApexThreshold = false
end
Options.PrimeApexKillThreshold:OnChanged(function(value)
    updatePrimeApexThreshold(value, "slider")
end)
Options.PrimeApexKillThresholdText:OnChanged(function(value)
    updatePrimeApexThreshold(value, "input")
end)

do
local golemBox = bossTab:AddLeftGroupbox("Aetherstone Golem")
golemBox:AddToggle("GolemFarmEnabled", {
    Text = "Aetherstone Golem Farm",
    Default = env.VampireFarmConfig.GolemFarmEnabled,
    Tooltip = "Insert the four runes, enter the gate, then farm the golem.",
})
Toggles.GolemFarmEnabled:OnChanged(function(enabled)
    env.VampireFarmConfig.GolemFarmEnabled = enabled
    if not enabled and (targetSource == "Golem"
        or targetSource == "GolemShard"
        or targetSource == "GolemSummon") then
        golem.Target = nil
        golem.ShardTarget = nil
        target = nil
        targetSource = nil
        restoreCamera()
    end
end)
golemBox:AddSlider("GolemKillThreshold", {
    Text = "Golem kill HP threshold",
    Default = golem.killThreshold(),
    Min = 0,
    Max = 100,
    Rounding = 0,
    Suffix = "%",
})
golemBox:AddInput("GolemKillThresholdText", {
    Text = "Golem threshold number (0-100)",
    Default = tostring(golem.killThreshold()),
    Numeric = true,
    Finished = true,
})
local syncingGolemThreshold = false
local function updateGolemThreshold(value, origin)
    if syncingGolemThreshold then return end
    local number = tonumber(value)
    if not number or number ~= number or number == math.huge
        or number == -math.huge then
        number = golem.killThreshold()
    end
    number = math.clamp(math.floor(number + 0.5), 0, 100)
    env.VampireFarmConfig.GolemKillThresholdPercent = number
    syncingGolemThreshold = true
    if origin ~= "slider" then
        Options.GolemKillThreshold:SetValue(number)
    end
    if origin ~= "input" then
        Options.GolemKillThresholdText:SetValue(tostring(number))
    end
    syncingGolemThreshold = false
end
Options.GolemKillThreshold:OnChanged(function(value)
    updateGolemThreshold(value, "slider")
end)
Options.GolemKillThresholdText:OnChanged(function(value)
    updateGolemThreshold(value, "input")
end)
end

lootBox:AddToggle("AutoChestLootEnabled", {
    Text = "Auto loot chests",
    Default = env.VampireFarmConfig.AutoChestLootEnabled,
    Tooltip = "Tries nearby enabled chest prompts once; skips unopened chests.",
})
Toggles.AutoChestLootEnabled:OnChanged(function(enabled)
    env.VampireFarmConfig.AutoChestLootEnabled = enabled
end)
lootBox:AddSlider("ChestLootRadius", {
    Text = "Search radius",
    Default = env.VampireFarmConfig.ChestLootRadius,
    Min = 10,
    Max = 500,
    Rounding = 0,
    Suffix = " studs",
})
Options.ChestLootRadius:OnChanged(function(value)
    env.VampireFarmConfig.ChestLootRadius = value
end)
lootBox:AddLabel("Boss fights take priority. Chest loot resumes your selected farm.", true)

attachBox:AddToggle("AutoAttachEnabled", {
    Text = "Auto Attach",
    Default = env.VampireFarmConfig.AutoAttachEnabled,
})
Toggles.AutoAttachEnabled:OnChanged(function(enabled)
    env.VampireFarmConfig.AutoAttachEnabled = enabled
end)
attachBox:AddSlider("AttachDistance", {
    Text = "Back distance (Z)",
    Default = math.clamp(followDistance(), 1, 150),
    Min = 1,
    Max = 150,
    Rounding = 1,
})
Options.AttachDistance:OnChanged(function(value)
    env.VampireFarmConfig.FollowDistance = value
end)
attachBox:AddSlider("AttachXOffset", {
    Text = "Side offset (X)",
    Default = boundedOffset(env.VampireFarmConfig.XOffset),
    Min = -150,
    Max = 150,
    Rounding = 1,
})
Options.AttachXOffset:OnChanged(function(value)
    env.VampireFarmConfig.XOffset = value
end)
attachBox:AddSlider("AttachYOffset", {
    Text = "Height offset (Y)",
    Default = boundedOffset(env.VampireFarmConfig.YOffset),
    Min = -150,
    Max = 150,
    Rounding = 1,
})
Options.AttachYOffset:OnChanged(function(value)
    env.VampireFarmConfig.YOffset = value
end)
for _, setting in ipairs({
    {"AttachIgnoreRotation", "Ignore mob rotation", "IgnoreRotation"},
    {"AttachRotateTowards", "Face mob", "RotateTowards"},
    {"AttachPreventVoiding", "Prevent voiding", "PreventVoiding"},
}) do
    attachBox:AddToggle(setting[1], {
        Text = setting[2],
        Default = env.VampireFarmConfig[setting[3]],
    })
    Toggles[setting[1]]:OnChanged(function(enabled)
        env.VampireFarmConfig[setting[3]] = enabled
    end)
end

aiBreakerBox:AddToggle("AIBreakerEnabled", {
    Text = "AI Breaker",
    Default = env.VampireFarmConfig.AIBreakerEnabled,
    Tooltip = "Spoofs root velocity while attached to the current enemy.",
})
Toggles.AIBreakerEnabled:OnChanged(function(enabled)
    env.VampireFarmConfig.AIBreakerEnabled = enabled
    if not enabled then restoreBreakerVelocity() end
end)
aiBreakerBox:AddDropdown("AIBreakerType", {
    Text = "Breaker type",
    Values = {"OPassive", "Passive", "Circular", "Aggressive"},
    Default = env.VampireFarmConfig.AIBreakerType,
})
addDropdownSearch(aiBreakerBox, "AIBreakerType", "breaker types")
Options.AIBreakerType:OnChanged(function(value)
    if AI_BREAKER_TYPES[value] then
        env.VampireFarmConfig.AIBreakerType = value
    end
end)
aiBreakerBox:AddLabel("Runs only while Auto Attach has a live target.", true)

local syncingMode = false
local function setFarmMode(mode)
    if activeMode == mode then return end
    activeMode = mode
    env.VampireFarmConfig.FarmMode = mode
    if not bossTarget and not apexTarget then
        target = nil
        targetSource = nil
        restoreCamera()
    end
    syncingMode = true
    if Toggles.VampireFarmEnabled then
        Toggles.VampireFarmEnabled:SetValue(mode == "Vampire")
    end
    if Toggles.MobFarmEnabled then
        Toggles.MobFarmEnabled:SetValue(mode == "Mob")
    end
    syncingMode = false
    print("[VampireFarm] Mode: " .. mode)
end

vampireBox:AddToggle("VampireFarmEnabled", {
    Text = "Enable Vampire Farm",
    Default = activeMode == "Vampire",
})
Toggles.VampireFarmEnabled:OnChanged(function(enabled)
    if syncingMode then return end
    if enabled then
        setFarmMode("Vampire")
    elseif activeMode == "Vampire" then
        setFarmMode("Off")
    end
end)
mobBox:AddToggle("MobFarmEnabled", {
    Text = "Enable Mob Farm",
    Default = activeMode == "Mob",
})
Toggles.MobFarmEnabled:OnChanged(function(enabled)
    if syncingMode then return end
    if enabled then
        setFarmMode("Mob")
    elseif activeMode == "Mob" then
        setFarmMode("Off")
    end
end)

local knownMobNames = {}
for _, name in ipairs(MOB_NAME_SEED) do
    knownMobNames[name] = true
end
for name in pairs(env.VampireFarmConfig.SelectedMobs) do
    if type(name) == "string" and MOB_NAMES[name] then
        knownMobNames[name] = true
    end
end
local function mobNameList()
    local names = {}
    for name in pairs(knownMobNames) do
        table.insert(names, name)
    end
    table.sort(names)
    return names
end

local initialMobSelection = {}
for name, selected in pairs(env.VampireFarmConfig.SelectedMobs) do
    if selected and knownMobNames[name] then
        table.insert(initialMobSelection, name)
    end
end

mobBox:AddDropdown("MobTargets", {
    Text = "Mobs to farm",
    Values = mobNameList(),
    Default = initialMobSelection,
    Multi = true,
    AllowNull = true,
})
addDropdownSearch(mobBox, "MobTargets", "mobs")
mobBox:AddLabel("Select one or more mobs. Names stay listed after despawn.", true)

mobSettingsBox:AddDropdown("MobPriorityTarget", {
    Text = "Mob to configure",
    Values = mobNameList(),
    Default = MOB_NAME_SEED[1],
})
addDropdownSearch(mobSettingsBox, "MobPriorityTarget", "configured mobs")
mobSettingsBox:AddSlider("MobPriorityValue", {
    Text = "Priority (higher first)",
    Default = 1,
    Min = 1,
    Max = 10,
    Rounding = 0,
})
local spawnChoices = {"Auto"}
local seenSpawnNames = {}
for _, entry in ipairs(spawns:GetChildren()) do
    if entry:IsA("BasePart") and not seenSpawnNames[entry.Name] then
        seenSpawnNames[entry.Name] = true
        table.insert(spawnChoices, entry.Name)
    end
end
table.sort(spawnChoices, function(a, b)
    if a == "Auto" then return true end
    if b == "Auto" then return false end
    return a < b
end)
mobSettingsBox:AddDropdown("MobSpawnChoice", {
    Text = "Spawn for this mob",
    Values = spawnChoices,
    Default = "Auto",
})
addDropdownSearch(mobSettingsBox, "MobSpawnChoice", "spawns")
mobSettingsBox:AddLabel("Auto uses mapped spawns. Pick a spawn for unmapped mobs.", true)

local syncingMobSettings = false
local function configuredMobName()
    return Options.MobPriorityTarget.Value
end
local function refreshMobSettings()
    local name = configuredMobName()
    if not name then return end
    syncingMobSettings = true
    Options.MobPriorityValue:SetValue(
        math.clamp(tonumber(env.VampireFarmConfig.MobPriorities[name]) or 1, 1, 10))
    local override = env.VampireFarmConfig.MobSpawnOverrides[name]
    Options.MobSpawnChoice:SetValue(
        override and table.find(spawnChoices, override) and override or "Auto")
    syncingMobSettings = false
end
Options.MobPriorityTarget:OnChanged(refreshMobSettings)
Options.MobPriorityValue:OnChanged(function(value)
    if syncingMobSettings then return end
    local name = configuredMobName()
    if name then
        env.VampireFarmConfig.MobPriorities[name] = math.clamp(math.floor(value), 1, 10)
    end
end)
Options.MobSpawnChoice:OnChanged(function(value)
    if syncingMobSettings then return end
    local name = configuredMobName()
    if name then
        env.VampireFarmConfig.MobSpawnOverrides[name] = value ~= "Auto" and value or nil
    end
end)

local refreshingMobs = false
Options.MobTargets:OnChanged(function(selected)
    if refreshingMobs then return end
    selected = type(selected) == "table" and selected or {}
    for name in pairs(knownMobNames) do
        env.VampireFarmConfig.SelectedMobs[name] = selected[name] == true or nil
    end
    if targetSource == "Base" and target
        and not env.VampireFarmConfig.SelectedMobs[target.Name]
        and activeMode == "Mob" then
        target = nil
    end
end)

local mobSignature = ""
local function refreshMobNames()
    for _, model in ipairs(enemies:GetChildren()) do
        if model:IsA("Model") and model:FindFirstChildOfClass("Humanoid")
            and MOB_NAMES[model.Name] then
            knownMobNames[model.Name] = true
        end
    end
    local names = mobNameList()
    local signature = table.concat(names, "\n")
    if signature == mobSignature then return end
    mobSignature = signature
    local selected = {}
    for _, name in ipairs(names) do
        if env.VampireFarmConfig.SelectedMobs[name] then
            selected[name] = true
        end
    end
    refreshingMobs = true
    Options.MobTargets:SetValues(names)
    Options.MobTargets:SetValue(selected)
    Options.MobPriorityTarget:SetValues(names)
    if not table.find(names, configuredMobName()) then
        Options.MobPriorityTarget:SetValue(names[1])
    end
    refreshingMobs = false
end
refreshMobNames()
task.spawn(function()
    while running do
        refreshMobNames()
        task.wait(1)
    end
end)

combatBox:AddToggle("VampireInstantKill", {
    Text = "Instant kill attempt",
    Default = env.VampireFarmConfig.InstantKillEnabled,
    Tooltip = "Attempt the local HP kill at or below the selected mob HP percentage.",
})
Toggles.VampireInstantKill:OnChanged(function(value)
    env.VampireFarmConfig.InstantKillEnabled = value
end)

combatBox:AddSlider("VampireKillThreshold", {
    Text = "Mob HP threshold",
    Default = currentKillThreshold(),
    Min = 0,
    Max = 100,
    Rounding = 0,
    Suffix = "%",
})
combatBox:AddInput("VampireKillThresholdText", {
    Text = "Threshold number (0-100)",
    Default = tostring(currentKillThreshold()),
    Numeric = true,
    Finished = true,
})
local syncingThreshold = false
local function updateThreshold(value, origin)
    if syncingThreshold then return end
    local number = tonumber(value)
    if not number or number ~= number then
        number = currentKillThreshold()
    end
    number = math.clamp(math.floor(number + 0.5), 0, 100)
    env.VampireFarmConfig.KillThresholdPercent = number
    syncingThreshold = true
    if origin ~= "slider" then
        Options.VampireKillThreshold:SetValue(number)
    end
    if origin ~= "input" then
        Options.VampireKillThresholdText:SetValue(tostring(number))
    end
    syncingThreshold = false
end
Options.VampireKillThreshold:OnChanged(function(value)
    updateThreshold(value, "slider")
end)
Options.VampireKillThresholdText:OnChanged(function(value)
    updateThreshold(value, "input")
end)

statBox:AddDropdown("VampireStatTarget", {
    Text = "Invest points in",
    Values = {"STR", "DEX", "INT", "CON"},
    Default = env.VampireFarmConfig.AutoStatTarget,
})
addDropdownSearch(statBox, "VampireStatTarget", "stats")
Options.VampireStatTarget:OnChanged(function(value)
    if VALID_STATS[value] then
        env.VampireFarmConfig.AutoStatTarget = value
    end
end)
statBox:AddToggle("VampireAutoStat", {
    Text = "Auto Stat",
    Default = env.VampireFarmConfig.AutoStatEnabled,
})
Toggles.VampireAutoStat:OnChanged(function(value)
    env.VampireFarmConfig.AutoStatEnabled = value
end)

skillsBox:AddToggle("VampireAutoSkill", {
    Text = "Auto Skill",
    Default = env.VampireFarmConfig.AutoSkillEnabled,
})
Toggles.VampireAutoSkill:OnChanged(function(value)
    env.VampireFarmConfig.AutoSkillEnabled = value
end)
skillsBox:AddDropdown("VampireSkillPicker", {
    Text = "Weapon and grimoire skills",
    Values = {},
    Multi = true,
    AllowNull = true,
})
addDropdownSearch(skillsBox, "VampireSkillPicker", "skills")
skillsBox:AddLabel("Grimoire spells appear when owned as Tools in your Backpack or character.", true)

uiBox:AddToggle("VampireNoRender", {
    Text = "No Render",
    Default = env.VampireFarmConfig.NoRender,
})
Toggles.VampireNoRender:OnChanged(function(value)
    setNoRender(value)
end)
uiBox:AddLabel("Show / hide key"):AddKeyPicker("VampireMenuKey", {
    Default = env.VampireFarmConfig.ToggleKeybind,
    NoUI = true,
    Mode = "Toggle",
    Text = "Clover menu",
})
Library.ToggleKeybind = Options.VampireMenuKey
Options.VampireMenuKey:OnChanged(function(value)
    env.VampireFarmConfig.ToggleKeybind = value
end)
uiBox:AddButton("Hide window", function()
    Library:Toggle()
end)
uiBox:AddButton("Stop farm", function()
    env.StopVampireFarm()
end)
Library:OnUnload(function()
    Library.Unloaded = true
    if running then env.StopVampireFarm() end
end)

local playerGui = player:WaitForChild("PlayerGui")
if not running or env.VampireFarmLaunchToken ~= launchToken then return end
local function getAvailableSkills()
    local hud = playerGui:FindFirstChild("HUD")
    local bar = hud and hud:FindFirstChild("WeaponSkills")
    local frame = bar and bar:FindFirstChild("Frame")
    local result = {}
    if frame then
        for _, slot in ipairs(frame:GetChildren()) do
            local moveName = slot:FindFirstChild("MoveName")
            if slot:FindFirstChild("SkillButton") and slot.Name ~= "SkillSlot"
                and moveName and moveName.Text == slot.Name then
                local key = "Weapon:" .. slot.Name
                local selected = env.VampireFarmConfig.SelectedSkills
                if selected[slot.Name] and selected[key] == nil then
                    selected[key] = true
                    selected[slot.Name] = nil
                end
                table.insert(result, {
                    Name = slot.Name,
                    Key = key,
                    Kind = "Weapon",
                    Order = slot.LayoutOrder,
                    Label = "Weapon | " .. slot.Name,
                })
            end
        end
    end
    local seenSpells = {}
    for _, container in ipairs({player.Character, player:FindFirstChildOfClass("Backpack")}) do
        if container then
            for _, tool in ipairs(container:GetChildren()) do
                if tool:IsA("Tool") and not seenSpells[tool.Name]
                    and (spellNames[tool.Name]
                        or tool:GetAttribute("Type") == "Spell"
                        or tool:GetAttribute("ItemType") == "Spell") then
                    seenSpells[tool.Name] = true
                    table.insert(result, {
                        Name = tool.Name,
                        Key = "Grimoire:" .. tool.Name,
                        Kind = "Grimoire",
                        Order = 100 + (tonumber(tool:GetAttribute("Index")) or 99),
                        Label = "Grimoire | " .. tool.Name,
                        Tool = tool,
                    })
                end
            end
        end
    end
    table.sort(result, function(a, b)
        if a.Order == b.Order then return a.Key < b.Key end
        return a.Order < b.Order
    end)
    return result
end

local refreshingSkills = true -- Preserve saved choices while registering the initial callback.
Options.VampireSkillPicker:OnChanged(function(selectedLabels)
    if refreshingSkills or type(selectedLabels) ~= "table" then return end
    local available = getAvailableSkills()
    local selected = env.VampireFarmConfig.SelectedSkills
    for _, skill in ipairs(available) do
        selected[skill.Key] = selectedLabels[skill.Label] or nil
    end
end)

local skillSignature = ""
local function refreshSkillPicker()
    local available = getAvailableSkills()
    local names = {}
    local selectedLabels = {}
    for _, skill in ipairs(available) do
        table.insert(names, skill.Label)
        if env.VampireFarmConfig.SelectedSkills[skill.Key] then
            selectedLabels[skill.Label] = true
        end
    end
    local signature = table.concat(names, "\n")
    if signature == skillSignature then return end
    skillSignature = signature
    refreshingSkills = true
    Options.VampireSkillPicker:SetValues(names)
    Options.VampireSkillPicker:SetValue(selectedLabels)
    refreshingSkills = false
end
refreshSkillPicker()
refreshingSkills = false
skillsBox:AddButton("Refresh skill list", function()
    skillSignature = "__refresh__"
    refreshSkillPicker()
end)
skillsBox:AddButton("Select all detected skills", function()
    local selected = {}
    for _, skill in ipairs(getAvailableSkills()) do
        selected[skill.Label] = true
    end
    Options.VampireSkillPicker:SetValue(selected)
end)
local function printSkillStatus()
    local character = player.Character
    local status = character and character:FindFirstChild("Status")
    local cooldown = status and status:FindFirstChild("Cooldown")
    local casting = status and status:FindFirstChild("Casting")
    local available = getAvailableSkills()
    local selectedCount = 0
    for _, skill in ipairs(available) do
        local selected = env.VampireFarmConfig.SelectedSkills[skill.Key] == true
        if selected then selectedCount += 1 end
        print("[CloverSkills] " .. skill.Label .. " | selected=" .. tostring(selected)
            .. " | cooldown=" .. tostring(cooldown and cooldown:FindFirstChild(skill.Name) ~= nil)
            .. " | toolEnabled=" .. tostring(skill.Tool and skill.Tool.Enabled))
    end
    print("[CloverSkills] enabled=" .. tostring(env.VampireFarmConfig.AutoSkillEnabled)
        .. " | detected=" .. #available .. " | selected=" .. selectedCount
        .. " | status=" .. tostring(status ~= nil)
        .. " | cooldownFolder=" .. tostring(cooldown ~= nil)
        .. " | casting=" .. tostring(casting and casting.Value)
        .. " | target=" .. tostring(target and target.Name))
    if selectedCount == 0 then
        warn("[CloverSkills] Select skills from the dropdown or click Select all detected skills.")
    end
    if not target then
        warn("[CloverSkills] Auto Skill needs a live farm target; enable the intended farm.")
    end
    if not cooldown then
        warn("[CloverSkills] Character.Status.Cooldown is missing; skill activation is currently blocked.")
    end
end
skillsBox:AddButton("Print skill status", printSkillStatus)
task.spawn(function()
    while running do
        refreshSkillPicker()
        task.wait(0.5)
    end
end)

if type(getconnections) == "function" then
    local ok, connections = pcall(getconnections, player.Idled)
    if ok then
        for _, connection in ipairs(connections) do
            pcall(function() connection:Disable() end)
            pcall(function() connection:Disconnect() end)
        end
    end
end

antiAfkConnection = player.Idled:Connect(function()
    local ok, err = pcall(function()
        local VirtualInputManager = Instance.new("VirtualInputManager")
        VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 0)
        VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 0)
        VirtualInputManager:Destroy()
    end)
    if not ok then
        warn("[VampireFarm] Anti-AFK failed: " .. tostring(err))
    end
end)
print("[VampireFarm] Anti-AFK enabled")
if env.VampireFarmConfig.NoRender then
    setNoRender(true)
end

task.spawn(function()
    while running do
        if env.VampireFarmConfig.AutoStatEnabled then
            local statName = env.VampireFarmConfig.AutoStatTarget
            local character = player.Character
            local status = character and character:FindFirstChild("Status")
            local changes = status and status:FindFirstChild("Changes")
            local stat = changes and changes:FindFirstChild(statName)

            if VALID_STATS[statName] and stat and stat:IsA("NumberValue") then
                local cap = tonumber(stat:GetAttribute("Max"))
                if not cap or stat.Value < cap then
                    local ok, data = pcall(function()
                        return fetch:InvokeServer()
                    end)
                    local points = ok and type(data) == "table"
                        and type(data.CoreData) == "table"
                        and tonumber(data.CoreData.StatPoints) or 0

                    if running and env.VampireFarmConfig.AutoStatEnabled
                        and env.VampireFarmConfig.AutoStatTarget == statName
                        and points >= 1 then
                        action:FireServer("StatDump", {Stat = statName, Dump = 1})
                    end
                end
            end
        end
        task.wait(1.25)
    end
end)

local function applyRadius()
    if type(sethiddenproperty) ~= "function" then return end
    pcall(sethiddenproperty, player, "MaxSimulationRadius", SIMULATION_RADIUS)
    pcall(sethiddenproperty, player, "SimulationRadius", SIMULATION_RADIUS)
end

applyRadius()
local radiusElapsed = 0
radiusConnection = RunService.Heartbeat:Connect(function(dt)
    if not running then return end
    radiusElapsed += dt
    if radiusElapsed >= RADIUS_INTERVAL then
        radiusElapsed = 0
        applyRadius()
    end
end)

local function getRoot(model)
    return model and (model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart)
end

golem.Runes = {
    {Name = "Rune of Colossal Wrath", Position = Vector3.new(1393.33, 89.61, 1081.79)},
    {Name = "Rune of Endless Challenge", Position = Vector3.new(3078.26, 83.72, 1536.53)},
    {Name = "Rune of Raging Tempest", Position = Vector3.new(1277.00, 83.48, -1190.37)},
    {Name = "Rune of Shattered Earth", Position = Vector3.new(2619.18, 171.48, -798.14)},
}
golem.GatePosition = Vector3.new(1577.56, 90.31, 827.95)
golem.IslePosition = Vector3.new(11169.42, 638.36, 30.70)

function golem.warn(message)
    if os.clock() - golem.LastWarningAt >= 15 then
        warn("[VampireFarm] Golem summon: " .. message)
        golem.LastWarningAt = os.clock()
    end
end

function golem.events()
    local interactions = entities:FindFirstChild("Interactions")
    return interactions and interactions:FindFirstChild("SpecialEvents")
end

function golem.runeIsLit(model)
    local function atTarget(part)
        local color = part and part:FindFirstChild("TargetColor")
        if not (part and part:IsA("BasePart")
            and color and color:IsA("Color3Value")) then return false end
        local current, targetColor = part.Color, color.Value
        return math.abs(current.R - targetColor.R)
            + math.abs(current.G - targetColor.G)
            + math.abs(current.B - targetColor.B) < 0.12
    end
    if not model then return false end
    local stone = model:FindFirstChild("Stone")
    local portalLink = stone and stone:FindFirstChild("PortalRune")
    return atTarget(model:FindFirstChild("NeonPiece"))
        or atTarget(portalLink and portalLink.Value)
end

function golem.nearPart(root, part, fallback)
    local position = part and part.Position or fallback
    if (root.Position - position).Magnitude <= 7 then return true end
    local destination = position + Vector3.new(0, 3, 4)
    root.AssemblyLinearVelocity = Vector3.zero
    root.AssemblyAngularVelocity = Vector3.zero
    root.CFrame = CFrame.lookAt(destination, position)
    return false
end

function golem.findInsertButton(runeName)
    local wanted = ("Insert the " .. runeName):lower()
    for _, gui in ipairs(playerGui:GetChildren()) do
        if gui:IsA("ScreenGui") and gui.Enabled
            and gui.Name:lower():find("dialog", 1, true) then
            for _, item in ipairs(gui:GetDescendants()) do
                if item:IsA("TextLabel") or item:IsA("TextButton") then
                    local label = item.Text:lower():gsub("%s+", " ")
                    if label:find(wanted, 1, true) then
                        local button = item:IsA("GuiButton") and item
                            or item:FindFirstAncestorWhichIsA("GuiButton")
                        if button and button.Visible then return button end
                    end
                end
            end
        end
    end
end

function golem.clickChoice(button)
    for _, signal in ipairs({button.MouseButton1Click, button.Activated}) do
        if type(getconnections) == "function" then
            local ok, connections = pcall(getconnections, signal)
            if ok and type(connections) == "table" and #connections > 0 then
                if type(firesignal) == "function" then
                    local fired = pcall(firesignal, signal)
                    if fired then return true end
                end
                local fired = false
                for _, connection in ipairs(connections) do
                    if type(connection.Function) == "function" then
                        fired = pcall(connection.Function) or fired
                    end
                end
                if fired then return true end
            end
        end
    end
    if type(firesignal) == "function" then
        return pcall(firesignal, button.MouseButton1Click)
    end
    return false
end

function golem.summonStep(root)
    if not running or not env.VampireFarmConfig.GolemFarmEnabled then return end
    local events = golem.events()
    if not events then
        golem.warn("SpecialEvents is not streamed in")
        golem.NextSummonAt = os.clock() + 5
        return
    end
    local gate = events:FindFirstChild("WarpGate")
    local gateMiddle = gate and gate:FindFirstChild("Middle")
    local gatePrompt = gateMiddle and gateMiddle:FindFirstChild("Interaction")

    -- An enabled gate means the rune phase has already been completed.
    if not (gatePrompt and gatePrompt.Enabled) then
        for _, rune in ipairs(golem.Runes) do
            local model = events:FindFirstChild(rune.Name)
            if not golem.runeIsLit(model) then
                local stone = model and model:FindFirstChild("Stone")
                if not golem.nearPart(root, stone, rune.Position) then
                    print("[VampireFarm] Golem rune: moved to " .. rune.Name)
                    return
                end
                local prompt = stone and stone:FindFirstChild("Interaction")
                if not (prompt and prompt:IsA("ProximityPrompt") and prompt.Enabled) then
                    golem.warn("rune prompt unavailable: " .. rune.Name)
                    golem.NextSummonAt = os.clock() + 5
                    return
                end
                if type(fireproximityprompt) ~= "function" then
                    golem.warn("fireproximityprompt is unavailable")
                    golem.NextSummonAt = os.clock() + 20
                    return
                end
                local ok, err = pcall(fireproximityprompt, prompt)
                if not ok then
                    golem.warn("prompt failed: " .. tostring(err))
                    golem.NextSummonAt = os.clock() + 10
                    return
                end
                local deadline = os.clock() + 2
                local button
                repeat
                    button = golem.findInsertButton(rune.Name)
                    if button then break end
                    task.wait(0.1)
                until os.clock() >= deadline or not running
                    or not env.VampireFarmConfig.GolemFarmEnabled
                if not running or not env.VampireFarmConfig.GolemFarmEnabled then
                    return
                end
                if not button or not golem.clickChoice(button) then
                    golem.warn("could not select Insert for " .. rune.Name
                        .. "; check that the rune is in your inventory")
                    golem.NextSummonAt = os.clock() + 20
                    return
                end
                deadline = os.clock() + 4
                repeat
                    if golem.runeIsLit(model) then
                        print("[VampireFarm] Golem rune inserted: " .. rune.Name)
                        return
                    end
                    task.wait(0.2)
                until os.clock() >= deadline or not running
                    or not env.VampireFarmConfig.GolemFarmEnabled
                if not running or not env.VampireFarmConfig.GolemFarmEnabled then
                    return
                end
                golem.warn("no activation observed for " .. rune.Name)
                golem.NextSummonAt = os.clock() + 15
                return
            end
        end
    end

    if (root.Position - golem.IslePosition).Magnitude < 500 then
        return -- Already inside; wait here for the boss model to spawn.
    end
    if not (gatePrompt and gatePrompt.Enabled) then
        golem.warn("all runes appear lit, but WarpGate is not open")
        golem.NextSummonAt = os.clock() + 5
        return
    end
    if not golem.nearPart(root, gateMiddle, golem.GatePosition) then
        print("[VampireFarm] Golem runes complete; moved to WarpGate")
        return
    end
    if type(fireproximityprompt) ~= "function" then
        golem.warn("cannot enter WarpGate without fireproximityprompt")
        golem.NextSummonAt = os.clock() + 20
        return
    end
    local ok, err = pcall(fireproximityprompt, gatePrompt)
    if not ok then
        golem.warn("WarpGate prompt failed: " .. tostring(err))
    else
        print("[VampireFarm] Entering Aetherstone Isle")
    end
    golem.NextSummonAt = os.clock() + 5
end

local PLACE_ANCHORS = {
    {Name = "Capital", Path = {"Entities", "Interactions", "Special Interactions", "Fast Travel 3"}, Position = Vector3.new(2685.36, 141.25, 1704.45)},
    {Name = "Castle Entrance", Path = {"Entities", "Interactions", "Teleports", "CastleTeleporter", "Spawn"}, Position = Vector3.new(2742.33, 321.94, 2946.93)},
    {Name = "Castle Interior", Path = {"Entities", "Interactions", "Teleports", "CastleTeleporter", "InteriorTeleporter", "Spawn"}, Position = Vector3.new(2829.53, 570.42, 10711.36)},
    {Name = "Desert Village", Path = {"Entities", "Interactions", "Special Interactions", "Fast Travel 1"}, Position = Vector3.new(-564.24, 91.75, 1135.25)},
    {Name = "Grasslands Village", Path = {"Entities", "Interactions", "Special Interactions", "Fast Travel 2"}, Position = Vector3.new(1663.49, 74.25, 72.80)},
    {Name = "Tundra Village", Path = {"Entities", "Interactions", "Special Interactions", "Fast Travel"}, Position = Vector3.new(1344.85, 231.75, -3766.69)},
    {Name = "Vampire Region", Path = {"Entities", "Spawns", "VampireSoldierSpawn"}, Position = Vector3.new(616.60, 1813.15, 16565.41)},
}
local placeByName, placeNames = {}, {}
for _, place in ipairs(PLACE_ANCHORS) do
    placeByName[place.Name] = place
    table.insert(placeNames, place.Name)
end
table.sort(placeNames)

local function resolvePlacePosition(place)
    local instance = workspace
    for _, segment in ipairs(place.Path) do
        instance = instance and instance:FindFirstChild(segment)
    end
    if instance and instance:IsA("BasePart") then
        return instance.Position
    end
    local root = instance and getRoot(instance)
    return root and root.Position or place.Position
end

local function teleportManual(destination, facePosition, label)
    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local root = getRoot(character)
    if not (humanoid and humanoid.Health > 0 and root) then
        warn("[VampireFarm] Teleport unavailable until your character is alive")
        return
    end
    teleportPaused = true
    target, targetSource, bossTarget, apexTarget, golem.Target = nil, nil, nil, nil, nil
    golem.ShardTarget = nil
    restoreBreakerVelocity()
    restoreCamera()
    root.AssemblyLinearVelocity = Vector3.zero
    root.AssemblyAngularVelocity = Vector3.zero
    root.CFrame = facePosition and CFrame.lookAt(destination, facePosition)
        or CFrame.new(destination)
    print("[VampireFarm] Teleported to " .. label .. "; farm paused")
end

placeTeleportBox:AddDropdown("TeleportPlace", {
    Text = "Place",
    Values = placeNames,
    Default = placeNames[1],
})
addDropdownSearch(placeTeleportBox, "TeleportPlace", "places")
placeTeleportBox:AddButton("Teleport to Place", function()
    local place = placeByName[Options.TeleportPlace.Value]
    if not place then return end
    teleportManual(resolvePlacePosition(place) + Vector3.new(0, 5, 0),
        nil, place.Name)
end)

local npcFolders = {"Quests", "Special Interactions", "SpecialEvents",
    "Halloween2024", "FillerNpcs"}
local npcByLabel = {}
local npcSignature = ""
npcTeleportBox:AddDropdown("TeleportNPC", {
    Text = "NPC",
    Values = {},
    AllowNull = true,
})
addDropdownSearch(npcTeleportBox, "TeleportNPC", "NPCs")
local function refreshTeleportNPCs()
    local models = {}
    local function addNPC(model)
        if model:IsA("Model") and model ~= player.Character
            and not Players:GetPlayerFromCharacter(model)
            and model:FindFirstChildOfClass("Humanoid") then
            local root = getRoot(model)
            if root then
                table.insert(models, {
                    Model = model,
                    Name = model.Name,
                    ParentName = model.Parent and model.Parent.Name or "Workspace",
                    Position = root.Position,
                })
            end
        end
    end
    local interactions = entities:FindFirstChild("Interactions")
    for _, folderName in ipairs(npcFolders) do
        local folder = interactions and interactions:FindFirstChild(folderName)
        if folder then
            for _, instance in ipairs(folder:GetDescendants()) do
                addNPC(instance)
            end
        end
    end
    for _, instance in ipairs(workspace:GetChildren()) do addNPC(instance) end
    for _, instance in ipairs(entities:GetChildren()) do addNPC(instance) end
    table.sort(models, function(a, b)
        if a.Name ~= b.Name then return a.Name < b.Name end
        if a.ParentName ~= b.ParentName then
            return a.ParentName < b.ParentName
        end
        local aPos, bPos = a.Position, b.Position
        if aPos.X ~= bPos.X then return aPos.X < bPos.X end
        return aPos.Z < bPos.Z
    end)
    local names, lookup, duplicates = {}, {}, {}
    for _, model in ipairs(models) do
        local base = model.Name .. " (" .. model.ParentName .. ")"
        duplicates[base] = (duplicates[base] or 0) + 1
        local label = base .. " #" .. duplicates[base]
        table.insert(names, label)
        lookup[label] = model.Model
    end
    npcByLabel = lookup
    local signature = table.concat(names, "\n")
    if signature == npcSignature then return end
    npcSignature = signature
    local selected = Options.TeleportNPC.Value
    Options.TeleportNPC:SetValues(names)
    if #names > 0 then
        Options.TeleportNPC:SetValue(table.find(names, selected) and selected or names[1])
    end
end
npcTeleportBox:AddButton("Teleport to NPC", function()
    local selected = Options.TeleportNPC.Value
    local model = npcByLabel[selected]
    local npcRoot = model and model:IsDescendantOf(workspace) and getRoot(model)
    if not npcRoot then
        refreshTeleportNPCs()
        warn("[VampireFarm] Selected NPC is not available")
        return
    end
    local destination = (npcRoot.CFrame * CFrame.new(0, 0, 5)).Position
    teleportManual(destination, npcRoot.Position, model.Name)
end)
refreshTeleportNPCs()
task.spawn(function()
    while running do
        refreshTeleportNPCs()
        task.wait(5)
    end
end)

local teleportMobSet = {}
for name in pairs(PRIORITY) do teleportMobSet[name] = true end
for _, name in ipairs(MOB_NAME_SEED) do teleportMobSet[name] = true end
for _, name in ipairs(BOSS_NAME_SEED) do teleportMobSet[name] = true end
for name in pairs(APEX_NAMES) do teleportMobSet[name] = true end
local teleportMobNames = {}
for name in pairs(teleportMobSet) do table.insert(teleportMobNames, name) end
table.sort(teleportMobNames)
mobTeleportBox:AddDropdown("TeleportMob", {
    Text = "Mob",
    Values = teleportMobNames,
    Default = teleportMobNames[1],
})
addDropdownSearch(mobTeleportBox, "TeleportMob", "teleport mobs")
mobTeleportBox:AddButton("Teleport to Mob", function()
    local name = Options.TeleportMob.Value
    if not name then return end
    local myRoot = getRoot(player.Character)
    local best, bestDistance
    local function consider(model)
        if model:IsA("Model") and model.Name == name
            and (model.Parent == enemies
                or (model:GetAttribute("CollisionGroup") == "Enemy"
                    and model:GetAttribute("OverheadType") == nil)) then
            local humanoid = model:FindFirstChildOfClass("Humanoid")
            local mobRoot = getRoot(model)
            if humanoid and humanoid.Health > 0 and mobRoot then
                local distance = myRoot and (mobRoot.Position - myRoot.Position).Magnitude or 0
                if not best or distance < bestDistance then
                    best, bestDistance = mobRoot, distance
                end
            end
        end
    end
    for _, model in ipairs(enemies:GetChildren()) do consider(model) end
    if not best then
        for _, model in ipairs(workspace:GetDescendants()) do consider(model) end
    end
    if best then
        local destination = (best.CFrame * CFrame.new(0, 0, 5)).Position
        teleportManual(destination, best.Position, name)
        return
    end
    local spawnName = MOB_SPAWN_NAMES[name]
        or (name == "Vampire Soldier" and "VampireSoldierSpawn")
    local mobSpawn = spawnName and spawns:FindFirstChild(spawnName)
    if mobSpawn and mobSpawn:IsA("BasePart") then
        teleportManual(mobSpawn.Position + Vector3.new(0, 5, 0),
            nil, name .. " spawn")
    else
        warn("[VampireFarm] No live " .. name .. " is available to teleport to")
    end
end)
teleportControlBox:AddLabel("Manual teleports pause all farms until you resume.", true)
teleportControlBox:AddButton("Resume Farming", function()
    teleportPaused = false
    print("[VampireFarm] Manual teleport pause ended; resuming farms")
end)

local function goToSoldierSpawn(root)
    root.CFrame = CFrame.new(spawn.Position + Vector3.new(0, 5, 0))
    root.AssemblyLinearVelocity = Vector3.zero
    root.AssemblyAngularVelocity = Vector3.zero
    print("[VampireFarm] Moved to VampireSoldierSpawn")
end

local function mobPriority(name)
    local number = tonumber(env.VampireFarmConfig.MobPriorities[name])
    if not number or number ~= number or number == math.huge
        or number == -math.huge then
        return 1
    end
    return math.clamp(math.floor(number), 1, 10)
end

local function targetPriority(model)
    if activeMode == "Vampire" then
        return PRIORITY[model.Name]
    end
    if activeMode == "Mob" and MOB_NAMES[model.Name]
        and env.VampireFarmConfig.SelectedMobs[model.Name] then
        return mobPriority(model.Name)
    end
    return nil
end

local function aliveModel(model)
    local humanoid = model and model:FindFirstChildOfClass("Humanoid")
    return model
        and model:IsDescendantOf(workspace)
        and humanoid
        and humanoid.Health > 0
        and getRoot(model) ~= nil
end

local function eligibleBaseEnemy(model)
    return model and model.Parent == enemies
        and targetPriority(model) ~= nil
        and aliveModel(model)
end

local function eligibleBoss(model)
    if not env.VampireFarmConfig.BossFarmEnabled
        or not model or not BOSS_NAMES[model.Name]
        or not env.VampireFarmConfig.SelectedBosses[model.Name]
        or not aliveModel(model) then
        return false
    end
    if model.Parent == enemies then return true end
    return model:GetAttribute("CollisionGroup") == "Enemy"
        and model:GetAttribute("OverheadType") == nil
end

function golem.eligible(model)
    return env.VampireFarmConfig.GolemFarmEnabled
        and model and model.Name == golem.Name
        and aliveModel(model)
end

function golem.eligibleShard(model)
    return env.VampireFarmConfig.GolemFarmEnabled
        and model and model.Name == "Golem Shard"
        and model.Parent == enemies and aliveModel(model)
end

local function eligibleSpecialBoss(model, name, enabled)
    if not enabled or not model or model.Name ~= name
        or not aliveModel(model) then
        return false
    end
    if model.Parent == enemies then return true end
    return model:GetAttribute("CollisionGroup") == "Enemy"
        and model:GetAttribute("OverheadType") == nil
end

local function eligibleApex(model)
    return eligibleSpecialBoss(model, "Apex",
        env.VampireFarmConfig.ApexFarmEnabled)
end

local function eligiblePrimeApex(model)
    return eligibleSpecialBoss(model, "Prime Apex",
        env.VampireFarmConfig.PrimeApexFarmEnabled)
end

local bossCandidates = setmetatable({}, {__mode = "k"})
local apexCandidates = setmetatable({}, {__mode = "k"})
local function trackBoss(instance)
    if instance:IsA("Model") then
        if instance.Name == golem.Name then
            golem.Candidates[instance] = true
        elseif BOSS_NAMES[instance.Name] then
            bossCandidates[instance] = true
        elseif APEX_NAMES[instance.Name] then
            apexCandidates[instance] = true
        end
    end
end
bossAddedConnection = workspace.DescendantAdded:Connect(function(instance)
    trackBoss(instance)
    if instance:IsA("Model") then
        task.defer(function()
            if running and instance:IsDescendantOf(workspace) then
                trackBoss(instance)
            end
        end)
    end
end)
for _, instance in ipairs(workspace:GetDescendants()) do
    trackBoss(instance)
end

local function bestBoss(fromPosition)
    for _, model in ipairs(enemies:GetChildren()) do
        trackBoss(model)
    end
    local best, bestDistance
    for model in pairs(bossCandidates) do
        if eligibleBoss(model) then
            local distance = (getRoot(model).Position - fromPosition).Magnitude
            if not best or distance < bestDistance then
                best, bestDistance = model, distance
            end
        end
    end
    return best
end

function golem.best(fromPosition)
    local best, bestDistance
    for model in pairs(golem.Candidates) do
        if golem.eligible(model) then
            local distance = (getRoot(model).Position - fromPosition).Magnitude
            if not best or distance < bestDistance then
                best, bestDistance = model, distance
            end
        end
    end
    return best
end

function golem.bestShard(fromPosition)
    local best, bestDistance
    for _, model in ipairs(enemies:GetChildren()) do
        if golem.eligibleShard(model) then
            local distance = (getRoot(model).Position - fromPosition).Magnitude
            if not best or distance < bestDistance then
                best, bestDistance = model, distance
            end
        end
    end
    return best
end

local function bestSpecialBoss(fromPosition, eligible)
    for _, model in ipairs(enemies:GetChildren()) do
        trackBoss(model)
    end
    local best, bestDistance
    for model in pairs(apexCandidates) do
        if eligible(model) then
            local distance = (getRoot(model).Position - fromPosition).Magnitude
            if not best or distance < bestDistance then
                best, bestDistance = model, distance
            end
        end
    end
    return best
end

local function bestApex(fromPosition)
    return bestSpecialBoss(fromPosition, eligibleApex)
end

local function bestPrimeApex(fromPosition)
    return bestSpecialBoss(fromPosition, eligiblePrimeApex)
end

local chestPrompts = setmetatable({}, {__mode = "k"})
local attemptedChestPrompts = setmetatable({}, {__mode = "k"})
local function trackChestPrompt(instance)
    if instance:IsA("ProximityPrompt") then
        chestPrompts[instance] = true
    end
end
chestAddedConnection = workspace.DescendantAdded:Connect(trackChestPrompt)
for _, instance in ipairs(workspace:GetDescendants()) do
    trackChestPrompt(instance)
end

local function chestPartAndRoot(prompt)
    local part, chestRoot
    local instance = prompt.Parent
    while instance and instance ~= workspace do
        if not part and instance:IsA("BasePart") then
            part = instance
        end
        if not chestRoot and instance.Name:lower():find("chest", 1, true) then
            chestRoot = instance
        end
        instance = instance.Parent
    end
    if not chestRoot then
        local text = (prompt.ObjectText .. " " .. prompt.ActionText .. " "
            .. tostring(prompt:GetAttribute("Target") or "")):lower()
        if text:find("chest", 1, true) then
            chestRoot = part
        end
    end
    return part, chestRoot
end

local function chestStateAllows(prompt, chestRoot)
    local instance = prompt
    while instance and instance ~= workspace do
        for _, flag in ipairs({"Opened", "Looted", "Claimed", "Locked", "Disabled", "Depleted"}) do
            if instance:GetAttribute(flag) == true then return false end
        end
        for _, flag in ipairs({"CanOpen", "Available", "Active"}) do
            if instance:GetAttribute(flag) == false then return false end
        end
        if instance == chestRoot then break end
        instance = instance.Parent
    end
    return true
end

local function eligibleChest(prompt)
    if not (prompt and prompt:IsDescendantOf(workspace)
        and prompt.Enabled and prompt.MaxActivationDistance > 0
        and not attemptedChestPrompts[prompt]) then
        return false
    end
    local part, chestRoot = chestPartAndRoot(prompt)
    return part and chestRoot and chestStateAllows(prompt, chestRoot), part, chestRoot
end

local missingPromptWarning = false
local function bestChest(fromPosition)
    if not env.VampireFarmConfig.AutoChestLootEnabled then return nil end
    if type(fireproximityprompt) ~= "function" then
        if not missingPromptWarning then
            warn("[VampireFarm] Auto Chest Loot needs fireproximityprompt in this executor")
            missingPromptWarning = true
        end
        return nil
    end
    local best, bestDistance
    for prompt in pairs(chestPrompts) do
        local eligible, part = eligibleChest(prompt)
        if eligible then
            local distance = (part.Position - fromPosition).Magnitude
            if distance <= env.VampireFarmConfig.ChestLootRadius
                and (not best or distance < bestDistance) then
                best, bestDistance = prompt, distance
            end
        end
    end
    return best
end

local function tryOpenChest(prompt, root)
    local eligible, part, chestRoot = eligibleChest(prompt)
    if not eligible then return end
    root.CFrame = CFrame.new(part.Position + Vector3.new(0, 3, 3))
    root.AssemblyLinearVelocity = Vector3.zero
    root.AssemblyAngularVelocity = Vector3.zero
    task.wait(0.2)
    if not running or not prompt:IsDescendantOf(workspace)
        or not prompt.Enabled or not chestStateAllows(prompt, chestRoot) then
        return
    end
    attemptedChestPrompts[prompt] = true
    local ok, err = pcall(fireproximityprompt, prompt)
    if not ok then
        warn("[VampireFarm] Chest prompt failed: " .. tostring(err))
        return
    end
    task.wait(0.6)
    if not prompt:IsDescendantOf(workspace) or not prompt.Enabled
        or not chestStateAllows(prompt, chestRoot) then
        print("[VampireFarm] Chest opened: " .. chestRoot:GetFullName())
    else
        warn("[VampireFarm] Chest did not visibly open; skipping this instance")
    end
end

local function aliveTarget(model)
    if targetSource == "GolemShard" then
        return model == golem.ShardTarget and golem.eligibleShard(model)
    end
    if targetSource == "Golem" then
        return model == golem.Target and golem.eligible(model)
    end
    if targetSource == "PrimeApex" then
        return model == apexTarget and eligiblePrimeApex(model)
    end
    if targetSource == "Apex" then
        return model == apexTarget and eligibleApex(model)
    end
    if targetSource == "Boss" then
        return model == bossTarget and eligibleBoss(model)
    end
    return eligibleBaseEnemy(model)
end

local function bestEnemy(fromPosition)
    local best, bestPriority, bestDistance

    for _, model in ipairs(enemies:GetChildren()) do
        if eligibleBaseEnemy(model) then
            local priority = targetPriority(model)
            local distance = (getRoot(model).Position - fromPosition).Magnitude

            if not best
                or priority > bestPriority
                or (priority == bestPriority and distance < bestDistance) then
                best, bestPriority, bestDistance = model, priority, distance
            end
        end
    end

    return best
end

local mobSpawnIndex = 0
local nextMobSpawnAt = 0
local lastMobSpawnWarningAt = -math.huge
local function goToSelectedMobSpawn(root)
    if os.clock() < nextMobSpawnAt then return end
    local candidates = {}
    for name, selected in pairs(env.VampireFarmConfig.SelectedMobs) do
        if selected and MOB_NAMES[name] then
            local chosenName = env.VampireFarmConfig.MobSpawnOverrides[name]
                or MOB_SPAWN_NAMES[name]
            local chosenSpawn = chosenName and spawns:FindFirstChild(chosenName)
            if chosenSpawn and chosenSpawn:IsA("BasePart") then
                table.insert(candidates, {
                    Name = name,
                    Spawn = chosenSpawn,
                    Priority = mobPriority(name),
                })
            end
        end
    end
    table.sort(candidates, function(a, b)
        if a.Priority == b.Priority then return a.Name < b.Name end
        return a.Priority > b.Priority
    end)
    if #candidates == 0 then
        if os.clock() - lastMobSpawnWarningAt >= 15 then
            warn("[VampireFarm] Mob Farm has no selected mobs with mapped spawns; select mobs or set a spawn override")
            lastMobSpawnWarningAt = os.clock()
        end
        nextMobSpawnAt = os.clock() + 5
        return
    end
    mobSpawnIndex = mobSpawnIndex % #candidates + 1
    local chosen = candidates[mobSpawnIndex]
    if (root.Position - chosen.Spawn.Position).Magnitude > 80 then
        root.CFrame = CFrame.new(chosen.Spawn.Position + Vector3.new(0, 5, 0))
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
        print("[VampireFarm] Mob Farm moved to " .. chosen.Spawn.Name
            .. " for " .. chosen.Name)
    end
    nextMobSpawnAt = os.clock() + 6
end

local attemptedMobs = setmetatable({}, {__mode = "k"})

golem.killDiagnosticTimes = setmetatable({}, {__mode = "k"})
function golem.reportKillGate(model, reason, force)
    if not model then
        if force then print("[CloverKill] No current farm target") end
        return
    end
    local previous = golem.killDiagnosticTimes[model]
    if force or not previous or os.clock() - previous >= 10 then
        golem.killDiagnosticTimes[model] = os.clock()
        print("[CloverKill] " .. model.Name .. " | " .. reason)
    end
end
function golem.inspectKill(model)
    if not model then return "no target", nil end
    if not env.VampireFarmConfig.InstantKillEnabled then return "toggle is OFF", nil end
    if targetSource == "GolemShard" then return "shards excluded: deaths must register on server", nil end
    if attemptedMobs[model] then return "already attempted for this target", nil end
    local root = getRoot(model)
    local humanoid = model:FindFirstChildOfClass("Humanoid")
    if not root or not humanoid or humanoid.MaxHealth <= 0 then return "root/humanoid unavailable", nil end
    if humanoid.Health <= 0 then return "client health already zero", nil end
    local threshold = currentKillThreshold()
    if targetSource == "Apex" then threshold = currentApexKillThreshold()
    elseif targetSource == "PrimeApex" then threshold = currentPrimeApexKillThreshold()
    elseif targetSource == "Golem" then threshold = golem.killThreshold() end
    local hpPercent = humanoid.Health / humanoid.MaxHealth * 100
    if hpPercent > threshold then return ("HP %.1f%% is above %.1f%% threshold"):format(hpPercent, threshold), nil end
    if type(isnetworkowner) ~= "function" then return "executor does not expose isnetworkowner", nil end
    local checked, owned = pcall(isnetworkowner, root)
    if not checked then return "ownership check failed: " .. tostring(owned), nil end
    if not owned then return "client does not own target physics", nil end
    return ("eligible at %.1f%% HP; local attempt only"):format(hpPercent), humanoid
end
combatBox:AddButton("Print instant-kill status", function()
    local reason = golem.inspectKill(target)
    golem.reportKillGate(target, reason, true)
end)
local function tryOwnedMobLocalKill(model)
    local reason, humanoid = golem.inspectKill(model)
    if not humanoid then
        if env.VampireFarmConfig.InstantKillEnabled then golem.reportKillGate(model, reason, false) end
        return false
    end
    local ok, err = pcall(function() humanoid.Health = 0 end)
    if not ok then
        golem.reportKillGate(model, "health write failed: " .. tostring(err), false)
        return false
    end
    attemptedMobs[model] = true
    golem.reportKillGate(model, reason .. "; client health now " .. tostring(humanoid.Health), true)
    task.delay(0.75, function()
        if not running or not humanoid.Parent then return end
        if humanoid.Health > 0 then
            warn("[CloverKill] Health is positive after the local attempt: " .. model.Name
                .. "; continuing normal combat.")
        else
            print("[CloverKill] Client health remains zero for " .. model.Name
                .. "; this does not confirm a server kill or rewards.")
        end
    end)
    return true
end

local warnedDisabledSpawn = false
local equipCharacter, lastEquipAttempt, equipAttempts = nil, -math.huge, 0

-- Follow in PostSimulation and apply offsets in the mob's local space.
-- Teleport to distant targets immediately when mobs are far apart.
attachConnection = RunService.PostSimulation:Connect(function()
    if not running or not env.VampireFarmConfig.AutoAttachEnabled
        or not aliveTarget(target) then return end

    local character = player.Character
    local myHumanoid = character and character:FindFirstChildOfClass("Humanoid")
    local myRoot = getRoot(character)
    local enemyRoot = getRoot(target)
    if not (myHumanoid and myHumanoid.Health > 0 and myRoot and enemyRoot) then
        return
    end

    local targetCFrame = enemyRoot.CFrame
    if env.VampireFarmConfig.IgnoreRotation then
        targetCFrame = CFrame.new(targetCFrame.Position)
    end

    local voidPoint = workspace:FindFirstChild("Layer2Floor1") and 18.5 or 0
    if env.VampireFarmConfig.PreventVoiding and targetCFrame.Y < voidPoint then
        targetCFrame = CFrame.new(targetCFrame.X, voidPoint, targetCFrame.Z)
    end

    local backCFrame = targetCFrame * CFrame.new(
        boundedOffset(env.VampireFarmConfig.XOffset),
        boundedOffset(env.VampireFarmConfig.YOffset),
        math.clamp(followDistance(), -150, 150)
    )

    myRoot.AssemblyLinearVelocity = Vector3.zero
    myRoot.AssemblyAngularVelocity = Vector3.zero
    if env.VampireFarmConfig.RotateTowards then
        myRoot.CFrame = CFrame.lookAt(backCFrame.Position, targetCFrame.Position)
    else
        myRoot.CFrame = backCFrame
    end
end)

-- Apply the pathfind-breaker velocity after Auto Attach's PostSimulation reset.
-- Restore it before the next render, or before simulation if rendering is off.
breakerSimulationConnection = RunService.PreSimulation:Connect(function()
    if breakerRoot then restoreBreakerVelocity() end
end)
breakerHeartbeatConnection = RunService.Heartbeat:Connect(function()
    if breakerRoot then restoreBreakerVelocity() end
    if not running or not env.VampireFarmConfig.AIBreakerEnabled
        or not env.VampireFarmConfig.AutoAttachEnabled
        or not aliveTarget(target) then return end

    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local root = getRoot(character)
    local enemyRoot = getRoot(target)
    if not (humanoid and humanoid.Health > 0 and root and enemyRoot)
        or root.Anchored then return end

    local mode = env.VampireFarmConfig.AIBreakerType
    local velocity
    if mode == "Passive" then
        velocity = Vector3.new(16, -1e5, -16)
    elseif mode == "Circular" then
        local time = os.clock()
        velocity = Vector3.new(math.cos(time) * 20, -1e4,
            math.sin(time) * 20)
    elseif mode == "Aggressive" then
        local towardEnemy = enemyRoot.Position - root.Position
        velocity = Vector3.new(0, -9e9, 0) - towardEnemy
    else
        velocity = Vector3.new(16, -750, -16)
    end

    breakerRoot = root
    breakerSavedVelocity = root.AssemblyLinearVelocity
    root.AssemblyLinearVelocity = velocity
end)
breakerRenderConnection = RunService.PreRender:Connect(function()
    if breakerRoot then restoreBreakerVelocity() end
end)

local grimoireEquipPauseUntil = -math.huge
local function ensureSelectedWeapon(character)
    if character ~= equipCharacter then
        equipCharacter, lastEquipAttempt, equipAttempts = character, -math.huge, 0
    end
    if os.clock() < grimoireEquipPauseUntil then return end
    if character:FindFirstChild("Weapon") or character:FindFirstChildOfClass("Tool") then
        return
    end
    if os.clock() - lastEquipAttempt < 1 then
        return
    end
    local ok, canEquip = pcall(function()
        return CheckService:Equip(character)
    end)
    if ok and canEquip then
        lastEquipAttempt = os.clock()
        equipAttempts += 1
        local sent, err = pcall(function() action:FireServer("EquipWeapon") end)
        if not sent then
            warn("[VampireFarm] Weapon equip failed: " .. tostring(err))
            return
        end
        print("[VampireFarm] Equipping selected weapon (attempt " .. equipAttempts .. ")")
    end
end

local lastM1Sent = -math.huge
local lastSkillAttempt = {}
local attackWaitStarted
local lastBookAttempt = -math.huge
local nextSkillIndex = 1
local grimoireActivationSerial = 0
function golem.coffinAimPoint(enemy)
    local root = getRoot(player.Character)
    local enemyRoot = getRoot(enemy)
    if not root or not enemyRoot then return nil end
    local delta = enemyRoot.Position - root.Position
    local flat = Vector3.new(delta.X, 0, delta.Z)
    local forward = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
    local direction = flat.Magnitude > 0.01 and flat.Unit
        or (forward.Magnitude > 0.01 and forward.Unit or Vector3.new(0,0,-1))
    local distance = math.min(env.VampireFarmConfig.CoffinAimDistance, flat.Magnitude)
    local ahead = root.Position + direction * distance
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {player.Character, enemy}
    local ground = workspace:Raycast(ahead + Vector3.new(0,6,0), Vector3.new(0,-24,0), params)
    return ground and ground.Position + Vector3.new(0,0.1,0) or ahead
end
function golem.aimCoffin(enemy)
    local point = golem.coffinAimPoint(enemy)
    local camera = workspace.CurrentCamera
    if not point or not camera or game:GetService("UserInputService"):GetFocusedTextBox() then return false end
    local pixel, visible = camera:WorldToScreenPoint(point)
    if not visible or pixel.Z <= 0 then return false end
    return pcall(function()
        game:GetService("VirtualInputManager"):SendMouseMoveEvent(math.floor(pixel.X), math.floor(pixel.Y), game)
    end)
end
local function sendSpellClick(enemy)
    local inputService = game:GetService("UserInputService")
    if inputService:GetFocusedTextBox() then return false, "a text box has focus" end
    local camera = workspace.CurrentCamera
    local enemyRoot = getRoot(enemy)
    if not camera or not enemyRoot then return false, "target/camera unavailable" end
    local aimPoint = enemyRoot.Position
    local equipped = player.Character and player.Character:FindFirstChild("Shadow Magic: Night Coffin")
    if equipped and equipped:IsA("Tool") then aimPoint = golem.coffinAimPoint(enemy) or aimPoint end
    local point, visible = camera:WorldToScreenPoint(aimPoint)
    if not visible or point.Z <= 0 then return false, "target is outside the camera view" end
    local x, y = math.floor(point.X), math.floor(point.Y)
    local gui = player:FindFirstChildOfClass("PlayerGui")
    if gui then
        for _, object in ipairs(gui:GetGuiObjectsAtPosition(x, y)) do
            local screen = object:FindFirstAncestorOfClass("ScreenGui")
            if screen and screen.Name == "CloverDashboard" then
                return false, "hide the Clover menu with RightShift before auto casting"
            end
        end
    end
    local input = game:GetService("VirtualInputManager")
    local sent, err = pcall(function()
        input:SendMouseMoveEvent(x, y, game)
        input:SendMouseButtonEvent(x, y, 0, true, game, 0)
    end)
    if not sent then return false, tostring(err) end
    task.wait(0.08)
    local released, releaseError = pcall(function()
        input:SendMouseButtonEvent(x, y, 0, false, game, 0)
    end)
    if not released then
        pcall(function() input:SendMouseButtonEvent(x, y, 0, false, game, 0) end)
        return false, tostring(releaseError)
    end
    return true
end
local function activateGrimoireTool(character, enemy, tool)
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid or not tool.Enabled then return false end
    if tool.Parent ~= character then
        local equipped = pcall(function() humanoid:EquipTool(tool) end)
        if not equipped then return false end
        local deadline = os.clock() + 0.75
        while running and tool.Parent ~= character and os.clock() < deadline do
            task.wait(0.05)
        end
    end
    if not running or player.Character ~= character or tool.Parent ~= character
        or not tool.Enabled or not aliveTarget(enemy) then return false end

    local status = character:FindFirstChild("Status")
    local casting = status and status:FindFirstChild("Casting")
    local cooldown = status and status:FindFirstChild("Cooldown")
    if casting and casting.Value then return false end
    -- Allow the spell's equip handler to connect its activation listeners.
    task.wait(0.15)
    if not running or player.Character ~= character or tool.Parent ~= character
        or not aliveTarget(enemy) then return false end
    if tool.Name == "Shadow Magic: Night Coffin" then
        golem.aimCoffin(enemy)
        task.wait()
        if not running or player.Character ~= character or tool.Parent ~= character or not aliveTarget(enemy) then return false end
        golem.aimCoffin(enemy)
    end
    local activated, err = pcall(function() tool:Activate() end)
    if not activated then
        warn("[CloverSkills] Activation error for " .. tool.Name .. ": " .. tostring(err))
        return false
    end
    grimoireActivationSerial += 1
    local activationSerial = grimoireActivationSerial
    grimoireEquipPauseUntil = os.clock() + 2
    local startedAt = os.clock()
    local deadline = startedAt + 1.5
    local inputFallbackSent = false
    local confirmed = false
    repeat
        if (casting and casting.Value)
            or (cooldown and cooldown:FindFirstChild(tool.Name)) then
            confirmed = true
            break
        end
        if not inputFallbackSent and os.clock() - startedAt >= 0.35 then
            inputFallbackSent = true
            if running and player.Character == character and tool.Parent == character
                and aliveTarget(enemy) then
                local clicked, clickError = sendSpellClick(enemy)
                if clicked then
                    print("[CloverSkills] Normal input fallback: " .. tool.Name)
                else
                    warn("[CloverSkills] Input fallback blocked: " .. tostring(clickError))
                end
            end
        end
        if tool.Name == "Shadow Magic: Night Coffin" and running and aliveTarget(enemy) then golem.aimCoffin(enemy) end
        task.wait(0.05)
    until not running or player.Character ~= character or os.clock() >= deadline

    if not confirmed then
        warn("[CloverSkills] No cast/cooldown confirmation for " .. tool.Name
            .. "; no casting/cooldown change was observed after the activation attempts.")
        if running and player.Character == character and tool.Parent == character then
            pcall(function() tool:Deactivate() end)
            pcall(function() humanoid:UnequipTools() end)
        end
        grimoireEquipPauseUntil = os.clock() + 0.25
        return false
    end
    print("[CloverSkills] Cast confirmed: " .. tool.Name)
    grimoireEquipPauseUntil = os.clock() + 30
    task.spawn(function()
        local finishDeadline = os.clock() + 30
        while running and player.Character == character and tool.Parent == character
            and casting and casting.Value and os.clock() < finishDeadline do
            task.wait(0.1)
        end
        if activationSerial ~= grimoireActivationSerial then return end
        if running and player.Character == character and tool.Parent == character
            and os.clock() >= finishDeadline and casting and casting.Value then
            warn("[CloverSkills] Cast still active after 30s: " .. tool.Name
                .. "; leaving the spell equipped.")
        elseif running and player.Character == character and tool.Parent == character then
            pcall(function() tool:Deactivate() end)
            pcall(function() humanoid:UnequipTools() end)
        end
        grimoireEquipPauseUntil = os.clock() + 0.25
    end)
    return true
end
local function trySelectedSkill(character, enemy)
    if not env.VampireFarmConfig.AutoSkillEnabled
        or not aliveTarget(enemy) then
        return false
    end

    local status = character:FindFirstChild("Status")
    local cooldown = status and status:FindFirstChild("Cooldown")
    local casting = status and status:FindFirstChild("Casting")
    if not cooldown then return false end
    if casting and casting.Value == true then return false end

    local myRoot = getRoot(character)
    local enemyRoot = getRoot(enemy)
    if not (myRoot and enemyRoot)
        or (myRoot.Position - enemyRoot.Position).Magnitude > 18 then
        return false
    end

    local waitingForAttack = false
    local combat = status:FindFirstChild("Combat")
    local available = getAvailableSkills()
    for offset = 0, #available - 1 do
        local index = (nextSkillIndex + offset - 1) % #available + 1
        local skill = available[index]
        local name = skill.Name
        if env.VampireFarmConfig.SelectedSkills[skill.Key]
            and not cooldown:FindFirstChild(name)
            and os.clock() - (lastSkillAttempt[skill.Key] or -math.huge)
                >= SKILL_RETRY_INTERVAL then
            if skill.Kind == "Weapon" then
                if character:FindFirstChild("Weapon") then
                    local ok, ready = pcall(function()
                        return CheckService:Skill(character, name)
                    end)
                    if ok and ready then
                        if not aliveTarget(enemy) then return false end
                        lastSkillAttempt[skill.Key] = os.clock()
                        nextSkillIndex = index % #available + 1
                        attackWaitStarted = nil
                        local sent, err = pcall(function()
                            action:FireServer("Toolbar", {WeaponSkill = name})
                        end)
                        if sent then return true end
                        warn("[VampireFarm] Weapon skill failed: " .. tostring(err))
                    end
                    if combat and combat:GetAttribute("Attacking") == true then
                        waitingForAttack = true
                    end
                end
            else
                local book = status:FindFirstChild("Grimoire")
                if book and book:IsA("BoolValue") and not book.Value then
                    if os.clock() - lastBookAttempt >= 3 then
                        if not aliveTarget(enemy) then return false end
                        lastBookAttempt = os.clock()
                        local sent, err = pcall(function()
                            action:FireServer("Book")
                        end)
                        if sent then
                            grimoireEquipPauseUntil = os.clock() + 2.5
                            return true
                        end
                        warn("[VampireFarm] Grimoire equip failed: " .. tostring(err))
                    end
                else
                    local tool = skill.Tool
                    if tool and tool.Enabled
                        and (tool.Parent == character
                            or tool.Parent == player:FindFirstChildOfClass("Backpack")) then
                        if not aliveTarget(enemy) then return false end
                        lastSkillAttempt[skill.Key] = os.clock()
                        if activateGrimoireTool(character, enemy, tool) then
                            lastSkillAttempt[skill.Key] = os.clock()
                            nextSkillIndex = index % #available + 1
                            attackWaitStarted = nil
                            return true
                        end
                    end
                end
            end
        end
    end
    -- Give an M1 animation a short gap without stalling the farm forever.
    if waitingForAttack then
        attackWaitStarted = attackWaitStarted or os.clock()
        if os.clock() - attackWaitStarted < 1.5 then return true end
    end
    attackWaitStarted = nil
    return false
end

RunService:BindToRenderStep(cameraBinding, Enum.RenderPriority.Camera.Value + 1, function()
    if not running then return end
    local camera = workspace.CurrentCamera
    local myRoot = getRoot(player.Character)
    local enemyRoot = getRoot(target)
    if not (camera and myRoot and aliveTarget(target) and enemyRoot) then
        restoreCamera()
        return
    end
    if not previousCameraType then
        previousCameraType = camera.CameraType
        previousCameraSubject = camera.CameraSubject
    end
    local focus = enemyRoot.Position + Vector3.new(0, 2, 0)
    local cameraPosition = myRoot.Position - myRoot.CFrame.LookVector * env.VampireFarmConfig.FarmCameraDistance
        + Vector3.new(0, 5, 0)
    camera.CameraType = Enum.CameraType.Scriptable
    camera.CFrame = CFrame.lookAt(cameraPosition, focus)
    camera.Focus = CFrame.new(focus)
end)

print("[VampireFarm] Started in " .. activeMode .. " mode; local kill threshold "
    .. currentKillThreshold() .. "%")

task.spawn(function()
    local observedCharacter
    local requested = false
    while running do
        local character = player.Character
        if character ~= observedCharacter then observedCharacter = character; requested = false end
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        if env.VampireFarmConfig.AutoResetEnabled and not requested and humanoid
            and humanoid.MaxHealth > 0 and humanoid.Health > 0
            and humanoid.Health / humanoid.MaxHealth * 100 <= env.VampireFarmConfig.AutoResetHealthPercent then
            requested = true
            local ok, err = pcall(function() humanoid.Health = 0 end)
            if ok then print("[CloverHealth] Low HP reset requested")
            else warn("[CloverHealth] Reset failed: " .. tostring(err)) end
        end
        task.wait(0.25)
    end
end)
local function updateTarget(fromPosition)
    local primeApex
    if env.VampireFarmConfig.PrimeApexFarmEnabled then
        primeApex = eligiblePrimeApex(apexTarget) and apexTarget
            or bestPrimeApex(fromPosition)
    end
    if primeApex then
        if target ~= primeApex or targetSource ~= "PrimeApex" then
            print("[VampireFarm] Prime Apex priority: " .. primeApex.Name
                .. " at " .. tostring(getRoot(primeApex).Position))
        end
        apexTarget = primeApex
        target = primeApex
        targetSource = "PrimeApex"
        return
    end

    local apex
    if env.VampireFarmConfig.ApexFarmEnabled then
        apex = eligibleApex(apexTarget) and apexTarget or bestApex(fromPosition)
    end
    if apex then
        if target ~= apex or targetSource ~= "Apex" then
            print("[VampireFarm] Apex priority: " .. apex.Name
                .. " at " .. tostring(getRoot(apex).Position))
        end
        apexTarget = apex
        target = apex
        targetSource = "Apex"
        return
    end
    if targetSource == "Apex" or targetSource == "PrimeApex" then
        print("[VampireFarm] Apex target cleared; resuming other farms")
        target = nil
        targetSource = nil
    end
    apexTarget = nil

    local foundGolem
    if env.VampireFarmConfig.GolemFarmEnabled then
        foundGolem = golem.eligible(golem.Target) and golem.Target
            or golem.best(fromPosition)
    end
    if foundGolem then
        golem.Target = foundGolem
        local shard = golem.eligibleShard(golem.ShardTarget)
            and golem.ShardTarget or golem.bestShard(fromPosition)
        if shard then
            if target ~= shard or targetSource ~= "GolemShard" then
                print("[VampireFarm] Golem Shard priority: "
                    .. tostring(getRoot(shard).Position))
            end
            golem.ShardTarget = shard
            target = shard
            targetSource = "GolemShard"
            return
        end
        golem.ShardTarget = nil
        if target ~= foundGolem or targetSource ~= "Golem" then
            print("[VampireFarm] Golem priority: " .. foundGolem.Name
                .. " at " .. tostring(getRoot(foundGolem).Position))
        end
        target = foundGolem
        targetSource = "Golem"
        return
    end
    if targetSource == "Golem" or targetSource == "GolemShard" then
        print("[VampireFarm] Golem cleared; resuming farm or summon route")
        target = nil
        targetSource = nil
    end
    golem.Target = nil
    golem.ShardTarget = nil

    local boss
    if env.VampireFarmConfig.BossFarmEnabled then
        boss = eligibleBoss(bossTarget) and bossTarget or bestBoss(fromPosition)
    end
    if boss then
        if target ~= boss or targetSource ~= "Boss" then
            print("[VampireFarm] Boss priority: " .. boss.Name
                .. " at " .. tostring(getRoot(boss).Position))
        end
        bossTarget = boss
        target = boss
        targetSource = "Boss"
        return
    end

    if targetSource == "Boss" then
        print("[VampireFarm] Boss cleared; resuming " .. activeMode .. " farm")
        target = nil
        targetSource = nil
    end
    bossTarget = nil
    if env.VampireFarmConfig.GolemFarmEnabled
        and os.clock() >= golem.NextSummonAt then
        target = nil
        targetSource = "GolemSummon"
        return
    end
    if activeMode == "Off" then
        target = nil
        targetSource = nil
        return
    end

    local best = bestEnemy(fromPosition)
    if targetSource ~= "Base" or not eligibleBaseEnemy(target)
        or (best and targetPriority(best) > targetPriority(target)) then
        target = best
        targetSource = target and "Base" or nil
        if target then
            nextMobSpawnAt = 0
            print("[VampireFarm] Target acquired: " .. target.Name
                .. " at " .. tostring(getRoot(target).Position))
        end
    end
end

while running do
    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local myRoot = getRoot(character)

    if not (humanoid and humanoid.Health > 0 and myRoot) then
        target = nil
        targetSource = nil
        task.wait(1)
    elseif teleportPaused then
        target = nil
        targetSource = nil
        task.wait(0.25)
    else
        updateTarget(myRoot.Position)

        if targetSource ~= "Boss" and targetSource ~= "Golem"
            and targetSource ~= "GolemShard"
            and targetSource ~= "GolemSummon" and targetSource ~= "Apex"
            and targetSource ~= "PrimeApex" then
            local chest = bestChest(myRoot.Position)
            if chest then
                target = nil
                targetSource = nil
                restoreCamera()
                tryOpenChest(chest, myRoot)
                task.wait(0.2)
                continue
            end
        end

        if targetSource == "GolemSummon" then
            restoreCamera()
            golem.summonStep(myRoot)
            task.wait(0.3)
        elseif not target then
            if activeMode == "Vampire" then
                if (myRoot.Position - spawn.Position).Magnitude > 80 then
                    goToSoldierSpawn(myRoot)
                end

                if not warnedDisabledSpawn
                    and spawn:GetAttribute("spawn_enabled") == false then
                    warnedDisabledSpawn = true
                    warn("[VampireFarm] VampireSoldierSpawn reports spawn_enabled=false; proximity may not activate it")
                end
            elseif activeMode == "Mob" then
                goToSelectedMobSpawn(myRoot)
            end

            task.wait(activeMode == "Off" and 0.3 or 1)
        else
            ensureSelectedWeapon(character)

            if not aliveTarget(target) then
                target = nil
                continue
            end

            if tryOwnedMobLocalKill(target) then
                target = nil
                task.wait(ATTACK_INTERVAL)
                continue
            end

            -- Keep M1 regular even when selected skills are always ready.
            local skillUsed = false
            if env.VampireFarmConfig.AutoSkillEnabled
                and os.clock() - lastM1Sent < ATTACK_INTERVAL * 2
                and aliveTarget(target) then
                skillUsed = trySelectedSkill(character, target)
            end
            local attackStatus = character:FindFirstChild("Status")
            local activeCast = attackStatus and attackStatus:FindFirstChild("Casting")
            if not skillUsed and not (activeCast and activeCast.Value)
                and aliveTarget(target) then
                local sent, err = pcall(function()
                    action:FireServer("M1", {password = "Spirit"})
                end)
                if sent then
                    lastM1Sent = os.clock()
                else
                    warn("[VampireFarm] M1 failed: " .. tostring(err))
                end
            end
            task.wait(ATTACK_INTERVAL)
        end
    end
end




