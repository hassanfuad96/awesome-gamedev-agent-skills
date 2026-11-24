--!nonstrict
-- The Reef Restoration character outfits (concept art 1-npc-character.png), built from parts
-- welded onto a character's limbs, so they fit any avatar: R15 or R6, any body scale (every
-- piece is sized and placed relative to the limb it's on).
--   explorerBlue / explorerPink   the players' diving suits: black with blue or pink accents,
--                                 an oxygen tank, goggles on the forehead, a coral emblem,
--                                 belt and harness, and flippers
--   shopkeeper                    tan shirt, navy apron with the coral emblem, straw sun hat
--   guide                         blue polo, khaki shorts, a blue cap, lanyard badge, pouch
--   masterdiver                   black suit with glowing cyan trim, gold-banded tank, a full
--                                 helmet with a glowing visor and gold ear cups
--   scientist                     white lab coat over navy, glasses, a glowing tablet
--   explorer                      khaki shirt and shorts, safari hat, binoculars, backpack
-- Outfits.dress(character, id) dresses a character (players and NPCs alike); dressing again
-- replaces the old outfit. Every piece is massless, non-colliding and never takes clicks.

local Outfits = {}

local PIECE_TAG = "OutfitPiece" -- an attribute on every piece, so a re-dress can clear them

export type Style = {
	suit: Color3, -- torso
	sleeves: Color3?, -- arms (default: suit)
	legs: Color3?, -- upper legs and hips (default: suit)
	shins: Color3?, -- lower legs (default: legs)
	skin: Color3?, -- for NPCs: head and hands
	accent: Color3?,
}

local BLACK = Color3.fromRGB(28, 30, 38)
local SKIN_NPC = {
	Coralie = Color3.fromRGB(241, 194, 158),
	Kai = Color3.fromRGB(205, 150, 110),
	Mako = Color3.fromRGB(160, 110, 80),
	Pearl = Color3.fromRGB(245, 205, 175),
	Marlo = Color3.fromRGB(226, 172, 130),
}
Outfits.SKIN = SKIN_NPC

-- The parts of a character, R15 first, falling back to R6.
local function limbs(character: Model): { [string]: BasePart? }
	local function find(...: string): BasePart?
		for _, name in { ... } do
			local p = character:FindFirstChild(name)
			if p and p:IsA("BasePart") then
				return p
			end
		end
		return nil
	end
	return {
		head = find("Head"),
		torso = find("UpperTorso", "Torso"),
		hips = find("LowerTorso", "Torso"),
		leftUpperArm = find("LeftUpperArm", "Left Arm"),
		rightUpperArm = find("RightUpperArm", "Right Arm"),
		leftLowerArm = find("LeftLowerArm", "Left Arm"),
		rightLowerArm = find("RightLowerArm", "Right Arm"),
		leftHand = find("LeftHand", "Left Arm"),
		rightHand = find("RightHand", "Right Arm"),
		leftUpperLeg = find("LeftUpperLeg", "Left Leg"),
		rightUpperLeg = find("RightUpperLeg", "Right Leg"),
		leftLowerLeg = find("LeftLowerLeg", "Left Leg"),
		rightLowerLeg = find("RightLowerLeg", "Right Leg"),
		leftFoot = find("LeftFoot", "Left Leg"),
		rightFoot = find("RightFoot", "Right Leg"),
	}
end

-- Welds a piece onto `limb`. `size` and `offset` are in multiples of the limb's size (so a
-- piece at (0, 0.5, 0) sits on the limb's top face whatever the avatar's scale); `pad` adds
-- studs to the size, for things that wrap round a limb.
type PieceOptions = { shape: Enum.PartType?, material: Enum.Material?, transparency: number?, pad: Vector3?, rotation: CFrame?, absolute: boolean? }
local function piece(limb: BasePart?, name: string, size: Vector3, offset: Vector3, color: Color3, o: PieceOptions?): Part?
	if not limb then
		return nil
	end
	local options = o or {}
	local s = limb.Size
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = options.shape or Enum.PartType.Block
	p.Size = (if options.absolute then size else size * s) + (options.pad or Vector3.zero)
	p.Color = color
	p.Material = options.material or Enum.Material.SmoothPlastic
	p.Transparency = options.transparency or 0
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = false
	p.CFrame = limb.CFrame * CFrame.new(offset * s) * (options.rotation or CFrame.identity)
	p:SetAttribute(PIECE_TAG, true)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = limb
	weld.Part1 = p
	weld.Parent = p
	p.Parent = limb
	return p
end

local UPRIGHT = CFrame.Angles(0, 0, math.rad(90)) -- cylinders run along X
local ALONG_Z = CFrame.Angles(0, math.rad(90), 0)
local BALL = Enum.PartType.Ball
local CYL = Enum.PartType.Cylinder
local NEON = Enum.Material.Neon

local function setColor(part: BasePart?, color: Color3)
	if part then
		part.Color = color
	end
end

-- Body colours, set on the parts and on BodyColors (so the avatar loader can't undo them).
local function paint(character: Model, L: { [string]: BasePart? }, style: Style)
	local sleeves = style.sleeves or style.suit
	local legs = style.legs or style.suit
	local shins = style.shins or legs
	local skin = style.skin or (L.head and L.head.Color) or Color3.fromRGB(240, 200, 160)
	local isR15 = character:FindFirstChild("UpperTorso") ~= nil
	setColor(L.torso, style.suit)
	setColor(L.hips, legs)
	for _, side in { "left", "right" } do
		setColor(L[side .. "UpperArm"], sleeves)
		if isR15 then
			setColor(L[side .. "LowerArm"], sleeves)
			setColor(L[side .. "Hand"], skin)
			setColor(L[side .. "LowerLeg"], shins)
			setColor(L[side .. "Foot"], shins)
		end
		setColor(L[side .. "UpperLeg"], legs)
	end
	if style.skin then
		setColor(L.head, style.skin)
	end
	local bodyColors = character:FindFirstChildOfClass("BodyColors")
	if bodyColors then
		bodyColors.TorsoColor3 = style.suit
		bodyColors.LeftArmColor3 = sleeves
		bodyColors.RightArmColor3 = sleeves
		bodyColors.LeftLegColor3 = legs
		bodyColors.RightLegColor3 = legs
		if style.skin then
			bodyColors.HeadColor3 = style.skin
		end
	end
end

-- Takes off what would clash with an outfit: classic clothing, and layered clothing and back
-- accessories (the oxygen tank goes there). Hair, hats and faces stay.
local CLOTHING_TYPES = {
	[Enum.AccessoryType.Back] = true,
	[Enum.AccessoryType.Jacket] = true,
	[Enum.AccessoryType.Sweater] = true,
	[Enum.AccessoryType.Shirt] = true,
	[Enum.AccessoryType.TShirt] = true,
	[Enum.AccessoryType.Pants] = true,
	[Enum.AccessoryType.Shorts] = true,
	[Enum.AccessoryType.DressSkirt] = true,
	[Enum.AccessoryType.LeftShoe] = true,
	[Enum.AccessoryType.RightShoe] = true,
	[Enum.AccessoryType.Waist] = true,
}
local function undress(character: Model)
	for _, child in character:GetChildren() do
		if child:IsA("Shirt") or child:IsA("Pants") or child:IsA("ShirtGraphic") then
			child:Destroy()
		elseif child:IsA("Accessory") and CLOTHING_TYPES[child.AccessoryType] then
			child:Destroy()
		end
	end
	for _, d in character:GetDescendants() do
		if d:IsA("BasePart") and d:GetAttribute(PIECE_TAG) then
			d:Destroy()
		end
	end
end

-- Removes hats and hair too (for outfits with a helmet, or NPCs with their own hair).
local function removeHeadwear(character: Model)
	for _, child in character:GetChildren() do
		if child:IsA("Accessory") then
			child:Destroy()
		end
	end
end

---------------------------------------------------------------------------------------------
-- Shared kit

-- The coral emblem from the art: a little glowing branching coral on the chest.
local function emblem(torso: BasePart?, color: Color3, at: Vector3?)
	local c = at or Vector3.new(0, 0.12, -0.5)
	piece(torso, "EmblemStem", Vector3.new(0.05, 0.28, 0.02), c + Vector3.new(0, -0.04, -0.02), color, { material = NEON })
	for _, side in { -1, 1 } do
		piece(torso, "EmblemBranch", Vector3.new(0.04, 0.2, 0.02), c + Vector3.new(side * 0.07, 0.06, -0.02), color, { material = NEON, rotation = CFrame.Angles(0, 0, side * -0.6) })
	end
end

-- A belt round the hips with a buckle (and, on dive suits, the harness's waist clips).
local function belt(hips: BasePart?, color: Color3, buckle: Color3)
	piece(hips, "Belt", Vector3.new(1, 0.28, 1), Vector3.new(0, 0.25, 0), color, { pad = Vector3.new(0.08, 0, 0.08) })
	piece(hips, "Buckle", Vector3.new(0.22, 0.24, 0.05), Vector3.new(0, 0.25, -0.52), buckle, { material = Enum.Material.Metal })
end

-- An oxygen tank on the back with its valve and a band in the accent colour.
local function tank(torso: BasePart?, body: Color3, band: Color3)
	if not torso then
		return
	end
	local s = torso.Size
	local height = s.Y * 1.35
	local radius = s.X * 0.2
	local at = Vector3.new(0, -0.05, 0.5) + Vector3.new(0, 0, radius / s.Z + 0.02)
	piece(torso, "Tank", Vector3.new(height, radius * 2, radius * 2), at, body, { absolute = true, shape = CYL, material = Enum.Material.Metal, rotation = UPRIGHT })
	piece(torso, "TankBand", Vector3.new(0.12, radius * 2.06, radius * 2.06), at + Vector3.new(0, 0.18, 0), band, { absolute = true, shape = CYL, rotation = UPRIGHT })
	piece(torso, "TankBand", Vector3.new(0.12, radius * 2.06, radius * 2.06), at + Vector3.new(0, -0.3, 0), band, { absolute = true, shape = CYL, rotation = UPRIGHT })
	piece(torso, "TankValve", Vector3.new(0.3, radius * 0.9, radius * 0.9), at + Vector3.new(0, height / s.Y / 2 + 0.06, 0), Color3.fromRGB(60, 62, 70), { absolute = true, shape = CYL, material = Enum.Material.Metal, rotation = UPRIGHT })
end

-- Shoulder straps of the harness, crossing the chest.
local function harness(torso: BasePart?, color: Color3)
	for _, side in { -1, 1 } do
		piece(torso, "Strap", Vector3.new(0.14, 1, 0.04), Vector3.new(side * 0.26, 0, -0.51), color)
		piece(torso, "StrapBack", Vector3.new(0.14, 1, 0.04), Vector3.new(side * 0.26, 0, 0.51), color)
	end
	piece(torso, "ChestClip", Vector3.new(0.6, 0.08, 0.04), Vector3.new(0, -0.25, -0.53), color)
end

-- Dive goggles pushed up on the forehead, with the strap round the head.
local function goggles(head: BasePart?, frame: Color3, lens: Color3)
	piece(head, "GoggleStrap", Vector3.new(1, 0.16, 1), Vector3.new(0, 0.28, 0), frame, { pad = Vector3.new(0.06, 0, 0.06) })
	for _, side in { -1, 1 } do
		piece(head, "GoggleFrame", Vector3.new(0.4, 0.3, 0.1), Vector3.new(side * 0.21, 0.3, -0.53), frame)
		piece(head, "GoggleLens", Vector3.new(0.3, 0.2, 0.05), Vector3.new(side * 0.21, 0.3, -0.58), lens, { material = Enum.Material.Glass, transparency = 0.15 })
	end
end

-- Flippers: a long flat fin off the front of each foot, in the accent colour.
local function flippers(L: { [string]: BasePart? }, color: Color3)
	for _, side in { "left", "right" } do
		local foot = L[side .. "Foot"]
		if foot then
			local r6 = foot.Name:find(" ") ~= nil -- an R6 leg: the foot is its bottom
			local base = if r6 then Vector3.new(0, -0.48, 0) else Vector3.new(0, -0.35, 0)
			piece(foot, "Flipper", Vector3.new(1.1, 0.12, 1.9), base + Vector3.new(0, 0, if r6 then -0.6 else -0.55), color, { pad = Vector3.new(0, 0.05, 0) })
			piece(foot, "FlipperStrap", Vector3.new(1.05, if r6 then 0.12 else 0.4, 1.05), base + Vector3.new(0, if r6 then 0.06 else 0.2, 0), color)
		end
	end
end

-- Accent bands: cuffs at the wrists and ankles and stripes down the suit's sides.
local function bands(L: { [string]: BasePart? }, color: Color3, glow: boolean?)
	local material = if glow then NEON else Enum.Material.SmoothPlastic
	for _, side in { "left", "right" } do
		local sign = if side == "left" then -1 else 1
		piece(L[side .. "LowerArm"], "Cuff", Vector3.new(1, 0.18, 1), Vector3.new(0, -0.38, 0), color, { pad = Vector3.new(0.05, 0, 0.05), material = material })
		piece(L[side .. "UpperArm"], "ArmStripe", Vector3.new(0.08, 1, 0.3), Vector3.new(sign * 0.5, 0, 0), color, { material = material })
		piece(L[side .. "UpperLeg"], "LegStripe", Vector3.new(0.08, 1, 0.35), Vector3.new(sign * 0.5, 0, 0), color, { material = material })
		piece(L[side .. "LowerLeg"], "KneeBand", Vector3.new(1, 0.14, 1), Vector3.new(0, 0.32, 0), color, { pad = Vector3.new(0.05, 0, 0.05), material = material })
	end
	piece(L.torso, "SideStripe", Vector3.new(0.06, 1, 0.5), Vector3.new(-0.5, 0, 0), color, { material = material })
	piece(L.torso, "SideStripe", Vector3.new(0.06, 1, 0.5), Vector3.new(0.5, 0, 0), color, { material = material })
end

-- A block of hair over the top and back of the head, with a fringe (NPCs).
local function hair(head: BasePart?, color: Color3, long: boolean?)
	piece(head, "Hair", Vector3.new(1.06, 0.45, 1.06), Vector3.new(0, 0.32, 0.03), color, { material = Enum.Material.SmoothPlastic })
	piece(head, "HairBack", Vector3.new(1.06, if long then 1.1 else 0.6, 0.25), Vector3.new(0, if long then -0.15 else 0.1, 0.45), color)
	piece(head, "Fringe", Vector3.new(0.9, 0.2, 0.12), Vector3.new(0.05, 0.38, -0.5), color, { rotation = CFrame.Angles(0, 0, -0.12) })
end

local function boots(L: { [string]: BasePart? }, color: Color3)
	for _, side in { "left", "right" } do
		local foot = L[side .. "Foot"]
		if foot and not foot.Name:find(" ") then
			piece(foot, "Boot", Vector3.new(1, 1, 1), Vector3.new(0, 0, -0.05), color, { pad = Vector3.new(0.08, 0.08, 0.15) })
		elseif foot then
			piece(foot, "Boot", Vector3.new(1, 0.3, 1.05), Vector3.new(0, -0.36, -0.03), color, { pad = Vector3.new(0.06, 0, 0) })
		end
	end
end

---------------------------------------------------------------------------------------------
-- The outfits

local function diveSuit(character: Model, L, accent: Color3)
	paint(character, L, { suit = BLACK, accent = accent })
	bands(L, accent)
	harness(L.torso, Color3.fromRGB(40, 42, 50))
	belt(L.hips, Color3.fromRGB(40, 42, 50), accent)
	for _, x in { -0.3, 0.3 } do
		piece(L.hips, "BeltClip", Vector3.new(0.16, 0.2, 0.05), Vector3.new(x, 0.25, -0.53), accent)
	end
	emblem(L.torso, Color3.fromRGB(120, 230, 240))
	tank(L.torso, Color3.fromRGB(196, 200, 210), accent)
	goggles(L.head, accent:Lerp(Color3.new(0, 0, 0), 0.25), Color3.fromRGB(120, 210, 255))
	flippers(L, accent)
end

local builders: { [string]: (Model, { [string]: BasePart? }) -> () } = {
	explorerBlue = function(character, L)
		diveSuit(character, L, Color3.fromRGB(40, 150, 255))
	end,
	explorerPink = function(character, L)
		diveSuit(character, L, Color3.fromRGB(235, 70, 200))
	end,

	-- The Shopkeeper: tan shirt, navy apron with the emblem, a straw sun hat.
	shopkeeper = function(character, L)
		removeHeadwear(character)
		paint(character, L, { suit = Color3.fromRGB(214, 184, 134), legs = Color3.fromRGB(70, 60, 54), skin = SKIN_NPC.Coralie })
		hair(L.head, Color3.fromRGB(120, 70, 40), true)
		piece(L.torso, "Apron", Vector3.new(0.82, 0.9, 0.04), Vector3.new(0, -0.05, -0.52), Color3.fromRGB(40, 60, 120))
		piece(L.hips, "ApronSkirt", Vector3.new(0.86, 1.2, 0.04), Vector3.new(0, -0.3, -0.52), Color3.fromRGB(40, 60, 120))
		emblem(L.hips, Color3.fromRGB(150, 220, 255), Vector3.new(0, -0.25, -0.54))
		piece(L.torso, "ApronStrap", Vector3.new(1, 0.08, 1), Vector3.new(0, -0.3, 0), Color3.fromRGB(40, 60, 120), { pad = Vector3.new(0.05, 0, 0.05) })
		local straw = Color3.fromRGB(232, 206, 140)
		piece(L.head, "HatBrim", Vector3.new(0.12, 2.1, 2.1), Vector3.new(0, 0.55, 0), straw, { shape = CYL, rotation = UPRIGHT })
		piece(L.head, "HatCrown", Vector3.new(1.05, 0.5, 1.05), Vector3.new(0, 0.78, 0), straw)
		piece(L.head, "HatBand", Vector3.new(1.08, 0.14, 1.08), Vector3.new(0, 0.62, 0), Color3.fromRGB(40, 60, 120))
		boots(L, Color3.fromRGB(90, 62, 40))
	end,

	-- The Guide: blue polo, khaki shorts, blue cap with the emblem, lanyard badge, a pouch.
	guide = function(character, L)
		removeHeadwear(character)
		paint(character, L, { suit = Color3.fromRGB(30, 110, 230), sleeves = Color3.fromRGB(30, 110, 230), legs = Color3.fromRGB(196, 170, 126), shins = SKIN_NPC.Kai, skin = SKIN_NPC.Kai })
		hair(L.head, Color3.fromRGB(30, 26, 30))
		for _, side in { "left", "right" } do
			piece(L[side .. "LowerArm"], "Skin", Vector3.new(1, 1, 1), Vector3.zero, SKIN_NPC.Kai, { pad = Vector3.new(0.02, 0, 0.02) })
		end
		piece(L.torso, "Collar", Vector3.new(0.55, 0.14, 0.12), Vector3.new(0, 0.45, -0.5), Color3.fromRGB(20, 80, 190))
		piece(L.torso, "Lanyard", Vector3.new(0.05, 0.5, 0.03), Vector3.new(0.1, 0.2, -0.53), Color3.fromRGB(20, 40, 90))
		piece(L.torso, "Badge", Vector3.new(0.22, 0.3, 0.04), Vector3.new(0.1, -0.12, -0.55), Color3.fromRGB(245, 245, 245))
		emblem(L.torso, Color3.fromRGB(255, 255, 255), Vector3.new(-0.22, 0.2, -0.5))
		belt(L.hips, Color3.fromRGB(80, 54, 36), Color3.fromRGB(200, 200, 210))
		piece(L.hips, "Pouch", Vector3.new(0.25, 0.4, 0.3), Vector3.new(0.45, 0.05, -0.2), Color3.fromRGB(70, 52, 38))
		local blue = Color3.fromRGB(30, 100, 220)
		piece(L.head, "Cap", Vector3.new(1.08, 0.4, 1.08), Vector3.new(0, 0.5, 0), blue, { shape = BALL })
		piece(L.head, "CapBase", Vector3.new(1.08, 0.18, 1.08), Vector3.new(0, 0.43, 0), blue)
		piece(L.head, "CapBill", Vector3.new(0.9, 0.06, 0.55), Vector3.new(0, 0.38, -0.72), blue)
		emblem(L.head, Color3.fromRGB(255, 255, 255), Vector3.new(0, 0.6, -0.55))
		boots(L, Color3.fromRGB(70, 52, 38))
	end,

	-- The Master Diver: black suit with glowing cyan trim, a gold-banded tank, and a full helmet
	-- with a glowing visor and gold ear cups.
	masterdiver = function(character, L)
		removeHeadwear(character)
		local cyan = Color3.fromRGB(60, 220, 255)
		local gold = Color3.fromRGB(230, 180, 70)
		paint(character, L, { suit = Color3.fromRGB(20, 24, 40), skin = SKIN_NPC.Mako })
		bands(L, cyan, true)
		harness(L.torso, gold)
		belt(L.hips, Color3.fromRGB(30, 30, 40), gold)
		emblem(L.torso, gold)
		tank(L.torso, Color3.fromRGB(200, 204, 214), gold)
		piece(L.head, "Helmet", Vector3.new(1.35, 1.35, 1.35), Vector3.new(0, 0.05, 0), Color3.fromRGB(26, 30, 50), { shape = BALL })
		piece(L.head, "Visor", Vector3.new(1.05, 0.55, 0.3), Vector3.new(0, 0.1, -0.55), Color3.fromRGB(70, 200, 255), { material = Enum.Material.Glass, transparency = 0.1 })
		piece(L.head, "VisorGlow", Vector3.new(0.95, 0.06, 0.1), Vector3.new(0, -0.18, -0.65), cyan, { material = NEON })
		for _, side in { -1, 1 } do
			piece(L.head, "EarCup", Vector3.new(0.18, 0.5, 0.5), Vector3.new(side * 0.68, 0.05, 0), gold, { shape = CYL, material = Enum.Material.Metal })
		end
		piece(L.head, "HelmetRidge", Vector3.new(0.18, 0.2, 1.1), Vector3.new(0, 0.66, 0), gold, { material = Enum.Material.Metal })
		flippers(L, cyan)
	end,

	-- The Research Scientist: white lab coat over navy, glasses, a glowing tablet in one hand.
	scientist = function(character, L)
		removeHeadwear(character)
		local navy, coat = Color3.fromRGB(36, 46, 86), Color3.fromRGB(236, 240, 244)
		paint(character, L, { suit = navy, sleeves = coat, legs = Color3.fromRGB(30, 36, 66), skin = SKIN_NPC.Pearl })
		hair(L.head, Color3.fromRGB(26, 24, 34))
		for _, side in { -1, 1 } do
			piece(L.torso, "CoatPanel", Vector3.new(0.36, 1.02, 1.04), Vector3.new(side * 0.33, 0, 0), coat)
			piece(L.hips, "CoatTail", Vector3.new(0.5, 1.6, 0.05), Vector3.new(side * 0.27, -0.5, -0.53), coat)
			piece(L.torso, "Lapel", Vector3.new(0.14, 0.5, 0.04), Vector3.new(side * 0.15, 0.25, -0.53), coat:Lerp(Color3.new(0, 0, 0), 0.08), { rotation = CFrame.Angles(0, 0, side * 0.35) })
		end
		piece(L.hips, "CoatBack", Vector3.new(1.05, 1.6, 0.05), Vector3.new(0, -0.5, 0.53), coat)
		emblem(L.torso, Color3.fromRGB(110, 200, 255))
		for _, side in { -1, 1 } do
			piece(L.head, "GlassesRim", Vector3.new(0.32, 0.26, 0.05), Vector3.new(side * 0.2, 0.08, -0.56), Color3.fromRGB(20, 20, 24))
			piece(L.head, "GlassesLens", Vector3.new(0.24, 0.18, 0.03), Vector3.new(side * 0.2, 0.08, -0.58), Color3.fromRGB(200, 230, 255), { material = Enum.Material.Glass, transparency = 0.4 })
		end
		piece(L.head, "GlassesBridge", Vector3.new(0.12, 0.05, 0.04), Vector3.new(0, 0.1, -0.57), Color3.fromRGB(20, 20, 24))
		local tablet = piece(L.leftHand, "Tablet", Vector3.new(0.08, 1.3, 1.6), Vector3.new(0.55, 0, -0.6), Color3.fromRGB(30, 40, 60), { rotation = CFrame.Angles(0.3, 0, 0) })
		if tablet then
			piece(tablet, "Screen", Vector3.new(1.2, 1, 0.8), Vector3.new(-0.6, 0, 0), Color3.fromRGB(80, 200, 255), { material = NEON })
		end
		boots(L, Color3.fromRGB(30, 30, 34))
	end,

	-- The Explorer NPC: khaki shirt and shorts, a safari hat, binoculars, and a backpack.
	explorer = function(character, L)
		removeHeadwear(character)
		local khaki = Color3.fromRGB(196, 172, 120)
		paint(character, L, { suit = khaki, legs = khaki:Lerp(Color3.new(0, 0, 0), 0.12), shins = SKIN_NPC.Marlo, skin = SKIN_NPC.Marlo })
		hair(L.head, Color3.fromRGB(90, 56, 30))
		for _, side in { -1, 1 } do
			piece(L.torso, "Pocket", Vector3.new(0.26, 0.25, 0.04), Vector3.new(side * 0.25, 0.15, -0.52), khaki:Lerp(Color3.new(0, 0, 0), 0.15))
		end
		belt(L.hips, Color3.fromRGB(90, 60, 36), Color3.fromRGB(200, 170, 90))
		piece(L.torso, "Backpack", Vector3.new(0.8, 0.85, 0.45), Vector3.new(0, -0.02, 0.72), Color3.fromRGB(110, 90, 60))
		piece(L.torso, "Strap", Vector3.new(0.06, 1.1, 0.03), Vector3.new(0.12, 0.05, -0.53), Color3.fromRGB(60, 44, 30), { rotation = CFrame.Angles(0, 0, -0.6) })
		for _, x in { -0.1, 0.1 } do
			piece(L.torso, "Binoculars", Vector3.new(0.3, 0.12, 0.12), Vector3.new(x, -0.22, -0.62), Color3.fromRGB(40, 40, 44), { absolute = false, shape = CYL, rotation = CFrame.Angles(0, math.rad(90), math.rad(90)) })
		end
		local hat = Color3.fromRGB(184, 156, 104)
		piece(L.head, "HatBrim", Vector3.new(0.1, 1.9, 1.9), Vector3.new(0, 0.5, 0), hat, { shape = CYL, rotation = UPRIGHT })
		piece(L.head, "HatCrown", Vector3.new(1, 0.55, 1), Vector3.new(0, 0.75, 0), hat, { shape = BALL })
		piece(L.head, "HatBand", Vector3.new(1.02, 0.12, 1.02), Vector3.new(0, 0.6, 0), Color3.fromRGB(90, 60, 36))
		emblem(L.head, Color3.fromRGB(80, 160, 230), Vector3.new(0, 0.72, -0.5))
		boots(L, Color3.fromRGB(90, 62, 40))
	end,
}

Outfits.IDS = {}
for id in builders do
	table.insert(Outfits.IDS, id)
end

function Outfits.exists(id: string): boolean
	return builders[id] ~= nil
end

-- Dresses `character` in outfit `id` (replacing any outfit it had). Pieces are welded, so the
-- character must be in its resting pose: call it on spawn, before animations move limbs much.
function Outfits.dress(character: Model, id: string)
	local build = builders[id]
	if not build then
		return
	end
	undress(character)
	build(character, limbs(character))
	character:SetAttribute("Outfit", id)
end

-- Takes an outfit off again (back to the player's own clothes on their next spawn).
function Outfits.strip(character: Model)
	for _, d in character:GetDescendants() do
		if d:IsA("BasePart") and d:GetAttribute(PIECE_TAG) then
			d:Destroy()
		end
	end
	character:SetAttribute("Outfit", nil)
end

return Outfits
