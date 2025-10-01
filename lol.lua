-- 初始按键（保持原样）
game:GetService("VirtualInputManager"):SendKeyEvent(true, "W", false, game)
task.wait(0.01)
game:GetService("VirtualInputManager"):SendKeyEvent(false, "W", false, game)
task.wait(0.01)

-- 服务声明
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local TextService = game:GetService("TextService")
local UserInputService = game:GetService("UserInputService")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local StarterGui = game:GetService("StarterGui")

-- 获取本地玩家
local LocalPlayer = Players.LocalPlayer

-- 全局变量控制脚本执行
local scriptEnabled = false
local activeCoroutines = {}
local forceServerSwitchScheduled = false

-- 自定义换服时间设置
local huanfu = 3 -- 换服时间设置（秒）

-- 检查必要的模块是否存在
local devv, Signal, itemModule
local success, errorMsg = pcall(function()
    devv = require(ReplicatedStorage.devv)
    Signal = devv.load("Signal")
    itemModule = devv.load('v3item')
end)

if not success then
    warn("无法加载必要的模块: " .. tostring(errorMsg))
    return
end

-- ========================
-- 协程管理功能
-- ========================
local function trackCoroutine(coroutineFunc, name)
    local co = coroutine.create(coroutineFunc)
    activeCoroutines[name] = co
    return co
end

local function stopAllCoroutines()
    print("🛑 正在停止所有协程...")
    for name, co in pairs(activeCoroutines) do
        if coroutine.status(co) ~= "dead" then
            coroutine.close(co)
            print("✅ 已停止协程: " .. name)
        end
    end
    activeCoroutines = {}
end

-- ========================
-- 人物加载检测和强制换服功能
-- ========================
local function waitForCharacterLoad()
    print("⏳ 等待人物加载...")
    
    -- 等待角色存在
    while not LocalPlayer.Character do
        LocalPlayer.CharacterAdded:Wait()
    end
    
    -- 等待角色组件加载完成
    local character = LocalPlayer.Character
    character:WaitForChild("Humanoid")
    character:WaitForChild("HumanoidRootPart")
    
    print("✅ 人物加载完成")
    return character
end

local function scheduleForceServerSwitch()
    if forceServerSwitchScheduled then
        return
    end
    
    forceServerSwitchScheduled = true
    print("⏰ 已安排" .. huanfu .. "秒后强制更换服务器")
    
    trackCoroutine(function()
        task.wait(huanfu)
        
        if scriptEnabled then
            print("🚀 执行强制服务器更换...")
            
            -- 停止所有正在执行的协程
            stopAllCoroutines()
            
            -- 执行服务器跳转
            TPServer()
        end
    end, "force_switch_timer")
end

-- ========================
-- 自动W键循环功能
-- ========================
local autoWEnabled = true
local wKeyInterval = 0.01 -- W键按下的间隔时间（秒）

-- 自动W键循环函数
local function autoWKeyLoop()
    while scriptEnabled and autoWEnabled and task.wait(wKeyInterval) do
        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") and LocalPlayer.Character.Humanoid.Health > 0 then
            -- 按下W键
            VirtualInputManager:SendKeyEvent(true, "W", false, game)
            task.wait(0.01)
            VirtualInputManager:SendKeyEvent(false, "W", false, game)
        end
    end
end

-- ========================
-- 数据存储和文件路径配置
-- ========================
local basePath = "BENAutoScript"
local serverCountFile = basePath .. "/server_count.txt"
local itemCountFile = basePath .. "/item_count.txt"
local visitedServersFile = basePath .. "/visited_servers.txt"
local executionCountFile = basePath .. "/execution_count.txt"
local moneyPrinterCountFile = basePath .. "/money_printer_count.txt"
local blacklistFile = basePath .. "/blacklist_enabled.txt"
local huanfuTimeFile = basePath .. "/huanfu_time.txt" -- 新增：换服时间配置文件

-- 检查文件系统功能是否可用
local fileSystemAvailable = pcall(function()
    return readfile and writefile and isfile and makefolder
end)

-- 确保目录存在
local function ensureDirectory()
    if not fileSystemAvailable then return false end
    
    local success = pcall(function()
        if not isfolder(basePath) then
            makefolder(basePath)
        end
        return true
    end)
    return success
end

-- 读取换服时间设置
local function readHuanfuTime()
    if not fileSystemAvailable then return 3 end -- 默认3秒
    
    if isfile(huanfuTimeFile) then
        local success, time = pcall(function()
            return tonumber(readfile(huanfuTimeFile)) or 3
        end)
        return success and time or 3
    end
    return 3
end

-- 写入换服时间设置
local function writeHuanfuTime(time)
    if not fileSystemAvailable then return false end
    
    local success = pcall(function()
        writefile(huanfuTimeFile, tostring(time))
        return true
    end)
    return success
end

-- 读取执行次数
local function readExecutionCount()
    if not fileSystemAvailable then return 0 end
    
    if isfile(executionCountFile) then
        local success, count = pcall(function()
            return tonumber(readfile(executionCountFile)) or 0
        end)
        return success and count or 0
    end
    return 0
end

-- 写入执行次数
local function writeExecutionCount(count)
    if not fileSystemAvailable then return false end
    
    local success = pcall(function()
        writefile(executionCountFile, tostring(count))
        return true
    end)
    return success
end

-- 读取印钞机计数
local function readMoneyPrinterCount()
    if not fileSystemAvailable then return 0 end
    
    if isfile(moneyPrinterCountFile) then
        local success, count = pcall(function()
            return tonumber(readfile(moneyPrinterCountFile)) or 0
        end)
        return success and count or 0
    end
    return 0
end

-- 写入印钞机计数
local function writeMoneyPrinterCount(count)
    if not fileSystemAvailable then return false end
    
    local success = pcall(function()
        writefile(moneyPrinterCountFile, tostring(count))
        return true
    end)
    return success
end

-- 读取黑名单启用状态
local function readBlacklistEnabled()
    if not fileSystemAvailable then return false end
    
    if isfile(blacklistFile) then
        local success, enabled = pcall(function()
            local content = readfile(blacklistFile)
            return content == "true"
        end)
        return success and enabled or false
    end
    return false
end

-- 写入黑名单启用状态
local function writeBlacklistEnabled(enabled)
    if not fileSystemAvailable then return false end
    
    local success = pcall(function()
        writefile(blacklistFile, tostring(enabled))
        return true
    end)
    return success
end

-- 清除已访问服务器记录的功能
local function clearVisitedServers()
    if not fileSystemAvailable then
        print("❌ 文件操作功能不可用")
        return false
    end
    
    local success = pcall(function()
        if isfile(visitedServersFile) then
            delfile(visitedServersFile)
            print("✅ 已清除已访问服务器记录")
            return true
        else
            print("❌ 未找到已访问服务器记录文件")
            return false
        end
    end)
    
    return success
end

-- 自动执行计数逻辑
local function handleAutoExecution()
    ensureDirectory()
    
    -- 读取当前执行次数
    local currentCount = readExecutionCount()
    local newCount = currentCount + 1
    
    print("当前执行次数: " .. tostring(currentCount) .. " → " .. tostring(newCount))
    
    -- 写入新的执行次数
    if writeExecutionCount(newCount) then
        print("✅ 执行次数记录成功")
    else
        print("❌ 执行次数记录失败")
    end
    
    -- 检查是否需要重置
    if newCount >= 10 then
        print("🎯 达到10次执行，自动重置服务器记录")
        if clearVisitedServers() then
            -- 重置计数器
            if writeExecutionCount(0) then
                print("✅ 执行次数已重置为0")
            else
                print("❌ 执行次数重置失败")
            end
        else
            print("❌ 服务器记录清除失败")
        end
    end
end

-- 创建文件夹存储数据
local function setupDataStorage()
    local serverEntries = 0
    local itemDetections = 0
    local moneyPrinterDetections = 0
    local visitedServers = {}
    local blacklistEnabled = false
    
    local success, result = pcall(function()
        -- 检查文件系统是否可用
        if not fileSystemAvailable then
            return {serverEntries = 1, itemDetections = 0, moneyPrinterDetections = 0, visitedServers = {}, blacklistEnabled = false}
        end
        
        -- 确保目录存在
        ensureDirectory()
        
        -- 读取换服时间设置
        huanfu = readHuanfuTime()
        
        -- 服务器进入次数文件路径
        if not isfile(serverCountFile) then
            writefile(serverCountFile, "1")
            serverEntries = 1
        else
            local countText = readfile(serverCountFile)
            serverEntries = (tonumber(countText) or 0) + 1
            writefile(serverCountFile, tostring(serverEntries))
        end
        
        -- 物品检测次数文件路径
        if not isfile(itemCountFile) then
            writefile(itemCountFile, "0")
            itemDetections = 0
        else
            local countText = readfile(itemCountFile)
            itemDetections = tonumber(countText) or 0
        end
        
        -- 印钞机检测次数文件路径
        if not isfile(moneyPrinterCountFile) then
            writefile(moneyPrinterCountFile, "0")
            moneyPrinterDetections = 0
        else
            local countText = readfile(moneyPrinterCountFile)
            moneyPrinterDetections = tonumber(countText) or 0
        end
        
        -- 已访问服务器记录文件路径
        if not isfile(visitedServersFile) then
            writefile(visitedServersFile, "{}")
            visitedServers = {}
        else
            local serversText = readfile(visitedServersFile)
            local decodeSuccess, data = pcall(function()
                return HttpService:JSONDecode(serversText)
            end)
            if decodeSuccess and type(data) == "table" then
                visitedServers = data
            else
                visitedServers = {}
                writefile(visitedServersFile, "{}")
            end
        end
        
        -- 黑名单启用状态文件路径
        if not isfile(blacklistFile) then
            writefile(blacklistFile, "false")
            blacklistEnabled = false
        else
            local enabledText = readfile(blacklistFile)
            blacklistEnabled = enabledText == "true"
        end
        
        -- 记录当前服务器ID
        local currentJobId = game.JobId
        if currentJobId and currentJobId ~= "" then
            if not visitedServers[currentJobId] then
                visitedServers[currentJobId] = {
                    firstVisit = os.time(),
                    lastVisit = os.time(),
                    visitCount = 1
                }
            else
                visitedServers[currentJobId].lastVisit = os.time()
                visitedServers[currentJobId].visitCount = (visitedServers[currentJobId].visitCount or 0) + 1
            end
            
            -- 保存更新后的服务器记录
            pcall(function()
                writefile(visitedServersFile, HttpService:JSONEncode(visitedServers))
            end)
        end
        
        return {
            serverEntries = serverEntries, 
            itemDetections = itemDetections, 
            moneyPrinterDetections = moneyPrinterDetections,
            visitedServers = visitedServers,
            blacklistEnabled = blacklistEnabled
        }
    end)
    
    if success then
        return result
    else
        return {serverEntries = 1, itemDetections = 0, moneyPrinterDetections = 0, visitedServers = {}, blacklistEnabled = false}
    end
end

-- 保存物品检测次数
local function saveItemDetectionCount(count)
    if not fileSystemAvailable then return false end
    
    local success = pcall(function()
        writefile(itemCountFile, tostring(count))
        return true
    end)
    return success
end

-- 保存印钞机检测次数
local function saveMoneyPrinterCount(count)
    if not fileSystemAvailable then return false end
    
    local success = pcall(function()
        writefile(moneyPrinterCountFile, tostring(count))
        return true
    end)
    return success
end

-- 保存已访问服务器记录
local function saveVisitedServers(servers)
    if not fileSystemAvailable then return false end
    
    local success = pcall(function()
        writefile(visitedServersFile, HttpService:JSONEncode(servers))
        return true
    end)
    return success
end

-- 初始化数据和自动执行计数
local data = setupDataStorage()
local serverEntryCount = data.serverEntries
local itemDetectionCount = data.itemDetections
local moneyPrinterCount = data.moneyPrinterDetections or 0
local visitedServers = data.visitedServers or {}
local blacklistEnabled = data.blacklistEnabled or false
handleAutoExecution()

-- ========================
-- UI 设置
-- ========================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "BENAutoScriptUI"
ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
ScreenGui.ResetOnSpawn = false

-- 创建主容器
local mainContainer = Instance.new("Frame")
mainContainer.Size = UDim2.new(0, 240, 0, 250) -- 增加高度以容纳新按钮
mainContainer.Position = UDim2.new(1, -250, 0, 10)
mainContainer.AnchorPoint = Vector2.new(0, 0)
mainContainer.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
mainContainer.BackgroundTransparency = 0.3
mainContainer.BorderSizePixel = 0
mainContainer.Parent = ScreenGui

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 12)
mainCorner.Parent = mainContainer

local mainStroke = Instance.new("UIStroke")
mainStroke.Color = Color3.fromRGB(100, 100, 200)
mainStroke.Thickness = 2
mainStroke.Parent = mainContainer

-- 标题
local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, 0, 0, 25)
titleLabel.Position = UDim2.new(0, 0, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.TextColor3 = Color3.fromRGB(100, 200, 255)
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextSize = 14
titleLabel.Text = "BEN AUTO SCRIPT STATS"
titleLabel.TextXAlignment = Enum.TextXAlignment.Center
titleLabel.TextYAlignment = Enum.TextYAlignment.Center
titleLabel.Parent = mainContainer

-- 分隔线
local separator = Instance.new("Frame")
separator.Size = UDim2.new(0.9, 0, 0, 1)
separator.Position = UDim2.new(0.05, 0, 0, 25)
separator.BackgroundColor3 = Color3.fromRGB(100, 100, 200)
separator.BorderSizePixel = 0
separator.Parent = mainContainer

-- 服务器计数显示
local serverFrame = Instance.new("Frame")
serverFrame.Size = UDim2.new(1, -10, 0, 25)
serverFrame.Position = UDim2.new(0, 5, 0, 30)
serverFrame.BackgroundTransparency = 1
serverFrame.Parent = mainContainer

local serverIcon = Instance.new("TextLabel")
serverIcon.Size = UDim2.new(0, 25, 1, 0)
serverIcon.Position = UDim2.new(0, 0, 0, 0)
serverIcon.BackgroundTransparency = 1
serverIcon.TextColor3 = Color3.fromRGB(100, 200, 100)
serverIcon.Font = Enum.Font.GothamBold
serverIcon.TextSize = 16
serverIcon.Text = "🔄"
serverIcon.TextXAlignment = Enum.TextXAlignment.Center
serverIcon.TextYAlignment = Enum.TextYAlignment.Center
serverIcon.Parent = serverFrame

local serverLabel = Instance.new("TextLabel")
serverLabel.Size = UDim2.new(1, -30, 1, 0)
serverLabel.Position = UDim2.new(0, 30, 0, 0)
serverLabel.BackgroundTransparency = 1
serverLabel.TextColor3 = Color3.new(1, 1, 1)
serverLabel.Font = Enum.Font.Gotham
serverLabel.TextSize = 14
serverLabel.Text = "服务器进入: " .. serverEntryCount
serverLabel.TextXAlignment = Enum.TextXAlignment.Left
serverLabel.TextYAlignment = Enum.TextYAlignment.Center
serverLabel.Parent = serverFrame

-- 物品检测计数显示
local itemFrame = Instance.new("Frame")
itemFrame.Size = UDim2.new(1, -10, 0, 25)
itemFrame.Position = UDim2.new(0, 5, 0, 55)
itemFrame.BackgroundTransparency = 1
itemFrame.Parent = mainContainer

local itemIcon = Instance.new("TextLabel")
itemIcon.Size = UDim2.new(0, 25, 1, 0)
itemIcon.Position = UDim2.new(0, 0, 0, 0)
itemIcon.BackgroundTransparency = 1
itemIcon.TextColor3 = Color3.fromRGB(255, 200, 100)
itemIcon.Font = Enum.Font.GothamBold
itemIcon.TextSize = 16
itemIcon.Text = "📦"
itemIcon.TextXAlignment = Enum.TextXAlignment.Center
itemIcon.TextYAlignment = Enum.TextYAlignment.Center
itemIcon.Parent = itemFrame

local itemLabel = Instance.new("TextLabel")
itemLabel.Size = UDim2.new(1, -30, 1, 0)
itemLabel.Position = UDim2.new(0, 30, 0, 0)
itemLabel.BackgroundTransparency = 1
itemLabel.TextColor3 = Color3.new(1, 1, 1)
itemLabel.Font = Enum.Font.Gotham
itemLabel.TextSize = 14
itemLabel.Text = "物品检测: " .. itemDetectionCount
itemLabel.TextXAlignment = Enum.TextXAlignment.Left
itemLabel.TextYAlignment = Enum.TextYAlignment.Center
itemLabel.Parent = itemFrame

-- 印钞机检测计数显示
local printerFrame = Instance.new("Frame")
printerFrame.Size = UDim2.new(1, -10, 0, 25)
printerFrame.Position = UDim2.new(0, 5, 0, 80)
printerFrame.BackgroundTransparency = 1
printerFrame.Parent = mainContainer

local printerIcon = Instance.new("TextLabel")
printerIcon.Size = UDim2.new(0, 25, 1, 0)
printerIcon.Position = UDim2.new(0, 0, 0, 0)
printerIcon.BackgroundTransparency = 1
printerIcon.TextColor3 = Color3.fromRGB(100, 255, 100)
printerIcon.Font = Enum.Font.GothamBold
printerIcon.TextSize = 16
printerIcon.Text = "💰"
printerIcon.TextXAlignment = Enum.TextXAlignment.Center
printerIcon.TextYAlignment = Enum.TextYAlignment.Center
printerIcon.Parent = printerFrame

local printerLabel = Instance.new("TextLabel")
printerLabel.Size = UDim2.new(1, -30, 1, 0)
printerLabel.Position = UDim2.new(0, 30, 0, 0)
printerLabel.BackgroundTransparency = 1
printerLabel.TextColor3 = Color3.new(1, 1, 1)
printerLabel.Font = Enum.Font.Gotham
printerLabel.TextSize = 14
printerLabel.Text = "印钞机检测: " .. moneyPrinterCount
printerLabel.TextXAlignment = Enum.TextXAlignment.Left
printerLabel.TextYAlignment = Enum.TextYAlignment.Center
printerLabel.Parent = printerFrame

-- 已访问服务器计数显示
local visitedFrame = Instance.new("Frame")
visitedFrame.Size = UDim2.new(1, -10, 0, 25)
visitedFrame.Position = UDim2.new(0, 5, 0, 105)
visitedFrame.BackgroundTransparency = 1
visitedFrame.Parent = mainContainer

local visitedIcon = Instance.new("TextLabel")
visitedIcon.Size = UDim2.new(0, 25, 1, 0)
visitedIcon.Position = UDim2.new(0, 0, 0, 0)
visitedIcon.BackgroundTransparency = 1
visitedIcon.TextColor3 = Color3.fromRGB(200, 100, 255)
visitedIcon.Font = Enum.Font.GothamBold
visitedIcon.TextSize = 16
visitedIcon.Text = "📊"
visitedIcon.TextXAlignment = Enum.TextXAlignment.Center
visitedIcon.TextYAlignment = Enum.TextYAlignment.Center
visitedIcon.Parent = visitedFrame

local visitedLabel = Instance.new("TextLabel")
visitedLabel.Size = UDim2.new(1, -30, 1, 0)
visitedLabel.Position = UDim2.new(0, 30, 0, 0)
visitedLabel.BackgroundTransparency = 1
visitedLabel.TextColor3 = Color3.new(1, 1, 1)
visitedLabel.Font = Enum.Font.Gotham
visitedLabel.TextSize = 14
visitedLabel.Text = "已访问服务器: " .. (visitedServers and #visitedServers or 0)
visitedLabel.TextXAlignment = Enum.TextXAlignment.Left
visitedLabel.TextYAlignment = Enum.TextYAlignment.Center
visitedLabel.Parent = visitedFrame

-- 换服时间显示
local huanfuFrame = Instance.new("Frame")
huanfuFrame.Size = UDim2.new(1, -10, 0, 25)
huanfuFrame.Position = UDim2.new(0, 5, 0, 130)
huanfuFrame.BackgroundTransparency = 1
huanfuFrame.Parent = mainContainer

local huanfuIcon = Instance.new("TextLabel")
huanfuIcon.Size = UDim2.new(0, 25, 1, 0)
huanfuIcon.Position = UDim2.new(0, 0, 0, 0)
huanfuIcon.BackgroundTransparency = 1
huanfuIcon.TextColor3 = Color3.fromRGB(100, 200, 255)
huanfuIcon.Font = Enum.Font.GothamBold
huanfuIcon.TextSize = 16
huanfuIcon.Text = "⏰"
huanfuIcon.TextXAlignment = Enum.TextXAlignment.Center
huanfuIcon.TextYAlignment = Enum.TextYAlignment.Center
huanfuIcon.Parent = huanfuFrame

local huanfuLabel = Instance.new("TextLabel")
huanfuLabel.Size = UDim2.new(1, -30, 1, 0)
huanfuLabel.Position = UDim2.new(0, 30, 0, 0)
huanfuLabel.BackgroundTransparency = 1
huanfuLabel.TextColor3 = Color3.new(1, 1, 1)
huanfuLabel.Font = Enum.Font.Gotham
huanfuLabel.TextSize = 14
huanfuLabel.Text = "换服时间: " .. huanfu .. "秒"
huanfuLabel.TextXAlignment = Enum.TextXAlignment.Left
huanfuLabel.TextYAlignment = Enum.TextYAlignment.Center
huanfuLabel.Parent = huanfuFrame

-- 自动W键控制按钮
local wKeyButton = Instance.new("TextButton")
wKeyButton.Size = UDim2.new(0.9, 0, 0, 25)
wKeyButton.Position = UDim2.new(0.05, 0, 0, 155)
wKeyButton.BackgroundColor3 = Color3.fromRGB(60, 150, 200)
wKeyButton.BackgroundTransparency = 0.2
wKeyButton.TextColor3 = Color3.new(1, 1, 1)
wKeyButton.Font = Enum.Font.GothamBold
wKeyButton.TextSize = 12
wKeyButton.Text = "自动W键: 开启"
wKeyButton.Parent = mainContainer

local wKeyButtonCorner = Instance.new("UICorner")
wKeyButtonCorner.CornerRadius = UDim.new(0, 6)
wKeyButtonCorner.Parent = wKeyButton

local wKeyButtonStroke = Instance.new("UIStroke")
wKeyButtonStroke.Color = Color3.fromRGB(100, 180, 255)
wKeyButtonStroke.Thickness = 1
wKeyButtonStroke.Parent = wKeyButton

-- 黑名单控制按钮
local blacklistButton = Instance.new("TextButton")
blacklistButton.Size = UDim2.new(0.9, 0, 0, 25)
blacklistButton.Position = UDim2.new(0.05, 0, 0, 185)
blacklistButton.BackgroundColor3 = blacklistEnabled and Color3.fromRGB(60, 200, 60) or Color3.fromRGB(200, 60, 60)
blacklistButton.BackgroundTransparency = 0.2
blacklistButton.TextColor3 = Color3.new(1, 1, 1)
blacklistButton.Font = Enum.Font.GothamBold
blacklistButton.TextSize = 12
blacklistButton.Text = blacklistEnabled and "移除红卡: 开启" or "移除红卡: 关闭"
blacklistButton.Parent = mainContainer

local blacklistButtonCorner = Instance.new("UICorner")
blacklistButtonCorner.CornerRadius = UDim.new(0, 6)
blacklistButtonCorner.Parent = blacklistButton

local blacklistButtonStroke = Instance.new("UIStroke")
blacklistButtonStroke.Color = blacklistEnabled and Color3.fromRGB(100, 255, 100) or Color3.fromRGB(255, 100, 100)
blacklistButtonStroke.Thickness = 1
blacklistButtonStroke.Parent = blacklistButton

-- 清除服务器记录按钮
local clearButton = Instance.new("TextButton")
clearButton.Size = UDim2.new(0.9, 0, 0, 25)
clearButton.Position = UDim2.new(0.05, 0, 0, 215)
clearButton.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
clearButton.BackgroundTransparency = 0.2
clearButton.TextColor3 = Color3.new(1, 1, 1)
clearButton.Font = Enum.Font.GothamBold
clearButton.TextSize = 12
clearButton.Text = "清除服务器记录"
clearButton.Parent = mainContainer

local clearButtonCorner = Instance.new("UICorner")
clearButtonCorner.CornerRadius = UDim.new(0, 6)
clearButtonCorner.Parent = clearButton

local clearButtonStroke = Instance.new("UIStroke")
clearButtonStroke.Color = Color3.fromRGB(255, 100, 100)
clearButtonStroke.Thickness = 1
clearButtonStroke.Parent = clearButton

-- 显示执行次数的标签
local countLabel = Instance.new("TextLabel")
countLabel.Size = UDim2.new(1, -10, 0, 15)
countLabel.Position = UDim2.new(0, 5, 0, 243)
countLabel.BackgroundTransparency = 1
countLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
countLabel.Font = Enum.Font.Gotham
countLabel.TextSize = 10
countLabel.Text = "计数: 加载中..."
countLabel.TextXAlignment = Enum.TextXAlignment.Center
countLabel.Parent = mainContainer

-- 更新物品检测显示
local function updateItemDetectionDisplay()
    itemLabel.Text = "物品检测: " .. itemDetectionCount
end

-- 更新印钞机检测显示
local function updateMoneyPrinterDisplay()
    printerLabel.Text = "印钞机检测: " .. moneyPrinterCount
end

-- 更新已访问服务器显示
local function updateVisitedServersDisplay()
    local count = 0
    if visitedServers then
        for _ in pairs(visitedServers) do
            count = count + 1
        end
    end
    visitedLabel.Text = "已访问服务器: " .. count
end

-- 更新换服时间显示
local function updateHuanfuDisplay()
    huanfuLabel.Text = "换服时间: " .. huanfu .. "秒"
end

-- 更新计数显示
local function updateCountDisplay()
    local currentCount = readExecutionCount()
    countLabel.Text = "计数: " .. tostring(currentCount) .. "/10"
end

-- 更新黑名单按钮显示
local function updateBlacklistButton()
    blacklistButton.Text = blacklistEnabled and "移除红卡: 开启" or "移除红卡: 关闭"
    blacklistButton.BackgroundColor3 = blacklistEnabled and Color3.fromRGB(60, 200, 60) or Color3.fromRGB(200, 60, 60)
    blacklistButtonStroke.Color = blacklistEnabled and Color3.fromRGB(100, 255, 100) or Color3.fromRGB(255, 100, 100)
end

-- W键按钮点击事件
wKeyButton.MouseButton1Click:Connect(function()
    autoWEnabled = not autoWEnabled
    if autoWEnabled then
        wKeyButton.Text = "自动W键: 开启"
        wKeyButton.BackgroundColor3 = Color3.fromRGB(60, 150, 200)
        wKeyButtonStroke.Color = Color3.fromRGB(100, 180, 255)
        print("✅ 自动W键已开启")
    else
        wKeyButton.Text = "自动W键: 关闭"
        wKeyButton.BackgroundColor3 = Color3.fromRGB(150, 60, 60)
        wKeyButtonStroke.Color = Color3.fromRGB(255, 100, 100)
        print("❌ 自动W键已关闭")
    end
end)

-- 黑名单按钮点击事件
blacklistButton.MouseButton1Click:Connect(function()
    blacklistEnabled = not blacklistEnabled
    updateBlacklistButton()
    
    -- 保存黑名单状态
    if writeBlacklistEnabled(blacklistEnabled) then
        print("✅ 黑名单状态已保存: " .. (blacklistEnabled and "开启" or "关闭"))
    else
        print("❌ 黑名单状态保存失败")
    end
    
    if blacklistEnabled then
        print("🎯 黑名单已启用，将不再拾取以下物品:")
        print("   - NextBot Grenade")
        print("   - Military Armory Keycard")
        print("   - Helicopter")
        print("   - Diamond Ring")
        print("   - Diamond")
        print("   - Void Gem")
        print("   - Dark Matter Gem")
        print("   - Rollie")
        print("   - Nuclear Missile Launcher")
        print("   - Suitcase Nuke")
        print("   - Trident")
        print("   - Golden Cup")
    else
        print("🎯 黑名单已禁用，将正常拾取所有物品")
    end
end)

-- 按钮点击效果
local function setupButtonHoverEffects(button)
    button.MouseEnter:Connect(function()
        TweenService:Create(button, TweenInfo.new(0.2), {BackgroundTransparency = 0}):Play()
    end)
    
    button.MouseLeave:Connect(function()
        TweenService:Create(button, TweenInfo.new(0.2), {BackgroundTransparency = 0.2}):Play()
    end)
end

setupButtonHoverEffects(wKeyButton)
setupButtonHoverEffects(blacklistButton)
setupButtonHoverEffects(clearButton)

-- 清除按钮点击事件
clearButton.MouseButton1Click:Connect(function()
    local success = clearVisitedServers()
    
    -- 显示操作结果
    local resultLabel = Instance.new("TextLabel")
    resultLabel.Size = UDim2.new(1, -10, 0, 15)
    resultLabel.Position = UDim2.new(0, 5, 0, 243)
    resultLabel.BackgroundTransparency = 1
    resultLabel.Font = Enum.Font.Gotham
    resultLabel.TextSize = 10
    resultLabel.TextXAlignment = Enum.TextXAlignment.Center
    resultLabel.Parent = mainContainer
    
    if success then
        resultLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
        resultLabel.Text = "✅ 清除成功!"
        -- 重置已访问服务器数据
        visitedServers = {}
        updateVisitedServersDisplay()
    else
        resultLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
        resultLabel.Text = "❌ 清除失败"
    end
    
    -- 3秒后恢复显示计数
    task.wait(3)
    resultLabel:Destroy()
    updateCountDisplay()
end)

-- 中间欢迎文字
local welcomeContainer = Instance.new("Frame")
welcomeContainer.Size = UDim2.new(0, 0, 0, 50)
welcomeContainer.Position = UDim2.new(0.5, 0, 0.4, 0)
welcomeContainer.AnchorPoint = Vector2.new(0.5, 0.5)
welcomeContainer.BackgroundTransparency = 1
welcomeContainer.ClipsDescendants = true
welcomeContainer.Parent = ScreenGui

local welcomeLabel = Instance.new("TextLabel")
welcomeLabel.Size = UDim2.new(1, 0, 1, 0)
welcomeLabel.Position = UDim2.new(0, 0, 0, 0)
welcomeLabel.BackgroundTransparency = 1
welcomeLabel.TextColor3 = Color3.new(1, 1, 1)
welcomeLabel.Font = Enum.Font.GothamBold
welcomeLabel.TextSize = 36
welcomeLabel.Text = "BEN AUTO SCRIPT"
welcomeLabel.TextXAlignment = Enum.TextXAlignment.Left
welcomeLabel.TextYAlignment = Enum.TextYAlignment.Center
welcomeLabel.Parent = welcomeContainer

-- 从左到右渐显动画
task.spawn(function()
    local textService = game:GetService("TextService")
    local textSize = textService:GetTextSize("BEN AUTO SCRIPT", 36, Enum.Font.GothamBold, Vector2.new(1000, 50))
    
    -- 展开动画
    for i = 1, 20 do
        welcomeContainer.Size = UDim2.new(0, textSize.X * (i / 20), 0, 50)
        task.wait(0.02)
    end
    
    welcomeContainer.Size = UDim2.new(0, textSize.X, 0, 50)
    
    -- 显示5秒后淡出
    task.wait(5)
    
    -- 淡出动画
    for i = 1, 10 do
        welcomeLabel.TextTransparency = i / 10
        task.wait(0.1)
    end
    welcomeContainer:Destroy()
end)

-- ========================
-- 自动售卖功能
-- ========================
local function autoSellOnce()
    local itemsToSell = {
        'Amethyst', 'Sapphire', 'Emerald', 'Topaz', 'Ruby', 
        'Diamond Ring', "Gold Bar", "AK-47", "AR-15", "Diamond"
    }
    
    local soldCount = 0
    
    pcall(function()
        if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("Humanoid") then
            return
        end
        
        local inventory = itemModule.inventory
        if not inventory or not inventory.items then
            return
        end
        
        for i, v in next, inventory.items do
            for _, itemName in ipairs(itemsToSell) do
                if v.name == itemName then
                    local sellid = v.guid
                    
                    Signal.FireServer("equip", sellid)
                    Signal.FireServer("sellItem", sellid)
                    
                    soldCount = soldCount + 1
                    task.wait(0.3)
                    break
                end
            end
        end
        
        if soldCount > 0 then
            print("✅ 成功售卖 " .. soldCount .. " 件物品")
        else
            print("ℹ️ 没有物品可售卖")
        end
    end)
end

-- ========================
-- 战斗功能
-- ========================
local autokill = true
local autojia = true
local autostomp = true
local hitMOD = "meleemegapunch"
local jiahit = "Light Vest"

local function getFistsGUID()
    if not itemModule or not itemModule.inventory or not itemModule.inventory.items then
        return nil
    end
    
    for _, v in pairs(itemModule.inventory.items) do
        if v.name == 'Fists' then
            return v.guid
        end
    end
    return nil
end

local qtid = getFistsGUID()

-- 战斗主循环
local combatConnection
combatConnection = RunService.Heartbeat:Connect(function()
    if not scriptEnabled then return end
    
    pcall(function()
        local character = LocalPlayer.Character
        if not character then return end
        
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        local rootPart = character:FindFirstChild("HumanoidRootPart")
        if not humanoid or not rootPart or humanoid.Health <= 0 then return end

        -- 自动穿甲
        if autojia then
            Signal.InvokeServer("attemptPurchase", jiahit)
            for i, v in next, itemModule.inventory.items do
                if v.name == jiahit then
                    local light = v.guid
                    local armor = LocalPlayer:GetAttribute('armor')
                    if armor == nil or armor <= 0 then
                        Signal.FireServer("equip", light)
                        Signal.FireServer("useConsumable", light)
                        Signal.FireServer("removeItem", light)
                        break
                    end
                end
            end
        end

        -- 杀戮光环
        if autokill and qtid then
            for _, player in ipairs(Players:GetPlayers()) do
                if player ~= LocalPlayer and player.Character then
                    local targetChar = player.Character
                    local targetHRP = targetChar:FindFirstChild("HumanoidRootPart")
                    local targetHumanoid = targetChar:FindFirstChildOfClass("Humanoid")
                    
                    if targetHRP and targetHumanoid and targetHumanoid.Health > 0 then
                        local distance = (rootPart.Position - targetHRP.Position).Magnitude
                        
                        if distance <= 40 then
                            local uid = player.UserId
                            
                            Signal.FireServer("equip", qtid)
                            Signal.FireServer("meleeItemHit", "player", { 
                                hitPlayerId = uid, 
                                meleeType = hitMOD 
                            })
                            
                            break
                        end
                    end
                end
            end
        end

        -- 踩踏光环
        if autostomp then
            for _, player in ipairs(Players:GetPlayers()) do
                if player ~= LocalPlayer and player.Character then
                    local targetChar = player.Character
                    local targetHRP = targetChar:FindFirstChild("HumanoidRootPart")
                    local targetHumanoid = targetChar:FindFirstChildOfClass("Humanoid")
                    
                    if targetHRP and targetHumanoid and targetHumanoid.Health < 20 then
                        local distance = (rootPart.Position - targetHRP.Position).Magnitude
                        
                        if distance <= 40 then
                            Signal.FireServer("stomp", player)
                            break
                        end
                    end
                end
            end
        end
    end)
end)

-- 监听角色重生
local function onCharacterAdded(character)
    character:WaitForChild("Humanoid")
    character:WaitForChild("HumanoidRootPart")
    qtid = getFistsGUID()
    autoSellOnce() -- 角色重生时自动售卖
end

-- ========================
-- 物品收集与服务器跳转
-- ========================
local forbiddenZoneCenter = Vector3.new(352.884155, 13.0287256, -1353.05396)
local forbiddenRadius = 80
local currentJobId = game.JobId

-- 定义黑名单物品
local blacklistedItems = {
    "NextBot Grenade", "Military Armory Keycard", "Helicopter", 
    "Diamond Ring", "Diamond", "Void Gem", "Dark Matter Gem", 
    "Rollie", "Nuclear Missile Launcher", "Suitcase Nuke", 
    "Trident", "Golden Cup"
}

-- 定义目标物品
local targetItems = { 
    "Money Printer", "Blue Candy Cane", "Bunny Balloon", "Ghost Balloon", 
    "Clover Balloon", "Bat Balloon", "Gold Clover Balloon", "Golden Rose", 
    "Black Rose", "Heart Balloon", "Dafy Money Printor", "NextBot Grenade", 
    "Military Armory Keycard", "Trident", "Helicopter", "Diamond Ring", 
    "Diamond", "Void Gem", "Dark Matter Gem", "Rollie", "Nuclear Missile Launcher",
    "Suitcase Nuke", "Trident", "Golden Cup"
}

-- 获取实际可拾取的物品列表
local function getActualTargetItems()
    if blacklistEnabled then
        local filteredItems = {}
        for _, itemName in ipairs(targetItems) do
            local isBlacklisted = false
            for _, blacklistedItem in ipairs(blacklistedItems) do
                if itemName == blacklistedItem then
                    isBlacklisted = true
                    break
                end
            end
            if not isBlacklisted then
                table.insert(filteredItems, itemName)
            end
        end
        return filteredItems
    else
        return targetItems
    end
end

-- 增加物品检测计数
local function incrementItemDetection()
    itemDetectionCount = itemDetectionCount + 1
    if saveItemDetectionCount(itemDetectionCount) then
        updateItemDetectionDisplay()
        print("✅ 检测到目标物品，总检测次数: " .. itemDetectionCount)
    end
end

-- 增加印钞机检测计数
local function incrementMoneyPrinterDetection()
    moneyPrinterCount = moneyPrinterCount + 1
    if saveMoneyPrinterCount(moneyPrinterCount) then
        updateMoneyPrinterDisplay()
        print("💰 检测到印钞机! 总印钞机检测次数: " .. moneyPrinterCount)
    end
end

-- 服务器跳转功能
local function TPServer()
    print("🔄 正在寻找新服务器...")
    
    local success, servers = pcall(function()
        local response = game:HttpGet("https://games.roblox.com/v1/games/"..game.PlaceId.."/servers/Public?limit=100")
        return HttpService:JSONDecode(response)
    end)
    
    if not success then
        task.wait(1)
        TPServer()
        return
    end
    
    local availableServers = {}
    
    if servers and servers.data then
        for _, server in ipairs(servers.data) do
            -- 排除已访问的服务器和当前服务器
            if server.playing < server.maxPlayers and server.id ~= currentJobId and not (visitedServers and visitedServers[server.id]) then
                table.insert(availableServers, {
                    id = server.id,
                    players = server.playing,
                    maxPlayers = server.maxPlayers
                })
            end
        end
    end
    
    if #availableServers > 0 then
        table.sort(availableServers, function(a, b)
            return a.players < b.players
        end)
        
        local bestServers = {}
        local quarterIndex = math.max(1, math.floor(#availableServers * 0.25))
        
        for i = 1, quarterIndex do
            table.insert(bestServers, availableServers[i].id)
        end
        
        if #bestServers > 0 then
            local selectedServer = bestServers[math.random(1, #bestServers)]
            print("🚀 正在跳转到服务器: " .. selectedServer)
            TeleportService:TeleportToPlaceInstance(game.PlaceId, selectedServer)
        else
            local randomServer = availableServers[math.random(1, #availableServers)].id
            print("🚀 正在跳转到随机服务器: " .. randomServer)
            TeleportService:TeleportToPlaceInstance(game.PlaceId, randomServer)
        end
    else
        -- 如果没有可用的新服务器，随机选择一个已访问的服务器
        local visitedServerIds = {}
        if visitedServers then
            for serverId in pairs(visitedServers) do
                if serverId ~= currentJobId then
                    table.insert(visitedServerIds, serverId)
                end
            end
        end
        
        if #visitedServerIds > 0 then
            local randomVisitedServer = visitedServerIds[math.random(1, #visitedServerIds)]
            print("🚀 正在跳转到已访问服务器: " .. randomVisitedServer)
            TeleportService:TeleportToPlaceInstance(game.PlaceId, randomVisitedServer)
        else
            print("⏳ 未找到可用服务器，1秒后重试...")
            task.wait(0.5)
            TPServer()
        end
    end
end

-- 物品检测
local function FindTargetItems()
    local foundItems = {}
    local startTime = os.clock()
    local actualTargetItems = getActualTargetItems()
    
    local workspaceEntities = workspace:FindFirstChild("Game")
    if not workspaceEntities then return foundItems end
    
    local entities = workspaceEntities:FindFirstChild("Entities")
    if not entities then return foundItems end
    
    local itemPickup = entities:FindFirstChild("ItemPickup")
    if not itemPickup then return foundItems end
    
    for _, itemFolder in pairs(itemPickup:GetChildren()) do
        for _, item in pairs(itemFolder:GetChildren()) do
            if (item:IsA("MeshPart") or item:IsA("Part")) and os.clock() - startTime < 0.5 then
                local itemPos = item.Position
                local distance = (itemPos - forbiddenZoneCenter).Magnitude
                
                if distance > forbiddenRadius then
                    local prompt = item:FindFirstChildOfClass("ProximityPrompt")
                    if prompt then
                        for _, targetItem in ipairs(actualTargetItems) do
                            if prompt.ObjectText == targetItem then
                                -- 增加物品检测计数
                                incrementItemDetection()
                                
                                -- 如果是印钞机，增加印钞机计数
                                if prompt.ObjectText == "Money Printer" or prompt.ObjectText == "Dafy Money Printor" then
                                    incrementMoneyPrinterDetection()
                                end
                                
                                local charRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                                local distanceToPlayer = charRoot and (itemPos - charRoot.Position).Magnitude or math.huge
                                
                                table.insert(foundItems, {
                                    item = item,
                                    prompt = prompt,
                                    distance = distanceToPlayer
                                })
                                break
                            end
                        end
                    end
                end
            end
        end
    end
    
    table.sort(foundItems, function(a, b)
        return a.distance < b.distance
    end)
    
    return foundItems
end

-- 物品收集
local function PickItem(item, prompt)
    if not item or not prompt or not item.Parent then return false end
    
    local startTime = tick()
    local timeout = 3
    local itemCollected = false
    local shouldSwitchServer = false
    
    prompt.RequiresLineOfSight = false
    prompt.HoldDuration = 0
    
    local eKeyLoop = coroutine.create(function()
        while not itemCollected and item and item.Parent and tick() - startTime < timeout do
            VirtualInputManager:SendKeyEvent(true, "E", false, game)
            task.wait(0.01)
            VirtualInputManager:SendKeyEvent(false, "E", false, game)
            task.wait(0.01)
        end
    end)
    
    coroutine.resume(eKeyLoop)
    
    local connection
    connection = RunService.Heartbeat:Connect(function()
        if not item or not item.Parent then
            itemCollected = true
            if connection then connection:Disconnect() end
            return
        end
        
        if tick() - startTime >= timeout then
            shouldSwitchServer = true
            if connection then connection:Disconnect() end
            return
        end
        
        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
            LocalPlayer.Character.HumanoidRootPart.CFrame = item.CFrame * CFrame.new(0, 2, 0)
        end
        fireproximityprompt(prompt)
    end)
    
    repeat 
        task.wait(0.1) 
    until itemCollected or not item or not item.Parent or tick() - startTime >= timeout
    
    if connection then
        connection:Disconnect()
    end
    
    if shouldSwitchServer then
        TPServer()
    end
    
    return itemCollected
end

-- 自动按E功能
local function autoPressE()
    while scriptEnabled do
        VirtualInputManager:SendKeyEvent(true, "E", false, game)
        task.wait(0.01)
        VirtualInputManager:SendKeyEvent(false, "E", false, game)
        task.wait(0.01)
    end
end

-- 主循环
local function mainLoop()
    while scriptEnabled do
        local character = LocalPlayer.Character
        if not character then
            LocalPlayer.CharacterAdded:Wait()
            character = LocalPlayer.Character
        end
        
        local humanoidRootPart = character:WaitForChild("HumanoidRootPart")
        local humanoid = character:WaitForChild("Humanoid")
        
        local items = FindTargetItems()
        if #items > 0 then
            for _, itemData in ipairs(items) do
                if PickItem(itemData.item, itemData.prompt) then
                    break
                end
            end
        else
            TPServer()
        end
        
        task.wait(0.1)
    end
end

-- ========================
-- 脚本主启动函数
-- ========================
local function startScript()
    print("🎉 BEN Auto Script 开始启动...")
    
    -- 等待人物加载完成
    local character = waitForCharacterLoad()
    
    -- 启用脚本执行
    scriptEnabled = true
    
    -- 启动所有功能协程
    trackCoroutine(autoWKeyLoop, "auto_w_key")
    trackCoroutine(autoPressE, "auto_press_e")
    trackCoroutine(mainLoop, "main_loop")
    
    -- 安排自定义时间后强制换服
    scheduleForceServerSwitch()
    
    print("✅ 脚本已完全加载并开始执行!")
    print("📁 数据路径: " .. basePath)
    print("🔢 当前执行次数: " .. readExecutionCount())
    print("💰 当前印钞机检测次数: " .. moneyPrinterCount)
    print("⚡ 自动W键功能: " .. (autoWEnabled and "已启用" or "已禁用"))
    print("🚫 黑名单功能: " .. (blacklistEnabled and "已启用" or "已禁用"))
    print("⏰ 换服时间设置为: " .. huanfu .. "秒")
    print("⏰ " .. huanfu .. "秒后将强制更换服务器")
end

-- 初始化角色监听
if LocalPlayer.Character then
    onCharacterAdded(LocalPlayer.Character)
else
    LocalPlayer.CharacterAdded:Connect(onCharacterAdded)
end

-- 更新UI显示
updateVisitedServersDisplay()
updateCountDisplay()
updateBlacklistButton()
updateHuanfuDisplay()

-- 启动脚本
startScript()
