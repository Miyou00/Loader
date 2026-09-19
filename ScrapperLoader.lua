--[[
    ScrapperLoader.lua
    ------------------
    Public bootstrap loader for the Private Inspector.

    Worker:
        https://private-inspector.psychepsycho851.workers.dev

    Client version:
        2.7.0

    Flow:
        1. Identify the Roblox account.
        2. Ask the Worker for an authorization token.
        3. If an active 24-hour activation exists, receive a
           fresh source token.
        4. Otherwise show the license panel.
        5. Submit the PWF license key.
        6. Receive a fresh source token.
        7. Request the private Inspector source.
        8. Execute the returned source.

    IMPORTANT:
        Delta's request() API is used because it was verified
        working against the Worker.

        X-HWID is an account-bound identifier, not a genuine
        hardware fingerprint.
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

local deviceId = "rbx-user-" .. userId
local hwid = "rbx-user-hwid-" .. userId

------------------------------------------------------------
-- REQUEST API
------------------------------------------------------------

local requestFunction

do
    local found = false

    local ok, value = pcall(function()
        return request
    end)

    if ok and type(value) == "function" then
        requestFunction = value
        found = true
    end

    if not found then
        local genvOk, genv = pcall(function()
            if type(getgenv) == "function" then
                return getgenv()
            end

            return nil
        end)

        if genvOk and type(genv) == "table" then
            local requestOk, requestValue = pcall(function()
                return genv.request
            end)

            if requestOk and type(requestValue) == "function" then
                requestFunction = requestValue
            end
        end
    end
end

------------------------------------------------------------
-- UI
------------------------------------------------------------

local oldGui = playerGui:FindFirstChild("ScrapperLoader")

if oldGui then
    oldGui:Destroy()
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ScrapperLoader"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.DisplayOrder = 999999
screenGui.Parent = playerGui

local overlay = Instance.new("Frame")
overlay.Name = "Overlay"
overlay.Size = UDim2.fromScale(1, 1)
overlay.BackgroundColor3 = Color3.fromRGB(15, 17, 21)
overlay.BorderSizePixel = 0
overlay.Parent = screenGui

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.Size = UDim2.fromOffset(440, 285)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.BackgroundColor3 = Color3.fromRGB(24, 27, 33)
panel.BorderSizePixel = 0
panel.Parent = overlay

local panelCorner = Instance.new("UICorner")
panelCorner.CornerRadius = UDim.new(0, 10)
panelCorner.Parent = panel

local panelStroke = Instance.new("UIStroke")
panelStroke.Color = Color3.fromRGB(55, 62, 74)
panelStroke.Thickness = 1
panelStroke.Parent = panel

------------------------------------------------------------
-- TITLE
------------------------------------------------------------

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

------------------------------------------------------------
-- SUBTITLE
------------------------------------------------------------

local subtitle = Instance.new("TextLabel")
subtitle.Size = UDim2.new(1, -40, 0, 44)
subtitle.Position = UDim2.fromOffset(20, 56)
subtitle.BackgroundTransparency = 1
subtitle.Text = "Checking your activation..."
subtitle.TextColor3 = Color3.fromRGB(151, 160, 174)
subtitle.TextSize = 12
subtitle.Font = Enum.Font.Gotham
subtitle.TextWrapped = true
subtitle.TextXAlignment = Enum.TextXAlignment.Left
subtitle.TextYAlignment = Enum.TextYAlignment.Top
subtitle.Parent = panel

------------------------------------------------------------
-- USER ID
------------------------------------------------------------

local userLabel = Instance.new("TextLabel")
userLabel.Size = UDim2.new(1, -40, 0, 20)
userLabel.Position = UDim2.fromOffset(20, 98)
userLabel.BackgroundTransparency = 1
userLabel.Text = "Roblox UserId: " .. userId
userLabel.TextColor3 = Color3.fromRGB(151, 160, 174)
userLabel.TextSize = 10
userLabel.Font = Enum.Font.Gotham
userLabel.TextXAlignment = Enum.TextXAlignment.Left
userLabel.Parent = panel

------------------------------------------------------------
-- LICENSE INPUT
------------------------------------------------------------

local input = Instance.new("TextBox")
input.Name = "LicenseKey"
input.Size = UDim2.new(1, -40, 0, 42)
input.Position = UDim2.fromOffset(20, 128)
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

------------------------------------------------------------
-- STATUS
------------------------------------------------------------

local status = Instance.new("TextLabel")
status.Size = UDim2.new(1, -40, 0, 44)
status.Position = UDim2.fromOffset(20, 178)
status.BackgroundTransparency = 1
status.Text = "Initializing..."
status.TextColor3 = Color3.fromRGB(151, 160, 174)
status.TextSize = 11
status.Font = Enum.Font.Gotham
status.TextWrapped = true
status.TextXAlignment = Enum.TextXAlignment.Left
status.TextYAlignment = Enum.TextYAlignment.Top
status.Parent = panel

------------------------------------------------------------
-- CLOSE BUTTON
------------------------------------------------------------

local closeButton = Instance.new("TextButton")
closeButton.Name = "Close"
closeButton.Size = UDim2.fromOffset(80, 38)
closeButton.Position = UDim2.new(0, 20, 1, -54)
closeButton.BackgroundColor3 = Color3.fromRGB(29, 33, 40)
closeButton.BorderSizePixel = 0
closeButton.Text = "Close"
closeButton.TextColor3 = Color3.fromRGB(240, 243, 247)
closeButton.TextSize = 12
closeButton.Font = Enum.Font.GothamMedium
closeButton.Parent = panel

local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 6)
closeCorner.Parent = closeButton

------------------------------------------------------------
-- ACTIVATE BUTTON
------------------------------------------------------------

local activateButton = Instance.new("TextButton")
activateButton.Name = "Activate"
activateButton.Size = UDim2.fromOffset(120, 38)
activateButton.Position = UDim2.new(1, -140, 1, -54)
activateButton.BackgroundColor3 = Color3.fromRGB(92, 151, 255)
activateButton.BorderSizePixel = 0
activateButton.Text = "Activate"
activateButton.TextColor3 = Color3.fromRGB(255, 255, 255)
activateButton.TextSize = 12
activateButton.Font = Enum.Font.GothamSemibold
activateButton.Parent = panel

local activateCorner = Instance.new("UICorner")
activateCorner.CornerRadius = UDim.new(0, 6)
activateCorner.Parent = activateButton

------------------------------------------------------------
-- UI FUNCTIONS
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

local function destroyLoader()
    if screenGui and screenGui.Parent then
        screenGui:Destroy()
    end
end

closeButton.Activated:Connect(function()
    destroyLoader()
end)

------------------------------------------------------------
-- JSON
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

------------------------------------------------------------
-- HEADERS
------------------------------------------------------------

local function buildHeaders(extra)
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
-- HTTP REQUEST
------------------------------------------------------------

local function httpRequest(method, path, body, extraHeaders)
    if type(requestFunction) ~= "function" then
        return nil, nil,
            "Delta request() is unavailable."
    end

    local requestData = {
        Url = WORKER_URL .. path,
        Method = method,
        Headers = buildHeaders(extraHeaders)
    }

    if body ~= nil then
        requestData.Body = body
    end

    local ok, response = pcall(function()
        return requestFunction(requestData)
    end)

    if not ok then
        return nil, nil,
            "Delta request() failed:\n" .. tostring(response)
    end

    if type(response) ~= "table" then
        return nil, nil,
            "Delta request() returned an invalid response."
    end

    local responseBody =
        response.Body
        or response.body
        or response.ResponseBody
        or response.responseBody

    local statusCode =
        response.StatusCode
        or response.Status
        or response.statusCode
        or response.status

    if type(responseBody) ~= "string" then
        responseBody = tostring(responseBody or "")
    end

    return responseBody, tonumber(statusCode) or 0, nil
end

------------------------------------------------------------
-- TOKEN REQUEST
------------------------------------------------------------

local function getToken(licenseKey)
    local payload = {
        user_id = userId,
        job_id = jobId
    }

    if type(licenseKey) == "string" and licenseKey ~= "" then
        payload.license_key = licenseKey
    end

    local body = encodeJSON(payload)

    local responseBody, statusCode, requestError =
        httpRequest(
            "POST",
            "/token",
            body
        )

    if requestError then
        return nil, requestError
    end

    if type(responseBody) ~= "string" or responseBody == "" then
        return nil,
            "Worker returned an empty response.\nHTTP " ..
            tostring(statusCode)
    end

    local data = decodeJSON(responseBody)

    if not data then
        return nil,
            "Worker returned invalid JSON.\nHTTP " ..
            tostring(statusCode) ..
            "\n\n" ..
            string.sub(responseBody, 1, 400)
    end

    if type(data.token) == "string" and data.token ~= "" then
        return data.token, nil
    end

    return nil, tostring(data.error or "AUTHORIZATION_FAILED")
end

------------------------------------------------------------
-- AUTH ERROR TRANSLATION
------------------------------------------------------------

local function explainAuthError(errorCode)
    local value = tostring(errorCode or "")

    if value == "CLIENT_UPDATE_REQUIRED" then
        return "This loader version is not accepted by the Worker."
    end

    if value == "LICENSE_REQUIRED" then
        return "No active 24-hour activation was found."
    end

    if value == "DEVICE_NOT_ENROLLED" then
        return "This Roblox account is not enrolled."
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
-- PRIVATE SOURCE
------------------------------------------------------------

local function getSource(token)
    if type(token) ~= "string" or token == "" then
        return nil, "Missing source token."
    end

    local responseBody, statusCode, requestError =
        httpRequest(
            "GET",
            "/script",
            nil,
            {
                ["Authorization"] = "Bearer " .. token
            }
        )

    if requestError then
        return nil, requestError
    end

    if type(responseBody) ~= "string" or responseBody == "" then
        return nil,
            "Private Inspector source was empty.\nHTTP " ..
            tostring(statusCode)
    end

    if #responseBody > MAX_SOURCE_BYTES then
        return nil, "Private Inspector source exceeded the size limit."
    end

    --------------------------------------------------------
    -- Worker JSON error response
    --------------------------------------------------------

    local firstCharacter = string.sub(
        responseBody:gsub("^%s+", ""),
        1,
        1
    )

    if firstCharacter == "{" then
        local errorData = decodeJSON(responseBody)

        if errorData then
            local errorMessage =
                errorData.error
                or errorData.message
                or "Private source request failed."

            return nil,
                tostring(errorMessage) ..
                "\nHTTP " ..
                tostring(statusCode)
        end
    end

    return responseBody, nil
end

------------------------------------------------------------
-- SOURCE EXECUTION
------------------------------------------------------------

local function executeSource(source)
    if type(source) ~= "string" or source == "" then
        return false, "Private Inspector source is empty."
    end

    if type(loadstring) ~= "function" then
        return false,
            "loadstring is unavailable in this executor."
    end

    local compileOk, chunkOrError, compileError = pcall(function()
        return loadstring(source)
    end)

    if not compileOk then
        return false,
            "Inspector compilation failed:\n" ..
            tostring(chunkOrError)
    end

    -- loadstring returns (nil, errorMessage) for syntax errors in standard
    -- Lua/Luau environments. Preserve that diagnostic instead of masking it
    -- as "did not return a function".
    if type(chunkOrError) ~= "function" then
        return false,
            "Inspector compilation failed:\n" ..
            tostring(compileError or chunkOrError or "Unknown compiler error")
    end

    local executeOk, executeError =
        pcall(chunkOrError)

    if not executeOk then
        return false,
            "Inspector execution failed:\n" ..
            tostring(executeError)
    end

    return true
end

------------------------------------------------------------
-- EXECUTION ERROR UI
------------------------------------------------------------

local function showFatalError(message)
    destroyLoader()

    local errorGui = Instance.new("ScreenGui")
    errorGui.Name = "ScrapperLoaderError"
    errorGui.ResetOnSpawn = false
    errorGui.IgnoreGuiInset = true
    errorGui.DisplayOrder = 999999
    errorGui.Parent = playerGui

    local errorFrame = Instance.new("Frame")
    errorFrame.Size = UDim2.fromScale(1, 1)
    errorFrame.BackgroundColor3 = Color3.fromRGB(15, 17, 21)
    errorFrame.BorderSizePixel = 0
    errorFrame.Parent = errorGui

    local errorPanel = Instance.new("Frame")
    errorPanel.Size = UDim2.fromOffset(520, 230)
    errorPanel.Position = UDim2.fromScale(0.5, 0.5)
    errorPanel.AnchorPoint = Vector2.new(0.5, 0.5)
    errorPanel.BackgroundColor3 = Color3.fromRGB(24, 27, 33)
    errorPanel.BorderSizePixel = 0
    errorPanel.Parent = errorFrame

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = errorPanel

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(90, 55, 55)
    stroke.Thickness = 1
    stroke.Parent = errorPanel

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -40, 1, -40)
    label.Position = UDim2.fromOffset(20, 20)
    label.BackgroundTransparency = 1
    label.TextColor3 = Color3.fromRGB(245, 100, 100)
    label.TextSize = 14
    label.Font = Enum.Font.Gotham
    label.TextWrapped = true
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextYAlignment = Enum.TextYAlignment.Top
    label.Text =
        "PRIVATE INSPECTOR ERROR\n\n" ..
        tostring(message)
    label.Parent = errorPanel
end

------------------------------------------------------------
-- LICENSE ACTIVATION
------------------------------------------------------------

local busy = false

local function activateLicense()
    if busy then
        return
    end

    local licenseKey =
        tostring(input.Text or ""):match("^%s*(.-)%s*$")
        or ""

    if licenseKey == "" then
        setStatus(
            "Enter a PWF license key.",
            "error"
        )
        return
    end

    if #licenseKey > 128 then
        setStatus(
            "License key is too long.",
            "error"
        )
        return
    end

    busy = true

    activateButton.Text = "Checking..."
    activateButton.AutoButtonColor = false

    setSubtitle(
        "Submitting your PWF license key..."
    )

    setStatus(
        "Activating license...",
        nil
    )

    local token, tokenError =
        getToken(licenseKey)

    if not token then
        setStatus(
            explainAuthError(tokenError),
            "error"
        )

        busy = false
        activateButton.Text = "Activate"
        activateButton.AutoButtonColor = true

        return
    end

    setSubtitle(
        "Activation successful.\n" ..
        "Retrieving Private Inspector..."
    )

    setStatus(
        "Fetching private source...",
        "success"
    )

    local source, sourceError =
        getSource(token)

    if not source then
        setStatus(
            sourceError,
            "error"
        )

        busy = false
        activateButton.Text = "Activate"
        activateButton.AutoButtonColor = true

        return
    end

    setStatus(
        "Starting Private Inspector...",
        "success"
    )

    task.wait(0.2)

    destroyLoader()

    local executed, executionError =
        executeSource(source)

    if not executed then
        showFatalError(executionError)
    end
end

activateButton.Activated:Connect(
    activateLicense
)

input.FocusLost:Connect(
    function(enterPressed)
        if enterPressed then
            activateLicense()
        end
    end
)

------------------------------------------------------------
-- STARTUP
------------------------------------------------------------

task.spawn(function()

    --------------------------------------------------------
    -- Verify request API
    --------------------------------------------------------

    if type(requestFunction) ~= "function" then
        setSubtitle(
            "Delta HTTP API could not be detected."
        )

        setStatus(
            "request() is unavailable.",
            "error"
        )

        return
    end

    --------------------------------------------------------
    -- Existing activation
    --------------------------------------------------------

    setSubtitle(
        "Checking your existing activation..."
    )

    setStatus(
        "Connecting to authorization server...",
        nil
    )

    local token, tokenError =
        getToken()

    --------------------------------------------------------
    -- Existing activation found
    --------------------------------------------------------

    if token then

        setSubtitle(
            "Active 24-hour activation found."
        )

        setStatus(
            "Retrieving Private Inspector...",
            "success"
        )

        local source, sourceError =
            getSource(token)

        if not source then
            setStatus(
                sourceError,
                "error"
            )
            return
        end

        setStatus(
            "Starting Private Inspector...",
            "success"
        )

        task.wait(0.2)

        destroyLoader()

        local executed, executionError =
            executeSource(source)

        if not executed then
            showFatalError(executionError)
        end

        return
    end

    --------------------------------------------------------
    -- License required
    --------------------------------------------------------

    if tokenError == "LICENSE_REQUIRED"
        or tokenError == "DEVICE_NOT_ENROLLED"
        or tokenError == "DEVICE_ENTITLEMENT_EXPIRED" then

        setSubtitle(
            "No active 24-hour activation was found.\n" ..
            "Enter a new PWF license key to continue."
        )

        setStatus(
            "License required.",
            nil
        )

        task.wait(0.25)

        pcall(function()
            input:CaptureFocus()
        end)

        return
    end

    --------------------------------------------------------
    -- Version error
    --------------------------------------------------------

    if tokenError == "CLIENT_UPDATE_REQUIRED" then

        setSubtitle(
            "The Worker rejected this client version.\n" ..
            "Loader version: " ..
            SCRIPT_VERSION
        )

        setStatus(
            explainAuthError(tokenError),
            "error"
        )

        return
    end

    --------------------------------------------------------
    -- Other authorization error
    --------------------------------------------------------

    setSubtitle(
        "Authorization request failed."
    )

    setStatus(
        explainAuthError(tokenError),
        "error"
    )
end)
