local Players = game:GetService('Players')
local UIS = game:GetService('UserInputService')
local TweenService = game:GetService('TweenService')
local RunService = game:GetService('RunService')
local HttpService = game:GetService('HttpService')
local TextService = game:GetService('TextService')
local CoreGui = game:GetService('CoreGui')

local function C(r,g,b) return Color3.fromRGB(r,g,b) end
local P = {
    panel = C(38,38,38),     
    code = C(29,29,29),
    selected = C(54,54,54),
    accent = C(245,245,245),
    ink = C(20,20,20),
    text = C(245,245,245),
    muted = C(153,153,153),
    edge = C(125,125,125),
    green = C(125,223,163),
    red = C(240,126,126),
    blue = C(126,189,248),
    orange = C(231,183,130),
}
local E = (type(getgenv) == 'function' and getgenv()) or _G
if type(E) == 'table' and type(E.basaltImproved) == 'table' then
    pcall(function() E.basaltImproved.destroy() end)
end

local connections = {}
local alive = true
local function connect(signal, callback)
    local c = signal:Connect(callback)
    table.insert(connections, c)
    return c
end
local function node(class, parent, props)
    local o = Instance.new(class)
    if props then
        for k,v in pairs(props) do o[k] = v end
    end
    o.Parent = parent
    return o
end
local function round(parent, pixels)
    return node('UICorner', parent, {CornerRadius = UDim.new(0,pixels)})
end
local function stroke(parent, color, width, trans)
    return node('UIStroke', parent, {
        Color=color or P.edge, Thickness=width or 1,
        Transparency=trans or 0.8,
        ApplyStrokeMode=Enum.ApplyStrokeMode.Border
    })
end
local function tween(o, duration, props)
    local tw = TweenService:Create(o, TweenInfo.new(duration or .16, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), props)
    tw:Play()
    return tw
end
local function frame(parent, name, pos, size, color, rad, transparency)
    local f = node('Frame', parent, {
        Name=name, BorderSizePixel=0, Position=pos, Size=size,
        BackgroundColor3=color or P.panel,
        BackgroundTransparency=transparency or 0,
    })
    if rad then round(f,rad) end
    return f
end
local function text(parent,name,str,pos,size,sz,col,font,align)
    return node('TextLabel',parent,{
        Name=name, BackgroundTransparency=1, BorderSizePixel=0,
        Text=str or '', Position=pos, Size=size,
        TextColor3=col or P.text, TextSize=sz or 13,
        Font=font or Enum.Font.Gotham,
        TextXAlignment=align or Enum.TextXAlignment.Left,
        TextYAlignment=Enum.TextYAlignment.Center,
        TextTruncate=Enum.TextTruncate.AtEnd,
    })
end
local function btn(parent,name,str,pos,size,color,rad)
    local b=node('TextButton',parent,{
        Name=name, Text=str or '', Position=pos, Size=size,
        AutoButtonColor=false, BackgroundColor3=color or P.selected,
        BorderSizePixel=0, TextColor3=P.text, TextSize=12,
        Font=Enum.Font.GothamMedium, TextTruncate=Enum.TextTruncate.AtEnd,
    })
    if rad then round(b,rad) end
    local prePressTransparency = 0
    connect(b.MouseButton1Down,function()
        prePressTransparency = b.BackgroundTransparency
        tween(b,.11,{BackgroundTransparency=math.min(1,prePressTransparency+.16)})
    end)
    connect(b.MouseButton1Up,function()
        tween(b,.14,{BackgroundTransparency=prePressTransparency})
    end)
    return b
end
local function bar(parent,x1,y1,x2,y2,color,thickness)
    local dx,dy=x2-x1,y2-y1
    local length=math.sqrt(dx*dx+dy*dy)
    local f=frame(parent,'Segment',UDim2.fromOffset((x1+x2)/2,(y1+y2)/2),
        UDim2.fromOffset(length,thickness or 1.8),color,thickness or 1.8)
    f.AnchorPoint=Vector2.new(.5,.5)
    f.Rotation=math.deg(math.atan2(dy,dx))
    return f
end
-- Basalt renders monochrome line icons. These are native Frame strokes,
-- not emoji or network images, so they render consistently on mobile.
local function icon(parent,which,at,size,color)
    local holder=node('Frame',parent,{Name='Icon',Position=at,Size=UDim2.fromOffset(size,size),BackgroundTransparency=1})
    local s=size/24
    local function line(a,b,c,d,w) return bar(holder,a*s,b*s,c*s,d*s,color,(w or 2)*s) end
    local function rect(x,y,w,h,r)
        local f=frame(holder,'Glyph',UDim2.fromOffset(x*s,y*s),UDim2.fromOffset(w*s,h*s),color,r and r*s or nil)
        return f
    end
    if which=='home' then
        line(4,11,12,5);line(12,5,20,11);line(6,10,6,20);line(18,10,18,20);line(6,20,18,20);line(10,20,10,14);line(14,14,14,20)
    elseif which=='terminal' then
        line(5,7,10,12);line(10,12,5,17);line(12,18,19,18)
    elseif which=='cloud' then
        line(5,17,18,17);line(5,17,3,14);line(3,14,5,11);line(5,11,8,11);line(8,11,10,7);line(10,7,15,6);line(15,6,19,9);line(19,9,19,11);line(19,11,22,14);line(22,14,18,17)
    elseif which=='sparkles' then
        line(11,3,11,10);line(8,6,14,6);line(11,10,8,6);line(11,10,14,6);line(17,13,17,21);line(13,17,21,17);line(17,13,13,17);line(17,13,21,17)
    elseif which=='settings' then
        local m=rect(5,5,14,14,7);m.BackgroundTransparency=1;stroke(m,color,2*s,0)
        local n=rect(10,10,4,4,4);n.BackgroundTransparency=1;stroke(n,color,2*s,0)
        line(12,1,12,4);line(12,20,12,23);line(1,12,4,12);line(20,12,23,12)
    elseif which=='close' then
        line(5,5,19,19);line(19,5,5,19)
    elseif which=='play' then
        line(7,5,7,19);line(7,5,18,12);line(18,12,7,19)
    elseif which=='copy' then
        line(8,4,20,4);line(20,4,20,17);line(20,17,8,17);line(8,17,8,4)
        line(5,7,4,7);line(4,7,4,21);line(4,21,16,21);line(16,21,16,20)
    elseif which=='paste' then
        line(5,7,5,21);line(5,21,19,21);line(19,21,19,7);line(9,4,15,4)
        line(9,4,9,8);line(15,4,15,8);line(9,8,15,8)
    elseif which=='trash' then
        line(5,7,19,7);line(7,8,8,21);line(8,21,16,21);line(16,21,17,8)
        line(9,4,15,4);line(11,11,11,17);line(14,11,14,17)
    elseif which=='add' then
        line(12,4,12,20);line(4,12,20,12)
    elseif which=='bolt' then
        line(14,2,6,13);line(6,13,12,13);line(12,13,10,22);line(10,22,19,10);line(19,10,13,10);line(13,10,14,2)
    elseif which=='search' then
        local q=rect(4,4,13,13,8);q.BackgroundTransparency=1;stroke(q,color,1.8*s,0);line(16,16,21,21)
    elseif which=='code' then
        line(9,7,4,12);line(4,12,9,17);line(15,7,20,12);line(20,12,15,17)
    elseif which=='check' then
        line(4,12,10,18);line(10,18,20,6)
    else
        local q=rect(8,8,8,8,2);q.BackgroundTransparency=1;stroke(q,color,1.8*s,0)
    end
    return holder
end

local parentGui=CoreGui
if type(gethui)=='function' then
    local ok,h=pcall(gethui)
    if ok and typeof(h)=='Instance' then parentGui=h end
end
local Interface=node('ScreenGui',parentGui,{
    Name='Basalt_Improved',ResetOnSpawn=false,IgnoreGuiInset=true,DisplayOrder=71,
    ZIndexBehavior=Enum.ZIndexBehavior.Sibling,
})
local DimGui=node('ScreenGui',parentGui,{
    Name='Basalt_Improved_Backdrop',ResetOnSpawn=false,IgnoreGuiInset=true,DisplayOrder=70,
    ZIndexBehavior=Enum.ZIndexBehavior.Sibling,
})
local Root=frame(Interface,'Root',UDim2.new(),UDim2.fromScale(1,1),P.panel,nil,1)
local dimmer=btn(DimGui,'Backdrop','',UDim2.new(),UDim2.fromScale(1,1),C(0,0,0))
dimmer.Visible=false;dimmer.BackgroundTransparency=.55

local Panel=frame(Root,'Panel',UDim2.fromOffset(16,16),UDim2.fromOffset(536,310),P.panel,nil,1)
Panel.Active=true
local Scale=node('UIScale',Panel,{Scale=1})
local Shadow=frame(Panel,'Shadow',UDim2.fromOffset(0,5),UDim2.fromOffset(536,310),C(0,0,0),22,.67)
Shadow.ZIndex=0
local Glass=frame(Panel,'Glass',UDim2.fromOffset(0,77),UDim2.fromOffset(536,233),P.panel,17,.08)
Glass.ZIndex=2;Glass.ClipsDescendants=true
stroke(Glass,C(120,120,120),1,.86)
local Dock=frame(Panel,'Dock',UDim2.fromOffset(248,0),UDim2.fromOffset(192,40),P.panel,24,.08)
Dock.ZIndex=10;stroke(Dock,P.edge,1,.88)
local Selection=frame(Dock,'Selection',UDim2.fromOffset(3,3),UDim2.fromOffset(34,34),P.accent,17)
Selection.ZIndex=11
local toggle=btn(Root,'Toggle','',UDim2.new(.5,-24,.17,0),UDim2.fromOffset(48,48),P.panel,24)
toggle.ZIndex=40;toggle.Visible=false;toggle.BackgroundTransparency=.08
stroke(toggle,P.edge,1,.64)
local toggleIcon=icon(toggle,'code',UDim2.fromOffset(12,12),24,P.text);toggleIcon.ZIndex=41
local close=btn(Panel,'Close','',UDim2.fromOffset(139,0),UDim2.fromOffset(40,40),P.panel,22)
close.ZIndex=15;close.BackgroundTransparency=.08
icon(close,'close',UDim2.fromOffset(11,11),18,P.text)
local logo=text(Panel,'Brand','BASALT',UDim2.fromOffset(13,5),UDim2.fromOffset(118,32),14,P.text,Enum.Font.GothamBold)
local ver=text(Panel,'Version','/ EDITOR',UDim2.fromOffset(14,33),UDim2.fromOffset(115,16),9,P.muted,Enum.Font.GothamMedium)
local statusDot=frame(Panel,'Status',UDim2.fromOffset(14,61),UDim2.fromOffset(6,6),P.green,5)
local statusText=text(Panel,'StatusText','READY',UDim2.fromOffset(26,54),UDim2.fromOffset(85,20),10,P.muted,Enum.Font.GothamMedium)
local fpsText=text(Panel,'FrameRate','— FPS',UDim2.fromOffset(142,54),UDim2.fromOffset(66,20),11,P.muted,Enum.Font.Code)
local clockText=text(Panel,'Clock','--:--',UDim2.fromOffset(208,54),UDim2.fromOffset(66,20),11,P.muted,Enum.Font.Code)
local noteText=text(Panel,'Hint','DRAG TO MOVE',UDim2.fromOffset(377,54),UDim2.fromOffset(147,20),9,P.muted,Enum.Font.GothamMedium,Enum.TextXAlignment.Right)
logo.Active=true;ver.Active=true;statusText.Active=true;noteText.Active=true

local navNames={'Code','Console','Hub','Agent','Settings'}
local navIcons={'home','terminal','cloud','sparkles','settings'}
local navButtons={}
for i,name in ipairs(navNames) do
    local b=btn(Dock,name..'Tab','',UDim2.fromOffset(3+(i-1)*38,3),UDim2.fromOffset(34,34),P.accent,17)
    b.ZIndex=12;b.BackgroundTransparency=1
    local g=icon(b,navIcons[i],UDim2.fromOffset(5,5),24,i==1 and P.ink or P.text)
    g.ZIndex=13
    navButtons[i]={button=b,glyph=g}
end

local content={}
local function page(name)
    local f=frame(Glass,name..'Page',UDim2.new(),UDim2.fromScale(1,1),P.panel,nil,1)
    f.Visible=false;f.ZIndex=4
    content[name]=f
    return f
end
local codePage=page('Code')
local consolePage=page('Console')
local hubPage=page('Hub')
local agentPage=page('Agent')
local settingsPage=page('Settings')
local current='Code'
local function setPage(name)
    current=name
    for k,p in pairs(content) do p.Visible=(k==name) end
    for i,entry in ipairs(navButtons) do
        for _,child in ipairs(entry.glyph:GetChildren()) do
            local color = (name==navNames[i] and P.ink or P.text)
            if child:IsA('Frame') and child.Name=='Segment' then
                tween(child,.13,{BackgroundColor3=color})
            elseif child:IsA('Frame') and child.Name=='Glyph' then
                local outline=child:FindFirstChildOfClass('UIStroke')
                if outline then tween(outline,.13,{Color=color}) end
            end
        end
    end
    for i,n in ipairs(navNames) do
        if n==name then tween(Selection,.2,{Position=UDim2.fromOffset(3+(i-1)*38,3)}) break end
    end
end
for i,item in ipairs(navButtons) do
    connect(item.button.MouseButton1Click,function()setPage(navNames[i])end)
end

-- CODE PAGE. Exact names/geometry from Basalt's EditorCard/Source hierarchy.
local ScriptTabs=node('ScrollingFrame',codePage,{
    Name='ScriptTabs',BackgroundTransparency=1,BorderSizePixel=0,
    Position=UDim2.fromOffset(12,8),Size=UDim2.fromOffset(472,32),
    CanvasSize=UDim2.fromOffset(0,0),AutomaticCanvasSize=Enum.AutomaticSize.X,
    ScrollBarThickness=0,ScrollingDirection=Enum.ScrollingDirection.X,
    ZIndex=5,
})
local tabsLayout=node('UIListLayout',ScriptTabs,{
    FillDirection=Enum.FillDirection.Horizontal,Padding=UDim.new(0,6),SortOrder=Enum.SortOrder.LayoutOrder,
})
local AddTab=btn(codePage,'AddTab','',UDim2.fromOffset(491,13),UDim2.fromOffset(24,24),P.selected,12)
AddTab.ZIndex=7;icon(AddTab,'add',UDim2.fromOffset(5,5),14,P.text)

local EditorCard=frame(codePage,'EditorCard',UDim2.fromOffset(12,47),UDim2.fromOffset(512,144),P.code,9)
EditorCard.ZIndex=5;EditorCard.ClipsDescendants=true
stroke(EditorCard,P.edge,1,.91)
local EditorScroll=node('ScrollingFrame',EditorCard,{
    Name='EditorScroll',Position=UDim2.new(),Size=UDim2.fromScale(1,1),
    BackgroundTransparency=1,BorderSizePixel=0,ScrollingDirection=Enum.ScrollingDirection.XY,
    CanvasSize=UDim2.fromOffset(0,160),ScrollBarThickness=2,
    ScrollBarImageColor3=P.muted,ScrollBarImageTransparency=.5,
    ZIndex=6,
})
local LineNumbers=text(EditorScroll,'LineNumbers','1',UDim2.fromOffset(0,3),UDim2.fromOffset(25,160),13,P.muted,Enum.Font.Code,Enum.TextXAlignment.Right)
LineNumbers.ZIndex=6;LineNumbers.TextYAlignment=Enum.TextYAlignment.Top;LineNumbers.LineHeight=1.13
local divider=frame(EditorScroll,'GutterRule',UDim2.fromOffset(32,4),UDim2.fromOffset(1,150),P.edge,nil,.76)
divider.ZIndex=6
local Highlight=text(EditorScroll,'Highlight','',UDim2.fromOffset(37,3),UDim2.fromOffset(465,160),13,P.text,Enum.Font.Code)
Highlight.ZIndex=7;Highlight.RichText=true;Highlight.TextWrapped=false
Highlight.TextYAlignment=Enum.TextYAlignment.Top;Highlight.LineHeight=1.13
Highlight.TextTruncate=Enum.TextTruncate.None
local Source=node('TextBox',EditorScroll,{
    Name='Source',BackgroundTransparency=1,BorderSizePixel=0,
    Position=UDim2.fromOffset(37,3),Size=UDim2.fromOffset(465,160),
    Text='',PlaceholderText='',ClearTextOnFocus=false,MultiLine=true,
    TextWrapped=false,ShowNativeInput=true,
    TextColor3=P.text,TextTransparency=1,TextSize=13,LineHeight=1.13,
    Font=Enum.Font.Code,TextXAlignment=Enum.TextXAlignment.Left,
    TextYAlignment=Enum.TextYAlignment.Top,ZIndex=8,
})
local Caret=frame(EditorScroll,'Caret',UDim2.fromOffset(37,3),UDim2.fromOffset(1,15),P.text)
Caret.Visible=false;Caret.ZIndex=9
-- When the mobile system keyboard opens, native edit positioning is retained.

local Actions=frame(codePage,'Actions',UDim2.fromOffset(12,197),UDim2.fromOffset(512,29),P.panel,nil,1)
Actions.ZIndex=6
local Run=btn(Actions,'Run','',UDim2.fromOffset(0,0),UDim2.fromOffset(105,29),P.accent,14)
Run.TextColor3=P.ink;Run.ZIndex=7
icon(Run,'play',UDim2.fromOffset(12,7),15,P.ink)
text(Run,'Caption','Execute',UDim2.fromOffset(35,0),UDim2.fromOffset(65,29),11,P.ink,Enum.Font.GothamBold)
local EditActions=frame(Actions,'EditActions',UDim2.fromOffset(114,0),UDim2.fromOffset(398,29),P.selected,14)
local function smallAction(label,x,w,ico)
    local b=btn(EditActions,label,'',UDim2.fromOffset(x,1),UDim2.fromOffset(w,27),P.selected,13)
    icon(b,ico,UDim2.fromOffset(8,6),15,P.text)
    text(b,'Caption',label,UDim2.fromOffset(29,0),UDim2.new(1,-30,1,0),10,P.text,Enum.Font.GothamMedium)
    return b
end
local Paste=smallAction('Paste',0,76,'paste')
local ExecClip=smallAction('Run clipboard',78,135,'play')
local Copy=smallAction('Copy',216,78,'copy')
local Clear=smallAction('Clear',296,101,'trash')

-- CONSOLE PAGE
local cHeader=text(consolePage,'Header','CONSOLE',UDim2.fromOffset(15,12),UDim2.fromOffset(190,24),14,P.text,Enum.Font.GothamBold)
local cSub=text(consolePage,'Sub','Execution activity & errors',UDim2.fromOffset(15,35),UDim2.fromOffset(310,18),11,P.muted)
local ConsoleCopy=btn(consolePage,'ConsoleCopy','',UDim2.fromOffset(444,9),UDim2.fromOffset(30,30),P.selected,15)
icon(ConsoleCopy,'copy',UDim2.fromOffset(8,8),14,P.text)
local ConsoleClear=btn(consolePage,'ConsoleClear','',UDim2.fromOffset(479,9),UDim2.fromOffset(30,30),P.selected,15)
icon(ConsoleClear,'trash',UDim2.fromOffset(8,8),14,P.text)
local ConsoleCard=frame(consolePage,'ConsoleCard',UDim2.fromOffset(12,60),UDim2.fromOffset(512,163),P.code,11)
stroke(ConsoleCard,P.edge,1,.91)
local ConsoleScroll=node('ScrollingFrame',ConsoleCard,{
    Name='ConsoleScroll',BackgroundTransparency=1,BorderSizePixel=0,
    Position=UDim2.fromOffset(10,7),Size=UDim2.new(1,-20,1,-14),
    ScrollBarThickness=2,ScrollBarImageColor3=P.muted,
    CanvasSize=UDim2.fromOffset(0,0),AutomaticCanvasSize=Enum.AutomaticSize.Y,
})
local logLayout=node('UIListLayout',ConsoleScroll,{Padding=UDim.new(0,5),SortOrder=Enum.SortOrder.LayoutOrder})
local logs={}
local function log(message,kind)
    if not alive then return end
    kind=kind or 'info'
    local msg=tostring(message)
    table.insert(logs,string.format('[%s] %s',kind:upper(),msg))
    if #logs>160 then table.remove(logs,1) end
    local row=text(ConsoleScroll,'LogLine',msg,UDim2.new(),UDim2.new(1,-10,0,16),12,
        kind=='error' and P.red or kind=='success' and P.green or kind=='warning' and P.orange or P.text,
        Enum.Font.Code)
    row.TextWrapped=true;row.TextTruncate=Enum.TextTruncate.None
    row.AutomaticSize=Enum.AutomaticSize.Y
    row.Size=UDim2.new(1,-8,0,16)
    local pref=text(row,'Prefix',kind=='error' and 'ERR' or kind=='success' and 'OK' or '•',
        UDim2.fromOffset(0,0),UDim2.fromOffset(26,16),10,P.muted,Enum.Font.GothamBold)
    row.TextXAlignment=Enum.TextXAlignment.Left
    row.Text=string.rep(' ',6)..msg
    task.defer(function()
        if not alive or not ConsoleScroll.Parent then return end
        ConsoleScroll.CanvasPosition=Vector2.new(0,math.max(0,logLayout.AbsoluteContentSize.Y-ConsoleScroll.AbsoluteSize.Y))
    end)
    if #ConsoleScroll:GetChildren()>175 then
        for _,child in ipairs(ConsoleScroll:GetChildren()) do
            if child.Name=='LogLine' then child:Destroy();break end
        end
    end
end
connect(ConsoleCopy.MouseButton1Click,function()
    if type(setclipboard)=='function' then
        pcall(setclipboard,table.concat(logs,'\n'));log('Console copied','success')
    else log('Clipboard unavailable','warning') end
end)
connect(ConsoleClear.MouseButton1Click,function()
    for _,child in ipairs(ConsoleScroll:GetChildren()) do
        if child.Name=='LogLine' then child:Destroy() end
    end
    table.clear(logs);log('Console cleared')
end)

-- PERSISTENCE / TABS. Original Basalt used .basalt/tabs.json; this version
-- keeps a separate file to avoid corrupting any existing Basalt workspace.
local scriptTabs={}
local activeScript=nil
local FOLDER='.basalt'
local FILE=FOLDER..'/improved_workspace.json'
local hasStorage=type(readfile)=='function' and type(writefile)=='function'
local function saveFile()
    if not hasStorage then return false end
    local payload={version=3,active=1,tabs={}}
    for i,t in ipairs(scriptTabs or {}) do
        table.insert(payload.tabs,{name=t.name,code=t.code})
        if t==activeScript then payload.active=i end
    end
    local ok=pcall(function()
        if type(isfolder)=='function' and type(makefolder)=='function' then
            if not isfolder(FOLDER) then makefolder(FOLDER) end
        end
        writefile(FILE,HttpService:JSONEncode(payload))
    end)
    return ok
end
local redrawTabs,loadActive,renderLibrary
local writeRevision=0
local function queueSave()
    writeRevision=writeRevision+1
    local revision=writeRevision
    task.delay(.9,function()
        if alive and revision==writeRevision then saveFile() end
    end)
end
local function cleanName(v)
    v=tostring(v or 'script.luau')
    if #v>36 then v=v:sub(1,36) end
    return v:gsub('[%c]','')
end
redrawTabs=function()
    for _,child in ipairs(ScriptTabs:GetChildren()) do
        if child:IsA('TextButton') then child:Destroy() end
    end
    for i,t in ipairs(scriptTabs) do
        local selected=t==activeScript
        local b=btn(ScriptTabs,'File'..i,'',UDim2.new(),UDim2.fromOffset(118,29),
            selected and P.selected or P.panel,9)
        b.LayoutOrder=i;b.BackgroundTransparency=selected and 0 or .22
        text(b,'FileName',t.name,UDim2.fromOffset(10,0),UDim2.fromOffset(83,29),
            11,selected and P.text or P.muted,Enum.Font.GothamMedium)
        local exit=btn(b,'Remove','×',UDim2.fromOffset(96,6),UDim2.fromOffset(16,17),P.selected,5)
        exit.BackgroundTransparency=1;exit.TextSize=16;exit.TextColor3=P.muted
        connect(b.MouseButton1Click,function()
            if t==activeScript then return end
            activeScript.code=Source.Text
            activeScript=t
            loadActive();redrawTabs();queueSave()
        end)
        connect(exit.MouseButton1Click,function()
            if #scriptTabs==1 then log('Keep at least one tab','warning');return end
            local old=t==activeScript
            local index=table.find(scriptTabs,t)
            if index then table.remove(scriptTabs,index) end
            if old then
                activeScript=scriptTabs[math.clamp(index or 1,1,#scriptTabs)]
                loadActive()
            end
            redrawTabs();queueSave()
        end)
    end
    if renderLibrary then renderLibrary() end
end

local keywordSet={}
for word in string.gmatch('and break continue do else elseif end export false for function if in local nil not or repeat return then true type typeof until while', '%S+') do
    keywordSet[word]=true
end
local builtinSet={}
for word in string.gmatch('game workspace script Instance Enum Color3 Vector3 Vector2 UDim2 UDim task print warn error pairs ipairs pcall xpcall tostring tonumber math string table getgenv loadstring require', '%S+') do
    builtinSet[word]=true
end
local function esc(s)
    return s:gsub('&','&amp;'):gsub('<','&lt;'):gsub('>','&gt;'):gsub('"','&quot;'):gsub("'",'&apos;')
end
local function wrap(t,hex) return '<font color="#'..hex..'">'..esc(t)..'</font>' end
local function tintSyntax(src)
    if #src>25000 then return esc(src:sub(1,25000)) end
    local out={};local i=1;local n=#src
    while i<=n do
        local c=src:sub(i,i)
        if src:sub(i,i+1)=='--' then
            local e=src:find('\n',i,true) or (n+1)
            out[#out+1]=wrap(src:sub(i,e-1),'828282');i=e
        elseif c=='"' or c=="'" then
            local first=i;local quote=c;i=i+1
            while i<=n do
                local q=src:sub(i,i)
                if q=='\\' then i=i+2
                elseif q==quote then i=i+1;break
                elseif q=='\n' then break
                else i=i+1 end
            end
            out[#out+1]=wrap(src:sub(first,i-1),'C7E8A2')
        elseif c:match('%d') and (i==1 or not src:sub(i-1,i-1):match('[%w_]')) then
            local a,b=src:find('^%d[%d%.]*',i)
            local value=src:sub(a or i,b or i)
            out[#out+1]=wrap(value,'E7B782');i=(b or i)+1
        elseif c:match('[%a_]') then
            local a,b=src:find('^[%a_][%w_]*',i)
            local word=src:sub(a or i,b or i)
            if keywordSet[word] then out[#out+1]=wrap(word,'D1B5FF')
            elseif builtinSet[word] then out[#out+1]=wrap(word,'A6D4F6')
            else out[#out+1]=esc(word) end
            i=(b or i)+1
        else
            out[#out+1]=esc(c);i=i+1
        end
    end
    return table.concat(out)
end
local function redrawEditor()
    local src=Source.Text
    Highlight.Text=tintSyntax(src)
    local lines=1
    for _ in src:gmatch('\n') do lines=lines+1 end
    local nums={}
    for i=1,math.min(lines,1000) do nums[i]=tostring(i) end
    LineNumbers.Text=table.concat(nums,'\n')
    local longest=0
    for ln in (src..'\n'):gmatch('(.-)\n') do longest=math.max(longest,#ln) end
    local h=math.max(160,math.ceil(lines*15.1)+14)
    local w=math.max(465,math.floor(longest*7.8)+70)
    Highlight.Size=UDim2.fromOffset(w-41,h)
    Source.Size=UDim2.fromOffset(w-41,h)
    LineNumbers.Size=UDim2.fromOffset(25,h)
    divider.Size=UDim2.fromOffset(1,h)
    EditorScroll.CanvasSize=UDim2.fromOffset(w,h)
end
loadActive=function()
    if not activeScript then return end
    Source.Text=activeScript.code or ''
    redrawEditor()
end
connect(Source:GetPropertyChangedSignal('Text'),function()
    if activeScript then activeScript.code=Source.Text end
    redrawEditor();queueSave()
end)
-- Best-effort custom caret for transparent-source syntax overlay.
local function placeCaret()
    if not Caret.Visible then return end
    local p=Source.CursorPosition
    if type(p)~='number' or p<1 then Caret.Visible=false;return end
    local prefix=Source.Text:sub(1,p-1)
    local last=prefix:match('([^\n]*)$') or ''
    local row=1;for _ in prefix:gmatch('\n') do row=row+1 end
    local width=TextService:GetTextSize(last,13,Enum.Font.Code,Vector2.new(10000,40)).X
    Caret.Position=UDim2.fromOffset(37+width,3+(row-1)*15)
end
connect(Source.Focused,function() Caret.Visible=true;placeCaret() end)
connect(Source.FocusLost,function() Caret.Visible=false end)
connect(Source:GetPropertyChangedSignal('CursorPosition'),placeCaret)

local function newTab(title,code)
    if activeScript then activeScript.code=Source.Text end
    if #scriptTabs>=16 then log('Maximum 16 tabs','warning');return end
    local t={name=cleanName(title or ('script_'..(#scriptTabs+1)..'.luau')),code=code or ''}
    table.insert(scriptTabs,t);activeScript=t
    loadActive();redrawTabs();queueSave()
end
connect(AddTab.MouseButton1Click,function()newTab()end)

local function clipRead()
    if type(getclipboard)~='function' then return nil,'Clipboard API unavailable' end
    local ok,s=pcall(getclipboard)
    if ok and type(s)=='string' then return s end
    return nil,tostring(s)
end
local function clipWrite(s)
    if type(setclipboard)~='function' then log('Clipboard API unavailable','warning');return end
    local ok,err=pcall(setclipboard,s)
    if ok then log('Copied to clipboard','success') else log(err,'error') end
end
local function runScript(src,label)
    if type(src)~='string' or src:match('^%s*$') then log('Nothing to execute','warning');return end
    local compiler=loadstring
    if type(compiler)~='function' then
        log('loadstring is unavailable in this environment','error')
        setPage('Console');return
    end
    local okay,fn,err=pcall(compiler,src)
    if not okay then log('Compile: '..tostring(fn),'error');setPage('Console');return end
    if type(fn)~='function' then log('Compile: '..tostring(err),'error');setPage('Console');return end
    statusText.Text='RUNNING';statusDot.BackgroundColor3=P.orange
    log('Executing '..tostring(label or (activeScript and activeScript.name or 'script')))
    task.spawn(function()
        local started=os.clock()
        local worked,res=pcall(fn)
        if not alive then return end
        if worked then
            log(string.format('Finished in %.2fs',os.clock()-started),'success')
            statusText.Text='READY';statusDot.BackgroundColor3=P.green
        else
            log('Runtime: '..tostring(res),'error')
            statusText.Text='ERROR';statusDot.BackgroundColor3=P.red
        end
    end)
end
connect(Run.MouseButton1Click,function()runScript(Source.Text)end)
connect(Paste.MouseButton1Click,function()
    local s,err=clipRead()
    if s then Source.Text=s;log('Pasted '..#s..' characters','success')
    else log(err,'warning') end
end)
connect(ExecClip.MouseButton1Click,function()
    local s,err=clipRead()
    if s then runScript(s,'clipboard') else log(err,'warning') end
end)
connect(Copy.MouseButton1Click,function()clipWrite(Source.Text)end)
connect(Clear.MouseButton1Click,function()Source.Text='';log('Editor cleared')end)

-- HUB: keeps Basalt's local script manager model, with searchable entries.
local hubTitle=text(hubPage,'Title','SCRIPT HUB',UDim2.fromOffset(15,12),UDim2.fromOffset(220,22),14,P.text,Enum.Font.GothamBold)
local hubSub=text(hubPage,'Sub','Local scripts · tap to load',UDim2.fromOffset(15,33),UDim2.fromOffset(240,17),11,P.muted)
local searchField=node('TextBox',hubPage,{
    Name='Search',Position=UDim2.fromOffset(15,55),Size=UDim2.fromOffset(506,29),
    BackgroundColor3=P.code,BorderSizePixel=0,Text='',PlaceholderText='Search scripts...',
    ClearTextOnFocus=false,TextColor3=P.text,PlaceholderColor3=P.muted,TextSize=12,
    Font=Enum.Font.Gotham,TextXAlignment=Enum.TextXAlignment.Left,
})
round(searchField,9);stroke(searchField,P.edge,1,.85)
node('UIPadding',searchField,{PaddingLeft=UDim.new(0,12)})
local libraryView=node('ScrollingFrame',hubPage,{
    Name='Scripts',Position=UDim2.fromOffset(12,91),Size=UDim2.fromOffset(512,131),
    BackgroundTransparency=1,BorderSizePixel=0,
    ScrollBarThickness=2,ScrollBarImageColor3=P.muted,
    AutomaticCanvasSize=Enum.AutomaticSize.Y,CanvasSize=UDim2.new(),
})
local libLayout=node('UIListLayout',libraryView,{Padding=UDim.new(0,6),SortOrder=Enum.SortOrder.LayoutOrder})
local library={
    {name='Hello world',code='print("Hello from Basalt")'},
    {name='Client information',code='local p = game:GetService("Players").LocalPlayer\nprint(p.Name, game.PlaceId)'},
    {name='Frame-rate counter',code='local r = game:GetService("RunService")\nlocal frames = 0\nlocal t = os.clock()\nr.RenderStepped:Connect(function()\n    frames += 1\n    if os.clock() - t >= 1 then\n        print("FPS", frames)\n        frames = 0\n        t = os.clock()\n    end\nend)'},
}
renderLibrary=function()
    for _,c in ipairs(libraryView:GetChildren()) do
        if c:IsA('TextButton') then c:Destroy() end
    end
    local q=searchField.Text:lower()
    local entries={}
    for _,t in ipairs(scriptTabs) do table.insert(entries,{name=t.name,code=t.code,personal=true}) end
    for _,t in ipairs(library) do table.insert(entries,t) end
    local found=0
    for i,t in ipairs(entries) do
        if q=='' or t.name:lower():find(q,1,true) then
            found=found+1
            local b=btn(libraryView,'Script'..i,'',UDim2.new(),UDim2.new(1,-5,0,40),P.code,10)
            b.LayoutOrder=i;stroke(b,P.edge,1,.9)
            icon(b,t.personal and 'code' or 'cloud',UDim2.fromOffset(10,10),20,P.muted)
            text(b,'Name',t.name,UDim2.fromOffset(42,0),UDim2.new(1,-122,1,0),12,P.text,Enum.Font.GothamMedium)
            local typeText=text(b,'Type',t.personal and 'TAB' or 'SAMPLE',UDim2.new(1,-74,0,0),UDim2.fromOffset(65,40),9,P.muted,Enum.Font.GothamMedium,Enum.TextXAlignment.Right)
            connect(b.MouseButton1Click,function()
                newTab(t.name,t.code)
                setPage('Code');log('Loaded '..t.name,'success')
            end)
        end
    end
    hubSub.Text=tostring(found)..' available scripts · tap to load'
end
connect(searchField:GetPropertyChangedSignal('Text'),renderLibrary)

-- AGENT PANEL. Basalt's original agent requires an unavailable native/backend.
-- Preserve the page; provide functional offline workspace operations instead
-- of impersonating the missing network AI service.
text(agentPage,'Title','WORKSPACE AGENT',UDim2.fromOffset(15,12),UDim2.fromOffset(275,23),14,P.text,Enum.Font.GothamBold)
text(agentPage,'Desc','Local commands · no remote AI backend',UDim2.fromOffset(15,36),UDim2.fromOffset(475,20),11,P.muted)
local agentCard=frame(agentPage,'AgentCard',UDim2.fromOffset(13,65),UDim2.fromOffset(510,108),P.code,12)
text(agentCard,'Heading','Quick commands',UDim2.fromOffset(12,8),UDim2.fromOffset(300,23),12,P.text,Enum.Font.GothamMedium)
local promptField=node('TextBox',agentCard,{
    Name='Prompt',Position=UDim2.fromOffset(11,37),Size=UDim2.fromOffset(395,30),
    BackgroundColor3=P.selected,BorderSizePixel=0,Text='',PlaceholderText='run, clear, new, copy, save, console',
    ClearTextOnFocus=false,TextColor3=P.text,PlaceholderColor3=P.muted,
    TextXAlignment=Enum.TextXAlignment.Left,TextSize=11,Font=Enum.Font.Gotham,
})
round(promptField,8);node('UIPadding',promptField,{PaddingLeft=UDim.new(0,10)})
local send=btn(agentCard,'Send','Go',UDim2.fromOffset(418,37),UDim2.fromOffset(80,30),P.accent,9)
send.TextColor3=P.ink
local agentResult=text(agentCard,'Result','Available: run · clear · new · copy · save · console',UDim2.fromOffset(12,77),UDim2.fromOffset(485,23),10,P.muted)
local function agentGo()
    local cmd=promptField.Text:lower():match('^%s*(.-)%s*$')
    if cmd=='run' or cmd=='execute' then runScript(Source.Text);agentResult.Text='Execution requested'
    elseif cmd=='clear' then Source.Text='';agentResult.Text='Editor cleared'
    elseif cmd=='new' then newTab();agentResult.Text='New tab created'
    elseif cmd=='copy' then clipWrite(Source.Text);agentResult.Text='Copy requested'
    elseif cmd=='save' then agentResult.Text=saveFile() and 'Workspace saved' or 'File API unavailable'
    elseif cmd=='console' then setPage('Console');agentResult.Text='Console opened'
    elseif cmd=='' then agentResult.Text='Enter a local command'
    else agentResult.Text='Unknown command. This is not a connected AI model.' end
end
connect(send.MouseButton1Click,agentGo)
connect(promptField.FocusLost,function(submit)if submit then agentGo() end end)
text(agentPage,'AgentNote','The reconstructed Basalt agent relies on native components that are',UDim2.fromOffset(16,181),UDim2.fromOffset(490,16),10,P.muted)
text(agentPage,'AgentNote2','not included in the reconstruction; it is not simulated here.',UDim2.fromOffset(16,197),UDim2.fromOffset(490,16),10,P.muted)

-- SETTINGS PAGE
text(settingsPage,'Title','SETTINGS',UDim2.fromOffset(15,12),UDim2.fromOffset(220,26),14,P.text,Enum.Font.GothamBold)
text(settingsPage,'Desc','Basalt visual defaults · refined interactions',UDim2.fromOffset(15,36),UDim2.fromOffset(485,20),11,P.muted)
local opacity=0.08
local options={}
local function setting(label,desc,y,action)
    local b=btn(settingsPage,label,'',UDim2.fromOffset(13,y),UDim2.fromOffset(510,43),P.code,10)
    stroke(b,P.edge,1,.91)
    text(b,'Label',label,UDim2.fromOffset(13,2),UDim2.fromOffset(376,19),12,P.text,Enum.Font.GothamMedium)
    text(b,'Detail',desc,UDim2.fromOffset(13,21),UDim2.fromOffset(440,17),10,P.muted)
    icon(b,'add',UDim2.fromOffset(481,13),16,P.muted)
    connect(b.MouseButton1Click,action)
    return b
end
setting('Panel opacity','Toggle solid / glass',62,function()
    opacity=(opacity<.1) and .27 or .08
    tween(Glass,.2,{BackgroundTransparency=opacity})
    tween(Dock,.2,{BackgroundTransparency=opacity})
end)
setting('Save workspace','Write script tabs to local storage',110,function()
    log(saveFile() and 'Workspace saved' or 'File API unavailable',hasStorage and 'success' or 'warning')
end)
setting('Reset panel position','Return to Basalt\'s original position',158,function()
    tween(Panel,.22,{Position=UDim2.fromOffset(16,16)})
end)

-- FLOATING TOGGLE / PANEL DRAG
local showing=true
local designScale=1
local function showUI(v)
    showing=v
    Panel.Visible=v
    toggle.Visible=not v
    dimmer.Visible=false
    if v then
        Scale.Scale=math.max(.4,Scale.Scale*.965)
        tween(Scale,.2,{Scale=designScale or 1})
    end
end
connect(close.MouseButton1Click,function()showUI(false)end)
connect(toggle.MouseButton1Click,function()showUI(true)end)
connect(dimmer.MouseButton1Click,function()showUI(false)end)
local dragging=false
local dragStart=nil
local panelStart=nil
local dragInput=nil
local function clampPanel(x,y)
    local view=Root.AbsoluteSize
    local w=536*Scale.Scale
    local h=310*Scale.Scale
    return math.clamp(x,0,math.max(0,view.X-w)),math.clamp(y,0,math.max(0,view.Y-h))
end
local function setupDrag(handle,target,isFloat)
    connect(handle.InputBegan,function(input)
        if input.UserInputType~=Enum.UserInputType.MouseButton1 and input.UserInputType~=Enum.UserInputType.Touch then return end
        dragging=true;dragInput=input;dragStart=input.Position;panelStart=target.Position
        local endConn
        endConn=connect(input.Changed,function()
            if input.UserInputState==Enum.UserInputState.End then
                dragging=false
                if endConn then endConn:Disconnect() end
            end
        end)
    end)
end
setupDrag(logo,Panel)
setupDrag(ver,Panel)
setupDrag(noteText,Panel)
-- Drag from unused header/status area. The nav buttons remain normal buttons.
setupDrag(statusText,Panel)
connect(UIS.InputChanged,function(input)
    if not dragging or not dragStart or not panelStart then return end
    if input~=dragInput and input.UserInputType~=Enum.UserInputType.MouseMovement then return end
    local delta=input.Position-dragStart
    local factor=Scale.Scale>0 and Scale.Scale or 1
    local newX=panelStart.X.Offset+delta.X/factor
    local newY=panelStart.Y.Offset+delta.Y/factor
    local actualX,actualY=clampPanel(newX*factor,newY*factor)
    Panel.Position=UDim2.fromOffset(actualX/factor,actualY/factor)
end)
-- Floating toggle itself is draggable on touch; tap still restores UI.
local toggleStart, toggleOrigin
connect(toggle.InputBegan,function(input)
    if input.UserInputType~=Enum.UserInputType.MouseButton1 and input.UserInputType~=Enum.UserInputType.Touch then return end
    toggleStart=input.Position;toggleOrigin=toggle.Position
end)
connect(toggle.InputChanged,function(input)
    if not toggleStart or not toggleOrigin then return end
    if input.UserInputType~=Enum.UserInputType.Touch and input.UserInputType~=Enum.UserInputType.MouseMovement then return end
    local delta=input.Position-toggleStart
    if delta.Magnitude>10 then
        toggle.Position=UDim2.new(toggleOrigin.X.Scale,toggleOrigin.X.Offset+delta.X,toggleOrigin.Y.Scale,toggleOrigin.Y.Offset+delta.Y)
    end
end)
connect(toggle.InputEnded,function()toggleStart=nil end)

local function fit()
    local viewport=Root.AbsoluteSize
    if viewport.X<=0 or viewport.Y<=0 then return end
    -- Basalt used 536x310 and scaled against a 704-point reference size.
    -- Limit to device-safe viewport instead of cropping on portrait phones.
    designScale=math.clamp(math.min((viewport.X-22)/536,(viewport.Y-22)/310,1.52),.46,1.52)
    Scale.Scale=designScale
    local newX,newY=clampPanel(Panel.Position.X.Offset*designScale,Panel.Position.Y.Offset*designScale)
    Panel.Position=UDim2.fromOffset(newX/designScale,newY/designScale)
end
connect(Root:GetPropertyChangedSignal('AbsoluteSize'),fit)

-- FPS and clock are optional cosmetic services in the original status row.
local frames=0;local elapsed=0;local nextClock=0
connect(RunService.RenderStepped,function(dt)
    if not alive then return end
    frames=frames+1;elapsed=elapsed+dt
    if elapsed>=1 then
        fpsText.Text=tostring(math.floor(frames/elapsed+.5))..' FPS'
        frames=0;elapsed=0
    end
    local tm=os.clock()
    if tm>=nextClock then
        clockText.Text=os.date('%H:%M')
        nextClock=tm+8
    end
end)

-- Load persisted workspace when possible, without taking over original Basalt files.
local loaded=false
if hasStorage then
    local ok,payload=pcall(function()
        if type(isfile)=='function' and not isfile(FILE) then return nil end
        return HttpService:JSONDecode(readfile(FILE))
    end)
    if ok and type(payload)=='table' and type(payload.tabs)=='table' then
        for _,t in ipairs(payload.tabs) do
            if #scriptTabs>=16 then break end
            if type(t)=='table' and type(t.name)=='string' and type(t.code)=='string' then
                table.insert(scriptTabs,{name=cleanName(t.name),code=t.code})
            end
        end
        if #scriptTabs>0 then
            activeScript=scriptTabs[math.clamp(tonumber(payload.active) or 1,1,#scriptTabs)]
            loaded=true
        end
    end
end
if not loaded then
    local first={name='draft.luau',code='-- Basalt editor\nprint("Hello from Basalt")'}
    table.insert(scriptTabs,first);activeScript=first
end
loadActive();redrawTabs();renderLibrary();setPage('Code')
fit()
log('Basalt UI initialized','success')
log(hasStorage and 'Workspace persistence enabled' or 'File APIs not available; tabs stay in memory',hasStorage and 'info' or 'warning')

local function destroy()
    if not alive then return end
    saveFile()
    alive=false
    for _,c in ipairs(connections) do pcall(function()c:Disconnect()end) end
    pcall(function()Interface:Destroy()end)
    pcall(function()DimGui:Destroy()end)
    if E and type(E)=='table' then E.basaltImproved=nil end
end
if E and type(E)=='table' then
    E.basaltImproved={
        version='Basalt_UI_source_rebuild_1',gui=Interface,dimGui=DimGui,
        editor=Source,source=Source,run=runScript,selectTab=setPage,
        getActiveScript=function()return activeScript end,
        addScript=newTab,save=saveFile,close=function()showUI(false)end,
        open=function()showUI(true)end,destroy=destroy,
    }
end
