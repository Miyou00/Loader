```lua
--[[
    ScrapperLoader.lua
    Private Inspector public bootstrap loader

    Worker:
    https://private-inspector.psychepsycho851.workers.dev

    Client version:
    2.7.0

    The loader intentionally creates its UI BEFORE performing
    any HTTP/authentication work so failures remain visible.
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

-- These are account-bound identifiers.
-- They are NOT genuine hardware fingerprints.
local deviceId = "rbx-user-" .. userId
local hwid = "rbx-user-hwid-" .. userId

------------------------------------------------------------
-- UI
------------------------------------------------------------

local oldGui = playerGui:FindFirstChild("ScrapperLoader")

if oldGui then
    oldGui:Destroy()
end

local gui = Instance.new("ScreenGui")
gui.Name = "ScrapperLoader"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 999999
gui.Parent = playerGui

local background = Instance.new("Frame")
background.Size = UDim2.fromScale(1, 1)
background.BackgroundColor3 = Color3.fromRGB(15, 17, 21)
background.BorderSizePixel = 0
background.Parent = gui

local panel = Instance.new("Frame")
panel.Size = UDim2.fromOffset(440, 285)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.BackgroundColor3 = Color3.fromRGB(24, 27, 33)
panel.BorderSizePixel = 0
panel.Parent = background

local panelCorner = Instance.new("UICorner")
panelCorner.CornerRadius = UDim.new(0, 10)
panelCorner.Parent = panel

local panelStroke = Instance.new("UIStroke")
panelStroke.Color = Color3.fromRGB(55, 62, 74)
panelStroke.Thickness = 1
panelStroke.Parent = panel

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -40, 0, 32)
title.Position = UDim2.fromOffset(20, 18)
title.BackgroundTransparency = 1
title.Text = "Private Inspector"
title.TextColor3 = Color3.fromRGB(240, 243, 247)
title.TextSize = 20
title.Font = Enum.Font.GothamBold
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = panel

local subtitle = Instance.new("TextLabel")
subtitle.Size = UDim2.new(1, -40, 0, 42)
subtitle.Position = UDim2.fromOffset(20, 56)
subtitle.BackgroundTransparency = 1
subtitle.Text = "Starting..."
subtitle.TextColor3 = Color3.fromRGB(151, 160, 174)
subtitle.TextSize = 12
subtitle.Font = Enum.Font.Gotham
subtitle.TextWrapped = true
subtitle.TextXAlignment = Enum.TextXAlignment.Left
subtitle.TextYAlignment = Enum.TextYAlignment.Top
subtitle.Parent = panel

local userLabel = Instance.new("TextLabel")
userLabel.Size = UDim2.new(1, -40, 0, 20)
userLabel.Position = UDim2.fromOffset(20, 96)
userLabel.BackgroundTransparency = 1
userLabel.Text = "Roblox UserId: " .. userId
userLabel.TextColor3 = Color3.fromRGB(151, 160, 174)
userLabel.TextSize = 10
userLabel.Font = Enum.Font.Gotham
userLabel.TextXAlignment = Enum.TextXAlignment.Left
userLabel.Parent = panel

local input = Instance.new("TextBox")
input.Size = UDim2.new(1, -40, 0, 42)
input.Position = UDim2.fromOffset(20, 126)
input.BackgroundColor3 = Color3.fromRGB(29, 33, 40)
input.BorderSizePixel = 0
input.Text = ""
input.PlaceholderText = "Enter your PWF license key"
input.PlaceholderColor3 = Color3.fromRGB(151, 160, 174)
input.TextColor3 = Color3.fromRGB(240, 243, 247)
input.TextSize = 12
input.Font = Enum.Font.Gotham
input.ClearTextOnFocus = false
input.TextXAlignment = Enum.TextXAlignment.Left
input.Parent = panel

local inputCorner = Instance.new("UICorner")
inputCorner.CornerRadius = UDim.new(0, 6)
inputCorner.Parent = input

local inputPadding = Instance.new("UIPadding")
inputPadding.PaddingLeft = UDim.new(0, 12)
inputPadding.PaddingRight = UDim.new(0, 12)
inputPadding.Parent = input

local status = Instance.new("TextLabel")
status.Size = UDim2.new(1, -40, 0, 42)
status.Position = UDim2.fromOffset(20, 176)
status.BackgroundTransparency = 1
status.Text = "Initializing..."
status.TextColor3 = Color3.fromRGB(151, 160, 174)
status.TextSize = 11
status.Font = Enum.Font.Gotham
status.TextWrapped = true
status.TextXAlignment = Enum.TextXAlignment.Left
status.TextYAlignment = Enum.TextYAlignment.Top
status.Parent = panel

local close = Instance.new("TextButton")
close.Size = UDim2.fromOffset(80, 38)
close.Position = UDim2.new(0, 20, 1, -54)
close.BackgroundColor3 = Color3.fromRGB(29, 33, 40)
close.BorderSizePixel = 0
close.Text = "Close"
close.TextColor3 = Color3.fromRGB(240, 243, 247)
close.TextSize = 12
close.Font = Enum.Font.GothamMedium
close.Parent = panel

local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 6)
closeCorner.Parent = close

local activate = Instance.new("TextButton")
activate.Size = UDim2.fromOffset(120, 38)
activate.Position = UDim2.new(1, -140, 1, -54)
activate.BackgroundColor3 = Color3.fromRGB(92, 151, 255)
activate.BorderSizePixel = 0
activate.Text = "Activate"
activate.TextColor3 = Color3.fromRGB(255, 255, 255)
activate.TextSize = 12
activate.Font = Enum.Font.GothamSemibold
activate.Parent = panel

local activateCorner = Instance.new("UICorner")
activateCorner.CornerRadius = UDim.new(0, 6)
activateCorner.Parent = activate

------------------------------------------------------------
-- UI HELPERS
------------------------------------------------------------

local function setStatus(message, kind)
    status.Text = tostring(message or "")

    if kind == "error" then
        status.TextColor3 = Color3.fromRGB(245, 100, 100)
    elseif kind == "success" then
        status.TextColor3 = Color3.fromRGB(100, 220, 140)
    else
        status.TextColor3 = Color3.fromRGB(151, 160, 174)
    end
end

local function setSubtitle(message)
    subtitle.Text = tostring(message or "")
end

local function destroyUI()
    if gui and gui.Parent then
        gui:Destroy()
    end
end

close.Activated:Connect(function()
    destroyUI()
end)

------------------------------------------------------------
-- JSON
------------------------------------------------------------

local function encodeJSON(value)
    local ok, result = pcall(function()
        return HttpService:JSONEncode(value)
    end)

    if ok then
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

------------------------------------------------------------
-- HEADERS
------------------------------------------------------------

local function makeHeaders(extra)
    local headers = {
        ["Content-Type"] = "application/json",
        ["Cache-Control"] = "no-cache",
        ["X-Client-Version"] = SCRIPT_VERSION,
        ["X-User-Id"] = userId,
        ["X-Job-Id"] = jobId,
        ["X-Device-Id"] = deviceId,
        ["X-HWID"] = hwid
    }

    for key, value in pairs(extra or {}) do
        headers[key] = value
    end

    return headers
end

------------------------------------------------------------
-- EXECUTOR REQUEST DETECTION
------------------------------------------------------------

local function getRequestFunction()
    local names = {
        "request",
        "http_request",
        "syn_request"
    }

    for _, name in ipairs(names) do
        local fn = nil

        local ok = pcall(function()
            fn = _G[name]
        end)

        if ok and type(fn) == "function" then
            return fn, name
        end

        local genvOk, genv = pcall(function()
            if type(getgenv) == "function" then
                return getgenv()
            end

            return nil
        end)

        if genvOk and type(genv) == "table" then
            local valueOk, value = pcall(function()
                return genv[name]
            end)

            if valueOk and type(value) == "function" then
                return value, name
            end
        end
    end

    return nil, nil
end

------------------------------------------------------------
-- HTTP REQUEST
------------------------------------------------------------

local function requestHTTP(method, path, body, extraHeaders)
    local url = WORKER_URL .. path
    local headers = makeHeaders(extraHeaders)

    --------------------------------------------------------
    -- Try executor request API
    --------------------------------------------------------

    local requestFunction, requestName = getRequestFunction()

    if requestFunction then
        local requestData = {
            Url = url,
            Method = method,
            Headers = headers
        }

        if body ~= nil then
            requestData.Body = body
        end

        local ok, response = pcall(function()
            return requestFunction(requestData)
        end)

        if ok and type(response) == "table" then
            local responseBody =
                response.Body
                or response.body
                or response.ResponseBody
                or response.responseBody

            local responseStatus =
                response.StatusCode
                or response.Status
                or response.statusCode
                or response.status

            if type(responseBody) == "string" then
                return true, responseBody, tonumber(responseStatus) or 200, requestName
            end
        end
    end

    --------------------------------------------------------
    -- Fallback: game:HttpPost / game:HttpGet
    --------------------------------------------------------

    if method == "POST" then
        local ok, response = pcall(function()
            return game:HttpPost(
                url,
                body or "",
                "application/json",
                headers
            )
        end)

        if ok and type(response) == "string" then
            return true, response, 200, "game:HttpPost"
        end

        return false, tostring(response), 0, "game:HttpPost"
    end

    local ok, response = pcall(function()
        return game:HttpGet(
            url,
            true,
            headers
        )
    end)

    if ok and type(response) == "string" then
        return true, response, 200, "game:HttpGet"
    end

    return false, tostring(response), 0, "game:HttpGet"
end

------------------------------------------------------------
-- /token
------------------------------------------------------------

local function requestToken(licenseKey)
    local payload = {
        user_id = userId,
        job_id = jobId
    }

    if licenseKey and licenseKey ~= "" then
        payload.license_key = licenseKey
    end

    local body = encodeJSON(payload)

    local ok, responseBody, statusCode, method =
        requestHTTP("POST", "/token", body)

    if not ok then
        return nil, "HTTP request failed (" .. tostring(method) .. "): " .. tostring(responseBody)
    end

    local data = decodeJSON(responseBody)

    if not data then
        return nil,
            "Worker returned invalid JSON. HTTP " ..
            tostring(statusCode) ..
            "\nResponse: " ..
            string.sub(tostring(responseBody), 1, 300)
    end

    if type(data.token) == "string" and data.token ~= "" then
        return data.token, nil
    end

    return nil, data.error or "AUTHORIZATION_FAILED"
end

------------------------------------------------------------
-- ERROR MESSAGES
------------------------------------------------------------

local function explainError(errorCode)
    local value = tostring(errorCode or "")

    if value == "CLIENT_UPDATE_REQUIRED" then
        return "This loader version is not accepted by the Worker."
    end

    if value == "LICENSE_REQUIRED" then
        return "No active activation. Enter a PWF license key."
    end

    if value == "DEVICE_NOT_ENROLLED" then
        return "This account is not enrolled. Enter a PWF license key."
    end

    if value == "DEVICE_ENTITLEMENT_EXPIRED" then
        return "Your 24-hour activation has expired."
    end

    if value == "HWID_MISMATCH" then
        return "This license is bound to another device identity."
    end

    if value == "DEVICE_LIMIT" then
        return "The PWF device limit has been reached."
    end

    if value == "INVALID_LICENSE" then
        return "The PWF license key is invalid."
    end

    if value == "LICENSE_EXPIRED" then
        return "The PWF license has expired."
    end

    if value == "LICENSE_BANNED" then
        return "The PWF license is banned."
    end

    if value == "LICENSE_PAUSED" then
        return "The PWF license is paused."
    end

    if value == "USER_MISMATCH" then
        return "This activation belongs to another Roblox account."
    end

    if value == "JOB_MISMATCH" then
        return "This authorization belongs to another server session."
    end

    return value ~= "" and value or "Authorization failed."
end

------------------------------------------------------------
-- /script
------------------------------------------------------------

local function getSource(token)
    if type(token) ~= "string" or token == "" then
        return nil, "Missing source token."
    end

    local ok, responseBody, statusCode, method =
        requestHTTP(
            "GET",
            "/script",
            nil,
            {
                ["Authorization"] = "Bearer " .. token
            }
        )

    if not ok then
        return nil,
```
