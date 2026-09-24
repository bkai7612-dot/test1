-- Redeem promo codes.
local Util = require(script.Parent.Util)
local Notify = require(script.Parent.Notify)
local State = require(script.Parent.Parent.State)
local T = Util.Theme

local CodesPanel = {}

local frame

function CodesPanel.Init(gui, hud)
	local content
	frame, content = Util.panel(gui, "CODES", UDim2.fromOffset(460, 280), function()
		hud.ClosePanel("Codes")
	end)

	Util.label(content, "Enter a code for free rewards!", {
		Size = UDim2.new(1, 0, 0, 24),
		TextColor3 = T.sub,
	})
	local box = Util.new("TextBox", {
		Position = UDim2.new(0, 0, 0, 40),
		Size = UDim2.new(1, 0, 0, 50),
		BackgroundColor3 = T.panel2,
		BorderSizePixel = 0,
		Font = Enum.Font.GothamBold,
		PlaceholderText = "Type code here",
		PlaceholderColor3 = T.sub,
		Text = "",
		TextColor3 = T.text,
		TextScaled = true,
		ClearTextOnFocus = false,
		Parent = content,
	})
	Util.corner(box, 10)
	Util.padding(box, 10)

	local function redeem()
		local code = box.Text
		if code == "" then
			return
		end
		local ok, msg = State.Request("RedeemCode", code)
		if ok then
			box.Text = ""
		elseif msg then
			Notify.Show(msg, "error")
		end
	end
	Util.button(content, "REDEEM", T.good, {
		Position = UDim2.new(0, 0, 0, 104),
		Size = UDim2.new(1, 0, 0, 50),
	}, redeem)
	box.FocusLost:Connect(function(enterPressed)
		if enterPressed then
			redeem()
		end
	end)
end

function CodesPanel.Open()
	frame.Visible = true
end

function CodesPanel.Close()
	frame.Visible = false
end

return CodesPanel
