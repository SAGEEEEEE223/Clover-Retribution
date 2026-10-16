-- Clover Hub: complete-source merge (ore, Kraken, party, mana); farms idle on startup.
local env=getgenv()
if type(env.StopCloverHub)=="function" then pcall(env.StopCloverHub) end
local player=game:GetService("Players").LocalPlayer
local runtime={controls={},saveSerial=0}
runtime.settingsPath="CloverHub-settings-"..tostring(player.UserId)..".json"
env.CloverRuntime=runtime
-- A visible boot card is rendered before profile setup, then removed after its entrance.
local boot=Instance.new("ScreenGui")
boot.Name="CloverBoot"; boot.ResetOnSpawn=false; boot.DisplayOrder=100
boot.Parent=player:WaitForChild("PlayerGui")
local card=Instance.new("CanvasGroup")
card.AnchorPoint=Vector2.new(.5,.5); card.Position=UDim2.fromScale(.5,.5)
card.Size=UDim2.fromOffset(330,112); card.BackgroundColor3=Color3.fromRGB(17,20,17)
card.BorderSizePixel=0; card.GroupTransparency=1; card.Parent=boot
local corner=Instance.new("UICorner"); corner.CornerRadius=UDim.new(0,16); corner.Parent=card
local bootScale=Instance.new("UIScale"); bootScale.Scale=.7; bootScale.Parent=card
local title=Instance.new("TextLabel"); title.BackgroundTransparency=1; title.Size=UDim2.new(1,0,0,45)
title.Position=UDim2.fromOffset(0,18); title.Font=Enum.Font.GothamBold; title.TextSize=25
title.TextColor3=Color3.fromRGB(190,219,65); title.Text="CLOVER"; title.Parent=card
local detail=Instance.new("TextLabel"); detail.BackgroundTransparency=1; detail.Size=UDim2.new(1,0,0,25)
detail.Position=UDim2.fromOffset(0,65); detail.Font=Enum.Font.Gotham; detail.TextSize=12
detail.TextColor3=Color3.fromRGB(190,196,182); detail.Text="Preparing your controls…"; detail.Parent=card
game:GetService("RunService").RenderStepped:Wait()
local bootTween=game:GetService("TweenService")
bootTween:Create(bootScale,TweenInfo.new(.65,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{Scale=1}):Play()
bootTween:Create(card,TweenInfo.new(.4),{GroupTransparency=0}):Play()
runtime.closeBoot=function()
    if not boot.Parent or runtime.bootClosing then return end
    runtime.bootClosing=true
    detail.Text="Ready"
    task.delay(.65,function()
        if not boot.Parent then return end
        local fade=bootTween:Create(card,TweenInfo.new(.3),{GroupTransparency=1})
        fade.Completed:Once(function() boot:Destroy() end); fade:Play()
    end)
end
task.delay(20,runtime.closeBoot)

local function createCloverLibrary()
    local UIS = game:GetService("UserInputService")
    local Tween = game:GetService("TweenService")
    local toggles, options, connections = {}, {}, {}
    local lib = {Unloaded = false, ToggleKeybind = false :: any, CleanupCallbacks={}}
    local colors = {bg = Color3.fromRGB(13,15,14), panel = Color3.fromRGB(21,23,21),
        field = Color3.fromRGB(34,37,32), line = Color3.fromRGB(49,53,44),
        text = Color3.fromRGB(245,247,239), muted = Color3.fromRGB(178,185,169),
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
    local motionTweens={}
    local function animate(object,duration,properties,style)
        if motionTweens[object] then motionTweens[object]:Cancel() end
        local tween=Tween:Create(object,TweenInfo.new(duration,style or Enum.EasingStyle.Quint,Enum.EasingDirection.Out),properties)
        motionTweens[object]=tween
        tween.Completed:Once(function() if motionTweens[object]==tween then motionTweens[object]=nil end end)
        tween:Play()
        return tween
    end
    local function button(parent, text)
        local b = make("TextButton", {Text=text, BackgroundColor3=colors.field,
            TextColor3=colors.text, Font=Enum.Font.Gotham, TextSize=12,
            AutoButtonColor=false, BorderSizePixel=0, TextTruncate=Enum.TextTruncate.AtEnd}, parent)
        round(b, 8)
        local pressScale=make("UIScale",{Scale=1},b)
        connect(b.InputBegan,function(input)
            if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
                animate(pressScale,.09,{Scale=.96},Enum.EasingStyle.Quad)
            end
        end)
        connect(b.InputEnded,function(input)
            if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
                animate(pressScale,.22,{Scale=1},Enum.EasingStyle.Back)
            end
        end)
        connect(b.MouseLeave,function() animate(pressScale,.18,{Scale=1}) end)
        local hoverColor
        b.MouseEnter:Connect(function()
            if b:GetAttribute("NoHover") then return end
            hoverColor=b.BackgroundColor3
            Tween:Create(b,TweenInfo.new(.12),{BackgroundColor3=hoverColor:Lerp(colors.text,.055)}):Play()
        end)
        b.MouseLeave:Connect(function()
            if hoverColor and not b:GetAttribute("NoHover") then
                Tween:Create(b,TweenInfo.new(.12),{BackgroundColor3=hoverColor}):Play()
            end
        end)
        return b
    end
    local function observable(initial,id)
        local scope=tostring(runtime.profile or "Shared")..":"..tostring(id)
        local saved=runtime.controls[scope]
        if saved~=nil and (initial==nil or type(saved)==type(initial)) then
            initial=type(saved)=="table" and table.clone(saved) or saved
        end
        local o = {Value=initial}
        function o:OnChanged(callback) self.callback=callback; callback(self.Value) end
        function o:SetValue(value)
            if self.Value == value then return end
            self.Value=value
            if self.render then self.render() end
            if self.callback then self.callback(value) end
            runtime.controls[scope]=type(self.Value)=="table" and table.clone(self.Value) or self.Value
            if runtime.requestSave then runtime.requestSave() end
        end
        return o
    end
    local screen = make("ScreenGui", {Name="CloverDashboard", ResetOnSpawn=false,
        ZIndexBehavior=Enum.ZIndexBehavior.Sibling, DisplayOrder=80}, player:WaitForChild("PlayerGui"))
    local window
    local wantedVisible=true
    local visibilitySerial=0
    local windowScale,windowBaseScale= nil,1
    local windowTween
    function lib:Toggle()
        if not window or self.Unloaded then return end
        wantedVisible=not wantedVisible
        visibilitySerial+=1
        local serial=visibilitySerial
        if windowTween then windowTween:Cancel() end
        if wantedVisible then window.Visible=true end
        if windowScale then
            if wantedVisible and not windowTween then windowScale.Scale=windowBaseScale*.92 end
            animate(windowScale,wantedVisible and .3 or .15,{Scale=windowBaseScale*(wantedVisible and 1 or .94)},wantedVisible and Enum.EasingStyle.Back or Enum.EasingStyle.Quad)
        end
        windowTween=Tween:Create(window,TweenInfo.new(.16,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),
            {GroupTransparency=wantedVisible and 0 or 1})
        windowTween.Completed:Once(function()
            if serial==visibilitySerial and not wantedVisible and not self.Unloaded then window.Visible=false end
        end)
        windowTween:Play()
    end
    function lib:OnUnload(callback) self.unloadCallback=callback end
    function lib:RegisterCleanup(callback) table.insert(self.CleanupCallbacks,callback) end
    function lib:Unload()
        if self.Unloaded then return end
        self.Unloaded=true
        for object,tween in pairs(motionTweens) do tween:Cancel(); motionTweens[object]=nil end
        for _, c in ipairs(connections) do c:Disconnect() end
        for _,callback in ipairs(self.CleanupCallbacks) do pcall(callback) end
        screen:Destroy()
        if self.unloadCallback then self.unloadCallback() end
    end
    function lib:CreateWindow(settings)
        window=make("CanvasGroup", {GroupTransparency=0,Size=UDim2.fromOffset(820,590), AnchorPoint=Vector2.new(.5,.5),
            Position=UDim2.fromScale(.5,.5), BackgroundColor3=colors.bg, BorderSizePixel=0}, screen)
        round(window,14)
        make("UIStroke", {Color=colors.line, Thickness=1}, window)
        local scale=make("UIScale", {}, window); windowScale=scale
        local function resize()
            local camera=workspace.CurrentCamera
            if camera then windowBaseScale=math.max(.2,math.min(1, (camera.ViewportSize.X-24)/820, (camera.ViewportSize.Y-24)/590)); scale.Scale=windowBaseScale end
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
        local subtitle=label(sidebar,string.upper(runtime.profile or "RETRIBUTION"),10)
        subtitle.Position=UDim2.fromOffset(16,39); subtitle.TextColor3=colors.muted
        local nav=make("ScrollingFrame", {BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=2,AutomaticCanvasSize=Enum.AutomaticSize.Y,CanvasSize=UDim2.new(), Position=UDim2.fromOffset(10,120),
            Size=UDim2.new(1,-20,1,-174)}, sidebar)
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
        local search=make("TextBox",{Text="",PlaceholderText="Find a tab...",ClearTextOnFocus=false,
            BackgroundColor3=colors.field,TextColor3=colors.text,PlaceholderColor3=colors.muted,
            Font=Enum.Font.Gotham,TextSize=12,TextXAlignment=Enum.TextXAlignment.Left,
            Position=UDim2.fromOffset(10,80),Size=UDim2.new(1,-20,0,30),BorderSizePixel=0},sidebar)
        round(search,8); make("UIPadding",{PaddingLeft=UDim.new(0,9)},search)
        connect(search:GetPropertyChangedSignal("Text"),function()
            local query=search.Text:lower()
            for _,entry in ipairs(pages) do entry.button.Visible=entry.name:lower():find(query,1,true)~=nil end
            nav.CanvasPosition=Vector2.zero
        end)
        local function group(parent,title)
            local section=make("Frame", {BackgroundColor3=colors.panel, BorderSizePixel=0,
                Size=UDim2.new(1,0,0,0), AutomaticSize=Enum.AutomaticSize.Y},parent)
            round(section,12); make("UIStroke",{Color=colors.line},section)
            make("UIPadding",{PaddingTop=UDim.new(0,12),PaddingBottom=UDim.new(0,12),
                PaddingLeft=UDim.new(0,12),PaddingRight=UDim.new(0,12)},section)
            make("UIListLayout",{Padding=UDim.new(0,8),SortOrder=Enum.SortOrder.LayoutOrder},section)
            local titleLabel=label(section,string.upper(title),11); titleLabel.TextColor3=colors.muted
            local g={}
            local order=0
            local function row(height)
                order+=1
                return make("Frame",{BackgroundTransparency=1,Size=UDim2.new(1,0,0,height or 34),LayoutOrder=order},section)
            end
            function g:AddLabel(text,wrap)
                local r=row(wrap and 58 or 26)
                local l=label(r,text,12); l.Size=UDim2.fromScale(1,1); l.TextWrapped=true; l.TextColor3=colors.muted
                local result={}
                function result:SetText(text) l.Text=tostring(text) end
                function result:AddKeyPicker(id,data)
                    local o=observable(data.Default,id); options[id]=o
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
                local b=button(r,""); b:SetAttribute("NoHover",true); b.Size=UDim2.fromOffset(38,22); b.Position=UDim2.new(1,-38,.5,-11)
                local dot=make("Frame",{Size=UDim2.fromOffset(16,16),BackgroundColor3=colors.text,BorderSizePixel=0},b); round(dot,20)
                local o=observable(data.Default==true,id); toggles[id]=o
                o.render=function()
                    b.BackgroundColor3=o.Value and colors.accent or colors.field
                    animate(dot,.2,{Position=UDim2.fromOffset(o.Value and 19 or 3,3)},Enum.EasingStyle.Back)
                end
                o.render(); connect(b.Activated,function() o:SetValue(not o.Value) end); return o
            end
            function g:AddInput(id,data)
                local r=row(57); label(r,data.Text,12)
                local b=make("TextBox",{Text=tostring(data.Default or ""),PlaceholderText=data.Placeholder or "Enter value",
                    ClearTextOnFocus=false,BackgroundColor3=colors.field,TextColor3=colors.text,
                    PlaceholderColor3=colors.muted,Font=Enum.Font.Gotham,TextSize=12,
                    Size=UDim2.new(1,0,0,29),Position=UDim2.fromOffset(0,25),BorderSizePixel=0},r); round(b,8)
                local o=observable(tostring(data.Default or ""),id); options[id]=o
                o.render=function() if b.Text~=tostring(o.Value) then b.Text=tostring(o.Value) end end
                local function changed() o:SetValue(b.Text) end
                if data.Finished==false then connect(b:GetPropertyChangedSignal("Text"),changed) else connect(b.FocusLost,changed) end
                return o
            end
            function g:AddSlider(id,data)
                local r=row(50); local sliderLabel=label(r,data.Text,12); sliderLabel.Size=UDim2.new(.7,0,0,22)
                local valueLabel=label(r,"",11); valueLabel.Size=UDim2.new(.3,0,0,22); valueLabel.Position=UDim2.fromScale(.7,0); valueLabel.TextXAlignment=Enum.TextXAlignment.Right
                local track=button(r,""); track:SetAttribute("NoHover",true); track.Size=UDim2.new(1,0,0,8); track.Position=UDim2.fromOffset(0,34)
                local fill=make("Frame",{BackgroundColor3=colors.accent,BorderSizePixel=0,Size=UDim2.fromScale(0,1)},track); round(fill,8)
                local o=observable(data.Default or data.Min,id); options[id]=o
                o.render=function()
                    valueLabel.Text=tostring(o.Value)
                    Tween:Create(fill,TweenInfo.new(.09),{Size=UDim2.fromScale(math.clamp((o.Value-data.Min)/(data.Max-data.Min),0,1),1)}):Play()
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
                local r=row(57); label(r,data.Text,12)
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
                local o=observable(initial,id); o.Values=table.clone(data.Values or {}); options[id]=o
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
            for _,existing in ipairs(pages) do if existing.name==name then return existing.tab end end
            local tabButton=button(nav,name); tabButton:SetAttribute("NoHover",true); tabButton.Size=UDim2.new(1,0,0,36); tabButton.TextXAlignment=Enum.TextXAlignment.Left
            make("UIPadding",{PaddingLeft=UDim.new(0,12)},tabButton)
            local page=make("ScrollingFrame",{BackgroundTransparency=1,BorderSizePixel=0,ClipsDescendants=true,
                Position=UDim2.fromOffset(200,52),Size=UDim2.new(1,-218,1,-68),ScrollBarThickness=3,
                ScrollBarImageColor3=colors.accent,CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.Y,Visible=first},window)
            local columns={}
            for i=1,2 do
                columns[i]=make("Frame",{BackgroundTransparency=1,Position=UDim2.new((i-1)*.5,(i-1)*6,0,2),
                    Size=UDim2.new(.5,-8,0,0),AutomaticSize=Enum.AutomaticSize.Y},page)
                make("UIListLayout",{Padding=UDim.new(0,14),SortOrder=Enum.SortOrder.LayoutOrder},columns[i])
            end
                        local indicator=make("Frame",{BackgroundColor3=colors.accent,BorderSizePixel=0,
                Position=UDim2.fromOffset(0,9),Size=UDim2.fromOffset(3,18),Visible=first},tabButton)
            round(indicator,3)
            local entry={page=page,button=tabButton,name=name,indicator=indicator}; table.insert(pages,entry)
            local function activate()
                header.Text=string.upper(name).."  /  CLOVER RETRIBUTION"
                for _,item in ipairs(pages) do
                    local selected=item==entry; item.page.Visible=selected; item.indicator.Visible=selected
                    if selected then
                        item.page.Position=UDim2.fromOffset(208,52)
                        animate(item.page,.22,{Position=UDim2.fromOffset(200,52)})
                        item.indicator.Size=UDim2.fromOffset(3,6); animate(item.indicator,.25,{Size=UDim2.fromOffset(3,18)},Enum.EasingStyle.Back)
                    end
                    Tween:Create(item.button,TweenInfo.new(.14),{BackgroundColor3=selected and Color3.fromRGB(39,46,24) or colors.panel}):Play()
                    item.button.TextColor3=selected and colors.accent or colors.muted
                end
            end
            connect(tabButton.Activated,activate)
            if first then first=false; activate() else tabButton.BackgroundColor3=colors.panel; tabButton.TextColor3=colors.muted end
            local tab={}
            entry.tab=tab
            function tab:AddLeftGroupbox(title) return group(columns[1],title) end
            function tab:AddRightGroupbox(title) return group(columns[2],title) end
            return tab
        end
        window.GroupTransparency=1; window.Visible=false
        function lib:PlayEntrance()
            if self.Unloaded then return end
            window.Visible=true
            local destination=window.Position
            window.Position=destination+UDim2.fromOffset(0,40)
            window.GroupTransparency=1; scale.Scale=windowBaseScale*.78
            animate(scale,.75,{Scale=windowBaseScale},Enum.EasingStyle.Back)
            animate(window,.65,{GroupTransparency=0,Position=destination})
            if self.HUDEntrance then self.HUDEntrance() end
        end
        runtime.configureUI(lib,result,toggles,options)
        task.defer(function()
            task.wait(.3)
            if lib.Unloaded or runtime.library~=lib then return end
            runtime.starting=false
            lib:PlayEntrance()
            if runtime.closeBoot then runtime.closeBoot() end
            print("[CloverHub] Startup animation v3")
        end)
        return result
    end
    function lib:CreateHUD(settings)
        local hud=make("CanvasGroup",{Name="StatusHUD",BackgroundColor3=colors.panel,BorderSizePixel=0,
            Position=UDim2.fromOffset(24,110),Size=UDim2.fromOffset(284,306),GroupTransparency=1,
            Visible=settings.Visible~=false},screen)
        round(hud,13)
        make("UIStroke",{Color=colors.line,Thickness=1},hud)
        local hudScale=make("UIScale",{},hud)
        local hudBaseScale=1
        local function fitHUD()
            local camera=workspace.CurrentCamera
            if camera then hudBaseScale=math.max(.55,math.min(1,(camera.ViewportSize.X-32)/284,(camera.ViewportSize.Y-40)/306)); hudScale.Scale=hudBaseScale end
        end
        local hudViewportConnection
        local function bindHUDCamera()
            if hudViewportConnection then hudViewportConnection:Disconnect() end
            local camera=workspace.CurrentCamera
            if camera then hudViewportConnection=connect(camera:GetPropertyChangedSignal("ViewportSize"),fitHUD) end
            fitHUD()
        end
        bindHUDCamera(); connect(workspace:GetPropertyChangedSignal("CurrentCamera"),bindHUDCamera)
        local brand=label(hud,"CLOVER",14); brand.Font=Enum.Font.GothamBold
        brand.TextColor3=colors.accent; brand.Position=UDim2.fromOffset(14,10); brand.Size=UDim2.fromOffset(130,24)
        local titleDrag=make("TextButton",{Text="",BackgroundTransparency=1,Position=UDim2.fromOffset(0,0),Size=UDim2.new(1,-38,0,42)},hud)
        local collapse=button(hud,"−"); collapse.Size=UDim2.fromOffset(24,24); collapse.Position=UDim2.new(1,-35,0,10)
        local separator=make("Frame",{BackgroundColor3=colors.line,BorderSizePixel=0,Position=UDim2.fromOffset(12,42),Size=UDim2.new(1,-24,0,1)},hud)
        local content=make("Frame",{BackgroundTransparency=1,Position=UDim2.fromOffset(14,52),Size=UDim2.new(1,-28,0,240)},hud)
        local fields={}
        for i,entry in ipairs({{"Mode","Mode"},{"Target","Target"},{"Skills","Skills"},{"Time","Session"}}) do
            local name=label(content,entry[2],11); name.TextColor3=colors.muted
            name.Position=UDim2.fromOffset(0,(i-1)*25); name.Size=UDim2.new(.32,0,0,22)
            local value=label(content,"—",11); value.Position=UDim2.new(.32,0,0,(i-1)*25)
            value.Size=UDim2.new(.68,0,0,22); value.TextXAlignment=Enum.TextXAlignment.Right; value.TextTruncate=Enum.TextTruncate.AtEnd
            fields[entry[1]]=value
        end
        local function bar(title,y,color)
            local text=label(content,title,11); text.Position=UDim2.fromOffset(0,y); text.Size=UDim2.new(1,0,0,20)
            local track=make("Frame",{BackgroundColor3=colors.field,BorderSizePixel=0,Position=UDim2.fromOffset(0,y+24),Size=UDim2.new(1,0,0,5)},content); round(track,5)
            local fill=make("Frame",{BackgroundColor3=color,BorderSizePixel=0,Size=UDim2.fromScale(0,1)},track); round(fill,5)
            return {text=text,fill=fill,fraction=-1}
        end
        local ownHealth=bar("Your HP",104,colors.accent)
        local enemyHealth=bar("Target HP",143,Color3.fromRGB(125,166,242))
        local pause=button(content,"Pause farm"); pause.Position=UDim2.fromOffset(0,193); pause.Size=UDim2.new(.5,-4,0,29)
        local menu=button(content,"Open menu"); menu.Position=UDim2.new(.5,4,0,193); menu.Size=UDim2.new(.5,-4,0,29)
        connect(pause.Activated,function() if settings.OnPause then settings.OnPause() end end)
        connect(menu.Activated,function() if not wantedVisible then lib:Toggle() end end)
        local dragging,dragStart,startPosition,touch
        connect(titleDrag.InputBegan,function(input)
            if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
                dragging=true; dragStart=input.Position; startPosition=hud.Position; touch=input
            end
        end)
        connect(UIS.InputChanged,function(input)
            if dragging and (input.UserInputType==Enum.UserInputType.MouseMovement or input==touch) then
                local delta=input.Position-dragStart
                hud.Position=UDim2.new(startPosition.X.Scale,startPosition.X.Offset+delta.X,startPosition.Y.Scale,startPosition.Y.Offset+delta.Y)
            end
        end)
        connect(UIS.InputEnded,function(input)
            if input.UserInputType==Enum.UserInputType.MouseButton1 or input==touch then dragging=false end
        end)
        local collapsed=false
        connect(collapse.Activated,function()
            collapsed=not collapsed; collapse.Text=collapsed and "+" or "−"
            content.Visible=not collapsed; separator.Visible=not collapsed
            animate(hud,.25,{Size=UDim2.fromOffset(284,collapsed and 44 or 306)})
        end)
        local hudTween
        local hudVisibilitySerial=0
        local result={}
        function result:SetVisible(value)
            if runtime.starting then
                hud.Visible=false; hud.GroupTransparency=1
                lib.HUDEntrance=function()
                    if lib.Unloaded then return end
                    hud.Visible=false; hudTween=nil
                    result:SetVisible(value)
                end
                return
            end
            if hud.Visible==value and ((value and hud.GroupTransparency==0) or (not value and hud.GroupTransparency==1)) then return end
            hudVisibilitySerial+=1
            local serial=hudVisibilitySerial
            if hudTween then hudTween:Cancel() end
            if value then
                if not hud.Visible or not hudTween then hudScale.Scale=hudBaseScale*.75 end
                hud.Visible=true
            end
            animate(hudScale,value and .75 or .2,{Scale=hudBaseScale*(value and 1 or .92)},value and Enum.EasingStyle.Back or Enum.EasingStyle.Quad)
            hudTween=Tween:Create(hud,TweenInfo.new(value and .5 or .2),{GroupTransparency=value and 0 or 1})
            hudTween.Completed:Once(function() if serial==hudVisibilitySerial and not value and not lib.Unloaded then hud.Visible=false end end)
            hudTween:Play()
        end
        local function updateBar(item,title,health,maxHealth)
            local fraction=maxHealth and maxHealth>0 and math.clamp(health/maxHealth,0,1) or 0
            item.text.Text=maxHealth and maxHealth>0 and (title.."  "..math.floor(fraction*100+.5).."%") or title.."  —"
            if math.abs(fraction-item.fraction)>.001 then
                item.fraction=fraction
                animate(item.fill,.25,{Size=UDim2.fromScale(fraction,1)})
            end
        end
        function result:Update(data)
            for key,field in pairs(fields) do
                local nextText=tostring(data[key] or "—")
                if field.Text~=nextText then
                    field.Text=nextText
                    if key=="Target" or key=="Mode" then field.TextTransparency=.45; animate(field,.2,{TextTransparency=0}) end
                end
            end
            pause.Text=data.Paused and "Resume farm" or "Pause farm"
            updateBar(ownHealth,"Your HP",data.Health or 0,data.MaxHealth)
            updateBar(enemyHealth,"Target HP",data.TargetHealth or 0,data.TargetMaxHealth)
        end
        result:SetVisible(settings.Visible~=false)
        return result
    end
    return lib,toggles,options
end

-- Shared upgrades. Uses live objects and supplied game events; no guessed quest remotes.
runtime.config=type(env.CloverHubConfig)=="table" and env.CloverHubConfig or {}
env.CloverHubConfig=runtime.config
for key,value in pairs({AutoM1=true,AttackInterval=.65,ManaRest=false,ManaLow=15,ManaResume=60,
    ESPMobs=false,ESPPlayers=false,ESPNPCs=false,ESPRange=1500,AutoCollect=false,CollectRange=30,
    CollectChests=true,CollectDrops=true,CollectResources=false,AutoQuestPrompt=false,
    AutoReset=false,ResetHP=20,AutoStaminaReset=true,ResetStamina=10,HUDEnabled=true,CameraDistance=14,CoffinAhead=5}) do
    if runtime.config[key]==nil then runtime.config[key]=value end
end
runtime.profiles={}
runtime.paused=false
runtime.session=os.clock()
runtime.switchSerial=0
runtime.getRoot=function(model)
    if not model or typeof(model)~="Instance" then return nil end
    if model:IsA("BasePart") then return model end
    local root=model:FindFirstChild("HumanoidRootPart")
    if root and root:IsA("BasePart") then return root end
    return model:IsA("Model") and model.PrimaryPart or nil
end
function runtime.detect()
    local map=workspace:FindFirstChild("Map")
    if (map and map:FindFirstChild("Arcanespiritrealm")) or workspace:FindFirstChild("Aetherion") then return "Arcane Dungeon" end
    local e=workspace:FindFirstChild("Entities")
    local sp=e and e:FindFirstChild("Spawns")
    if map and (map:FindFirstChild("Jungle_Island") or map:FindFirstChild("Jungle") or map:FindFirstChild("JungleMap")) then return "Jungle" end
    if sp and sp:FindFirstChild("VampireSoldierSpawn") then
        for _,mob in ipairs((e:FindFirstChild("Enemies") or e):GetChildren()) do
            if mob.Name=="Rogue Magic Knight" or mob.Name=="Mossback Mammoth" or mob.Name=="Alpha Crocodile" then return "Jungle" end
        end
        return "First Kingdom"
    end
    if map and (map:FindFirstChild("Jungle") or map:FindFirstChild("JungleMap")) then return "Jungle" end
    if sp then
        for _,part in ipairs(sp:GetChildren()) do
            if part.Name:lower():find("crocodile",1,true) or part.Name:lower():find("mammoth",1,true) then return "Jungle" end
        end
    end
    return "Explorer"
end
function runtime.mana()
    local character=player.Character
    if not character then return nil end
    local function valid(n) return type(n)=="number" and n==n and n~=math.huge and n~=-math.huge end
    local current,maximum=character:GetAttribute("Mana"),character:GetAttribute("MaxMana")
    if valid(current) and valid(maximum) and maximum>0 then return math.clamp(current/maximum*100,0,100) end
    local status=character:FindFirstChild("Status")
    local value=status and status:FindFirstChild("Mana",true)
    if not value or not (value:IsA("NumberValue") or value:IsA("IntValue")) then return nil end
    current=value.Value
    maximum=tonumber(value:GetAttribute("Max")) or tonumber(value:GetAttribute("MaxValue"))
    local sibling=value.Parent and value.Parent:FindFirstChild("MaxMana")
    if not maximum and sibling and (sibling:IsA("NumberValue") or sibling:IsA("IntValue")) then maximum=sibling.Value end
    if not valid(current) or not valid(maximum) or maximum<=0 then return nil end
    return math.clamp(current/maximum*100,0,100)
end
function runtime.stamina()
    local character=player.Character
    if not character then return nil end
    local status=character:FindFirstChild("Status")
    local value=status and status:FindFirstChild("Stamina",true)
    local current,max
    if value and (value:IsA("NumberValue") or value:IsA("IntValue")) then
        current=value.Value
        max=tonumber(value:GetAttribute("Max")) or tonumber(value:GetAttribute("MaxValue"))
        local sibling=value.Parent:FindFirstChild("MaxStamina")
        if not max and sibling and (sibling:IsA("NumberValue") or sibling:IsA("IntValue")) then max=sibling.Value end
    end
    current=current or tonumber(character:GetAttribute("Stamina")) or (status and tonumber(status:GetAttribute("Stamina")))
    max=max or tonumber(character:GetAttribute("MaxStamina")) or (status and tonumber(status:GetAttribute("MaxStamina")))
    if not current or not max or max<=0 or current~=current or max~=max then return nil end
    return math.clamp(current/max*100,0,100)
end
function runtime.allowCombat()
    if runtime.paused then return false end
    local mana=runtime.mana()
    if not runtime.config.ManaRest or not mana then runtime.resting=false; return true end
    local low=runtime.config.ManaLow
    local resume=math.max(low+1,runtime.config.ManaResume)
    if runtime.resting then runtime.resting=mana<resume else runtime.resting=mana<=low end
    return not runtime.resting
end
function runtime.allowAttack(character)
    if runtime.kaldrisDodging or not runtime.config.AutoM1 or not runtime.allowCombat() then return false end
    local status=character and character:FindFirstChild("Status")
    local casting=status and status:FindFirstChild("Casting")
    return not (casting and casting.Value)
end
function runtime.isEnemy(model)
    if not model or not model:IsA("Model") or not model:FindFirstChildOfClass("Humanoid") then return false end
    if game:GetService("Players"):GetPlayerFromCharacter(model) then return false end
    local e=workspace:FindFirstChild("Entities")
    local enemies=e and e:FindFirstChild("Enemies")
    return (enemies and model:IsDescendantOf(enemies))
        or game:GetService("CollectionService"):HasTag(model,"Enemy")
        or (model:GetAttribute("CollisionGroup")=="Enemy" and model:GetAttribute("OverheadType")==nil)
end
function runtime.blocked(model)
    if not model or typeof(model)~="Instance" then return true end
    return game:GetService("CollectionService"):HasTag(model,"Untargetable") or model:GetAttribute("FightPause")==true
end
function runtime.cast(character,enemy,tool,isRunning)
    if not runtime.allowCombat() or not isRunning() or not tool.Enabled then return false end
    local humanoid=character:FindFirstChildOfClass("Humanoid")
    local status=character:FindFirstChild("Status")
    local casting=status and status:FindFirstChild("Casting")
    local cooldown=status and status:FindFirstChild("Cooldown")
    if not humanoid or (casting and casting.Value) then return false end
    if tool.Parent~=character then humanoid:EquipTool(tool); task.wait(.18) end
    if tool.Parent~=character or player.Character~=character or not isRunning() then return false end
    local root=runtime.getRoot(character)
    local enemyRoot=runtime.getRoot(enemy)
    local camera=workspace.CurrentCamera
    if not root or not enemyRoot or not camera then return false end
    local priorType,priorCFrame,priorSubject=camera.CameraType,camera.CFrame,camera.CameraSubject
    local ownCFrame=CFrame.lookAt(root.Position-root.CFrame.LookVector*runtime.config.CameraDistance+Vector3.new(0,5,0),enemyRoot.Position)
    camera.CameraType=Enum.CameraType.Scriptable; camera.CFrame=ownCFrame
    local function restore()
        if workspace.CurrentCamera==camera and camera.CFrame==ownCFrame then
            camera.CameraType=priorType; camera.CFrame=priorCFrame
            if priorSubject and priorSubject.Parent then camera.CameraSubject=priorSubject end
        end
    end
    local function aim(click)
        local currentRoot=runtime.getRoot(enemy)
        if not currentRoot or not isRunning() then return false end
        local point=currentRoot.Position
        if tool.Name=="Shadow Magic: Night Coffin" then
            local delta=Vector3.new(point.X-root.Position.X,0,point.Z-root.Position.Z)
            if delta.Magnitude>.01 then
                point=root.Position+delta.Unit*math.min(delta.Magnitude,runtime.config.CoffinAhead)
                local params=RaycastParams.new(); params.FilterType=Enum.RaycastFilterType.Exclude
                params.FilterDescendantsInstances={character,enemy}
                local ground=workspace:Raycast(point+Vector3.new(0,6,0),Vector3.new(0,-24,0),params)
                if ground then point=ground.Position+Vector3.new(0,.1,0) end
            end
        end
        local pixel,visible=camera:WorldToScreenPoint(point)
        if not visible or game:GetService("UserInputService"):GetFocusedTextBox() then return false end
        for _,object in ipairs(player.PlayerGui:GetGuiObjectsAtPosition(pixel.X,pixel.Y)) do
            local gui=object:FindFirstAncestorOfClass("ScreenGui")
            if gui and gui.Name=="CloverDashboard" then return false end
        end
        local vim=game:GetService("VirtualInputManager")
        vim:SendMouseMoveEvent(pixel.X,pixel.Y,game)
        if click then
            local pressed=pcall(function() vim:SendMouseButtonEvent(pixel.X,pixel.Y,0,true,game,0) end)
            if pressed then
                task.wait(.08)
                pcall(function() vim:SendMouseButtonEvent(pixel.X,pixel.Y,0,false,game,0) end)
            end
            return pressed
        end
        return true
    end
    pcall(aim,false); task.wait(); pcall(function() tool:Activate() end)
    local deadline=os.clock()+1.5
    local clicked=false
    local confirmed=false
    repeat
        if (casting and casting.Value) or (cooldown and cooldown:FindFirstChild(tool.Name)) then confirmed=true; break end
        if not clicked then clicked=true; pcall(aim,true) end
        task.wait(.05)
    until not isRunning() or player.Character~=character or os.clock()>=deadline
    restore()
    if not confirmed then warn("[CloverSkill] No cast confirmed: "..tool.Name) end
    task.spawn(function()
        task.wait(.3)
        local deadline=os.clock()+30
        while isRunning() and player.Character==character and casting and casting.Value and os.clock()<deadline do task.wait(.1) end
        if isRunning() and player.Character==character and tool.Parent==character and not (casting and casting.Value) then
            pcall(function() tool:Deactivate(); humanoid:UnequipTools() end)
        end
    end)
    return confirmed
end
function runtime.stopProfiles()
    for _,name in ipairs({"StopVampireFarm","StopJungleFarm","StopArcaneDungeonFarm"}) do
        if type(env[name])=="function" then pcall(env[name]) end
    end
    if runtime.library and not runtime.library.Unloaded then runtime.library:Unload() end
end
function runtime.switch(profile)
    if not runtime.profiles[profile] then warn("[CloverHub] Unknown profile: "..tostring(profile)); return end
    runtime.switchSerial+=1
    local serial=runtime.switchSerial
    runtime.stopProfiles()
    env.VampireFarmLaunchToken={}; env.JungleFarmLaunchToken={}; env.ArcaneDungeonLaunchToken={}
    runtime.profile=profile; runtime.paused=false; runtime.resting=false; runtime.kaldrisDodging=false; runtime.telemetry=nil
    runtime.config.Profile=profile
    runtime.starting=true
    task.spawn(function()
        if serial~=runtime.switchSerial or env.CloverRuntime~=runtime then return end
        local ok,err=xpcall(runtime.profiles[profile],debug.traceback)
        if not ok and serial==runtime.switchSerial then
            warn("[CloverHub] Profile startup failed: "..tostring(err))
            runtime.stopProfiles()
            local library=runtime.newUI()
            local window=library:CreateWindow({Title="Clover Hub"})
            local status=window:AddTab("Startup error"):AddLeftGroupbox("Profile unavailable")
            status:AddLabel(tostring(err):sub(1,220),true)
            status:AddLabel("Select another area in Hub. Missing objects may not be streamed in yet.",true)
        end
        if serial==runtime.switchSerial and env.CloverRuntime==runtime then
            runtime.starting=false
            task.defer(function()
                game:GetService("RunService").RenderStepped:Wait()
                if serial==runtime.switchSerial and runtime.library and not runtime.library.Unloaded then
                    runtime.library:PlayEntrance()
                    if runtime.closeBoot then runtime.closeBoot() end
                    print("[CloverHub] Startup animation v2")
                end
            end)
        end
    end)
end
function runtime.configureUI(library,window,toggles,options)
    runtime.library=library
    runtime.sharedToggles=toggles
    local cfg=runtime.config
    local tab=window:AddTab("Hub")
    local areas=tab:AddLeftGroupbox("Area profile")
    local combat=tab:AddRightGroupbox("Combat and mana")
    areas:AddDropdown("HubProfile",{Text="Choose area",Values={"First Kingdom","Jungle","Arcane Dungeon","Explorer"},Default=runtime.profile or runtime.detect()})
    areas:AddButton("Load selected area",function() runtime.switch(options.HubProfile.Value) end)
    areas:AddButton("Detect current area",function() runtime.switch(runtime.detect()) end)
    areas:AddButton("Pause / resume all",function() runtime.paused=not runtime.paused end)
    areas:AddLabel("Only one area runs at a time. After travelling to another Roblox place, run the same loader again.",true)
    local function toggle(box,id,text,key)
        box:AddToggle(id,{Text=text,Default=cfg[key]})
        toggles[id]:OnChanged(function(value) cfg[key]=value end)
    end
    local function slider(box,id,text,key,min,max,round)
        box:AddSlider(id,{Text=text,Default=cfg[key],Min=min,Max=max,Rounding=round or 0})
        options[id]:OnChanged(function(value) cfg[key]=value end)
    end
    toggle(combat,"HubM1","Auto M1", "AutoM1")
    slider(combat,"HubM1Delay","Attack interval (seconds)","AttackInterval",.3,2,2)
    toggle(combat,"HubManaRest","Rest attacks at low mana","ManaRest")
    slider(combat,"HubManaLow","Rest below mana (%)","ManaLow",1,60)
    slider(combat,"HubManaResume","Resume above mana (%)","ManaResume",20,100)
    combat:AddLabel("Mana rest uses a live Mana value with a known maximum. Missing mana data leaves combat enabled.",true)
    local survival=window:AddTab("Survival")
    local health=survival:AddLeftGroupbox("Automatic resets")
    local survivalInfo=survival:AddRightGroupbox("Live detection")
    survivalInfo:AddLabel("Reset controls are collected here. The live reading below confirms whether detection is available.",true)
    toggle(health,"HubReset","Auto reset at low HP","AutoReset")
    slider(health,"HubResetHP","Reset HP (%)","ResetHP",1,90)
    toggle(health,"HubStaminaReset","Auto reset at low stamina","AutoStaminaReset")
    slider(health,"HubResetStamina","Reset stamina (%)","ResetStamina",1,50)
    local staminaLabel=survivalInfo:AddLabel("Stamina: waiting for current / maximum values",true)
    survivalInfo:AddLabel("Reset starts off. When enabled, waits 15 seconds after spawning and 1 second below the selected threshold.",true)
    local visuals=window:AddTab("Visuals"):AddLeftGroupbox("ESP")
    toggle(visuals,"HubESPMobs","Mob / boss ESP","ESPMobs")
    toggle(visuals,"HubESPPlayers","Player ESP","ESPPlayers")
    toggle(visuals,"HubESPNPCs","NPC ESP","ESPNPCs")
    slider(visuals,"HubESPRange","ESP distance","ESPRange",100,5000)
    local collectTab=window:AddTab("Collection")
    local collect=collectTab:AddLeftGroupbox("Nearby prompts")
    toggle(collect,"HubCollect","Collect nearby enabled prompts","AutoCollect")
    toggle(collect,"HubCollectChests","Chests","CollectChests")
    toggle(collect,"HubCollectDrops","Drops / loot","CollectDrops")
    toggle(collect,"HubCollectResources","Ores / flowers / resources","CollectResources")
    slider(collect,"HubCollectRange","Search distance","CollectRange",5,100)
    collect:AddLabel("Uses streamed prompts within their actual interaction range. No guessed inventory or pickup remotes.",true)
    local quests=collectTab:AddRightGroupbox("Quest interactions")
    quests:AddDropdown("HubQuestPrompt",{Text="Streamed quest NPC / prompt",Values={},AllowNull=true})
    toggle(quests,"HubAutoQuestPrompt","Interact with selected nearby quest NPC","AutoQuestPrompt")
    quests:AddLabel("Dialogue choices remain manual. This interacts with the selected NPC; it does not complete an entire story automatically.",true)
    local info=window:AddTab("Progression"):AddLeftGroupbox("Official Trello notes")
    info:AddLabel("Jungle access: level/prestige requirements and Orion's Mana Skin progression. Travel through the Wizard King.",true)
    info:AddLabel("Maera introductions unlock village work. Village Standing must reach 100 before seal cards can drop.",true)
    info:AddLabel("Seal Archive: cards need Seal Openers to activate their bonuses. Farming alone does not unlock the Archive.",true)
    info:AddLabel("Arcane Dungeon handles its own boss prompt and invulnerable phases. Explorer targets live Enemy-tagged models in other areas.",true)
    local settings=tab:AddLeftGroupbox("Settings")
    settings:AddLabel("Changes save automatically and restore on reload.",true)
    toggle(settings,"HubHUD","Show live HUD","HUDEnabled")
    settings:AddButton("Save settings",function()
        if type(writefile)~="function" then warn("[CloverHub] writefile unavailable"); return end
        local data={Version=2,UserId=player.UserId,Hub=cfg,World=env.VampireFarmConfig,Jungle=env.CloverJungleConfig,Arcane=env.CloverArcaneConfig,Controls=runtime.controls}
        local ok,err=pcall(function() writefile(runtime.settingsPath,game:GetService("HttpService"):JSONEncode(data)) end)
        if ok then print("[CloverHub] Saved settings") else warn(err) end
    end)
    settings:AddButton("Replay startup animation",function() library:PlayEntrance() end)
    settings:AddButton("Print diagnostics",function()
        local data=runtime.telemetry and runtime.telemetry() or {}
        print("[CloverHub] profile="..tostring(runtime.profile).." detected="..runtime.detect().." target="..tostring(data.Model and data.Model.Name or data.Target)
            .." mana="..tostring(runtime.mana()).." paused="..tostring(runtime.paused).." teleportPaused="..tostring(data.TeleportPaused)
            .." mode="..tostring(data.FarmMode).." bossEnabled="..tostring(data.BossEnabled).." M1="..tostring(runtime.config.AutoM1).." place="..game.PlaceId)
        for _,name in ipairs({"fireproximityprompt","readfile","writefile","isnetworkowner"}) do print("[CloverHub] "..name.."="..type(env[name])) end
    end)
    local annotations={}
    local folder=Instance.new("Folder"); folder.Name="CloverESP"; folder.Parent=player.PlayerGui
    library:RegisterCleanup(function() folder:Destroy() end)
    local hud=library:CreateHUD({Visible=cfg.HUDEnabled,OnPause=function() runtime.paused=not runtime.paused end})
    runtime.hud=hud
    local seenHUD=cfg.HUDEnabled
    local promptLast=setmetatable({},{__mode="k"})
    local promptLookup={}
    local resetCharacter
    local resetSent=false
    local staminaReadyAt=os.clock()+15
    local staminaLowSince
    task.spawn(function()
        while not library.Unloaded and env.CloverRuntime==runtime and runtime.library==library do
            local data=runtime.telemetry and runtime.telemetry() or {}
            local character=player.Character
            local humanoid=character and character:FindFirstChildOfClass("Humanoid")
            local target=data.Model
            local targetHumanoid=target and target:FindFirstChildOfClass("Humanoid")
            local elapsed=math.floor(os.clock()-runtime.session)
            local status=character and character:FindFirstChild("Status")
            local casting=status and status:FindFirstChild("Casting")
            hud:Update({Mode=runtime.paused and "Paused" or runtime.resting and "Mana rest" or runtime.profile,
                Target=target and target.Name or data.Target or "Waiting…",Skills=casting and casting.Value and "Casting" or data.Skills or "Idle",
                Time=string.format("%02d:%02d:%02d",math.floor(elapsed/3600),math.floor(elapsed/60)%60,elapsed%60),
                Health=humanoid and humanoid.Health or 0,MaxHealth=humanoid and humanoid.MaxHealth,
                TargetHealth=targetHumanoid and targetHumanoid.Health or 0,TargetMaxHealth=targetHumanoid and targetHumanoid.MaxHealth,Paused=runtime.paused})
            if seenHUD~=cfg.HUDEnabled then seenHUD=cfg.HUDEnabled; hud:SetVisible(seenHUD) end
            if character~=resetCharacter then
                resetCharacter=character; resetSent=false; staminaReadyAt=os.clock()+15; staminaLowSince=nil
            end
            local stamina=runtime.stamina()
            staminaLabel:SetText(stamina and string.format("Stamina: %.0f%%",stamina) or "Stamina: current / maximum unavailable")
            if cfg.AutoStaminaReset and not runtime.paused and stamina and stamina<=cfg.ResetStamina
                and os.clock()>=staminaReadyAt and humanoid and humanoid.Health>0 then
                staminaLowSince=staminaLowSince or os.clock()
            else staminaLowSince=nil end
            if staminaLowSince and os.clock()-staminaLowSince>=1 and not resetSent then
                local ok,err=pcall(function() humanoid.Health=0 end)
                if ok then resetSent=true; print("[CloverHub] Low stamina reset requested")
                else staminaLowSince=nil; warn("[CloverHub] Stamina reset failed: "..tostring(err)) end
            end
            if cfg.AutoReset and not resetSent and humanoid and humanoid.MaxHealth>0 and humanoid.Health>0
                and humanoid.Health/humanoid.MaxHealth*100<=cfg.ResetHP then
                resetSent=true; pcall(function() humanoid.Health=0 end)
            end
            task.wait(.25)
        end
    end)
    task.spawn(function()
        while not library.Unloaded and env.CloverRuntime==runtime and runtime.library==library do
            local root=runtime.getRoot(player.Character)
            local wanted={}
            if root and (cfg.ESPMobs or cfg.ESPPlayers or cfg.ESPNPCs) then
                local candidates={}
                for _,p in ipairs(game:GetService("Players"):GetPlayers()) do if p~=player and p.Character then candidates[p.Character]="Player" end end
                local entities=workspace:FindFirstChild("Entities")
                if entities then
                    for _,hum in ipairs(entities:GetDescendants()) do if hum:IsA("Humanoid") then
                        local model=hum.Parent
                        if model and model:IsA("Model") and model~=player.Character then candidates[model]=runtime.isEnemy(model) and "Mob" or "NPC" end
                    end end
                end
                for _,model in ipairs(game:GetService("CollectionService"):GetTagged("Enemy")) do if model:IsA("Model") then candidates[model]="Mob" end end
                local sorted={}
                for model,kind in pairs(candidates) do
                    local modelRoot=runtime.getRoot(model)
                    local enabled=kind=="Mob" and cfg.ESPMobs or kind=="Player" and cfg.ESPPlayers or kind=="NPC" and cfg.ESPNPCs
                    if enabled and modelRoot then
                        local distance=(modelRoot.Position-root.Position).Magnitude
                        if distance<=cfg.ESPRange then table.insert(sorted,{Model=model,Root=modelRoot,Kind=kind,Distance=distance}) end
                    end
                end
                table.sort(sorted,function(a,b) return a.Distance<b.Distance end)
                for i=1,math.min(#sorted,31) do
                    local item=sorted[i]; wanted[item.Model]=true
                    local record=annotations[item.Model]
                    if not record then
                        local color=item.Kind=="Player" and Color3.fromRGB(125,166,242) or item.Kind=="NPC" and Color3.fromRGB(240,190,95) or Color3.fromRGB(190,219,65)
                        local highlight=Instance.new("Highlight"); highlight.Adornee=item.Model; highlight.FillTransparency=.88; highlight.OutlineColor=color; highlight.Parent=folder
                        local gui=Instance.new("BillboardGui"); gui.Adornee=item.Root; gui.Size=UDim2.fromOffset(220,44); gui.StudsOffset=Vector3.new(0,3,0); gui.AlwaysOnTop=true; gui.Parent=folder
                        local text=Instance.new("TextLabel"); text.BackgroundTransparency=1; text.Size=UDim2.fromScale(1,1); text.Font=Enum.Font.Gotham; text.TextSize=11; text.TextColor3=color; text.TextStrokeTransparency=.3; text.Parent=gui
                        record={Highlight=highlight,Gui=gui,Text=text}; annotations[item.Model]=record
                    end
                    record.Gui.Adornee=item.Root
                    local hum=item.Model:FindFirstChildOfClass("Humanoid")
                    record.Text.Text=item.Model.Name.."  "..math.floor(item.Distance).." studs"..(hum and ("\nHP "..math.floor(hum.Health).." / "..math.floor(hum.MaxHealth)) or "")
                end
            end
            for model,record in pairs(annotations) do if not wanted[model] then record.Highlight:Destroy(); record.Gui:Destroy(); annotations[model]=nil end end
            local questNames={}; promptLookup={}
            if root then
                local entities=workspace:FindFirstChild("Entities")
                for _,object in ipairs(entities and entities:GetDescendants() or {}) do
                    if object:IsA("ProximityPrompt") and object.Enabled then
                        local part=object.Parent
                        if part and part:IsA("Attachment") then part=part.Parent end
                        if not (part and part:IsA("BasePart")) then part=object:FindFirstAncestorWhichIsA("Model"); part=runtime.getRoot(part) end
                        if part then
                            local descriptor=object:GetFullName():lower().." "..object.ObjectText:lower().." "..object.ActionText:lower()
                            local distance=(root.Position-part.Position).Magnitude
                            local isQuest=descriptor:find("quest",1,true)~=nil
                            if isQuest then local label=object.ObjectText~="" and object.ObjectText or part.Parent.Name; label=label.." | "..object:GetFullName(); promptLookup[label]=object; table.insert(questNames,label) end
                            local kind=descriptor:find("chest",1,true) and "Chest" or (descriptor:find("drop",1,true) or descriptor:find("loot",1,true)) and "Drop"
                                or (descriptor:find("ore",1,true) or descriptor:find("flower",1,true) or descriptor:find("herb",1,true)) and "Resource"
                            local enabled=kind=="Chest" and cfg.CollectChests or kind=="Drop" and cfg.CollectDrops or kind=="Resource" and cfg.CollectResources
                            local selectedQuest=cfg.AutoQuestPrompt and options.HubQuestPrompt.Value and promptLookup[options.HubQuestPrompt.Value]==object
                            local owner=object:GetAttribute("OwnerUserId")
                            local available=object:GetAttribute("Locked")~=true and object:GetAttribute("Claimed")~=true and (not owner or owner==player.UserId)
                            if not runtime.paused and available and not runtime.blocked((runtime.telemetry and runtime.telemetry().Model) or player.Character or part)
                                and ((cfg.AutoCollect and enabled and distance<=cfg.CollectRange) or selectedQuest)
                                and distance<=object.MaxActivationDistance and os.clock()-(promptLast[object] or -math.huge)>= (selectedQuest and 12 or 5)
                                and type(fireproximityprompt)=="function" then
                                promptLast[object]=os.clock(); pcall(fireproximityprompt,object)
                            end
                        end
                    end
                end
            end
            table.sort(questNames)
            local signature=table.concat(questNames,"\n")
            if signature~=options.HubQuestPrompt._signature then options.HubQuestPrompt._signature=signature; options.HubQuestPrompt:SetValues(questNames) end
            task.wait(.8)
        end
    end)
end
function runtime.explorer()
    local library,toggles,options=runtime.newUI()
    local window=library:CreateWindow({Title="Clover Explorer"})
    local box=window:AddTab("Explorer"):AddLeftGroupbox("Streamed enemies")
    local enabled=false
    box:AddToggle("ExplorerEnabled",{Text="Farm nearest streamed enemy",Default=false})
    toggles.ExplorerEnabled:OnChanged(function(v) enabled=v end)
    box:AddLabel("For areas without a dedicated route. No queueing, boss summoning, or automatic quest completion is assumed.",true)
    local target
    runtime.telemetry=function() return {Model=target,Skills="Use area profile for skills"} end
    task.spawn(function()
        local lastAttack=-math.huge
        while not library.Unloaded and runtime.library==library do
            local root=runtime.getRoot(player.Character)
            local humanoid=player.Character and player.Character:FindFirstChildOfClass("Humanoid")
            if enabled and runtime.allowCombat() and root and humanoid and humanoid.Health>0 then
                local best,distance
                local candidates={}
                local entities=workspace:FindFirstChild("Entities")
                local enemies=entities and entities:FindFirstChild("Enemies")
                for _,model in ipairs(enemies and enemies:GetChildren() or {}) do candidates[model]=true end
                for _,model in ipairs(game:GetService("CollectionService"):GetTagged("Enemy")) do candidates[model]=true end
                for model in pairs(candidates) do
                    local hum=model:IsA("Model") and model:FindFirstChildOfClass("Humanoid")
                    local mobRoot=runtime.getRoot(model)
                    if hum and hum.Health>0 and mobRoot and not runtime.blocked(model) then
                        local d=(root.Position-mobRoot.Position).Magnitude
                        if not distance or d<distance then best=model; distance=d end
                    end
                end
                target=best
                if target then
                    local mobRoot=runtime.getRoot(target)
                    local position=(mobRoot.CFrame*CFrame.new(0,0,5)).Position
                    root.CFrame=CFrame.lookAt(position,mobRoot.Position); root.AssemblyLinearVelocity=Vector3.zero
                    if runtime.allowAttack(player.Character) and os.clock()-lastAttack>=runtime.config.AttackInterval then
                        local package=game.ReplicatedStorage:FindFirstChild("ReplicatedPackage")
                        local action=package and package:FindFirstChild("Remotes") and package.Remotes:FindFirstChild("action")
                        if action and action:IsA("RemoteEvent") then
                            lastAttack=os.clock()
                            local ok,err=pcall(function() action:FireServer("M1",{password="Spirit"}) end)
                            if not ok then warn("[CloverExplorer] M1 failed: "..tostring(err)) end
                        end
                    end
                end
            else target=nil end
            task.wait(.15)
        end
    end)
end

function runtime.saveSettings()
    if type(writefile)~="function" then
        if not runtime.saveUnavailable then warn("[CloverHub] Automatic saving requires executor writefile support"); runtime.saveUnavailable=true end
        return false
    end
    local data={Version=2,UserId=player.UserId,Hub=runtime.config,World=env.VampireFarmConfig,Jungle=env.CloverJungleConfig,Arcane=env.CloverArcaneConfig,Controls=runtime.controls}
    local ok,err=pcall(function() writefile(runtime.settingsPath,game:GetService("HttpService"):JSONEncode(data)) end)
    if not ok then warn("[CloverHub] Settings save failed: "..tostring(err)) end
    return ok
end
function runtime.requestSave()
    runtime.saveSerial+=1
    local serial=runtime.saveSerial
    task.delay(.4,function()
        if serial==runtime.saveSerial and env.CloverRuntime==runtime then runtime.saveSettings() end
    end)
end
runtime.newUI=function() return createCloverLibrary() end
runtime.profiles["First Kingdom"]=function()
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
-- Input handling belongs to the shared UI.
local player = Players.LocalPlayer
local entities = workspace:WaitForChild("Entities",15); assert(entities,"Entities not streamed")
local enemies = entities:WaitForChild("Enemies",15); assert(enemies,"Enemies not streamed")
local spawns = entities:WaitForChild("Spawns",15); assert(spawns,"Spawns not streamed; select another area in Hub")
local spawn = spawns:FindFirstChild("VampireSoldierSpawn")
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

-- Attack interval belongs to the shared Hub controls.
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
local kraken = {
    Name = "Desert Kraken",
    Candidates = setmetatable({}, {__mode = "k"}),
    SafeUntil = 0,
    LastAnchor = nil,
    Waiting = false,
}
local SIMULATION_RADIUS = 3000
local RADIUS_INTERVAL = 0.05
local oreFarm = {
    Folders = {"GrasslandsOreCorrect", "TundraOre", "Desert"},
    Names = {"Stone", "Copper", "Iron", "Manastone", "Dragonite"},
    NameSet = {},
    Current = nil, Phase = nil, ReadyAt = 0, MineUntil = 0,
    NextNodeAt = 0, LastWarningAt = -math.huge,
    Attempted = setmetatable({}, {__mode = "k"}),
}
for _, name in ipairs(oreFarm.Names) do oreFarm.NameSet[name] = true end
table.sort(oreFarm.Names)

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
    if APEX_NAMES[entry.name] or entry.name == golem.Name
        or entry.name == kraken.Name then
        -- Apex, golem, and Kraken have separate farm controls.
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
if not BOSS_NAMES.Kaldris then
    BOSS_NAMES.Kaldris = true
    table.insert(BOSS_NAME_SEED, "Kaldris")
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

for name in pairs(MOB_SPAWN_NAMES) do
    if not MOB_NAMES[name] and not BOSS_NAMES[name] then
        MOB_NAMES[name]=true; table.insert(MOB_NAME_SEED,name)
    end
end
table.sort(MOB_NAME_SEED)
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
if type(env.VampireFarmConfig.OwnedMobPinEnabled) ~= "boolean" then
    env.VampireFarmConfig.OwnedMobPinEnabled = true
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
if type(env.VampireFarmConfig.AutoEquipWeaponEnabled) ~= "boolean" then
    env.VampireFarmConfig.AutoEquipWeaponEnabled = true
end
if type(env.VampireFarmConfig.AutoSkillManaGateEnabled) ~= "boolean" then
    env.VampireFarmConfig.AutoSkillManaGateEnabled = true
end
if type(env.VampireFarmConfig.AutoSkillManaThresholdPercent) ~= "number"
    or env.VampireFarmConfig.AutoSkillManaThresholdPercent ~= env.VampireFarmConfig.AutoSkillManaThresholdPercent
    or env.VampireFarmConfig.AutoSkillManaThresholdPercent == math.huge
    or env.VampireFarmConfig.AutoSkillManaThresholdPercent == -math.huge then
    env.VampireFarmConfig.AutoSkillManaThresholdPercent = 30
end
env.VampireFarmConfig.AutoSkillManaThresholdPercent = math.clamp(
    env.VampireFarmConfig.AutoSkillManaThresholdPercent, 0, 100)
if type(env.VampireFarmConfig.AutoSkillResetAtLowMana) ~= "boolean" then
    env.VampireFarmConfig.AutoSkillResetAtLowMana = true
end
if type(env.VampireFarmConfig.AutoSkillResetManaThreshold) ~= "number"
    or env.VampireFarmConfig.AutoSkillResetManaThreshold ~= env.VampireFarmConfig.AutoSkillResetManaThreshold
    or env.VampireFarmConfig.AutoSkillResetManaThreshold == math.huge
    or env.VampireFarmConfig.AutoSkillResetManaThreshold == -math.huge then
    env.VampireFarmConfig.AutoSkillResetManaThreshold = 0
end
env.VampireFarmConfig.AutoSkillResetManaThreshold = math.max(0,
    math.floor(env.VampireFarmConfig.AutoSkillResetManaThreshold + 0.5))
env.VampireFarmConfig.AutoSkillResetManaThresholdPercent = nil
if type(env.VampireFarmConfig.SilentAimEnabled) ~= "boolean" then
    env.VampireFarmConfig.SilentAimEnabled = false
end
if type(env.VampireFarmConfig.SelectedSkills) ~= "table" then
    env.VampireFarmConfig.SelectedSkills = {}
end
env.VampireFarmConfig.SelectedSkills["Grimoire:World Tree Magic: Heartwood Lance"] = nil
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
if type(env.VampireFarmConfig.KrakenFarmEnabled) ~= "boolean" then
    env.VampireFarmConfig.KrakenFarmEnabled = true
end
if type(env.VampireFarmConfig.KrakenDiveProtectionEnabled) ~= "boolean" then
    env.VampireFarmConfig.KrakenDiveProtectionEnabled = true
end
do
local function boundedKrakenSetting(value, default, minimum, maximum)
    local number = tonumber(value)
    if not number or number ~= number or number == math.huge
        or number == -math.huge then
        number = default
    end
    return math.clamp(number, minimum, maximum)
end
env.VampireFarmConfig.KrakenHoverDistance = boundedKrakenSetting(
    env.VampireFarmConfig.KrakenHoverDistance, 320, 80, 800)
env.VampireFarmConfig.KrakenHoverHeight = boundedKrakenSetting(
    env.VampireFarmConfig.KrakenHoverHeight, 400, 100, 1000)
env.VampireFarmConfig.KrakenSafetySeconds = boundedKrakenSetting(
    env.VampireFarmConfig.KrakenSafetySeconds, 3, 1, 8)
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
if type(env.VampireFarmConfig.SelectedOres) ~= "table" then
    env.VampireFarmConfig.SelectedOres = {}
    for _, name in ipairs(oreFarm.Names) do
        env.VampireFarmConfig.SelectedOres[name] = true
    end
end
for name in pairs(env.VampireFarmConfig.SelectedOres) do
    if not oreFarm.NameSet[name] then
        env.VampireFarmConfig.SelectedOres[name] = nil
    end
end
function oreFarm.boundedTime(value, default, maximum)
    local number = tonumber(value)
    if not number or number ~= number or number == math.huge
        or number == -math.huge then
        number = default
    end
    return math.clamp(math.floor(number * 10 + 0.5) / 10, 0, maximum)
end
env.VampireFarmConfig.OreMineSeconds = oreFarm.boundedTime(
    env.VampireFarmConfig.OreMineSeconds, 2, 60)
env.VampireFarmConfig.OreDelaySeconds = oreFarm.boundedTime(
    env.VampireFarmConfig.OreDelaySeconds, 1, 5)
if env.VampireFarmConfig.FarmMode ~= "Vampire"
    and env.VampireFarmConfig.FarmMode ~= "Mob"
    and env.VampireFarmConfig.FarmMode ~= "Ore"
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
    env.VampireFarmConfig.InstantKillEnabled = true
end
if env.VampireFarmConfig.InstantKillMethod ~= "Dead state"
    and env.VampireFarmConfig.InstantKillMethod ~= "Local health" then
    env.VampireFarmConfig.InstantKillMethod = "Dead state"
end
env.VampireFarmConfig.OwnDamageThresholdPercent = nil
env.VampireFarmOwnDamageReady = nil
if type(env.VampireFarmConfig.PartyDamageGateEnabled) ~= "boolean" then
    env.VampireFarmConfig.PartyDamageGateEnabled = false
end
if type(env.VampireFarmConfig.AutoInvitePlayersEnabled) ~= "boolean" then
    env.VampireFarmConfig.AutoInvitePlayersEnabled = false
end
if type(env.VampireFarmConfig.AutoAcceptPartyInvitesEnabled) ~= "boolean" then
    env.VampireFarmConfig.AutoAcceptPartyInvitesEnabled = false
end
do
local threshold = tonumber(env.VampireFarmConfig.PartyDamageThresholdPercent)
if not threshold or threshold ~= threshold
    or threshold == math.huge or threshold == -math.huge then
    threshold = 10
end
env.VampireFarmConfig.PartyDamageThresholdPercent = math.clamp(
    math.floor(threshold + 0.5), 0, 100)
local idleSeconds = tonumber(env.VampireFarmConfig.PartyDamageIdleSeconds)
if not idleSeconds or idleSeconds ~= idleSeconds
    or idleSeconds == math.huge or idleSeconds == -math.huge then
    idleSeconds = 12
end
env.VampireFarmConfig.PartyDamageIdleSeconds = math.clamp(
    math.floor(idleSeconds + 0.5), 3, 30)
local inviteInterval = tonumber(env.VampireFarmConfig.PartyInviteIntervalSeconds)
if not inviteInterval or inviteInterval ~= inviteInterval
    or inviteInterval == math.huge or inviteInterval == -math.huge then
    inviteInterval = 15
end
env.VampireFarmConfig.PartyInviteIntervalSeconds = math.clamp(
    math.floor(inviteInterval + 0.5), 5, 60)
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

local Library, Toggles, Options = runtime.newUI()

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
local kaldrisCycle={Phase='Altar'}
local activeMode = env.VampireFarmConfig.FarmMode
local target
local targetSource
local bossTarget
local apexTarget
local radiusConnection
local attachConnection
env.VampireFarmPinState = {}
local breakerHeartbeatConnection
local breakerRenderConnection
local breakerSimulationConnection
local breakerRoot, breakerSavedVelocity
local antiAfkConnection
local bossAddedConnection
local chestAddedConnection
local cameraBinding = "VampireFarmCamera"
local previousCameraType, previousCameraSubject

local silentAim = {Target = nil, Until = 0, ManaResetCharacter = nil}
local kaldrisDodgeUntil=0
env.VampireFarmPartyGate = {
    -- Party damage waiting is temporarily disabled; KillThreshold remains in use.
}
env.VampireFarmPartyAutomation = {
    LastInviteAt = setmetatable({}, {__mode = "k"}),
    LastAnyInviteAt = -math.huge,
}

function env.VampireFarmPinState:Clear()
    self.Mob, self.Root, self.CFrame = nil, nil, nil
end

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
    runtime.saveSettings()
    running = false
    runtime.kaldrisDodging=false
    if kaldrisCycle.disconnectBoss then kaldrisCycle.disconnectBoss() end
    RunService:UnbindFromRenderStep(cameraBinding)
    restoreCamera()
    if radiusConnection then radiusConnection:Disconnect() end
    if attachConnection then attachConnection:Disconnect() end
    env.VampireFarmPinState:Clear()
    if breakerHeartbeatConnection then breakerHeartbeatConnection:Disconnect() end
    if breakerRenderConnection then breakerRenderConnection:Disconnect() end
    if breakerSimulationConnection then breakerSimulationConnection:Disconnect() end
    restoreBreakerVelocity()
    if antiAfkConnection then antiAfkConnection:Disconnect() end
    if bossAddedConnection then bossAddedConnection:Disconnect() end
    if chestAddedConnection then chestAddedConnection:Disconnect() end
    if silentAim.ManaChangedConnection then silentAim.ManaChangedConnection:Disconnect() end
    if silentAim.LoadedChangedConnection then silentAim.LoadedChangedConnection:Disconnect() end
    if silentAim.CharacterAddedConnection then silentAim.CharacterAddedConnection:Disconnect() end
    if env.VampireFarmPartyAutomation.PlayerAddedConnection then
        env.VampireFarmPartyAutomation.PlayerAddedConnection:Disconnect()
    end
    if env.VampireFarmPartyAutomation.PlayerRemovingConnection then
        env.VampireFarmPartyAutomation.PlayerRemovingConnection:Disconnect()
    end
    silentAim.Target = nil
    silentAim.Until = 0
    if silentAim.Remote and silentAim.RemoteWrapper then
        pcall(function()
            if type(getcallbackvalue) == "function"
                and getcallbackvalue(silentAim.Remote, "OnClientInvoke")
                    == silentAim.RemoteWrapper then
                silentAim.Remote.OnClientInvoke = silentAim.OriginalRemote
            end
        end)
    end
    if silentAim.GameGlobal and silentAim.GlobalWrapper
        and silentAim.GameGlobal.GetMouse == silentAim.GlobalWrapper then
        silentAim.GameGlobal.GetMouse = silentAim.OriginalGlobal
    end
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

function golem.enableCombat()
    teleportPaused=false; runtime.paused=false
    runtime.config.AutoM1=true
    if runtime.sharedToggles and runtime.sharedToggles.HubM1 then runtime.sharedToggles.HubM1:SetValue(true) end
    env.VampireFarmConfig.AutoAttachEnabled=true
    if Toggles.AutoAttachEnabled then Toggles.AutoAttachEnabled:SetValue(true) end
end
local Window = Library:CreateWindow({
    Title = "Clover",
    Center = true,
    AutoShow = true,
    Size = UDim2.fromOffset(560, 520),
    MenuFadeTime = 0.2,
})
local farmTab = Window:AddTab("Overview")
local mobTab = Window:AddTab("Mobs")
oreFarm.Tab = Window:AddTab("Ore Farm")
local bossTab = Window:AddTab("Bosses")
kraken.Tab = Window:AddTab("Kraken Farm")
local teleportTab = Window:AddTab("Teleport")
local lootTab = Window:AddTab("Loot")
env.VampireFarmPartyAutomation.Tab = Window:AddTab("Party")
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
local kaldrisTab=Window:AddTab("Kaldris")
local kaldrisBox=kaldrisTab:AddLeftGroupbox("Ashen Crucible")
local kaldrisInfo=kaldrisTab:AddRightGroupbox("Cinder Sigils")
kaldrisInfo:AddLabel("Starts OFF. Enable the repeat cycle near the streamed Ember Altar. It summons once, fights Kaldris, resets after defeat and returns to the altar. Other mob farms stay off.",true)
kaldrisInfo:AddLabel("Cinder Sigils: your item description lists fire mages and charred netherwings. Summoning consumes a sigil at the Ember Altar.",true)
kaldrisBox:AddToggle("KaldrisCombat",{Text="Fight spawned Kaldris only",Default=false})
Toggles.KaldrisCombat:OnChanged(function(enabled)
    -- OnChanged runs immediately while later controls are still being constructed.
    if not Options.BossTargets or not Toggles.BossFarmEnabled then return end
    if enabled then teleportPaused=false; runtime.paused=false end
    runtime.config.AutoCollect=false; runtime.config.AutoQuestPrompt=false
    if runtime.sharedToggles then
        if runtime.sharedToggles.HubCollect then runtime.sharedToggles.HubCollect:SetValue(false) end
        if runtime.sharedToggles.HubAutoQuestPrompt then runtime.sharedToggles.HubAutoQuestPrompt:SetValue(false) end
    end
    if Toggles.VampireFarmEnabled then Toggles.VampireFarmEnabled:SetValue(false) end
    if Toggles.MobFarmEnabled then Toggles.MobFarmEnabled:SetValue(false) end
    for _,id in ipairs({"ApexFarmEnabled","PrimeApexFarmEnabled","GolemFarmEnabled","AutoChestLootEnabled","OreFarmEnabled","KrakenFarmEnabled"}) do
        if Toggles[id] then Toggles[id]:SetValue(false) end
    end
    Options.BossTargets:SetValue(enabled and {Kaldris=true} or {})
    Toggles.BossFarmEnabled:SetValue(enabled)
    if runtime.library then
        local shared=runtime.sharedToggles
        if shared and shared.HubM1 then shared.HubM1:SetValue(enabled) end
    end
    runtime.config.AutoM1=enabled
    env.VampireFarmConfig.AutoAttachEnabled=enabled
    if Toggles.AutoAttachEnabled then Toggles.AutoAttachEnabled:SetValue(enabled) end
end)
kaldrisBox:AddButton("Interact with nearby Ember Altar",function()
    local map=workspace:FindFirstChild("Map")
    local altar=map and map:FindFirstChild("EmberAltar")
    local part=altar and altar:FindFirstChild("InteractionPart")
    local prompt=part and part:FindFirstChild("Interaction")
    local root=runtime.getRoot(player.Character)
    if not prompt or not prompt:IsA("ProximityPrompt") or not part:IsA("BasePart") or not root then
        warn("[Kaldris] Ember Altar not streamed nearby"); return
    end
    if not prompt.Enabled or (root.Position-part.Position).Magnitude>prompt.MaxActivationDistance then
        warn("[Kaldris] Walk within the altar's interaction range first"); return
    end
    if type(fireproximityprompt)~="function" then warn("[Kaldris] Prompt API unavailable"); return end
    local ok,err=pcall(fireproximityprompt,prompt)
    if not ok then warn("[Kaldris] Altar interaction failed: "..tostring(err)) end
end)
kaldrisBox:AddToggle("KaldrisAutoCycle",{Text="Auto summon / fight / reset / repeat",Default=false})
kaldrisBox:AddToggle("KaldrisSpinPrestige",{Text="At level 200: prestige for spins and repeat",Default=true})
kaldrisCycle.Label=kaldrisBox:AddLabel("Cycle off",true)
Toggles.KaldrisAutoCycle:OnChanged(function(enabled)
    if not kaldrisCycle.setCombat then return end
    kaldrisCycle.disconnectBoss()
    kaldrisCycle.Phase="Altar"; kaldrisCycle.ResetCharacter=nil; kaldrisCycle.AfterReset=nil
    kaldrisCycle.AltarClickedButton=nil
    kaldrisCycle.PrestigeLevel=nil; kaldrisCycle.DialogueStage=nil; kaldrisCycle.Recovering=nil
    if enabled then
        teleportPaused=false; runtime.paused=false
        -- Enter the exclusive boss route first to disable every competing farm.
        kaldrisCycle.setCombat(true); kaldrisCycle.setCombat(false)
        kaldrisCycle.prompt("Altar"); kaldrisCycle.prompt("Wizard")
        if Toggles.VampireAutoSkill then Toggles.VampireAutoSkill:SetValue(true) end
        kaldrisCycle.ConfigureAt=nil
        if kaldrisCycle.configureCombat then kaldrisCycle.configureCombat() end
        runtime.config.AutoReset=false; runtime.config.AutoStaminaReset=false
        if runtime.sharedToggles then
            for _,id in ipairs({"HubReset","HubStaminaReset"}) do
                if runtime.sharedToggles[id] then runtime.sharedToggles[id]:SetValue(false) end
            end
        end
        env.VampireFarmConfig.AutoResetEnabled=false
        if Toggles.CloverAutoReset then Toggles.CloverAutoReset:SetValue(false) end
        if Toggles.VampireAutoSkillResetAtLowMana then Toggles.VampireAutoSkillResetAtLowMana:SetValue(false) end
        kaldrisCycle.status("Cycle enabled; checking level and altar")
    else
        kaldrisCycle.setCombat(false)
        if Toggles.VampireAutoSkill then Toggles.VampireAutoSkill:SetValue(false) end
        kaldrisCycle.status("Cycle off")
    end
end)
kaldrisBox:AddButton("Print cycle diagnostics",function()
    if not kaldrisCycle.level then return end
    print("[KaldrisCycle] phase="..tostring(kaldrisCycle.Phase).." level="..tostring(kaldrisCycle.level()))
    for _,kind in ipairs({"Altar","Wizard"}) do
        local prompt=kaldrisCycle.prompt(kind)
        print("[KaldrisCycle] "..kind.."="..(prompt and prompt:GetFullName() or "not streamed / ambiguous").." cached="..tostring(kaldrisCycle[kind.."Position"]))
    end
    local gui=player:FindFirstChildOfClass("PlayerGui")
    local dialogue=gui and gui:FindFirstChild("Dialogue")
    if dialogue then
        for _,item in ipairs(dialogue:GetDescendants()) do
            if (item:IsA("TextLabel") or item:IsA("TextButton")) and kaldrisCycle.visible(item) then
                print("[KaldrisDialogue] "..item:GetFullName().." | "..item.Text)
            end
        end
    end
end)
kaldrisBox:AddToggle("KaldrisAirDodge",{Text="Aerial dodge on visible casting signal",Default=false})
Toggles.KaldrisAirDodge:OnChanged(function(value) env.VampireFarmConfig.KaldrisAirDodgeEnabled=value end)
kaldrisBox:AddSlider("KaldrisDodgeHeight",{Text="Dodge height (studs)",Default=30,Min=10,Max=70,Rounding=0})
Options.KaldrisDodgeHeight:OnChanged(function(value) env.VampireFarmConfig.KaldrisDodgeHeight=value end)
kaldrisInfo:AddLabel("Aerial dodge requires Kaldris to expose a Casting BoolValue or boolean Casting attribute. It cannot predict unreported attacks or guarantee immunity.",true)
kaldrisInfo:AddLabel("Repeat cycle spends one sigil per summon. At level 200 it resets, visits the streamed Wizard King and selects spin prestige. A detected level reset resumes the altar route. Missing routes, unknown dialogue or unconfirmed summons pause the cycle.",true)
local uiTab = Window:AddTab("Settings")
local combatBox = farmTab:AddLeftGroupbox("Combat")
local statBox = farmTab:AddRightGroupbox("Stats")
local vampireBox = farmTab:AddLeftGroupbox("Vampire Farm")
local mobBox = mobTab:AddLeftGroupbox("Mob Farm")
local mobSettingsBox = mobTab:AddRightGroupbox("Priority and Spawn")
oreFarm.Box = oreFarm.Tab:AddLeftGroupbox("Ore Farm")
oreFarm.TimingBox = oreFarm.Tab:AddRightGroupbox("Timing")
local bossBox = bossTab:AddLeftGroupbox("Boss Farm")
local apexBox = bossTab:AddRightGroupbox("Apex Farm")
local primeApexBox = bossTab:AddRightGroupbox("Prime Apex Farm")
local placeTeleportBox = teleportTab:AddLeftGroupbox("Places")
local npcTeleportBox = teleportTab:AddRightGroupbox("NPCs")
local mobTeleportBox = teleportTab:AddRightGroupbox("Mobs")
local teleportControlBox = teleportTab:AddLeftGroupbox("Farm Control")
local lootBox = lootTab:AddLeftGroupbox("Auto Chest Loot")
env.VampireFarmPartyAutomation.Box = env.VampireFarmPartyAutomation.Tab:AddLeftGroupbox("Party automation")
env.VampireFarmPartyAutomation.Tab:AddRightGroupbox("Availability"):AddLabel("Party invites are available when enabled. Automatic acceptance and party damage waiting are disabled in the supplied script.",true)
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

do
    local hudBox=uiTab:AddRightGroupbox("Live Status HUD")
    if type(env.VampireFarmConfig.HUDEnabled)~="boolean" then env.VampireFarmConfig.HUDEnabled=true end
    hudBox:AddToggle("CloverHUDEnabled",{Text="Show status HUD",Default=env.VampireFarmConfig.HUDEnabled})
    Toggles.CloverHUDEnabled:OnChanged(function(value)
        env.VampireFarmConfig.HUDEnabled=value; runtime.config.HUDEnabled=value
        if golem.HUD then golem.HUD:SetVisible(value) end
    end)
    hudBox:AddLabel("The HUD stays visible when the main menu is hidden. Drag its title to move it; use − to collapse it.",true)
end

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

do
local krakenBox = kraken.Tab:AddLeftGroupbox("Desert Kraken")
local krakenSafetyBox = kraken.Tab:AddRightGroupbox("Sand Dive Protection")
krakenBox:AddToggle("KrakenFarmEnabled", {
    Text = "Kraken Farm",
    Default = env.VampireFarmConfig.KrakenFarmEnabled,
    Tooltip = "Prioritizes a live Desert Kraken, then resumes the previous farm.",
})
Toggles.KrakenFarmEnabled:OnChanged(function(enabled)
    if enabled then golem.enableCombat() end
    env.VampireFarmConfig.KrakenFarmEnabled = enabled
    if not enabled then
        kraken.Target = nil
        kraken.SafeUntil = 0
        kraken.Waiting = false
        if targetSource == "Kraken" then
            target = nil
            targetSource = nil
        end
    end
end)
krakenBox:AddLabel("Prime Apex > Apex > Kraken > Golem > bosses > current farm.", true)
krakenBox:AddLabel("Targets a live Kraken; its spawn is controlled by the game.", true)

krakenSafetyBox:AddToggle("KrakenDiveProtection", {
    Text = "Avoid Sand Dive",
    Default = env.VampireFarmConfig.KrakenDiveProtectionEnabled,
})
Toggles.KrakenDiveProtection:OnChanged(function(enabled)
    env.VampireFarmConfig.KrakenDiveProtectionEnabled = enabled
    if not enabled then
        kraken.SafeUntil = 0
        kraken.Waiting = false
    end
end)
krakenSafetyBox:AddSlider("KrakenHoverDistance", {
    Text = "Wait distance", Default = env.VampireFarmConfig.KrakenHoverDistance,
    Min = 80, Max = 800, Rounding = 0,
})
Options.KrakenHoverDistance:OnChanged(function(value)
    env.VampireFarmConfig.KrakenHoverDistance = value
end)
krakenSafetyBox:AddSlider("KrakenHoverHeight", {
    Text = "Air height", Default = env.VampireFarmConfig.KrakenHoverHeight,
    Min = 100, Max = 1000, Rounding = 0,
})
Options.KrakenHoverHeight:OnChanged(function(value)
    env.VampireFarmConfig.KrakenHoverHeight = value
end)
krakenSafetyBox:AddSlider("KrakenSafetySeconds", {
    Text = "Stay back after dive", Default = env.VampireFarmConfig.KrakenSafetySeconds,
    Min = 1, Max = 8, Rounding = 1,
})
Options.KrakenSafetySeconds:OnChanged(function(value)
    env.VampireFarmConfig.KrakenSafetySeconds = value
end)
krakenSafetyBox:AddLabel("Floats outside the arena during dive, emergence, or invulnerability.", true)
end

bossBox:AddToggle("BossFarmEnabled", {
    Text = "Auto Boss Farm",
    Default = env.VampireFarmConfig.BossFarmEnabled,
    Tooltip = "Interrupts the current farm for any live listed boss, then resumes it.",
})
Toggles.BossFarmEnabled:OnChanged(function(enabled)
    if enabled then golem.enableCombat() end
    env.VampireFarmConfig.BossFarmEnabled = enabled
    if not enabled and targetSource == "Boss" then
        bossTarget = nil
        target = nil
        targetSource = nil
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
    if enabled then golem.enableCombat() end
    env.VampireFarmConfig.ApexFarmEnabled = enabled
    if not enabled and targetSource == "Apex" then
        apexTarget = nil
        target = nil
        targetSource = nil
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
    if enabled then golem.enableCombat() end
    env.VampireFarmConfig.PrimeApexFarmEnabled = enabled
    if not enabled and targetSource == "PrimeApex" then
        apexTarget = nil
        target = nil
        targetSource = nil
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
    if enabled then golem.enableCombat() end
    env.VampireFarmConfig.GolemFarmEnabled = enabled
    if not enabled and (targetSource == "Golem"
        or targetSource == "GolemShard"
        or targetSource == "GolemSummon") then
        golem.Target = nil
        golem.ShardTarget = nil
        target = nil
        targetSource = nil
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
attachBox:AddToggle("OwnedMobPinEnabled", {
    Text = "Pin owned mob",
    Default = env.VampireFarmConfig.OwnedMobPinEnabled,
    Tooltip = "Holds the active target in place while you own its physics.",
})
Toggles.OwnedMobPinEnabled:OnChanged(function(enabled)
    env.VampireFarmConfig.OwnedMobPinEnabled = enabled
    if not enabled then env.VampireFarmPinState:Clear() end
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
    if mode~="Off" then
        teleportPaused=false; runtime.paused=false
        if mode~="Ore" then golem.enableCombat() end
    end
    if activeMode == mode then return end
    activeMode = mode
    env.VampireFarmConfig.FarmMode = mode
    oreFarm.Current = nil
    oreFarm.Phase = nil
    if not bossTarget and not apexTarget and not kraken.Target then
        target = nil
        targetSource = nil
    end
    syncingMode = true
    if Toggles.VampireFarmEnabled then
        Toggles.VampireFarmEnabled:SetValue(mode == "Vampire")
    end
    if Toggles.MobFarmEnabled then
        Toggles.MobFarmEnabled:SetValue(mode == "Mob")
    end
    if Toggles.OreFarmEnabled then
        Toggles.OreFarmEnabled:SetValue(mode == "Ore")
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

do
local oreBox = oreFarm.Box
local oreTimingBox = oreFarm.TimingBox
oreBox:AddToggle("OreFarmEnabled", {
    Text = "Enable Ore Farm",
    Default = activeMode == "Ore",
    Tooltip = "Mines selected ores; live boss targets still take priority.",
})
Toggles.OreFarmEnabled:OnChanged(function(enabled)
    if syncingMode then return end
    if enabled then
        setFarmMode("Ore")
    elseif activeMode == "Ore" then
        setFarmMode("Off")
    end
end)
local initialOreSelection = {}
for _, name in ipairs(oreFarm.Names) do
    if env.VampireFarmConfig.SelectedOres[name] then
        table.insert(initialOreSelection, name)
    end
end
oreBox:AddDropdown("OreTargets", {
    Text = "Ores to mine",
    Values = oreFarm.Names,
    Default = initialOreSelection,
    Multi = true,
    AllowNull = true,
})
addDropdownSearch(oreBox, "OreTargets", "ores")
Options.OreTargets:OnChanged(function(selected)
    selected = type(selected) == "table" and selected or {}
    for _, name in ipairs(oreFarm.Names) do
        env.VampireFarmConfig.SelectedOres[name] = selected[name] == true or nil
    end
    if oreFarm.Current and not env.VampireFarmConfig.SelectedOres[
        oreFarm.Current:GetAttribute("LinkedItem")] then
        oreFarm.Current, oreFarm.Phase = nil, nil
    end
end)
oreBox:AddButton("Select All", function()
    local selected = {}
    for _, name in ipairs(oreFarm.Names) do selected[name] = true end
    Options.OreTargets:SetValue(selected)
end)
oreBox:AddButton("Deselect All", function()
    Options.OreTargets:SetValue({})
end)
oreBox:AddLabel("Live bosses interrupt mining; ore farming resumes afterward.", true)
oreTimingBox:AddSlider("OreMineSeconds", {
    Text = "Mining time",
    Default = env.VampireFarmConfig.OreMineSeconds,
    Min = 0, Max = 60, Rounding = 1, Suffix = " s",
    Tooltip = "Time to remain at a node after triggering its prompt.",
})
Options.OreMineSeconds:OnChanged(function(value)
    env.VampireFarmConfig.OreMineSeconds = oreFarm.boundedTime(value, 2, 60)
end)
oreTimingBox:AddSlider("OreDelaySeconds", {
    Text = "Wait after mining",
    Default = env.VampireFarmConfig.OreDelaySeconds,
    Min = 0, Max = 5, Rounding = 1, Suffix = " s",
})
Options.OreDelaySeconds:OnChanged(function(value)
    env.VampireFarmConfig.OreDelaySeconds = oreFarm.boundedTime(value, 1, 5)
end)
oreTimingBox:AddLabel("Each ore uses the game's 0.5-second prompt.", true)
end

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

combatBox:AddToggle("VampireInstantKill", {
    Text = "Instant kill attempt",
    Default = env.VampireFarmConfig.InstantKillEnabled,
    Tooltip = "Attempt the local HP kill when the mob reaches its HP threshold.",
})
Toggles.VampireInstantKill:OnChanged(function(value)
    env.VampireFarmConfig.InstantKillEnabled = value
end)
combatBox:AddDropdown("VampireInstantKillMethod", {
    Text = "Insta Kill method",
    Values = {"Dead state", "Local health"},
    Default = env.VampireFarmConfig.InstantKillMethod,
})
addDropdownSearch(combatBox, "VampireInstantKillMethod", "kill methods")
Options.VampireInstantKillMethod:OnChanged(function(value)
    env.VampireFarmConfig.InstantKillMethod = value
end)
--[[ Temporarily disabled: party damage waiting controls.
combatBox:AddToggle("VampirePartyDamageGate", {
    Text = "Wait for party damage",
    Default = env.VampireFarmConfig.PartyDamageGateEnabled,
    Tooltip = "Wait for party members contributing to this mob, without stopping your own damage progress.",
})
Toggles.VampirePartyDamageGate:OnChanged(function(value)
    env.VampireFarmConfig.PartyDamageGateEnabled = value
end)
combatBox:AddSlider("VampirePartyDamageThreshold", {
    Text = "Damage per party member",
    Default = env.VampireFarmConfig.PartyDamageThresholdPercent,
    Min = 0,
    Max = 100,
    Rounding = 0,
    Suffix = "% of mob max HP",
})
Options.VampirePartyDamageThreshold:OnChanged(function(value)
    env.VampireFarmConfig.PartyDamageThresholdPercent = value
end)
combatBox:AddSlider("VampirePartyDamageIdleSeconds", {
    Text = "Stop waiting after no damage",
    Default = env.VampireFarmConfig.PartyDamageIdleSeconds,
    Min = 3,
    Max = 30,
    Rounding = 0,
    Suffix = "s",
})
Options.VampirePartyDamageIdleSeconds:OnChanged(function(value)
    env.VampireFarmConfig.PartyDamageIdleSeconds = value
end)
]]
env.VampireFarmPartyAutomation.Box:AddToggle("VampireAutoInvitePlayers", {
    Text = "Invite players to my party",
    Default = env.VampireFarmConfig.AutoInvitePlayersEnabled,
    Tooltip = "Invite players in this server and retry until they join your party.",
})
Toggles.VampireAutoInvitePlayers:OnChanged(function(value)
    env.VampireFarmConfig.AutoInvitePlayersEnabled = value
end)
env.VampireFarmPartyAutomation.Box:AddSlider("VampirePartyInviteInterval", {
    Text = "Retry invite after",
    Default = env.VampireFarmConfig.PartyInviteIntervalSeconds,
    Min = 5,
    Max = 60,
    Rounding = 0,
    Suffix = "s",
})
Options.VampirePartyInviteInterval:OnChanged(function(value)
    env.VampireFarmConfig.PartyInviteIntervalSeconds = value
end)
--[[ Temporarily disabled: automatic party invite acceptance.
env.VampireFarmPartyAutomation.Box:AddToggle("VampireAutoAcceptPartyInvites", {
    Text = "Accept party invites",
    Default = env.VampireFarmConfig.AutoAcceptPartyInvitesEnabled,
    Tooltip = "Accept visible in-game party invitation dialogs while you are not already in a party.",
})
Toggles.VampireAutoAcceptPartyInvites:OnChanged(function(value)
    env.VampireFarmConfig.AutoAcceptPartyInvitesEnabled = value
end)
]]


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

skillsBox:AddToggle("VampireAutoEquipWeapon", {
    Text = "Auto Equip Weapon",
    Default = env.VampireFarmConfig.AutoEquipWeaponEnabled,
})
Toggles.VampireAutoEquipWeapon:OnChanged(function(value)
    env.VampireFarmConfig.AutoEquipWeaponEnabled = value
end)
skillsBox:AddToggle("VampireAutoSkill", {
    Text = "Auto Skill",
    Default = env.VampireFarmConfig.AutoSkillEnabled,
})
Toggles.VampireAutoSkill:OnChanged(function(value)
    env.VampireFarmConfig.AutoSkillEnabled = value
    if not value then silentAim.Target, silentAim.Until = nil, 0 end
    if silentAim.CheckManaReset then silentAim.CheckManaReset(player.Character) end
end)
skillsBox:AddToggle("VampireAutoSkillManaGate", {
    Text = "Pause skills below mana threshold",
    Default = env.VampireFarmConfig.AutoSkillManaGateEnabled,
})
Toggles.VampireAutoSkillManaGate:OnChanged(function(value)
    env.VampireFarmConfig.AutoSkillManaGateEnabled = value
end)
skillsBox:AddSlider("VampireAutoSkillManaThreshold", {
    Text = "Resume skills at mana",
    Default = env.VampireFarmConfig.AutoSkillManaThresholdPercent,
    Min = 0,
    Max = 100,
    Rounding = 0,
    Suffix = "%",
})
Options.VampireAutoSkillManaThreshold:OnChanged(function(value)
    env.VampireFarmConfig.AutoSkillManaThresholdPercent = value
end)
skillsBox:AddToggle("VampireAutoSkillResetAtLowMana", {
    Text = "Reset character at low mana",
    Default = env.VampireFarmConfig.AutoSkillResetAtLowMana,
    Tooltip = "With Auto Skill on, sets your Humanoid.Health to 0 when Mana is at or below the entered amount; resumes after respawn.",
})
Toggles.VampireAutoSkillResetAtLowMana:OnChanged(function(value)
    env.VampireFarmConfig.AutoSkillResetAtLowMana = value
    if silentAim.CheckManaReset then silentAim.CheckManaReset(player.Character) end
end)
skillsBox:AddInput("VampireAutoSkillResetManaThreshold", {
    Text = "Reset when Mana <=",
    Default = tostring(env.VampireFarmConfig.AutoSkillResetManaThreshold),
    Numeric = true,
    Finished = true,
})
Options.VampireAutoSkillResetManaThreshold:OnChanged(function(value)
    local number = tonumber(value)
    if number and number == number and number ~= math.huge
        and number ~= -math.huge then
        env.VampireFarmConfig.AutoSkillResetManaThreshold = math.max(0,
            math.floor(number + 0.5))
        if silentAim.CheckManaReset then silentAim.CheckManaReset(player.Character) end
    end
end)
skillsBox:AddToggle("VampireSilentAim", {
    Text = "Silent Aim for Auto Skill",
    Default = env.VampireFarmConfig.SilentAimEnabled,
    Tooltip = "Redirects mouse-based Auto Skills to the current target without moving the camera.",
})
Toggles.VampireSilentAim:OnChanged(function(value)
    env.VampireFarmConfig.SilentAimEnabled = value
    if value and silentAim.install then silentAim.install() end
    if not value then silentAim.Target, silentAim.Until = nil, 0 end
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
uiBox:AddLabel("Settings save automatically. Farms start off on each execution.",true)
uiBox:AddButton("Save config now",function() runtime.saveSettings() end)
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
local function getAvailableSkills(forceRefresh)
    if not forceRefresh and silentAim.AvailableSkills
        and os.clock() < silentAim.AvailableSkillsUntil then
        return silentAim.AvailableSkills
    end
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
                    and tool.Name ~= "World Tree Magic: Heartwood Lance"
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
    silentAim.AvailableSkills = result
    silentAim.AvailableSkillsUntil = os.clock() + 0.45
    return result
end

local refreshingSkills = false
local skillSignature = ""
Options.VampireSkillPicker:OnChanged(function(selectedLabels)
    if refreshingSkills
        or os.clock() < (silentAim.SkillPickerRefreshUntil or 0) then return end
    local available = getAvailableSkills(true)
    local labels = {}
    for _, skill in ipairs(available) do
        table.insert(labels, skill.Label)
    end
    if table.concat(labels, "\n") ~= skillSignature then return end
    local selected = env.VampireFarmConfig.SelectedSkills
    for _, skill in ipairs(available) do
        selected[skill.Key] = selectedLabels[skill.Label] or nil
    end
end)

local function refreshSkillPicker()
    local available = getAvailableSkills(true)
    if #available == 0
        and next(env.VampireFarmConfig.SelectedSkills) ~= nil then
        return
    end
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
    if signature ~= silentAim.SkillPickerPendingSignature then
        silentAim.SkillPickerPendingSignature = signature
        silentAim.SkillPickerPendingSince = os.clock()
        return
    end
    if os.clock() - silentAim.SkillPickerPendingSince < 1 then return end
    skillSignature = signature
    refreshingSkills = true
    silentAim.SkillPickerRefreshUntil = os.clock() + 2
    Options.VampireSkillPicker:SetValues(names)
    Options.VampireSkillPicker:SetValue(selectedLabels)
    refreshingSkills = false
end
refreshSkillPicker()
task.spawn(function()
    while running do
        refreshSkillPicker()
        task.wait(0.5)
    end
end)

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
        if not runtime.paused and env.VampireFarmConfig.AutoStatEnabled then
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
    return runtime.getRoot(model)
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

function env.VampireFarmPartyAutomation.IsMember(other)
    local partyRef = player:FindFirstChild("Party")
    local party = partyRef and (partyRef:IsA("ObjectValue") and partyRef.Value or partyRef)
    return party and party:FindFirstChild(other.Name) ~= nil
end

function env.VampireFarmPartyAutomation.Invite(other)
    if not running or runtime.paused or not env.VampireFarmConfig.AutoInvitePlayersEnabled
        or not other or other == player or other.Parent ~= Players
        or env.VampireFarmPartyAutomation.IsMember(other) then return false end

    local ownParty = player:FindFirstChild("Party")
    if ownParty and ownParty:IsA("ObjectValue") then return false end
    local automation = env.VampireFarmPartyAutomation
    local now = os.clock()
    if now - automation.LastAnyInviteAt < 2
        or now - (automation.LastInviteAt[other] or -math.huge)
            < env.VampireFarmConfig.PartyInviteIntervalSeconds then return false end

    local remote = action.Parent:FindFirstChild("Party")
    if not remote or not remote:IsA("RemoteEvent") then return false end
    local ok, err = pcall(function()
        remote:FireServer("invite", other)
    end)
    if not ok then
        warn("[VampireFarm] Party invite failed: " .. tostring(err))
        return false
    end
    automation.LastInviteAt[other] = now
    automation.LastAnyInviteAt = now
    return true
end

--[[ Temporarily disabled: automatic party invite acceptance.
function env.VampireFarmPartyAutomation.IsShown(button, gui)
    local node = button
    while node and node ~= gui do
        if node:IsA("GuiObject") and not node.Visible then return false end
        node = node.Parent
    end
    return node == gui and gui.Enabled
end

function env.VampireFarmPartyAutomation.AcceptVisibleInvite()
    if not running or not env.VampireFarmConfig.AutoAcceptPartyInvitesEnabled
        or player:FindFirstChild("Party") then return false end
    local automation = env.VampireFarmPartyAutomation
    for _, gui in ipairs(playerGui:GetChildren()) do
        local guiName = gui.Name:lower()
        if gui:IsA("ScreenGui") and gui.Enabled
            and (guiName:find("dialog", 1, true)
                or guiName:find("confirm", 1, true)
                or guiName:find("invite", 1, true)) then
            local textParts = {}
            local acceptButton
            for _, item in ipairs(gui:GetDescendants()) do
                if item:IsA("TextLabel") or item:IsA("TextButton") then
                    local label = item.Text:lower():gsub("%s+", " ")
                    table.insert(textParts, label)
                    if label == "accept" or label == "yes" or label == "join"
                        or label:find("^accept ") or label:find("^join ") then
                        acceptButton = item:IsA("GuiButton") and item
                            or item:FindFirstAncestorWhichIsA("GuiButton")
                    end
                elseif item:IsA("ImageButton") then
                    local name = item.Name:lower()
                    if name == "accept" or name == "yes" or name == "join" then
                        acceptButton = item
                    end
                end
            end
            local message = table.concat(textParts, " ")
            if message:find("party", 1, true)
                and (message:find("invit", 1, true)
                    or message:find("join", 1, true))
                and acceptButton
                and automation.IsShown(acceptButton, gui) then
                local now = os.clock()
                if now - (automation.AttemptedButtons[acceptButton] or -math.huge) >= 2 then
                    automation.AttemptedButtons[acceptButton] = now
                    if golem.clickChoice(acceptButton) then
                        print("[VampireFarm] Clicked a party invitation's Accept button")
                        return true
                    end
                    if not automation.WarnedAcceptClick then
                        automation.WarnedAcceptClick = true
                        warn("[VampireFarm] Party invite found, but this executor could not click its Accept button")
                    end
                end
            end
        end
    end
    return false
end
]]

env.VampireFarmPartyAutomation.PlayerAddedConnection = Players.PlayerAdded:Connect(function(other)
    task.defer(function()
        if running then env.VampireFarmPartyAutomation.Invite(other) end
    end)
end)
env.VampireFarmPartyAutomation.PlayerRemovingConnection = Players.PlayerRemoving:Connect(function(other)
    env.VampireFarmPartyAutomation.LastInviteAt[other] = nil
end)
task.spawn(function()
    while running do
        if env.VampireFarmConfig.AutoInvitePlayersEnabled then
            for _, other in ipairs(Players:GetPlayers()) do
                if env.VampireFarmPartyAutomation.Invite(other) then break end
            end
        end
        -- Auto-accept is disabled; auto-invite above remains active.
        task.wait(0.5)
    end
end)

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
    oreFarm.Current, oreFarm.Phase = nil, nil
    restoreBreakerVelocity()
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
teleportMobSet[kraken.Name] = true
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
        or (name == kraken.Name and kraken.Name)
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
    if not (spawn and spawn:IsA("BasePart")) then return end
    root.CFrame = CFrame.new(spawn.Position + Vector3.new(0, 5, 0))
    root.AssemblyLinearVelocity = Vector3.zero
    root.AssemblyAngularVelocity = Vector3.zero
    print("[VampireFarm] Moved to VampireSoldierSpawn")
end

function oreFarm.eligible(node)
    if not (node and node:IsA("BasePart")
        and node.Name:lower() == "orespawn"
        and node:IsDescendantOf(workspace)
        and node:GetAttribute("Active") ~= false
        and env.VampireFarmConfig.SelectedOres[node:GetAttribute("LinkedItem")]) then
        return nil
    end
    local prompt = node:FindFirstChildOfClass("ProximityPrompt")
    if prompt and prompt.Enabled and prompt.MaxActivationDistance > 0 then
        return prompt
    end
    return nil
end

function oreFarm.best(fromPosition)
    local interactions = entities:FindFirstChild("Interactions")
    local collectibles = interactions and interactions:FindFirstChild("Collectibles")
    if not collectibles then return nil end
    local bestNode, bestPrompt, bestDistance
    local now = os.clock()
    for _, folderName in ipairs(oreFarm.Folders) do
        local folder = collectibles:FindFirstChild(folderName)
        if folder then
            for _, node in ipairs(folder:GetChildren()) do
                local prompt = oreFarm.eligible(node)
                if prompt and now >= (oreFarm.Attempted[node] or 0) then
                    local distance = (fromPosition - node.Position).Magnitude
                    if not bestDistance or distance < bestDistance then
                        bestNode, bestPrompt, bestDistance = node, prompt, distance
                    end
                end
            end
        end
    end
    return bestNode, bestPrompt
end

function oreFarm.step(root)
    local now = os.clock()
    if oreFarm.Phase == "mining" then
        if now < oreFarm.MineUntil then
            local node = oreFarm.Current
            if node and node:IsDescendantOf(workspace) then
                root.AssemblyLinearVelocity = Vector3.zero
                root.AssemblyAngularVelocity = Vector3.zero
                root.CFrame = CFrame.new(node.Position + Vector3.new(0, 3, 0))
            end
            return
        end
        oreFarm.Current, oreFarm.Phase = nil, nil
        oreFarm.NextNodeAt = now + env.VampireFarmConfig.OreDelaySeconds
    end
    if now < oreFarm.NextNodeAt then return end
    if type(fireproximityprompt) ~= "function" then
        if now - oreFarm.LastWarningAt >= 15 then
            warn("[VampireFarm] Ore Farm needs fireproximityprompt")
            oreFarm.LastWarningAt = now
        end
        return
    end

    local node = oreFarm.Current
    local prompt = oreFarm.eligible(node)
    if not prompt then
        node, prompt = oreFarm.best(root.Position)
        if not node then
            oreFarm.Current, oreFarm.Phase = nil, nil
            return
        end
        oreFarm.Current = node
        oreFarm.Phase = "approach"
        oreFarm.ReadyAt = now + 0.25
    end
    local distance = (root.Position - node.Position).Magnitude
    if distance > math.max(2, prompt.MaxActivationDistance - 1) then
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
        root.CFrame = CFrame.new(node.Position + Vector3.new(0, 3, 0))
        oreFarm.ReadyAt = now + 0.25
        return
    end
    if now < oreFarm.ReadyAt then return end

    local ok, err = pcall(fireproximityprompt, prompt)
    if not ok then
        oreFarm.Attempted[node] = now + 5
        oreFarm.Current, oreFarm.Phase = nil, nil
        warn("[VampireFarm] Ore prompt failed: " .. tostring(err))
        return
    end
    local cooldown = tonumber(node:GetAttribute("CD")) or 120
    oreFarm.Attempted[node] = now + math.clamp(cooldown, 1, 600)
    oreFarm.Phase = "mining"
    oreFarm.MineUntil = now + env.VampireFarmConfig.OreMineSeconds
    print("[VampireFarm] Mining " .. tostring(node:GetAttribute("LinkedItem"))
        .. " at " .. tostring(node.Position))
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

function kraken.eligible(model)
    if not env.VampireFarmConfig.KrakenFarmEnabled
        or not model or model.Name ~= kraken.Name
        or not aliveModel(model) then
        return false
    end
    if model.Parent == enemies then return true end
    return model:GetAttribute("CollisionGroup") == "Enemy"
        and model:GetAttribute("OverheadType") == nil
end

function kraken.diveAnimationPlaying(model)
    local humanoid = model:FindFirstChildOfClass("Humanoid")
    local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
    local animations = model:FindFirstChild("Anims")
    local dive = animations and animations:FindFirstChild("dive")
    local emerge = animations and animations:FindFirstChild("emerge")
    if not (animator and dive and emerge) then return false end
    local ok, tracks = pcall(function()
        return animator:GetPlayingAnimationTracks()
    end)
    if not ok then return false end
    for _, track in ipairs(tracks) do
        local animation = track.Animation
        local id = animation and animation.AnimationId
        if track.IsPlaying and id
            and (id == dive.AnimationId or id == emerge.AnimationId) then
            return true
        end
    end
    return false
end

function kraken.updateDanger(model)
    if not env.VampireFarmConfig.KrakenDiveProtectionEnabled
        or not kraken.eligible(model) then return false end
    local root = getRoot(model)
    if root then kraken.LastAnchor = root.CFrame end
    local state = model:GetAttribute("state")
    local submerged = type(state) == "string"
        and state ~= "" and state:lower() ~= "above"
    local status = model:FindFirstChild("Status")
    local untargetable = status and status:FindFirstChild("Untargetable")
    local attribute = model:GetAttribute("Untargetable")
    local invulnerable = game:GetService("CollectionService")
        :HasTag(model, "Untargetable")
        or (untargetable and untargetable:IsA("NumberValue")
            and untargetable.Value > 0)
        or attribute == true or (type(attribute) == "number" and attribute > 0)
    local danger = submerged or invulnerable
        or kraken.diveAnimationPlaying(model)
    if danger then
        kraken.SafeUntil = math.max(kraken.SafeUntil,
            os.clock() + env.VampireFarmConfig.KrakenSafetySeconds)
        if not kraken.Waiting then
            print("[VampireFarm] Kraken dive/phase detected; floating clear")
            kraken.Waiting = true
        end
    end
    return danger
end

function kraken.safetyActive()
    return env.VampireFarmConfig.KrakenFarmEnabled and env.VampireFarmConfig.KrakenDiveProtectionEnabled
        and kraken.LastAnchor ~= nil and os.clock() < kraken.SafeUntil
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
        elseif instance.Name == kraken.Name then
            kraken.Candidates[instance] = true
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

function kraken.best(fromPosition)
    for _, model in ipairs(enemies:GetChildren()) do trackBoss(model) end
    local best, bestDistance
    for model in pairs(kraken.Candidates) do
        if kraken.eligible(model) then
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
        chestPrompts[instance] = {IsChest = nil, NextCheck = 0}
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
    if not (prompt and prompt:IsDescendantOf(workspace)) then
        return false
    end
    local part, chestRoot = chestPartAndRoot(prompt)
    if not (part and chestRoot and prompt.Enabled
        and prompt.MaxActivationDistance > 0
        and not attemptedChestPrompts[prompt]) then
        return false, part, chestRoot
    end
    return chestStateAllows(prompt, chestRoot), part, chestRoot
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
    local now = os.clock()
    for prompt, state in pairs(chestPrompts) do
        if not prompt:IsDescendantOf(workspace) then
            chestPrompts[prompt] = nil
        elseif state.IsChest or now >= state.NextCheck then
            local eligible, part, chestRoot = eligibleChest(prompt)
            state.IsChest = chestRoot ~= nil
            state.NextCheck = now + 5
            if eligible then
                local distance = (part.Position - fromPosition).Magnitude
                if distance <= env.VampireFarmConfig.ChestLootRadius
                    and (not best or distance < bestDistance) then
                    best, bestDistance = prompt, distance
                end
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
    if targetSource == "Kraken" then
        return model == kraken.Target and kraken.eligible(model)
    end
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

function env.VampireFarmPinState:Apply()
    if not env.VampireFarmConfig.OwnedMobPinEnabled
        or teleportPaused or not runtime.allowCombat() or targetSource~="Base" or not target or not aliveTarget(target)
        or type(isnetworkowner) ~= "function" then
        self:Clear()
        return
    end

    local root = getRoot(target)
    if not root or not root:IsA("BasePart") or root.Anchored then
        self:Clear()
        return
    end
    local ok, owned = pcall(isnetworkowner, root)
    if not (ok and owned) then
        self:Clear()
        return
    end

    if self.Mob ~= target or self.Root ~= root then
        self.Mob, self.Root, self.CFrame = target, root, root.CFrame
    end
    root.AssemblyLinearVelocity = Vector3.zero
    root.AssemblyAngularVelocity = Vector3.zero
    root.CFrame = self.CFrame
end


function silentAim.resolve()
    if not running or teleportPaused or not runtime.allowCombat() or not env.VampireFarmConfig.AutoSkillEnabled
        or not env.VampireFarmConfig.SilentAimEnabled
        or os.clock() > silentAim.Until
        or silentAim.Target ~= target
        or not aliveTarget(silentAim.Target) then
        return nil
    end
    local part = getRoot(silentAim.Target)
    if not part then return nil end
    return {Position = part.Position, Target = part}
end

function silentAim.arm(enemy, seconds)
    if env.VampireFarmConfig.SilentAimEnabled and enemy == target
        and aliveTarget(enemy) then
        silentAim.Target = enemy
        silentAim.Until = os.clock() + seconds
    end
end

function silentAim.install()
    if not running or not env.VampireFarmConfig.SilentAimEnabled then return end
    local gameGlobal = _G
    if type(getrenv) == "function" then
        local ok, runtime = pcall(getrenv)
        if ok and type(runtime) == "table" and type(runtime._G) == "table" then
            gameGlobal = runtime._G
        end
    end
    if not silentAim.GlobalWrapper and type(gameGlobal.GetMouse) == "function" then
        silentAim.GameGlobal = gameGlobal
        silentAim.OriginalGlobal = gameGlobal.GetMouse
        silentAim.GlobalWrapper = function(...)
            local aim = silentAim.resolve()
            if aim then return aim end
            return silentAim.OriginalGlobal(...)
        end
        gameGlobal.GetMouse = silentAim.GlobalWrapper
    end
    if silentAim.RemoteWrapper then return end
    local remote = action.Parent:FindFirstChild("GetMouse")
    if not (remote and remote:IsA("RemoteFunction")
        and type(getcallbackvalue) == "function") then return end
    local ok, original = pcall(getcallbackvalue, remote, "OnClientInvoke")
    if not ok or type(original) ~= "function" then return end
    local wrapper = function(...)
        local aim = silentAim.resolve()
        if aim then return aim end
        return original(...)
    end
    local installed = pcall(function() remote.OnClientInvoke = wrapper end)
    if installed then
        silentAim.Remote = remote
        silentAim.OriginalRemote = original
        silentAim.RemoteWrapper = wrapper
    end
end

task.spawn(function()
    local deadline = os.clock() + 20
    repeat
        silentAim.install()
        if silentAim.RemoteWrapper and silentAim.GlobalWrapper then break end
        task.wait(0.25)
    until not running or os.clock() >= deadline
    if running and env.VampireFarmConfig.SilentAimEnabled and not silentAim.RemoteWrapper and not silentAim.GlobalWrapper then
        warn("[VampireFarm] Silent Aim could not find a mouse callback")
    end
end)

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
        if selected then
            local chosenName = env.VampireFarmConfig.MobSpawnOverrides[name]
                or MOB_SPAWN_NAMES[name]
            local chosenSpawn = chosenName and spawns:FindFirstChild(chosenName,true)
            if chosenSpawn and chosenSpawn:IsA("Model") then chosenSpawn=runtime.getRoot(chosenSpawn) end
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
local killCounts=setmetatable({}, {__mode="k"})

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
    if (killCounts[model] or 0)>=3 then return "three unconfirmed attempts; continuing normal combat",nil end
    if os.clock()-(attemptedMobs[model] or -math.huge)<5 then return "retry cooldown",nil end
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
    if Toggles.KaldrisAutoCycle.Value and model and model.Name=="Kaldris" then return false end
    local reason,humanoid=golem.inspectKill(model)
    if not humanoid then return false end
    local previous=humanoid.Health
    local ok,err=pcall(function()
        if env.VampireFarmConfig.InstantKillMethod=="Dead state" then
            humanoid:ChangeState(Enum.HumanoidStateType.Dead)
        else humanoid.Health=0 end
    end)
    attemptedMobs[model]=os.clock(); killCounts[model]=(killCounts[model] or 0)+1
    if not ok then golem.reportKillGate(model,tostring(err),false); return false end
    golem.reportKillGate(model,"Unconfirmed local kill attempt; normal combat remains enabled",true)
    task.delay(.5,function()
        if not running or not model.Parent or not humanoid.Parent then return end
        if humanoid.Health<=0 and model:GetAttribute("Dead")~=true then
            pcall(function() humanoid.Health=previous end)
            warn("[CloverKill] No authoritative death marker; restored client health for target tracking")
        end
    end)
    return false
end
local warnedDisabledSpawn = false
local equipCharacter, lastEquipAttempt, equipAttempts = nil, -math.huge, 0

function kraken.floatClear(myRoot)
    local anchor = kraken.LastAnchor
    if not anchor then return end
    if breakerRoot then restoreBreakerVelocity() end
    local offset = (anchor * CFrame.new(0, 0,
        env.VampireFarmConfig.KrakenHoverDistance)).Position
    local position = Vector3.new(offset.X,
        anchor.Position.Y + env.VampireFarmConfig.KrakenHoverHeight,
        offset.Z)
    local face = Vector3.new(anchor.Position.X, position.Y, anchor.Position.Z)
    myRoot.AssemblyLinearVelocity = Vector3.zero
    myRoot.AssemblyAngularVelocity = Vector3.zero
    if (face - position).Magnitude > 0.01 then
        myRoot.CFrame = CFrame.lookAt(position, face)
    else
        myRoot.CFrame = CFrame.new(position)
    end
end

-- Follow in PostSimulation and apply offsets in the mob's local space.
-- Teleport to distant targets immediately when mobs are far apart.
attachConnection = RunService.PostSimulation:Connect(function()
    runtime.kaldrisDodging=false
    if not running or teleportPaused or not runtime.allowCombat() then
        env.VampireFarmPinState:Clear()
        return
    end
    env.VampireFarmPinState:Apply()

    local character = player.Character
    local myHumanoid = character and character:FindFirstChildOfClass("Humanoid")
    local myRoot = getRoot(character)
    if not (myHumanoid and myHumanoid.Health > 0 and myRoot) then
        return
    end
    if not teleportPaused then
        if targetSource == "Kraken" and kraken.eligible(target) then
            kraken.updateDanger(target)
        end
        if kraken.safetyActive() then
            kraken.floatClear(myRoot)
            return
        end
    end
    if not env.VampireFarmConfig.AutoAttachEnabled
        or not aliveTarget(target) then return end
    local enemyRoot = getRoot(target)
    if not enemyRoot then return end

    local targetCFrame = enemyRoot.CFrame
    runtime.kaldrisDodging=false
    if target.Name=="Kaldris" and env.VampireFarmConfig.KaldrisAirDodgeEnabled then
        local status=target:FindFirstChild("Status")
        local casting=status and status:FindFirstChild("Casting",true)
        local active=(casting and casting:IsA("BoolValue") and casting.Value)
            or target:GetAttribute("Casting")==true
        if active then kaldrisDodgeUntil=os.clock()+.75 end
        if os.clock()<kaldrisDodgeUntil then
            runtime.kaldrisDodging=true
            local height=math.clamp(tonumber(env.VampireFarmConfig.KaldrisDodgeHeight) or 30,10,70)
            local destination=enemyRoot.Position+Vector3.new(0,height,8)
            myRoot.CFrame=CFrame.lookAt(destination,enemyRoot.Position)
            myRoot.AssemblyLinearVelocity=Vector3.zero
            return
        end
    end

    if env.VampireFarmConfig.IgnoreRotation then
        targetCFrame = CFrame.new(targetCFrame.Position)
    end

    local voidPoint = workspace:FindFirstChild("Layer2Floor1") and 18.5 or 0
    if env.VampireFarmConfig.PreventVoiding
        and targetSource ~= "Kraken" and targetCFrame.Y < voidPoint then
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
        local facingPoint = Vector3.new(targetCFrame.X, backCFrame.Y, targetCFrame.Z)
        if (facingPoint - backCFrame.Position).Magnitude > 0.01 then
            myRoot.CFrame = CFrame.lookAt(backCFrame.Position, facingPoint)
        else
            myRoot.CFrame = backCFrame
        end
    else
        myRoot.CFrame = backCFrame
    end
end)

-- Apply the pathfind-breaker velocity after Auto Attach's PostSimulation reset.
-- Restore it before the next render, or before simulation if rendering is off.
breakerSimulationConnection = RunService.PreSimulation:Connect(function()
    if running then env.VampireFarmPinState:Apply() end
    if breakerRoot then restoreBreakerVelocity() end
end)
breakerHeartbeatConnection = RunService.Heartbeat:Connect(function()
    if breakerRoot then restoreBreakerVelocity() end
    if not running or teleportPaused or not runtime.allowCombat() or runtime.kaldrisDodging or not env.VampireFarmConfig.AIBreakerEnabled
        or kraken.safetyActive()
        or targetSource == "Kraken"
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
    if not env.VampireFarmConfig.AutoEquipWeaponEnabled then return end
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

local lastSkillAttempt = {}
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
    if not running or teleportPaused or not runtime.allowCombat() or kraken.safetyActive() or runtime.kaldrisDodging or player.Character ~= character or tool.Parent ~= character
        or not tool.Enabled or not aliveTarget(enemy) then return false end

    local status = character:FindFirstChild("Status")
    local casting = status and status:FindFirstChild("Casting")
    local cooldown = status and status:FindFirstChild("Cooldown")
    if casting and casting.Value then return false end
    -- Allow the spell's equip handler to connect its activation listeners.
    task.wait(0.15)
    if not running or teleportPaused or not runtime.allowCombat() or kraken.safetyActive() or runtime.kaldrisDodging or player.Character ~= character or tool.Parent ~= character
        or not aliveTarget(enemy) then return false end
    if tool.Name == "Shadow Magic: Night Coffin" then
        golem.aimCoffin(enemy)
        task.wait()
        if not running or teleportPaused or not runtime.allowCombat() or kraken.safetyActive() or runtime.kaldrisDodging or player.Character ~= character or tool.Parent ~= character or not aliveTarget(enemy) then return false end
        golem.aimCoffin(enemy)
    end
    silentAim.arm(enemy,8)
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
    if not running or teleportPaused or not runtime.allowCombat() or kraken.safetyActive() or runtime.kaldrisDodging or not env.VampireFarmConfig.AutoSkillEnabled
        or character ~= player.Character or enemy ~= target
        or not aliveTarget(enemy) then
        return false
    end
    if env.VampireFarmConfig.AutoSkillManaGateEnabled then
        local mana=runtime.mana()
        if not mana or mana<env.VampireFarmConfig.AutoSkillManaThresholdPercent then return false end
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
                        silentAim.arm(enemy, 8)
                        local sent, err = pcall(function()
                            action:FireServer("Toolbar", {WeaponSkill = name})
                        end)
                        if sent then return true end
                        silentAim.Target, silentAim.Until = nil, 0
                        warn("[VampireFarm] Weapon skill failed: " .. tostring(err))
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
                        local ok, ready = pcall(function()
                            return CheckService:Skill(character, name)
                        end)
                        if ok and ready
                            and activateGrimoireTool(character, enemy, tool) then
                            lastSkillAttempt[skill.Key] = os.clock()
                            nextSkillIndex = index % #available + 1
                            return true
                        end
                    end
                end
            end
        end
    end
    return false
end

task.spawn(function()
    while running and env.VampireFarmLaunchToken == launchToken do
        local waitTime = 0.15
        local skillTarget = silentAim.SkillCombatTarget
        local character = player.Character
        if env.VampireFarmConfig.AutoSkillEnabled
            and next(env.VampireFarmConfig.SelectedSkills) ~= nil
            and skillTarget and skillTarget == target
            and character and aliveTarget(skillTarget) then
            waitTime = 0.03
            local status = character:FindFirstChild("Status")
            local casting = status and status:FindFirstChild("Casting")
            if not casting or casting.Value == false then
                silentAim.SkillBusy=true
                local ok, err = pcall(trySelectedSkill, character, skillTarget)
                silentAim.SkillBusy=false
                if not ok then
                    warn("[VampireFarm] Auto Skill failed: " .. tostring(err))
                end
            end
        end
        task.wait(waitTime)
    end
end)

print("[VampireFarm] Started in " .. activeMode .. " mode; local kill threshold "
    .. currentKillThreshold() .. "%")

RunService:BindToRenderStep(cameraBinding, Enum.RenderPriority.Camera.Value + 1, function()
    if not running then return end
    if teleportPaused or not runtime.allowCombat() or kraken.safetyActive() then restoreCamera(); return end
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
        if not runtime.paused and env.VampireFarmConfig.AutoResetEnabled and not requested and humanoid
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
golem.HUD=runtime.hud
runtime.telemetry=function()
    return {Model=target,Skills=env.VampireFarmConfig.AutoSkillEnabled and "Enabled" or "Off",
        TeleportPaused=teleportPaused,FarmMode=activeMode,BossEnabled=env.VampireFarmConfig.BossFarmEnabled,Source=targetSource,Ore=oreFarm.Current and oreFarm.Current:GetAttribute("LinkedItem"),KrakenSafety=kraken.safetyActive()}
end
local function updateTarget(fromPosition)
    if Toggles.KaldrisCombat and Toggles.KaldrisCombat.Value then
        local found
        for _,model in ipairs(enemies:GetDescendants()) do
            if model:IsA("Model") and model.Name=="Kaldris" and aliveModel(model) then found=model; break end
        end
        if not found then
            for model in pairs(bossCandidates) do
                if model.Name=="Kaldris" and aliveModel(model) and runtime.isEnemy(model) then found=model; break end
            end
        end
        bossTarget=found; target=found; targetSource=found and "Boss" or nil
        oreFarm.Current=nil; oreFarm.Phase=nil; kraken.SafeUntil=0; kraken.Waiting=false
        return
    end
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

    local foundKraken
    if env.VampireFarmConfig.KrakenFarmEnabled then
        foundKraken = kraken.eligible(kraken.Target) and kraken.Target
            or kraken.best(fromPosition)
    end
    if foundKraken then
        if target ~= foundKraken or targetSource ~= "Kraken" then
            print("[VampireFarm] Kraken priority: " .. foundKraken.Name
                .. " at " .. tostring(getRoot(foundKraken).Position))
        end
        kraken.Target = foundKraken
        target = foundKraken
        targetSource = "Kraken"
        local root = getRoot(foundKraken)
        if root then kraken.LastAnchor = root.CFrame end
        return
    end
    if targetSource == "Kraken" then
        if env.VampireFarmConfig.KrakenDiveProtectionEnabled
            and kraken.LastAnchor then
            kraken.SafeUntil = math.max(kraken.SafeUntil,
                os.clock() + env.VampireFarmConfig.KrakenSafetySeconds)
        end
        print("[VampireFarm] Kraken cleared; resuming other farms")
        target = nil
        targetSource = nil
    end
    kraken.Target = nil

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
    if activeMode ~= "Ore" and env.VampireFarmConfig.GolemFarmEnabled
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

silentAim.CheckManaReset = function(character)
    if not running or runtime.paused or teleportPaused or env.VampireFarmLaunchToken ~= launchToken
        or not env.VampireFarmConfig.AutoSkillEnabled
        or not env.VampireFarmConfig.AutoSkillResetAtLowMana
        or not character or character ~= player.Character
        or silentAim.ManaResetCharacter == character
        or character:GetAttribute("Loaded") ~= true then
        return false
    end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local mana = character:GetAttribute("Mana")
    local threshold = env.VampireFarmConfig.AutoSkillResetManaThreshold
    if not humanoid or humanoid.Health <= 0
        or type(mana) ~= "number" or mana ~= mana
        or mana == math.huge or mana == -math.huge
        or type(threshold) ~= "number" or mana > threshold then
        return false
    end

    silentAim.ManaResetCharacter = character
    local resetOk, resetErr = pcall(function()
        humanoid.Health = 0
    end)
    if not resetOk then
        silentAim.ManaResetCharacter = nil
        warn("[VampireFarm] Mana-threshold reset failed: " .. tostring(resetErr))
        return false
    end
    warn(("[VampireFarm] Mana %.0f <= reset threshold %.0f; setting Humanoid.Health to 0")
        :format(mana, threshold))
    return true
end

-- Kaldris cycle: one prompt per summon, confirmed defeat, reset, altar, spin prestige.
function kaldrisCycle.status(message)
    if kaldrisCycle.Message==message then return end
    kaldrisCycle.Message=message
    if kaldrisCycle.Label then kaldrisCycle.Label:SetText(message) end
    print("[KaldrisCycle] "..message)
end
function kaldrisCycle.configureCombat()
    if os.clock()-(kaldrisCycle.ConfigureAt or -math.huge)<2 then return end
    kaldrisCycle.ConfigureAt=os.clock()
    for id,value in pairs({VampireAutoEquipWeapon=true,VampireAutoSkill=true,VampireSilentAim=true,
        VampireAutoSkillManaGate=false,KaldrisAirDodge=true}) do
        local control=Toggles[id]
        if control and control.Value~=value then control:SetValue(value) end
    end
    runtime.config.ManaRest=false
    if runtime.sharedToggles and runtime.sharedToggles.HubManaRest then runtime.sharedToggles.HubManaRest:SetValue(false) end
    local changed=false
    for _,skill in ipairs(getAvailableSkills()) do
        if not env.VampireFarmConfig.SelectedSkills[skill.Key] then
            env.VampireFarmConfig.SelectedSkills[skill.Key]=true; changed=true
        end
    end
    if changed then
        -- Force the visible picker to reflect automatic selections as well.
        skillSignature=""; refreshSkillPicker()
    end
end
function kaldrisCycle.setCombat(enabled)
    if Toggles.KaldrisCombat.Value~=enabled then Toggles.KaldrisCombat:SetValue(enabled) end
    if not enabled then target,targetSource,bossTarget=nil,nil,nil end
end
function kaldrisCycle.level()
    local character=player.Character
    local status=character and character:FindFirstChild("Status")
    local containers={player,character,status,status and status:FindFirstChild("Replicated"),player:FindFirstChild("leaderstats"),player:FindFirstChild("Data")}
    for _,container in pairs(containers) do
        local value=container:GetAttribute("Level")
        local child=container:FindFirstChild("Level")
        if child and (child:IsA("IntValue") or child:IsA("NumberValue")) then value=child.Value end
        if type(value)=="number" and value==value and value>=0 and value<math.huge then return math.floor(value) end
    end
end
function kaldrisCycle.findBoss()
    for _,model in ipairs(enemies:GetDescendants()) do
        if model:IsA("Model") and model.Name=="Kaldris" and aliveModel(model) then return model end
    end
    for model in pairs(bossCandidates) do
        if model.Name=="Kaldris" and runtime.isEnemy(model) and aliveModel(model) then return model end
    end
end
function kaldrisCycle.prompt(kind)
    local cached=kaldrisCycle[kind.."Prompt"]
    if cached and cached:IsDescendantOf(workspace) then return cached end
    local candidates={}
    for _,prompt in ipairs(workspace:GetDescendants()) do
        if prompt:IsA("ProximityPrompt") then
            local node=prompt.Parent
            while node and node~=workspace do
                local name=node.Name:lower():gsub("[^%w]", "")
                if (kind=="Altar" and name=="emberaltar")
                    or (kind=="Wizard" and (name=="fabio" or name=="wizardking" or name=="wizzardking" or name:match("^fabiowizardking"))) then
                    table.insert(candidates,prompt); break
                end
                node=node.Parent
            end
        end
    end
    if #candidates==1 then
        cached=candidates[1]; kaldrisCycle[kind.."Prompt"]=cached
        local part=cached.Parent
        if part:IsA("Attachment") then part=part.Parent end
        if part:IsA("BasePart") then kaldrisCycle[kind.."Position"]=part.Position end
        return cached
    end
end
function kaldrisCycle.travel(kind,root)
    local prompt=kaldrisCycle.prompt(kind)
    local part=prompt and prompt.Parent
    if part and part:IsA("Attachment") then part=part.Parent end
    if not part or not part:IsA("BasePart") then
        local position=kaldrisCycle[kind.."Position"]
        if position and os.clock()-(kaldrisCycle.LastStream or -math.huge)>5 then
            kaldrisCycle.LastStream=os.clock()
            root.CFrame=CFrame.new(position+Vector3.new(0,3,3))
            task.spawn(function() pcall(function() player:RequestStreamAroundAsync(position,3) end) end)
        end
        kaldrisCycle.status(kind.." prompt unavailable; move near it once to load the route")
        return
    end
    kaldrisCycle[kind.."Position"]=part.Position
    if not prompt.Enabled then kaldrisCycle.status(kind.." prompt is disabled; waiting"); return end
    local range=math.min(5,math.max(1,prompt.MaxActivationDistance*.5))
    if (root.Position-part.Position).Magnitude>range then
        root.AssemblyLinearVelocity=Vector3.zero
        root.AssemblyAngularVelocity=Vector3.zero
        root.CFrame=CFrame.new(part.Position+Vector3.new(0,1,range*.5))
        kaldrisCycle.status("Returning to "..kind); return
    end
    return prompt
end
function kaldrisCycle.fire(prompt)
    if type(fireproximityprompt)~="function" then kaldrisCycle.status("Prompt API unavailable"); return false end
    local ok,err=pcall(fireproximityprompt,prompt,math.max(0,prompt.HoldDuration))
    if not ok then kaldrisCycle.status("Prompt failed: "..tostring(err)) end
    return ok
end
function kaldrisCycle.disconnectBoss()
    if kaldrisCycle.DeathConnection then kaldrisCycle.DeathConnection:Disconnect() end
    kaldrisCycle.DeathConnection=nil
    kaldrisCycle.Boss=nil; kaldrisCycle.DeathAt=nil
end
function kaldrisCycle.watchBoss(boss)
    if kaldrisCycle.Boss==boss then kaldrisCycle.DeathAt=nil; return end
    kaldrisCycle.disconnectBoss()
    kaldrisCycle.Boss=boss
    local humanoid=boss:FindFirstChildOfClass("Humanoid")
    if humanoid then kaldrisCycle.DeathConnection=humanoid.Died:Connect(function()
        if kaldrisCycle.Boss==boss then kaldrisCycle.DeathAt=os.clock() end
    end) end
end
function kaldrisCycle.resetFor(nextPhase,character,humanoid)
    kaldrisCycle.setCombat(false)
    kaldrisCycle.AltarClickedButton=nil
    kaldrisCycle.ResetCharacter=character
    kaldrisCycle.AfterReset=nextPhase
    kaldrisCycle.Phase="Resetting"
    kaldrisCycle.status("Resetting character, then returning to "..(nextPhase=="Prestige" and "Wizard King" or "altar"))
    local ok,err=pcall(function() humanoid.Health=0 end)
    if not ok then kaldrisCycle.halt("Reset failed: "..tostring(err)) end
end
function kaldrisCycle.halt(reason)
    kaldrisCycle.setCombat(false)
    if Toggles.VampireAutoSkill then Toggles.VampireAutoSkill:SetValue(false) end
    kaldrisCycle.Phase="Stopped"
    kaldrisCycle.status(reason.."; toggle the cycle off/on to retry")
end
function kaldrisCycle.visible(button)
    local node=button
    while node and node~=playerGui do
        if node:IsA("GuiObject") and not node.Visible then return false end
        if node:IsA("ScreenGui") and not node.Enabled then return false end
        node=node.Parent
    end
    return node==playerGui
end
function kaldrisCycle.dialogueChoice(stage)
    local text,buttons={},{}
    for _,object in ipairs(playerGui:GetDescendants()) do
        if (object:IsA("TextLabel") or object:IsA("TextButton")) and kaldrisCycle.visible(object) then
            local screen=object:FindFirstAncestorOfClass("ScreenGui")
            if screen and (screen.Name=="CloverDashboard" or screen.Name=="CloverBoot") then continue end
            local normalized=object.Text:lower():gsub("<[^>]+>", ""):gsub("[^%w%s]", ""):gsub("%s+", " "):match("^%s*(.-)%s*$")
            table.insert(text,normalized)
            local button=object:IsA("GuiButton") and object or object:FindFirstAncestorWhichIsA("GuiButton")
            -- Labels can live beside an ImageButton rather than inside it.
            buttons[object]={Text=normalized,Target=button or object}
        end
    end
    local context=table.concat(text," ")
    local found
    for _,entry in pairs(buttons) do
        local button,label=entry.Target,entry.Text
        local matches=stage=="Open" and label=="im tired of my current self"
            or stage=="Altar" and label=="press a cinder sigil into the altar"
            or stage=="Spins" and label=="if only i had a few more chances"
            or stage=="Confirm" and (label=="yes" or label=="confirm" or label=="im sure" or label=="i understand")
                and (context:find("spin",1,true) or context:find("few more chances",1,true)) and context:find("reset",1,true)
        if matches then if found and found~=button then return end; found=button end
    end
    return found
end
function kaldrisCycle.clickDialogueChoice(button)
    if not button or not kaldrisCycle.visible(button) then return false end
    local position,size=button.AbsolutePosition,button.AbsoluteSize
    if not position or not size or size.X<=0 or size.Y<=0 then return false end
    local screen=button:FindFirstAncestorOfClass("ScreenGui")
    local inset=game:GetService("GuiService"):GetGuiInset()
    local x=position.X+size.X*.5
    local rawY=position.Y+size.Y*.5
    local y=rawY+(screen and not screen.IgnoreGuiInset and inset.Y or 0)
    local function hitsChoice(atY)
        for _,item in ipairs(playerGui:GetGuiObjectsAtPosition(x,atY)) do
            if item==button or item:IsDescendantOf(button) then return true end
        end
        return false
    end
    if not hitsChoice(y) then
        if y~=rawY and hitsChoice(rawY) then y=rawY
        else kaldrisCycle.status("Dialogue choice has no matching screen hit target"); return false end
    end
    -- Send a normal pointer click: synthetic signals can return successfully
    -- without invoking the game's actual GUI input handling.
    for _,item in ipairs(playerGui:GetGuiObjectsAtPosition(x,y)) do
        local owner=item:FindFirstAncestorOfClass("ScreenGui")
        if owner and owner.Name=="CloverDashboard" then
            kaldrisCycle.status("Close the Clover menu covering the dialogue choice"); return false
        end
    end
    if game:GetService("UserInputService"):GetFocusedTextBox() then return false end
    local input=game:GetService("VirtualInputManager")
    local pressed=false
    local ok,err=pcall(function()
        input:SendMouseMoveEvent(x,y,game)
        input:SendMouseButtonEvent(x,y,0,true,game,0); pressed=true
        task.wait(.08)
    end)
    if pressed then
        local released=pcall(function() input:SendMouseButtonEvent(x,y,0,false,game,0) end)
        ok=ok and released
    end
    if not ok then kaldrisCycle.status("Dialogue pointer click failed: "..tostring(err)) end
    return ok and pressed
end
function kaldrisCycle.submitAltarChoice()
    local button=kaldrisCycle.dialogueChoice("Altar")
    if not button then return false end
    if kaldrisCycle.AltarClickedButton==button then
        kaldrisCycle.status("Cinder Sigil click sent; waiting for the dialogue to change")
        return false
    end
    if not kaldrisCycle.clickDialogueChoice(button) then
        kaldrisCycle.status("Cinder Sigil choice visible; dialogue click API failed")
        return false
    end
    kaldrisCycle.AltarClickedButton=button
    kaldrisCycle.Phase="AltarConfirm"; kaldrisCycle.AltarClickedAt=os.clock()
    kaldrisCycle.status("Cinder Sigil clicked; verifying dialogue change")
    return true
end
function kaldrisCycle.altarAccepted()
    kaldrisCycle.AltarClickedButton=nil
    kaldrisCycle.Phase="Summoning"; kaldrisCycle.SummonAt=os.clock()
    kaldrisCycle.setCombat(true)
    kaldrisCycle.status("Cinder Sigil choice selected; boss combat armed, waiting for Kaldris")
end
function kaldrisCycle.prestige(root,level)
    kaldrisCycle.setCombat(false)
    if kaldrisCycle.PrestigeLevel and level<=5 and level<kaldrisCycle.PrestigeLevel then
        kaldrisCycle.PrestigeLevel=nil; kaldrisCycle.DialogueStage=nil
        kaldrisCycle.Phase="Altar"; kaldrisCycle.status("Spin prestige level reset detected; returning to altar"); return
    end
    local now=os.clock()
    if not kaldrisCycle.DialogueStage then
        local prompt=kaldrisCycle.travel("Wizard",root)
        if not prompt then return end
        if now-(kaldrisCycle.LastWizardPrompt or -math.huge)<5 then return end
        if kaldrisCycle.fire(prompt) then
            kaldrisCycle.LastWizardPrompt=now; kaldrisCycle.DialogueStage="Open"; kaldrisCycle.DialogueAt=now
            kaldrisCycle.PrestigeLevel=level
        end
        return
    end
    if kaldrisCycle.WizardPosition and (root.Position-kaldrisCycle.WizardPosition).Magnitude>12 then
        kaldrisCycle.halt("Moved away from Wizard King during prestige"); return
    end
    if now-kaldrisCycle.DialogueAt>30 then kaldrisCycle.halt("Prestige was not confirmed; unknown dialogue or requirements"); return end
    if now-(kaldrisCycle.LastChoice or -math.huge)<1 then return end
    local stage=kaldrisCycle.DialogueStage
    -- Some versions open the prestige choices directly.
    local button=kaldrisCycle.dialogueChoice(stage)
    if not button and stage=="Open" then button=kaldrisCycle.dialogueChoice("Spins"); if button then stage="Spins" end end
    if button and kaldrisCycle.clickDialogueChoice(button) then
        kaldrisCycle.LastChoice=now
        kaldrisCycle.DialogueStage=stage=="Open" and "Spins" or stage=="Spins" and "Confirm" or "AwaitLevel"
        kaldrisCycle.status(stage=="Spins" and "Spin prestige selected; verifying level reset" or "Wizard King dialogue: "..kaldrisCycle.DialogueStage)
    end
end
function kaldrisCycle.tick(character,humanoid,root)
    if not Toggles.KaldrisAutoCycle.Value then return false end
    if kaldrisCycle.Phase=="Stopped" then kaldrisCycle.setCombat(false); return true end
    if runtime.paused then kaldrisCycle.status("Cycle paused"); return true end
    local level=kaldrisCycle.level()
    if not level then kaldrisCycle.setCombat(false); kaldrisCycle.status("Level unavailable; cycle paused"); return true end
    if kaldrisCycle.Phase=="Resetting" then
        if character and character~=kaldrisCycle.ResetCharacter and humanoid and humanoid.Health>0 and root then
            kaldrisCycle.ResetCharacter=nil; kaldrisCycle.Phase=kaldrisCycle.AfterReset
            kaldrisCycle.AfterReset=nil
        else return true end
    end
    if not (humanoid and humanoid.Health>0 and root) then
        kaldrisCycle.setCombat(false)
        kaldrisCycle.Recovering=true
        kaldrisCycle.status("Character resetting; return route resumes when character exists"); return true
    end
    if kaldrisCycle.Recovering then
        kaldrisCycle.Recovering=nil; kaldrisCycle.disconnectBoss(); kaldrisCycle.Phase="Altar"
    end
    kaldrisCycle.configureCombat()
    if kaldrisCycle.Phase=="Prestige" then kaldrisCycle.prestige(root,level); return true end
    if level>=200 then
        kaldrisCycle.disconnectBoss()
        if not Toggles.KaldrisSpinPrestige.Value then kaldrisCycle.halt("Reached level "..level); return true end
        kaldrisCycle.resetFor("Prestige",character,humanoid); return true
    end
    local boss=kaldrisCycle.findBoss()
    if boss then
        kaldrisCycle.watchBoss(boss); kaldrisCycle.Phase="Fighting"
        kaldrisCycle.setCombat(true); kaldrisCycle.status("Fighting Kaldris | Level "..level.." / 200")
        return false
    end
    if kaldrisCycle.Phase=="Fighting" then
        kaldrisCycle.setCombat(false)
        local previous=kaldrisCycle.Boss
        local health=previous and previous:FindFirstChildOfClass("Humanoid")
        if previous and (previous:GetAttribute("Dead")==true or health and health.Health<=0) then kaldrisCycle.DeathAt=kaldrisCycle.DeathAt or os.clock() end
        if not kaldrisCycle.DeathAt then
            kaldrisCycle.status("Kaldris disappeared without a death signal; waiting for phase or defeat")
            return true
        end
        if os.clock()-kaldrisCycle.DeathAt<8 then kaldrisCycle.status("Checking boss defeat / phase transition"); return true end
        kaldrisCycle.disconnectBoss(); kaldrisCycle.resetFor("Altar",character,humanoid); return true
    end
    kaldrisCycle.setCombat(kaldrisCycle.Phase=="Summoning")
    if kaldrisCycle.Phase=="Summoning" then
        if os.clock()-kaldrisCycle.SummonAt>90 then kaldrisCycle.halt("No Kaldris appeared after selecting Cinder Sigil")
        else kaldrisCycle.status("Cinder Sigil choice selected; boss combat armed, waiting for Kaldris") end
        return true
    end
    if kaldrisCycle.Phase=="AltarConfirm" then
        if not kaldrisCycle.dialogueChoice("Altar") then kaldrisCycle.altarAccepted()
        elseif os.clock()-kaldrisCycle.AltarClickedAt>10 then
            kaldrisCycle.halt("Cinder Sigil dialogue did not change after the click; check sigil availability")
        end
        return true
    end
    if kaldrisCycle.submitAltarChoice() then return true end
    if kaldrisCycle.Phase=="AltarDialogue" then
        if os.clock()-kaldrisCycle.AltarOpenedAt>30 then
            kaldrisCycle.halt("Cinder Sigil dialogue was not selected; print cycle diagnostics")
        else kaldrisCycle.status("Altar dialogue opened; looking for the Cinder Sigil choice") end
        return true
    end
    local prompt=kaldrisCycle.travel("Altar",root)
    if prompt and kaldrisCycle.fire(prompt) then
        kaldrisCycle.Phase="AltarDialogue"; kaldrisCycle.AltarOpenedAt=os.clock()
        kaldrisCycle.status("Altar prompt opened; selecting Cinder Sigil dialogue next")
    end
    return true
end

silentAim.BindManaReset = function(character)
    if silentAim.ManaChangedConnection then silentAim.ManaChangedConnection:Disconnect() end
    if silentAim.LoadedChangedConnection then silentAim.LoadedChangedConnection:Disconnect() end
    silentAim.ManaChangedConnection, silentAim.LoadedChangedConnection = nil, nil
    if not character then return end

    silentAim.ManaChangedConnection = character:GetAttributeChangedSignal("Mana"):Connect(function()
        silentAim.CheckManaReset(character)
    end)
    silentAim.LoadedChangedConnection = character:GetAttributeChangedSignal("Loaded"):Connect(function()
        silentAim.CheckManaReset(character)
    end)
    silentAim.CheckManaReset(character)
end

silentAim.CharacterAddedConnection = player.CharacterAdded:Connect(silentAim.BindManaReset)
silentAim.BindManaReset(player.Character)

while running do
    silentAim.SkillCombatTarget = nil
    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local myRoot = getRoot(character)

    if kaldrisCycle.tick(character,humanoid,myRoot) then
        task.wait(0.1)
    elseif not (humanoid and humanoid.Health > 0 and myRoot) then
        target = nil
        targetSource = nil
        task.wait(0.1)
    elseif silentAim.CheckManaReset(character) then
        task.wait(0.1)
    elseif teleportPaused or not runtime.allowCombat() then
        target = nil
        targetSource = nil
        oreFarm.Current, oreFarm.Phase = nil, nil
        task.wait(0.25)
    else
        updateTarget(myRoot.Position)

        if activeMode == "Ore" and targetSource then
            oreFarm.Current, oreFarm.Phase = nil, nil
        end

        if targetSource == "Kraken" and kraken.eligible(target) then
            kraken.updateDanger(target)
        end
        if kraken.safetyActive() then
            task.wait(0.1)
            continue
        elseif kraken.Waiting then
            kraken.Waiting = false
            print("[VampireFarm] Kraken dive/phase ended; resuming combat")
        end

        if not Toggles.KaldrisCombat.Value and targetSource ~= "Kraken" and targetSource ~= "Boss"
            and targetSource ~= "Golem"
            and targetSource ~= "GolemShard"
            and targetSource ~= "GolemSummon" and targetSource ~= "Apex"
            and targetSource ~= "PrimeApex"
            and not (activeMode == "Ore" and oreFarm.Current) then
            local chest = bestChest(myRoot.Position)
            if chest then
                target = nil
                targetSource = nil
                tryOpenChest(chest, myRoot)
                task.wait(0.2)
                continue
            end
        end

        if targetSource == "GolemSummon" then
            golem.summonStep(myRoot)
            task.wait(0.3)
        elseif not target then
            if Toggles.KaldrisCombat.Value then
                task.wait(.2); continue
            end
            if activeMode == "Vampire" then
                if not spawn or spawn.Parent ~= spawns then
                    spawn = spawns:FindFirstChild("VampireSoldierSpawn")
                end
                if spawn and spawn:IsA("BasePart")
                    and (myRoot.Position - spawn.Position).Magnitude > 80 then
                    goToSoldierSpawn(myRoot)
                end

                if not warnedDisabledSpawn
                    and (not spawn
                        or spawn:GetAttribute("spawn_enabled") == false) then
                    warnedDisabledSpawn = true
                    warn("[VampireFarm] VampireSoldierSpawn is unavailable or disabled in this place")
                end
            elseif activeMode == "Mob" then
                goToSelectedMobSpawn(myRoot)
            elseif activeMode == "Ore" then
                oreFarm.step(myRoot)
            end

            task.wait(activeMode == "Ore" and 0.1
                or activeMode == "Off" and 0.3 or 1)
        else
            ensureSelectedWeapon(character)

            if not aliveTarget(target) then
                target = nil
                continue
            end

            -- Party damage waiting is disabled; continue farming this target.

            if tryOwnedMobLocalKill(target) then
                target = nil
                task.wait(runtime.config.AttackInterval)
                continue
            end

            -- Skill checks run between M1 ticks, when the game clears Casting.
            silentAim.SkillCombatTarget = target
            if aliveTarget(target) and not silentAim.SkillBusy and runtime.allowAttack(character) and not runtime.blocked(target) then
                local sent, err = pcall(function()
                    action:FireServer("M1", {password = "Spirit"})
                end)
                if not sent then
                    warn("[VampireFarm] M1 failed: " .. tostring(err))
                end
            end
            task.wait(runtime.config.AttackInterval)
        end
    end
end

end
runtime.profiles.Jungle=function()
-- Jungle Island farm for Potassium.
-- Mob names and spawn mappings come from the connected place's live folders.

local env = getgenv()
if type(env.StopJungleFarm) == "function" then pcall(env.StopJungleFarm) end
if type(env.StopVampireFarm) == "function" then pcall(env.StopVampireFarm) end

local config = {
    MobFarm = false,
    BossFarm = false,
    ApexFarm = false,
    PrimeApexFarm = false,
    AutoAttach = false,
    FollowDistance = 5,
    XOffset = 0,
    YOffset = 0,
    AIBreaker = false,
    AIBreakerType = "OPassive",
    AutoEquip = true,
    AutoSkill = false,
    AutoStat = false,
    Stat = "STR",
    InstantKill = false,
    MobKillThreshold = 89,
    BossKillThreshold = 89,
    ApexKillThreshold = 50,
    PrimeApexKillThreshold = 35,
    NoRender = false,
    SimulationRadius = 3000,
    MenuKey = "RightShift",
    SelectedMobs = {},
    SelectedBosses = {},
    SelectedSkills = {},
    MobPriorities = {},
    MobSpawnOverrides = {},
}
if type(env.CloverJungleConfig)=="table" then
    for key,value in pairs(env.CloverJungleConfig) do if config[key]~=nil then config[key]=value end end
end
env.CloverJungleConfig=config
local token = {}
env.JungleFarmLaunchToken = token
if not game:IsLoaded() then game.Loaded:Wait() end
if env.JungleFarmLaunchToken ~= token then return end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local VirtualUser = game:GetService("VirtualUser")
local player = Players.LocalPlayer
local replicated = game:GetService("ReplicatedStorage")
local entities = workspace:WaitForChild("Entities", 15)
local enemies = entities and entities:WaitForChild("Enemies", 15)
local spawns = entities and entities:WaitForChild("Spawns", 15)
local interactions = entities and entities:FindFirstChild("Interactions")
local events = entities and entities:FindFirstChild("Events")
local package = replicated:WaitForChild("ReplicatedPackage", 15)
local remotes = package and package:WaitForChild("Remotes", 15)
local action = remotes and remotes:WaitForChild("action", 15)
local fetch = remotes and remotes:FindFirstChild("fetch")
if not (enemies and spawns and action) then
    error("[JungleFarm] Missing Entities.Enemies, Entities.Spawns, or action remote")
end

local services=package:FindFirstChild("LocalServices")
local checkModule = services and services:FindFirstChild("CheckService")
local checkOk, CheckService = pcall(function() return require(checkModule) end)
if not checkOk then CheckService = nil end
local modules=package:FindFirstChild("Modules")
local catalogModule = modules and modules:FindFirstChild("SealCatalog")
local catalogOk, SealCatalog = pcall(function() return require(catalogModule) end)
if not catalogOk then SealCatalog = nil end

local spellNames = {}
local database=services and services:FindFirstChild("Database")
local spellFolder = database and database:FindFirstChild("Spell")
if spellFolder then
    for _, item in ipairs(spellFolder:GetDescendants()) do
        if item:IsA("ModuleScript") then spellNames[item.Name] = true end
    end
end

local MOB_NAMES, BOSS_NAMES = {}, {}
local SPECIAL_BOSSES = {Apex = true, ["Prime Apex"] = true}
if SealCatalog and type(SealCatalog.Seals) == "table" then
    for _, entry in ipairs(SealCatalog.Seals) do
        if entry.region == "Jungle" and type(entry.name) == "string" then
            if entry.boss == true then
                if not SPECIAL_BOSSES[entry.name] then BOSS_NAMES[entry.name] = true end
            else
                MOB_NAMES[entry.name] = true
            end
        end
    end
end

local function rootOf(model)
    local root=runtime.getRoot(model)
    if root then return root end
    local alternate=model and model:FindFirstChild("RootPart")
    return alternate and alternate:IsA("BasePart") and alternate or nil
end
local function alive(model)
    if not (model and model:IsA("Model") and model:IsDescendantOf(workspace)) then
        return false
    end
    local humanoid = model:FindFirstChildOfClass("Humanoid")
    return humanoid ~= nil and humanoid.Health > 0 and rootOf(model) ~= nil
        and not model:GetAttribute("Dead")
end

local function enemyModel(model)
    return alive(model) and not Players:GetPlayerFromCharacter(model) and (model:IsDescendantOf(enemies)
        or CollectionService:HasTag(model, "Enemy")
        or model:GetAttribute("CollisionGroup") == "Enemy")
end

local function spawnPool(part)
    local raw=part:GetAttribute("spawn_pool")
    if type(raw)~="string" or raw=="" then return {} end
    local ok,pool=pcall(function() return HttpService:JSONDecode(raw) end)
    if not ok or type(pool)~="table" then return {} end
    local names={}
    for key,value in pairs(pool) do
        if type(key)=="string" and key~="" and value~=false and value~=0 then
            names[key]=true
        elseif type(key)=="number" then
            local name=type(value)=="string" and value or type(value)=="table" and (value.name or value.Name)
            if type(name)=="string" and name~="" then names[name]=true end
        end
    end
    return names
end
local function spawnParts()
    local parts={}
    for _,part in ipairs(spawns:GetDescendants()) do
        if part:IsA("BasePart") and part:GetAttribute("spawn_pool")~=nil then table.insert(parts,part) end
    end
    return parts
end
local function spawnUsable(part)
    return part and part:IsA("BasePart") and part:IsDescendantOf(spawns)
        and part:GetAttribute("spawn_enabled")~=false and part:GetAttribute("Active")~=false
end
local function refreshCatalog()
    for _, model in ipairs(enemies:GetDescendants()) do
        if enemyModel(model) and not SPECIAL_BOSSES[model.Name] then
            local bossValue = model:FindFirstChild("Boss")
            if BOSS_NAMES[model.Name]
                or (bossValue and bossValue:IsA("BoolValue") and bossValue.Value) then
                BOSS_NAMES[model.Name] = true
                MOB_NAMES[model.Name] = nil
            else
                MOB_NAMES[model.Name] = true
            end
        end
    end
    for _, part in ipairs(spawnParts()) do
        if part:IsA("BasePart") then
            for name in pairs(spawnPool(part)) do
                if not (BOSS_NAMES[name] or SPECIAL_BOSSES[name]) then
                    MOB_NAMES[name] = true
                end
            end
        end
    end
    for name in pairs(MOB_NAMES) do
        if config.SelectedMobs[name] == nil then config.SelectedMobs[name] = false end
    end
    for name in pairs(BOSS_NAMES) do
        if config.SelectedBosses[name] == nil then config.SelectedBosses[name] = false end
    end
end
refreshCatalog()

if env.JungleFarmLaunchToken ~= token then return end
local Library,Toggles,Options = runtime.newUI()

local running = true
local paused = false
local target, targetKind
local connections = {}
local lastM1 = -math.huge
local lastEquip = -math.huge
local lastBook = -math.huge
local lastSkill = {}
local nextSkillIndex = 1
local grimoireEquipPauseUntil = -math.huge
local grimoireBusy = false
local lastKillAttempt = setmetatable({}, {__mode = "k"})
local nextCamp = 0
local campIndex = 0
local breakerRoot, breakerSavedVelocity

local function connect(signal, callback)
    local connection = signal:Connect(callback)
    table.insert(connections, connection)
    return connection
end

local function setNoRender(enabled)
    local ok, err = pcall(function() RunService:Set3dRenderingEnabled(not enabled) end)
    if ok then config.NoRender = enabled
    else warn("[JungleFarm] NoRender: " .. tostring(err)) end
end

local function restoreBreakerVelocity()
    if breakerRoot and breakerRoot.Parent and breakerSavedVelocity then
        breakerRoot.AssemblyLinearVelocity = breakerSavedVelocity
    end
    breakerRoot, breakerSavedVelocity = nil, nil
end

env.StopJungleFarm = function()
    if not running then return end
    running = false
    for _, connection in ipairs(connections) do connection:Disconnect() end
    restoreBreakerVelocity()
    if config.NoRender then setNoRender(false) end
    if Library and not Library.Unloaded then pcall(function() Library:Unload() end) end
    target, targetKind = nil, nil
    print("[JungleFarm] Stopped")
end

local function mobPriority(name)
    return math.clamp(tonumber(config.MobPriorities[name]) or 1, 1, 10)
end

local function classify(model)
    if not enemyModel(model) then return nil end
    local name = model.Name
    if name == "Prime Apex" and config.PrimeApexFarm then return "PrimeApex", 400 end
    if name == "Apex" and config.ApexFarm then return "Apex", 300 end
    if config.BossFarm and BOSS_NAMES[name] and config.SelectedBosses[name] then
        return "Boss", 200
    end
    if config.MobFarm and MOB_NAMES[name] and config.SelectedMobs[name] then
        return "Mob", mobPriority(name)
    end
    return nil
end

local function liveCandidates()
    local result, seen = {}, {}
    local function add(model)
        if model and not seen[model] and enemyModel(model) then
            seen[model] = true
            table.insert(result, model)
        end
    end
    for _, model in ipairs(enemies:GetDescendants()) do add(model) end
    for _, model in ipairs(CollectionService:GetTagged("Enemy")) do add(model) end
    return result
end

local function chooseTarget(fromPosition)
    local best, bestKind, bestRank, bestDistance
    for _, model in ipairs(liveCandidates()) do
        local kind, rank = classify(model)
        if kind then
            local distance = (rootOf(model).Position - fromPosition).Magnitude
            if not best or rank > bestRank
                or (rank == bestRank and distance < bestDistance) then
                best, bestKind, bestRank, bestDistance = model, kind, rank, distance
            end
        end
    end
    if target and targetKind then
        local kind, rank = classify(target)
        if kind and (not best or rank >= bestRank) then return target, kind end
    end
    return best, bestKind
end

local function mappedSpawns(name)
    local selected={}
    local override=config.MobSpawnOverrides[name]
    if override then
        for _,part in ipairs(spawns:GetDescendants()) do
            if spawnUsable(part) and (part:GetFullName()==override or part.Name==override) then
                table.insert(selected,part)
            end
        end
        if #selected>0 then return selected end
    end
    for _,part in ipairs(spawnParts()) do
        if spawnUsable(part) and spawnPool(part)[name] then table.insert(selected,part) end
    end
    table.sort(selected,function(a,b) return a:GetFullName()<b:GetFullName() end)
    return selected
end
local function campPoint(root)
    if os.clock() < nextCamp then return end
    local choices = {}
    if config.MobFarm then
        for name in pairs(MOB_NAMES) do
            if config.SelectedMobs[name] then
                for _, part in ipairs(mappedSpawns(name)) do
                    table.insert(choices, {Part = part, Name = name,
                        Priority = mobPriority(name)})
                end
            end
        end
    end
    if #choices == 0 and config.BossFarm and events then
        for name in pairs(BOSS_NAMES) do
            if config.SelectedBosses[name] then
                local folder = events:FindFirstChild(name)
                local node = folder and folder:FindFirstChild("Node1")
                if node and node:IsA("BasePart") then
                    table.insert(choices, {Part = node, Name = name, Priority = 1})
                end
            end
        end
    end
    table.sort(choices, function(a, b)
        if a.Priority ~= b.Priority then return a.Priority > b.Priority end
        if a.Name ~= b.Name then return a.Name < b.Name end
        return a.Part.Name < b.Part.Name
    end)
    if #choices == 0 then
        if config.MobFarm then
            warn("[JungleFarm] No available camp for selected mobs. Select mobs in Jungle Mobs; use Print mob routes to inspect streamed spawns.")
        end
        nextCamp = os.clock() + 15
        return
    end
    local topPriority = choices[1].Priority
    local top = {}
    for _, choice in ipairs(choices) do
        if choice.Priority == topPriority then table.insert(top, choice) end
    end
    campIndex = campIndex % #top + 1
    local choice = top[campIndex]
    if (root.Position - choice.Part.Position).Magnitude > 80 then
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
        root.CFrame = CFrame.new(choice.Part.Position + Vector3.new(0, 5, 0))
        print("[JungleFarm] Waiting at " .. choice.Part.Name .. " for " .. choice.Name)
    end
    nextCamp = os.clock() + 6
end

local function killThreshold(kind)
    if kind == "PrimeApex" then return config.PrimeApexKillThreshold end
    if kind == "Apex" then return config.ApexKillThreshold end
    if kind == "Boss" then return config.BossKillThreshold end
    return config.MobKillThreshold
end

local function tryLocalKill(model, kind)
    local function skip(reason) config.LastKillStatus=reason; return false end
    if not running or paused or not runtime.allowCombat() then return skip("Farm paused") end
    if not config.InstantKill then return skip("Instant kill is off") end
    if not model or model~=target or not enemyModel(model) then return skip("No live farm target") end
    if runtime.blocked(model) then return skip("Target is in a protected phase") end
    local humanoid=model:FindFirstChildOfClass("Humanoid")
    local root=rootOf(model)
    if not humanoid or not root or humanoid.MaxHealth<=0 then return skip("Target health unavailable") end
    local threshold=tonumber(killThreshold(kind))
    if not threshold or threshold~=threshold then return skip("Invalid HP threshold") end
    threshold=math.clamp(threshold,0,100)
    if humanoid.Health/humanoid.MaxHealth*100>threshold then return skip("Target is above its HP threshold") end
    if type(isnetworkowner)~="function" then return skip("Executor ownership check unavailable") end
    local checked,owned=pcall(isnetworkowner,root)
    if not checked or not owned then return skip("Client does not own target physics") end
    local record=lastKillAttempt[model]
    if record and record.Count>=3 then return skip("Three unconfirmed attempts; normal combat continues") end
    if record and os.clock()-record.Time<5 then return skip("Waiting before next attempt") end
    record={Count=record and record.Count+1 or 1,Time=os.clock()}
    lastKillAttempt[model]=record
    local previousHealth=humanoid.Health
    local ok,err=pcall(function()
        if config.InstantKillMethod=="Dead state" then humanoid:ChangeState(Enum.HumanoidStateType.Dead)
        else humanoid.Health=0 end
    end)
    if not ok then return skip("Attempt failed: "..tostring(err)) end
    config.LastKillStatus="Local attempt sent; server result unverified"
    warn("[JungleKill] "..model.Name..": "..config.LastKillStatus)
    task.delay(.5,function()
        if not running or not model.Parent or not humanoid.Parent or model:GetAttribute("Dead")==true then return end
        if humanoid.Health<=0 then
            pcall(function() humanoid.Health=previousHealth end)
            config.LastKillStatus="No replicated death marker; continuing normal combat"
        end
    end)
    return false -- A local state change is not proof of a server-confirmed kill.
end
local function availableSkills()
    local result = {}
    local gui = player:FindFirstChildOfClass("PlayerGui")
    local hud = gui and gui:FindFirstChild("HUD")
    local bar = hud and hud:FindFirstChild("WeaponSkills")
    local frame = bar and bar:FindFirstChild("Frame")
    if frame then
        for _, slot in ipairs(frame:GetChildren()) do
            local move = slot:FindFirstChild("MoveName")
            if slot:FindFirstChild("SkillButton") and move
                and move.Text == slot.Name and slot.Name ~= "SkillSlot" then
                table.insert(result, {Key = "Weapon:" .. slot.Name,
                    Name = slot.Name, Label = "Weapon | " .. slot.Name,
                    Kind = "Weapon", Order = slot.LayoutOrder})
            end
        end
    end
    local seen = {}
    for _, container in ipairs({player.Character, player:FindFirstChildOfClass("Backpack")}) do
        if container then
            for _, tool in ipairs(container:GetChildren()) do
                if tool:IsA("Tool") and not seen[tool.Name]
                    and (spellNames[tool.Name] or tool:GetAttribute("Type") == "Spell"
                        or tool:GetAttribute("ItemType") == "Spell") then
                    seen[tool.Name] = true
                    table.insert(result, {Key = "Grimoire:" .. tool.Name,
                        Name = tool.Name, Label = "Grimoire | " .. tool.Name,
                        Kind = "Grimoire", Order = 100 +
                            (tonumber(tool:GetAttribute("Index")) or 99), Tool = tool})
                end
            end
        end
    end
    table.sort(result, function(a, b)
        return a.Order == b.Order and a.Key < b.Key or a.Order < b.Order
    end)
    return result
end

local function ensureWeapon(character)
    if not config.AutoEquip or os.clock() - lastEquip < 1
        or os.clock() < grimoireEquipPauseUntil then return end
    if character:FindFirstChild("Weapon") or character:FindFirstChildOfClass("Tool") then return end
    lastEquip = os.clock()
    if CheckService then
        local ok, ready = pcall(function() return CheckService:Equip(character) end)
        if ok and not ready then return end
    end
    pcall(function() action:FireServer("EquipWeapon") end)
end

local function activateGrimoire(character, enemy, tool)
    grimoireBusy=true
    grimoireEquipPauseUntil=os.clock()+32
    local ok,confirmed=pcall(runtime.cast,character,enemy,tool,function() return running end)
    grimoireBusy=false
    grimoireEquipPauseUntil=os.clock()+.25
    if not ok then warn("[JungleSkill] "..tostring(confirmed)) end
    return ok and confirmed
end
local function trySkill(character)
    if not runtime.allowCombat() or not config.AutoSkill or grimoireBusy or not enemyModel(target) then return false end
    local status = character:FindFirstChild("Status")
    local cooldown = status and status:FindFirstChild("Cooldown")
    local casting = status and status:FindFirstChild("Casting")
    if not cooldown or (casting and casting.Value) then return false end
    local myRoot, enemyRoot = rootOf(character), rootOf(target)
    if not (myRoot and enemyRoot)
        or (myRoot.Position - enemyRoot.Position).Magnitude > 18 then return false end
    local skills = availableSkills()
    if #skills == 0 then return false end
    for offset = 0, #skills - 1 do
        local index = (nextSkillIndex + offset - 1) % #skills + 1
        local skill = skills[index]
        if config.SelectedSkills[skill.Key]
            and not cooldown:FindFirstChild(skill.Name)
            and os.clock() - (lastSkill[skill.Key] or -math.huge) >= 1.5 then
            if skill.Kind == "Weapon" and character:FindFirstChild("Weapon") then
                local ok, ready = pcall(function()
                    return not CheckService or CheckService:Skill(character, skill.Name)
                end)
                if ok and ready then
                    lastSkill[skill.Key] = os.clock()
                    nextSkillIndex = index % #skills + 1
                    pcall(function()
                        action:FireServer("Toolbar", {WeaponSkill = skill.Name})
                    end)
                    return true
                end
            elseif skill.Kind == "Grimoire" then
                local book = status:FindFirstChild("Grimoire")
                if book and book:IsA("BoolValue") and not book.Value then
                    if os.clock() - lastBook >= 3 then
                        lastBook = os.clock()
                        grimoireEquipPauseUntil = os.clock() + 2.5
                        pcall(function() action:FireServer("Book") end)
                        return true
                    end
                elseif skill.Tool and skill.Tool.Enabled then
                    if activateGrimoire(character, target, skill.Tool) then
                        lastSkill[skill.Key] = os.clock()
                        nextSkillIndex = index % #skills + 1
                        return true
                    end
                end
            end
        end
    end
    return false
end

Library.MainColor = Color3.fromHex("1b2b34")
Library.BackgroundColor = Color3.fromHex("16232a")
Library.AccentColor = Color3.fromHex("6699cc")
Library.OutlineColor = Color3.fromHex("343d46")
Library.FontColor = Color3.fromHex("d8dee9")
local window = Library:CreateWindow({
    Title = "Jungle Farm", Center = true, AutoShow = true,
    Size = UDim2.fromOffset(640, 550), MenuFadeTime = 0.2,
})
runtime.telemetry=function() return {Model=target,Skills=config.AutoSkill and "Enabled" or "Off"} end
local mobTab = window:AddTab("Jungle Mobs")
local bossTab = window:AddTab("Boss Farm")
local combatTab = window:AddTab("Combat")
local teleportTab = window:AddTab("Teleport")
local uiTab = window:AddTab("UI")
local mobBox = mobTab:AddLeftGroupbox("Mobs")
local mobSettings = mobTab:AddRightGroupbox("Priority and Spawn")
local bossBox = bossTab:AddLeftGroupbox("Bosses")
local specialBox = bossTab:AddRightGroupbox("Apex")
local attackBox = combatTab:AddLeftGroupbox("Attack")
local attachBox = combatTab:AddLeftGroupbox("Attach")
local skillBox = combatTab:AddRightGroupbox("Skills and Stats")
local breakerBox = combatTab:AddRightGroupbox("AI Breaker")
local placeBox = teleportTab:AddLeftGroupbox("Places")
local npcBox = teleportTab:AddRightGroupbox("NPCs")
local mobTeleportBox = teleportTab:AddRightGroupbox("Mobs and Bosses")
local teleportBox = teleportTab:AddLeftGroupbox("Farm Control")
local uiBox = uiTab:AddLeftGroupbox("Window")

local function sortedNames(set)
    local names = {}
    for name in pairs(set) do table.insert(names, name) end
    table.sort(names)
    return names
end

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
        originalSetValues(dropdown, allValues)
        originalSetValue(dropdown, value)
        applySearch()
    end
    local searchId = "Search" .. dropdownId
    groupbox:AddInput(searchId, {
        Text = "Search " .. label, Default = "",
        Placeholder = "Type to filter...", Finished = false,
    })
    Options[searchId]:OnChanged(function(value)
        query = tostring(value or "")
        applySearch()
    end)
end

breakerBox:AddToggle("JungleAIBreaker", {
    Text = "AI Breaker", Default = config.AIBreaker,
})
Toggles.JungleAIBreaker:OnChanged(function(v)
    config.AIBreaker = v
    if not v then restoreBreakerVelocity() end
end)
breakerBox:AddDropdown("JungleAIBreakerType", {
    Text = "Breaker type", Values = {"OPassive", "Passive", "Circular", "Aggressive"},
    Default = config.AIBreakerType,
})
addDropdownSearch(breakerBox, "JungleAIBreakerType", "breaker types")
Options.JungleAIBreakerType:OnChanged(function(v) config.AIBreakerType = v end)

local function enableJungleCombat()
    paused=false; runtime.paused=false; nextCamp=0
    runtime.config.AutoM1=true; config.AutoAttach=true
    if runtime.sharedToggles and runtime.sharedToggles.HubM1 then runtime.sharedToggles.HubM1:SetValue(true) end
    if Toggles.JungleAutoAttach then Toggles.JungleAutoAttach:SetValue(true) end
end
local initialMobs, initialBosses = sortedNames(MOB_NAMES), sortedNames(BOSS_NAMES)
mobBox:AddToggle("JungleMobFarm", {Text = "Auto Mob Farm", Default = config.MobFarm})
Toggles.JungleMobFarm:OnChanged(function(v) config.MobFarm = v; target = nil; if v then enableJungleCombat() end end)
mobBox:AddDropdown("JungleMobTargets", {
    Text = "Mobs to farm", Values = initialMobs,
    Default = config.SelectedMobs, Multi = true, AllowNull = true,
})
addDropdownSearch(mobBox, "JungleMobTargets", "mobs")
local refreshingMobs = false
Options.JungleMobTargets:OnChanged(function(selected)
    if refreshingMobs or type(selected) ~= "table" then return end
    for name in pairs(MOB_NAMES) do config.SelectedMobs[name] = selected[name] == true end
    target = nil
end)
mobBox:AddButton("Select all", function()
    local selected = {}
    for name in pairs(MOB_NAMES) do selected[name] = true end
    Options.JungleMobTargets:SetValue(selected)
end)
mobBox:AddButton("Deselect all", function()
    Options.JungleMobTargets:SetValue({})
end)
mobBox:AddLabel("Selected bosses interrupt mobs, then mob farming resumes.", true)

mobSettings:AddDropdown("JungleMobSettingTarget", {
    Text = "Configure mob", Values = initialMobs, Default = initialMobs[1],
    AllowNull = true,
})
addDropdownSearch(mobSettings, "JungleMobSettingTarget", "mob settings")
mobSettings:AddSlider("JungleMobPriority", {
    Text = "Priority", Default = 1, Min = 1, Max = 10, Rounding = 0,
})
local spawnChoices = {"Auto"}
for _, part in ipairs(spawnParts()) do
    if part:IsA("BasePart") then table.insert(spawnChoices, part:GetFullName()) end
end
table.sort(spawnChoices, function(a, b)
    if a == "Auto" then return true end
    if b == "Auto" then return false end
    return a < b
end)
mobSettings:AddDropdown("JungleMobSpawn", {
    Text = "Spawn for this mob", Values = spawnChoices, Default = "Auto",
})
addDropdownSearch(mobSettings, "JungleMobSpawn", "spawns")
mobSettings:AddLabel("Auto reads each Jungle spawn's spawn_pool.", true)
local syncingMobSettings = false
local function refreshMobSettings()
    local name = Options.JungleMobSettingTarget.Value
    if not name then return end
    syncingMobSettings = true
    Options.JungleMobPriority:SetValue(mobPriority(name))
    local override = config.MobSpawnOverrides[name]
    Options.JungleMobSpawn:SetValue(override and table.find(spawnChoices, override)
        and override or "Auto")
    syncingMobSettings = false
end
Options.JungleMobSettingTarget:OnChanged(refreshMobSettings)
Options.JungleMobPriority:OnChanged(function(value)
    if syncingMobSettings then return end
    local name = Options.JungleMobSettingTarget.Value
    if name then config.MobPriorities[name] = value end
end)
Options.JungleMobSpawn:OnChanged(function(value)
    if syncingMobSettings then return end
    local name = Options.JungleMobSettingTarget.Value
    if name then
        config.MobSpawnOverrides[name] = value ~= "Auto" and value or nil
    end
end)
refreshMobSettings()

bossBox:AddToggle("JungleBossFarm", {Text = "Auto Boss Farm", Default = config.BossFarm})
Toggles.JungleBossFarm:OnChanged(function(v) config.BossFarm = v; target = nil; if v then enableJungleCombat() end end)
bossBox:AddDropdown("JungleBossTargets", {
    Text = "Bosses to farm", Values = initialBosses,
    Default = config.SelectedBosses, Multi = true, AllowNull = true,
})
addDropdownSearch(bossBox, "JungleBossTargets", "bosses")
local refreshingBosses = false
Options.JungleBossTargets:OnChanged(function(selected)
    if refreshingBosses or type(selected) ~= "table" then return end
    for name in pairs(BOSS_NAMES) do config.SelectedBosses[name] = selected[name] == true end
    target = nil
end)
bossBox:AddButton("Select all", function()
    local selected = {}
    for name in pairs(BOSS_NAMES) do selected[name] = true end
    Options.JungleBossTargets:SetValue(selected)
end)
bossBox:AddButton("Deselect all", function()
    Options.JungleBossTargets:SetValue({})
end)
bossBox:AddLabel("Live selected bosses outrank every regular mob.", true)

specialBox:AddToggle("JungleApexFarm", {Text = "Apex Farm", Default = config.ApexFarm})
Toggles.JungleApexFarm:OnChanged(function(v) config.ApexFarm = v; target = nil; if v then enableJungleCombat() end end)
specialBox:AddToggle("JunglePrimeApexFarm", {
    Text = "Prime Apex Farm", Default = config.PrimeApexFarm,
})
Toggles.JunglePrimeApexFarm:OnChanged(function(v)
    config.PrimeApexFarm = v; target = nil; if v then enableJungleCombat() end
end)
specialBox:AddLabel("Prime Apex > Apex > selected bosses > mobs.", true)

attackBox:AddToggle("JungleInstantKill", {
    Text = "Instant kill attempt", Default = config.InstantKill,
})
Toggles.JungleInstantKill:OnChanged(function(v) config.InstantKill = v end)
attackBox:AddDropdown("JungleKillMethod",{Text="Instant kill method",Values={"Local health","Dead state"},Default=config.InstantKillMethod or "Local health"})
Options.JungleKillMethod:OnChanged(function(value) config.InstantKillMethod=value end)
attackBox:AddButton("Print instant-kill status",function()
    print("[JungleKill] "..tostring(config.LastKillStatus or "Enable the toggle and acquire a selected farm target"))
end)
attackBox:AddLabel("Uses the target type's HP threshold and requires client physics ownership. Local attempts do not guarantee a server kill.",true)
local function addThreshold(groupbox, id, label, field)
    groupbox:AddSlider(id, {
        Text = label, Default = config[field],
        Min = 0, Max = 100, Rounding = 0, Suffix = "%",
    })
    Options[id]:OnChanged(function(value) config[field] = value end)
    groupbox:AddInput(id .. "Text", {
        Text = label .. " %", Default = tostring(config[field]),
        Numeric = true, Finished = true,
    })
    Options[id .. "Text"]:OnChanged(function(value)
        local number = tonumber(value)
        if number then
            Options[id]:SetValue(math.clamp(math.floor(number + 0.5), 0, 100))
        end
    end)
end
addThreshold(attackBox, "JungleMobKill", "Mob HP threshold", "MobKillThreshold")
addThreshold(attackBox, "JungleBossKill", "Boss HP threshold", "BossKillThreshold")
addThreshold(attackBox, "JungleApexKill", "Apex HP threshold", "ApexKillThreshold")
addThreshold(attackBox, "JunglePrimeKill", "Prime HP threshold", "PrimeApexKillThreshold")
attackBox:AddLabel("Local attempt needs network ownership; confirm server reward.", true)

attachBox:AddToggle("JungleAutoAttach", {Text = "Auto Attach", Default = config.AutoAttach})
Toggles.JungleAutoAttach:OnChanged(function(v) config.AutoAttach = v end)
for _, setting in ipairs({
    {"JungleDistance", "Back distance", "FollowDistance", 1, 80},
    {"JungleXOffset", "Side offset", "XOffset", -80, 80},
    {"JungleYOffset", "Height offset", "YOffset", -80, 80},
}) do
    attachBox:AddSlider(setting[1], {
        Text = setting[2], Default = config[setting[3]],
        Min = setting[4], Max = setting[5], Rounding = 1,
    })
    Options[setting[1]]:OnChanged(function(v) config[setting[3]] = v end)
end

skillBox:AddToggle("JungleAutoEquip", {
    Text = "Auto equip weapon", Default = config.AutoEquip,
})
Toggles.JungleAutoEquip:OnChanged(function(v) config.AutoEquip = v end)
skillBox:AddToggle("JungleAutoSkill", {Text = "Auto Skill", Default = config.AutoSkill})
Toggles.JungleAutoSkill:OnChanged(function(v) config.AutoSkill = v end)
skillBox:AddDropdown("JungleSkillTargets", {
    Text = "Equipped skills", Values = {}, Default = {},
    Multi = true, AllowNull = true,
})
addDropdownSearch(skillBox, "JungleSkillTargets", "skills")
local refreshingSkills = true
Options.JungleSkillTargets:OnChanged(function(selected)
    if refreshingSkills or type(selected) ~= "table" then return end
    for _, skill in ipairs(availableSkills()) do
        config.SelectedSkills[skill.Key] = selected[skill.Label] == true
    end
end)
skillBox:AddDropdown("JungleStat", {
    Text = "Stat", Values = {"STR", "DEX", "INT", "CON"},
    Default = config.Stat,
})
addDropdownSearch(skillBox, "JungleStat", "stats")
Options.JungleStat:OnChanged(function(v) config.Stat = v end)
skillBox:AddToggle("JungleAutoStat", {Text = "Auto Stat", Default = config.AutoStat})
Toggles.JungleAutoStat:OnChanged(function(v) config.AutoStat = v end)

local map = workspace:FindFirstChild("Map")
local island = map and map:FindFirstChild("Jungle_Island")
local placeNames = {
    "Docks", "HunterCamp", "HotSprings", "Temple", "DungeonEntrance",
    "Volcano", "JaguarBossArea", "Jungle_Village", "CrocodileVillage",
}
local validPlaces = {}
for _, name in ipairs(placeNames) do
    if island and island:FindFirstChild(name) then table.insert(validPlaces, name) end
end
table.sort(validPlaces)

local function positionOf(instance)
    if not instance then return nil end
    if instance:IsA("BasePart") then return instance.Position end
    if instance:IsA("Model") then return instance:GetPivot().Position end
    if instance:IsA("Folder") then
        local minimum, maximum
        for _, part in ipairs(instance:GetDescendants()) do
            if part:IsA("BasePart") then
                local position = part.Position
                minimum = minimum and Vector3.new(
                    math.min(minimum.X, position.X),
                    math.min(minimum.Y, position.Y),
                    math.min(minimum.Z, position.Z)) or position
                maximum = maximum and Vector3.new(
                    math.max(maximum.X, position.X),
                    math.max(maximum.Y, position.Y),
                    math.max(maximum.Z, position.Z)) or position
            end
        end
        return minimum and (minimum + maximum) * 0.5 or nil
    end
    return nil
end

local function manualTeleport(position, face, label)
    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local root = rootOf(character)
    if not (position and humanoid and humanoid.Health > 0 and root) then
        warn("[JungleFarm] Teleport unavailable")
        return
    end
    paused = true
    target, targetKind = nil, nil
    root.AssemblyLinearVelocity = Vector3.zero
    root.AssemblyAngularVelocity = Vector3.zero
    local destination = position + Vector3.new(0, 6, 0)
    root.CFrame = face and CFrame.lookAt(destination, face) or CFrame.new(destination)
    print("[JungleFarm] Teleported to " .. label .. "; farm paused")
end

placeBox:AddDropdown("JunglePlaceTeleport", {
    Text = "Place", Values = validPlaces, Default = validPlaces[1],
    AllowNull = true,
})
addDropdownSearch(placeBox, "JunglePlaceTeleport", "places")
placeBox:AddButton("Teleport to Place", function()
    local name = Options.JunglePlaceTeleport.Value
    local landmark = name and island and island:FindFirstChild(name)
    if landmark then
        manualTeleport(positionOf(landmark), nil, name)
    else
        warn("[JungleFarm] Selected place is unavailable")
    end
end)

local npcByLabel = {}
local npcSignature = ""
npcBox:AddDropdown("JungleNPCTeleport", {
    Text = "NPC", Values = {}, AllowNull = true,
})
addDropdownSearch(npcBox, "JungleNPCTeleport", "NPCs")
local function refreshNPCs()
    local found = {}
    local function scan(container)
        if not container then return end
        for _, model in ipairs(container:GetDescendants()) do
            if model:IsA("Model") and model:FindFirstChildOfClass("Humanoid")
                and rootOf(model) then
                table.insert(found, model)
            end
        end
    end
    scan(interactions)
    scan(entities:FindFirstChild("Villagers"))
    table.sort(found, function(a, b)
        if a.Name ~= b.Name then return a.Name < b.Name end
        return a:GetFullName() < b:GetFullName()
    end)
    local labels, lookup, duplicates = {}, {}, {}
    for _, model in ipairs(found) do
        local parent = model.Parent and model.Parent.Name or "Workspace"
        local base = model.Name .. " (" .. parent .. ")"
        duplicates[base] = (duplicates[base] or 0) + 1
        local label = base .. " #" .. duplicates[base]
        table.insert(labels, label)
        lookup[label] = model
    end
    npcByLabel = lookup
    local signature = table.concat(labels, "\n")
    if signature == npcSignature then return end
    npcSignature = signature
    local selected = Options.JungleNPCTeleport.Value
    Options.JungleNPCTeleport:SetValues(labels)
    if #labels > 0 then
        Options.JungleNPCTeleport:SetValue(table.find(labels, selected)
            and selected or labels[1])
    end
end
npcBox:AddButton("Teleport to NPC", function()
    local model = npcByLabel[Options.JungleNPCTeleport.Value]
    local root = model and model:IsDescendantOf(workspace) and rootOf(model)
    if root then
        local destination = (root.CFrame * CFrame.new(0, 0, 5)).Position
        manualTeleport(destination - Vector3.new(0, 6, 0), root.Position, model.Name)
    else
        refreshNPCs()
        warn("[JungleFarm] Selected NPC is unavailable")
    end
end)

mobTeleportBox:AddDropdown("JungleMobTeleport", {
    Text = "Mob or boss", Values = {}, AllowNull = true,
})
addDropdownSearch(mobTeleportBox, "JungleMobTeleport", "mobs / bosses")
mobTeleportBox:AddButton("Teleport to Mob", function()
    local name = Options.JungleMobTeleport.Value
    if not name then return end
    local myRoot = rootOf(player.Character)
    local best, bestDistance
    for _, model in ipairs(liveCandidates()) do
        if model.Name == name then
            local enemyRoot = rootOf(model)
            local distance = myRoot and (enemyRoot.Position - myRoot.Position).Magnitude
                or 0
            if not best or distance < bestDistance then
                best, bestDistance = enemyRoot, distance
            end
        end
    end
    if best then
        local destination = (best.CFrame * CFrame.new(0, 0, 5)).Position
        manualTeleport(destination - Vector3.new(0, 6, 0), best.Position, name)
        return
    end
    local mapped = mappedSpawns(name)
    if #mapped > 0 then
        manualTeleport(mapped[1].Position, nil, name .. " spawn")
        return
    end
    local folder = events and events:FindFirstChild(name)
    local marker = folder and folder:FindFirstChild("Node1")
    if marker and marker:IsA("BasePart") then
        manualTeleport(marker.Position, nil, name .. " marker")
    else
        warn("[JungleFarm] No live target or mapped spawn for " .. name)
    end
end)

teleportBox:AddLabel("Manual teleports pause farming until resumed.", true)
teleportBox:AddButton("Resume Farming", function()
    paused = false
    print("[JungleFarm] Farming resumed")
end)

uiBox:AddToggle("JungleNoRender", {Text = "NoRender", Default = config.NoRender})
Toggles.JungleNoRender:OnChanged(setNoRender)
uiBox:AddLabel("Show / hide key"):AddKeyPicker("JungleMenuKey", {
    Default = config.MenuKey, NoUI = true, Mode = "Toggle",
    Text = "Toggle menu",
})
Library.ToggleKeybind = Options.JungleMenuKey
Options.JungleMenuKey:OnChanged(function(v) config.MenuKey = v end)
uiBox:AddButton("Hide window", function() Library:Toggle() end)
uiBox:AddButton("Stop farm", function() env.StopJungleFarm() end)
Library:OnUnload(function()
    Library.Unloaded = true
    if running then env.StopJungleFarm() end
end)

if config.NoRender then setNoRender(true) end
connect(player.Idled, function()
    pcall(function()
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.zero)
    end)
end)

local radiusElapsed = 0
connect(RunService.Heartbeat, function(dt)
    radiusElapsed += dt
    if radiusElapsed < 0.05 then return end
    radiusElapsed = 0
    if type(sethiddenproperty) == "function" then
        pcall(sethiddenproperty, player, "MaxSimulationRadius", config.SimulationRadius)
        pcall(sethiddenproperty, player, "SimulationRadius", config.SimulationRadius)
    end
end)

connect(RunService.PostSimulation, function()
    if not running or paused or not config.AutoAttach or not enemyModel(target) then
        return
    end
    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local myRoot, enemyRoot = rootOf(character), rootOf(target)
    if not (humanoid and humanoid.Health > 0 and myRoot and enemyRoot) then return end
    local targetPosition = (enemyRoot.CFrame * CFrame.new(
        math.clamp(tonumber(config.XOffset) or 0, -80, 80),
        math.clamp(tonumber(config.YOffset) or 0, -80, 80),
        math.clamp(tonumber(config.FollowDistance) or 5, 1, 80)
    )).Position
    myRoot.AssemblyLinearVelocity = Vector3.zero
    myRoot.AssemblyAngularVelocity = Vector3.zero
    local facing = Vector3.new(enemyRoot.Position.X, targetPosition.Y,
        enemyRoot.Position.Z)
    if (facing - targetPosition).Magnitude > 0.01 then
        myRoot.CFrame = CFrame.lookAt(targetPosition, facing)
    else
        myRoot.CFrame = CFrame.new(targetPosition)
    end
end)

connect(RunService.PreSimulation, function()
    if breakerRoot then restoreBreakerVelocity() end
end)
connect(RunService.Heartbeat, function()
    if breakerRoot then restoreBreakerVelocity() end
    if not running or paused or not config.AIBreaker
        or not config.AutoAttach or not enemyModel(target) then return end
    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local root, enemyRoot = rootOf(character), rootOf(target)
    if not (humanoid and humanoid.Health > 0 and root and enemyRoot)
        or root.Anchored then return end
    local velocity
    if config.AIBreakerType == "Passive" then
        velocity = Vector3.new(16, -1e5, -16)
    elseif config.AIBreakerType == "Circular" then
        local now = os.clock()
        velocity = Vector3.new(math.cos(now) * 20, -1e4, math.sin(now) * 20)
    elseif config.AIBreakerType == "Aggressive" then
        velocity = Vector3.new(0, -9e9, 0) - (enemyRoot.Position - root.Position)
    else
        velocity = Vector3.new(16, -750, -16)
    end
    breakerRoot = root
    breakerSavedVelocity = root.AssemblyLinearVelocity
    root.AssemblyLinearVelocity = velocity
end)
connect(RunService.PreRender, function()
    if breakerRoot then restoreBreakerVelocity() end
end)

task.spawn(function()
    while running do
        if not runtime.paused and config.AutoStat and fetch then
            local character = player.Character
            local status = character and character:FindFirstChild("Status")
            local changes = status and status:FindFirstChild("Changes")
            local stat = changes and changes:FindFirstChild(config.Stat)
            local cap = stat and tonumber(stat:GetAttribute("Max"))
            if stat and (not cap or stat.Value < cap) then
                local ok, data = pcall(function() return fetch:InvokeServer() end)
                local points = ok and type(data) == "table"
                    and type(data.CoreData) == "table"
                    and tonumber(data.CoreData.StatPoints) or 0
                if points >= 1 and running and not runtime.paused and config.AutoStat then
                    pcall(function()
                        action:FireServer("StatDump", {Stat = config.Stat, Dump = 1})
                    end)
                end
            end
        end
        task.wait(1.25)
    end
end)

local mobSignature, bossSignature, skillSignature, teleportSignature = "", "", "", ""
local function refreshDropdowns()
    local choices={"Auto"}
    for _,part in ipairs(spawnParts()) do table.insert(choices,part:GetFullName()) end
    table.sort(choices,function(a,b) if a==b then return false end; if a=="Auto" then return true end; if b=="Auto" then return false end; return a<b end)
    if table.concat(choices,"\n")~=table.concat(spawnChoices,"\n") then
        spawnChoices=choices
        Options.JungleMobSpawn:SetValues(choices)
        refreshMobSettings()
    end
    refreshCatalog()
    local mobNames = sortedNames(MOB_NAMES)
    local signature = table.concat(mobNames, "\n")
    if signature ~= mobSignature then
        mobSignature = signature
        local selected = {}
        for _, name in ipairs(mobNames) do
            if config.SelectedMobs[name] then selected[name] = true end
        end
        refreshingMobs = true
        Options.JungleMobTargets:SetValues(mobNames)
        Options.JungleMobTargets:SetValue(selected)
        refreshingMobs = false
        Options.JungleMobSettingTarget:SetValues(mobNames)
        if not table.find(mobNames, Options.JungleMobSettingTarget.Value) then
            Options.JungleMobSettingTarget:SetValue(mobNames[1])
        end
        refreshMobSettings()
    end
    local bossNames = sortedNames(BOSS_NAMES)
    signature = table.concat(bossNames, "\n")
    if signature ~= bossSignature then
        bossSignature = signature
        local selected = {}
        for _, name in ipairs(bossNames) do
            if config.SelectedBosses[name] then selected[name] = true end
        end
        refreshingBosses = true
        Options.JungleBossTargets:SetValues(bossNames)
        Options.JungleBossTargets:SetValue(selected)
        refreshingBosses = false
    end
    local names = {}
    for name in pairs(MOB_NAMES) do names[name] = true end
    for name in pairs(BOSS_NAMES) do names[name] = true end
    names.Apex, names["Prime Apex"] = true, true
    local teleportNames = sortedNames(names)
    signature = table.concat(teleportNames, "\n")
    if signature ~= teleportSignature then
        teleportSignature = signature
        local selected = Options.JungleMobTeleport.Value
        Options.JungleMobTeleport:SetValues(teleportNames)
        if #teleportNames > 0 then
            Options.JungleMobTeleport:SetValue(
                table.find(teleportNames, selected) and selected or teleportNames[1])
        end
    end
    local skills = availableSkills()
    local labels, selectedSkills = {}, {}
    for _, skill in ipairs(skills) do
        table.insert(labels, skill.Label)
        if config.SelectedSkills[skill.Key] then selectedSkills[skill.Label] = true end
    end
    signature = table.concat(labels, "\n")
    if signature ~= skillSignature then
        skillSignature = signature
        refreshingSkills = true
        Options.JungleSkillTargets:SetValues(labels)
        Options.JungleSkillTargets:SetValue(selectedSkills)
        refreshingSkills = false
    end
end
mobBox:AddButton("Refresh mobs and routes",function() refreshDropdowns() end)
mobBox:AddButton("Print mob routes",function()
    refreshCatalog()
    for _,name in ipairs(sortedNames(MOB_NAMES)) do
        local routes=mappedSpawns(name)
        print("[JungleRoute] "..name.." | selected="..tostring(config.SelectedMobs[name]==true).." | camps="..#routes)
        for _,part in ipairs(routes) do print("  "..part:GetFullName()) end
    end
end)
refreshDropdowns()
refreshNPCs()
task.spawn(function()
    while running do
        refreshDropdowns()
        refreshNPCs()
        task.wait(1)
    end
end)

print("[JungleFarm] Started; live spawn pools and boss markers loaded")
task.spawn(function()
    while running do
        local character = player.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        local myRoot = rootOf(character)
        if not (humanoid and humanoid.Health > 0 and myRoot) then
            target, targetKind = nil, nil
            task.wait(0.5)
        elseif paused or not runtime.allowCombat() then
            target, targetKind = nil, nil
            task.wait(0.25)
        else
            local nextTarget, nextKind = chooseTarget(myRoot.Position)
            if nextTarget ~= target or nextKind ~= targetKind then
                target, targetKind = nextTarget, nextKind
                if target then
                    print("[JungleFarm] " .. targetKind .. " target: " .. target.Name)
                end
            end
            if not target then
                campPoint(myRoot)
                task.wait(0.25)
            else
                ensureWeapon(character)
                if not enemyModel(target) then
                    target, targetKind = nil, nil
                    task.wait(0.1)
                elseif CollectionService:HasTag(target, "Untargetable")
                    or target:GetAttribute("FightPause") == true then
                    task.wait(0.2)
                elseif tryLocalKill(target, targetKind) then
                    target, targetKind = nil, nil
                    task.wait(0.65)
                else
                    if runtime.allowAttack(character) and os.clock() - lastM1 >= runtime.config.AttackInterval then
                        local ok, err = pcall(function()
                            action:FireServer("M1", {password = "Spirit"})
                        end)
                        if ok then lastM1 = os.clock()
                        else warn("[JungleFarm] M1: " .. tostring(err)) end
                    else
                        trySkill(character)
                    end
                    task.wait(0.1)
                end
            end
        end
    end
end)
end
runtime.profiles["Arcane Dungeon"]=function()
-- Arcane spirit dungeon farm. Separate from vampire-farm and Project Rain src.
-- The saved dungeon has no VampireSoldierSpawn. Its Aetherion boss is an
-- Enemy-tagged model cloned directly into workspace after the spirit prompt.
-- The old static SealCatalog does not list Aetherion, so this script discovers
-- tagged enemies at runtime and waits for the boss's vulnerable phase.

local env = getgenv()
if type(env.StopArcaneDungeonFarm) == "function" then
    pcall(env.StopArcaneDungeonFarm)
end

-- Discard config left by older versions; this run starts from defaults.
-- Keep settings for this area between hub switches.
local config = type(env.CloverArcaneConfig)=="table" and env.CloverArcaneConfig or {}
env.CloverArcaneConfig=config
local defaults = {
    Enabled = true,
    AutoStartBoss = true,
    AutoAttach = true,
    AutoEquip = true,
    AutoSkill = false,
    AutoStat = false,
    Stat = "STR",
    NoRender = false,
    InstantKill = false,
    KillThreshold = 5,
    FollowDistance = 7,
    XOffset = 0,
    YOffset = 0,
    PhaseHover = true,
    HoverDistance = 320,
    HoverHeight = 400,
    SimRadius = 3000,
    MenuKey = "RightShift",
    SelectedEnemies = {},
    SelectedSkills = {},
}
for key, value in pairs(defaults) do
    if config[key] == nil then config[key] = value end
end
if type(config.SelectedEnemies) ~= "table" then config.SelectedEnemies = {} end
if type(config.SelectedSkills) ~= "table" then config.SelectedSkills = {} end
if type(config.MenuKey) ~= "string" or not Enum.KeyCode[config.MenuKey] then
    config.MenuKey = "RightShift"
end
config.KillThreshold = math.clamp(tonumber(config.KillThreshold) or 5, 0, 100)
config.FollowDistance = math.clamp(tonumber(config.FollowDistance) or 7, 1, 80)
config.XOffset = math.clamp(tonumber(config.XOffset) or 0, -80, 80)
config.YOffset = math.clamp(tonumber(config.YOffset) or 0, -80, 80)
config.HoverDistance = math.clamp(tonumber(config.HoverDistance) or 320, 80, 800)
config.HoverHeight = math.clamp(tonumber(config.HoverHeight) or 400, 100, 1000)

local token = {}
env.ArcaneDungeonLaunchToken = token
if not game:IsLoaded() then game.Loaded:Wait() end
if env.ArcaneDungeonLaunchToken ~= token then return end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local VirtualUser = game:GetService("VirtualUser")
local player = Players.LocalPlayer
local replicated = game:GetService("ReplicatedStorage")
local entities = workspace:WaitForChild("Entities", 15)
local enemies = entities and entities:WaitForChild("Enemies", 15)
local package = replicated:WaitForChild("ReplicatedPackage", 15)
local remotes = package and package:WaitForChild("Remotes", 15)
local action = remotes and remotes:WaitForChild("action", 15)
local fetch = remotes and remotes:FindFirstChild("fetch")
if not (enemies and action) then
    error("[ArcaneDungeon] Missing Entities.Enemies or ReplicatedPackage.Remotes.action")
end

local checkModule = package:FindFirstChild("CheckService", true)
local checkOk, CheckService = pcall(function()
    return checkModule and require(checkModule)
end)
if not checkOk then CheckService = nil end

local spellNames = {}
local spellFolder = package:FindFirstChild("Spell", true)
if spellFolder then
    for _, item in ipairs(spellFolder:GetDescendants()) do
        if item:IsA("ModuleScript") then spellNames[item.Name] = true end
    end
end

if env.ArcaneDungeonLaunchToken ~= token then return end
local Library,Toggles,Options = runtime.newUI()

local running = true
local target
local connections = {}
local nextPrompt = 0
local lastPromptAt = -math.huge
local nextDialogue = 0
local nextWarn = 0
local lastM1 = -math.huge
local lastEquip = -math.huge
local lastSkill = {}
local lastBook = -math.huge
local nextSkill = 1
local knownEnemies = {Aetherion = true}
local bossSeen = false
local bossFinished = false
local lastKillAttempt = setmetatable({}, {__mode = "k"})

local function connect(signal, callback)
    local connection = signal:Connect(callback)
    table.insert(connections, connection)
    return connection
end

local function setNoRender(enabled)
    local ok, err = pcall(function() RunService:Set3dRenderingEnabled(not enabled) end)
    if ok then config.NoRender = enabled
    else warn("[ArcaneDungeon] NoRender: " .. tostring(err)) end
end

env.StopArcaneDungeonFarm = function()
    if not running then return end
    running = false
    for _, connection in ipairs(connections) do connection:Disconnect() end
    if config.NoRender then setNoRender(false) end
    if Library and not Library.Unloaded then
        pcall(function() Library:Unload() end)
    end
    target = nil
    print("[ArcaneDungeon] Stopped")
end

local function rootOf(model)
    return model and (model:FindFirstChild("HumanoidRootPart")
        or model:FindFirstChild("RootPart") or model.PrimaryPart)
end

local function alive(model)
    if not (model and model:IsA("Model") and model:IsDescendantOf(workspace)) then
        return false
    end
    local humanoid = model:FindFirstChildOfClass("Humanoid")
    return humanoid ~= nil and humanoid.Health > 0 and rootOf(model) ~= nil
end

local function isEnemy(model)
    if not alive(model) or model == player.Character then return false end
    if model:GetAttribute("Dead") or model:GetAttribute("HasKneeled")
        or model:GetAttribute("FightPause") then return false end
    return model.Parent == enemies or CollectionService:HasTag(model, "Enemy")
        or model.Name == "Aetherion"
end

local function isBoss(model)
    return model and (model.Name == "Aetherion"
        or (model:FindFirstChild("Boss") and model.Boss:IsA("BoolValue")
            and model.Boss.Value))
end

local function availableSkills()
    local result = {}
    local gui = player:FindFirstChildOfClass("PlayerGui")
    local hud = gui and gui:FindFirstChild("HUD")
    local bar = hud and hud:FindFirstChild("WeaponSkills")
    local frame = bar and bar:FindFirstChild("Frame")
    if frame then
        for _, slot in ipairs(frame:GetChildren()) do
            local move = slot:FindFirstChild("MoveName")
            if slot:FindFirstChild("SkillButton") and move
                and move.Text == slot.Name and slot.Name ~= "SkillSlot" then
                table.insert(result, {
                    Key = "Weapon:" .. slot.Name, Name = slot.Name,
                    Label = "Weapon | " .. slot.Name, Kind = "Weapon",
                    Order = slot.LayoutOrder,
                })
            end
        end
    end
    local seen = {}
    for _, container in ipairs({player.Character, player:FindFirstChildOfClass("Backpack")}) do
        if container then
            for _, tool in ipairs(container:GetChildren()) do
                if tool:IsA("Tool") and not seen[tool.Name]
                    and (spellNames[tool.Name] or tool:GetAttribute("Type") == "Spell"
                        or tool:GetAttribute("ItemType") == "Spell") then
                    seen[tool.Name] = true
                    table.insert(result, {
                        Key = "Grimoire:" .. tool.Name, Name = tool.Name,
                        Label = "Grimoire | " .. tool.Name, Kind = "Grimoire",
                        Order = 100 + (tonumber(tool:GetAttribute("Index")) or 99),
                        Tool = tool,
                    })
                end
            end
        end
    end
    table.sort(result, function(a, b)
        return a.Order == b.Order and a.Key < b.Key or a.Order < b.Order
    end)
    return result
end

local function equipWeapon(character)
    if not config.AutoEquip or os.clock() - lastEquip < 1 then return end
    if character:FindFirstChild("Weapon") or character:FindFirstChildOfClass("Tool") then return end
    lastEquip = os.clock()
    if CheckService then
        local ok, ready = pcall(function() return CheckService:Equip(character) end)
        if ok and not ready then return end
    end
    pcall(function() action:FireServer("EquipWeapon") end)
end

local function useSkill(character)
    if not config.AutoSkill or not runtime.allowCombat() or not alive(target) or runtime.blocked(target) then return false end
    local status=character:FindFirstChild("Status")
    local cooldown=status and status:FindFirstChild("Cooldown")
    local casting=status and status:FindFirstChild("Casting")
    if not cooldown or (casting and casting.Value) then return false end
    local root,enemyRoot=rootOf(character),rootOf(target)
    if not root or not enemyRoot or (root.Position-enemyRoot.Position).Magnitude>18 then return false end
    local skills=availableSkills()
    for offset=0,#skills-1 do
        local index=(nextSkill+offset-1)%#skills+1
        local skill=skills[index]
        if config.SelectedSkills[skill.Key] and not cooldown:FindFirstChild(skill.Name)
            and os.clock()-(lastSkill[skill.Key] or -math.huge)>=1.5 then
            if skill.Kind=="Weapon" and character:FindFirstChild("Weapon") then
                local ok,ready=pcall(function() return not CheckService or CheckService:Skill(character,skill.Name) end)
                if ok and ready then
                    lastSkill[skill.Key]=os.clock(); nextSkill=index%#skills+1
                    action:FireServer("Toolbar",{WeaponSkill=skill.Name}); return true
                end
            elseif skill.Kind=="Grimoire" then
                local book=status:FindFirstChild("Grimoire")
                if book and book:IsA("BoolValue") and not book.Value then
                    if os.clock()-lastBook>=3 then lastBook=os.clock(); action:FireServer("Book"); return true end
                elseif skill.Tool and skill.Tool.Enabled then
                    lastSkill[skill.Key]=os.clock()
                    local ok,confirmed=pcall(runtime.cast,character,target,skill.Tool,function() return running end)
                    if ok and confirmed then nextSkill=index%#skills+1; return true end
                    if not ok then warn("[ArcaneSkill] "..tostring(confirmed)) end
                end
            end
        end
    end
    return false
end
local function tryLocalKill(model, force)
    return false, "Use M1 and skills; local health writes are not server-confirmed kills"
end
local function candidates()
    local found, seen = {}, {}
    local function add(model)
        if model and not seen[model] and isEnemy(model) then
            seen[model] = true
            knownEnemies[model.Name] = true
            table.insert(found, model)
        end
    end
    for _, model in ipairs(enemies:GetChildren()) do add(model) end
    for _, model in ipairs(CollectionService:GetTagged("Enemy")) do add(model) end
    add(workspace:FindFirstChild("Aetherion"))
    return found
end

local function chooseTarget(myPosition)
    local best, score = nil, -math.huge
    for _, model in ipairs(candidates()) do
        if isBoss(model) or config.SelectedEnemies[model.Name] ~= false then
            local root = rootOf(model)
            local distance = (root.Position - myPosition).Magnitude
            local rank = (isBoss(model) and 1000000 or 0) - distance
            if rank > score then best, score = model, rank end
        end
    end
    return best
end

local function startPrompt()
    local map = workspace:FindFirstChild("Map")
    local realm = map and map:FindFirstChild("Arcanespiritrealm")
    local statue = realm and realm:FindFirstChild("AetherWarGolem")
    local part = statue and (statue.PrimaryPart or statue:FindFirstChild("RootPart"))
    local prompt = part and part:FindFirstChildOfClass("ProximityPrompt")
    return part, prompt
end

local function dialogueOpen()
    local gui = player:FindFirstChildOfClass("PlayerGui")
    local dialogue = gui and gui:FindFirstChild("Dialogue")
    return dialogue and dialogue:IsA("ScreenGui") and dialogue.Enabled
end

local function hoverPosition(anchor, distance)
    local offset = (anchor.CFrame * CFrame.new(0, 0, distance)).Position
    local altitude = anchor.Position.Y + config.HoverHeight
    local extras = package:FindFirstChild("Extra_Assets")
    local spirits = extras and extras:FindFirstChild("SpiritStorage")
    local arcane = spirits and spirits:FindFirstChild("ArcaneSpiritStorage")
    local hitboxes = arcane and arcane:FindFirstChild("MoveHitboxes")
    if hitboxes then
        for _, part in ipairs(hitboxes:GetChildren()) do
            if part:IsA("BasePart") then
                altitude = math.max(altitude,
                    part.Position.Y + part.Size.Y * 0.5 + 50)
            end
        end
    end
    return Vector3.new(offset.X, altitude, offset.Z)
end

local function moveFloating(myRoot, anchor, distance)
    local position = hoverPosition(anchor, distance)
    local face = Vector3.new(anchor.Position.X, position.Y, anchor.Position.Z)
    myRoot.AssemblyLinearVelocity = Vector3.zero
    myRoot.AssemblyAngularVelocity = Vector3.zero
    if (face - position).Magnitude > 0.01 then
        myRoot.CFrame = CFrame.lookAt(position, face)
    else
        myRoot.CFrame = CFrame.new(position)
    end
end

local function tryDialogueChoice()
    if os.clock() < nextDialogue then return end
    local gui = player:FindFirstChildOfClass("PlayerGui")
    local dialogue = gui and gui:FindFirstChild("Dialogue")
    if not (dialogue and dialogue:IsA("ScreenGui") and dialogue.Enabled) then return end
    for _, item in ipairs(dialogue:GetDescendants()) do
        if (item:IsA("TextButton") or item:IsA("TextLabel")) then
            local label = item.Text:lower()
            if (label:find("fight", 1, true) or label:find("challenge", 1, true)
                or label:find("battle", 1, true))
                and not (label:find("training", 1, true)
                    or label:find("leave", 1, true)) then
                local button = item:IsA("GuiButton") and item
                    or item:FindFirstAncestorWhichIsA("GuiButton")
                if button and button.Visible then
                    local fired = pcall(function()
                        local vim = game:GetService("VirtualInputManager")
                        local point = button.AbsolutePosition + button.AbsoluteSize / 2
                        vim:SendMouseButtonEvent(point.X, point.Y, 0, true, game, 0)
                        vim:SendMouseButtonEvent(point.X, point.Y, 0, false, game, 0)
                    end)
                    if not fired and type(firesignal) == "function" then
                        fired = pcall(firesignal, button.Activated)
                        if not fired then
                            fired = pcall(firesignal, button.MouseButton1Click)
                        end
                    end
                    if fired then
                        nextDialogue = os.clock() + 5
                        print("[ArcaneDungeon] Selected fight dialogue: " .. item.Text)
                    end
                    return
                end
            end
        end
    end
end

local function tryStartBoss(myRoot)
    if not config.AutoStartBoss or bossFinished then return end
    if dialogueOpen() or os.clock() < nextPrompt then return end
    local part, prompt = startPrompt()
    if not (part and prompt and prompt.Enabled) then return end
    local distance = (myRoot.Position - part.Position).Magnitude
    if distance > math.max(5, prompt.MaxActivationDistance - 2) then
        local destination = (part.CFrame * CFrame.new(0, 0, 5)).Position
        myRoot.AssemblyLinearVelocity = Vector3.zero
        myRoot.CFrame = CFrame.lookAt(destination, part.Position)
        return
    end
    nextPrompt = os.clock() + 5
    if type(fireproximityprompt) == "function" then
        local ok, err = pcall(fireproximityprompt, prompt)
        if ok then
            lastPromptAt = os.clock()
            print("[ArcaneDungeon] Triggered AetherWarGolem prompt")
        else
            warn("[ArcaneDungeon] Prompt failed: " .. tostring(err))
        end
    elseif os.clock() >= nextWarn then
        nextWarn = os.clock() + 15
        warn("[ArcaneDungeon] fireproximityprompt unavailable; interact with the golem manually")
    end
end

Library.MainColor = Color3.fromHex("1b2b34")
Library.BackgroundColor = Color3.fromHex("16232a")
Library.AccentColor = Color3.fromHex("6699cc")
Library.OutlineColor = Color3.fromHex("343d46")
Library.FontColor = Color3.fromHex("d8dee9")
local window = Library:CreateWindow({
    Title = "Arcane Dungeon Farm", Center = true, AutoShow = true,
    Size = UDim2.fromOffset(600, 520), MenuFadeTime = 0.2,
})
runtime.telemetry=function() return {Model=target,Skills=config.AutoSkill and "Enabled" or "Off"} end
local farmTab = window:AddTab("Arcane Dungeon")
local combatTab = window:AddTab("Combat")
local uiTab = window:AddTab("UI")
local farmBox = farmTab:AddLeftGroupbox("Progression")
local enemyBox = farmTab:AddRightGroupbox("Targets")
local attachBox = combatTab:AddLeftGroupbox("Attach")
local skillBox = combatTab:AddRightGroupbox("Skills and Stats")
local uiBox = uiTab:AddLeftGroupbox("Window")

farmBox:AddToggle("DungeonEnabled", {Text = "Farm enemies", Default = config.Enabled})
Toggles.DungeonEnabled:OnChanged(function(v) config.Enabled = v end)
farmBox:AddToggle("DungeonAutoStart", {Text = "Start Aetherion fight", Default = config.AutoStartBoss})
Toggles.DungeonAutoStart:OnChanged(function(v) config.AutoStartBoss = v end)
farmBox:AddButton("Trigger fight now", function()
    nextPrompt = 0
    local myRoot = rootOf(player.Character)
    if myRoot then tryStartBoss(myRoot) end
end)
farmBox:AddLabel("Aetherion has priority; normal enemies resume afterward.", true)
farmBox:AddLabel("The boss is untargetable during attack phases.", true)
farmBox:AddToggle("DungeonInstantKill", {
    Text = "Finish with normal combat", Default = config.InstantKill,
})
Toggles.DungeonInstantKill:OnChanged(function(v) config.InstantKill = v end)
farmBox:AddSlider("DungeonKillThreshold", {
    Text = "Kill HP threshold", Default = config.KillThreshold,
    Min = 0, Max = 100, Rounding = 0, Suffix = "%",
})
Options.DungeonKillThreshold:OnChanged(function(v) config.KillThreshold = v end)
farmBox:AddInput("DungeonKillThresholdText", {
    Text = "Threshold %", Default = tostring(config.KillThreshold),
    Numeric = true, Finished = true,
})
Options.DungeonKillThresholdText:OnChanged(function(v)
    local n = tonumber(v)
    if n then Options.DungeonKillThreshold:SetValue(math.clamp(math.floor(n + 0.5), 0, 100)) end
end)
farmBox:AddButton("Instant kill current boss", function()
    if not (target and target.Name == "Aetherion") then
        warn("[ArcaneDungeon] No live Aetherion target")
        return
    end
    if CollectionService:HasTag(target, "Untargetable") then
        warn("[ArcaneDungeon] Aetherion is in an untargetable phase")
        return
    end
    local ok, reason = tryLocalKill(target, true)
    if not ok then warn("[ArcaneDungeon] Instant kill attempt: " .. tostring(reason)) end
end)
farmBox:AddLabel("Local kill requires network ownership; check server reward.", true)

enemyBox:AddDropdown("DungeonEnemyTargets", {
    Text = "Normal enemies", Values = {}, Multi = true, Default = {},
})
local refreshingEnemies = false
Options.DungeonEnemyTargets:OnChanged(function(selected)
    if refreshingEnemies or type(selected) ~= "table" then return end
    for name in pairs(knownEnemies) do
        if name ~= "Aetherion" then config.SelectedEnemies[name] = selected[name] == true end
    end
end)
enemyBox:AddButton("Select all", function()
    local selected = {}
    for name in pairs(knownEnemies) do
        if name ~= "Aetherion" then selected[name] = true end
    end
    Options.DungeonEnemyTargets:SetValue(selected)
end)
enemyBox:AddButton("Deselect all", function()
    Options.DungeonEnemyTargets:SetValue({})
end)
enemyBox:AddLabel("New enemy names appear as they spawn.", true)

attachBox:AddToggle("DungeonAutoAttach", {Text = "Auto Attach", Default = config.AutoAttach})
Toggles.DungeonAutoAttach:OnChanged(function(v) config.AutoAttach = v end)
attachBox:AddSlider("DungeonDistance", {
    Text = "Back distance", Default = config.FollowDistance,
    Min = 1, Max = 80, Rounding = 1, Suffix = " studs",
})
Options.DungeonDistance:OnChanged(function(v) config.FollowDistance = v end)
attachBox:AddSlider("DungeonXOffset", {
    Text = "Side offset", Default = config.XOffset,
    Min = -80, Max = 80, Rounding = 1,
})
Options.DungeonXOffset:OnChanged(function(v) config.XOffset = v end)
attachBox:AddSlider("DungeonYOffset", {
    Text = "Height offset", Default = config.YOffset,
    Min = -80, Max = 80, Rounding = 1,
})
Options.DungeonYOffset:OnChanged(function(v) config.YOffset = v end)
attachBox:AddToggle("DungeonPhaseHover", {
    Text = "Float during dialogue / invulnerability",
    Default = config.PhaseHover,
})
Toggles.DungeonPhaseHover:OnChanged(function(v) config.PhaseHover = v end)
attachBox:AddSlider("DungeonHoverDistance", {
    Text = "Boss wait distance", Default = config.HoverDistance,
    Min = 80, Max = 800, Rounding = 0, Suffix = " studs",
})
Options.DungeonHoverDistance:OnChanged(function(v) config.HoverDistance = v end)
attachBox:AddSlider("DungeonHoverHeight", {
    Text = "Air height", Default = config.HoverHeight,
    Min = 100, Max = 1000, Rounding = 0, Suffix = " studs",
})
Options.DungeonHoverHeight:OnChanged(function(v) config.HoverHeight = v end)

skillBox:AddToggle("DungeonAutoEquip", {Text = "Auto equip weapon", Default = config.AutoEquip})
Toggles.DungeonAutoEquip:OnChanged(function(v) config.AutoEquip = v end)
skillBox:AddToggle("DungeonAutoSkill", {Text = "Auto Skill", Default = config.AutoSkill})
Toggles.DungeonAutoSkill:OnChanged(function(v) config.AutoSkill = v end)
skillBox:AddDropdown("DungeonSkillTargets", {
    Text = "Equipped skills", Values = {}, Multi = true, Default = {},
})
local refreshingSkills = true
Options.DungeonSkillTargets:OnChanged(function(selected)
    if refreshingSkills or type(selected) ~= "table" then return end
    for _, skill in ipairs(availableSkills()) do
        config.SelectedSkills[skill.Key] = selected[skill.Label] == true
    end
end)
skillBox:AddDropdown("DungeonStat", {
    Text = "Stat", Values = {"STR", "DEX", "INT", "CON"}, Default = config.Stat,
})
Options.DungeonStat:OnChanged(function(v) config.Stat = v end)
skillBox:AddToggle("DungeonAutoStat", {Text = "Auto Stat", Default = config.AutoStat})
Toggles.DungeonAutoStat:OnChanged(function(v) config.AutoStat = v end)

uiBox:AddToggle("DungeonNoRender", {Text = "NoRender", Default = config.NoRender})
Toggles.DungeonNoRender:OnChanged(setNoRender)
uiBox:AddLabel("Show / hide key"):AddKeyPicker("DungeonMenuKey", {
    Default = config.MenuKey, NoUI = true, Mode = "Toggle",
    Text = "Toggle menu",
})
Library.ToggleKeybind = Options.DungeonMenuKey
Options.DungeonMenuKey:OnChanged(function(value) config.MenuKey = value end)
uiBox:AddButton("Hide window", function() Library:Toggle() end)
uiBox:AddButton("Stop farm", function() env.StopArcaneDungeonFarm() end)
Library:OnUnload(function()
    Library.Unloaded = true
    if running then env.StopArcaneDungeonFarm() end
end)

if config.NoRender then setNoRender(true) end
connect(player.Idled, function()
    pcall(function()
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.zero)
    end)
end)

local radiusElapsed = 0
connect(RunService.Heartbeat, function(dt)
    radiusElapsed += dt
    if radiusElapsed < 0.05 then return end
    radiusElapsed = 0
    if type(sethiddenproperty) == "function" then
        pcall(sethiddenproperty, player, "MaxSimulationRadius", config.SimRadius)
        pcall(sethiddenproperty, player, "SimulationRadius", config.SimRadius)
    end
end)

connect(RunService.PostSimulation, function()
    if not running or not runtime.allowCombat() or not config.Enabled then return end
    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local myRoot = rootOf(character)
    if not (humanoid and humanoid.Health > 0 and myRoot) then return end

    if config.PhaseHover then
        if dialogueOpen() or os.clock() - lastPromptAt < 4.5 then
            local statuePart = startPrompt()
            if statuePart then
                moveFloating(myRoot, statuePart, 0)
                return
            end
        end
        if alive(target) and target.Name == "Aetherion"
            and CollectionService:HasTag(target, "Untargetable") then
            moveFloating(myRoot, rootOf(target), config.HoverDistance)
            return
        end
    end

    if not config.AutoAttach or not alive(target) then return end
    local enemyRoot = rootOf(target)
    if not enemyRoot then return end
    local position = (enemyRoot.CFrame * CFrame.new(
        math.clamp(tonumber(config.XOffset) or 0, -80, 80),
        math.clamp(tonumber(config.YOffset) or 0, -80, 80),
        math.clamp(tonumber(config.FollowDistance) or 7, 1, 80)
    )).Position
    myRoot.AssemblyLinearVelocity = Vector3.zero
    myRoot.AssemblyAngularVelocity = Vector3.zero
    local face = Vector3.new(enemyRoot.Position.X, position.Y, enemyRoot.Position.Z)
    if (face - position).Magnitude > 0.01 then
        myRoot.CFrame = CFrame.lookAt(position, face)
    else
        myRoot.CFrame = CFrame.new(position)
    end
end)

task.spawn(function()
    while running do
        if not runtime.paused and config.AutoStat and fetch then
            local character = player.Character
            local status = character and character:FindFirstChild("Status")
            local changes = status and status:FindFirstChild("Changes")
            local stat = changes and changes:FindFirstChild(config.Stat)
            local cap = stat and tonumber(stat:GetAttribute("Max"))
            if stat and (not cap or stat.Value < cap) then
                local ok, data = pcall(function() return fetch:InvokeServer() end)
                local points = ok and type(data) == "table"
                    and type(data.CoreData) == "table"
                    and tonumber(data.CoreData.StatPoints) or 0
                if points >= 1 and running and not runtime.paused and config.AutoStat then
                    pcall(function()
                        action:FireServer("StatDump", {Stat = config.Stat, Dump = 1})
                    end)
                end
            end
        end
        task.wait(1.25)
    end
end)

local enemySignature, skillSignature = "", ""
task.spawn(function()
    while running do
        candidates()
        local names = {}
        local selected = {}
        for name in pairs(knownEnemies) do
            if name ~= "Aetherion" then
                table.insert(names, name)
                if config.SelectedEnemies[name] ~= false then selected[name] = true end
            end
        end
        table.sort(names)
        local signature = table.concat(names, "\n")
        if signature ~= enemySignature then
            enemySignature = signature
            refreshingEnemies = true
            Options.DungeonEnemyTargets:SetValues(names)
            Options.DungeonEnemyTargets:SetValue(selected)
            refreshingEnemies = false
        end
        local skills = availableSkills()
        local labels, selectedSkills = {}, {}
        for _, skill in ipairs(skills) do
            table.insert(labels, skill.Label)
            if config.SelectedSkills[skill.Key] then selectedSkills[skill.Label] = true end
        end
        signature = table.concat(labels, "\n")
        if signature ~= skillSignature then
            skillSignature = signature
            refreshingSkills = true
            Options.DungeonSkillTargets:SetValues(labels)
            Options.DungeonSkillTargets:SetValue(selectedSkills)
            refreshingSkills = false
        end
        task.wait(0.5)
    end
end)

print("[ArcaneDungeon] Started; waiting for dynamic enemies / Aetherion")
task.spawn(function()
    while running do
        local character = player.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        local myRoot = rootOf(character)
        if not (humanoid and humanoid.Health > 0 and myRoot) then
            target = nil
            task.wait(0.5)
        elseif not config.Enabled or not runtime.allowCombat() then
            target = nil
            task.wait(0.25)
        else
            local chosen = chooseTarget(myRoot.Position)
            if chosen ~= target then
                target = chosen
                if target then
                    print("[ArcaneDungeon] Target: " .. target.Name)
                end
            end
            if target then
                if target.Name == "Aetherion" then bossSeen = true end
                if target:GetAttribute("Dead") or target:GetAttribute("HasKneeled") then
                    if target.Name == "Aetherion" then bossFinished = true end
                    target = nil
                else
                    equipWeapon(character)
                    local invulnerable = CollectionService:HasTag(target, "Untargetable")
                        or target:GetAttribute("FightPause") == true
                    if not invulnerable then
                        if not tryLocalKill(target) then
                            if runtime.allowAttack(character) and os.clock() - lastM1 >= runtime.config.AttackInterval then
                                local ok, err = pcall(function()
                                    action:FireServer("M1", {password = "Spirit"})
                                end)
                                if ok then lastM1 = os.clock()
                                else warn("[ArcaneDungeon] M1: " .. tostring(err)) end
                            else
                                useSkill(character)
                            end
                        end
                    end
                end
            else
                if bossSeen and not workspace:FindFirstChild("Aetherion") then
                    bossFinished = true
                end
                tryStartBoss(myRoot)
                tryDialogueChoice()
            end
            task.wait(0.1)
        end
    end
end)
end
runtime.profiles.Explorer=runtime.explorer
env.StopCloverHub=function()
    runtime.switchSerial+=1
    runtime.stopProfiles()
end
if type(readfile)=="function" and type(isfile)=="function" then
    local ok,data=pcall(function()
        local path=runtime.settingsPath
        if not isfile(path) then path="CloverHub-settings.json" end
        if not isfile(path) then return nil end
        return game:GetService("HttpService"):JSONDecode(readfile(path))
    end)
    if ok and type(data)=="table" and (data.UserId==nil or data.UserId==player.UserId) then
        if type(data.Controls)=="table" then runtime.controls=data.Controls end
        if type(data.Hub)=="table" then for key,value in pairs(data.Hub) do
            if runtime.config[key]~=nil and type(value)==type(runtime.config[key]) then runtime.config[key]=value end
        end end
        if type(data.World)=="table" then env.VampireFarmConfig=data.World end
        if type(data.Jungle)=="table" then env.CloverJungleConfig=data.Jungle end
        if type(data.Arcane)=="table" then env.CloverArcaneConfig=data.Arcane end
    end
end
if not game:IsLoaded() then game.Loaded:Wait() end
-- Explicit user preference: every execution starts idle, regardless of saved farm toggles.
runtime.config.AutoM1=false; runtime.config.AutoCollect=false; runtime.config.AutoQuestPrompt=false
runtime.config.AutoReset=false; runtime.config.AutoStaminaReset=false
for _,name in ipairs({"VampireFarmConfig","CloverJungleConfig","CloverArcaneConfig"}) do
    local cfg=type(env[name])=="table" and env[name] or {}; env[name]=cfg
    for _,key in ipairs({"Enabled","BossFarmEnabled","ApexFarmEnabled","PrimeApexFarmEnabled","GolemFarmEnabled",
        "AutoChestLootEnabled","AutoAttachEnabled","AutoResetEnabled","MobFarm","BossFarm","ApexFarm","PrimeApexFarm",
        "KrakenFarmEnabled","OreFarmEnabled","AutoSkillResetAtLowMana","AutoInvitePlayersEnabled","AutoAcceptPartyInvitesEnabled","AutoStatEnabled","AutoStat","KaldrisAirDodgeEnabled","AutoStartBoss","AutoAttach","AutoSkill","AutoSkillEnabled","AIBreakerEnabled","AIBreaker"}) do cfg[key]=false end
    if name=="VampireFarmConfig" then cfg.FarmMode="Off" end
end
for key in pairs(runtime.controls) do
    if key:find("Farm",1,true) or key:find("Auto",1,true) or key:find("HubM1",1,true)
        or key:find("HubCollect",1,true) or key:find("HubReset",1,true) or key:find("HubStaminaReset",1,true)
        or key:find("DungeonEnabled",1,true) or key:find("ExplorerEnabled",1,true) or key:find("KaldrisCombat",1,true) or key:find("KaldrisAirDodge",1,true) then
        runtime.controls[key]=nil
    end
end
local detected=runtime.detect()
print("[CloverHub] Detected profile: "..detected.." | PlaceId "..game.PlaceId)
runtime.switch(detected)
runtime.requestSave()
