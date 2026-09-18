--[[
    ScrapperLoader.lua
    ------------------
    Public bootstrap loader for the Private Inspector.

    Public:
        Miyou00/Loader/main/ScrapperLoader.lua

    Private source:
        Retrieved only through the Cloudflare Worker.

    Flow:
        1. Identify the current Roblox UserId.
        2. Ask the Worker for a source token.
        3. If the account already has an active 24-hour activation,
           the Worker returns a fresh 5-minute source token immediately.
        4. If no activation exists, show the license panel.
        5. Submit the new PWF license key to the Worker.
        6. Fetch the private Inspector source using the one-time token.
        7. Execute the returned source.

    IMPORTANT:
        This loader does not contain the GitHub PAT or PWF App Secret.
        The X-HWID value below is NOT a real hardware ID. Delta does not
        expose a confirmed hardware-ID API. It is an account-bound identity
        so it must not be described as hardware binding.
]]

------------------------------------------------------------
-- CONFIG
------------------------------------------------------------

local WORKER_URL = "https://private-inspector.psychepsycho851.workers.dev"
local SCRIPT_VERSION = "2.7.0"
local MAX_SOURCE_BYTES = 2 * 1024 * 1024

------------------------------------------------------------
-- SERVICES
------------------------------------------------------------

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
if not player then
    return
end

local playerGui = player:WaitForChild("PlayerGui")

------------------------------------------------------------
-- IDENTITY
------------------------------------------------------------

local userId = tostring(player.UserId)
local jobId = tostring(game.JobId or "")

-- Delta does not expose a confirmed genuine hardware-ID API.
-- These values are account-bound identifiers, not hardware fingerprints.
local deviceId = "rbx-user-" .. userId
local hwid = "rbx-user-hwid-" .. userId

------------------------------------------------------------
-- HTTP
------------------------------------------------------------

local function encodeJSON(value)
    local ok, result = pcall(function()
        return HttpService:JSONEncode(value)
    end)

    if ok and type(result) == "string" then
        return result
    end

    return "{}"
end

local function decodeJSON(value)
    if type(value) ~= "string" or value == "" then
        return nil
    end

    local ok, result = pcall(function()
        return HttpService:JSONDecode(value)
    end)

    if ok and type(result) == "table" then
        return result
    end

    return nil
end

local function workerHeaders(extra)
    local headers = {
        ["Content-Type"] = "application/json",
        ["Cache-Control"] = "no-cache",
        ["X-Client-Version"] = SCRIPT_VERSION,
        ["X-User-Id"] = userId,
        ["X-Job-Id"] = jobId,
        ["X-Device-Id"] = deviceId,
        ["X-HWID"] = hwid,
    }

    for key, value in pairs(extra or {}) do
        headers[key] = value
    end

    return headers
end

local function postWorker(path, payload, extraHeaders)
    local body = encodeJSON(payload or {})
    local headers = workerHeaders(extraHeaders)

    local ok, result = pcall(function()
        return game:HttpPost(
            WORKER_URL .. path,
            body,
            "application/json",
            headers
        )
    end)

    if not ok then
        return nil, "Worker request failed: " .. tostring(result)
    end

    local data = decodeJSON(result)

    if not data then
        return nil, "Worker returned invalid JSON."
    end

    return data
end

local function getSource(token)
    if type(token) ~= "string" or token == "" then
        return nil, "Missing source token."
    end

    local ok, result = pcall(function()
        return game:HttpGet(
            WORKER_URL .. "/script",
            true,
            workerHeaders({
                ["Authorization"] = "Bearer " .. token,
            })
        )
    end)

    if not ok then
        -- Delta builds that do not accept the header form above cannot
        -- retrieve the protected /script endpoint safely.
        return nil, "Private source request failed: " .. tostring(result)
    end

    if type(result) ~= "string" or result == "" then
        return nil, "Private source was empty."
    end

    if #result > MAX_SOURCE_BYTES then
        return nil, "Private source exceeded the configured size limit."
    end

    return result
end

------------------------------------------------------------
-- UI
------------------------------------------------------------

local existing = playerGui:FindFirstChild("ScrapperLoader")
if existing then
    existing:Destroy()
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ScrapperLoader"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
screenGui.DisplayOrder = 2147483647
screenGui.Parent = playerGui

local function round(object, radius)
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, radius or 8)
    corner.Parent = object
end

local function addStroke(object, color, transparency, thickness)
    local stroke = Instance.new("UIStroke")
    stroke.Color = color or Color3.fromRGB(55, 62, 74)
    stroke.Transparency = transparency or 0
    stroke.Thickness = thickness or 1
    stroke.Parent = object
end

local THEME = {
    bg = Color3.fromRGB(15, 17, 21),
    panel = Color3.fromRGB(20, 23, 28),
    panel2 = Color3.fromRGB(24, 27, 33),
    surface = Color3.fromRGB(29, 33, 40),
    stroke = Color3.fromRGB(55, 62, 74),
    text = Color3.fromRGB(240, 243, 247),
    muted = Color3.fromRGB(151, 160, 174),
    accent = Color3.fromRGB(92, 151, 255),
    success = Color3.fromRGB(100, 220, 140),
    error = Color3.fromRGB(245, 100, 100),
}

local overlay = Instance.new("Frame")
overlay.Name = "LicenseGate"
overlay.Size = UDim2.fromScale(1, 1)
overlay.BackgroundColor3 = THEME.bg
overlay.BorderSizePixel = 0
overlay.ZIndex = 100
overlay.Parent = screenGui

local panel = Instance.new("Frame")
panel.Name = "KeyPanel"
panel.Size = UDim2.fromOffset(430, 270)
panel.Position = UDim2.new(0.5, 0, 0.5, 0)
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.BackgroundColor3 = THEME.panel2
panel.BorderSizePixel = 0
panel.ZIndex = 101
panel.Parent = overlay
round(panel, 10)
addStroke(panel, THEME.stroke, 0, 1)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -40, 0, 32)
title.Position = UDim2.fromOffset(20, 18)
title.BackgroundTransparency = 1
title.Text = "Private Inspector"
title.TextColor3 = THEME.text
title.TextSize = 20
title.Font = Enum.Font.GothamBold
title.TextXAlignment = Enum.TextXAlignment.Left
title.ZIndex = 102
title.Parent = panel

local subtitle = Instance.new("TextLabel")
subtitle.Size = UDim2.new(1, -40, 0, 48)
subtitle.Position = UDim2.fromOffset(20, 55)
subtitle.BackgroundTransparency = 1
subtitle.Text = "Checking your activation..."
subtitle.TextColor3 = THEME.muted
subtitle.TextSize = 12
subtitle.Font = Enum.Font.Gotham
subtitle.TextWrapped = true
subtitle.TextXAlignment = Enum.TextXAlignment.Left
subtitle.TextYAlignment = Enum.TextYAlignment.Top
subtitle.ZIndex = 102
subtitle.Parent = panel

local userLabel = Instance.new("TextLabel")
userLabel.Size = UDim2.new(1, -40, 0, 20)
userLabel.Position = UDim2.fromOffset(20, 91)
userLabel.BackgroundTransparency = 1
userLabel.Text = "Roblox UserId: " .. userId
userLabel.TextColor3 = THEME.muted
userLabel.TextSize = 10
userLabel.Font = Enum.Font.Gotham
userLabel.TextXAlignment = Enum.TextXAlignment.Left
userLabel.ZIndex = 102
userLabel.Parent = panel

local input = Instance.new("TextBox")
input.Name = "LicenseKey"
input.Size = UDim2.new(1, -40, 0, 42)
input.Position = UDim2.fromOffset(20, 121)
input.BackgroundColor3 = THEME.surface
input.BorderSizePixel = 0
input.TextColor3 = THEME.text
input.PlaceholderColor3 = THEME.muted
input.PlaceholderText = "Enter your PWF license key"
input.Text = ""
input.ClearTextOnFocus = false
input.TextSize = 12
input.Font = Enum.Font.Gotham
input.TextXAlignment = Enum.TextXAlignment.Left
input.ZIndex = 102
input.Parent = panel
round(input, 6)

local padding = Instance.new("UIPadding")
padding.PaddingLeft = UDim.new(0, 12)
padding.PaddingRight = UDim.new(0, 12)
padding.Parent = input

local status = Instance.new("TextLabel")
status.Size = UDim2.new(1, -40, 0, 26)
status.Position = UDim2.fromOffset(20, 168)
status.BackgroundTransparency = 1
status.Text = ""
status.TextColor3 = THEME.muted
status.TextSize = 11
status.Font = Enum.Font.Gotham
status.TextXAlignment = Enum.TextXAlignment.Left
status.ZIndex = 102
status.Parent = panel

local activate = Instance.new("TextButton")
activate.Name = "Activate"
activate.Size = UDim2.fromOffset(120, 38)
activate.Position = UDim2.new(1, -140, 1, -54)
activate.BackgroundColor3 = THEME.accent
activate.BorderSizePixel = 0
activate.Text = "Activate"
activate.TextColor3 = Color3.fromRGB(255, 255, 255)
activate.TextSize = 12
activate.Font = Enum.Font.GothamSemibold
activate.AutoButtonColor = true
activate.ZIndex = 102
activate.Parent = panel
round(activate, 6)

local close = Instance.new("TextButton")
close.Name = "Close"
close.Size = UDim2.fromOffset(80, 38)
close.Position = UDim2.new(0, 20, 1, -54)
close.BackgroundColor3 = THEME.surface
close.BorderSizePixel = 0
close.Text = "Close"
close.TextColor3 = THEME.text
close.TextSize = 12
close.Font = Enum.Font.GothamMedium
close.AutoButtonColor = true
close.ZIndex = 102
close.Parent = panel
round(close, 6)

local busy = false

local function setStatus(message, kind)
    status.Text = tostring(message or "")

    if kind == "error" then
        status.TextColor3 = THEME.error
    elseif kind == "success" then
        status.TextColor3 = THEME.success
    else
        status.TextColor3 = THEME.muted
    end
end

local function destroyLoaderUI()
    if screenGui and screenGui.Parent then
        screenGui:Destroy()
    end
end

close.Activated:Connect(function()
    destroyLoaderUI()
end)

------------------------------------------------------------
-- SOURCE EXECUTION
------------------------------------------------------------

local function executeSource(source)
    if type(source) ~= "string" or source == "" then
        return false, "Empty Inspector source."
    end

    local compiler = loadstring
    if type(compiler) ~= "function" then
        return false, "loadstring is unavailable in this executor."
    end

    local ok, chunkOrError = pcall(function()
        return compiler(source)
    end)

    if not ok or type(chunkOrError) ~= "function" then
        return false, "Inspector source compilation failed: " .. tostring(chunkOrError)
    end

    local runOk, runError = pcall(chunkOrError)

    if not runOk then
        return false, "Inspector source execution failed: " .. tostring(runError)
    end

    return true
end

------------------------------------------------------------
-- AUTHENTICATION
------------------------------------------------------------

local function fetchWithCurrentActivation()
    setStatus("Checking existing activation...", nil)

    local data, err = postWorker("/token", {
        user_id = userId,
        job_id = jobId,
    })

    if not data then
        return nil, err
    end

    if type(data.token) == "string" and data.token ~= "" then
        return data.token
    end

    return nil, data.error or "AUTHORIZATION_FAILED"
end

local function activateWithLicense()
    if busy then
        return
    end

    local licenseKey = tostring(input.Text or ""):match("^%s*(.-)%s*$")

    if licenseKey == "" then
        setStatus("Enter a PWF license key.", "error")
        return
    end

    if #licenseKey > 128 then
        setStatus("License key is too long.", "error")
        return
    end

    busy = true
    activate.AutoButtonColor = false
    activate.Text = "Checking..."
    setStatus("Activating license...", nil)

    local data, err = postWorker("/token", {
        user_id = userId,
        job_id = jobId,
        license_key = licenseKey,
    })

    if not data then
        setStatus(err or "Worker request failed.", "error")
        busy = false
        activate.AutoButtonColor = true
        activate.Text = "Activate"
        return
    end

    if type(data.token) ~= "string" or data.token == "" then
        local message = data.error or "License activation failed."

        if message == "INVALID_LICENSE" then
            message = "Invalid license key."
        elseif message == "HWID_MISMATCH" then
            message = "This license is bound to another device identity."
        elseif message == "DEVICE_LIMIT" then
            message = "PWF device limit reached."
        elseif message == "LICENSE_EXPIRED" then
            message = "This license has expired."
        elseif message == "LICENSE_BANNED" then
            message = "This license is banned."
        elseif message == "LICENSE_PAUSED" then
            message = "This license is paused."
        end

        setStatus(message, "error")
        busy = false
        activate.AutoButtonColor = true
        activate.Text = "Activate"
        return
    end

    setStatus("Activation successful. Loading Inspector...", "success")

    local source, sourceError = getSource(data.token)

    if not source then
        setStatus(sourceError or "Could not retrieve Inspector.", "error")
        busy = false
        activate.AutoButtonColor = true
        activate.Text = "Activate"
        return
    end

    destroyLoaderUI()

    local ok, executionError = executeSource(source)

    if not ok then
        warn(executionError)
    end
end

activate.Activated:Connect(activateWithLicense)

input.FocusLost:Connect(function(enterPressed)
    if enterPressed then
        activateWithLicense()
    end
end)

------------------------------------------------------------
-- STARTUP
------------------------------------------------------------

task.spawn(function()
    local token, err = fetchWithCurrentActivation()

    if token then
        setStatus("Activation found. Loading Inspector...", "success")

        local source, sourceError = getSource(token)

        if not source then
            setStatus(sourceError or "Could not retrieve Inspector.", "error")
            return
        end

        destroyLoaderUI()

        local ok, executionError = executeSource(source)

        if not ok then
            warn(executionError)
        end

        return
    end

    if err == "LICENSE_REQUIRED"
        or err == "DEVICE_NOT_ENROLLED"
        or err == "DEVICE_ENTITLEMENT_EXPIRED" then

        subtitle.Text =
            "No active 24-hour activation was found.\n" ..
            "Enter a new PWF license key to continue."

        setStatus("License required.", nil)
        input:CaptureFocus()
        return
    end

    subtitle.Text = "Authorization check failed."
    setStatus(tostring(err or "Unknown authorization error."), "error")
end)
