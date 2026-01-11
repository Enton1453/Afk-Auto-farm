local VirtualUser = game:GetService("VirtualUser")
game:GetService("Players").LocalPlayer.Idled:Connect(function()
    VirtualUser:CaptureController()
    VirtualUser:ClickButton2(Vector2.new())
end)

local Player = game.Players.LocalPlayer
local Cashiers = workspace:WaitForChild("Cashiers")
local Drops = workspace:WaitForChild("Ignored"):WaitForChild("Drop")
local Request = (syn and syn.request) or (http and http.request) or http_request or (fluxus and fluxus.request) or request

local Start_Cash = Player.DataFolder.Currency.Value
local CurrentStatus = "INITIALIZING"
local StartTime = os.time()
local BrokenBlacklist = {}

local function formatNumber(value)
    local str = tostring(value)
    return str:reverse():gsub("%d%d%d", "%1,"):reverse():gsub("^,", "")
end

local function sendProfitWebhook()
    task.spawn(function()
        local url = getgenv().FarmConfig.WebhookURL
        if not url or url == "" or not url:find("discord") then return end
        local Current_Cash = Player.DataFolder.Currency.Value
        local Profit = Current_Cash - Start_Cash
        local diff = os.difftime(os.time(), StartTime)
        local runtimeText = string.format("%dh %dm", math.floor(diff / 3600), math.floor((diff % 3600) / 60))

        local data = {
            ["embeds"] = {{
                ["title"] = "CyanFarm Status: " .. Player.Name,
                ["color"] = 65535, 
                ["fields"] = {
                    {["name"] = "💵 Current Wallet", ["value"] = "```$" .. formatNumber(Current_Cash) .. "```", ["inline"] = true},
                    {["name"] = "🚀 Profit Made", ["value"] = "```$" .. formatNumber(Profit) .. "```", ["inline"] = true},
                    {["name"] = "⏱️ Runtime", ["value"] = "```" .. runtimeText .. "```", ["inline"] = true}, 
                    {["name"] = "🛠 Status", ["value"] = "```" .. CurrentStatus .. "```", ["inline"] = false}
                },
                ["footer"] = {["text"] = "CyanWare Farm • Sent at: " .. os.date("%X")},
                ["timestamp"] = os.date("!%Y-%m-%dT%H:%M:%SZ")
            }}
        }
        pcall(function() Request({Url = url, Method = "POST", Headers = {["Content-Type"] = "application/json"}, Body = game:GetService("HttpService"):JSONEncode(data)}) end)
    end)
end

local GetTarget = function()
    local char = Player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return nil end
    local available = {}
    for _, v in pairs(Cashiers:GetChildren()) do
        local hum = v:FindFirstChild("Humanoid")
        local open = v:FindFirstChild("Open") or v:FindFirstChild("Wedge")
        if v.Name == "CA$HIER" and hum and hum.Health > 0 and open and open.Transparency < 1 and not BrokenBlacklist[v] then
            table.insert(available, {obj = v, dist = (open.Position - root.Position).Magnitude})
        end
    end
    table.sort(available, function(a, b) return a.dist < b.dist end)
    return available[1] and available[1].obj or nil
end

task.spawn(function()
    while true do
        task.wait(0.5)
        local char = Player.Character
        local hum = char and char:FindFirstChild("Humanoid")
        local root = char and char:FindFirstChild("HumanoidRootPart")
        
        if not char or not hum or hum.Health <= 0 or not root then
            CurrentStatus = "RESPAWNING..."
            char = Player.CharacterAdded:Wait()
            task.wait(2)
            continue
        end
        
        if getgenv().FarmConfig.Enabled then
            local target = GetTarget()
            local tool = Player.Backpack:FindFirstChild("Combat") or (char and char:FindFirstChild("Combat"))

            if target and tool then
                local hitPart = target:FindFirstChild("Open") or target:FindFirstChild("Wedge")
                CurrentStatus = "FARMING: " .. (target.Parent and target.Parent.Name or "Cashier")
                
                
                local standPos
                local targetX = hitPart.Position.X
                if math.abs(targetX - (-624.59845)) < 1 then
                    standPos = Vector3.new(-619.880, 23.244, -288.520)
                elseif math.abs(targetX - (-627.59845)) < 1 then
                    standPos = Vector3.new(-631.280, 23.244, -289.877)
                else
                    standPos = hitPart.CFrame * CFrame.new(0, 0, 2.5).Position
                end

                root.CFrame = CFrame.lookAt(standPos, hitPart.Position)
                task.wait(0.2)
                hum:EquipTool(tool)

                local hitsDone = 0
                local moneyDropped = false
                local startTime = tick()
                
                local connection = Drops.ChildAdded:Connect(function(child)
                    if child.Name == "MoneyDrop" and (child.Position - hitPart.Position).Magnitude < 15 then
                        moneyDropped = true
                    end
                end)

                
                while target and target:FindFirstChild("Humanoid") and target.Humanoid.Health > 0 and hum.Health > 0 do
                    root.CFrame = CFrame.lookAt(root.Position, Vector3.new(hitPart.Position.X, root.Position.Y, hitPart.Position.Z))
                    tool:Activate()
                    hitsDone = hitsDone + 1
                    
                    -- Hardcoded Timing Logic
                    if hitsDone <= 2 then
                        task.wait(1.2) -- Long Hit
                    else
                        task.wait(0.5) -- Normal Hit
                    end
                    
                    
                    if moneyDropped or (tick() - startTime) >= 5 then
                        break
                    end
                end
                if connection then connection:Disconnect() end

                if hum.Health > 0 then
                    CurrentStatus = "COLLECTING CASH"
                    local collectAttempt = tick()
                    while (tick() - collectAttempt) < 4 do
                        local foundMoney = false
                        for _, money in ipairs(Drops:GetChildren()) do
                            if money.Name == "MoneyDrop" and (money.Position - hitPart.Position).Magnitude <= 20 then
                                foundMoney = true
                                root.CFrame = CFrame.new(money.Position + Vector3.new(0, 1, 0))
                                if money:FindFirstChild("ClickDetector") then fireclickdetector(money.ClickDetector) end
                                task.wait(getgenv().FarmConfig.CollectDelay)
                            end
                        end
                        if not foundMoney and (tick() - collectAttempt) > 0.8 then break end
                        task.wait(0.1)
                    end
                end
                BrokenBlacklist[target] = true
                task.delay(30, function() BrokenBlacklist[target] = nil end)
            end
        end
    end
end)

task.spawn(function() while true do task.wait(getgenv().FarmConfig.WebhookInterval) sendProfitWebhook() end end)
task.spawn(function() while true do pcall(function() if Player.Character.Humanoid.Sit then Player.Character.Humanoid.Sit = false end end) task.wait(0.5) end end)
