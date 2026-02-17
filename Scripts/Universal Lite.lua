if not ReyHubKeyy or not WindUI or not Window then return end
-- ────────────── UTILITY FUNCTIONS ──────────────
local function SetG(path, value)
	local keys = path:split(".")
	local target = getgenv()
	for i = 1, #keys - 1 do
		if not target[keys[i]] then
			target[keys[i]] = {}
		end
		target = target[keys[i]]
	end
	target[keys[#keys]] = value
end

local function GetG(path)
	local keys = path:split(".")
	local target = getgenv()
	for i = 1, #keys do
		target = target[keys[i]]
		if not target then return nil end
	end
	return target
end

SetG("ActiveConnections", {})
local Utils = {}
function Utils.Disconnect(key)
	local conn = GetG("ActiveConnections."..key)
	if not conn then return end
	if typeof(conn) == "RBXScriptConnection" then
		conn:Disconnect()
	elseif type(conn) == "thread" then
		coroutine.close(conn)
	end
	SetG("ActiveConnections."..key, nil)
end

function Utils.AddConnection(key, conn)
	Utils.Disconnect(key)
	SetG("ActiveConnections."..key, conn)
end

function Utils.StartThread(key, func)
	Utils.Disconnect(key)
	local thread = coroutine.create(func)
	SetG("ActiveConnections."..key, thread)
	coroutine.resume(thread)
end

function Utils.CreateLoop(key, func, delay)
	Utils.Disconnect(key)
	local method = GetG("LoopMethod") or "While Loop"
	
	if method == "While Loop" then
		Utils.StartThread(key, function()
			while true do
				func()
				task.wait(delay or 0)
			end
		end)
	else
		local service
		if method == "Heartbeat" then
			service = RunService.Heartbeat
		elseif method == "Stepped" then
			service = RunService.Stepped
		elseif method == "RenderStepped" then
			service = RunService.RenderStepped
		end
		if service then
			if delay and delay > 0 then
				Utils.AddConnection(key, service:Connect(function()
					func()
					task.wait(delay)
				end))
			else
				Utils.AddConnection(key, service:Connect(func))
			end
		end
	end
end

-- ────────────── SERVICES & CACHE ──────────────
local function GetService(name)
	return game:GetService(name)
end

local Players = GetService("Players")
local RunService = GetService("RunService")
local UserInputService = GetService("UserInputService")
local TeleportService = GetService("TeleportService")
local VirtualUser = GetService("VirtualUser")
local HttpService = GetService("HttpService")
local PathfindingService = GetService("PathfindingService")
local LocalPlayer = Players.LocalPlayer

-- ────────────── PLAYER FUNCTIONS ──────────────
local function getRoot(character)
	return character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Head")
end

local function findPlayerByName(partialName)
	if not partialName or partialName == "" then return nil end
	local searchName = partialName:lower()
	local foundPlayer = nil
	
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Name:lower() == searchName or player.DisplayName:lower() == searchName then
			return player
		end
		if player.Name:lower():sub(1, #searchName) == searchName or 
		   player.DisplayName:lower():sub(1, #searchName) == searchName then
			foundPlayer = player
		end
	end
	
	if not foundPlayer then
		local success, userId = pcall(function()
			return Players:GetUserIdFromNameAsync(searchName)
		end)
		if success and userId then
			return {UserId = userId, Name = partialName}
		end
	end
	
	return foundPlayer
end

-- ────────────── UI INITIALIZATION ──────────────

local ConfigManager = ConfigManager or Window.ConfigManager
local mainConfig = mainConfig or ConfigManager:CreateConfig("Config-1")

local PlayersTab = Window:Section({Title = "Player", Icon = "user-round-cog"})
local PlayerTab = PlayersTab:Tab({Title = "Local Player", Icon = "user"})
local AnotherPlayerTab = PlayersTab:Tab({Title = "Another Player", Icon = "users"})
local TrollTab = PlayersTab:Tab({Title = "Trolls", Icon = "drama"})

local TeleportTab = Window:Tab({Title = "Teleport", Icon = "map-pin"})
local MiscTab = Window:Tab({Title = "Misc", Icon = "box"})
local SettingsTab = Window:Tab({Title = "Settings", Icon = "settings"})

-- ────────────── TAB: LOCAL PLAYER ──────────────
-- Movement Section
local MovementSection = PlayerTab:Section({
	Title = "Movement", Desc = "Character movement controls",
	Icon = "move", Box = true, BoxBorder = true, Opened = true
})

MovementSection:Input({
	Title = "WalkSpeed", Desc = "Set character walking speed",
	Value = (LocalPlayer.Character and LocalPlayer.Character.Humanoid and tostring(LocalPlayer.Character.Humanoid.WalkSpeed)) or "16",
	Flag = "WalkSpeed",
	Callback = function(value)
		local speed = tonumber(value) or 16
		local humanoid = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid")
		if humanoid then
			humanoid.WalkSpeed = speed
			WindUI:Notify({Title = "WalkSpeed", Content = "Set to " .. speed, Duration = 2})
		end
	end
})

MovementSection:Input({
	Title = "JumpPower", Desc = "Set character jump power",
	Value = (LocalPlayer.Character and LocalPlayer.Character.Humanoid and tostring(LocalPlayer.Character.Humanoid.JumpPower)) or "50",
	Flag = "JumpPower",
	Callback = function(value)
		local power = tonumber(value) or 50
		local humanoid = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid")
		if humanoid then
			humanoid.JumpPower = power
			WindUI:Notify({Title = "JumpPower", Content = "Set to " .. power, Duration = 2})
		end
	end
})

MovementSection:Toggle({
	Title = "Infinite Jump", Desc = "You can jump repeatedly until heaven",
	Value = false, Flag = "InfiniteJump",
	Callback = function(state)
		Utils.Disconnect("InfiniteJump")
		if state then
			Utils.AddConnection("InfiniteJump", UserInputService.JumpRequest:Connect(function()
				local debounce = GetG("InfJumpDebounce")
				if debounce then return end
				SetG("InfJumpDebounce", true)
				local humanoid = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
				if humanoid then humanoid:ChangeState("Jumping") end
				task.wait()
				SetG("InfJumpDebounce", false)
			end))
			WindUI:Notify({Title = "Infinite Jump", Content = "Enabled", Duration = 2})
		else
			WindUI:Notify({Title = "Infinite Jump", Content = "Disabled", Duration = 2})
		end
	end
})

local function applyNoclipToCharacter(char)
	if not GetG("NoclipEnabled") then return end
	for _, part in pairs(char:GetDescendants()) do
		if part:IsA("BasePart") then part.CanCollide = false end
	end
end

MovementSection:Toggle({
	Title = "Noclip", Desc = "Pass through walls and objects",
	Value = false, Flag = "Noclip",
	Callback = function(state)
		SetG("NoclipEnabled", state)
		Utils.Disconnect("NoclipLoop")
		Utils.Disconnect("NoclipCharacterAdded")
		
		if state then
			if LocalPlayer.Character then applyNoclipToCharacter(LocalPlayer.Character) end
			Utils.StartThread("NoclipLoop", function()
				while GetG("NoclipEnabled") do
					if LocalPlayer.Character then applyNoclipToCharacter(LocalPlayer.Character) end
					task.wait(0.1)
				end
			end)
			Utils.AddConnection("NoclipCharacterAdded", LocalPlayer.CharacterAdded:Connect(function(char)
				task.wait(0.1)
				applyNoclipToCharacter(char)
			end))
			WindUI:Notify({Title = "Noclip", Content = "Enabled", Duration = 2})
		else
			WindUI:Notify({Title = "Noclip", Content = "Disabled", Duration = 2})
		end
	end
})

-- Abilities Section
local AbilitiesSection = PlayerTab:Section({
	Title = "Abilities", Desc = "Special character abilities",
	Icon = "zap", Box = true, BoxBorder = true, Opened = false
})

AbilitiesSection:Toggle({
	Title = "God Mode", Desc = "Become invincible (not work on all games)",
	Value = false, Flag = "GodMode",
	Callback = function(state)
		SetG("GodModeEnabled", state)
		Utils.Disconnect("GodMode")
		Utils.Disconnect("GodModeCharacterAdded")
		
		if state then
			local function applyGodMode(char)
				local humanoid = char:WaitForChild("Humanoid")
				Utils.AddConnection("GodMode", humanoid.HealthChanged:Connect(function()
					humanoid.Health = humanoid.MaxHealth
				end))
			end
			if LocalPlayer.Character then applyGodMode(LocalPlayer.Character) end
			Utils.AddConnection("GodModeCharacterAdded", LocalPlayer.CharacterAdded:Connect(applyGodMode))
			WindUI:Notify({Title = "God Mode", Content = "Enabled", Duration = 2})
		else
			WindUI:Notify({Title = "God Mode", Content = "Disabled", Duration = 2})
		end
	end
})

AbilitiesSection:Toggle({
	Title = "Anti-AFK", Desc = "Prevent automatic kick",
	Value = false, Flag = "AntiAFK",
	Callback = function(state)
		SetG("AntiAFKEnabled", state)
		Utils.Disconnect("AntiAFK")
		if state then
			local vu = game:GetService("VirtualUser")
			Utils.AddConnection("AntiAFK", LocalPlayer.Idled:Connect(function()
				vu:Button2Down(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
				task.wait(1)
				vu:Button2Up(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
			end))
			WindUI:Notify({Title = "Anti-AFK", Content = "Enabled", Duration = 2})
		else
			WindUI:Notify({Title = "Anti-AFK", Content = "Disabled", Duration = 2})
		end
	end
})

AbilitiesSection:Toggle({
	Title = "Anti-Kick", Desc = "Prevent game kicks",
	Value = false, Flag = "AntiKick",
	Callback = function(state)
		if state then
			local mt = getrawmetatable(game)
			local old = mt.__namecall
			setreadonly(mt, false)
			mt.__namecall = newcclosure(function(self, ...)
				local method = getnamecallmethod()
				if method == "Kick" or method == "kick" then return nil end
				return old(self, ...)
			end)
		end
	end
})


AbilitiesSection:Toggle({
	Title = "Swim", Desc = "Swim in air",
	Value = false, Flag = "Swim",
	Callback = function(state)
		SetG("SwimEnabled", state)
		if state then
			local char = LocalPlayer.Character
			if not char then return end
			local humanoid = char:FindFirstChildWhichIsA("Humanoid")
			if not humanoid then return end
			
			SetG("OriginalGravity", workspace.Gravity)
			workspace.Gravity = 0
			
			local enums = Enum.HumanoidStateType:GetEnumItems()
			table.remove(enums, table.find(enums, Enum.HumanoidStateType.None))
			for _, v in pairs(enums) do humanoid:SetStateEnabled(v, false) end
			humanoid:ChangeState(Enum.HumanoidStateType.Swimming)
			
			Utils.AddConnection("SwimLoop", RunService.Heartbeat:Connect(function()
				if not GetG("SwimEnabled") then return end
				local char = LocalPlayer.Character
				local hrp = char and char:FindFirstChild("HumanoidRootPart")
				local humanoid = char and char:FindFirstChildWhichIsA("Humanoid")
				if hrp and humanoid then
					local moving = humanoid.MoveDirection ~= Vector3.new() or UserInputService:IsKeyDown(Enum.KeyCode.Space)
					if not moving then hrp.Velocity = Vector3.new() end
				end
			end))
			
			Utils.AddConnection("SwimDeath", humanoid.Died:Connect(function()
				SetG("SwimEnabled", false)
				workspace.Gravity = GetG("OriginalGravity") or 196.2
				Utils.Disconnect("SwimLoop")
				Utils.Disconnect("SwimDeath")
			end))
			WindUI:Notify({Title = "Swim", Content = "Swim enabled", Duration = 2})
		else
			local char = LocalPlayer.Character
			if char then
				local humanoid = char:FindFirstChildWhichIsA("Humanoid")
				if humanoid then
					local enums = Enum.HumanoidStateType:GetEnumItems()
					table.remove(enums, table.find(enums, Enum.HumanoidStateType.None))
					for _, v in pairs(enums) do humanoid:SetStateEnabled(v, true) end
				end
			end
			workspace.Gravity = GetG("OriginalGravity") or 196.2
			Utils.Disconnect("SwimLoop")
			Utils.Disconnect("SwimDeath")
			WindUI:Notify({Title = "Swim", Content = "Swim disabled", Duration = 2})
		end
	end
})

-- Fake Lag
AbilitiesSection:Divider()
local FakeLagToggle = AbilitiesSection:Toggle({
	Title = "Fake Lag", Desc = "Simulate network delay (1 = 1 second delay)",
	Value = false, Flag = "FakeLag",
	Callback = function(state)
		SetG("FakeLagEnabled", state)
		if state then
			local lagValue = GetG("FakeLagValue") or 0
			local success, err = pcall(function()
				settings():GetService("NetworkSettings").IncomingReplicationLag = lagValue
			end)
			if success then
				WindUI:Notify({Title = "Fake Lag", Content = "Enabled: " .. lagValue .. " second delay", Duration = 2})
			else
				WindUI:Notify({Title = "Error", Content = "Failed: " .. tostring(err), Duration = 2})
				FakeLagToggle:Set(false)
			end
		else
			pcall(function() settings():GetService("NetworkSettings").IncomingReplicationLag = 0 end)
			WindUI:Notify({Title = "Fake Lag", Content = "Disabled", Duration = 2})
		end
	end
})

local FakeLagInput = AbilitiesSection:Input({
	Title = "Fake Lag Value (seconds)", Desc = "Set delay time (0-60)",
	Value = "0", Placeholder = "Enter seconds...", Flag = "FakeLagValue",
	Callback = function(value)
		local num = tonumber(value)
		if num and num >= 0 and num <= 60 then
			SetG("FakeLagValue", num)
			if GetG("FakeLagEnabled") then
				pcall(function() settings():GetService("NetworkSettings").IncomingReplicationLag = num end)
			end
			WindUI:Notify({Title = "Fake Lag", Content = "Value set to " .. num .. " seconds", Duration = 2})
		else
			WindUI:Notify({Title = "Error", Content = "Must be between 0-60", Duration = 2})
		end
	end
})

AbilitiesSection:Button({
	Title = "Reset Fake Lag", Desc = "Reset delay to 0", Icon = "rotate-ccw",
	Callback = function()
		pcall(function() settings():GetService("NetworkSettings").IncomingReplicationLag = 0 end)
		SetG("FakeLagValue", 0)
		FakeLagInput:Set("0")
		if GetG("FakeLagEnabled") then
			pcall(function() settings():GetService("NetworkSettings").IncomingReplicationLag = 0 end)
		end
		WindUI:Notify({Title = "Fake Lag", Content = "Reset to 0 seconds", Duration = 2})
	end
})

SetG("FakeLagValue", 0)
SetG("FakeLagEnabled", false)

-- Appearance Section
local AppearanceSection = PlayerTab:Section({
	Title = "Appearance", Desc = "Copy Avatar",
	Icon = "user", Box = true, BoxBorder = true, Opened = false
})

local lastCopyTime, copy_cooldown, copyAvatarInput, originalAvatarDesc, AppearanceStatus = 0, 5, "", nil, false

local function getAvatarThumbnailUrl(userId)
	local ok, contentUrl, isReady = pcall(function()
		return Players:GetUserThumbnailAsync(
			userId,
			Enum.ThumbnailType.AvatarThumbnail,
			Enum.ThumbnailSize.Size420x420
		)
	end)
	
	if ok and contentUrl and isReady then
		return contentUrl
	else
		return "https://www.roblox.com/thumbnail/avatar?userId=" ..
			tostring(userId) .. "&width=420&height=420&format=png"
	end
end

local function SaveOriginalAvatar()
	task.spawn(function()
		local success, desc = pcall(function()
			return Players:GetHumanoidDescriptionFromUserId(LocalPlayer.UserId)
		end)
		if success then originalAvatarDesc = desc end
	end)
end

local function copyAvatarToPlayer(target)
	local now = tick()
	if now - lastCopyTime < copy_cooldown then
		WindUI:Notify({Title = "Cooldown", Content = "Wait " .. math.ceil(copy_cooldown - (now - lastCopyTime)) .. "s"})
		return
	elseif not target then
		WindUI:Notify({Title = "Copy Avatar", Content = "No target found!", Duration = 3})
		return 
	end
	lastCopyTime = now
	
	local userId = target.UserId or (type(target) == "number" and target or target.UserId)
	local targetName = target.Name or "Unknown"
	
	local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid then 
		WindUI:Notify({Title = "Copy Avatar", Content = "Failed to find humanoid!", Duration = 3})
		return 
	end
	
	local success, desc = pcall(function()
		return Players:GetHumanoidDescriptionFromUserId(userId)
	end)
	if not success or not desc then
		WindUI:Notify({Title = "Copy Avatar", Content = "Failed to load avatar data!", Duration = 3})
		return
	end
	
	for _, obj in ipairs(character:GetChildren()) do
		if obj:IsA("Shirt") or obj:IsA("Pants") or obj:IsA("ShirtGraphic") or
		   obj:IsA("Accessory") or obj:IsA("BodyColors") then
			obj:Destroy()
		end
	end
	
	local head = character:FindFirstChild("Head")
	if head then
		for _, decal in ipairs(head:GetChildren()) do
			if decal:IsA("Decal") then decal:Destroy() end
		end
	end
	
	local applySuccess = pcall(function() humanoid:ApplyDescriptionClientServer(desc) end)
	if applySuccess then
		AppearanceStatus = target
		if target and target.DisplayName then
			WindUI:Notify({Title = "Copy Avatar", Content = "Successfully copied " .. target.DisplayName .. " (@" .. targetName .. ")'s avatar!", Duration = 3})
		end
	else
		WindUI:Notify({Title = "Copy Avatar", Content = "Failed to apply avatar!", Duration = 3})
	end
end

local function ResetAvatar()
	if not originalAvatarDesc then SaveOriginalAvatar() end
	task.wait(0.1)
	local char = LocalPlayer.Character
	if char then
		local humanoid = char:FindFirstChild("Humanoid")
		if humanoid and originalAvatarDesc then
			humanoid:ApplyDescriptionClientServer(originalAvatarDesc)
			WindUI:Notify({Title = "Avatar Reset", Content = "Avatar reset to original", Duration = 3})
			AppearanceStatus = false
		else
			WindUI:Notify({Title = "Error", Content = "Failed to reset avatar", Duration = 3})
		end
	end
end

if not isfolder("ReyHub") then makefolder("ReyHub") end
local AvatarManager = {
	FileName = "ReyHub/AvatarList",
	List = {},
	Selected = ""
}

local function ConvertSelectedToTable()
	if not AvatarManager.Selected then return end
	for i, v in ipairs(AvatarManager.List) do
		if type(v) == "string" and v == AvatarManager.Selected then
			AvatarManager.List[i] = {
				Title = v,
				Icon = "star"
			}
			return true
		end
	end
	return false
end

local function LoadAvatarList()
	local success, data = pcall(function() return readfile(AvatarManager.FileName) end)
	if success and data and data ~= "" then
		local decoded = HttpService:JSONDecode(data)
		AvatarManager.List = decoded or {}
	else AvatarManager.List = {} end
	ConvertSelectedToTable()
end

local function SaveAvatarList()
	local success, json = pcall(function() return HttpService:JSONEncode(AvatarManager.List) end)
	if success then pcall(function() writefile(AvatarManager.FileName, json) end) end
end

local playerInfoContainer, copyavaInputContainer, SavedNamesDropdown, CopyAvaActionD, CopyAvaActionS
local ContLoaded = false
local function UpdateInfoContainer(target)
	ContLoaded = false
	LoadAvatarList()
	if playerInfoContainer then playerInfoContainer:Destroy() end
	if copyavaInputContainer then copyavaInputContainer:Destroy() end
	if SavedNamesDropdown then SavedNamesDropdown:Destroy() end
	if CopyAvaActionS and CopyAvaActionD then CopyAvaActionD:Destroy() CopyAvaActionS:Destroy() end
	if not target then
		playerInfoContainer = AppearanceSection:Paragraph({
			Title = "No player selected",
			Desc = "Enter a username below to copy avatar"
		})
	else
		local fullbodyUrl = getAvatarThumbnailUrl(target.UserId)
		playerInfoContainer = AppearanceSection:Paragraph({
			Title = string.format("User: @%s\nNick: %s\nID: %s",target.Name or "-",target.DisplayName or "-",target.UserId or "-"),
			Desc = "Selected Target",
			Image = fullbodyUrl,
			ImageSize = 120,
			Buttons = {
				{
					Icon = "user",
					Title = "Copy Avatar",
					Callback = function()
						copyAvatarToPlayer(target)
					end
				},
				{
					Icon = "rotate-ccw",
					Title = "Reset Avatar",
					Callback = ResetAvatar
				}
			}
		})
	end
	
	copyavaInputContainer = AppearanceSection:Input({
		Title = "Copy Avatar", Desc = "Enter player name to copy avatar",
		Value = (copyAvatarInput or target.Name or nil), Placeholder = "Enter username...", Flag = "CopyAvatar",
		Callback = function(value)
			if value and value ~= "" then
				copyAvatarInput = value
				local target = findPlayerByName(value)
				if ContLoaded then
					UpdateInfoContainer(target)
				end
			end
		end
	})
	
	local function SavedDropdownF(value)
		if not ContLoaded then return end
		SavedNamesDropdown:Close()
		copyAvatarInput = value
		AvatarManager.Selected = value
		copyavaInputContainer:Set(value)
	end
	SavedNamesDropdown = AppearanceSection:Dropdown({
		Title = "Saved Usernames",
		Desc = "Select a saved username",
		Values = AvatarManager.List,
		Value = (AvatarManager.Selected or nil),
		SearchBarEnabled = true,
		Callback = SavedDropdownF
	})
	
	CopyAvaActionS = AppearanceSection:Button({
		Title = "Save Current Username",
		Desc = "Save entered username to list",
		Icon = "save",
		Callback = function()
			if copyAvatarInput and copyAvatarInput ~= "" then
				for _, name in ipairs(AvatarManager.List) do
					if name == copyAvatarInput then
						WindUI:Notify({Title = "Error", Content = "Name already in list", Duration = 2})
						return
					end
				end
				ContLoaded = false
				AvatarManager.Selected = copyAvatarInput 
				table.insert(AvatarManager.List, copyAvatarInput)
				SaveAvatarList()
				WindUI:Notify({Title = "Saved", Content = "Username saved: " .. copyAvatarInput, Duration = 2})
				SavedNamesDropdown:Refresh(AvatarManager.List)
				ContLoaded = true
			else
				WindUI:Notify({Title = "Error", Content = "Enter a username first", Duration = 2})
			end
		end
	})
	
	CopyAvaActionD = AppearanceSection:Button({
		Title = "Delete Selected Username",
		Desc = "Remove username from saved list",
		Icon = "trash-2",
		Callback = function()
			if AvatarManager.Selected and AvatarManager.List then
				for i, name in ipairs(AvatarManager.List) do
					if name == AvatarManager.Selected then
						table.remove(AvatarManager.List, i)
						break
					end
				end
				ContLoaded = false
				SaveAvatarList()
				SavedNamesDropdown:Refresh(AvatarManager.List)
				AvatarManager.Selected = nil
				WindUI:Notify({Title = "Deleted", Content = "Username removed", Duration = 2})
				ContLoaded = true
			end
		end
	})
	ContLoaded = true
end
UpdateInfoContainer()

LocalPlayer.CharacterAdded:Connect(function()
	if copyAvatarInput ~= "" and AppearanceStatus then
		lastCopyTime = 0
		copyAvatarToPlayer(AppearanceStatus)
	end
end)

SaveOriginalAvatar()


local AnimationSection = PlayerTab:Section({
	Title = "Animations", Desc = "Customize character animations",
	Icon = "person-standing", Box = true, BoxBorder = true, Opened = false
})
task.spawn(function()
local animationLoaded = false
local dropdowns = {}
local function loadAnimationPacks()
	if animationLoaded then return end
	animationLoaded = true
	local ANIMATION_PACKS = {
		{label = "Default", ids = nil},
		{label = "Vampire", ids = {idle1="1083445855", idle2="1083450166", walk="1083473930", run="1083462077", jump="1083455352", climb="1083439238", fall="1083443587"}},
		{label = "Hero", ids = {idle1="616111295", idle2="616113536", walk="616122287", run="616117076", jump="616115533", climb="616104706", fall="616108001"}},
		{label = "Zombie", ids = {idle1="616158929", idle2="616160636", walk="616168032", run="616163682", jump="616161997", climb="616156119", fall="616157476"}},
		{label = "Mage", ids = {idle1="707742142", idle2="707855907", walk="707897309", run="707861613", jump="707853694", climb="707826056", fall="707829716"}},
		{label = "Ninja", ids = {idle1="656117400", idle2="656118341", walk="656121766", run="656118852", jump="656117878", climb="656114359", fall="656115606"}},
		{label = "Cartoon", ids = {idle1="742637544", idle2="742638445", walk="742640026", run="742638842", jump="742637942", climb="742636889", fall="742637151"}},
		{label = "Knight", ids = {idle1="657595757", idle2="657568135", walk="657552124", run="657564596", jump="658409194", climb="658360781", fall="657600338"}},
		{label = "Popstar", ids = {idle1="1212900985", idle2="1212900985", walk="1212980338", run="1212980348", jump="1212954642", climb="1213044953", fall="1212900995"}},
		{label = "Werewolf", ids = {idle1="1083195517", idle2="1083214717", walk="1083178339", run="1083216690", jump="1083218792", climb="1083182000", fall="1083189019"}},
		{label = "Retro", ids = {idle1="10921259953", idle2="10921258489", walk="10921269718", run="10921261968", jump="10921263860", climb="10921257536", fall="10921262864"}},
		{label = "Adidas Community", ids = {idle1="122257458498464", idle2="102357151005774", walk="122150855457006", run="82598234841035", jump="75290611992385", climb="88763136693023", fall="98600215928904"}},
		{label = "Catwalk Glam E.L.F", ids = {idle1="133806214992291", idle2="94970088341563", walk="109168724482748", run="81024476153754", jump="116936326516985", climb="119377220967554", fall="92294537340807"}},
		{label = "Popular Criminal", ids = {idle1="118832222982049", idle2="76049494037641", walk="92072849924640", run="72301599441680", jump="104325245285198", climb="131326830509784", fall="121152442762481"}},
		{label = "NFL", ids = {idle1="92080889861410", idle2="74451233229259", walk="110358958299415", run="117333533048078", jump="119846112151352", climb="134630013742019", fall="129773241321032"}},
		{label = "Walmart", ids = {idle1="92080889861410", idle2="74451233229259", walk="110358958299415", run="117333533048078", jump="119846112151352", climb="134630013742019", fall="129773241321032"}},
		{label = "Adidas Sport", ids = {idle1="18537376492", idle2="18537371272", walk="18537392113", run="18537384940", jump="18537380791", climb="18537363391", fall="18537367238"}},
		{label = "Thick E.L.F", ids = {idle1="16738333868", idle2="16738334710", walk="16738340646", run="16738337225", jump="16738336650", climb="16738332169", fall="16738333171"}},
		{label = "Stylish", ids = {idle1="10921272275", idle2="10921273958", walk="10921283326", run="10921276116", jump="10921279832", climb="10921271391", fall="10921278648"}},
		{label = "Old School", ids = {idle1="10921230744", idle2="10921232093", walk="10921244891", run="10921240218", jump="10921242013", climb="10921229866", fall="10921241244"}},
		{label = "Superhero", ids = {idle1="10921315373", idle2="10921316709", walk="10921326949", run="10921320299", jump="10921322186", climb="10921314188", fall="10921321317"}},
		{label = "Ninja", ids = {idle1="10921155160", idle2="10921155867", walk="10921162768", run="10921157929", jump="10921160088", climb="10921154678", fall="10921159222"}},
		{label = "Bubby", ids = {idle1="10921155160", idle2="10921155867", walk="10921162768", run="10921157929", jump="10921160088", climb="10921154678", fall="10921159222"}},
		{label = "Wizard", ids = {idle1="10921144709", idle2="10921145797", walk="10921152678", run="10921148209", jump="10921149743", climb="10921143404", fall="10921148939"}},
		{label = "Robot", ids = {idle1="10921248039", idle2="10921248831", walk="10921255446", run="10921250460", jump="10921252123", climb="10921247141", fall="10921251156"}},
		{label = "Toy", ids = {idle1="10921301576", idle2="10921302207", walk="10921312010", run="10921306285", jump="10921308158", climb="10921300839", fall="10921307241"}},
		{label = "Elder", ids = {idle1="10921101664", idle2="10921102574", walk="10921111375", run="10921104374", jump="10921107367", climb="10921100400", fall="10921105765"}},
		{label = "Levitation", ids = {idle1="10921132962", idle2="10921133721", walk="10921140719", run="10921135644", jump="10921137402", climb="10921132092", fall="10921136539"}},
		{label = "Astronaut", ids = {idle1="10921034824", idle2="10921036806", walk="10921046031", run="10921039308", jump="10921042494", climb="10921032124", fall="10921040576"}},
		{label = "Werewolf", ids = {idle1="10921330408", idle2="10921333667", walk="10921342074", run="10921336997", jump="1083218792", climb="10921329322", fall="10921337907"}},
		{label = "Knight", ids = {idle1="10921117521", idle2="10921118894", walk="10921127095", run="10921121197", jump="10921123517", climb="10921116196", fall="10921122579"}},
		{label = "Pirate", ids = {idle1="750781874", idle2="750782770", walk="750785693", run="750783738", jump="750782230", climb="750779899", fall="750780242"}},
		{label = "Confident", ids = {idle1="1069977950", idle2="1069987858", walk="1070017263", run="1070001516", jump="1069984524", climb="1069946257", fall="1069973677"}},
		{label = "Patroll", ids = {idle1="1149612882", idle2="1150842221", walk="1151231493", run="1150967949", jump="1150944216", climb="1148811837", fall="1148863382"}},
		{label = "Sneaky", ids = {idle1="1132473842", idle2="1132477671", walk="1132510133", run="1132494274", jump="1132489853", climb="1132461372", fall="1132469004"}},
		{label = "Princess", ids = {idle1="941003647", idle2="941013098", walk="941028902", run="941015281", jump="941008832", climb="940996062", fall="941000007"}},
		{label = "Cowboy", ids = {idle1="1014390418", idle2="1014398616", walk="1014421541", run="1014401683", jump="1014394726", climb="1014380606", fall="1014384571"}},
		{label = "Glitter Woman", ids = {idle1="4708191566", idle2="4708192150", walk="4708193840", run="4708192705", jump="4708188025", climb="4708184253", fall="4708186162"}},
		{label = "Toilet Lord", ids = {idle1="4417977954", idle2="4417978624", walk="4708193840", run="4417979645", jump="4708188025", climb="4708184253", fall="4708186162"}},
		{label = "Ud'zal", ids = {idle1="3303162274", idle2="3303162549", walk="3303162967", run="3236836670", jump="4708188025", climb="4708184253", fall="4708186162"}},
		{label = "Beroco", ids = {idle1="3293641938", idle2="3293642554", walk="10921269718", run="3236836670", jump="4708188025", climb="4708184253", fall="4708186162"}},
		{label = "Wicked Dancing Through Life", ids = {idle1 = "92849173543269", idle2 = "132238900951109", walk = "73718308412641", run = "135515454877967", jump = "78508480717326", climb = "129447497744818", fall = "78147885297412"}},
		{label = "Adidas Aura", ids = {idle1 = "110211186840347", idle2 = "114191137265065", walk = "83842218823011", run = "118320322718866", jump = "109996626521204", climb = "97824616490448", fall = "95603166884636"}},
		{label = "Amazon Unboxed", ids = {idle1 = "98281136301627", idle2 = "138183121662404", walk = "90478085024465", run = "134824450619865", jump = "121454505477205", climb = "121145883950231", fall = "94788218468396"}},
		{label = "No Boundaries by Walmart", ids = {idle1 = "18747067405", idle2 = "18747063918", walk = "18747074203", run = "18747070484", jump = "18747069148", climb = "18747060903", fall = "18747062535"}},
	}
	
	local ANIMATION_TYPES = {
		{type = "Idle", key = "idle1"},
		{type = "Walk", key = "walk"},
		{type = "Run", key = "run"},
		{type = "Jump", key = "jump"},
		{type = "Climb", key = "climb"},
		{type = "Fall", key = "fall"}
	}
	
	local animationData = {}
	local currentIndex = {}
	local originalAnimationIDs = {}
	
	for _, animType in ipairs(ANIMATION_TYPES) do
		animationData[animType.type] = {{label = "Default", id = nil}}
		currentIndex[animType.type] = 1
	end
	
	for i = 2, #ANIMATION_PACKS do
		local pack = ANIMATION_PACKS[i]
		if pack.ids then
			for _, animType in ipairs(ANIMATION_TYPES) do
				table.insert(animationData[animType.type], {label = pack.label, id = pack.ids[animType.key]})
			end
		end
	end
	
	local function cacheOriginalAnimations()
		local char = LocalPlayer.Character
		local Animate = char and char:FindFirstChild("Animate")
		if not Animate or next(originalAnimationIDs) then return end 
		
		pcall(function()
			originalAnimationIDs = {
				idle1 = Animate.idle.Animation1.AnimationId:match("%d+"),
				idle2 = Animate.idle.Animation2.AnimationId:match("%d+"),
				walk = Animate.walk.WalkAnim.AnimationId:match("%d+"),
				run = Animate.run.RunAnim.AnimationId:match("%d+"),
				jump = Animate.jump.JumpAnim.AnimationId:match("%d+"),
				climb = Animate.climb.ClimbAnim.AnimationId:match("%d+"),
				fall = Animate.fall.FallAnim.AnimationId:match("%d+"),
			}
			
			ANIMATION_PACKS[1].ids = {
				idle1 = originalAnimationIDs.idle1,
				idle2 = originalAnimationIDs.idle2,
				walk = originalAnimationIDs.walk,
				run = originalAnimationIDs.run,
				jump = originalAnimationIDs.jump,
				climb = originalAnimationIDs.climb,
				fall = originalAnimationIDs.fall
			}
		end)
	end
	
	local function applyCurrentAnimations()
		local char = LocalPlayer.Character
		local Animate = char and char:FindFirstChild("Animate")
		if not Animate then return end
		
		cacheOriginalAnimations()
		local animsToApply = {}
		for k, v in pairs(originalAnimationIDs) do animsToApply[k] = v end
		
		local animationMappings = {
			idle1 = "Idle",
			idle2 = "Idle",
			walk = "Walk",
			run = "Run",
			jump = "Jump",
			climb = "Climb",
			fall = "Fall"
		}
		
		local changed = false
		for animKey, animType in pairs(animationMappings) do
			local data = animationData[animType]
			local index = currentIndex[animType]
			if data[index] and data[index].id then
				animsToApply[animKey] = data[index].id
				changed = true
			end
		end
		
		if not changed then return end
		
		pcall(function()
			Animate.Disabled = true
			local prefix = "http://www.roblox.com/asset/?id="
			if animsToApply.idle1 then Animate.idle.Animation1.AnimationId = prefix .. animsToApply.idle1 end
			if animsToApply.idle2 then Animate.idle.Animation2.AnimationId = prefix .. animsToApply.idle2 end
			if animsToApply.walk then Animate.walk.WalkAnim.AnimationId = prefix .. animsToApply.walk end
			if animsToApply.run then Animate.run.RunAnim.AnimationId = prefix .. animsToApply.run end
			if animsToApply.jump then Animate.jump.JumpAnim.AnimationId = prefix .. animsToApply.jump end
			if animsToApply.climb then Animate.climb.ClimbAnim.AnimationId = prefix .. animsToApply.climb end
			if animsToApply.fall then Animate.fall.FallAnim.AnimationId = prefix .. animsToApply.fall end
			Animate.Disabled = false
		end)
	end
	
	for _, animType in ipairs(ANIMATION_TYPES) do
		local values = {}
		for _, data in ipairs(animationData[animType.type]) do 
			table.insert(values, data.label) 
		end
		
		dropdowns[animType.type] = AnimationSection:Dropdown({
			Title = animType.type .. " Animation",
			Desc = "Select animation when character " .. animType.type:lower() .. "s",
			Values = values,
			Multi = false,
			SearchBarEnabled = true,
			Flag = animType.type .. "Anim",
			Callback = function(value)
				for i, data in ipairs(animationData[animType.type]) do
					if data.label == value then 
						currentIndex[animType.type] = i
						break 
					end
				end
				applyCurrentAnimations()
			end
		})
	end
	
	local packNames = {}
	for i, pack in ipairs(ANIMATION_PACKS) do
		table.insert(packNames, pack.label)
	end
	AnimationSection:Dropdown({
		Title = "Select Animation Packs",
		Desc = "Apply full animation pack",
		Values = packNames,
		Multi = false,
		Flag = "AllAnimation",
		Callback = function(selectedPack)
			for _, pack in ipairs(ANIMATION_PACKS) do
				if pack.label == selectedPack and pack.ids then
					local char = LocalPlayer.Character
					local Animate = char and char:FindFirstChild("Animate")
					if Animate then
						pcall(function()
							Animate.Disabled = true
							local prefix = "http://www.roblox.com/asset/?id="
							
							if pack.ids.idle1 then Animate.idle.Animation1.AnimationId = prefix .. pack.ids.idle1 end
							if pack.ids.idle2 then Animate.idle.Animation2.AnimationId = prefix .. pack.ids.idle2 end
							if pack.ids.walk then Animate.walk.WalkAnim.AnimationId = prefix .. pack.ids.walk end
							if pack.ids.run then Animate.run.RunAnim.AnimationId = prefix .. pack.ids.run end
							if pack.ids.jump then Animate.jump.JumpAnim.AnimationId = prefix .. pack.ids.jump end
							if pack.ids.climb then Animate.climb.ClimbAnim.AnimationId = prefix .. pack.ids.climb end
							if pack.ids.fall then Animate.fall.FallAnim.AnimationId = prefix .. pack.ids.fall end
							
							Animate.Disabled = false
						end)
					WindUI:Notify({Title = "Animation", Content = "Applied " .. selectedPack .. " pack", Duration = 2})
					end
					break
				end
			end
		end
	})
	
	AnimationSection:Button({
		Title = "Reset to Default", 
		Icon = "refresh-cw",
		Desc = "Reset all animations to default game animations",
		Callback = function()
			for _, animType in ipairs(ANIMATION_TYPES) do
				currentIndex[animType.type] = 1
			end
			
			local char = LocalPlayer.Character
			local Animate = char and char:FindFirstChild("Animate")
			if Animate then
				pcall(function()
					Animate.Disabled = true
					local prefix = "http://www.roblox.com/asset/?id="
					if originalAnimationIDs.idle1 then Animate.idle.Animation1.AnimationId = prefix .. originalAnimationIDs.idle1 end
					if originalAnimationIDs.idle2 then Animate.idle.Animation2.AnimationId = prefix .. originalAnimationIDs.idle2 end
					if originalAnimationIDs.walk then Animate.walk.WalkAnim.AnimationId = prefix .. originalAnimationIDs.walk end
					if originalAnimationIDs.run then Animate.run.RunAnim.AnimationId = prefix .. originalAnimationIDs.run end
					if originalAnimationIDs.jump then Animate.jump.JumpAnim.AnimationId = prefix .. originalAnimationIDs.jump end
					if originalAnimationIDs.climb then Animate.climb.ClimbAnim.AnimationId = prefix .. originalAnimationIDs.climb end
					if originalAnimationIDs.fall then Animate.fall.FallAnim.AnimationId = prefix .. originalAnimationIDs.fall end
					Animate.Disabled = false
				end)
			end
			
			WindUI:Notify({Title = "Animation", Content = "Reset to default animations", Duration = 2})
		end
	})
	
	LocalPlayer.CharacterAdded:Connect(function()
		task.wait(0.5)
		applyCurrentAnimations()
	end)
	
	if LocalPlayer.Character then cacheOriginalAnimations() end
	LocalPlayer.CharacterAdded:Connect(function(char) 
		task.wait(0.5) 
		cacheOriginalAnimations() 
	end)
	
	WindUI:Notify({Title = "Animations", Content = "Animation packs loaded!", Duration = 2})
end

local AnimationLoader = AnimationSection:Button({
	Title = "Load Animation Packs", 
	Icon = "download",
	Desc = "Load all animation packs (may cause lag)",
	Callback = function()
		loadAnimationPacks()
	end
})

task.spawn(function()
	while not animationLoaded do task.wait(0.1) end
	AnimationLoader:Destroy()
end)

end)

-- Camera Section
local CameraSection = PlayerTab:Section({
	Title = "Camera", Desc = "Camera and view controls",
	Icon = "camera", Box = true, BoxBorder = true, Opened = false
})

local OrigZoom = {LocalPlayer.CameraMinZoomDistance or 0.5, LocalPlayer.CameraMaxZoomDistance or 200}
CameraSection:Toggle({
	Title = "Infinite Zoom", Desc = "Unlimited camera zoom",
	Value = false, Flag = "InfiniteZoom",
	Callback = function(state)
		LocalPlayer.CameraMaxZoomDistance = state and math.huge or OrigZoom[2]
		LocalPlayer.CameraMinZoomDistance = state and 0.5 or OrigZoom[1]
		WindUI:Notify({Title = "Infinite Zoom", Content = state and "Enabled" or "Disabled", Duration = 2})
	end
})

CameraSection:Slider({
	Title = "Field of View", Desc = "Adjust camera field of view",
	Value = {Default = 70, Min = 50, Max = 120}, Flag = "FOV",
	Callback = function(value)
		workspace.CurrentCamera.FieldOfView = value
		WindUI:Notify({Title = "FOV", Content = "Set to " .. value, Duration = 2})
	end
})

-- Scripts Section
local ScriptsSection = PlayerTab:Section({
	Title = "Scripts", Desc = "Player-related scripts",
	Icon = "code", Box = true, BoxBorder = true, Opened = false
})

ScriptsSection:Button({
	Title = "Infinite Yield", Desc = "Load Infinite Yield admin commands", Icon = "terminal",
	Callback = function()
		loadstring(game:HttpGet("https://raw.githubusercontent.com/EdgeIY/infiniteyield/master/source"))()
		WindUI:Notify({Title = "Infinite Yield", Content = "Loaded", Duration = 3})
	end
})

ScriptsSection:Button({
	Title = "Remote Spy Mod", Desc = "Load Remote Spy", Icon = "venetian-mask",
	Callback = function()
		loadstring(game:HttpGet("https://pastebin.com/raw/g967CR0U"))()
		WindUI:Notify({Title = "Remote Spy [Mod]", Content = "Loaded", Duration = 3})
	end
})

ScriptsSection:Button({
	Title = "Fly Script", Desc = "Load Fly V3 script", Icon = "bird",
	Callback = function()
		loadstring(game:HttpGet("https://raw.githubusercontent.com/S-3ntinel/FE/main/Fly3.lua"))()
		WindUI:Notify({Title = "Fly Script", Content = "Loaded", Duration = 3})
	end
})

PlayerTab:Divider()
PlayerTab:Button({
	Title = "Unlock FPS", Desc = "Remove Roblox FPS cap", Icon = "zap",
	Callback = function()
		local x = pcall(function() setfpscap(999) end)
		if x then WindUI:Notify({Title = "FPS", Content = "FPS unlocked to 999", Duration = 3}) end
	end
})

-- ────────────── TAB: ANOTHER PLAYER ──────────────
local Hitbox = {
	Active = false,
	Size = Vector3.new(10, 10, 10),
	Transparency = 0.7,
	ESPEnabled = false,
	OriginalSizes = {},
	Highlights = {}
}

SetG("Hitbox", Hitbox)

local function SaveOriginalSize(player)
	if not player.Character then return end
	local rootPart = player.Character:FindFirstChild("HumanoidRootPart")
	if rootPart and not Hitbox.OriginalSizes[player] then
		Hitbox.OriginalSizes[player] = rootPart.Size
	end
end

local function RestoreOriginalSize(player)
	if not player.Character then return end
	local rootPart = player.Character:FindFirstChild("HumanoidRootPart")
	if rootPart and Hitbox.OriginalSizes[player] then
		rootPart.Size = Hitbox.OriginalSizes[player]
		rootPart.Transparency = 1
		rootPart.BrickColor = BrickColor.new("Medium stone grey")
		rootPart.Material = Enum.Material.Plastic
		rootPart.CanCollide = true
		Hitbox.OriginalSizes[player] = nil
	end
end

local function UpdatePlayerESP(player)
	if not Hitbox.ESPEnabled or not player.Character then
		if Hitbox.Highlights[player] then
			Hitbox.Highlights[player]:Destroy()
			Hitbox.Highlights[player] = nil
		end
		return
	end
	
	if not Hitbox.Highlights[player] then
		local h = Instance.new("Highlight")
		h.Adornee = player.Character
		h.FillColor = Color3.fromRGB(0, 255, 255)
		h.OutlineColor = Color3.fromRGB(255, 255, 255)
		h.FillTransparency = 0.5
		h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		h.Parent = player.Character
		Hitbox.Highlights[player] = h
	end
end

local function UpdateHitboxes()
	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= LocalPlayer and player.Character then
			local rootPart = player.Character:FindFirstChild("HumanoidRootPart")
			if rootPart then
				if Hitbox.Active then
					SaveOriginalSize(player)
					rootPart.Size = Hitbox.Size
					rootPart.Transparency = Hitbox.Transparency
					rootPart.BrickColor = BrickColor.new("Really blue")
					rootPart.Material = Enum.Material.Neon
					rootPart.CanCollide = false
				else
					if Hitbox.OriginalSizes[player] then
						rootPart.Size = Hitbox.OriginalSizes[player]
					else
						rootPart.Size = Vector3.new(2, 2, 1)
					end
					rootPart.Transparency = 1
					rootPart.BrickColor = BrickColor.new("Medium stone grey")
					rootPart.Material = Enum.Material.Plastic
					rootPart.CanCollide = true
					Hitbox.OriginalSizes[player] = nil
				end
			end
		end
	end
end

local function UpdateAllESP()
	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= LocalPlayer then
			UpdatePlayerESP(player)
		end
	end
end

local function ResetAllHitboxes()
	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= LocalPlayer and player.Character then
			local rootPart = player.Character:FindFirstChild("HumanoidRootPart")
			if rootPart then
				if Hitbox.OriginalSizes[player] then
					rootPart.Size = Hitbox.OriginalSizes[player]
				else
					rootPart.Size = Vector3.new(2, 2, 1)
				end
				rootPart.Transparency = 1
				rootPart.BrickColor = BrickColor.new("Medium stone grey")
				rootPart.Material = Enum.Material.Plastic
				rootPart.CanCollide = true
				Hitbox.OriginalSizes[player] = nil
			end
		end
	end
end

Utils.AddConnection("HitboxRenderStepped", RunService.RenderStepped:Connect(function()
	if Hitbox.ESPEnabled then
		for _, player in ipairs(Players:GetPlayers()) do
			if player ~= LocalPlayer then
				UpdatePlayerESP(player)
			end
		end
	end
end))

Utils.AddConnection("HitboxStepped", RunService.Stepped:Connect(function()
	if Hitbox.Active then
		UpdateHitboxes()
	end
end))

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function()
		task.wait(0.5)
		if Hitbox.ESPEnabled then
			UpdatePlayerESP(player)
		end
		if Hitbox.Active then
			SaveOriginalSize(player)
		end
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	if Hitbox.Highlights[player] then
		Hitbox.Highlights[player]:Destroy()
		Hitbox.Highlights[player] = nil
	end
	Hitbox.OriginalSizes[player] = nil
end)

local HitboxSection = AnotherPlayerTab:Section({
	Title = "Hitbox Settings",
	Desc = "Modify player hitboxes",
	Icon = "settings",
	Box = true,
	BoxBorder = true,
	Opened = false
})

HitboxSection:Toggle({
	Title = "Enable Hitbox",
	Desc = "Expand other players' hitboxes",
	Value = false,
	Flag = "HitboxEnable",
	Callback = function(state)
		Hitbox.Active = state
		SetG("Hitbox.Active", state)
		
		if not state then
			ResetAllHitboxes()
		end
		
		WindUI:Notify({
			Title = "Hitbox",
			Content = state and "Enabled" or "Disabled",
			Duration = 2
		})
	end
})

HitboxSection:Slider({
	Title = "Hitbox Size",
	Desc = "Adjust hitbox size",
	Value = {Default = 10, Min = 1, Max = 50},
	Flag = "HitboxSize",
	Callback = function(value)
		Hitbox.Size = Vector3.new(value, value, value)
		SetG("Hitbox.Size", Hitbox.Size)
		
		if Hitbox.Active then
			for _, player in ipairs(Players:GetPlayers()) do
				if player ~= LocalPlayer and player.Character then
					local rootPart = player.Character:FindFirstChild("HumanoidRootPart")
					if rootPart then
						rootPart.Size = Hitbox.Size
					end
				end
			end
		end
	end
})

local HitboxTransparencySlider = HitboxSection:Slider({
	Title = "Transparency",
	Desc = "Adjust hitbox transparency",
	Value = {Default = 0.7, Min = 0, Max = 1},
	Step = 0.1,
	Flag = "HitboxTransparency",
	Callback = function(value)
		Hitbox.Transparency = value
		SetG("Hitbox.Transparency", value)
		
		if Hitbox.Active then
			for _, player in ipairs(Players:GetPlayers()) do
				if player ~= LocalPlayer and player.Character then
					local rootPart = player.Character:FindFirstChild("HumanoidRootPart")
					if rootPart then
						rootPart.Transparency = Hitbox.Transparency
					end
				end
			end
		end
	end
})

HitboxSection:Toggle({
	Title = "Enable ESP",
	Desc = "Show highlight around players (independent from hitbox)",
	Value = false,
	Flag = "HitboxESP",
	Callback = function(state)
		Hitbox.ESPEnabled = state
		SetG("Hitbox.ESPEnabled", state)
		
		if not state then
			HitboxTransparencySlider:Set(0.7)
			for _, player in ipairs(Players:GetPlayers()) do
				if player ~= LocalPlayer and Hitbox.Highlights[player] then
					Hitbox.Highlights[player]:Destroy()
					Hitbox.Highlights[player] = nil
				end
			end
		else
			HitboxTransparencySlider:Set(1)
			UpdateAllESP()
		end
		
		WindUI:Notify({
			Title = "ESP",
			Content = state and "Enabled" or "Disabled",
			Duration = 2
		})
	end
})

-- ESP Players Section
local ESPPlayersSection = AnotherPlayerTab:Section({
	Title = "ESP Players", Desc = "Visual ESP for other players",
	Icon = "eye", Box = true, BoxBorder = true, Opened = true
})

local espTargets, espAllPlayers, espEnabled, espObjects, selectedEspTypes, espConnections = {}, false, {}, {}, {}, {}

local function getTeamColor(player)
	return player.Team and player.Team.TeamColor.Color or Color3.fromRGB(0, 255, 0)
end

local function clearESP(player)
	if espObjects[player] then
		for _, obj in pairs(espObjects[player]) do
			if obj and obj.Parent then obj:Destroy() end
		end
		espObjects[player] = nil
	end
	if espConnections[player] then
		espConnections[player]:Disconnect()
		espConnections[player] = nil
	end
end

local function createESP(player, character)
	clearESP(player)
	espObjects[player] = {}
	if not character then return end
	
	local teamColor = getTeamColor(player)
	
	if selectedEspTypes["Body"] then
		local highlight = Instance.new("Highlight")
		highlight.Name = "ESP_Body"
		highlight.Adornee = character
		highlight.FillColor = teamColor
		highlight.FillTransparency = 0.4
		highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
		highlight.OutlineTransparency = 0
		highlight.Parent = character
		table.insert(espObjects[player], highlight)
	end
	
	if selectedEspTypes["Box"] then
		local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
		if humanoidRootPart then
			local box = Instance.new("BoxHandleAdornment")
			box.Name = "ESP_Box"
			box.Adornee = humanoidRootPart
			box.Size = Vector3.new(4, 6, 2)
			box.Color3 = teamColor
			box.Transparency = 0.3
			box.AlwaysOnTop = true
			box.ZIndex = 10
			box.Parent = humanoidRootPart
			table.insert(espObjects[player], box)
		end
	end
	
	if selectedEspTypes["Tracer"] then
		local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
		if humanoidRootPart then
			local line = Instance.new("LineHandleAdornment")
			line.Name = "ESP_Tracer"
			line.Adornee = humanoidRootPart
			line.Length = 100
			line.Thickness = 2
			line.Color3 = teamColor
			line.ZIndex = 5
			line.Parent = humanoidRootPart
			table.insert(espObjects[player], line)
		end
	end
	
	if selectedEspTypes["HP Bar"] then
		local humanoidRootPart = character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Head")
		if humanoidRootPart then
			local hpBar = Instance.new("BillboardGui")
			hpBar.Name = "ESP_HPBar"
			hpBar.Adornee = humanoidRootPart
			hpBar.Size = UDim2.new(4, 0, 0.5, 0)
			hpBar.StudsOffset = Vector3.new(0, 3.5, 0)
			hpBar.AlwaysOnTop = true
			
			local background = Instance.new("Frame")
			background.Name = "Background"
			background.Size = UDim2.new(1, 0, 1, 0)
			background.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
			background.BorderSizePixel = 0
			background.Parent = hpBar
			
			local fill = Instance.new("Frame")
			fill.Name = "Fill"
			fill.Size = UDim2.new(1, 0, 1, 0)
			fill.BackgroundColor3 = teamColor
			fill.BorderSizePixel = 0
			fill.Parent = background
			
			hpBar.Parent = humanoidRootPart
			table.insert(espObjects[player], hpBar)
		end
	end
	
	if selectedEspTypes["Name"] then
		local humanoidRootPart = character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Head")
		if humanoidRootPart then
			local nameTag = Instance.new("BillboardGui")
			nameTag.Name = "ESP_Name"
			nameTag.Adornee = humanoidRootPart
			nameTag.Size = UDim2.new(0, 200, 0, 50)
			nameTag.StudsOffset = Vector3.new(0, 4.5, 0)
			nameTag.AlwaysOnTop = true
			
			local textLabel = Instance.new("TextLabel")
			textLabel.Name = "Text"
			textLabel.Size = UDim2.new(1, 0, 1, 0)
			textLabel.BackgroundTransparency = 1
			textLabel.Text = player.DisplayName .. " (@" .. player.Name .. ")"
			textLabel.TextColor3 = teamColor
			textLabel.TextSize = 16
			textLabel.TextStrokeTransparency = 0
			textLabel.Font = Enum.Font.GothamBold
			textLabel.Parent = nameTag
			
			nameTag.Parent = humanoidRootPart
			table.insert(espObjects[player], nameTag)
		end
	end
	
	if selectedEspTypes["Distance"] then
		local humanoidRootPart = character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Head")
		if humanoidRootPart then
			local distanceTag = Instance.new("BillboardGui")
			distanceTag.Name = "ESP_Distance"
			distanceTag.Adornee = humanoidRootPart
			distanceTag.Size = UDim2.new(0, 200, 0, 50)
			distanceTag.StudsOffset = Vector3.new(0, 6, 0)
			distanceTag.AlwaysOnTop = true
			
			local textLabel = Instance.new("TextLabel")
			textLabel.Name = "Text"
			textLabel.Size = UDim2.new(1, 0, 1, 0)
			textLabel.BackgroundTransparency = 1
			textLabel.Text = "0m"
			textLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
			textLabel.TextSize = 14
			textLabel.TextStrokeTransparency = 0
			textLabel.Font = Enum.Font.Gotham
			textLabel.Parent = distanceTag
			
			distanceTag.Parent = humanoidRootPart
			table.insert(espObjects[player], distanceTag)
			
			espConnections[player] = RunService.RenderStepped:Connect(function()
				if player.Character and LocalPlayer.Character then
					local targetHrp = player.Character:FindFirstChild("HumanoidRootPart")
					local localHrp = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
					if targetHrp and localHrp then
						local distance = (targetHrp.Position - localHrp.Position).Magnitude
						textLabel.Text = string.format("%.1fm", distance)
					end
				end
			end)
		end
	end
end

local function updateESPTypes()
	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= LocalPlayer and espEnabled[player] then
			if player.Character then createESP(player, player.Character) end
		end
	end
end

local function updatePlayerList()
	local players = {}
	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= LocalPlayer then
			table.insert(players, player.DisplayName .. " (@" .. player.Name .. ")")
		end
	end
	table.sort(players)
	return players
end

local function updateESP()
	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= LocalPlayer then
			local found = false
			for _, target in ipairs(espTargets) do
				if target == player.Name then found = true; break end
			end
			
			local shouldESP = espAllPlayers or found
			
			if shouldESP and not espEnabled[player] then
				espEnabled[player] = true
				if player.Character then createESP(player, player.Character) end
				player.CharacterAdded:Connect(function(char)
					task.wait(0.5)
					if espEnabled[player] then createESP(player, char) end
				end)
			elseif not shouldESP and espEnabled[player] then
				espEnabled[player] = false
				clearESP(player)
			end
		end
	end
end

local playerDropdown = ESPPlayersSection:Dropdown({
	Title = "Select Players", Desc = "Choose players to ESP",
	Values = updatePlayerList(), Multi = true, Flag = "ESPPlayers",
	Callback = function(values)
		espTargets = {}
		for _, value in ipairs(values) do
			local parts = value:split("(@")
			if #parts == 2 then table.insert(espTargets, parts[2]:sub(1, -2)) end
		end
		updateESP()
	end
})

ESPPlayersSection:Toggle({
	Title = "All Players", Desc = "ESP on all players (overrides selection)",
	Value = false, Flag = "ESPAllPlayers",
	Callback = function(state) espAllPlayers = state; updateESP() end
})

local espTypes = {"Body", "Box", "Tracer", "HP Bar", "Name", "Distance"}

local espDropdown = ESPPlayersSection:Dropdown({
	Title = "ESP Types", Desc = "Choose ESP visual types",
	Values = espTypes, Multi = true, Flag = "ESPTypes",
	Callback = function(values)
		selectedEspTypes = {}
		for _, v in ipairs(values) do selectedEspTypes[v] = true end
		updateESPTypes()
	end
})

Players.PlayerAdded:Connect(function(player)
	task.wait(1)
	playerDropdown:Refresh(updatePlayerList())
end)

Players.PlayerRemoving:Connect(function(player)
	clearESP(player)
	espEnabled[player] = nil
	for i, target in ipairs(espTargets) do
		if target == player.Name then table.remove(espTargets, i); break end
	end
	playerDropdown:Refresh(updatePlayerList())
	updateESP()
end)

for _, player in ipairs(Players:GetPlayers()) do
	if player ~= LocalPlayer then
		player.CharacterAdded:Connect(function(char)
			if espEnabled[player] then task.wait(0.5); createESP(player, char) end
		end)
	end
end

ESPPlayersSection:Button({
	Title = "Refresh Players", Desc = "Refresh player list", Icon = "refresh-cw",
	Callback = function()
		playerDropdown:Refresh(updatePlayerList())
		WindUI:Notify({Title = "ESP", Content = "Player list refreshed", Duration = 2})
	end
})

ESPPlayersSection:Button({
	Title = "Clear All ESP", Desc = "Remove all ESP visuals", Icon = "trash-2",
	Callback = function()
		for _, player in ipairs(Players:GetPlayers()) do clearESP(player) end
		espEnabled, espObjects, espTargets, espConnections = {}, {}, {}, {}
		playerDropdown:Set({})
		WindUI:Notify({Title = "ESP", Content = "All ESP cleared", Duration = 2})
	end
})

-- Camera Section (Another Player)
local CameraSectionAP = AnotherPlayerTab:Section({
	Title = "Camera", Desc = "Camera controls for other players",
	Icon = "camera", Box = true, BoxBorder = true, Opened = false
})

local viewingPlayer, viewDied, viewChanged, lookAtEnabled, selectedCameraPlayer = nil, nil, nil, false, nil

local function updatePlayerListCamera()
	local players = {}
	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= LocalPlayer then
			table.insert(players, player.DisplayName .. " (@" .. player.Name .. ")")
		end
	end
	table.sort(players)
	return players
end

local cameraDropdown = CameraSectionAP:Dropdown({
	Title = "Select Player", Desc = "Choose player to view/look at",
	Values = updatePlayerListCamera(), Multi = false, Flag = "CameraPlayer",
	Callback = function(value)
		local parts = value:split("(@")
		selectedCameraPlayer = #parts == 2 and parts[2]:sub(1, -2) or value
	end
})

Players.PlayerAdded:Connect(function()
	cameraDropdown:Refresh(updatePlayerListCamera())
end)

Players.PlayerRemoving:Connect(function(player)
	if viewingPlayer == player then
		viewingPlayer = nil
		Utils.Disconnect("ViewDied")
		Utils.Disconnect("ViewChanged")
		workspace.CurrentCamera.CameraSubject = LocalPlayer.Character
	end
	cameraDropdown:Refresh(updatePlayerListCamera())
end)

local function stopViewing()
	if viewDied then viewDied:Disconnect(); viewDied = nil end
	if viewChanged then viewChanged:Disconnect(); viewChanged = nil end
	viewingPlayer = nil
	workspace.CurrentCamera.CameraSubject = LocalPlayer.Character
end

CameraSectionAP:Toggle({
	Title = "Look At Player", Desc = "Continuously look at player's head",
	Value = false, Flag = "LookAtPlayer",
	Callback = function(state)
		SetG("LookAtPlayer", state)
		Utils.Disconnect("LookAtLoop")
		
		if state and selectedCameraPlayer then
			local target = findPlayerByName(selectedCameraPlayer)
			if not target or not target.Character then
				WindUI:Notify({Title = "Error", Content = "Player not found!", Duration = 2})
				return
			end
			
			SetG("LookAtOriginalZoom", {
				Max = LocalPlayer.CameraMaxZoomDistance,
				Min = LocalPlayer.CameraMinZoomDistance
			})
			LocalPlayer.CameraMaxZoomDistance = 0.5
			LocalPlayer.CameraMinZoomDistance = 0.5
			
			Utils.AddConnection("LookAtLoop", RunService.RenderStepped:Connect(function()
				if not GetG("LookAtPlayer") then return end
				local currentTarget = findPlayerByName(selectedCameraPlayer)
				if currentTarget and currentTarget.Character then
					local head = currentTarget.Character:FindFirstChild("Head")
					if head then
						local camera = workspace.CurrentCamera
						camera.CFrame = CFrame.new(camera.CFrame.Position, head.Position)
					end
				end
			end))
			WindUI:Notify({Title = "Look At", Content = "Looking at " .. target.Name, Duration = 2})
		else
			local originalZoom = GetG("LookAtOriginalZoom")
			if originalZoom then
				LocalPlayer.CameraMaxZoomDistance = originalZoom.Max
				LocalPlayer.CameraMinZoomDistance = originalZoom.Min
			end
			WindUI:Notify({Title = "Look At", Content = "Stopped", Duration = 2})
		end
	end
})

CameraSectionAP:Toggle({
	Title = "View Player", Desc = "Spectate selected player",
	Value = false, Flag = "ViewPlayer",
	Callback = function(state)
		if state then
			if not selectedCameraPlayer then
				WindUI:Notify({Title = "Error", Content = "Select a player first!", Duration = 2})
				return
			end
			
			local target = findPlayerByName(selectedCameraPlayer)
			if not target then
				WindUI:Notify({Title = "Error", Content = "Player not found!", Duration = 2})
				return
			end
			
			viewingPlayer = target
			stopViewing()
			
			if target.Character then workspace.CurrentCamera.CameraSubject = target.Character end
			
			local function viewDiedFunc()
				repeat task.wait() until target.Character
				workspace.CurrentCamera.CameraSubject = target.Character
			end
			
			viewDied = target.CharacterAdded:Connect(viewDiedFunc)
			Utils.AddConnection("ViewDied", viewDied)
			
			local function viewChangedFunc()
				if workspace.CurrentCamera.CameraSubject ~= target.Character then
					workspace.CurrentCamera.CameraSubject = target.Character
				end
			end
			
			viewChanged = workspace.CurrentCamera:GetPropertyChangedSignal("CameraSubject"):Connect(viewChangedFunc)
			Utils.AddConnection("ViewChanged", viewChanged)
			WindUI:Notify({Title = "View", Content = "Viewing " .. target.Name, Duration = 2})
		else
			stopViewing()
			WindUI:Notify({Title = "View", Content = "Stopped viewing", Duration = 2})
		end
	end
})

local ClickFollowSection = AnotherPlayerTab:Section({
	Title = "Click to Follow", Desc = "Click on a player to pathfind to them",
	Icon = "mouse-pointer", Box = true, BoxBorder = true, Opened = false
})

local CF = {
	enabled = false,
	target = nil,
	highlight = nil,
	conn = nil,
	path = PathfindingService:CreatePath({AgentRadius = 2, AgentCanJump = true})
}

function CF.stop()
	CF.target = nil
	if CF.highlight then CF.highlight:Destroy(); CF.highlight = nil end
	if LocalPlayer.Character and LocalPlayer.Character:FindFirstChildWhichIsA("Humanoid") then
		local hum = LocalPlayer.Character:FindFirstChildWhichIsA("Humanoid")
		local root = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
		if hum and root then hum:MoveTo(root.Position) end
	end
end

function CF.loop()
	while CF.enabled and CF.target do
		if not CF.target or not CF.target.Character or not CF.target.Character:FindFirstChild("HumanoidRootPart") then CF.stop(); break end
		local char = LocalPlayer.Character
		if not char then task.wait(0.5) continue end
		local hum = char:FindFirstChildWhichIsA("Humanoid")
		local root = char:FindFirstChild("HumanoidRootPart")
		local targetRoot = CF.target.Character.HumanoidRootPart
		if not hum or not root or not targetRoot then task.wait(0.5) continue end
		
		if (root.Position - targetRoot.Position).Magnitude > 5 then
			local success = pcall(function() CF.path:ComputeAsync(root.Position, targetRoot.Position) end)
			if success and CF.path.Status == Enum.PathStatus.Success then
				local waypoints = CF.path:GetWaypoints()
				if waypoints[2] then
					hum:MoveTo(waypoints[2].Position)
					if waypoints[2].Action == Enum.PathWaypointAction.Jump then hum.Jump = true end
				end
			else hum:MoveTo(targetRoot.Position) end
		end
		task.wait(0.1)
	end
	CF.stop()
end

function CF.onInput(input)
	if not CF.enabled then return end
	if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
	
	local mousePos = UserInputService:GetMouseLocation()
	local unitRay = workspace.CurrentCamera:ViewportPointToRay(mousePos.X, mousePos.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = {LocalPlayer.Character or {}}
	local result = workspace:Raycast(unitRay.Origin, unitRay.Direction * 500, params)
	
	if result and result.Instance then
		local hitChar = result.Instance:FindFirstAncestorOfClass("Model")
		local hitPlayer = Players:GetPlayerFromCharacter(hitChar)
		if hitPlayer then
			if hitPlayer == CF.target then CF.stop()
			else
				CF.stop()
				CF.target = hitPlayer
				CF.highlight = Instance.new("Highlight")
				CF.highlight.FillTransparency = 1
				CF.highlight.OutlineColor = Color3.fromRGB(255, 0, 0)
				CF.highlight.OutlineTransparency = 0
				CF.highlight.Parent = hitChar
				task.spawn(CF.loop)
			end
		end
	end
end

ClickFollowSection:Toggle({
	Title = "Enable Click to Follow",
	Desc = "Click on a player to pathfind to them. Click again to stop.",
	Value = false, Flag = "ClickFollowToggle",
	Callback = function(state)
		CF.enabled = state
		if state then
			CF.conn = UserInputService.InputBegan:Connect(CF.onInput)
			WindUI:Notify({Title = "Click to Follow", Content = "Enabled - Click on players", Duration = 2})
		else
			if CF.conn then CF.conn:Disconnect(); CF.conn = nil end
			CF.stop()
			WindUI:Notify({Title = "Click to Follow", Content = "Disabled", Duration = 2})
		end
	end
})

Players.PlayerRemoving:Connect(function(p)
	if CF.target and p == CF.target then CF.stop() end
end)

-- ────────────── TAB: Troll ──────────────
local FlingSection = TrollTab:Section({
	Title = "Fling", Desc = "Fling players and objects",
	Icon = "zap", Box = true, BoxBorder = true, Opened = true
})

local TeleportAnnoySection = TrollTab:Section({
	Title = "Teleport Annoy", Desc = "Annoy players by teleporting",
	Icon = "users", Box = true, BoxBorder = true, Opened = false
})

local BackShotSection = TrollTab:Section({
	Title = "Back Shot", Desc = "Move back and forth behind target",
	Icon = "arrow-left-right", Box = true, BoxBorder = true, Opened = false
})

local JerkOffSection = TrollTab:Section({
	Title = "Jerk Off", Desc = "Add jerk off tool to backpack",
	Icon = "hand", Box = true, BoxBorder = true, Opened = false
})

local WalkFlingData = {Enabled = false, Loop = nil}
FlingSection:Toggle({
	Title = "Walk Fling", Desc = "Fling while walking",
	Value = false, Flag = "WalkFlingToggle",
	Callback = function(state)
		WalkFlingData.Enabled = state
		if state then
			local char = LocalPlayer.Character
			if not char then return end
			SetG("NoclipEnabled", true)
			applyNoclipToCharacter(char)
			Utils.AddConnection("WalkFlingDeath", char:FindFirstChildOfClass("Humanoid").Died:Connect(function()
				-- Find toggle element and set false
				for _, element in pairs(AbilitiesSection.Elements or {}) do
					if element.Flag == "WalkFlingToggle" and element.Set then
						element:Set(false)
						break
					end
				end
			end))
			WalkFlingData.Loop = true
			Utils.StartThread("WalkFlingLoop", function()
				local movel = 0.1
				while WalkFlingData.Loop do
					local character = LocalPlayer.Character
					local root = getRoot(character)
					local vel = root and root.Velocity
					if character and root and vel then
						root.Velocity = vel * 10000 + Vector3.new(0, 10000, 0)
						RunService.RenderStepped:Wait()
						if character and root then root.Velocity = vel end
						RunService.Stepped:Wait()
						if character and root then
							root.Velocity = vel + Vector3.new(0, movel, 0)
							movel = movel * -1
						end
					end
					RunService.Heartbeat:Wait()
				end
			end)
			WindUI:Notify({Title = "Walk Fling", Content = "Enabled", Duration = 2})
		else
			WalkFlingData.Loop = false
			Utils.Disconnect("WalkFlingDeath")
			SetG("NoclipEnabled", false)
			Utils.Disconnect("NoclipLoop")
			Utils.Disconnect("NoclipCharacterAdded")
			WindUI:Notify({Title = "Walk Fling", Content = "Disabled", Duration = 2})
		end
	end
})

local selectedAnnoyPlayer, annoyEnabled, annoyDelay = nil, false, 0.1
local function updatePlayerListAnnoy()
	local players = {}
	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= LocalPlayer then
			table.insert(players, player.DisplayName .. " (@" .. player.Name .. ")")
		end
	end
	table.sort(players)
	return players
end

local annoyDropdown = TeleportAnnoySection:Dropdown({
	Title = "Select Player to Annoy",
	Desc = "Choose player to teleport to periodically",
	Values = updatePlayerListAnnoy(),
	Multi = false,
	SearchBarEnabled = true,
	Callback = function(value)
		local parts = value:split("(@")
		selectedAnnoyPlayer = #parts == 2 and parts[2]:sub(1, -2) or value
	end
})
Players.PlayerAdded:Connect(function() annoyDropdown:Refresh(updatePlayerListAnnoy()) end)
Players.PlayerRemoving:Connect(function(player)
	if selectedAnnoyPlayer == player.Name then selectedAnnoyPlayer = nil end
	annoyDropdown:Refresh(updatePlayerListAnnoy())
end)

TeleportAnnoySection:Toggle({
	Title = "Annoy Selected Player",
	Desc = "Teleport to selected player every 0.1 seconds",
	Value = false,
	Callback = function(state)
		annoyEnabled = state
		Utils.Disconnect("TeleportAnnoyLoop")
		if state then
			if not selectedAnnoyPlayer then
				WindUI:Notify({Title = "Error", Content = "Select a player first!", Duration = 3})
				return false
			end
			local username = selectedAnnoyPlayer
			if selectedAnnoyPlayer:find("(@") then
				local parts = selectedAnnoyPlayer:split("(@")
				username = parts[2]:sub(1, -2)
			end
			Utils.CreateLoop("TeleportAnnoyLoop", function()
				if not annoyEnabled then return end
				local target = findPlayerByName(username)
				if not target or not target.Character then return end
				local char = LocalPlayer.Character
				if char then
					local hrp = char:FindFirstChild("HumanoidRootPart")
					local targetHrp = target.Character:FindFirstChild("HumanoidRootPart")
					if hrp and targetHrp then hrp.CFrame = targetHrp.CFrame end
				end
				task.wait(annoyDelay)
			end)
			WindUI:Notify({Title = "Teleport Annoy", Content = "Enabled - Annoying " .. username, Duration = 2})
		else
			WindUI:Notify({Title = "Teleport Annoy", Content = "Disabled", Duration = 2})
		end
	end
})

TeleportAnnoySection:Input({
	Title = "Teleport Delay", Desc = "Delay between teleports (seconds)",
	Value = "0.1", Placeholder = "0.1", Flag = "AnnoyDelay",
	Callback = function(value)
		local num = tonumber(value)
		if num and num >= 0.01 then annoyDelay = num end
	end
})

local selectedBackShotTarget, backShotEnabled, backShotDistance, backShotSpeed = nil, false, 5, 0.1
local function updateBackShotPlayerList()
	local players = {}
	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= LocalPlayer then
			table.insert(players, player.DisplayName .. " (@" .. player.Name .. ")")
		end
	end
	table.sort(players)
	return players
end
local backShotDropdown = BackShotSection:Dropdown({
	Title = "Select Target", Desc = "Choose player for Back Shot",
	Values = updateBackShotPlayerList(), Multi = false, Flag = "BackShotTargetDropdown",
	SearchBarEnabled = true,
	Callback = function(value)
		local parts = value:split("(@")
		selectedBackShotTarget = #parts == 2 and parts[2]:sub(1, -2) or value
	end
})
Players.PlayerAdded:Connect(function() backShotDropdown:Refresh(updateBackShotPlayerList()) end)
Players.PlayerRemoving:Connect(function(player)
	if selectedBackShotTarget == player.Name then selectedBackShotTarget = nil end
	backShotDropdown:Refresh(updateBackShotPlayerList())
end)
BackShotSection:Toggle({
	Title = "Back Shot", Desc = "Back Shoting target",
	Value = false, Flag = "BackShot",
	Callback = function(state)
		backShotEnabled = state
		Utils.Disconnect("BackShotLoop")
		if state then
			if not selectedBackShotTarget then
				WindUI:Notify({Title = "Error", Content = "Select a target first!", Duration = 3})
				return false
			end
			local username = selectedBackShotTarget
			if selectedBackShotTarget:find("(@") then
				local parts = selectedBackShotTarget:split("(@")
				username = parts[2]:sub(1, -2)
			end
			Utils.CreateLoop("BackShotLoop", function()
				if not backShotEnabled then return end
				local target = findPlayerByName(username)
				if not target or not target.Character then return end
				local char = LocalPlayer.Character
				if not char then return end
				local hrp = char:FindFirstChild("HumanoidRootPart")
				local targetHrp = target.Character:FindFirstChild("HumanoidRootPart")
				if not hrp or not targetHrp then return end
				local tweenService = game:GetService("TweenService")
				local tweenInfo = TweenInfo.new(backShotSpeed, Enum.EasingStyle.Linear)
				local lookCF = CFrame.lookAt(targetHrp.Position, targetHrp.Position + targetHrp.CFrame.LookVector)
				local back1 = lookCF * CFrame.new(0, 0, 1)
				local back5 = lookCF * CFrame.new(0, 0, backShotDistance)
				local tween = tweenService:Create(hrp, tweenInfo, {CFrame = back1})
				tween:Play()
				tween.Completed:Wait()
				tween = tweenService:Create(hrp, tweenInfo, {CFrame = back5})
				tween:Play()
				tween.Completed:Wait()
			end)
			WindUI:Notify({Title = "Back Shot", Content = "Activated on " .. username, Duration = 2})
		else
			WindUI:Notify({Title = "Back Shot", Content = "Deactivated", Duration = 2})
		end
	end
})
BackShotSection:Slider({
	Title = "Back Distance", Desc = "Maximum backward distance",
	Value = {Default = 5, Min = 1, Max = 20}, Flag = "BackShotDistance",
	Callback = function(value) backShotDistance = value end
})
BackShotSection:Slider({
	Title = "Move Speed", Desc = "Backshot speed",
	Step = 0.1,
	Value = {Default = 0.1, Min = 0.05, Max = 1}, Flag = "BackShotSpeed",
	Callback = function(value) backShotSpeed = value end
})

TrollTab:Divider()
TrollTab:Button({
	Title = "Jerk Off Tool",
	Desc = "Add a jerk off tool to your backpack",
	Icon = "hand",
	Callback = function()
		local humanoid = LocalPlayer.Character:FindFirstChildWhichIsA("Humanoid")
		local backpack = LocalPlayer:FindFirstChildWhichIsA("Backpack")
		if not humanoid or not backpack then
			WindUI:Notify({Title = "Error", Content = "Character or backpack not found", Duration = 3})
			return
		end

		local tool = Instance.new("Tool")
		tool.Name = "Jerk Off"
		tool.ToolTip = "in the stripped club. straight up \"jorking it\" . and by \"it\" , haha, well. let's just say. My peanits."
		tool.RequiresHandle = false
		tool.Parent = backpack

		local jorkin = false
		local track = nil

		local function stopTomfoolery()
			jorkin = false
			if track then
				track:Stop()
				track = nil
			end
		end

		tool.Equipped:Connect(function() jorkin = true end)
		tool.Unequipped:Connect(stopTomfoolery)
		humanoid.Died:Connect(stopTomfoolery)

		task.spawn(function()
			while task.wait() do
				if not jorkin then continue end
				local isR15 = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid") and LocalPlayer.Character:FindFirstChildOfClass("Humanoid").RigType == Enum.HumanoidRigType.R15
				if not track then
					local anim = Instance.new("Animation")
					anim.AnimationId = not isR15 and "rbxassetid://72042024" or "rbxassetid://698251653"
					track = humanoid:LoadAnimation(anim)
				end

				track:Play()
				track:AdjustSpeed(isR15 and 0.7 or 0.65)
				track.TimePosition = 0.6
				task.wait(0.1)
				while track and track.TimePosition < (not isR15 and 0.65 or 0.7) do task.wait(0.1) end
				if track then
					track:Stop()
					track = nil
				end
			end
		end)

		WindUI:Notify({Title = "Jerk Off", Content = "Tool added to backpack", Duration = 3})
	end
})
TrollTab:Paragraph({Title = "i have no idea what should i add in here, lemme know if u have idea, msg me on Rey Hub server, i might add em\n> Vera"})
-- ────────────── TAB: TELEPORT ──────────────
-- Player Teleport Section
local PlayerTeleportSection = TeleportTab:Section({
	Title = "Teleport to Player", Desc = "Teleport to online players",
	Icon = "users", Box = true, BoxBorder = true, Opened = true
})

local selectedPlayer = nil
local playerDropdownTP

local function updatePlayerListTP()
	local players = {}
	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= LocalPlayer then
			table.insert(players, player.DisplayName .. " (@" .. player.Name .. ")")
		end
	end
	table.sort(players)
	return players
end

playerDropdownTP = PlayerTeleportSection:Dropdown({
	Title = "Select Player", Desc = "Choose player to teleport to",
	Values = updatePlayerListTP(), Multi = false, Flag = "PlayerDropdownTP", SearchBarEnabled = true,
	Callback = function(value)
		local parts = value:split("(@")
		selectedPlayer = #parts == 2 and parts[2]:sub(1, -2) or value
	end
})

Players.PlayerAdded:Connect(function()
	playerDropdownTP:Refresh(updatePlayerListTP())
end)

Players.PlayerRemoving:Connect(function(player)
	if selectedPlayer == player.Name then selectedPlayer = nil end
	playerDropdownTP:Refresh(updatePlayerListTP())
end)

PlayerTeleportSection:Button({
	Title = "Teleport to Player", Desc = "Teleport to selected player", Icon = "navigation",
	Callback = function()
		if not selectedPlayer then
			WindUI:Notify({Title = "Error", Content = "Select a player first!", Duration = 3})
			return
		end
		local username = selectedPlayer
		if selectedPlayer:find("(@") then
			local parts = selectedPlayer:split("(@")
			username = parts[2]:sub(1, -2)
		end
		local target = findPlayerByName(username)
		if not target or not target.Character then
			WindUI:Notify({Title = "Error", Content = "Player not found!", Duration = 3})
			return
		end
		local char = LocalPlayer.Character
		if char then
			local hrp = char:FindFirstChild("HumanoidRootPart")
			local targetHrp = target.Character:FindFirstChild("HumanoidRootPart")
			if hrp and targetHrp then
				hrp.CFrame = targetHrp.CFrame
				WindUI:Notify({
					Title = "Teleport", 
					Content = "Teleported to " .. target.DisplayName .. " (@" .. target.Name .. ")", 
					Duration = 3
				})
			end
		end
	end
})

-- Saved Position Section
local SavedPositionSection = TeleportTab:Section({
	Title = "Saved Positions", Desc = "Save and teleport to positions",
	Icon = "bookmark", Box = true, BoxBorder = true, Opened = false
})

local savedPositions, selectedSavedPosition, positionNameInput = {}, nil, ""
local positionDropdown

local function refreshPositionDropdown()
	local positionNames = {}
	for name in pairs(savedPositions) do table.insert(positionNames, name) end
	table.sort(positionNames)
	positionDropdown:Refresh(positionNames)
end

positionDropdown = SavedPositionSection:Dropdown({
	Title = "Saved Positions", Desc = "Select saved position",
	Values = {}, Multi = false, Flag = "PositionDropdown", SearchBarEnabled = true,
	Callback = function(value) selectedSavedPosition = value end
})

local inputGroup = SavedPositionSection:Group({Title = "Position Name"})
inputGroup:Input({
	Title = "Position Name", Desc = "Enter name for position",
	Placeholder = "Enter position name...", Flag = "PositionName",
	Callback = function(value) positionNameInput = value end
})

local SavedPositionGroup = SavedPositionSection:Group({Title = "Actions"})
SavedPositionGroup:Button({
	Title = "Remove", Desc = "Delete selected position", Icon = "trash-2", Flag = "RemovePosition",
	Callback = function()
		if selectedSavedPosition and savedPositions[selectedSavedPosition] then
			savedPositions[selectedSavedPosition] = nil
			refreshPositionDropdown()
			WindUI:Notify({Title = "Position", Content = "Removed: " .. selectedSavedPosition, Duration = 3})
		end
	end
})

SavedPositionGroup:Button({
	Title = "Save", Desc = "Save current position", Icon = "save", Flag = "SavePosition",
	Callback = function()
		if positionNameInput and positionNameInput ~= "" then
			local char = LocalPlayer.Character
			if char then
				local hrp = char:FindFirstChild("HumanoidRootPart")
				if hrp then
					savedPositions[positionNameInput] = hrp.CFrame
					refreshPositionDropdown()
					WindUI:Notify({Title = "Position", Content = "Saved: " .. positionNameInput, Duration = 3})
				end
			end
		end
	end
})

SavedPositionSection:Button({
	Title = "Teleport to Saved", Desc = "Teleport to selected saved position", Icon = "navigation",
	Callback = function()
		if selectedSavedPosition and savedPositions[selectedSavedPosition] then
			local char = LocalPlayer.Character
			if char then
				local hrp = char:FindFirstChild("HumanoidRootPart")
				if hrp then
					hrp.CFrame = savedPositions[selectedSavedPosition]
					WindUI:Notify({Title = "Teleport", Content = "Teleported to " .. selectedSavedPosition, Duration = 3})
				end
			end
		else
			WindUI:Notify({Title = "Error", Content = "No position selected!", Duration = 3})
		end
	end
})

TeleportTab:Section({Title = "Misc", Icon = "skull", Box = true, BoxBorder = true, Opened = false})

local lastDeath = nil
local function setupDeathTracking()
	local char = LocalPlayer.Character
	if char then
		local humanoid = char:FindFirstChildOfClass("Humanoid")
		if humanoid then
			Utils.AddConnection("DeathTracker", humanoid.Died:Connect(function()
				local root = getRoot(char)
				if root then lastDeath = root.CFrame end
			end))
		end
	end
	
	Utils.AddConnection("CharacterAddedDeathTracker", LocalPlayer.CharacterAdded:Connect(function(newChar)
		task.wait(0.5)
		local humanoid = newChar:FindFirstChildOfClass("Humanoid")
		if humanoid then
			Utils.Disconnect("DeathTracker")
			Utils.AddConnection("DeathTracker", humanoid.Died:Connect(function()
				local root = getRoot(newChar)
				if root then lastDeath = root.CFrame end
			end))
		end
	end))
end
setupDeathTracking()

TeleportTab:Button({
	Title = "Teleport to Last Death", Desc = "Teleport to location where you last died", Icon = "skull",
	Callback = function()
		if lastDeath ~= nil then
			local char = LocalPlayer.Character
			if char then
				local humanoid = char:FindFirstChildOfClass("Humanoid")
				if humanoid and humanoid.SeatPart then humanoid.Sit = false; task.wait(0.1) end
				local root = getRoot(char)
				if root then
					root.CFrame = lastDeath
					WindUI:Notify({Title = "Teleport", Content = "Teleported to last death location", Duration = 3})
				end
			end
		else
			WindUI:Notify({Title = "Error", Content = "No death location recorded yet", Duration = 3})
		end
	end
})

TeleportTab:Button({
	Title = "Teleport Tool", Desc = "Tool to teleport to mouse position", Icon = "navigation",
	Callback = function()
		local TpTool = Instance.new("Tool")
		TpTool.Name = "Teleport Tool"
		TpTool.RequiresHandle = false
		local mouse = LocalPlayer:GetMouse()
		
		TpTool.Activated:Connect(function()
			local Char = LocalPlayer.Character
			local HRP = Char and Char:FindFirstChild("HumanoidRootPart")
			if not Char or not HRP then
				WindUI:Notify({Title = "Error", Content = "Failed to find HumanoidRootPart", Duration = 2})
				return
			end
			local hitPos = mouse.Hit
			HRP.CFrame = CFrame.new(hitPos.X, hitPos.Y + 3, hitPos.Z, select(4, HRP.CFrame:components()))
		end)
		TpTool.Parent = LocalPlayer.Backpack or LocalPlayer.Character
		WindUI:Notify({Title = "Teleport Tool", Content = "Tool added to backpack", Duration = 2})
	end
})

-- ────────────── TAB: MISC ──────────────
-- ────────────── GUI SECTION ──────────────
local GuiSection = MiscTab:Section({
	Title = "GUI", Desc = "GUI detection features",
	Icon = "layout-grid", Box = true, BoxBorder = true, Opened = true
})

local GuiDetectionState = {
	mode = "onClick",
	detectionEnabled = false,
	lastDetectedPath = "",
	lastDetectedGui = nil,
	hookedButtons = {}
}

SetG("GuiDetectionState", GuiDetectionState)

local pathParagraph = GuiSection:Paragraph({Title = "Gui Path:", Desc = "No path detected yet"})

GuiSection:Dropdown({
	Title = "Detection Mode", Desc = "Choose detection method",
	Values = {"onClick", "Hover"}, Multi = false, Value = "onClick", Flag = "Guis.mode",
	Callback = function(value)
		GuiDetectionState.mode = value
		if GuiDetectionState.detectionEnabled then
			local wasEnabled = GuiDetectionState.detectionEnabled
			GuiDetectionState.detectionEnabled = false
			cleanupGUIHooks()
			if wasEnabled then
				task.wait(0.1)
				startGUIHooks()
				GuiDetectionState.detectionEnabled = true
			end
		end
	end
})

local function isActuallyVisible(gui)
	if not gui:IsDescendantOf(LocalPlayer.PlayerGui) then 
		return false 
	end
	if gui:IsA("GuiObject") and (gui.AbsoluteSize.X <= 0 or gui.AbsoluteSize.Y <= 0) then 
		return false 
	end
	
	local current = gui
	while current and current ~= LocalPlayer.PlayerGui do
		if current:IsA("ScreenGui") and current.Enabled == false then 
			return false 
		end
		if current:IsA("GuiObject") and current.Visible == false then 
			return false 
		end
		current = current.Parent
	end
	return true
end

local function cleanupGUIHooks()
	for key, conn in pairs(GetG("ActiveConnections") or {}) do
		if key:find("GUI_") then 
			Utils.Disconnect(key) 
		end
	end
	
	for gui in pairs(GuiDetectionState.hookedButtons) do
		GuiDetectionState.hookedButtons[gui] = nil
	end
	
	if GuiDetectionState.descendantConnection then
		GuiDetectionState.descendantConnection:Disconnect()
		GuiDetectionState.descendantConnection = nil
	end
end

local function hookButton(gui)
	if not (gui:IsA("TextButton") or gui:IsA("ImageButton")) then 
		return 
	end
	
	if GuiDetectionState.hookedButtons[gui] then 
		return 
	end
	
	local fullName = gui:GetFullName()
	GuiDetectionState.hookedButtons[gui] = true
	
	local function onDetected()
		if isActuallyVisible(gui) then
			GuiDetectionState.lastDetectedPath = fullName
			GuiDetectionState.lastDetectedGui = gui
			pathParagraph:SetDesc(fullName)
		end
	end
	
	if GuiDetectionState.mode == "onClick" then
		Utils.AddConnection("GUI_Click_" .. fullName:gsub("[%.%[%]]", "_"), gui.MouseButton1Click:Connect(onDetected))
		Utils.AddConnection("GUI_ClickDown_" .. fullName:gsub("[%.%[%]]", "_"), gui.MouseButton1Down:Connect(onDetected))
	else
		Utils.AddConnection("GUI_Hover_" .. fullName:gsub("[%.%[%]]", "_"), gui.MouseEnter:Connect(onDetected))
		if UserInputService.TouchEnabled then
			Utils.AddConnection("GUI_Touch_" .. fullName:gsub("[%.%[%]]", "_"), gui.InputBegan:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.Touch then
					onDetected()
				end
			end))
		end
	end
end

local function startGUIHooks()
	cleanupGUIHooks()
	
	GuiDetectionState.hookedButtons = {}
	
	for _, gui in ipairs(LocalPlayer.PlayerGui:GetDescendants()) do
		hookButton(gui)
	end
	
	GuiDetectionState.descendantConnection = LocalPlayer.PlayerGui.DescendantAdded:Connect(function(gui)
		hookButton(gui)
	end)
	Utils.AddConnection("GUI_DescendantAdded", GuiDetectionState.descendantConnection)
end

GuiSection:Toggle({
	Title = "Enable GUI Detection", Desc = "Start detecting GUI interactions",
	Value = false, Flag = "GuiDetection",
	Callback = function(state)
		GuiDetectionState.detectionEnabled = state
		
		if state then
			startGUIHooks()
			WindUI:Notify({Title = "GUI Detection", Content = "Enabled", Duration = 2})
		else
			cleanupGUIHooks()
			WindUI:Notify({Title = "GUI Detection", Content = "Disabled", Duration = 2})
		end
	end
})

local GuiActions = GuiSection:Group({Title = "Actions"})

GuiActions:Button({
	Title = "Copy Path", Desc = "Copy path to clipboard", Icon = "copy",
	Callback = function()
		if GuiDetectionState.lastDetectedPath and GuiDetectionState.lastDetectedPath ~= "" then
			setclipboard(GuiDetectionState.lastDetectedPath)
			WindUI:Notify({Title = "Copied", Content = "Path copied to clipboard", Duration = 2})
		else
			WindUI:Notify({Title = "Error", Content = "No path to copy", Duration = 2})
		end
	end
})

local function clickGUI(gui)
	if not gui then return false end
	
	local methods = {
		{func = function() 
			if gui.MouseButton1Click then 
				firesignal(gui.MouseButton1Click, LocalPlayer) 
			end
		end},
		{func = function() 
			if gui.MouseButton1Click then 
				firesignal(gui.MouseButton1Click) 
			end
		end},
		{func = function() 
			if getconnections then
				for _, v in pairs(getconnections(gui.MouseButton1Down)) do 
					if v.Function then v.Function() end
				end
			end
		end},
		{func = function() 
			if getconnections then
				for _, v in pairs(getconnections(gui.MouseButton1Down)) do 
					if v.Fire then v:Fire() end
				end
			end
		end},
		{func = function() 
			if gui.MouseButton1Click and replicatesignal then 
				replicatesignal(gui.MouseButton1Click) 
			end
		end},
		{func = function()
			local success = pcall(function()
				gui:Activate()
			end)
			return success
		end}
	}
	
	for i, method in ipairs(methods) do
		local success = pcall(method.func)
		if success then return true end
	end
	
	return false
end

GuiActions:Button({
	Title = "Click It", Desc = "Fire signal on detected GUI", Icon = "mouse-pointer",
	Callback = function()
		if GuiDetectionState.lastDetectedGui then
			if clickGUI(GuiDetectionState.lastDetectedGui) then
				WindUI:Notify({Title = "Success", Content = "Signal fired", Duration = 1})
			else
				WindUI:Notify({Title = "Error", Content = "All methods failed", Duration = 2})
			end
		else
			WindUI:Notify({Title = "Error", Content = "No GUI object to click", Duration = 2})
		end
	end
})

local clickDelay = 0.5
GuiSection:Input({
	Title = "Click Delay", Desc = "Delay between auto clicks (seconds)",
	Value = "0.5", Flag = "ClickDelay",
	Callback = function(value)
		local num = tonumber(value)
		if num and num >= 0 then 
			clickDelay = num
			WindUI:Notify({Title = "Delay", Content = "Set to " .. num .. "s", Duration = 2}) 
		end
	end
})

GuiSection:Toggle({
	Title = "Auto Click", Desc = "Automatically click detected GUI",
	Value = false, Flag = "AutoClick",
	Callback = function(state)
		SetG("AutoClickEnabled", state)
		Utils.Disconnect("AutoClickLoop")
		
		if state then
			if not GuiDetectionState.lastDetectedGui then
				WindUI:Notify({Title = "Error", Content = "No GUI detected yet", Duration = 2})
				return false
			end
			
			Utils.CreateLoop("AutoClickLoop", function()
				if not GetG("AutoClickEnabled") or not GuiDetectionState.lastDetectedGui then 
					return 
				end
				
				local success = clickGUI(GuiDetectionState.lastDetectedGui)
				
				local method = GetG("LoopMethod") or "While Loop"
				if method == "While Loop" and clickDelay > 0 then 
					task.wait(clickDelay) 
				end
			end)
			
			WindUI:Notify({Title = "Auto Click", Content = "Enabled", Duration = 2})
		else
			WindUI:Notify({Title = "Auto Click", Content = "Disabled", Duration = 2})
		end
	end
})


local ProximitySection = MiscTab:Section({
	Title = "ProximityPrompt", Desc = "ProximityPrompt management",
	Icon = "sparkles", Box = true, BoxBorder = true, Opened = false
})

ProximitySection:Paragraph({Title = "can ban used as Instant and Auto Steal, works on almost all Brainrot games"})
ProximitySection:Toggle({
	Title = "Instant Prompt", Desc = "Instantly trigger proximity prompts",
	Value = false, Flag = "InstantPrompt",
	Callback = function(state)
		SetG("InstantPrompt", state)
		Utils.Disconnect("InstantPromptConnection")
		
		if state then
			local connection
			connection = game:GetService("ProximityPromptService").PromptShown:Connect(function(prompt)
				if not GetG("InstantPrompt") then connection:Disconnect() return end
				prompt.HoldDuration = 0
			end)
			Utils.AddConnection("InstantPromptConnection", connection)
			WindUI:Notify({Title = "Instant Prompt", Content = "Enabled", Duration = 2})
		else
			WindUI:Notify({Title = "Instant Prompt", Content = "Disabled", Duration = 2})
		end
	end
})

ProximitySection:Toggle({
	Title = "Auto Fire Prompt Shown", Desc = "Auto Fire ProximityPrompts Shown",
	Value = false, Flag = "AutoFPrompt",
	Callback = function(state)
		SetG("AutoFPrompt", state)
		Utils.Disconnect("AutoFPromptConnection")
		
		if state then
			local connection
			connection = game:GetService("ProximityPromptService").PromptShown:Connect(function(prompt)
				if not GetG("AutoFPrompt") then connection:Disconnect() return end
				if fireproximityprompt then
					fireproximityprompt(prompt)
				else
					VirtualUser:CaptureController()
					VirtualUser:SetKeyDown("e")
					VirtualUser:SetKeyUp("e")
				end
			end)
			Utils.AddConnection("AutoFPromptConnection", connection)
			WindUI:Notify({Title = "Auto Fire Prompt", Content = "Enabled", Duration = 2})
		else
			WindUI:Notify({Title = "Auto Fire Prompt", Content = "Disabled", Duration = 2})
		end
	end
})

-- Remote Section
local RemoteSection = MiscTab:Section({
	Title = "Remote Executor", Desc = "Execute remote functions/events",
	Icon = "terminal", Box = true, BoxBorder = true, Opened = false
})

local remoteCode = [[-- Example: game:GetService("ReplicatedStorage").Remotes:FireServer()]]
local codeDisplay = RemoteSection:Code({Title = "Code Preview", Code = remoteCode})

RemoteSection:Input({
	Title = "Remote Code", Desc = "Paste remote code here",
	Placeholder = "game:GetService(\"ReplicatedStorage\").Remote:FireServer(...)",
	Flag = "RemoteCodeInput",
	Callback = function(value)
		remoteCode = value
		codeDisplay:SetCode(value)
	end
})

local fireCount, fireDelayRemote, loopFire = 1, 0.1, false

RemoteSection:Input({
	Title = "Fire Count", Desc = "How many times to execute", Value = "1", Flag = "FireCount",
	Callback = function(value)
		local num = tonumber(value)
		if num and num >= 1 then fireCount = num end
	end
})

RemoteSection:Input({
	Title = "Fire Delay", Desc = "Delay between executions (seconds)", Value = "0.1", Flag = "FireDelayRemote",
	Callback = function(value)
		local num = tonumber(value)
		if num and num >= 0 then fireDelayRemote = num end
	end
})

local RemoteActions = RemoteSection:Group({Title = "Actions"})

RemoteActions:Button({
	Title = "Execute Once", Desc = "Execute remote code once", Icon = "zap",
	Callback = function()
		if remoteCode and remoteCode ~= "" then
			local success, err = pcall(function() loadstring(remoteCode)() end)
			if success then
				WindUI:Notify({Title = "Remote", Content = "Executed successfully", Duration = 2})
			else
				WindUI:Notify({Title = "Error", Content = "Execution failed: " .. tostring(err), Duration = 3})
			end
		else
			WindUI:Notify({Title = "Error", Content = "No code to execute", Duration = 2})
		end
	end
})

RemoteActions:Button({
	Title = "Execute Multiple", Desc = "Execute multiple times", Icon = "zap",
	Callback = function()
		if remoteCode and remoteCode ~= "" then
			local successCount, failCount = 0, 0
			for i = 1, fireCount do
				local success, err = pcall(function() loadstring(remoteCode)() end)
				if success then successCount = successCount + 1 else failCount = failCount + 1 end
				if fireDelayRemote > 0 and i < fireCount then task.wait(fireDelayRemote) end
			end
			WindUI:Notify({Title = "Remote", Content = string.format("Executed: %d success, %d failed", successCount, failCount), Duration = 3})
		else
			WindUI:Notify({Title = "Error", Content = "No code to execute", Duration = 2})
		end
	end
})

RemoteSection:Toggle({
	Title = "Loop Execute", Desc = "Continuously execute remote", Value = false, Flag = "LoopExecute",
	Callback = function(state)
		loopFire = state
		SetG("LoopExecute", state)
		Utils.Disconnect("RemoteLoop")
		if state then
			if not remoteCode or remoteCode == "" then
				WindUI:Notify({Title = "Error", Content = "No code to execute", Duration = 2})
				return
			end
			Utils.CreateLoop("RemoteLoop", function()
				if not GetG("LoopExecute") then return end
				local success, err = pcall(function() loadstring(remoteCode)() end)
				if not success then
					WindUI:Notify({Title = "Error", Content = "Loop stopped: " .. tostring(err), Duration = 3})
					SetG("LoopExecute", false)
					-- Find toggle element and set false
					for _, element in pairs(RemoteSection.Elements or {}) do
						if element.Flag == "LoopExecute" and element.Set then
							element:Set(false)
							break
						end
					end
					return
				end
				local method = GetG("LoopMethod") or "While Loop"
				if method == "While Loop" and fireDelayRemote >= 0 then task.wait(fireDelayRemote) end
			end)
			WindUI:Notify({Title = "Loop", Content = "Loop execution started", Duration = 2})
		else
			WindUI:Notify({Title = "Loop", Content = "Loop execution stopped", Duration = 2})
		end
	end
})

-- Fake Donation Section
local FakeDonationSection = MiscTab:Section({
	Title = "Fake Donation", Desc = "Only work in few game",
	Icon = "gift", Box = true, BoxBorder = true, Opened = false
})

local selectedDonationProduct, donationProducts = nil, {}

local function loadDonationProducts()
	donationProducts = {}
	pcall(function()
		local MarketplaceService = game:GetService("MarketplaceService")
		local products = MarketplaceService:GetDeveloperProductsAsync():GetCurrentPage()
		for _, product in pairs(products) do
			table.insert(donationProducts, {
				Name = product.Name or "N/A",
				Id = product.ProductId or 0,
				Desc = product.Description or "N/A",
				Price = product.PriceInRobux or 0
			})
		end
	end)
end

local donationDropdown = FakeDonationSection:Dropdown({
	Title = "Developer Products", Desc = "Select a product", Values = {}, Multi = false, Flag = "DonationProducts", SearchBarEnabled = true,
	Callback = function(value) selectedDonationProduct = value end
})

local function refreshDonationList()
	loadDonationProducts()
	local productNames = {}
	for _, product in ipairs(donationProducts) do table.insert(productNames, product.Name) end
	donationDropdown:Refresh(productNames)
end

FakeDonationSection:Button({
	Title = "Refresh Products", Desc = "Refresh product list", Icon = "refresh-cw",
	Callback = function() refreshDonationList(); WindUI:Notify({Title = "Donation", Content = "Product list refreshed", Duration = 2}) end
})

local DonationActions = FakeDonationSection:Group({Title = "Actions"})

DonationActions:Button({
	Title = "Copy ID", Desc = "Copy product ID to clipboard", Icon = "copy",
	Callback = function()
		if selectedDonationProduct then
			for _, product in ipairs(donationProducts) do
				if product.Name == selectedDonationProduct then
					if setclipboard then setclipboard(tostring(product.Id)) end
					WindUI:Notify({Title = "Copied", Content = "ID copied: " .. product.Id, Duration = 2})
					break
				end
			end
		end
	end
})

DonationActions:Button({
	Title = "Fire Donation", Desc = "Fake purchase product", Icon = "zap",
	Callback = function()
		if selectedDonationProduct then
			for _, product in ipairs(donationProducts) do
				if product.Name == selectedDonationProduct then
					pcall(function()
						local MarketplaceService = game:GetService("MarketplaceService")
						MarketplaceService:SignalPromptProductPurchaseFinished(LocalPlayer.UserId, product.Id, true)
						WindUI:Notify({Title = "Donation", Content = "Fired: " .. product.Name, Duration = 2})
					end)
					break
				end
			end
		end
	end
})

-- Visual Section
local VisualSection = MiscTab:Section({
	Title = "Lighting & Visual", Desc = "Lighting and visual effects controls",
	Icon = "eye", Box = true, BoxBorder = true, Opened = false
})

local fullbrightEnabled, xrayEnabled, lagReductionEnabled, loopFullbrightEnabled = false, false, false, false
local originalLighting, playerLight, lightRadius, lightBrightness = {}, nil, 30, 5

local function saveOriginalLighting()
	if not workspace:FindFirstChildOfClass("Lighting") then return end
	local lighting = workspace:FindFirstChildOfClass("Lighting")
	originalLighting = {
		Ambient = lighting.Ambient,
		Brightness = lighting.Brightness,
		GlobalShadows = lighting.GlobalShadows,
		OutdoorAmbient = lighting.OutdoorAmbient,
		FogStart = lighting.FogStart,
		FogEnd = lighting.FogEnd,
		ClockTime = lighting.ClockTime,
		BloomEnabled = lighting.Bloom.Enabled,
		BlurEnabled = lighting.Blur.Enabled,
		ColorCorrectionEnabled = lighting.ColorCorrection.Enabled,
		SunRaysEnabled = lighting.SunRays.Enabled
	}
end
saveOriginalLighting()

local function applyFullbright()
	local lighting = game:GetService("Lighting")
	lighting.Ambient = Color3.new(1, 1, 1)
	lighting.Brightness = 2
	lighting.GlobalShadows = false
	lighting.OutdoorAmbient = Color3.new(1, 1, 1)
	lighting.FogStart = 100000
	lighting.FogEnd = 100000
end

VisualSection:Button({
	Title = "Fullbright", Desc = "Makes the map brighter / more visible", Icon = "sun",
	Callback = function() applyFullbright(); WindUI:Notify({Title = "Fullbright", Content = "Enabled", Duration = 2}) end
})

VisualSection:Toggle({
	Title = "Loop Fullbright", Desc = "Makes the map brighter / more visible but looped",
	Value = false, Flag = "LoopFullbright",
	Callback = function(state)
		loopFullbrightEnabled = state
		Utils.Disconnect("LoopFullbright")
		if state then
			Utils.CreateLoop("LoopFullbright", function() applyFullbright() end)
			WindUI:Notify({Title = "Loop Fullbright", Content = "Enabled", Duration = 2})
		else
			WindUI:Notify({Title = "Loop Fullbright", Content = "Disabled", Duration = 2})
		end
	end
})

local defaultAmbientR = originalLighting.Ambient and math.floor(originalLighting.Ambient.R * 255) or 127
local defaultAmbientG = originalLighting.Ambient and math.floor(originalLighting.Ambient.G * 255) or 127
local defaultAmbientB = originalLighting.Ambient and math.floor(originalLighting.Ambient.B * 255) or 127
local defaultBrightness = originalLighting.Brightness and math.floor(originalLighting.Brightness * 10) or 10
local defaultGlobalShadows = originalLighting.GlobalShadows ~= nil and originalLighting.GlobalShadows or true

VisualSection:Slider({
	Title = "Ambient R", Desc = "Red component of ambient lighting",
	Value = {Default = defaultAmbientR, Min = 0, Max = 255}, Flag = "AmbientR",
	Callback = function(value)
		local lighting = game:GetService("Lighting")
		local current = lighting.Ambient
		lighting.Ambient = Color3.fromRGB(value, math.floor(current.G * 255), math.floor(current.B * 255))
	end
})

VisualSection:Slider({
	Title = "Ambient G", Desc = "Green component of ambient lighting",
	Value = {Default = defaultAmbientG, Min = 0, Max = 255}, Flag = "AmbientG",
	Callback = function(value)
		local lighting = game:GetService("Lighting")
		local current = lighting.Ambient
		lighting.Ambient = Color3.fromRGB(math.floor(current.R * 255), value, math.floor(current.B * 255))
	end
})

VisualSection:Slider({
	Title = "Ambient B", Desc = "Blue component of ambient lighting",
	Value = {Default = defaultAmbientB, Min = 0, Max = 255}, Flag = "AmbientB",
	Callback = function(value)
		local lighting = game:GetService("Lighting")
		local current = lighting.Ambient
		lighting.Ambient = Color3.fromRGB(math.floor(current.R * 255), math.floor(current.G * 255), value)
	end
})

VisualSection:Button({
	Title = "Day", Desc = "Changes the time to day for the client", Icon = "sun",
	Callback = function() game:GetService("Lighting").ClockTime = 14; WindUI:Notify({Title = "Day", Content = "Time set to day", Duration = 2}) end
})

VisualSection:Button({
	Title = "Night", Desc = "Changes the time to night for the client", Icon = "moon",
	Callback = function() game:GetService("Lighting").ClockTime = 0; WindUI:Notify({Title = "Night", Content = "Time set to night", Duration = 2}) end
})

VisualSection:Toggle({
	Title = "No Fog", Desc = "Removes fog", Value = false, Flag = "NoFog",
	Callback = function(state)
		local lighting = game:GetService("Lighting")
		if state then
			lighting.FogStart = 100000
			lighting.FogEnd = 100000
			WindUI:Notify({Title = "No Fog", Content = "Fog removed", Duration = 2})
		else
			lighting.FogStart = originalLighting.FogStart or 0
			lighting.FogEnd = originalLighting.FogEnd or 100000
			WindUI:Notify({Title = "No Fog", Content = "Fog restored", Duration = 2})
		end
	end
})

VisualSection:Slider({
	Title = "Brightness", Desc = "Changes the brightness lighting property",
	Value = {Default = defaultBrightness, Min = 0, Max = 30}, Flag = "Brightness",
	Callback = function(value) game:GetService("Lighting").Brightness = value / 10 end
})

VisualSection:Toggle({
	Title = "Global Shadows", Desc = "Toggle global shadows", Value = defaultGlobalShadows, Flag = "GlobalShadows",
	Callback = function(state) game:GetService("Lighting").GlobalShadows = state; WindUI:Notify({Title = "Global Shadows", Content = state and "Enabled" or "Disabled", Duration = 2}) end
})

VisualSection:Button({
	Title = "Restore Lighting", Desc = "Restores Lighting properties", Icon = "rotate-ccw",
	Callback = function()
		local lighting = game:GetService("Lighting")
		lighting.Ambient = originalLighting.Ambient or Color3.new(0.5, 0.5, 0.5)
		lighting.Brightness = originalLighting.Brightness or 1
		lighting.GlobalShadows = originalLighting.GlobalShadows or true
		lighting.ClockTime = originalLighting.ClockTime or 14
		lighting.FogStart = originalLighting.FogStart or 0
		lighting.FogEnd = originalLighting.FogEnd or 100000
		lighting.OutdoorAmbient = originalLighting.OutdoorAmbient or Color3.new(0.5, 0.5, 0.5)
		if originalLighting.BloomEnabled ~= nil then
			lighting.Bloom.Enabled = originalLighting.BloomEnabled
			lighting.Blur.Enabled = originalLighting.BlurEnabled
			lighting.ColorCorrection.Enabled = originalLighting.ColorCorrectionEnabled
			lighting.SunRays.Enabled = originalLighting.SunRaysEnabled
		end
		VisualSection:Get("AmbientR"):Set(defaultAmbientR)
		VisualSection:Get("AmbientG"):Set(defaultAmbientG)
		VisualSection:Get("AmbientB"):Set(defaultAmbientB)
		VisualSection:Get("Brightness"):Set(defaultBrightness)
		VisualSection:Get("GlobalShadows"):Set(defaultGlobalShadows)
		VisualSection:Get("NoFog"):Set(false)
		VisualSection:Get("LoopFullbright"):Set(false)
		if playerLight then playerLight:Destroy(); playerLight = nil end
		WindUI:Notify({Title = "Lighting", Content = "Restored to original", Duration = 2})
	end
})

VisualSection:Slider({
	Title = "Light Radius", Desc = "Radius for player light",
	Value = {Default = 30, Min = 5, Max = 100}, Flag = "LightRadius",
	Callback = function(value) lightRadius = value; if playerLight then playerLight.Range = value end end
})

VisualSection:Slider({
	Title = "Light Brightness", Desc = "Brightness for player light",
	Value = {Default = 5, Min = 1, Max = 20}, Flag = "LightBrightness",
	Callback = function(value) lightBrightness = value; if playerLight then playerLight.Brightness = value end end
})

VisualSection:Toggle({
	Title = "Player Light", Desc = "Gives your player dynamic light",
	Value = false, Flag = "PlayerLight",
	Callback = function(state)
		if state then
			if playerLight then playerLight:Destroy() end
			local char = LocalPlayer.Character
			if char then
				local root = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Head")
				if root then
					playerLight = Instance.new("PointLight")
					playerLight.Parent = root
					playerLight.Range = lightRadius
					playerLight.Brightness = lightBrightness
					playerLight.Shadows = true
					Utils.AddConnection("PlayerLightCharacterAdded", LocalPlayer.CharacterAdded:Connect(function(newChar)
						task.wait(0.5)
						if GetG("PlayerLight") then
							local newRoot = newChar:FindFirstChild("HumanoidRootPart") or newChar:FindFirstChild("Head")
							if newRoot then
								playerLight = Instance.new("PointLight")
								playerLight.Parent = newRoot
								playerLight.Range = lightRadius
								playerLight.Brightness = lightBrightness
								playerLight.Shadows = true
							end
						end
					end))
				end
			end
			WindUI:Notify({Title = "Player Light", Content = "Enabled", Duration = 2})
		else
			if playerLight then playerLight:Destroy(); playerLight = nil end
			Utils.Disconnect("PlayerLightCharacterAdded")
			WindUI:Notify({Title = "Player Light", Content = "Disabled", Duration = 2})
		end
	end
})

-- ────────────── TAB: SETTINGS ──────────────
-- Configs Section
local ConfigsSection = SettingsTab:Section({
	Title = "Config System", Desc = "Save and load your settings",
	Icon = "folder", Box = true, BoxBorder = true, Opened = true
})

local configNameInput, selectedConfig = "", nil
local configDropdown

local function refreshConfigList()
	local allConfigs = ConfigManager:AllConfigs() or {}
	local configNames = {}
	for i, configName in ipairs(allConfigs) do ConfigManager:CreateConfig(configName) table.insert(configNames, configName) end
	configDropdown:Refresh(configNames)
	return #configNames > 0
end

configDropdown = ConfigsSection:Dropdown({
	Title = "Saved Configs", Desc = "Select a config to load/delete",
	Values = {}, Multi = false, SearchBarEnabled = true,
	Callback = function(value) selectedConfig = value end
})

ConfigsSection:Input({
	Title = "Config Name", Desc = "Enter name for your config file",
	Placeholder = "MyConfig",
	Callback = function(value) configNameInput = value end
})

local ConfigActionsGroup = ConfigsSection:Group({Title = "Config Actions"})

ConfigActionsGroup:Button({
	Title = "Save Config", Desc = "Save current settings to config", Icon = "save",
	Callback = function()
		if configNameInput and configNameInput ~= "" then
			local data = mainConfig:GetData().elements
			mainConfig = ConfigManager:CreateConfig(configNameInput)
			mainConfig.Elements = data
			mainConfig.Save()
			WindUI:Notify({Title = "Configs", Content = "Config saved successfully!", Duration = 2})
			refreshConfigList()
		else
			WindUI:Notify({Title = "Configs", Content = "Please enter a config name", Duration = 2})
		end
	end
})

ConfigActionsGroup:Button({
	Title = "Load Config", Desc = "Load selected config", Icon = "folder-open",
	Callback = function()
		if selectedConfig and ConfigManager:GetConfig(selectedConfig) then
			mainConfig = ConfigManager:GetConfig(selectedConfig)
			mainConfig.Load()
			WindUI:Notify({Title = "Configs", Content = "Config loaded successfully!", Duration = 2})
		else
			WindUI:Notify({Title = "Configs", Content = "Please select a config", Duration = 2})
		end
	end
})

ConfigActionsGroup:Button({
	Title = "Delete Config", Desc = "Delete selected config", Icon = "trash-2",
	Callback = function()
		if selectedConfig then
			local found = false
			for _, val in pairs(ConfigManager:AllConfigs()) do
				if val == selectedConfig then found = true; break end
			end
			if found then
				local config = ConfigManager:CreateConfig(selectedConfig)
				config:Delete()
				refreshConfigList()
				WindUI:Notify({Title = "Configs", Content = "Config deleted successfully!", Duration = 2})
			else
				WindUI:Notify({Title = "Configs", Content = "Config not found", Duration = 2})
			end
		else
			WindUI:Notify({Title = "Configs", Content = "Please select a config", Duration = 2})
		end
	end
})

ConfigsSection:Button({
	Title = "Refresh Configs", Desc = "Refresh configs list", Icon = "refresh-cw",
	Callback = function()
		if refreshConfigList() then
			WindUI:Notify({Title = "Configs", Content = "Config list refreshed!", Duration = 2})
		else
			WindUI:Notify({Title = "Configs", Content = "No configs found", Duration = 2})
		end
	end
})
refreshConfigList()

ConfigsSection:Toggle({
	Title = "Auto-save Config", Desc = "Automatically save config (every 5s)",
	Value = false, Flag = "AutoSaveConfig",
	Callback = function(state)
		SetG("AutoSaveConfig", state)
		task.spawn(function()
			while GetG("AutoSaveConfig") do
				mainConfig.Save()
				task.wait(5)
			end
		end)
		WindUI:Notify({Title = "Auto-save", Content = state and "Enabled" or "Disabled", Duration = 2})
	end
})


local CustomizeSection = SettingsTab:Section({
	Title = "Customize", Desc = "Personalize UI interface",
	Icon = "palette", Box = true, BoxBorder = true, Opened = false
})

local themes = {"Dark", "Light", "Rose", "Plant", "Red", "Indigo", "Sky", "Violet", "Amber", "Emerald", "Midnight", "Crimson", "MonokaiPro", "CottonCandy", "Mellowsi"}
CustomizeSection:Dropdown({
	Title = "Theme Color", Desc = "Change UI color scheme",
	Values = themes, Multi = false, Flag = "ThemeColor",
	Callback = function(value) WindUI:SetTheme(value); WindUI:Notify({Title = "Theme", Content = "Theme changed to " .. value, Duration = 2}) end
})

CustomizeSection:Toggle({
	Title = "Hide User", Desc = "Show or hide user icon",
	Flag = "HideUser", Value = false,
	Callback = function(value)
		if value then
			Window.User:Disable()
		else
			Window.User:Enable()
		end
	end
})

CustomizeSection:Toggle({
	Title = "Anonymous User", Desc = "Set user icon to anonymous",
	Flag = "AnonymousUser", Value = false,
	Callback = function(value)
		Window.User:SetAnonymous(value)
	end
})

local FakesUI = CustomizeSection:Section({
	Title = "Fake UI", Desc = "(Only for Premium and Higher)",
	Icon = "hat-glasses", Box = true, BoxBorder = true, Opened = false
})

local FakeUI = {}
FakeUI.originalDataUser = {
	UserId = LocalPlayer.UserId,
	Name = LocalPlayer.Name,
	DisplayName = LocalPlayer.DisplayName
}

FakeUI.fakeDataUser = {
	Name = "",
	DisplayName = "",
	AvatarName = ""
}

FakeUI.UsernameInput = FakesUI:Input({
	Title = "Set Username", 
	Desc = "Set username",
	Placeholder = FakeUI.originalDataUser.Name,
	Locked = true, LockedTitle = "Premium and Higher Only",
	Callback = function(value)
		FakeUI.fakeDataUser.Name = value
	end
})

FakeUI.DisplayNameInput = FakesUI:Input({
	Title = "Set DisplayName", 
	Desc = "Set displayname",
	Placeholder = FakeUI.originalDataUser.DisplayName,
	Locked = true, LockedTitle = "Premium and Higher Only",
	Callback = function(value)
		FakeUI.fakeDataUser.DisplayName = value
	end
})

FakeUI.AvatarInput = FakesUI:Input({
	Title = "Set Avatar by Name",
	Desc = "Set user icon by name",
	Placeholder = FakeUI.originalDataUser.Name,
	Locked = true, LockedTitle = "Premium and Higher Only",
	Callback = function(value)
		FakeUI.fakeDataUser.AvatarName = value
	end
})

FakeUI.ApplyButton = FakesUI:Button({
	Title = "Apply Fake Identity for UI",
	Desc = "Apply fake Username, DisplayName, and Avatar",
	Icon = "user-pen", Locked = true, LockedTitle = "Premium and Higher Only",
	Callback = function()
		if FakeUI.fakeDataUser.Name ~= "" then
			LocalPlayer.Name = FakeUI.fakeDataUser.Name
			Window.User:SetAnonymous(false)
		end
		
		if FakeUI.fakeDataUser.DisplayName ~= "" then
			LocalPlayer.DisplayName = FakeUI.fakeDataUser.DisplayName
			Window.User:SetAnonymous(false)
		end
		
		if FakeUI.fakeDataUser.AvatarName ~= "" then
			local target = findPlayerByName(FakeUI.fakeDataUser.AvatarName)
			if target then
				local originalUserId = LocalPlayer.UserId
				LocalPlayer.UserId = target.UserId
				Window.User:SetAnonymous(false)
				LocalPlayer.UserId = originalUserId
			end
		end
		
		WindUI:Notify({Title = "Fake Identity", Content = "Applied fake identity for UI", Duration = 2})
	end
})

FakeUI.ResetButton = FakesUI:Button({
	Title = "Reset to Original",
	Desc = "Reset to original Username, DisplayName, and Avatar",
	Icon = "rotate-ccw", Locked = true, LockedTitle = "Premium and Higher Only",
	Callback = function()
		LocalPlayer.Name = FakeUI.originalDataUser.Name
		LocalPlayer.DisplayName = FakeUI.originalDataUser.DisplayName
		Window.User:SetAnonymous(false)
		WindUI:Notify({Title = "Identity", Content = "Reset to original", Duration = 2})
	end
})

task.spawn(function()
	local role = (GetRole and GetRole()) or "Free"
	if role == "Free" then return end
	for _, v in pairs(FakeUI) do
		if typeof(v) == "table" and typeof(v.Unlock) == "function" then
			pcall(function()
				v:Unlock()
			end)
		end
	end
end)

local ProtectionSection = SettingsTab:Section({
	Title = "Protection Systems", 
	Desc = "Anti-ban, anti-report, and anti-cheat bypass features",
	Icon = "shield", 
	Box = true, 
	BoxBorder = true, 
	Opened = false
})

ProtectionSection:Button({
	Title = "Bypass Voice Chat",
	Desc = "Attempt to bypass voice chat restrictions",
	Icon = "mic",
	Callback = function()
		local vc = game:GetService("VoiceChatService")
		local vi = game:GetService("VoiceChatInternal")
		local success, gid = pcall(function() return vi:GetGroupId() end)
		if not success then
			WindUI:Notify({Title = "Error", Content = "Failed to get group ID", Duration = 3})
			return
		end
		pcall(function() vi:JoinByGroupId(gid, false) end)
		pcall(function() vc:leaveVoice() end)
		task.wait()
		for i = 1, 4 do
			pcall(function() vi:JoinByGroupId(gid, false) end)
		end
		task.wait(5)
		pcall(function() vc:joinVoice() end)
		pcall(function() vi:JoinByGroupId(gid, false) end)
		WindUI:Notify({Title = "Voice Chat", Content = "Bypass attempt completed", Duration = 3})
	end
})

local antiBanEnabled = false
ProtectionSection:Toggle({
	Title = "Anti-Ban", 
	Desc = "Attempt to prevent game bans (experimental)",
	Value = false, 
	Flag = "AntiBan",
	Callback = function(state)
		antiBanEnabled = state
		if state then
			local mt = getrawmetatable(game)
			local oldNamecall = mt.__namecall
			local oldIndex = mt.__index
			setreadonly(mt, false)
			mt.__namecall = newcclosure(function(self, ...)
				local method = getnamecallmethod()
				if method == "Ban" or method == "ban" or method == "BanAsync" then
					WindUI:Notify({Title = "Anti-Ban", Content = "Ban attempt blocked", Duration = 2})
					return nil
				end
				return oldNamecall(self, ...)
			end)
			mt.__index = newcclosure(function(self, key)
				if key == "Ban" or key == "ban" then
					return function() 
						WindUI:Notify({Title = "Anti-Ban", Content = "Ban function blocked", Duration = 2})
						return nil 
					end
				end
				return oldIndex(self, key)
			end)
			setreadonly(mt, true)
			pcall(function()
				for _, obj in pairs(game:GetDescendants()) do
					if obj:IsA("StringValue") and (obj.Name:lower():find("ban") or obj.Value:lower():find("ban")) then
						obj:Destroy()
					end
				end
			end)
			WindUI:Notify({Title = "Anti-Ban", Content = "Enabled - Ban attempts will be blocked", Duration = 3})
		else
			WindUI:Notify({Title = "Anti-Ban", Content = "Disabled", Duration = 2})
		end
	end
})


local antiReportEnabled = false
ProtectionSection:Toggle({
	Title = "Anti-Report", 
	Desc = "Block report system and clear report data",
	Value = false, 
	Flag = "AntiReport",
	Callback = function(state)
		antiReportEnabled = state
		if state then
			local success, err = pcall(function()
				local mt = getrawmetatable(game)
				local oldNamecall = mt.__namecall
				setreadonly(mt, false)
				mt.__namecall = newcclosure(function(self, ...)
					local method = getnamecallmethod()
					local args = {...}
					local arg1 = args[1]
					if method == "ReportAbuse" or method == "Report" or 
					   method == "ReportAsync" or method == "SendReport" then
						WindUI:Notify({Title = "Anti-Report", Content = "Report attempt blocked", Duration = 2})
						return nil
					end
					if method == "SendAsync" and tostring(self):find("TextChatService") then
						local msg = tostring(arg1)
						if msg:lower():find("report") or msg:lower():find("cheat") or msg:lower():find("hack") then
							WindUI:Notify({Title = "Anti-Report", Content = "Report message filtered", Duration = 2})
							return nil
						end
					end
					return oldNamecall(self, ...)
				end)
				setreadonly(mt, true)
			end)
			task.spawn(function()
				while antiReportEnabled do
					pcall(function()
						for _, player in pairs(Players:GetPlayers()) do
							if player ~= LocalPlayer then
								pcall(function()
									local leaderstats = player:FindFirstChild("leaderstats")
									if leaderstats then
										for _, stat in pairs(leaderstats:GetChildren()) do
											if stat:IsA("StringValue") and stat.Value:lower():find("report") then
												stat.Value = ""
											end
										end
									end
								end)
							end
						end
					end)
					task.wait(10)
				end
			end)
			WindUI:Notify({Title = "Anti-Report", Content = "Enabled - Report system blocked", Duration = 3})
		else
			WindUI:Notify({Title = "Anti-Report", Content = "Disabled", Duration = 2})
		end
	end
})


local antiCheatEnabled = false
local originalFunctions = {}
ProtectionSection:Toggle({
	Title = "Anti-Cheat Bypass", 
	Desc = "Attempt to bypass common anti-cheat systems (use at own risk)",
	Value = false, 
	Flag = "AntiCheatBypass",
	Callback = function(state)
		antiCheatEnabled = state
		if state then
			originalFunctions = {
				getfenv = getfenv,
				setfenv = setfenv,
				getconnections = getconnections,
				getscripts = getscripts,
				getloadedmodules = getloadedmodules,
				getcallingscript = getcallingscript,
				getnilinstances = getnilinstances,
				getinstances = getinstances
			}
			local function spoofEnvironment()
				if setfenv then
					local env = getfenv(2) or {}
					env.getfenv = function() return {} end
					env.setfenv = function() return true end
					env.getconnections = function() return {} end
					env.getscripts = function() return {} end
					env.getloadedmodules = function() return {} end
					env.getcallingscript = function() return nil end
					env.getnilinstances = function() return {} end
					env.getinstances = function() return {} end
					setfenv(2, env)
				end
			end
			task.spawn(function()
				while antiCheatEnabled do
					pcall(function()
						for _, obj in pairs(game:GetService("LogService"):GetLogHistory()) do
							if obj.message:lower():find("cheat") or obj.message:lower():find("hack") or 
							   obj.message:lower():find("exploit") or obj.message:lower():find("inject") then
								pcall(function() game:GetService("LogService"):ClearLogHistory() end)
							end
						end
						if getconnections then
							local connections = getconnections(game:GetService("ScriptContext").Error)
							for _, conn in pairs(connections) do
								pcall(function() conn:Disable() end)
							end
						end
						spoofEnvironment()
					end)
					task.wait(5)
				end
			end)
			WindUI:Notify({Title = "Anti-Cheat", Content = "Enabled - AC detection attempts blocked", Duration = 3})
		else
			if originalFunctions.getfenv then getfenv = originalFunctions.getfenv end
			if originalFunctions.setfenv then setfenv = originalFunctions.setfenv end
			if originalFunctions.getconnections then getconnections = originalFunctions.getconnections end
			if originalFunctions.getscripts then getscripts = originalFunctions.getscripts end
			WindUI:Notify({Title = "Anti-Cheat", Content = "Disabled", Duration = 2})
		end
	end
})

-- More Settings
local MoreSettings = SettingsTab:Section{
	Title = "More Settings", Desc = "Additional Options",
	Icon = "separator-vertical", Box = true, BoxBorder = true, Opened = false
}

local DeltaLine = MoreSettings:Toggle({
	Title = "Hide Delta Line", Desc = "Hide the vertical line on the sidebar",
	Value = false, Flag = "HideDeltaLine", Locked = true, LockedTitle = "Delta Only",
	Callback = function(state)
		SetG("HideDeltaLine", state)
		Utils.Disconnect("HideDeltaLine")
		if state then
			local c = gethui or (syn and syn.get_hidden_gui) or nil
			if not c then return end
			local function applyHideDeltaLine()
				pcall(function()
					for _, v in ipairs(c():GetChildren()) do
						local sidebar = v:FindFirstChild("Sidebar")
						if sidebar and sidebar:IsA("GuiObject") then
							local x = sidebar.Position.X.Scale
							if x >= 1.07 then
								local yScale = sidebar.Position.Y.Scale
								local yOffset = sidebar.Position.Y.Offset
								sidebar.Position = UDim2.new(1.1, 0, yScale, yOffset)
							end
						end
					end
				end)
			end
			applyHideDeltaLine()
			Utils.StartThread("HideDeltaLine", function()
				while GetG("HideDeltaLine") do applyHideDeltaLine(); task.wait(0.5) end
			end)
			WindUI:Notify({Title = "Hide Delta Line", Content = "Enabled", Duration = 2})
		else
			WindUI:Notify({Title = "Hide Delta Line", Content = "Disabled", Duration = 2})
		end
	end
})

local FixDeltaLine = MoreSettings:Button({
	Title = "Fix Sidebar Position", Desc = "Fix sidebar position if it's misaligned",
	Icon = "wrench", Locked = true, LockedTitle = "Delta Only",
	Callback = function()
		pcall(function()
			local c = gethui or (syn and syn.get_hidden_gui) or nil
			if not c then return end
			for _, v in ipairs(c():GetChildren()) do
				local sidebar = v:FindFirstChild("Sidebar")
				if sidebar and sidebar:IsA("GuiObject") then
					local x = sidebar.Position.X.Scale
					local yScale = sidebar.Position.Y.Scale
					local yOffset = sidebar.Position.Y.Offset
					sidebar.Position = UDim2.new(1, 0, yScale, yOffset)
				end
			end
		end)
		WindUI:Notify({Title = "Sidebar", Content = "Position fixed", Duration = 2})
	end
})

MoreSettings:Button({
	Title = "Remote Spy Real Name", Desc = "use when RSPY Results Name like a shit", Icon = "wrench",
	Callback = function()
		for _, v in (getgc(true)) do
			if (typeof(v) == "table") then
				if (rawget(v, "Remote")) then
					if (v.Remote.Name == "") or (v.Remote.Name ~= v.Name) then v.Remote.Name = v.Name end
				end
			end
		end
	end
})

task.spawn(function()
	local executorName = (identifyexecutor and identifyexecutor() or getexecutorname and getexecutorname() or executor or "Unknown")
	if executorName == "Delta" then DeltaLine:Unlock(); FixDeltaLine:Unlock() end
end)

-- Utility Section
local UtilitySection = SettingsTab:Section({
	Title = "Rejoin & Server Hop", Icon = "server",
	Box = true, BoxBorder = true, Opened = false
})

SettingsTab:Button({
	Title = "Rejoin Server", Desc = "Rejoin current server", Icon = "refresh-cw",
	Callback = function() TeleportService:Teleport(game.PlaceId, LocalPlayer) end
})

SettingsTab:Button({
	Title = "Server Hop", Desc = "Join a random server", Icon = "shuffle",
	Callback = function()
		local servers = HttpService:JSONDecode(game:HttpGet("https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Desc&limit=100"))
		for _, server in ipairs(servers.data) do
			if server.playing < server.maxPlayers and server.id ~= game.JobId then
				TeleportService:TeleportToPlaceInstance(game.PlaceId, server.id, LocalPlayer)
				break
			end
		end
	end
})

Window:OnDestroy(function()
	Utils.Disconnect("HitboxRenderStepped")
	Utils.Disconnect("HitboxStepped")
	ResetAllHitboxes()
end)