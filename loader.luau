--[[
    NOVA | Mobile Luau Script Workspace
    Standalone Roblox CoreGui UI. No external assets, modules, or requests.

    Requires an environment that permits parenting to CoreGui and provides
    loadstring() to execute editor contents. A normal Roblox LocalScript
    cannot gain those privileges just by running this UI.

    Saved scripts optionally persist when readfile/writefile are available.
    Only execute code you trust.
]]

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")

local GUI_NAME = "NovaMobileWorkspace"
local SAVE_FILE = "nova_mobile_saved_scripts.json"
local WINDOW_W, WINDOW_H = 454, 592

local C = {
    backdrop = Color3.fromRGB(12, 14, 25),
    surface = Color3.fromRGB(20, 23, 39),
    surface2 = Color3.fromRGB(27, 31, 50),
    raised = Color3.fromRGB(33, 38, 60),
    line = Color3.fromRGB(56, 62, 88),
    white = Color3.fromRGB(245, 247, 255),
    muted = Color3.fromRGB(145, 154, 183),
    green = Color3.fromRGB(103, 230, 179),
    yellow = Color3.fromRGB(255, 201, 113),
    red = Color3.fromRGB(255, 119, 145),
}

local accent = Color3.fromRGB(151, 117, 255)
local pages = {}
local tabs = {}
local accentTargets = {}
local buttonColors = setmetatable({}, {__mode = "k"})
local connections = {}
local function track(connection)
    connections[#connections + 1] = connection
    return connection
end
local logs = {}
local saved = {}
local selectedPage = "Editor"
local modalOpen = false
local MAX_LOGS = 110
local appendLog -- forward declaration for early-created UI callbacks

local function new(className, props, parent)
    local obj = Instance.new(className)
    for key, value in pairs(props or {}) do
        obj[key] = value
    end
    if parent then obj.Parent = parent end
    return obj
end

local function round(obj, radius)
    new("UICorner", {CornerRadius = UDim.new(0, radius)}, obj)
    return obj
end

local function outline(obj, transparency, color)
    return new("UIStroke", {
        Color = color or C.line,
        Thickness = 1,
        Transparency = transparency or 0,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    }, obj)
end

local function label(parent, text, size, color, bold, pos, dimensions)
    return new("TextLabel", {
        BackgroundTransparency = 1,
        Position = pos or UDim2.fromOffset(0, 0),
        Size = dimensions or UDim2.fromScale(1, 1),
        Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham,
        Text = text,
        TextSize = size,
        TextColor3 = color,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        TextTruncate = Enum.TextTruncate.AtEnd,
    }, parent)
end

local function tween(target, values, duration)
    local t = TweenService:Create(target,
        TweenInfo.new(duration or 0.17, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), values)
    t:Play()
    return t
end

local function button(parent, text, pos, dimensions, background, foreground, size)
    local b = new("TextButton", {
        Position = pos,
        Size = dimensions,
        BackgroundColor3 = background,
        BorderSizePixel = 0,
        AutoButtonColor = false,
        Text = text,
        TextColor3 = foreground or C.white,
        TextSize = size or 13,
        Font = Enum.Font.GothamBold,
        Selectable = true,
    }, parent)
    round(b, 11)
    buttonColors[b] = background
    b.MouseEnter:Connect(function()
        local base = buttonColors[b] or background
        tween(b, {BackgroundColor3 = base:Lerp(C.white, 0.09)}, 0.14)
    end)
    b.MouseLeave:Connect(function()
        tween(b, {BackgroundColor3 = buttonColors[b] or background}, 0.15)
    end)
    return b
end

local function decorateAccent(obj, property)
    table.insert(accentTargets, {obj = obj, property = property or "BackgroundColor3"})
    obj[property or "BackgroundColor3"] = accent
end

-- CoreGui first; gethui() fallback for runtimes with a different UI container.
local parentContainer = CoreGui
local gui = new("ScreenGui", {
    Name = GUI_NAME,
    ResetOnSpawn = false,
    IgnoreGuiInset = true,
    DisplayOrder = 100000,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
})

local existing = CoreGui:FindFirstChild(GUI_NAME)
if existing then existing:Destroy() end
local mounted = pcall(function() gui.Parent = CoreGui end)
if not mounted and type(gethui) == "function" then
    local ok, container = pcall(gethui)
    if ok and container then
        parentContainer = container
        local duplicate = parentContainer:FindFirstChild(GUI_NAME)
        if duplicate then duplicate:Destroy() end
        mounted = pcall(function() gui.Parent = parentContainer end)
    end
end
if not mounted then
    error("NOVA: This environment cannot create a CoreGui interface.")
end

gui.Destroying:Connect(function()
    for _, connection in ipairs(connections) do
        connection:Disconnect()
    end
    table.clear(connections)
end)

-- Main window and subtle two-layer depth effect.
local main = new("Frame", {
    Name = "Window",
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromOffset(WINDOW_W, WINDOW_H),
    BackgroundColor3 = C.backdrop,
    BorderSizePixel = 0,
    ClipsDescendants = true,
}, gui)
round(main, 22)
outline(main, 0.12)

local scale = new("UIScale", {Scale = 1}, main)
local camera = workspace.CurrentCamera
local targetScale = 1
local function updateScale()
    camera = workspace.CurrentCamera or camera
    local viewport = camera and camera.ViewportSize or Vector2.new(800, 700)
    targetScale = math.min(1, math.max(0.46,
        (viewport.X - 20) / WINDOW_W,
        (viewport.Y - 34) / WINDOW_H))
    scale.Scale = targetScale
end
updateScale()
local viewportConnection
if camera then
    viewportConnection = track(camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale))
end

local accentLine = new("Frame", {
    Size = UDim2.new(1, 0, 0, 3),
    BackgroundColor3 = accent,
    BorderSizePixel = 0,
}, main)
decorateAccent(accentLine)

local header = new("Frame", {
    Name = "DragHandle",
    Position = UDim2.fromOffset(0, 3),
    Size = UDim2.new(1, 0, 0, 75),
    BackgroundTransparency = 1,
    Active = true,
}, main)

local logo = new("Frame", {
    Position = UDim2.fromOffset(16, 15),
    Size = UDim2.fromOffset(45, 45),
    BackgroundColor3 = accent,
    BorderSizePixel = 0,
}, header)
round(logo, 14)
decorateAccent(logo)
local logoText = label(logo, "N", 27, C.backdrop, true)
logoText.TextXAlignment = Enum.TextXAlignment.Center

label(header, "NOVA", 21, C.white, true, UDim2.fromOffset(74, 13), UDim2.fromOffset(210, 29))
label(header, "MOBILE SCRIPT WORKSPACE", 10, C.muted, false,
    UDim2.fromOffset(75, 41), UDim2.fromOffset(250, 17))

local minimize = button(header, "–", UDim2.new(1, -89, 0, 21), UDim2.fromOffset(31, 31), C.surface2, C.white, 22)
local close = button(header, "×", UDim2.new(1, -49, 0, 21), UDim2.fromOffset(31, 31), C.surface2, C.muted, 20)

local statusStrip = new("Frame", {
    Position = UDim2.fromOffset(15, 77),
    Size = UDim2.new(1, -30, 0, 31),
    BackgroundColor3 = C.surface,
    BorderSizePixel = 0,
}, main)
round(statusStrip, 9)
local statusDot = new("Frame", {
    Position = UDim2.fromOffset(12, 12),
    Size = UDim2.fromOffset(7, 7),
    BackgroundColor3 = C.green,
    BorderSizePixel = 0,
}, statusStrip)
round(statusDot, 6)
local statusText = label(statusStrip, "READY  •  LUAU WORKSPACE", 10, C.muted, true,
    UDim2.fromOffset(27, 0), UDim2.new(1, -36, 1, 0))

local nav = new("Frame", {
    Position = UDim2.fromOffset(15, 119),
    Size = UDim2.new(1, -30, 0, 43),
    BackgroundColor3 = C.surface,
    BorderSizePixel = 0,
}, main)
round(nav, 12)

for i, name in ipairs({"Editor", "Scripts", "Console", "Settings"}) do
    local tab = button(nav, name,
        UDim2.new((i - 1) / 4, 3, 0, 4),
        UDim2.new(0.25, -6, 1, -8),
        C.surface, C.muted, 12)
    tabs[name] = tab
end

local body = new("Frame", {
    Position = UDim2.fromOffset(15, 176),
    Size = UDim2.new(1, -30, 1, -265),
    BackgroundTransparency = 1,
}, main)

for _, name in ipairs({"Editor", "Scripts", "Console", "Settings"}) do
    pages[name] = new("Frame", {
        Name = name .. "Page",
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Visible = false,
    }, body)
end

local function sectionHeading(parent, title, subtitle)
    label(parent, title, 13, C.white, true,
        UDim2.fromOffset(3, 0), UDim2.new(0.7, 0, 0, 25))
    return label(parent, subtitle, 10, C.muted, false,
        UDim2.fromOffset(3, 24), UDim2.new(0.92, 0, 0, 19))
end

-- EDITOR --------------------------------------------------------------------
local editorPage = pages.Editor
local editorSubtitle = sectionHeading(editorPage, "CODE EDITOR", "Paste code below, then tap Execute")
editorSubtitle.Size = UDim2.new(0.59, 0, 0, 19)
local linesIndicator = label(editorPage, "1 LINE", 10, C.muted, true,
    UDim2.new(1, -100, 0, 4), UDim2.fromOffset(97, 20))
linesIndicator.TextXAlignment = Enum.TextXAlignment.Right

local editorCard = new("Frame", {
    Position = UDim2.fromOffset(0, 51),
    Size = UDim2.new(1, 0, 1, -51),
    BackgroundColor3 = C.surface,
    BorderSizePixel = 0,
    ClipsDescendants = true,
}, editorPage)
round(editorCard, 13)
outline(editorCard, 0.35)

local codeBox = new("TextBox", {
    Name = "Code",
    Position = UDim2.fromOffset(12, 11),
    Size = UDim2.new(1, -24, 1, -22),
    BackgroundTransparency = 1,
    MultiLine = true,
    ClearTextOnFocus = false,
    Text = "-- Welcome to NOVA\nprint(\"Hello from NOVA!\")",
    PlaceholderText = "-- Enter your Luau code here...",
    PlaceholderColor3 = C.muted,
    Font = Enum.Font.Code,
    TextSize = 14,
    TextColor3 = Color3.fromRGB(224, 231, 255),
    TextXAlignment = Enum.TextXAlignment.Left,
    TextYAlignment = Enum.TextYAlignment.Top,
    TextWrapped = false,
    BorderSizePixel = 0,
}, editorCard)

local function updateLineCount()
    local _, count = codeBox.Text:gsub("\n", "")
    local lines = count + 1
    linesIndicator.Text = tostring(lines) .. (lines == 1 and " LINE" or " LINES")
end
codeBox:GetPropertyChangedSignal("Text"):Connect(updateLineCount)
updateLineCount()

-- Optional clipboard support: no permissions are bypassed if unavailable.
local pasteCode = button(editorPage, "PASTE", UDim2.new(1, -165, 0, 24),
    UDim2.fromOffset(76, 25), C.surface2, C.white, 10)
local copyCode = button(editorPage, "COPY", UDim2.new(1, -82, 0, 24),
    UDim2.fromOffset(76, 25), C.surface2, C.white, 10)
pasteCode.Activated:Connect(function()
    if type(getclipboard) ~= "function" then
        appendLog("Clipboard paste is unavailable in this host.", "warn")
        return
    end
    local ok, value = pcall(getclipboard)
    if ok and type(value) == "string" then
        codeBox.Text = value
        appendLog("Pasted clipboard text into editor.", "success")
    else
        appendLog("Couldn't read clipboard contents.", "warn")
    end
end)
copyCode.Activated:Connect(function()
    if type(setclipboard) ~= "function" then
        appendLog("Clipboard copy is unavailable in this host.", "warn")
        return
    end
    local ok = pcall(setclipboard, codeBox.Text)
    appendLog(ok and "Editor copied to clipboard." or "Couldn't copy editor text.",
        ok and "success" or "warn")
end)

-- SCRIPTS LIBRARY ----------------------------------------------------------
local scriptsPage = pages.Scripts
sectionHeading(scriptsPage, "SCRIPT LIBRARY", "Tap Load to edit, or Run to execute")
local scriptScroll = new("ScrollingFrame", {
    Position = UDim2.fromOffset(0, 52),
    Size = UDim2.new(1, 0, 1, -52),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ScrollBarThickness = 3,
    ScrollBarImageColor3 = accent,
    CanvasSize = UDim2.fromOffset(0, 0),
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
    ScrollingDirection = Enum.ScrollingDirection.Y,
}, scriptsPage)
local scriptLayout = new("UIListLayout", {
    Padding = UDim.new(0, 9),
    SortOrder = Enum.SortOrder.LayoutOrder,
}, scriptScroll)
new("UIPadding", {PaddingRight = UDim.new(0, 5), PaddingBottom = UDim.new(0, 5)}, scriptScroll)

-- CONSOLE ------------------------------------------------------------------
local consolePage = pages.Console
sectionHeading(consolePage, "EXECUTION LOG", "Run results, prints, warnings and errors")
local clearLogs = button(consolePage, "CLEAR LOG", UDim2.new(1, -99, 0, 3),
    UDim2.fromOffset(99, 29), C.surface2, C.muted, 10)
local consoleScroll = new("ScrollingFrame", {
    Position = UDim2.fromOffset(0, 52),
    Size = UDim2.new(1, 0, 1, -52),
    BackgroundColor3 = C.surface,
    BorderSizePixel = 0,
    ScrollBarThickness = 3,
    ScrollBarImageColor3 = accent,
    CanvasSize = UDim2.fromOffset(0, 0),
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
    ScrollingDirection = Enum.ScrollingDirection.Y,
}, consolePage)
round(consoleScroll, 13)
new("UIPadding", {
    PaddingTop = UDim.new(0, 10),
    PaddingBottom = UDim.new(0, 10),
    PaddingLeft = UDim.new(0, 10),
    PaddingRight = UDim.new(0, 10),
}, consoleScroll)
new("UIListLayout", {Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder}, consoleScroll)

local function stringify(...)
    local vals = table.pack(...)
    local parts = {}
    for i = 1, vals.n do
        local ok, str = pcall(tostring, vals[i])
        parts[#parts + 1] = ok and str or "<unprintable>"
    end
    return table.concat(parts, "  ")
end

appendLog = function(message, kind)
    if not consoleScroll.Parent then return end
    local color = C.muted
    if kind == "error" then color = C.red
    elseif kind == "success" then color = C.green
    elseif kind == "warn" then color = C.yellow
    elseif kind == "info" then color = C.white end

    local entry = new("TextLabel", {
        Size = UDim2.new(1, -6, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = C.surface2,
        BorderSizePixel = 0,
        Font = Enum.Font.Code,
        TextSize = 12,
        TextColor3 = color,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        Text = "[" .. os.date("%H:%M:%S") .. "]  " .. tostring(message),
        LayoutOrder = #logs + 1,
    }, consoleScroll)
    round(entry, 8)
    new("UIPadding", {
        PaddingTop = UDim.new(0, 9),
        PaddingBottom = UDim.new(0, 9),
        PaddingLeft = UDim.new(0, 10),
        PaddingRight = UDim.new(0, 9),
    }, entry)
    logs[#logs + 1] = entry
    if #logs > MAX_LOGS then
        local old = table.remove(logs, 1)
        old:Destroy()
    end
    task.defer(function()
        if consoleScroll.Parent then
            consoleScroll.CanvasPosition = Vector2.new(0, 1000000)
        end
    end)
end
clearLogs.Activated:Connect(function()
    for _, entry in ipairs(logs) do entry:Destroy() end
    table.clear(logs)
    appendLog("Log cleared.", "info")
end)

-- EXECUTION: relies on the host's existing loadstring implementation.
-- A per-run environment captures print/warn when getfenv/setfenv work.
local activeExecutions = 0
local function runSource(source)
    if source:match("^%s*$") then
        appendLog("Nothing to execute: the editor is empty.", "warn")
        return
    end
    if type(loadstring) ~= "function" then
        appendLog("loadstring() is unavailable in this environment.", "error")
        return
    end

    appendLog("Compiling script...", "info")
    statusText.Text = "RUNNING  •  LUAU WORKSPACE"
    statusDot.BackgroundColor3 = C.yellow
    activeExecutions += 1

    task.spawn(function()
        local successCompile, chunk, compileError = pcall(loadstring, source)
        if not successCompile then
            appendLog("Compile error: " .. tostring(chunk), "error")
        elseif type(chunk) ~= "function" then
            appendLog("Compile error: " .. tostring(compileError), "error")
        else
            if type(getfenv) == "function" and type(setfenv) == "function" then
                local ok, originalEnv = pcall(getfenv, chunk)
                if ok and type(originalEnv) == "table" then
                    local wrappedEnv = setmetatable({
                        print = function(...)
                            appendLog(stringify(...), "info")
                            return print(...)
                        end,
                        warn = function(...)
                            appendLog(stringify(...), "warn")
                            return warn(...)
                        end,
                    }, {
                        __index = originalEnv,
                        __newindex = originalEnv,
                    })
                    pcall(setfenv, chunk, wrappedEnv)
                end
            end
            local ok, result = pcall(chunk)
            if ok then
                appendLog("Executed successfully." .. (result ~= nil and (" Return: " .. stringify(result)) or ""), "success")
            else
                appendLog("Runtime error: " .. tostring(result), "error")
            end
        end
        activeExecutions -= 1
        if activeExecutions <= 0 and gui.Parent then
            statusText.Text = "READY  •  LUAU WORKSPACE"
            statusDot.BackgroundColor3 = C.green
        end
    end)
end

local examples = {
    {
        name = "Hello World",
        note = "Test script execution and output",
        code = 'print("Hello from NOVA!")',
    },
    {
        name = "Player Details",
        note = "Show your current player name",
        code = 'local p = game:GetService("Players").LocalPlayer\nprint("Player:", p and p.Name or "Unknown")',
    },
    {
        name = "Camera Position",
        note = "Read your camera world position",
        code = 'local c = workspace.CurrentCamera\nprint("Camera position:", c and tostring(c.CFrame.Position) or "Unavailable")',
    },
}

local function loadSaved()
    if type(readfile) ~= "function" then return end
    local ok, raw = pcall(readfile, SAVE_FILE)
    if not ok or type(raw) ~= "string" then return end
    local decodedOK, decoded = pcall(function() return HttpService:JSONDecode(raw) end)
    if not decodedOK or type(decoded) ~= "table" then return end
    for _, record in ipairs(decoded) do
        if type(record) == "table" and type(record.name) == "string" and type(record.code) == "string" then
            saved[#saved + 1] = {name = record.name:sub(1, 40), code = record.code}
        end
        if #saved >= 40 then break end
    end
end

local function persistSaved()
    if type(writefile) ~= "function" then return false, "writefile unavailable" end
    local ok, err = pcall(function()
        writefile(SAVE_FILE, HttpService:JSONEncode(saved))
    end)
    return ok, err
end

local function setPage(name)
    selectedPage = name
    for key, p in pairs(pages) do p.Visible = (key == name) end
    for key, tab in pairs(tabs) do
        buttonColors[tab] = (key == name) and accent or C.surface
        tween(tab, {
            BackgroundColor3 = (key == name) and accent or C.surface,
            TextColor3 = (key == name) and C.backdrop or C.muted,
        }, 0.17)
    end
end

local rebuildScriptLibrary
local function scriptCard(entry, isSaved, index)
    local card = new("Frame", {
        Size = UDim2.new(1, -1, 0, 76),
        LayoutOrder = index,
        BackgroundColor3 = C.surface,
        BorderSizePixel = 0,
    }, scriptScroll)
    round(card, 12)
    outline(card, 0.5)

    label(card, entry.name, 13, C.white, true,
        UDim2.fromOffset(13, 11), UDim2.new(1, -154, 0, 23))
    label(card, isSaved and "SAVED SCRIPT" or entry.note, 10, C.muted, false,
        UDim2.fromOffset(13, 38), UDim2.new(1, -154, 0, 18))

    local loadB = button(card, "LOAD", UDim2.new(1, -135, 0, 22),
        UDim2.fromOffset(58, 32), C.surface2, C.white, 10)
    local runB = button(card, "RUN", UDim2.new(1, -70, 0, 22),
        UDim2.fromOffset(58, 32), accent, C.backdrop, 10)
    loadB.Activated:Connect(function()
        codeBox.Text = entry.code
        setPage("Editor")
        appendLog("Loaded script: " .. entry.name, "info")
    end)
    runB.Activated:Connect(function()
        runSource(entry.code)
        setPage("Console")
    end)
    if isSaved then
        local deleteB = button(card, "×", UDim2.new(1, -29, 0, 3),
            UDim2.fromOffset(23, 19), C.surface2, C.muted, 13)
        deleteB.Activated:Connect(function()
            for i, item in ipairs(saved) do
                if item == entry then
                    table.remove(saved, i)
                    persistSaved()
                    appendLog("Deleted saved script: " .. entry.name, "info")
                    rebuildScriptLibrary()
                    break
                end
            end
        end)
    end
end

rebuildScriptLibrary = function()
    for _, child in ipairs(scriptScroll:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end
    for i, entry in ipairs(saved) do scriptCard(entry, true, i) end
    for i, entry in ipairs(examples) do
        scriptCard(entry, false, #saved + i)
    end
end
loadSaved()
rebuildScriptLibrary()

-- SETTINGS -----------------------------------------------------------------
local settingsPage = pages.Settings
sectionHeading(settingsPage, "PREFERENCES", "Personalize the workspace")

local accentCard = new("Frame", {
    Position = UDim2.fromOffset(0, 54),
    Size = UDim2.new(1, 0, 0, 112),
    BackgroundColor3 = C.surface,
    BorderSizePixel = 0,
}, settingsPage)
round(accentCard, 13)
label(accentCard, "ACCENT COLOR", 12, C.white, true,
    UDim2.fromOffset(15, 10), UDim2.new(1, -30, 0, 26))

local function setAccent(color)
    accent = color
    for _, item in ipairs(accentTargets) do
        if item.obj.Parent then
            buttonColors[item.obj] = color
            tween(item.obj, {[item.property] = color}, 0.22)
        end
    end
    scriptScroll.ScrollBarImageColor3 = color
    consoleScroll.ScrollBarImageColor3 = color
    for _, child in ipairs(scriptScroll:GetDescendants()) do
        if child:IsA("TextButton") and child.Text == "RUN" then
            buttonColors[child] = color
            tween(child, {BackgroundColor3 = color}, 0.22)
        end
    end
    setPage(selectedPage)
end

for i, option in ipairs({
    {"VIOLET", Color3.fromRGB(151, 117, 255)},
    {"CYAN", Color3.fromRGB(91, 206, 245)},
    {"MINT", Color3.fromRGB(103, 230, 179)},
}) do
    local swatch = button(accentCard, option[1], UDim2.new((i - 1) / 3, 12, 0, 55),
        UDim2.new(1 / 3, -19, 0, 41), option[2], C.backdrop, 10)
    swatch.Activated:Connect(function() setAccent(option[2]) end)
end

local aboutCard = new("Frame", {
    Position = UDim2.fromOffset(0, 177),
    Size = UDim2.new(1, 0, 0, 152),
    BackgroundColor3 = C.surface,
    BorderSizePixel = 0,
}, settingsPage)
round(aboutCard, 13)
label(aboutCard, "SYSTEM STATUS", 12, C.white, true,
    UDim2.fromOffset(15, 11), UDim2.new(1, -30, 0, 25))
local lines = {
    "Script runtime", "Saved script storage", "Clipboard support", "Interface host",
}
local values = {
    type(loadstring) == "function" and "AVAILABLE" or "UNAVAILABLE",
    type(readfile) == "function" and type(writefile) == "function" and "PERSISTENT" or "THIS SESSION",
    type(setclipboard) == "function" and "COPY READY" or "NOT AVAILABLE",
    parentContainer == CoreGui and "COREGUI" or "GETHUI",
}
for i = 1, #lines do
    local y = 36 + (i - 1) * 27
    label(aboutCard, lines[i], 11, C.muted, false,
        UDim2.fromOffset(15, y), UDim2.fromOffset(190, 22))
    local v = label(aboutCard, values[i], 10, C.green, true,
        UDim2.new(1, -155, 0, y), UDim2.fromOffset(140, 22))
    v.TextXAlignment = Enum.TextXAlignment.Right
end

-- BOTTOM TOOLBAR -----------------------------------------------------------
local toolbar = new("Frame", {
    Position = UDim2.new(0, 15, 1, -76),
    Size = UDim2.new(1, -30, 0, 59),
    BackgroundColor3 = C.surface,
    BorderSizePixel = 0,
}, main)
round(toolbar, 14)
outline(toolbar, 0.52)

local execute = button(toolbar, "▶  EXECUTE", UDim2.fromOffset(8, 8),
    UDim2.new(0.43, -6, 1, -16), accent, C.backdrop, 13)
decorateAccent(execute)
local clearEditor = button(toolbar, "CLEAR", UDim2.new(0.43, 5, 0, 8),
    UDim2.new(0.26, -6, 1, -16), C.surface2, C.white, 12)
local saveEditor = button(toolbar, "SAVE", UDim2.new(0.69, 7, 0, 8),
    UDim2.new(0.31, -15, 1, -16), C.surface2, C.white, 12)

execute.Activated:Connect(function()
    runSource(codeBox.Text)
    setPage("Console")
end)
clearEditor.Activated:Connect(function()
    codeBox.Text = ""
    setPage("Editor")
    appendLog("Editor cleared.", "info")
end)

local function savePrompt()
    if modalOpen then return end
    modalOpen = true
    local overlay = new("Frame", {
        Name = "SaveDialog",
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Color3.fromRGB(0, 0, 0),
        BackgroundTransparency = 0.25,
        BorderSizePixel = 0,
        Active = true,
        ZIndex = 10,
    }, main)
    local dialog = new("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.new(1, -74, 0, 199),
        BackgroundColor3 = C.surface2,
        BorderSizePixel = 0,
        ZIndex = 11,
    }, overlay)
    round(dialog, 17)
    outline(dialog, 0)
    local title = label(dialog, "SAVE SCRIPT", 15, C.white, true,
        UDim2.fromOffset(18, 12), UDim2.new(1, -30, 0, 28))
    title.ZIndex = 12
    local subtitle = label(dialog, "Choose a name for this script", 11, C.muted, false,
        UDim2.fromOffset(18, 42), UDim2.new(1, -30, 0, 23))
    subtitle.ZIndex = 12
    local nameBox = new("TextBox", {
        Position = UDim2.fromOffset(18, 74),
        Size = UDim2.new(1, -36, 0, 43),
        BackgroundColor3 = C.backdrop,
        TextColor3 = C.white,
        PlaceholderText = "My Script",
        PlaceholderColor3 = C.muted,
        Font = Enum.Font.Gotham,
        TextSize = 14,
        Text = "",
        ClearTextOnFocus = false,
        ZIndex = 12,
    }, dialog)
    round(nameBox, 9)
    local cancel = button(dialog, "CANCEL", UDim2.new(0, 18, 1, -63),
        UDim2.new(0.5, -23, 0, 43), C.raised, C.white, 11)
    local confirm = button(dialog, "SAVE", UDim2.new(0.5, 5, 1, -63),
        UDim2.new(0.5, -23, 0, 43), accent, C.backdrop, 11)
    cancel.ZIndex, confirm.ZIndex = 12, 12
    local function dismiss()
        modalOpen = false
        overlay:Destroy()
    end
    cancel.Activated:Connect(dismiss)
    confirm.Activated:Connect(function()
        local name = nameBox.Text:match("^%s*(.-)%s*$")
        if name == "" then name = "Untitled" end
        name = name:sub(1, 40)
        if codeBox.Text:match("^%s*$") then
            appendLog("Nothing to save: editor is empty.", "warn")
            dismiss()
            return
        end
        local overwritten = false
        for _, item in ipairs(saved) do
            if item.name == name then
                item.code = codeBox.Text
                overwritten = true
                break
            end
        end
        if not overwritten then
            if #saved >= 40 then
                appendLog("Saved-script limit reached (40).", "warn")
                dismiss()
                return
            end
            table.insert(saved, 1, {name = name, code = codeBox.Text})
        end
        local ok = persistSaved()
        rebuildScriptLibrary()
        appendLog((overwritten and "Updated " or "Saved ") .. name ..
            (ok and " to storage." or " for this session."), "success")
        dismiss()
        setPage("Scripts")
    end)
    task.defer(function()
        if nameBox.Parent then nameBox:CaptureFocus() end
    end)
end
saveEditor.Activated:Connect(savePrompt)

-- MINIMIZED LAUNCHER -------------------------------------------------------
local launcher = button(gui, "N", UDim2.new(1, -73, 1, -79),
    UDim2.fromOffset(56, 56), accent, C.backdrop, 26)
launcher.Name = "OpenNova"
launcher.AnchorPoint = Vector2.new(0, 0)
launcher.Visible = false
round(launcher, 19)
decorateAccent(launcher)
outline(launcher, 0.15, C.white)

minimize.Activated:Connect(function()
    main.Visible = false
    launcher.Visible = true
end)
launcher.Activated:Connect(function()
    launcher.Visible = false
    main.Visible = true
    scale.Scale = targetScale * 0.94
    tween(scale, {Scale = targetScale}, 0.22)
end)
close.Activated:Connect(function()
    if viewportConnection then viewportConnection:Disconnect() end
    gui:Destroy()
end)

-- TOUCH + MOUSE DRAG. Drag only from the header, not the code editor.
local dragging = false
local dragStart, windowStart, dragInput
header.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or
       input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        windowStart = main.Position
        dragInput = input
    end
end)
header.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or
       input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end)
track(UserInputService.InputChanged:Connect(function(input)
    if not dragging then return end
    if input.UserInputType == Enum.UserInputType.MouseMovement or input == dragInput then
        local delta = input.Position - dragStart
        main.Position = UDim2.new(windowStart.X.Scale, windowStart.X.Offset + delta.X,
            windowStart.Y.Scale, windowStart.Y.Offset + delta.Y)
    end
end))
track(UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or
       input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end))

for name, tab in pairs(tabs) do
    tab.Activated:Connect(function() setPage(name) end)
end
setPage("Editor")
appendLog("NOVA ready. Only execute code from sources you trust.", "success")
if type(loadstring) ~= "function" then
    appendLog("Script execution requires a loadstring-enabled environment.", "warn")
end

-- Initial entrance animation.
scale.Scale = targetScale * 0.93
tween(scale, {Scale = targetScale}, 0.34)
