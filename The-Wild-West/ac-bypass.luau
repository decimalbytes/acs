local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer


local SharedModules = ReplicatedStorage:FindFirstChild("SharedModules")
local Global
local Network


local RepCharHandler
local CharRepUtils


local function Init()
    if SharedModules and SharedModules:FindFirstChild("Global") then
        Global = require(SharedModules.Global)
        Network = Global.Network
    else
        for _, module in pairs(getgc(true)) do
            if type(module) == "table" then
                if rawget(module, "Network") and rawget(module, "SyncedTime") then
                    Global = module
                    Network = Global.Network
                    break
                end
            end
        end
    end

    
    for _, module in pairs(getgc(true)) do
        if type(module) == "table" and rawget(module, "GetRepChar") and rawget(module, "AnimationUpdate") then
            RepCharHandler = module
            break
        end
    end

    
    if Global then
        CharRepUtils = Global.CharRepUtils
    else
        for _, module in pairs(getgc(true)) do
            if type(module) == "table" and rawget(module, "CharRepData") and rawget(module, "ClientRepRate") then
                CharRepUtils = module
                break
            end
        end
    end
    if not Global or not Network or not RepCharHandler then
        warn("couldn't find necessary modules")
        return false
    end
    
    return true
end

local Bypass = {
    Enabled = false,
    HookActive = false,
    SafeTeleporting = false,
    OriginalFireServer = nil,
    OriginalUpdateLocalCharPlatform = nil,
    LastPosition = nil,
    TeleportQueue = {}
}


function Bypass:DisableVelocityChecks()
    if not RepCharHandler or not RepCharHandler._UpdateLocalCharPlatform then return end
    
    if not self.OriginalUpdateLocalCharPlatform then
        self.OriginalUpdateLocalCharPlatform = RepCharHandler._UpdateLocalCharPlatform
        
        RepCharHandler._UpdateLocalCharPlatform = function(...)
            if self.SafeTeleporting then
                
                return
            end
            return self.OriginalUpdateLocalCharPlatform(...)
        end
    end
end


function Bypass:HookFireServer()
    if not Network or self.HookActive then return end

    self.OriginalFireServer = Network.FireServer
    self.HookActive = true
    
    Network.FireServer = function(netObj, event, ...)
        local args = {...}
        if self.SafeTeleporting and event == "DamageSelf" then
            return
        end
        if self.SafeTeleporting and event == "CharUpdate" then
            return
        end
        if event == "ACDTResponse" then
            return
        end
        return self.OriginalFireServer(netObj, event, unpack(args))
    end
end

function Bypass:HookReplicateCharacters()
    if not RepCharHandler or not RepCharHandler.ReplicateCharacters then return end
    local originalReplicateCharacters = RepCharHandler.ReplicateCharacters
    RepCharHandler.ReplicateCharacters = function(self, ...)
        if Bypass.SafeTeleporting then
            
            return
        end
        return originalReplicateCharacters(self, ...)
    end
end

function Bypass:HookFlags()
    if not RepCharHandler or not RepCharHandler.Flags then return end
    local mt = getmetatable(RepCharHandler.Flags)
    if mt and mt.__newindex then
        local original__newindex = mt.__newindex
        mt.__newindex = function(t, k, v)
            if Bypass.SafeTeleporting and (k == "DamageSelf" or k == "LowerStamina" or k == "CharacterReplicate") then
                return 
            end
            return original__newindex(t, k, v)
        end
    end
end

function Bypass:BypassMovementChecks()
    
    if RepCharHandler and getmetatable(getmetatable(RepCharHandler)) then
        local oldCharUpdate = getmetatable(getmetatable(RepCharHandler)).__namecall
        setmetatable(getmetatable(RepCharHandler), {
            __namecall = newcclosure(function(self, ...)
                local args = {...}
                local method = getnamecallmethod()
                if method == "FireServer" and args[1] == "DamageSelf" and self.SafeTeleporting then
                    return 
                end
                return oldCharUpdate(self, ...)
            end)
        })
    end
    
    
    if Global and Global.PlayerCharacter and Global.PlayerCharacter.Ragdoll then
        local oldRagdoll = Global.PlayerCharacter.Ragdoll
        
        Global.PlayerCharacter.Ragdoll = function(...)
            if Bypass.SafeTeleporting then
                return 
            end
            return oldRagdoll(...)
        end
    end
end

function Bypass:Enable()
    if self.Enabled then return end
    	print("bypassing teleport detection...")
    if not Init() then 
        warn("failed to initialize bypass")
        return 
    end
    
    self:DisableVelocityChecks()
    self:HookFireServer()
    self:HookReplicateCharacters()
    self:HookFlags()
    self:BypassMovementChecks()
    
    self.Enabled = true
    print("bypass enabled!")
end

function Bypass:SafeTeleportState(enabled)
    self.SafeTeleporting = enabled
end

Bypass:Enable()
return Bypass
