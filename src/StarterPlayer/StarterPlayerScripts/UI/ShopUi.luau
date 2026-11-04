-- 코인 상점 화면 (GDD 9.4): 궤적·부츠 탭, 색 미리보기 카드, 구매·장착. 판단은 서버 ShopService가 한다.
-- 허브 상점 가판대의 프롬프트(Shop 속성)나 B 키로 연다
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Collectibles = require(ReplicatedStorage.Config.Collectibles)
local Shop = require(ReplicatedStorage.Config.Shop)
local CollectibleLogic = require(ReplicatedStorage.Shared.CollectibleLogic)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Strings = require(ReplicatedStorage.Shared.Strings)

local player = Players.LocalPlayer

local COLOR = {
	Panel = Color3.fromRGB(24, 34, 58),
	Card = Color3.fromRGB(40, 54, 88),
	Preview = Color3.fromRGB(70, 110, 170),
	Text = Color3.fromRGB(255, 255, 255),
	Soft = Color3.fromRGB(200, 214, 240),
	Gold = Color3.fromRGB(255, 205, 60),
	Buy = Color3.fromRGB(240, 170, 50),
	Equip = Color3.fromRGB(96, 186, 120),
	Equipped = Color3.fromRGB(90, 150, 230),
	Locked = Color3.fromRGB(96, 104, 126),
	Tab = Color3.fromRGB(52, 66, 100),
	Fail = Color3.fromRGB(255, 150, 150),
}
local STATUS_SECONDS = 3

local ShopUi = {}

local gui: ScreenGui
local frame: Frame
local coinsLabel: TextLabel
local grid: ScrollingFrame
local gridLayout: UIGridLayout
local statusLabel: TextLabel
local tabButtons: { [string]: TextButton } = {}
local cards: { { item: any, button: TextButton } } = {}
local currentTab = Shop.Categories[1]
local busy = false
local statusToken = 0
local buyRemote: RemoteFunction
local equipRemote: RemoteFunction

local function t(key: string, ...: any): string
	return Strings.get(player.LocaleId, key, ...)
end

local function decode(name: string): { [string]: any }
	local raw = player:GetAttribute(name)
	if type(raw) ~= "string" then
		return {}
	end
	local ok, value = pcall(HttpService.JSONDecode, HttpService, raw)
	return if ok and type(value) == "table" then value else {}
end

local function coins(): number
	local value = player:GetAttribute("Coins")
	return if type(value) == "number" then value else 0
end

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

local function rounded(inst: GuiObject, radius: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = inst
end

local function box(parent: Instance, color: Color3, size: UDim2, position: UDim2, radius: number?): Frame
	local f = Instance.new("Frame")
	f.BackgroundColor3 = color
	f.BorderSizePixel = 0
	f.Size = size
	f.Position = position
	if radius then
		rounded(f, radius)
	end
	f.Parent = parent
	return f
end

local function text(parent: Instance, props: { [string]: any }): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextColor3 = COLOR.Text
	label.TextWrapped = true
	for key, value in props do
		(label :: any)[key] = value
	end
	label.Parent = parent
	return label
end

local function button(parent: Instance, color: Color3): TextButton
	local b = Instance.new("TextButton")
	b.BackgroundColor3 = color
	b.Font = Enum.Font.FredokaOne
	b.TextColor3 = COLOR.Text
	b.TextSize = 17
	b.AutoButtonColor = true
	rounded(b, 10)
	b.Parent = parent
	return b
end

local function status(message: string, color: Color3)
	statusToken += 1
	local token = statusToken
	statusLabel.Text = message
	statusLabel.TextColor3 = color
	task.delay(STATUS_SECONDS, function()
		if token == statusToken then
			statusLabel.Text = t("ShopNote")
			statusLabel.TextColor3 = COLOR.Soft
		end
	end)
end

-- 미리보기: 궤적은 색이 이어지는 띠, 부츠는 작은 부츠 한 켤레
local function trailPreview(parent: Instance, item)
	local band = box(parent, Color3.new(1, 1, 1), UDim2.new(1, -24, 0, 22), UDim2.new(0, 12, 0.5, -11), 11)
	local keys = {}
	for i, c in item.colors do
		table.insert(keys, ColorSequenceKeypoint.new((i - 1) / (#item.colors - 1), rgb(c)))
	end
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(keys)
	gradient.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 0.6) })
	gradient.Parent = band
end

local function bootsPreview(parent: Instance, item)
	for _, x in { -18, 6 } do
		local left = UDim.new(0.5, x)
		box(parent, rgb(item.body), UDim2.fromOffset(18, 24), UDim2.new(left, UDim.new(0.5, -16)), 4)
		box(parent, rgb(item.accent), UDim2.fromOffset(20, 5), UDim2.new(left - UDim.new(0, 1), UDim.new(0.5, -18)), 2)
		box(parent, rgb(item.sole), UDim2.fromOffset(24, 6), UDim2.new(left - UDim.new(0, 2), UDim.new(0.5, 8)), 3)
	end
end

local function refresh()
	if not gui.Enabled then
		return
	end
	coinsLabel.Text = t("ShopCoins", coins())
	local owned, equipped, balance = decode("ShopOwned"), decode("ShopEquipped"), coins()
	for _, card in cards do
		local item = card.item
		if equipped[item.category] == item.id then
			card.button.Text = t("ShopEquipped")
			card.button.BackgroundColor3 = COLOR.Equipped
		elseif owned[item.id] then
			card.button.Text = t("ShopEquip")
			card.button.BackgroundColor3 = COLOR.Equip
		elseif item.unlock then
			-- 팔지 않는 물건: 그 섬의 별조각을 몇 개 찾았는지
			local found, total = CollectibleLogic.islandProgress(Collectibles, item.unlock, decode("Shards"))
			card.button.Text = t("ShopShardCount", found, total)
			card.button.BackgroundColor3 = COLOR.Locked
		else
			card.button.Text = t("ShopBuy", item.price)
			card.button.BackgroundColor3 = if balance >= item.price then COLOR.Buy else COLOR.Locked
		end
	end
	for category, tab in tabButtons do
		tab.BackgroundColor3 = if category == currentTab then COLOR.Equipped else COLOR.Tab
	end
end

-- 안 가졌으면 사고(사면 바로 입는다), 가졌으면 입고, 입고 있으면 벗는다
local function press(item)
	if busy then
		return
	end
	local owned, equipped = decode("ShopOwned"), decode("ShopEquipped")
	if not owned[item.id] and item.unlock then
		status(t("ShopLocked", t("Island_" .. item.unlock)), COLOR.Gold)
		return
	end
	if not owned[item.id] and coins() < item.price then
		status(t("ShopNoCoins"), COLOR.Fail)
		return
	end
	busy = true
	if not owned[item.id] then
		local ok, reason = buyRemote:InvokeServer(item.id)
		if ok then
			status(t("ShopBought", t("Item_" .. item.id)), COLOR.Gold)
		elseif reason then
			status(t(reason), COLOR.Fail)
		end
	elseif equipped[item.category] == item.id then
		equipRemote:InvokeServer(item.category, nil)
	else
		equipRemote:InvokeServer(item.category, item.id)
	end
	busy = false
	refresh()
end

local function rebuild()
	for _, card in cards do
		card.button.Parent:Destroy()
	end
	table.clear(cards)
	for index, item in Shop.Items do
		if item.category ~= currentTab then
			continue
		end
		local card = box(grid, COLOR.Card, UDim2.new(), UDim2.new(), 12)
		card.Name = "Card_" .. item.id
		card.LayoutOrder = index
		local preview = box(card, COLOR.Preview, UDim2.new(1, -16, 0, 56), UDim2.fromOffset(8, 8), 10)
		if item.category == "Trail" then
			trailPreview(preview, item)
		else
			bootsPreview(preview, item)
		end
		text(card, {
			Text = t("Item_" .. item.id),
			TextSize = 15,
			Size = UDim2.new(1, -12, 0, 30),
			Position = UDim2.fromOffset(6, 66),
		})
		local b = button(card, COLOR.Buy)
		b.Name = item.id
		b.AnchorPoint = Vector2.new(0.5, 1)
		b.Position = UDim2.new(0.5, 0, 1, -8)
		b.Size = UDim2.new(1, -16, 0, 34)
		b.Activated:Connect(function()
			press(item)
		end)
		table.insert(cards, { item = item, button = b })
	end
	refresh()
end

local function layout()
	local camera = workspace.CurrentCamera
	local viewport = if camera then camera.ViewportSize else Vector2.new(1280, 720)
	local width = math.min(600, viewport.X - 24)
	frame.Size = UDim2.fromOffset(width, math.min(440, viewport.Y - 24))
	-- 좁은 화면에서는 카드를 줄여 한 줄에 둘 이상 들어가게 한다
	local narrow = width < 480
	gridLayout.CellSize = if narrow then UDim2.fromOffset(124, 140) else UDim2.fromOffset(170, 140)
end

function ShopUi.open()
	gui.Enabled = true
	layout()
	rebuild()
end

function ShopUi.close()
	gui.Enabled = false
end

function ShopUi.toggle()
	if gui.Enabled then
		ShopUi.close()
	else
		ShopUi.open()
	end
end

local function build()
	gui = Instance.new("ScreenGui")
	gui.Name = "SkyhopShop"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 6
	gui.Enabled = false
	gui.Parent = player:WaitForChild("PlayerGui")

	frame = box(gui, COLOR.Panel, UDim2.fromOffset(600, 440), UDim2.fromScale(0.5, 0.5), 16)
	frame.Name = "Panel"
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.BackgroundTransparency = 0.08

	text(frame, {
		Text = t("ShopTitle"),
		TextSize = 26,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(0.5, 0, 0, 40),
		Position = UDim2.fromOffset(16, 8),
	})
	coinsLabel = text(frame, {
		TextSize = 20,
		TextColor3 = COLOR.Gold,
		TextXAlignment = Enum.TextXAlignment.Right,
		Size = UDim2.new(0.5, -70, 0, 40),
		Position = UDim2.new(0.5, 0, 0, 8),
	})
	local close = button(frame, COLOR.Tab)
	close.Text = "X"
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -10, 0, 10)
	close.Size = UDim2.fromOffset(40, 36)
	close.Activated:Connect(ShopUi.close)

	for i, category in Shop.Categories do
		local tab = button(frame, COLOR.Tab)
		tab.Name = "Tab_" .. category
		tab.Text = t("ShopTab" .. category)
		tab.Size = UDim2.fromOffset(110, 34)
		tab.Position = UDim2.fromOffset(16 + (i - 1) * 118, 54)
		tab.Activated:Connect(function()
			currentTab = category
			rebuild()
		end)
		tabButtons[category] = tab
	end

	grid = Instance.new("ScrollingFrame")
	grid.Name = "Grid"
	grid.BackgroundTransparency = 1
	grid.BorderSizePixel = 0
	grid.Position = UDim2.fromOffset(12, 98)
	grid.Size = UDim2.new(1, -24, 1, -140)
	grid.CanvasSize = UDim2.new()
	grid.AutomaticCanvasSize = Enum.AutomaticSize.Y
	grid.ScrollingDirection = Enum.ScrollingDirection.Y
	grid.ScrollBarThickness = 6
	grid.Parent = frame
	gridLayout = Instance.new("UIGridLayout")
	gridLayout.CellPadding = UDim2.fromOffset(10, 10)
	gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
	gridLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	gridLayout.Parent = grid
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 4)
	padding.PaddingBottom = UDim.new(0, 4)
	padding.Parent = grid

	statusLabel = text(frame, {
		Text = t("ShopNote"),
		TextSize = 15,
		TextColor3 = COLOR.Soft,
		Size = UDim2.new(1, -24, 0, 34),
		Position = UDim2.new(0, 12, 1, -40),
	})
end

local function attachPrompt(inst: Instance)
	if inst:IsA("ProximityPrompt") and inst:GetAttribute("Shop") then
		inst.ActionText = t("ShopPrompt")
		inst.ObjectText = t("ShopTitle")
	end
end

function ShopUi.start()
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	buyRemote = remotes:WaitForChild(Remotes.ShopBuy) :: RemoteFunction
	equipRemote = remotes:WaitForChild(Remotes.ShopEquip) :: RemoteFunction
	build()

	for _, name in { "Coins", "ShopOwned", "ShopEquipped", "Shards" } do
		player:GetAttributeChangedSignal(name):Connect(refresh)
	end
	for _, inst in workspace:GetDescendants() do
		attachPrompt(inst)
	end
	workspace.DescendantAdded:Connect(attachPrompt)
	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		if prompt:GetAttribute("Shop") then
			ShopUi.open()
		end
	end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.B then
			ShopUi.toggle()
		end
	end)
	local camera = workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			if gui.Enabled then
				layout()
			end
		end)
	end
end

return ShopUi
