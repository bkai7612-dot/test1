--!strict
--[[
	MinigameController
	Opens the mini-game the server issued (MinigameStart), submits the
	answer, and closes on the server's verdict (MinigameResult). The server
	alone decides success. A local practice mode (RunLocal) generates and
	verifies challenges on the client for the tutorial only; it never touches
	the server's objectives.
]]

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local Minigames = require(Shared.Logic.Minigames)
local Signal = require(Shared.Utility.Signal)

local InteractionController = require(script.Parent.InteractionController)
local MinigameUI = require(script.Parent.Parent.UI.Minigames)

local localPlayer = Players.LocalPlayer

local MinigameController = {}

-- (success: boolean, reason: string?)
MinigameController.Finished = Signal.new()

local gui: ScreenGui
local activeSession: string? = nil
local closeCurrent: (() -> ())? = nil

local function close()
	if closeCurrent then
		closeCurrent()
		closeCurrent = nil
	end
	activeSession = nil
	gui.Enabled = false
	InteractionController.SetSuppressed(false)
	ContextActionService:UnbindAction("VoidlineMinigameCancel")
end

local function open(kind: string, challenge: any, info: any, submit: (any) -> (), cancel: () -> ())
	if closeCurrent then
		closeCurrent()
	end
	local builder = (MinigameUI :: any)[kind]
	if not builder then
		cancel()
		return
	end
	gui.Enabled = true
	InteractionController.SetSuppressed(true)
	closeCurrent = builder(gui, challenge, info, { Submit = submit, Cancel = cancel })
	ContextActionService:BindAction("VoidlineMinigameCancel", function(_, state)
		if state == Enum.UserInputState.Begin then
			cancel()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.ButtonB, Enum.KeyCode.Escape)
end

function MinigameController.IsOpen(): boolean
	return closeCurrent ~= nil
end

-- Tutorial practice: fully local, no server involvement.
function MinigameController.RunLocal(kind: string, onDone: (boolean) -> ())
	local challenge, secret = Minigames.generate(kind, Random.new())
	local started = os.clock()
	open(kind, challenge, { Title = "Practice: " .. kind, TimeLimit = Minigames.TimeLimit[kind] }, function(answer)
		local ok = Minigames.verify(kind, secret, answer) and os.clock() - started >= 0.5
		close()
		MinigameController.Finished:Fire(ok, if ok then nil else "Not quite - try again.")
		onDone(ok)
	end, function()
		close()
		onDone(false)
	end)
end

function MinigameController.Init()
	gui = Instance.new("ScreenGui")
	gui.Name = "VoidlineMinigame"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 8
	gui.Enabled = false
	gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	gui.Parent = localPlayer:WaitForChild("PlayerGui")
	local scale = Instance.new("UIScale")
	scale.Name = "Scale"
	scale.Parent = gui
end

function MinigameController.GetGui(): ScreenGui
	return gui
end

function MinigameController.Start()
	local submitRemote = Net.getEvent(Net.Names.MinigameSubmit)
	local cancelRemote = Net.getEvent(Net.Names.MinigameCancel)

	Net.getEvent(Net.Names.MinigameStart).OnClientEvent:Connect(function(sessionId: any, kind: any, challenge: any, info: any)
		if type(sessionId) ~= "string" or type(kind) ~= "string" or type(challenge) ~= "table" then
			return
		end
		activeSession = sessionId
		open(kind, challenge, if type(info) == "table" then info else {}, function(answer)
			if activeSession == sessionId then
				submitRemote:FireServer(sessionId, answer)
			end
		end, function()
			if activeSession == sessionId then
				cancelRemote:FireServer(sessionId)
			end
			close()
		end)
	end)

	Net.getEvent(Net.Names.MinigameResult).OnClientEvent:Connect(function(sessionId: any, success: any, reason: any)
		if sessionId ~= activeSession then
			return
		end
		close()
		MinigameController.Finished:Fire(success == true, if type(reason) == "string" then reason else nil)
	end)
end

return MinigameController
