if not getconnections or not debug or typeof(getconnections) ~= "function" or
typeof(debug) ~= "table" or not debug.setupvalue or typeof(debug.setupvalue) ~= "function"
or not debug.getupvalue or typeof(debug.getupvalue) ~= "function" or not cloneref
or typeof(cloneref) ~= "function" or not iscclosure or typeof(iscclosure) ~= "function"
or not getgc or typeof(getgc) ~= "function" or not debug.getconstants
or typeof(debug.getconstants) ~= "function" or not debug.getupvalues
or typeof(debug.getupvalues) ~= "function" or not newcclosure
or typeof(newcclosure) ~= "function" or not hookfunction
or typeof(hookfunction) ~= "function" then
    error("Executor is not supported")
end

-- Services & globals
local Players = cloneref(game:GetService("Players"))
local RunService = cloneref(game:GetService("RunService"))
local LocalPlayer = Players.LocalPlayer
local CurrentCamera = cloneref(workspace.CurrentCamera)

-- Constants
local MAX_CAMERA_ZOOM = 100
local CAMERA_TYPE = Enum.CameraType.Track
local ANTI_CHEAT_FULL_NAME = "ReplicatedFirst.BClient"

-- Functions
local IsClientScript = function(_script)
    if not _script or typeof(_script) ~= "Instance" then return false end

    return _script:IsA("ModuleScript") or _script:IsA("LocalScript") or (_script:IsA("Script") and _script.RunContext == Enum.RunContext.Client)
end

local GetScriptFromFunction = function(func)
    if not func or iscclosure(func) then return nil end
    
    local fenv = getfenv(func)
    if not fenv then return nil end
    local _script = rawget(fenv, "script")
    if not _script or not IsClientScript(_script) then return nil end

    return _script
end

local GetAntiCheatConnections = function(signal, onlyEnabled)
    if not signal or typeof(signal) ~= "RBXScriptSignal" then error("Invalid signal argument!") end

    local result = {}
    for i,v in ipairs(getconnections(signal)) do
        local func = v.Function
        if not func or iscclosure(func) then continue end
        local _script = GetScriptFromFunction(func)
        if not _script or typeof(_script) ~= "Instance" or _script:GetFullName() ~= ANTI_CHEAT_FULL_NAME then continue end

        if not onlyEnabled or (onlyEnabled and v.Enabled) then
            table.insert(result, v)
        end
    end

    return result
end

-- Returns thread.spawn & FreezeTrueLoop closures
local FindAntiCoreGuiThreadFunctions = function()
    local threadFunc = nil
    local freezeFunc = nil
    local encounters = 0
    for i,v in ipairs(getgc(false)) do
        if typeof(v) ~= "function" or iscclosure(v) then continue end

        local constants = debug.getconstants(v)
        local upvals = debug.getupvalues(v)
        if upvals and constants and table.find(constants, "CoreGui") ~= nil
        and table.find(constants, "__mode") ~= nil
        and table.find(constants, "kv") ~= nil
        and #upvals == 1 and typeof(upvals[1]) == "function" then
            threadFunc = v
            freezeFunc = upvals[1]
            encounters += 1
        end
    end
    if encounters ~= 1 then error("Found multiple Anti-CoreGui functions (try to re-execute)! Encounters: "..tostring(encounters).."/1") end

    return threadFunc, freezeFunc
end

local DisableAntiCoreGui = function()
    local threadFunc, freezeFunc = FindAntiCoreGuiThreadFunctions()
    if not threadFunc or not freezeFunc or typeof(threadFunc) ~= "function" or
    typeof(freezeFunc) ~= "function" then error("[Critical] Anti-CoreGui functions not found") end

    hookfunction(freezeFunc, newcclosure(function()
        local thread = coroutine.running()
        if coroutine.status(thread) ~= "dead" then
            coroutine.close(thread)
        end
    end))
end

local AlcDisableCharacterChecks = function(char)
    local HRP = char:FindFirstChild("HumanoidRootPart")
    if not HRP then return false end
    local Torso = char:FindFirstChild("Torso") or char:FindFirstChild("LowerTorso")
    if not Torso then return false end
    local Hum = char:FindFirstChildOfClass("Humanoid")
    if not Hum then return false end

    -- Fly, vfly
    local charDescConnections = GetAntiCheatConnections(char.DescendantAdded, true)
    for i,v in ipairs(charDescConnections) do
        v:Disable()

        local descConn = nil
        descConn = char.DescendantAdded:Connect(function(desc)
            -- DONT FORGET TO UPDATE UPVALUE INDEX!
            pcall(debug.setupvalue, v.Function, 2, true)
        end)
        local parentConn = nil
        parentConn = char:GetPropertyChangedSignal("Parent"):Connect(function()
            if char.Parent == nil then
                descConn:Disconnect()
                descConn = nil
                parentConn:Disconnect()
                parentConn = nil
            end
        end)
    end

    local hrpChildAddedConnections = GetAntiCheatConnections(HRP.ChildAdded)
    for i,v in ipairs(hrpChildAddedConnections) do
        if v.Enabled then v:Disable() end
    end

    -- Noclip
    local runServiceSteppedConnections = GetAntiCheatConnections(RunService.Stepped)
    local noclipSteppedCount = 0
    for i,v in ipairs(runServiceSteppedConnections) do
        local upvals = debug.getupvalues(v.Function)
        if not upvals or #upvals < 3 then continue end

        local hrpUpval = upvals[1]
        local detectCountUpval = upvals[3]
        if hrpUpval and hrpUpval == HRP and (typeof(detectCountUpval) == "number" or typeof(detectCountUpval) == "boolean") then
            if v.Enabled then v:Disable() end
            noclipSteppedCount += 1
        end
    end

    local torsoChangedConnections = GetAntiCheatConnections(Torso.Changed)
    local torsoChangedCount = 0
    for i,v in ipairs(torsoChangedConnections) do
        local upvals = debug.getupvalues(v.Function)
        if not upvals or #upvals < 1 then continue end

        local torsoUpval = upvals[1]
        if torsoUpval and torsoUpval == Torso then
            if v.Enabled then v:Disable() end
            torsoChangedCount += 1
        end
    end

    -- Teleportation
    local fastTeleportCount = 0
    for i,v in ipairs(runServiceSteppedConnections) do
        local upvals = debug.getupvalues(v.Function)
        local constants = debug.getconstants(v.Function)
        if upvals and #upvals >= 1 and constants
        and table.find(constants, "AssemblyLinearVelocity") ~= nil
        and table.find(constants, "Position") ~= nil
        and table.find(constants, "CFrame") ~= nil
        and table.find(constants, "CFrameReadHook") ~= nil
        and table.find(constants, "FastTeleport") ~= nil
        and upvals[1] == HRP then
            if v.Enabled then v:Disable() end
            fastTeleportCount += 1
        end
    end

    local hrpCFrameChangedConnections = GetAntiCheatConnections(HRP:GetPropertyChangedSignal("CFrame"))
    local hrpCFrameChangedCount = 0
    for i,v in ipairs(hrpCFrameChangedConnections) do
        if v.Enabled then v:Disable() end
        hrpCFrameChangedCount += 1
    end

    -- Flyjump & Humanoid states
    local humStateChangedConnections = GetAntiCheatConnections(Hum.StateChanged)
    local humStateChangedCount = 0
    for i,v in ipairs(humStateChangedConnections) do
        if v.Enabled then v:Disable() end
        humStateChangedCount += 1
    end

    return #charDescConnections > 0 and #hrpChildAddedConnections > 0 and noclipSteppedCount > 0 and torsoChangedCount > 0 and fastTeleportCount > 0 and hrpCFrameChangedCount > 0 and humStateChangedCount > 0
end

local OnCharacterAddedCallback = function(char)
    local hum = char:WaitForChild("Humanoid")

    hum:GetPropertyChangedSignal("SeatPart"):Connect(function()
        if not hum.SeatPart then
            CurrentCamera.CameraSubject = hum
        end
    end)
end

-- Main
local success, status = pcall(DisableAntiCoreGui)
if not success then
    error("Failed to bypass :sob: : "..status)
end

LocalPlayer.CharacterAdded:Connect(function(char)
    repeat task.wait() until AlcDisableCharacterChecks(char)
    OnCharacterAddedCallback(char)
    print("Character is now protected by Anti-LIP-AC guard!")
end)

if LocalPlayer.Character then
    repeat
        if not LocalPlayer.Character then break end
        task.wait()
    until AlcDisableCharacterChecks(LocalPlayer.Character)
    if LocalPlayer.Character then OnCharacterAddedCallback(LocalPlayer.Character) end
end

CurrentCamera:GetPropertyChangedSignal("CameraType"):Connect(function()
    if CurrentCamera.CameraType ~= Enum.CameraType.Scriptable then
        CurrentCamera.CameraType = CAMERA_TYPE
    end
end)

LocalPlayer:GetPropertyChangedSignal("CameraMaxZoomDistance"):Connect(function()
    LocalPlayer.CameraMaxZoomDistance = MAX_CAMERA_ZOOM
end)

CurrentCamera.CameraType = CAMERA_TYPE
LocalPlayer.CameraMaxZoomDistance = MAX_CAMERA_ZOOM

print("[Anti-LIP-AC] Initialized!")

loadstring(game:HttpGet("https://raw.githubusercontent.com/EdgeIY/infiniteyield/master/source"))()
print("[IY] Loaded")
