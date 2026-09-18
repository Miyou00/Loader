local Players = game:GetService("Players")

local player = Players.LocalPlayer

if not player then
    return
end

local playerGui = player:WaitForChild("PlayerGui")

local gui = Instance.new("ScreenGui")
gui.Name = "DeltaTest"
gui.ResetOnSpawn = false
gui.DisplayOrder = 999999
gui.Parent = playerGui

local box = Instance.new("TextLabel")
box.Size = UDim2.fromOffset(500, 180)
box.Position = UDim2.fromScale(0.5, 0.5)
box.AnchorPoint = Vector2.new(0.5, 0.5)
box.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
box.BorderSizePixel = 0
box.TextColor3 = Color3.fromRGB(255, 255, 255)
box.TextSize = 18
box.Font = Enum.Font.GothamBold
box.TextWrapped = true
box.Text = "DELTA TEST\n\nLua is executing.\nPlayer: " .. player.Name .. "\nUserId: " .. tostring(player.UserId)
box.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = box
