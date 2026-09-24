-- Spawns / despawns player cars and seats the driver.
-- Driving physics run on the owning client (network ownership), see
-- Client/CarController.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CarBuilder = require(Shared.CarBuilder)
local Upgrades = require(Shared.Upgrades)
local Remotes = require(Shared.Remotes)

local DataService = require(script.Parent.DataService)

local CarService = {}

local active = {} -- [player] = record
local carsFolder

local function seatCharacter(character, humanoid, seat)
	if humanoid.SeatPart then
		local weld = humanoid.SeatPart:FindFirstChild("SeatWeld")
		if weld then
			weld:Destroy()
		end
	end
	humanoid.Sit = false
	character:PivotTo(seat.CFrame * CFrame.new(0, 3, 0))
	seat:Sit(humanoid)
end

function CarService.Get(player)
	local rec = active[player]
	return rec and rec.model, rec and rec.mode
end

function CarService.Despawn(player)
	local rec = active[player]
	if not rec then
		return
	end
	active[player] = nil
	rec.cleaning = true
	for _, conn in rec.conns do
		conn:Disconnect()
	end
	local weld = rec.seat and rec.seat:FindFirstChild("SeatWeld")
	if weld then
		weld:Destroy()
	end
	if player.Parent then
		Remotes.Event("CarRemoved"):FireClient(player)
	end
	rec.model:Destroy()
end

-- mode: "race" | "test". Anchored cars are frozen (race countdown).
function CarService.Spawn(player, cframe, mode, anchored, extraAttributes)
	CarService.Despawn(player)
	local data = DataService.Get(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not data or not humanoid or humanoid.Health <= 0 or not character.PrimaryPart then
		return nil
	end

	local carId = data.selectedCar
	DataService.EnsureCar(data, carId)
	local model = CarBuilder.Build(carId, data.custom[carId], false)
	model.Name = player.Name .. "_Car"
	for key, value in Upgrades.GetStats(carId, data.upgrades[carId]) do
		model:SetAttribute(key, value)
	end
	model:SetAttribute("OwnerId", player.UserId)
	model:SetAttribute("Mode", mode)
	for key, value in extraAttributes or {} do
		model:SetAttribute(key, value)
	end

	-- Floating name tag for other players.
	local tag = Instance.new("BillboardGui")
	tag.Name = "NameTag"
	tag.Size = UDim2.fromOffset(200, 30)
	tag.StudsOffset = Vector3.new(0, 6, 0)
	tag.MaxDistance = 250
	tag.AlwaysOnTop = false
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.4
	label.Text = player.DisplayName
	label.Parent = tag
	tag.Parent = model.PrimaryPart
	tag.PlayerToHideFrom = player

	model:PivotTo(cframe)
	local chassis = model.PrimaryPart
	chassis.Anchored = anchored == true
	model.Parent = carsFolder

	local seat = model:FindFirstChild("DriverSeat")
	seatCharacter(character, humanoid, seat)
	if not anchored then
		pcall(function()
			chassis:SetNetworkOwner(player)
		end)
	end

	local rec = { model = model, mode = mode, seat = seat, conns = {} }
	active[player] = rec

	table.insert(
		rec.conns,
		seat:GetPropertyChangedSignal("Occupant"):Connect(function()
			if rec.cleaning or active[player] ~= rec or seat.Occupant ~= nil then
				return
			end
			if mode == "test" then
				-- Jumped out of a test drive: remove the car.
				task.defer(function()
					if active[player] == rec then
						CarService.Despawn(player)
					end
				end)
			else
				-- Racers can't leave their car mid-race; put them back in.
				task.delay(0.25, function()
					if active[player] ~= rec or seat.Occupant ~= nil then
						return
					end
					local ch = player.Character
					local hum = ch and ch:FindFirstChildOfClass("Humanoid")
					if hum and hum.Health > 0 then
						seatCharacter(ch, hum, seat)
					end
				end)
			end
		end)
	)
	table.insert(
		rec.conns,
		humanoid.Died:Connect(function()
			if active[player] == rec then
				CarService.Despawn(player)
			end
		end)
	)

	Remotes.Event("CarAssigned"):FireClient(player, model, mode)
	return model
end

-- Unfreeze a car (end of countdown) and hand physics to its driver.
function CarService.Release(player)
	local rec = active[player]
	if not rec or not rec.model.PrimaryPart then
		return
	end
	local chassis = rec.model.PrimaryPart
	chassis.Anchored = false
	pcall(function()
		chassis:SetNetworkOwner(player)
	end)
end

function CarService.Init()
	carsFolder = workspace:FindFirstChild("Cars") or Instance.new("Folder")
	carsFolder.Name = "Cars"
	carsFolder.Parent = workspace

	Players.PlayerRemoving:Connect(function(player)
		CarService.Despawn(player)
	end)
end

return CarService
