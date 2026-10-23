

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UIS = game:GetService("UserInputService")
local TextService = game:GetService("TextService")
local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")
local Camera = workspace.CurrentCamera

local ROOT_NAME = "AetherMobileWorkspace"
local SAVE_PATH = "aether_workspace_v2.json"
local MAX_TABS = 12
local DEFAULT_CODE = '-- Welcome to Aether\nprint("Hello from Aether!")'
local P = {
    backdrop = Color3.fromRGB(8, 11, 16),
    base = Color3.fromRGB(14, 18, 25),
    rail = Color3.fromRGB(11, 14, 20),
    pane = Color3.fromRGB(18, 23, 31),
    raised = Color3.fromRGB(25, 32, 43),
    raisedHover = Color3.fromRGB(33, 42, 54),
    border = Color3.fromRGB(42, 50, 63),
    text = Color3.fromRGB(236, 243, 249),
    muted = Color3.fromRGB(135, 151, 165),
    faint = Color3.fromRGB(95, 109, 124),
    error = Color3.fromRGB(255, 119, 134),
    warn = Color3.fromRGB(252, 197, 104),
    green = Color3.fromRGB(103, 224, 177),
}
local ACCENTS = {
    Ice = Color3.fromRGB(103, 210, 237),
    Mint = Color3.fromRGB(107, 227, 188),
    Violet = Color3.fromRGB(177, 146, 255),
}
local currentTheme = "Ice"
local accent = ACCENTS[currentTheme]
local fontSize = 14
local syntaxEnabled = true
local animationsEnabled = true
local tabs, library, logs = {}, {}, {}
local activeIndex, activePage, nextId = 1, "Editor", 1
local dirtyVersion, runCount = 0, 0
local uiClosed = false
local accentItems, navItems, pageItems = {}, {}, {}
local toastVersion = 0
local connections = {}
local codeBox, syntaxLabel, lineLabel, editorScroll, tabStrip, tabLayout
local lineInfo, byteInfo, statusInfo, toastLabel, saveModal, modalTitle, modalHint
local modalField, modalAction, modalCancel
local resultScroll, resultLayout, libraryScroll, libraryLayout, consoleScroll, consoleLayout
local librarySearch, searchInput, resultInfo
local main, mainScale, orb, screen, selectedFileName
local updateEditor, renderTabs, renderLibrary, addLog, showPage, notify
local refreshTheme, refreshCodeGeometry

local function new(class, parent, props)
    local instance = Instance.new(class)
    for key, value in pairs(props or {}) do instance[key] = value end
    if parent then instance.Parent = parent end
    return instance
end
local function corner(parent, radius)
    return new("UICorner", parent, {CornerRadius=UDim.new(0, radius)})
end
local function stroke(parent, color, transparency, thickness)
    return new("UIStroke", parent, {Color=color or P.border,
        Transparency=transparency or 0, Thickness=thickness or 1})
end
local function gradient(parent, first, last, rotation)
    return new("UIGradient", parent, {Rotation=rotation or 30,
        Color=ColorSequence.new(first, last)})
end
local function animate(obj, to, t)
    if not obj or not obj.Parent then return end
    if not animationsEnabled then
        for key, value in pairs(to) do obj[key] = value end
        return
    end
    local tw = TweenService:Create(obj, TweenInfo.new(t or .16,
        Enum.EasingStyle.Quart, Enum.EasingDirection.Out), to)
    tw:Play()
    return tw
end
local function label(parent, text, size, color, bold, props)
    local p = props or {}
    p.BackgroundTransparency = 1
    p.BorderSizePixel = 0
    p.Text = text
    p.Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham
    p.TextSize = size or 13
    p.TextColor3 = color or P.text
    p.TextXAlignment = p.TextXAlignment or Enum.TextXAlignment.Left
    p.TextYAlignment = p.TextYAlignment or Enum.TextYAlignment.Center
    return new("TextLabel", parent, p)
end
local function button(parent, text, props, kind)
    local p = props or {}
    p.Text = text
    p.AutoButtonColor = false
    p.BorderSizePixel = 0
    p.BackgroundColor3 = kind == "accent" and accent or P.raised
    p.TextColor3 = kind == "accent" and P.backdrop or P.text
    p.Font = Enum.Font.GothamBold
    p.TextSize = p.TextSize or 12
    local b = new("TextButton", parent, p)
    corner(b, p.CornerRadius or 9)
    if kind == "accent" then
        table.insert(accentItems, {obj=b, prop="BackgroundColor3"})
    end
    b.MouseEnter:Connect(function()
        if b.Parent then animate(b, {BackgroundColor3=kind == "accent" and accent:Lerp(Color3.new(1,1,1), .14) or P.raisedHover}, .12) end
    end)
    b.MouseLeave:Connect(function()
        if b.Parent then animate(b, {BackgroundColor3=kind == "accent" and accent or P.raised}, .13) end
    end)
    return b
end
local function pane(parent, props, r)
    local p = props or {}
    p.BorderSizePixel = 0
    p.BackgroundColor3 = p.BackgroundColor3 or P.pane
    local object = new("Frame", parent, p)
    corner(object, r or 11)
    stroke(object, P.border, .20)
    return object
end
local function track(con)
    table.insert(connections, con)
    return con
end
local function safeCall(f, ...)
    if type(f) ~= "function" then return false, "Unavailable in this executor" end
    return pcall(f, ...)
end
local function jsonEncode(value)
    local ok, encoded = pcall(function() return HttpService:JSONEncode(value) end)
    return ok and encoded or nil
end
local function jsonDecode(value)
    local ok, decoded = pcall(function() return HttpService:JSONDecode(value) end)
    return ok and decoded or nil
end
local function saveWorkspace()
    if type(writefile) ~= "function" then return end
    local data = {schema=2, tabs=tabs, activeIndex=activeIndex,
        library=library, nextId=nextId, accent=currentTheme,
        fontSize=fontSize, syntax=syntaxEnabled, animations=animationsEnabled}
    local encoded = jsonEncode(data)
    if encoded then pcall(writefile, SAVE_PATH, encoded) end
end
local function scheduleSave()
    dirtyVersion += 1
    local token = dirtyVersion
    task.delay(1.0, function()
        if dirtyVersion == token then saveWorkspace() end
    end)
end
local function loadWorkspace()
    if type(readfile) ~= "function" then return end
    local ok, raw = pcall(readfile, SAVE_PATH)
    if not ok or type(raw) ~= "string" then return end
    local data = jsonDecode(raw)
    if type(data) ~= "table" or data.schema ~= 2 then return end
    if type(data.tabs) == "table" then
        for _, item in ipairs(data.tabs) do
            if #tabs >= MAX_TABS then break end
            if type(item)=="table" and type(item.name)=="string" and type(item.source)=="string" then
                table.insert(tabs, {id=tonumber(item.id) or (#tabs+1),
                    name=item.name:sub(1,40), source=item.source:sub(1,200000)})
            end
        end
    end
    if type(data.library)=="table" then
        for _, item in ipairs(data.library) do
            if type(item)=="table" and type(item.name)=="string" and type(item.source)=="string" then
                table.insert(library, {name=item.name:sub(1,60), source=item.source:sub(1,200000)})
                if #library >= 100 then break end
            end
        end
    end
    if ACCENTS[data.accent] then currentTheme=data.accent; accent=ACCENTS[data.accent] end
    if type(data.fontSize)=="number" then fontSize=math.clamp(data.fontSize,11,19) end
    if type(data.syntax)=="boolean" then syntaxEnabled=data.syntax end
    if type(data.animations)=="boolean" then animationsEnabled=data.animations end
    if type(data.nextId)=="number" then nextId=math.clamp(data.nextId,1,99999) end
    activeIndex = math.clamp(tonumber(data.activeIndex) or 1, 1, math.max(1,#tabs))
end
loadWorkspace()
if #tabs == 0 then
    tabs[1] = {id=nextId, name="Untitled 1", source=DEFAULT_CODE}
    nextId += 1
end

-- Mount directly in CoreGui; use gethui() only as a fallback.
local existing = CoreGui:FindFirstChild(ROOT_NAME)
if existing then existing:Destroy() end
screen = new("ScreenGui", nil, {Name=ROOT_NAME, ResetOnSpawn=false,
    DisplayOrder=999, IgnoreGuiInset=true, ZIndexBehavior=Enum.ZIndexBehavior.Sibling})
local attached = pcall(function() screen.Parent = CoreGui end)
if not attached and type(gethui)=="function" then
    local ok,container=pcall(gethui)
    if ok and typeof(container)=="Instance" then
        local prior=container:FindFirstChild(ROOT_NAME)
        if prior then prior:Destroy() end
        attached=pcall(function() screen.Parent=container end)
    end
end
if not attached then error("Aether: unable to mount CoreGui (executor permission needed)") end
screen.Destroying:Connect(function()
    for _, connection in ipairs(connections) do pcall(function() connection:Disconnect() end) end
end)

local backdrop = new("Frame", screen, {Name="Shade",BackgroundColor3=P.backdrop,
    BackgroundTransparency=.42,BorderSizePixel=0,Size=UDim2.fromScale(1,1),Visible=false})
main = new("Frame", screen, {Name="AetherWindow",AnchorPoint=Vector2.new(.5,.5),
    Position=UDim2.fromScale(.5,.5),Size=UDim2.fromOffset(740,480),
    BackgroundColor3=P.base,BorderSizePixel=0,ClipsDescendants=true})
corner(main, 17)
stroke(main, P.border, .02)
local topAccent = new("Frame",main,{Name="TopAccent",BackgroundColor3=accent,
    BorderSizePixel=0,Size=UDim2.new(1,0,0,2),ZIndex=5})
gradient(topAccent,accent,accent:Lerp(P.pane,.85),0)
table.insert(accentItems,{obj=topAccent,prop="BackgroundColor3"})
mainScale = new("UIScale", main, {Scale=1})
local rootGradient = gradient(main, P.base, Color3.fromRGB(16,22,31), 90)
local rail = new("Frame", main, {Name="SideNavigation",BackgroundColor3=P.rail,
    BorderSizePixel=0,Size=UDim2.new(0,66,1,0)})
new("Frame", rail, {BackgroundColor3=P.border,BackgroundTransparency=.35,BorderSizePixel=0,
    Size=UDim2.new(0,1,1,0),Position=UDim2.new(1,-1,0,0)})
local brandMark = pane(rail, {Name="Brand",Size=UDim2.fromOffset(38,38),Position=UDim2.fromOffset(14,15),
    BackgroundColor3=accent}, 11)
gradient(brandMark, accent, accent:Lerp(Color3.new(0,0,0), .35), 45)
local mark = label(brandMark, "A", 19, P.backdrop, true,
    {Size=UDim2.fromScale(1,1),TextXAlignment=Enum.TextXAlignment.Center})
table.insert(accentItems, {obj=brandMark,prop="BackgroundColor3"})
local navArea = new("Frame", rail, {BackgroundTransparency=1,Position=UDim2.fromOffset(0,82),
    Size=UDim2.new(1,0,1,-132)})
new("UIListLayout", navArea, {Padding=UDim.new(0,6),HorizontalAlignment=Enum.HorizontalAlignment.Center,
    SortOrder=Enum.SortOrder.LayoutOrder})
local sidebarVersion = label(rail,"v2.0",10,P.faint,false,
    {Position=UDim2.new(0,0,1,-36),Size=UDim2.new(1,0,0,20),TextXAlignment=Enum.TextXAlignment.Center})

local body = new("Frame", main, {BackgroundTransparency=1,
    Position=UDim2.fromOffset(66,0),Size=UDim2.new(1,-66,1,0)})
local top = new("Frame", body, {BackgroundTransparency=1,Size=UDim2.new(1,0,0,62)})
local title = label(top, "AETHER", 16, P.text, true,
    {Position=UDim2.fromOffset(18,11),Size=UDim2.new(1,-170,0,25)})
local subtitle = label(top, "SCRIPT WORKSPACE   /   MOBILE", 9, P.faint, true,
    {Position=UDim2.fromOffset(18,35),Size=UDim2.new(1,-130,0,14)})
new("Frame", top,{BackgroundColor3=P.border,BorderSizePixel=0,
    Position=UDim2.new(0,0,1,-1),Size=UDim2.new(1,0,0,1)})
local minimize = button(top,"−",{Position=UDim2.new(1,-91,0,15),Size=UDim2.fromOffset(30,30),TextSize=21})
local close = button(top,"×",{Position=UDim2.new(1,-51,0,15),Size=UDim2.fromOffset(30,30),TextSize=19})

-- Floating, draggable launch button independent of the window's scale.
orb = button(screen,"A",{Name="FloatingLauncher",AnchorPoint=Vector2.new(.5,.5),
    Position=UDim2.new(1,-37,.47,0),Size=UDim2.fromOffset(52,52),TextSize=21},"accent")
corner(orb,17)
stroke(orb, P.text, .70)
orb.Visible = false

local pagesRoot = new("Frame", body,{BackgroundTransparency=1,Position=UDim2.fromOffset(0,62),
    Size=UDim2.new(1,0,1,-62),ClipsDescendants=true})
for _, name in ipairs({"Editor","Library","Discover","Console","Settings"}) do
    pageItems[name] = new("Frame", pagesRoot,{Name=name,BackgroundTransparency=1,
        Size=UDim2.fromScale(1,1),Visible=name=="Editor"})
end
local function navButton(name, glyph, index)
    local b = button(navArea,"",{Name=name,Size=UDim2.fromOffset(55,59),LayoutOrder=index,
        BackgroundTransparency=1})
    corner(b,11)
    local sideGlow = new("Frame",b,{BackgroundColor3=accent,BorderSizePixel=0,
        Size=UDim2.fromOffset(3,24),Position=UDim2.fromOffset(0,17),Visible=false})
    corner(sideGlow,3)
    table.insert(accentItems,{obj=sideGlow,prop="BackgroundColor3"})
    local ico = label(b,glyph,18,P.muted,true,{Size=UDim2.new(1,0,0,32),
        Position=UDim2.fromOffset(0,4),TextXAlignment=Enum.TextXAlignment.Center})
    local caption = label(b,name:upper(),8,P.faint,true,
        {Position=UDim2.fromOffset(0,37),Size=UDim2.new(1,0,0,12),TextXAlignment=Enum.TextXAlignment.Center})
    navItems[name]={button=b,icon=ico,caption=caption,strip=sideGlow}
    b.Activated:Connect(function() showPage(name) end)
end
navButton("Editor","</>",1)
navButton("Library","▤",2)
navButton("Discover","⌕",3)
navButton("Console",">_",4)
navButton("Settings","⚙",5)
showPage = function(name)
    if not pageItems[name] then return end
    activePage = name
    for page, frame in pairs(pageItems) do frame.Visible = page == name end
    for page, controls in pairs(navItems) do
        local chosen = page == name
        controls.strip.Visible=chosen
        animate(controls.button,{BackgroundTransparency=chosen and 0 or 1,
            BackgroundColor3=chosen and P.raised or P.rail},.16)
        controls.icon.TextColor3=chosen and accent or P.muted
        controls.caption.TextColor3=chosen and P.text or P.faint
    end
    subtitle.Text=(name:upper().."   /   MOBILE WORKSPACE")
end

-- Lightweight notifications; no blocking popups for routine actions.
local toast = pane(screen, {Name="Toast",AnchorPoint=Vector2.new(.5,0),
    Position=UDim2.new(.5,0,0,-76),Size=UDim2.fromOffset(270,47),
    BackgroundColor3=P.raised,ZIndex=60}, 12)
toastLabel = label(toast,"",12,P.text,true,
    {Position=UDim2.fromOffset(15,0),Size=UDim2.new(1,-25,1,0),ZIndex=61,
    TextTruncate=Enum.TextTruncate.AtEnd})
notify = function(message)
    toastVersion += 1
    local v=toastVersion
    toastLabel.Text=tostring(message)
    animate(toast,{Position=UDim2.new(.5,0,0,18)},.24)
    task.delay(2.35,function()
        if toastVersion==v and toast.Parent then
            animate(toast,{Position=UDim2.new(.5,0,0,-76)},.26)
        end
    end)
end

--[[ EDITOR -- Hydrogen layout + Basalt's multiple files/tabs. ]]
local editorPage = pageItems.Editor
local tabbar = new("Frame",editorPage,{BackgroundTransparency=1,Size=UDim2.new(1,0,0,46)})
tabStrip = new("ScrollingFrame",tabbar,{Name="OpenScripts",Active=true,
    BackgroundTransparency=1,BorderSizePixel=0,Position=UDim2.fromOffset(12,5),
    Size=UDim2.new(1,-57,0,36),ScrollBarThickness=0,CanvasSize=UDim2.fromOffset(0,0),
    ScrollingDirection=Enum.ScrollingDirection.X})
tabLayout = new("UIListLayout",tabStrip,{FillDirection=Enum.FillDirection.Horizontal,
    SortOrder=Enum.SortOrder.LayoutOrder,Padding=UDim.new(0,6)})
tabLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    tabStrip.CanvasSize=UDim2.fromOffset(tabLayout.AbsoluteContentSize.X+8,0)
end)
local newTabButton=button(tabbar,"+",{Position=UDim2.new(1,-43,0,6),Size=UDim2.fromOffset(31,31),TextSize=21})
local infoBar = new("Frame",editorPage,{BackgroundTransparency=1,
    Position=UDim2.fromOffset(12,45),Size=UDim2.new(1,-24,0,34)})
local activeDot = new("Frame",infoBar,{BackgroundColor3=P.green,BorderSizePixel=0,
    Position=UDim2.fromOffset(2,13),Size=UDim2.fromOffset(7,7)})
corner(activeDot,4)
lineInfo = label(infoBar,"1 line",11,P.muted,false,
    {Position=UDim2.fromOffset(17,1),Size=UDim2.fromOffset(100,30)})
byteInfo = label(infoBar,"0 chars",11,P.faint,false,
    {Position=UDim2.fromOffset(104,1),Size=UDim2.fromOffset(100,30)})
statusInfo = label(infoBar,"LUAU",10,P.faint,true,
    {Position=UDim2.new(1,-92,0,1),Size=UDim2.fromOffset(90,30),TextXAlignment=Enum.TextXAlignment.Right})
local codeSurface = pane(editorPage,{Name="CodeSurface",Position=UDim2.fromOffset(12,80),
    Size=UDim2.new(1,-24,1,-151),BackgroundColor3=P.backdrop,ClipsDescendants=true},12)
local codeHeader = new("Frame",codeSurface,{BackgroundColor3=P.pane,BorderSizePixel=0,
    Size=UDim2.new(1,0,0,29)})
label(codeHeader,"  ●    code.luau",10,P.muted,true,{Size=UDim2.new(1,-14,1,0)})
new("Frame",codeHeader,{BackgroundColor3=P.border,BorderSizePixel=0,
    Size=UDim2.new(1,0,0,1),Position=UDim2.new(0,0,1,-1)})
editorScroll = new("ScrollingFrame",codeSurface,{Name="CodeScroll",BackgroundTransparency=1,
    Position=UDim2.fromOffset(0,29),Size=UDim2.new(1,0,1,-29),
    BorderSizePixel=0,Active=true,CanvasSize=UDim2.new(),
    ScrollingDirection=Enum.ScrollingDirection.XY,ScrollBarThickness=3,
    ScrollBarImageColor3=P.faint,ScrollBarImageTransparency=.4})
local gutter = new("Frame",editorScroll,{Name="LineNumbers",BackgroundColor3=P.rail,
    BorderSizePixel=0,Position=UDim2.fromOffset(0,0),Size=UDim2.fromOffset(47,100)})
new("Frame",gutter,{BackgroundColor3=P.border,BorderSizePixel=0,
    Position=UDim2.new(1,-1,0,0),Size=UDim2.new(0,1,1,0)})
lineLabel=label(gutter,"1",fontSize,P.faint,false,
    {Font=Enum.Font.Code,Position=UDim2.fromOffset(5,10),Size=UDim2.new(1,-14,1,-12),
    TextXAlignment=Enum.TextXAlignment.Right,TextYAlignment=Enum.TextYAlignment.Top})
lineLabel.Font=Enum.Font.Code
syntaxLabel=label(editorScroll,"",fontSize,P.text,false,
    {Name="SyntaxColours",Position=UDim2.fromOffset(59,10),
    TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Top,
    RichText=true,TextWrapped=false,ZIndex=1})
syntaxLabel.Font=Enum.Font.Code
codeBox = new("TextBox",editorScroll,{Name="LuauEditor",BackgroundTransparency=1,
    BorderSizePixel=0,Position=UDim2.fromOffset(59,10),
    Size=UDim2.fromOffset(650,320),Text=DEFAULT_CODE,
    ClearTextOnFocus=false,MultiLine=true,TextWrapped=false,
    TextEditable=true,TextXAlignment=Enum.TextXAlignment.Left,
    TextYAlignment=Enum.TextYAlignment.Top,TextColor3=P.text,
    PlaceholderColor3=P.faint,PlaceholderText="-- Enter your Luau code here...",
    Font=Enum.Font.Code,TextSize=fontSize,ZIndex=2})
local actionBar = new("Frame",editorPage,{BackgroundTransparency=1,
    Position=UDim2.new(0,12,1,-64),Size=UDim2.new(1,-24,0,54)})
local actionLayout=new("UIListLayout",actionBar,{FillDirection=Enum.FillDirection.Horizontal,
    HorizontalAlignment=Enum.HorizontalAlignment.Center,
    VerticalAlignment=Enum.VerticalAlignment.Center,
    Padding=UDim.new(0,6),SortOrder=Enum.SortOrder.LayoutOrder})
local runButton=button(actionBar,"▶  EXECUTE",{Name="Run",Size=UDim2.fromOffset(109,41),LayoutOrder=1,TextSize=11},"accent")
local saveButton=button(actionBar,"SAVE",{Name="Save",Size=UDim2.fromOffset(65,41),LayoutOrder=2,TextSize=10})
local pasteButton=button(actionBar,"PASTE",{Name="Paste",Size=UDim2.fromOffset(65,41),LayoutOrder=3,TextSize=10})
local copyButton=button(actionBar,"COPY",{Name="Copy",Size=UDim2.fromOffset(65,41),LayoutOrder=4,TextSize=10})
local clearButton=button(actionBar,"CLEAR",{Name="Clear",Size=UDim2.fromOffset(65,41),LayoutOrder=5,TextSize=10})

local keywords = {}
for word in string.gmatch("and break do else elseif end false for function if in local nil not or repeat return then true until while continue self", "%S+") do keywords[word]=true end
local function xml(s)
    local escaped=s:gsub("&","&amp;"):gsub("<","&lt;"):gsub(">","&gt;")
    return escaped
end
local function tint(source, col)
    return '<font color="'..col..'">'..xml(source)..'</font>'
end
local function syntaxHighlight(src)
    if #src>13000 then return xml(src) end
    local out={}
    local i,n=1,#src
    while i<=n do
        local ch=src:sub(i,i)
        local nxt=src:sub(i+1,i+1)
        if ch=="-" and nxt=="-" then
            local k=src:find("\n",i,true) or (n+1)
            table.insert(out,tint(src:sub(i,k-1),"#7B899A")); i=k
        elseif ch=='"' or ch=="'" then
            local j=i+1
            while j<=n do
                local c=src:sub(j,j)
                if c=="\\" then j+=2
                elseif c==ch then j+=1; break
                else j+=1 end
            end
            table.insert(out,tint(src:sub(i,j-1),"#A8E6BB")); i=j
        elseif ch:match("[%a_]") then
            local j=i+1
            while j<=n and src:sub(j,j):match("[%w_]") do j+=1 end
            local word=src:sub(i,j-1)
            table.insert(out, keywords[word] and tint(word,"#B9A0FB") or xml(word))
            i=j
        elseif ch:match("%d") then
            local j=i+1
            while j<=n and src:sub(j,j):match("[%w%.]") do j+=1 end
            table.insert(out,tint(src:sub(i,j-1),"#F9C67E")); i=j
        else
            table.insert(out,xml(ch)); i+=1
        end
    end
    return table.concat(out)
end
local lastSource, lastW, lastH = "", 0, 0
refreshCodeGeometry = function()
    if not editorScroll then return end
    local text=codeBox.Text
    local lineCount,maxWidth,curWidth=1,0,0
    for k=1,#text do
        local c=text:sub(k,k)
        if c=="\n" then
            lineCount+=1; maxWidth=math.max(maxWidth,curWidth); curWidth=0
        elseif c=="\t" then curWidth+=4
        else curWidth+=1 end
    end
    maxWidth=math.max(maxWidth,curWidth)
    local lineHeight=math.floor(fontSize*1.22+1)
    local w=math.max(editorScroll.AbsoluteSize.X,math.ceil(70+maxWidth*fontSize*.65+50))
    local h=math.max(editorScroll.AbsoluteSize.Y,math.ceil(23+lineCount*lineHeight+30))
    if lastW~=w or lastH~=h then
        editorScroll.CanvasSize=UDim2.fromOffset(w,h)
        gutter.Size=UDim2.fromOffset(47,h)
        codeBox.Size=UDim2.fromOffset(math.max(w-70,200),h-20)
        syntaxLabel.Size=codeBox.Size
        lastW,lastH=w,h
    end
    lineLabel.Size=UDim2.fromOffset(33,h-18)
    local nums={}
    for k=1,math.min(lineCount,2000) do nums[k]=tostring(k) end
    lineLabel.Text=table.concat(nums,"\n")
    lineInfo.Text=tostring(lineCount)..(lineCount==1 and " line" or " lines")
    byteInfo.Text=tostring(#text).." chars"
    lineLabel.TextSize=fontSize
    codeBox.TextSize=fontSize
    syntaxLabel.TextSize=fontSize
    if syntaxEnabled then
        syntaxLabel.Text=syntaxHighlight(text)
        syntaxLabel.Visible=true
        codeBox.TextTransparency=.95
    else
        syntaxLabel.Visible=false
        codeBox.TextTransparency=0
    end
end

local isChangingTab=false
updateEditor = function()
    isChangingTab=true
    local t=tabs[activeIndex]
    codeBox.Text=t and t.source or ""
    isChangingTab=false
    refreshCodeGeometry()
    renderTabs()
end
track(codeBox:GetPropertyChangedSignal("Text"):Connect(function()
    if not isChangingTab then
        local t=tabs[activeIndex]
        if t then t.source=codeBox.Text; scheduleSave() end
    end
    refreshCodeGeometry()
end))
track(editorScroll:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
    lastW,lastH=0,0
    refreshCodeGeometry()
end))

renderTabs = function()
    for _, child in ipairs(tabStrip:GetChildren()) do
        if child:IsA("TextButton") then child:Destroy() end
    end
    for index, t in ipairs(tabs) do
        local active=index==activeIndex
        local width=math.clamp(#t.name*6+46,110,163)
        local entry=button(tabStrip,"",{Name="Tab_"..tostring(t.id),LayoutOrder=index,
            Size=UDim2.fromOffset(width,32),BackgroundColor3=active and P.raised or P.rail})
        entry.BackgroundColor3=active and P.raised or P.rail
        if active then stroke(entry,accent,.28,1) end
        local filename=label(entry,t.name,11,active and P.text or P.muted,active,
            {Position=UDim2.fromOffset(11,0),Size=UDim2.new(1,-36,1,0),
            TextTruncate=Enum.TextTruncate.AtEnd})
        local x=button(entry,"×",{Position=UDim2.new(1,-26,0,5),Size=UDim2.fromOffset(22,22),
            TextSize=14,BackgroundTransparency=1})
        x.BackgroundTransparency=1
        entry.Activated:Connect(function()
            activeIndex=index
            updateEditor(); scheduleSave()
        end)
        x.Activated:Connect(function()
            if #tabs==1 then
                tabs[1].source=""; tabs[1].name="Untitled"; activeIndex=1
            else
                table.remove(tabs,index)
                if activeIndex>index then activeIndex-=1 end
                activeIndex=math.clamp(activeIndex,1,#tabs)
            end
            updateEditor(); scheduleSave()
        end)
    end
end
local function newTab(name,source)
    if #tabs>=MAX_TABS then notify("Maximum 12 tabs reached"); return false end
    local t={id=nextId,name=name or ("Untitled "..tostring(nextId)),source=source or ""}
    nextId+=1
    table.insert(tabs,t)
    activeIndex=#tabs
    showPage("Editor")
    updateEditor(); scheduleSave()
    return true
end
newTabButton.Activated:Connect(function() newTab() end)

-- Shared modal: save / rename / delete confirmations.
local modalCover=new("Frame",screen,{BackgroundColor3=P.backdrop,BackgroundTransparency=.30,
    BorderSizePixel=0,Size=UDim2.fromScale(1,1),Visible=false,Active=true,ZIndex=80})
local dialog=pane(modalCover,{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),
    Size=UDim2.fromOffset(330,208),BackgroundColor3=P.pane,ZIndex=81},15)
local dialogScale = new("UIScale",dialog,{Scale=1})
modalTitle=label(dialog,"Save script",17,P.text,true,
    {Position=UDim2.fromOffset(19,14),Size=UDim2.new(1,-38,0,27),ZIndex=82})
modalHint=label(dialog,"Choose a name for your saved script.",11,P.muted,false,
    {Position=UDim2.fromOffset(19,44),Size=UDim2.new(1,-38,0,27),ZIndex=82,TextWrapped=true})
modalField=new("TextBox",dialog,{BackgroundColor3=P.raised,BorderSizePixel=0,
    Position=UDim2.fromOffset(19,84),Size=UDim2.new(1,-38,0,39),
    ClearTextOnFocus=false,Text="",PlaceholderText="Script name",
    Font=Enum.Font.Gotham,TextSize=13,TextColor3=P.text,PlaceholderColor3=P.faint,
    ZIndex=82})
corner(modalField,9); stroke(modalField,P.border,.35)
modalCancel=button(dialog,"CANCEL",{Position=UDim2.new(0,19,1,-57),
    Size=UDim2.fromOffset(127,39),ZIndex=82})
modalAction=button(dialog,"SAVE",{Position=UDim2.new(1,-146,1,-57),
    Size=UDim2.fromOffset(127,39),ZIndex=82},"accent")
local modalCallback=nil
local function hideModal()
    modalCover.Visible=false; modalCallback=nil
end
modalCancel.Activated:Connect(hideModal)
modalAction.Activated:Connect(function()
    local callback=modalCallback
    if callback then callback(modalField.Text) end
end)
local function askModal(heading,hint,initial,action,callback,usesField)
    modalTitle.Text=heading; modalHint.Text=hint
    modalField.Text=initial or ""
    modalField.Visible=usesField~=false
    modalAction.Text=action
    modalCover.Visible=true
    modalCallback=callback
end

local function currentTab() return tabs[activeIndex] end
local function saveToLibrary()
    local t=currentTab()
    if not t then return end
    askModal("Save to library","Give this script a name. Your code is retained in the editor.",
        t.name,"SAVE",function(name)
            name=name:match("^%s*(.-)%s*$")
            if name=="" then notify("Enter a script name"); return end
            name=name:sub(1,58)
            local found=nil
            for _, item in ipairs(library) do
                if item.name==name then found=item; break end
            end
            if found then found.source=t.source
            else table.insert(library,1,{name=name,source=t.source}) end
            t.name=name; hideModal(); renderTabs(); renderLibrary(); scheduleSave()
            notify("Saved "..name)
        end,true)
end
saveButton.Activated:Connect(saveToLibrary)
local function copyText(value)
    if type(setclipboard)~="function" then notify("Clipboard API is unavailable");return end
    local ok=pcall(setclipboard,value)
    notify(ok and "Copied to clipboard" or "Clipboard failed")
end
local function pasteText()
    if type(getclipboard)~="function" then notify("Clipboard API is unavailable");return end
    local ok,text=pcall(getclipboard)
    if not ok or type(text)~="string" then notify("Could not read clipboard");return end
    if #text>180000 then notify("Clipboard text is too large");return end
    codeBox.Text=text
    notify("Pasted clipboard text")
end
copyButton.Activated:Connect(function()copyText(codeBox.Text)end)
pasteButton.Activated:Connect(pasteText)
clearButton.Activated:Connect(function()codeBox.Text="";notify("Editor cleared")end)

--[[ CONSOLE ]]
local consolePage=pageItems.Console
local consoleHeader=label(consolePage,"EXECUTION LOG",14,P.text,true,
    {Position=UDim2.fromOffset(17,12),Size=UDim2.new(1,-180,0,28)})
local clearLogs=button(consolePage,"CLEAR",{Position=UDim2.new(1,-151,0,10),Size=UDim2.fromOffset(64,33)})
local copyLogs=button(consolePage,"COPY",{Position=UDim2.new(1,-79,0,10),Size=UDim2.fromOffset(64,33)})
local consoleWrap=pane(consolePage,{Position=UDim2.fromOffset(12,55),Size=UDim2.new(1,-24,1,-67),
    BackgroundColor3=P.backdrop,ClipsDescendants=true},11)
consoleScroll=new("ScrollingFrame",consoleWrap,{BackgroundTransparency=1,
    Position=UDim2.fromOffset(8,8),Size=UDim2.new(1,-16,1,-16),CanvasSize=UDim2.new(),
    ScrollBarThickness=3,ScrollBarImageColor3=P.muted,BorderSizePixel=0})
consoleLayout=new("UIListLayout",consoleScroll,{Padding=UDim.new(0,5),SortOrder=Enum.SortOrder.LayoutOrder})
consoleLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    consoleScroll.CanvasSize=UDim2.fromOffset(0,consoleLayout.AbsoluteContentSize.Y+10)
    task.defer(function()
        if consoleScroll.Parent then
            consoleScroll.CanvasPosition=Vector2.new(0,math.max(0,consoleLayout.AbsoluteContentSize.Y-consoleScroll.AbsoluteSize.Y+16))
        end
    end)
end)
local function logColor(level)
    return level=="ERROR" and P.error or (level=="WARN" and P.warn or
        (level=="RUN" and accent or (level=="PRINT" and P.green or P.muted)))
end
addLog=function(level,message)
    message=tostring(message)
    local time=os.date("%H:%M:%S")
    local item={kind=level,msg=message,time=time}
    table.insert(logs,item)
    if #logs>100 then table.remove(logs,1) end
    if not consoleScroll then return end
    local card=pane(consoleScroll,{Name="LogLine",Size=UDim2.new(1,-4,0,40),
        BackgroundColor3=P.pane,LayoutOrder=#logs},7)
    local col=logColor(level)
    local stripe=new("Frame",card,{BackgroundColor3=col,BorderSizePixel=0,
        Size=UDim2.fromOffset(3,22),Position=UDim2.fromOffset(0,9)})
    corner(stripe,2)
    label(card,level,9,col,true,{Position=UDim2.fromOffset(12,4),Size=UDim2.fromOffset(52,18)})
    label(card,time,9,P.faint,false,{Position=UDim2.new(1,-76,0,4),Size=UDim2.fromOffset(68,18),
        TextXAlignment=Enum.TextXAlignment.Right})
    local content=label(card,message,11,P.text,false,
        {Position=UDim2.fromOffset(12,22),Size=UDim2.new(1,-24,0,16),
        TextWrapped=true,TextYAlignment=Enum.TextYAlignment.Top})
    local estimated=math.max(1,math.ceil(#message/math.max(20,math.floor((consoleScroll.AbsoluteSize.X-38)/6.5))))
    card.Size=UDim2.new(1,-4,0,math.max(45,28+estimated*14))
    content.Size=UDim2.new(1,-24,1,-24)
    local children={}
    for _, obj in ipairs(consoleScroll:GetChildren()) do
        if obj.Name=="LogLine" then table.insert(children,obj) end
    end
    if #children>100 then children[1]:Destroy() end
end
clearLogs.Activated:Connect(function()
    table.clear(logs)
    for _,obj in ipairs(consoleScroll:GetChildren()) do
        if obj.Name=="LogLine" then obj:Destroy() end
    end
    notify("Console cleared")
end)
copyLogs.Activated:Connect(function()
    local arr={}
    for _,entry in ipairs(logs) do table.insert(arr,"["..entry.time.."] ["..entry.kind.."] "..entry.msg) end
    copyText(table.concat(arr,"\n"))
end)

local function executeCode(source)
    if not source or source:match("^%s*$") then
        notify("Editor is empty");return
    end
    runCount+=1
    local thisRun=runCount
    addLog("RUN","Run #"..thisRun.." started ("..tostring(#source).." bytes)")
    statusInfo.Text="RUNNING"
    notify("Executing script #"..thisRun)
    task.spawn(function()
        local loader=loadstring
        if type(loader)=="function" then
            local ok, chunk, compileError=pcall(loader,source)
            if not ok then
                addLog("ERROR","Loader failed: "..tostring(chunk))
            elseif type(chunk)~="function" then
                addLog("ERROR",tostring(compileError or "Compilation failed"))
            else
                -- Prefer a per-chunk environment, never replace global print/warn.
                -- Some native executors do not support setfenv on their chunks;
                -- in those cases, run status and errors still work.
                if type(getfenv)=="function" and type(setfenv)=="function" then
                    local okEnv,baseEnv=pcall(getfenv,chunk)
                    if okEnv and type(baseEnv)=="table" then
                        local originalPrint=baseEnv.print or print
                        local originalWarn=baseEnv.warn or warn
                        local function captured(kind,...)
                            local parts={}
                            for i=1,select("#",...) do
                                local okText,value=pcall(tostring,select(i,...))
                                parts[i]=okText and value or "<unprintable>"
                            end
                            pcall(addLog,kind,table.concat(parts,"  "))
                        end
                        local scoped=setmetatable({
                            print=function(...)
                                captured("PRINT",...)
                                return originalPrint(...)
                            end,
                            warn=function(...)
                                captured("WARN",...)
                                if type(originalWarn)=="function" then return originalWarn(...) end
                            end,
                        },{__index=baseEnv,__newindex=baseEnv})
                        pcall(setfenv,chunk,scoped)
                    end
                end
                local values=table.pack(pcall(chunk))
                if values[1] then
                    addLog("INFO","Run #"..thisRun.." returned successfully"..
                        (values.n>1 and (" | result: "..tostring(values[2])) or ""))
                else
                    addLog("ERROR",tostring(values[2]))
                    showPage("Console")
                end
            end
        else
            local environment=nil
            if type(getgenv)=="function" then
                local ok,env=pcall(getgenv)
                if ok and type(env)=="table" then environment=env end
            end
            local runner=(environment and environment.runcode) or runcode
            if type(runner)=="function" then
                local ok,err=pcall(runner,source)
                addLog(ok and "INFO" or "ERROR",ok and "Script sent to executor backend" or tostring(err))
            else
                addLog("ERROR","No loadstring() or runcode() available in this environment")
                showPage("Console")
            end
        end
        statusInfo.Text="LUAU"
    end)
end
runButton.Activated:Connect(function() executeCode(codeBox.Text) end)

--[[ LIBRARY -- source is always opened for review, never auto-run. ]]
local libPage=pageItems.Library
label(libPage,"SAVED SCRIPTS",14,P.text,true,
    {Position=UDim2.fromOffset(17,12),Size=UDim2.new(1,-145,0,27)})
local libSave=button(libPage,"+ SAVE",{Position=UDim2.new(1,-96,0,10),Size=UDim2.fromOffset(82,32)})
libSave.Activated:Connect(saveToLibrary)
local searchContainer=pane(libPage,{Position=UDim2.fromOffset(13,53),
    Size=UDim2.new(1,-26,0,40),BackgroundColor3=P.raised},9)
librarySearch=new("TextBox",searchContainer,{BackgroundTransparency=1,Text="",
    Font=Enum.Font.Gotham,TextSize=12,PlaceholderText="Search your saved scripts...",
    PlaceholderColor3=P.faint,TextColor3=P.text,ClearTextOnFocus=false,
    Position=UDim2.fromOffset(12,0),Size=UDim2.new(1,-24,1,0),TextXAlignment=Enum.TextXAlignment.Left})
libraryScroll=new("ScrollingFrame",libPage,{BackgroundTransparency=1,BorderSizePixel=0,
    Position=UDim2.fromOffset(12,103),Size=UDim2.new(1,-24,1,-114),
    ScrollBarThickness=3,ScrollBarImageColor3=P.faint,CanvasSize=UDim2.new()})
libraryLayout=new("UIListLayout",libraryScroll,{Padding=UDim.new(0,8),SortOrder=Enum.SortOrder.LayoutOrder})
libraryLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    libraryScroll.CanvasSize=UDim2.fromOffset(0,libraryLayout.AbsoluteContentSize.Y+6)
end)
renderLibrary=function()
    if not libraryScroll then return end
    for _,child in ipairs(libraryScroll:GetChildren()) do
        if child:IsA("Frame") or child:IsA("TextLabel") then child:Destroy() end
    end
    local query=(librarySearch and librarySearch.Text or ""):lower()
    local shown=0
    for index,item in ipairs(library) do
        if query=="" or item.name:lower():find(query,1,true) then
            shown+=1
            local card=pane(libraryScroll,{Size=UDim2.new(1,-3,0,73),LayoutOrder=index,
                BackgroundColor3=P.pane},10)
            local titleLabel=label(card,item.name,12,P.text,true,
                {Position=UDim2.fromOffset(12,7),Size=UDim2.new(1,-190,0,26),
                TextTruncate=Enum.TextTruncate.AtEnd})
            label(card,tostring(#item.source).." chars  •  saved script",10,P.muted,false,
                {Position=UDim2.fromOffset(12,36),Size=UDim2.new(1,-177,0,19)})
            local open=button(card,"OPEN",{Position=UDim2.new(1,-149,0,19),Size=UDim2.fromOffset(69,34)},"accent")
            local del=button(card,"×",{Position=UDim2.new(1,-72,0,19),Size=UDim2.fromOffset(58,34),TextSize=18})
            open.Activated:Connect(function()
                if newTab(item.name,item.source) then notify("Opened "..item.name) end
            end)
            del.Activated:Connect(function()
                askModal("Delete script?","Remove '"..item.name.."' from your saved library?",
                    "","DELETE",function()
                        table.remove(library,index)
                        hideModal();renderLibrary();scheduleSave();notify("Script deleted")
                    end,false)
            end)
        end
    end
    if shown==0 then
        label(libraryScroll,#library==0 and "No saved scripts yet. Save one from the editor." or "No matching scripts.",
            12,P.muted,false,{Size=UDim2.new(1,0,0,58),TextXAlignment=Enum.TextXAlignment.Center})
    end
end
librarySearch:GetPropertyChangedSignal("Text"):Connect(renderLibrary)

--[[ DISCOVER -- Basalt-style ScriptBlox explorer; LOAD for review, not auto-run. ]]
local discover=pageItems.Discover
label(discover,"SCRIPT EXPLORER",14,P.text,true,
    {Position=UDim2.fromOffset(17,10),Size=UDim2.new(1,-26,0,29)})
label(discover,"Search ScriptBlox and inspect source before execution",10,P.muted,false,
    {Position=UDim2.fromOffset(17,33),Size=UDim2.new(1,-26,0,20),TextTruncate=Enum.TextTruncate.AtEnd})
local searchRow=pane(discover,{Position=UDim2.fromOffset(12,66),Size=UDim2.new(1,-24,0,43),
    BackgroundColor3=P.raised},10)
searchInput=new("TextBox",searchRow,{BackgroundTransparency=1,Text="",
    PlaceholderText="Search scripts...",PlaceholderColor3=P.faint,
    ClearTextOnFocus=false,Font=Enum.Font.Gotham,TextSize=12,
    TextColor3=P.text,TextXAlignment=Enum.TextXAlignment.Left,
    Position=UDim2.fromOffset(13,0),Size=UDim2.new(1,-106,1,0)})
local searchButton=button(searchRow,"SEARCH",{Position=UDim2.new(1,-89,0,5),Size=UDim2.fromOffset(83,33)},"accent")
resultInfo=label(discover,"Enter a search to browse public scripts.",11,P.faint,false,
    {Position=UDim2.fromOffset(17,117),Size=UDim2.new(1,-30,0,25)})
resultScroll=new("ScrollingFrame",discover,{BackgroundTransparency=1,
    Position=UDim2.fromOffset(12,146),Size=UDim2.new(1,-24,1,-160),
    BorderSizePixel=0,CanvasSize=UDim2.new(),ScrollBarThickness=3,
    ScrollBarImageColor3=P.muted})
resultLayout=new("UIListLayout",resultScroll,{Padding=UDim.new(0,8),SortOrder=Enum.SortOrder.LayoutOrder})
resultLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    resultScroll.CanvasSize=UDim2.fromOffset(0,resultLayout.AbsoluteContentSize.Y+8)
end)
local function getResponse(url)
    local requester=request or http_request or (type(syn)=="table" and syn.request)
    if type(requester)=="function" then
        local ok,res=pcall(requester,{Url=url,Method="GET",Headers={Accept="application/json"}})
        if ok and type(res)=="table" and type(res.Body)=="string" then
            if res.StatusCode and tonumber(res.StatusCode)>=400 then return nil,"HTTP "..tostring(res.StatusCode) end
            return res.Body
        end
    end
    local ok,body=pcall(function()return game:HttpGet(url)end)
    if ok and type(body)=="string" then return body end
    return nil,"HTTP requests are not supported"
end
local searchSerial=0
local function searchScripts()
    local q=searchInput.Text:match("^%s*(.-)%s*$")
    if q=="" then notify("Enter a search query");return end
    searchSerial+=1
    local serial=searchSerial
    resultInfo.Text="Searching ScriptBlox..."
    for _,child in ipairs(resultScroll:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end
    task.spawn(function()
        local url="https://scriptblox.com/api/script/search?q="..HttpService:UrlEncode(q).."&max=20&mode=free"
        local body,err=getResponse(url)
        if serial~=searchSerial then return end
        if not body then resultInfo.Text="Search unavailable: "..tostring(err);addLog("WARN",resultInfo.Text);return end
        local data=jsonDecode(body)
        local scripts=data and data.result and data.result.scripts
        if type(scripts)~="table" then resultInfo.Text="No readable ScriptBlox results";return end
        resultInfo.Text=tostring(#scripts).." scripts found — tap LOAD to inspect code"
        for index,entry in ipairs(scripts) do
            local name=tostring(entry.title or "Untitled Script"):sub(1,80)
            local source=entry.script
            local isUsable=type(source)=="string" and #source>0 and #source<200000
            local card=pane(resultScroll,{Size=UDim2.new(1,-3,0,83),LayoutOrder=index},10)
            label(card,name,12,P.text,true,
                {Position=UDim2.fromOffset(12,8),Size=UDim2.new(1,-105,0,29),
                TextTruncate=Enum.TextTruncate.AtEnd})
            local meta=tostring(entry.game and entry.game.name or "Community script")
            label(card,meta:sub(1,66),10,P.muted,false,
                {Position=UDim2.fromOffset(12,40),Size=UDim2.new(1,-107,0,23),
                TextTruncate=Enum.TextTruncate.AtEnd})
            local load=button(card,isUsable and "LOAD" or "N/A",{
                Position=UDim2.new(1,-89,0,23),Size=UDim2.fromOffset(75,35)},isUsable and "accent" or nil)
            load.Activated:Connect(function()
                if not isUsable then notify("No source available for this script");return end
                if newTab(name,source) then notify("Source loaded for review") end
            end)
        end
    end)
end
searchButton.Activated:Connect(searchScripts)
searchInput.FocusLost:Connect(function(enter) if enter then searchScripts() end end)

--[[ SETTINGS ]]
local settings=pageItems.Settings
label(settings,"APPEARANCE",14,P.text,true,
    {Position=UDim2.fromOffset(17,14),Size=UDim2.new(1,-34,0,30)})
local settingsScroll=new("ScrollingFrame",settings,{BackgroundTransparency=1,
    Position=UDim2.fromOffset(12,52),Size=UDim2.new(1,-24,1,-64),
    BorderSizePixel=0,CanvasSize=UDim2.new(),ScrollBarThickness=3,
    ScrollBarImageColor3=P.faint})
local settingsLayout=new("UIListLayout",settingsScroll,{Padding=UDim.new(0,10),SortOrder=Enum.SortOrder.LayoutOrder})
settingsLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    settingsScroll.CanvasSize=UDim2.fromOffset(0,settingsLayout.AbsoluteContentSize.Y+12)
end)
local function settingCard(order,name,desc,height)
    local f=pane(settingsScroll,{Size=UDim2.new(1,-3,0,height or 76),LayoutOrder=order},11)
    label(f,name,12,P.text,true,{Position=UDim2.fromOffset(13,10),Size=UDim2.new(1,-26,0,23)})
    label(f,desc,10,P.muted,false,{Position=UDim2.fromOffset(13,32),
        Size=UDim2.new(1,-26,0,20),TextTruncate=Enum.TextTruncate.AtEnd})
    return f
end
local themeCard=settingCard(1,"Accent colour","Minimal dark UI with subtle accent",112)
local themes={}
for i,k in ipairs({"Ice","Mint","Violet"}) do
    local b=button(themeCard,k:upper(),{Position=UDim2.new((i-1)/3,13+(i-1)*-1,1,-47),
        Size=UDim2.new(1/3,-17,0,34),TextSize=10})
    themes[k]=b
    b.Activated:Connect(function()
        currentTheme=k;accent=ACCENTS[k];refreshTheme();scheduleSave();notify(k.." theme selected")
    end)
end
local fontCard=settingCard(2,"Editor font size","Change the monospaced code editor scale",86)
local sizeIndicator=label(fontCard,tostring(fontSize).." px",12,P.text,true,
    {Position=UDim2.new(1,-130,0,37),Size=UDim2.fromOffset(56,32),TextXAlignment=Enum.TextXAlignment.Center})
local fontDown=button(fontCard,"−",{Position=UDim2.new(1,-167,0,39),Size=UDim2.fromOffset(32,29),TextSize=17})
local fontUp=button(fontCard,"+",{Position=UDim2.new(1,-62,0,39),Size=UDim2.fromOffset(36,29),TextSize=17})
local function adjustFont(d)
    fontSize=math.clamp(fontSize+d,11,19)
    sizeIndicator.Text=tostring(fontSize).." px"
    lastW,lastH=0,0;refreshCodeGeometry();scheduleSave()
end
fontDown.Activated:Connect(function()adjustFont(-1)end)
fontUp.Activated:Connect(function()adjustFont(1)end)
local syntaxCard=settingCard(3,"Syntax colours","Highlight keywords, numbers and comments",85)
local syntaxToggle=button(syntaxCard,"",{Position=UDim2.new(1,-91,0,41),Size=UDim2.fromOffset(77,31)})
local function refreshSyntax()
    syntaxToggle.Text=syntaxEnabled and "ON" or "OFF"
    syntaxToggle.TextColor3=syntaxEnabled and accent or P.muted
    refreshCodeGeometry()
end
syntaxToggle.Activated:Connect(function() syntaxEnabled=not syntaxEnabled;refreshSyntax();scheduleSave() end)
local animationCard=settingCard(4,"Animations","Smooth transitions and microinteractions",85)
local animToggle=button(animationCard,"",{Position=UDim2.new(1,-91,0,41),Size=UDim2.fromOffset(77,31)})
local function refreshAnimation()
    animToggle.Text=animationsEnabled and "ON" or "OFF"
    animToggle.TextColor3=animationsEnabled and accent or P.muted
end
animToggle.Activated:Connect(function()
    animationsEnabled=not animationsEnabled;refreshAnimation();scheduleSave()
end)
local storageCard=settingCard(5,"Workspace storage","Tabs and saved scripts are stored when file APIs exist",90)
local storageStatus=label(storageCard,type(writefile)=="function" and "PERSISTENCE AVAILABLE" or "SESSION ONLY — FILE API UNAVAILABLE",
    10,type(writefile)=="function" and P.green or P.warn,true,
    {Position=UDim2.fromOffset(13,59),Size=UDim2.new(1,-20,0,18)})
refreshTheme=function()
    for _,a in ipairs(accentItems) do
        if a.obj and a.obj.Parent then
            a.obj[a.prop]=accent
            if a.obj==brandMark then
                local g=brandMark:FindFirstChildOfClass("UIGradient")
                if g then g.Color=ColorSequence.new(accent,accent:Lerp(Color3.new(0,0,0),.35)) end
            end
        end
    end
    for name,entry in pairs(navItems) do
        entry.icon.TextColor3=name==activePage and accent or P.muted
    end
    for name,b in pairs(themes) do
        b.BackgroundColor3=name==currentTheme and accent or P.raised
        b.TextColor3=name==currentTheme and P.backdrop or P.muted
    end
    refreshSyntax();refreshAnimation();renderTabs()
end

-- Size the whole experience for narrow portrait phones and wide landscape screens.
local viewportWidth, viewportHeight=740,480
local function updateLayout()
    Camera=workspace.CurrentCamera or Camera
    local vp=Camera and Camera.ViewportSize or Vector2.new(900,600)
    viewportWidth,viewportHeight=vp.X,vp.Y
    local portrait=vp.Y>vp.X*1.1
    local baseW=portrait and 426 or 808
    local baseH=portrait and 666 or 470
    local fit=math.min(1,(vp.X-22)/baseW,(vp.Y-28)/baseH)
    fit=math.max(.38,fit)
    dialogScale.Scale=math.clamp(math.min((vp.X-24)/330,(vp.Y-22)/208),.70,1)
    main.Size=UDim2.fromOffset(baseW,baseH)
    mainScale.Scale=fit
    local available=baseW-66-24
    local actions={runButton,saveButton,pasteButton,copyButton,clearButton}
    local gap=6*4
    local desired={109,65,65,65,65}
    local sum=0
    for _,w in ipairs(desired) do sum+=w end
    local proportion=math.min(1,(available-gap)/sum)
    for i,b in ipairs(actions) do
        b.Size=UDim2.fromOffset(math.floor(desired[i]*proportion),41)
    end
    lastW,lastH=0,0
    task.defer(refreshCodeGeometry)
end
updateLayout()
if Camera then track(Camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateLayout)) end
track(workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
    Camera=workspace.CurrentCamera
    updateLayout()
    if Camera then track(Camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateLayout)) end
end))

-- Touch + mouse dragging with viewport bounds and floating-toggle safeguards.
local function connectDrag(handle,target,isLauncher)
    local pressed,origin,startPos,moved=false,nil,nil,false
    local suppressClick=false
    handle.InputBegan:Connect(function(input)
        if input.UserInputType==Enum.UserInputType.Touch or input.UserInputType==Enum.UserInputType.MouseButton1 then
            pressed=true; origin=input.Position; startPos=target.Position; moved=false
            local ended
            ended=input.Changed:Connect(function()
                if input.UserInputState==Enum.UserInputState.End then
                    pressed=false
                    if moved then
                        suppressClick=true
                        task.delay(.2,function() suppressClick=false end)
                    end
                    if ended then ended:Disconnect() end
                end
            end)
        end
    end)
    track(UIS.InputChanged:Connect(function(input)
        if not pressed then return end
        if input.UserInputType~=Enum.UserInputType.MouseMovement and
           input.UserInputType~=Enum.UserInputType.Touch then return end
        local delta=input.Position-origin
        if delta.Magnitude>7 then moved=true end
        local vp=Camera and Camera.ViewportSize or Vector2.new(800,600)
        local x=startPos.X.Scale*vp.X+startPos.X.Offset+delta.X
        local y=startPos.Y.Scale*vp.Y+startPos.Y.Offset+delta.Y
        local margin=isLauncher and 27 or 52
        x=math.clamp(x,margin,math.max(margin,vp.X-margin))
        y=math.clamp(y,margin,math.max(margin,vp.Y-margin))
        if isLauncher then
            target.Position=UDim2.fromOffset(x,y)
        else
            target.Position=UDim2.new(.5,x-vp.X*.5,.5,y-vp.Y*.5)
        end
    end))
    return function() return suppressClick or moved end
end
connectDrag(top,main,false)
local launcherDragged=connectDrag(orb,orb,true)
local function toggleWindow(visible)
    main.Visible=visible
    backdrop.Visible=false
    orb.Visible=not visible
    if visible then updateLayout() end
end
minimize.Activated:Connect(function()toggleWindow(false)end)
orb.Activated:Connect(function()
    if not launcherDragged() then toggleWindow(true) end
end)
close.Activated:Connect(function()
    saveWorkspace()
    screen:Destroy()
end)

track(UIS.InputBegan:Connect(function(input,processed)
    local control=UIS:IsKeyDown(Enum.KeyCode.LeftControl) or UIS:IsKeyDown(Enum.KeyCode.RightControl)
    if not control then return end
    if input.KeyCode==Enum.KeyCode.Return then executeCode(codeBox.Text)
    elseif input.KeyCode==Enum.KeyCode.S then saveToLibrary()
    elseif input.KeyCode==Enum.KeyCode.N then newTab() end
end))

-- Startup
updateEditor()
renderLibrary()
refreshTheme()
showPage("Editor")
addLog("INFO","Aether workspace initialized")
addLog("INFO",type(loadstring)=="function" and "loadstring() available" or
    "loadstring() unavailable; a native runcode backend may be needed")
if type(writefile)~="function" then addLog("WARN","File APIs unavailable: library is session-only") end
notify("Aether is ready")
