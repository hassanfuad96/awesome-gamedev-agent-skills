--!nonstrict
-- Every sound in Grow a Reef, by name. All come from the Roblox Creator Store's licensed
-- libraries, free to use in any experience: music and stings from APM Music (APMOfficial),
-- sound effects from Pro Sound Effects (ProSoundEffects), and one Roblox UI sting. To swap a
-- sound, change its id here; volume and playbackSpeed are optional.

export type SoundDef = { id: number, volume: number?, playbackSpeed: number? }

local ReefSounds = {}

-- Background music, played in turn and looped as a playlist.
ReefSounds.playlist = {
	{ id = 1840447016, volume = 0.35 }, -- "Underwater Life" (APM)
	{ id = 1847688899, volume = 0.35 }, -- "Deep Sea Diving A" (APM)
} :: { SoundDef }

-- Music that replaces the playlist while a sea event runs (by event id).
ReefSounds.eventMusic = {
	Volcano = { id = 9043111968, volume = 0.4 }, -- "Dangerous Deep Sea 2" (APM)
	Octopus = { id = 9043110758, volume = 0.45 }, -- "Sea Monster" (APM): chase and fight
	Shipwreck = { id = 1846079117, volume = 0.4 }, -- "Dangerous Deep Sea 1" (APM): the ship sinks
} :: { [string]: SoundDef }
ReefSounds.orcaMusic = { id = 9043110758, volume = 0.5 } :: SoundDef -- when the orcas arrive

-- Looping underwater ambience under everything.
ReefSounds.ambience = { id = 9112889917, volume = 0.3 } :: SoundDef -- "Underwater Ambience 1" (PSE)

-- Short effects.
ReefSounds.effects = {
	plant = { id = 9112872239, volume = 0.6 }, -- small bubbles pop (PSE)
	harvest = { id = 9112872058, volume = 0.7, playbackSpeed = 1.2 }, -- small bubbles pop (PSE)
	sell = { id = 9113849651, volume = 0.7 }, -- coin throws (PSE)
	buy = { id = 9113849492, volume = 0.6 }, -- coins jingle (PSE)
	hatch = { id = 9113959332, volume = 0.8 }, -- egg crack (PSE)
	teleport = { id = 9125805579, volume = 0.6 }, -- rising whoosh (PSE)
	swim = { id = 9112872244, volume = 0.35 }, -- bubbles (PSE)
	place = { id = 9118616398, volume = 0.5 }, -- rock thud into sand (PSE)
	lava = { id = 9118616114, volume = 1 }, -- rock impact (PSE), played where the rock lands
	octopusHit = { id = 9112872235, volume = 0.5, playbackSpeed = 0.7 }, -- low bubble pop (PSE)
	dig = { id = 9118617019, volume = 0.8 }, -- rock thud into sand (PSE)
	reward = { id = 9040172806, volume = 0.6 }, -- "Small Discoveries (sting b)" (APM)
	bigReward = { id = 1839901317, volume = 0.6 }, -- "Heavenly sting" (APM)
	eventStart = { id = 15675043410, volume = 0.6 }, -- "Roblox_UI_Tonal_Stinger" (Roblox)
	clue = { id = 9041915227, volume = 0.6 }, -- "Wander Waltz (sting)" (APM): treasure clues
} :: { [string]: SoundDef }

function ReefSounds.assetId(def: SoundDef): string
	return "rbxassetid://" .. def.id
end

return ReefSounds
