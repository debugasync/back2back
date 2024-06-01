local players = game:GetService("Players")
local client = players.LocalPlayer
local camera = workspace.CurrentCamera

local function declare(self, index, value, check)
	if self[index] == nil then
		self[index] = value
	elseif check then
		local methods = { "remove", "Disconnect" }

		for _, method in ipairs(methods) do
			pcall(function()
				value[method](value)
			end)
		end
	end

	return self[index]
end

local global = {}
declare(_G, "global", global)

global.services = {}

local function get(service)
	return global.services[service]
end

local services = {
	loop = {},
	player = {},
	new = {}
}

local function newDrawing(class, properties)
	local drawing = Drawing.new(class)
	for property, value in pairs(properties) do
		pcall(function()
			drawing[property] = value
		end)
	end
	return drawing
end

local function findPlayer(self, player)
	for character, data in pairs(self.cache) do
		if data.player == player then
			return character
		end
	end
end

local function checkPlayer(self, player)
	local success, check = pcall(function()
		local character = player:IsA("Player") and player.Character or player
		local children = { character.Humanoid, character.HumanoidRootPart }

		return children and character.Parent ~= nil
	end)

	return success and check
end

local function newPlayer(self, player)
	local function cache(character)
		print("Caching", character)
		self.cache[character] = {
			player = player,
			drawings = {
				name = newDrawing("Text", { Visible = false, Center = true }),
				health = newDrawing("Line", { Visible = false }),
				healthOutline = newDrawing("Line", { Visible = false }),
				healthText = newDrawing("Text", { Visible = false, Center = false }),
				distance = newDrawing("Text", { Visible = false, Center = true }),
				weapon = newDrawing("Text", { Visible = false, Center = true }),
				box = newDrawing("Square", { Visible = false }),
				boxOutline = newDrawing("Square", { Visible = false }),
			}
		}
	end

	local function check(character)
		if self:check(character) then
			cache(character)
		else
			local listener
			listener = character.ChildAdded:Connect(function()
				if self:check(character) then
					cache(character)
					listener:Disconnect()
				end
			end)
		end
	end

	if player.Character then
		check(player.Character)
	end
	player.CharacterAdded:Connect(check)
end

local function removePlayer(self, player)
	print("Removing", player)
	if player:IsA("Player") then
		local character = self:find(player)
		if character then
			self:remove(character)
		end
	else
		local drawings = self.cache[player].drawings
		self.cache[player] = nil

		for _, drawing in pairs(drawings) do
			drawing:Remove()
		end
	end
end

local function updatePlayer(self, character, data)
	if not self:check(character) then
		self:remove(character)
	end

	local player = data.player
	local root = character.HumanoidRootPart
	local humanoid = character.Humanoid
	local drawings = data.drawings

	if self:check(client) then
		data.distance = (client.Character.HumanoidRootPart.Position - root.Position).Magnitude
	end

	local weapon = character:FindFirstChildWhichIsA("Tool") or "none"

	task.spawn(function()
		local position, visible = camera:WorldToViewportPoint(root.Position)

		local visuals = global.features.visuals

		local function check()
			local team
			if visuals.teamCheck then
				team = player.Team ~= client.Team
			else
				team = true
			end
			return visuals.enabled and data.distance and data.distance <= visuals.renderDistance and team
		end

		local function color(color)
			if visuals.teamColor then
				color = player.TeamColor.Color
			end
			return color
		end

		if visible and check() then
			local scale = 1 / (position.Z * math.tan(math.rad(camera.FieldOfView * 0.5)) * 2) * 1000
			local x, y = math.floor(position.X), math.floor(position.Y)

			drawings.name.Text = "[ " .. player.Name .. " ]"
			drawings.name.Size = math.max(math.min(math.abs(12.5 * scale), 12.5), 10)
			drawings.name.Position = Vector2.new(x, (y - drawings.name.TextBounds.Y) - 2)
			drawings.name.Color = color(visuals.names.color)
			drawings.name.Outline = visuals.names.outline.enabled
			drawings.name.OutlineColor = visuals.names.outline.color

			drawings.name.ZIndex = 2

			local healthPercent = 100 / (humanoid.MaxHealth / humanoid.Health)

			drawings.healthOutline.From = Vector2.new(x - 5, y)
			drawings.healthOutline.To = Vector2.new(x - 5, y + 20)
			drawings.health.From = Vector2.new(x - 5, (y + 20) - 1)
			drawings.health.To = Vector2.new(x - 5, ((drawings.health.From.Y - ((20 / 100) * healthPercent))) + 2)
			drawings.healthText.Text = "[ HP " .. math.floor(humanoid.Health) .. " ]"
			drawings.healthText.Size = math.max(math.min(math.abs(11 * scale), 11), 10)
			drawings.healthText.Position = Vector2.new(drawings.health.To.X - (drawings.healthText.TextBounds.X + 3), (drawings.health.To.Y - (2 / scale)))

			drawings.health.Color = visuals.health.colorLow:Lerp(visuals.health.color, healthPercent * 0.01)
			drawings.healthOutline.Color = visuals.health.outline.color
			drawings.healthOutline.Thickness = 3
			drawings.healthText.Color = drawings.health.Color
			drawings.healthText.Outline = visuals.health.text.outline.enabled
			drawings.healthText.OutlineColor = visuals.health.outline.color

			drawings.healthOutline.ZIndex = 1

			drawings.distance.Text = "[ " .. math.floor(data.distance) .. " ]"
			drawings.distance.Size = math.max(math.min(math.abs(11 * scale), 11), 10)
			drawings.distance.Position = Vector2.new(x, (y + 20) + (drawings.distance.TextBounds.Y * 0.25))
			drawings.distance.Color = color(visuals.distance.color)
			drawings.distance.Outline = visuals.distance.outline.enabled
			drawings.distance.OutlineColor = visuals.distance.outline.color

			drawings.weapon.Text = "[ " .. weapon .. " ]"
			drawings.weapon.Size = math.max(math.min(math.abs(11 * scale), 11), 10)
			drawings.weapon.Position = visuals.distance.enabled and Vector2.new(drawings.distance.Position.X,
            drawings.weapon.Position.Y + (drawings.weapon.TextBounds.Y * 0.75)) or drawings.distance.Position
			drawings.weapon.Color = color(visuals.weapon.color)
			drawings.weapon.Outline = visuals.weapon.outline.enabled
			drawings.weapon.OutlineColor = visuals.weapon.outline.color

			local width, height = math.floor(4.5 * scale), math.floor(6 * scale)
			local xPosition, yPosition = math.floor(x - width * 0.5), math.floor((y - height * 0.5) + (0.5 * scale))

			drawings.box.Size = Vector2.new(width, height)
			drawings.box.Position = Vector2.new(xPosition, yPosition)
			drawings.boxFilled.Size = drawings.box.Size
			drawings.boxFilled.Position = drawings.box.Position
			drawings.boxOutline.Size = drawings.box.Size
			drawings.boxOutline.Position = drawings.box.Position

			drawings.box.Color = color(visuals.boxes.color)
			drawings.box.Thickness = 1
			drawings.boxFilled.Color = color(visuals.boxes.filled.color)
			drawings.boxFilled.Transparency = visuals.boxes.filled.transparency
			drawings.boxOutline.Color = visuals.boxes.outline.color
			drawings.boxOutline.Thickness = 3

			drawings.boxOutline.ZIndex = drawings.box.ZIndex - 1
			drawings.boxFilled.ZIndex = drawings.boxOutline.ZIndex - 1

			drawings.box.Visible = (check() and visible and visuals.boxes.enabled)
			drawings.boxFilled.Visible = (check() and drawings.box.Visible and visuals.boxes.filled.enabled)
			drawings.boxOutline.Visible = (check() and drawings.box.Visible and visuals.boxes.outline.enabled)
			drawings.name.Visible = (check() and visible and visuals.names.enabled)
			drawings.health.Visible = (check() and visible and visuals.health.enabled)
			drawings.healthOutline.Visible = (check() and drawings.health.Visible and visuals.health.outline.enabled)
			drawings.healthText.Visible = (check() and drawings.health.Visible and visuals.health.text.enabled)
			drawings.distance.Visible = (check() and visible and visuals.distance.enabled)
			drawings.weapon.Visible = (check() and visible and visuals.weapon.enabled)
		end
	end)
end

global.features = {
	visuals = {
		enabled = true,
		teamCheck = false,
		teamColor = true,
		renderDistance = 2000,
		boxes = {
			enabled = true,
			color = Color3.fromRGB(255, 255, 255),
			outline = {
				enabled = true,
				color = Color3.fromRGB(0, 0, 0),
			},
			filled = {
				enabled = true,
				color = Color3.fromRGB(255, 255, 255),
				transparency = 0.25
			},
		},
		names = {
			enabled = true,
			color = Color3.fromRGB(255, 255, 255),
			outline = {
				enabled = true,
				color = Color3.fromRGB(0, 0, 0),
			},
		},
		health = {
			enabled = true,
			color = Color3.fromRGB(0, 255, 0),
			colorLow = Color3.fromRGB(255, 0, 0),
			outline = {
				enabled = true,
				color = Color3.fromRGB(0, 0, 0)
			},
			text = {
				enabled = true,
				outline = {
					enabled = true,
				},
			}
		},
		distance = {
			enabled = true,
			color = Color3.fromRGB(255, 255, 255),
			outline = {
				enabled = true,
				color = Color3.fromRGB(0, 0, 0),
			},
		},
		weapon = {
			enabled = true,
			color = Color3.fromRGB(255, 255, 255),
			outline = {
				enabled = true,
				color = Color3.fromRGB(0, 0, 0),
			},
		}
	}
}

for _, player in ipairs(players:GetPlayers()) do
	if player ~= client and not get("player"):find(player) then
		get("player"):new(player)
	end
end

get("player").added = players.PlayerAdded:Connect(function(player)
	get("player"):new(player)
end)

get("player").removing = players.PlayerRemoving:Connect(function(player)
	get("player"):remove(player)
end)
