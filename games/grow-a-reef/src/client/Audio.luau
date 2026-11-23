--!nonstrict
-- Music, ambience and sound effects, on this client only (ReefSounds lists every sound).
--   Music: the playlist loops; sea events with their own music (Volcano, Octopus, Shipwreck)
--   take over while they run, and the orcas' arrival switches to chase music.
--   Effects come from what changes in this player's DataSync (planted, harvested, sold, bought,
--   hatched, placed, upgraded, rewards), from teleports, from the octopus losing health, and
--   from a few key messages (quest complete, treasure clues).
-- A small Music button (top right) turns the music off and on; effects stay.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local ReefSounds = require(ReplicatedStorage.Shared.ReefSounds)
local Ui = require(script.Parent.Ui)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local Audio = {}

local FADE = TweenInfo.new(1.5)

local folder: Folder
local music: Sound
local musicGroup: SoundGroup -- the mixer: the Music button turns this group down
local effectsGroup: SoundGroup
local musicEnabled = true
local playlistIndex = 1
local currentMusic: ReefSounds.SoundDef? = nil
local previous: any = nil

local function sound(def: ReefSounds.SoundDef, parent: Instance): Sound
	local s = Instance.new("Sound")
	s.SoundId = ReefSounds.assetId(def)
	s.Volume = def.volume or 0.5
	s.PlaybackSpeed = def.playbackSpeed or 1
	s.Parent = parent
	return s
end

-- A one-off effect, heard by this player only.
function Audio.play(name: string)
	local def = ReefSounds.effects[name]
	if not def or not folder then
		return
	end
	local s = sound(def, folder)
	s.SoundGroup = effectsGroup
	s.Ended:Once(function()
		s:Destroy()
	end)
	s:Play()
	task.delay(15, function()
		if s.Parent then
			s:Destroy()
		end
	end)
end

-- Crossfades the music to `def` (looped), unless it's already playing.
local function playMusic(def: ReefSounds.SoundDef, looped: boolean)
	if currentMusic == def then
		return
	end
	currentMusic = def
	local target = def.volume or 0.35
	local fadeOut = TweenService:Create(music, FADE, { Volume = 0 })
	fadeOut:Play()
	fadeOut.Completed:Wait()
	if currentMusic ~= def then
		return -- something else took over while fading
	end
	music.SoundId = ReefSounds.assetId(def)
	music.Looped = looped
	music.TimePosition = 0
	music:Play()
	TweenService:Create(music, FADE, { Volume = target }):Play()
end

local function playlistTrack()
	task.spawn(playMusic, ReefSounds.playlist[playlistIndex], false)
end

-- Event music while an event runs (and chase music once the orcas come), else the playlist.
local function updateMusic()
	local eventId = Workspace:GetAttribute("EventId")
	local orcasAt = Workspace:GetAttribute("OrcasAt")
	if eventId == "Shipwreck" and type(orcasAt) == "number" and Workspace:GetServerTimeNow() >= orcasAt then
		task.spawn(playMusic, ReefSounds.orcaMusic, true)
	elseif type(eventId) == "string" and ReefSounds.eventMusic[eventId] then
		task.spawn(playMusic, ReefSounds.eventMusic[eventId], true)
	elseif not currentMusic or not table.find(ReefSounds.playlist, currentMusic) then
		playlistTrack()
	end
end

local function count(t: { [any]: number }?): number
	local total = 0
	for _, n in t or {} do
		total += if type(n) == "number" then n else 1
	end
	return total
end

local function claimed(quests: any): number
	local n = 0
	for _, done in (type(quests) == "table" and quests.claimed) or {} do
		if done == true then
			n += 1
		end
	end
	return n
end

-- Effects for what changed since the last DataSync.
function Audio.onData(data: any)
	local now = {
		shells = data.shells or 0,
		planted = data.planted or 0,
		bag = data.bagCount or 0,
		seeds = count(data.seeds),
		pets = count(data.pets),
		decor = count(data.decorPlaced),
		gear = count(data.gear),
		fence = data.fence,
		claimed = claimed(data.quests),
		rebirths = data.rebirths or 0,
	}
	local before = previous
	previous = now
	if not before then
		return -- the first snapshot isn't a change
	end
	if now.rebirths > before.rebirths then
		Audio.play("bigReward")
	elseif now.pets > before.pets then
		Audio.play("hatch")
		task.delay(0.4, Audio.play, "reward")
	elseif now.claimed > before.claimed then
		Audio.play("reward")
	elseif now.bag < before.bag and now.shells > before.shells then
		Audio.play("sell")
	elseif now.bag > before.bag then
		Audio.play("harvest")
	elseif now.planted > before.planted then
		Audio.play("plant")
	elseif now.decor > before.decor then
		Audio.play("place")
	elseif now.gear > before.gear or now.fence ~= before.fence then
		Audio.play("buy")
		task.delay(0.3, Audio.play, "reward")
	elseif now.seeds > before.seeds and now.shells < before.shells then
		Audio.play("buy")
	end
end

local function musicButton(playerGui: PlayerGui)
	local gui = Ui.new("ScreenGui", {
		Name = "AudioToggle",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 2,
		Parent = playerGui,
	})
	local button = Ui.button({
		Name = "Music",
		Text = "Music",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 10),
		Size = UDim2.fromOffset(64, 30),
		BackgroundColor3 = Ui.Colors.panel,
		MaxTextSize = 15,
		Parent = gui,
	})
	local stroke = Ui.stroke(Ui.Colors.accent, 1.5)
	stroke.Parent = button
	Ui.autoScale({ button })
	button.Activated:Connect(function()
		musicEnabled = not musicEnabled
		button.TextTransparency = if musicEnabled then 0 else 0.55
		stroke.Color = if musicEnabled then Ui.Colors.accent else Ui.Colors.muted
		TweenService:Create(musicGroup, TweenInfo.new(0.4), { Volume = if musicEnabled then 1 else 0 }):Play()
	end)
end

function Audio.start(playerGui: PlayerGui)
	folder = Instance.new("Folder")
	folder.Name = "ReefAudio"
	folder.Parent = SoundService
	musicGroup = Instance.new("SoundGroup")
	musicGroup.Name = "MusicGroup"
	musicGroup.Volume = 1
	musicGroup.Parent = folder
	effectsGroup = Instance.new("SoundGroup")
	effectsGroup.Name = "EffectsGroup"
	effectsGroup.Volume = 1
	effectsGroup.Parent = folder

	local ambience = sound(ReefSounds.ambience, folder)
	ambience.Name = "Ambience"
	ambience.Looped = true
	ambience.SoundGroup = effectsGroup
	ambience:Play()

	music = Instance.new("Sound")
	music.Name = "Music"
	music.Volume = 0
	music.SoundGroup = musicGroup
	music.Parent = folder
	music.Ended:Connect(function()
		if currentMusic and table.find(ReefSounds.playlist, currentMusic) then
			playlistIndex = playlistIndex % #ReefSounds.playlist + 1
			currentMusic = nil
			playlistTrack()
		end
	end)
	musicButton(playerGui)

	Workspace:GetAttributeChangedSignal("EventId"):Connect(function()
		if Workspace:GetAttribute("EventId") ~= nil then
			Audio.play("eventStart")
		end
		updateMusic()
	end)
	-- The orcas arrive partway through the Shipwreck: check the clock now and then.
	task.spawn(function()
		while true do
			task.wait(1)
			if Workspace:GetAttribute("EventId") == "Shipwreck" then
				updateMusic()
			end
		end
	end)
	updateMusic()

	Remotes.Teleported.OnClientEvent:Connect(function()
		Audio.play("teleport")
	end)
	local lastHealth = Workspace:GetAttribute("OctopusHealth")
	local lastHitSound = 0
	Workspace:GetAttributeChangedSignal("OctopusHealth"):Connect(function()
		local health = Workspace:GetAttribute("OctopusHealth")
		if type(health) == "number" and type(lastHealth) == "number" and health < lastHealth and os.clock() - lastHitSound > 0.08 then
			lastHitSound = os.clock()
			Audio.play("octopusHit")
		end
		lastHealth = health
	end)
	Remotes.Notify.OnClientEvent:Connect(function(text)
		if type(text) ~= "string" then
			return
		end
		if string.find(text, "^Clue %d") then
			Audio.play("clue")
		elseif string.find(text, "^Quest complete") or string.find(text, "^Reef Index set complete") then
			Audio.play("reward")
		elseif string.find(text, "^You dug up") or string.find(text, "^You helped beat") then
			Audio.play("bigReward")
		end
	end)
end

return Audio
