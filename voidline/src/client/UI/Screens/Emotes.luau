--!strict
--[[
	Emotes
	Plays owned emotes through the avatar's default Animate script (R15).
	Emotes are cosmetic; ownership comes from the server-synced profile.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared.Constants)
local CosmeticCatalog = require(Shared.Data.CosmeticCatalog)

local Components = require(script.Parent.Parent.Components)
local Create = require(script.Parent.Parent.Create)
local Theme = require(script.Parent.Parent.Theme)

local localPlayer = Players.LocalPlayer

local function play(emote: string): boolean
	local character = localPlayer.Character
	local animate = character and character:FindFirstChild("Animate")
	local bindable = animate and animate:FindFirstChild("PlayEmote")
	if bindable and bindable:IsA("BindableFunction") then
		local ok, result = pcall(function()
			return bindable:Invoke(emote)
		end)
		return ok and result ~= false
	end
	return false
end

return function(ctx: any)
	local root, body = Components.modal("Emotes", nil, ctx.Close, Vector2.new(520, 400))
	local grid = Create("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = body })
	Create("UIGridLayout", { CellSize = UDim2.fromOffset(150, 46), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = grid })
	local note = Components.label("", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		TextSize = Theme.TextSize.Small,
		TextColor3 = Theme.Color.Muted,
		Parent = body,
	})

	return {
		Root = root,
		Refresh = function()
			Components.clear(grid)
			local profile = ctx.Client.GetPrivate(Constants.PrivateKey.Profile)
			local owned = if type(profile) == "table" then profile.Owned or {} else {}
			local level = if type(profile) == "table" then profile.Level or 1 else 1
			for index, item in CosmeticCatalog.itemsForSlot("Emote") do
				if CosmeticCatalog.isUnlocked(item, owned, level) and item.Emote then
					Components.button(item.Name, function()
						if not play(item.Emote :: string) then
							note.Text = "Emotes need an R15 avatar."
						else
							ctx.Close()
						end
					end, "Secondary", { LayoutOrder = index, Parent = grid })
				end
			end
		end,
	}
end
