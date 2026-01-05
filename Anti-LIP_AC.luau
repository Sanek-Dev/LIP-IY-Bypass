if not getconnections or not debug or typeof(getconnections) ~= "function" or
typeof(debug) ~= "table" or not debug.setupvalue or typeof(debug.setupvalue) ~= "function"
or not debug.getupvalue or typeof(debug.getupvalue) ~= "function" or not cloneref
or typeof(cloneref) ~= "function" then
    error("Executor not supported")
end

local Players = cloneref(game:GetService("Players"))
local RunService = cloneref(game:GetService("RunService"))
local LocalPlayer = Players.LocalPlayer

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

local AlcDisableCharacterChecks = function(char)
    local HRP = char:FindFirstChild("HumanoidRootPart")
    if not HRP then return false end
    local Torso = char:FindFirstChild("Torso") or char:FindFirstChild("LowerTorso")
    if not Torso then return false end

    local disabledDescConn = false
    for i,v in ipairs(getconnections(char.DescendantAdded)) do
        if not v.Function or iscclosure(v.Function) then continue end
        local _script = GetScriptFromFunction(v.Function)
        if _script:GetFullName() == "ReplicatedFirst.BClient" then
            v:Disable()

            char.DescendantAdded:Connect(function(desc)
                debug.setupvalue(v.Function, 2, true)
            end)
            disabledDescConn = true
            break
        end
    end

    local disabledHrpConn = false
    for i,v in ipairs(getconnections(HRP.ChildAdded)) do
        if not v.Function or iscclosure(v.Function) then continue end
        local _script = GetScriptFromFunction(v.Function)
        if _script:GetFullName() == "ReplicatedFirst.BClient" then
            v:Disable()
            disabledHrpConn = true
            break
        end
    end

    local disabledStepped = false
    for i,v in ipairs(getconnections(RunService.Stepped)) do
        local func = v.Function
        if not func or iscclosure(func) then continue end
        local _script = GetScriptFromFunction(func)
        local hrpUpval = debug.getupvalue(func, 1)
        local detectCountUpval = debug.getupvalue(func, 3)
        if _script:GetFullName() == "ReplicatedFirst.BClient" and hrpUpval and hrpUpval == HRP and (typeof(detectCountUpval) == "number" or typeof(detectCountUpval) == "boolean") then
            if v.Enabled then v:Disable() end
            disabledStepped = true
            break
        end
    end

    local disabledTorsoConn = false
    for i,v in ipairs(getconnections(Torso.Changed)) do
        if not v.Function or iscclosure(v.Function) then continue end
        local _script = GetScriptFromFunction(v.Function)
        local torsoUpval = debug.getupvalue(v.Function, 1)
        if _script:GetFullName() == "ReplicatedFirst.BClient" and torsoUpval and torsoUpval == Torso then
            v:Disable()
            disabledTorsoConn = true
            break
        end
    end

    return disabledDescConn and disabledHrpConn and disabledStepped
end

LocalPlayer.CharacterAdded:Connect(function(char)
    repeat task.wait() until AlcDisableCharacterChecks(char)
    print("Character is now protected by Anti-LIPAC guard!")
end)

if LocalPlayer.Character then
    repeat
        if not LocalPlayer.Character then break end
        task.wait()
    until AlcDisableCharacterChecks(LocalPlayer.Character)
end

local CurrentCamera = cloneref(workspace.CurrentCamera)
CurrentCamera:GetPropertyChangedSignal("CameraType"):Connect(function()
    if CurrentCamera.CameraType ~= Enum.CameraType.Scriptable then
        CurrentCamera.CameraType = Enum.CameraType.Track
    end
end)
CurrentCamera.CameraType = Enum.CameraType.Track
LocalPlayer.CameraMaxZoomDistance = 100

print("[Anti-LIP-AC] Initialized!")

loadstring(game:HttpGet("https://raw.githubusercontent.com/EdgeIY/infiniteyield/master/source"))()
print("[IY] Loaded")