--!nonstrict
-- The marine creatures made from real 3D meshes (Roblox's AI mesh generator, from the
-- marine-life catalog in images/living-sea as reference). Each creature is a few textured
-- MeshParts: the asset ids, each piece's size and its offset from the creature's centre as
-- generated, all facing -Z (head forward). CreatureModels (server) builds them into
-- templates with AssetService:CreateMeshPartAsync, scaled to `length`; Creatures clones and
-- animates them.
--
-- Each piece's `role` says how it moves when the creature swims (Creatures.animate):
--   body     rigid with the creature, which sways as a whole
--   tail     swings side to side from its front edge
--   fin      side fins paddling, `side` -1 (left) or 1 (right)
--   flutter  a small fin beating fast (a seahorse's back fin)
--   dangle   hangs from its top edge and sways slowly (tentacles, arms)
--   fluke    a whale's tail, beating up and down from its front edge
-- Pieces the generator didn't split cleanly are left as `body`, so they move with the rest.
--
-- `style` is how the whole creature swims: "fish" sways from the head, "whale" (orca, whale)
-- rolls gently up and down, "upright" (seahorse, octopus, the shopkeepers) rocks in place. `length` is the size it's built at, in
-- studs along `measure` ("x", "y" or "z"; by default Z for fish and the height for upright).

export type Piece = {
	name: string,
	mesh: string,
	texture: string,
	size: Vector3,
	at: Vector3,
	role: "body" | "tail" | "fin" | "flutter" | "dangle" | "fluke",
	side: number?,
}

export type CreatureDef = {
	id: string,
	name: string,
	style: "fish" | "whale" | "upright",
	length: number,
	measure: ("x" | "y" | "z")?,
	pieces: { Piece },
}

local CreatureMeshes: { [string]: CreatureDef } = {
	minnow = {
		id = "minnow",
		name = "Minnow",
		style = "fish",
		length = 1.9,
		pieces = {
			{ name = "Body", role = "body", mesh = "rbxassetid://90445594325130", texture = "rbxassetid://81684078337985", size = Vector3.new(0.898, 1.024, 1.376), at = Vector3.new(0.004, -0.001, 0.001) },
			{ name = "Tail", role = "tail", mesh = "rbxassetid://74625244173980", texture = "rbxassetid://102603640047756", size = Vector3.new(0.669, 0.507, 0.257), at = Vector3.new(0.002, -0.075, 0.561) },
			{ name = "LeftFin", role = "fin", side = -1, mesh = "rbxassetid://77144084641636", texture = "rbxassetid://135246173212776", size = Vector3.new(0.2, 0.184, 0.327), at = Vector3.new(-0.347, -0.19, -0.223) },
			{ name = "RightFin", role = "fin", side = 1, mesh = "rbxassetid://134064642656879", texture = "rbxassetid://118106918216728", size = Vector3.new(0.201, 0.183, 0.321), at = Vector3.new(0.352, -0.191, -0.222) },
		},
	},
	stripedTang = {
		id = "stripedTang",
		name = "Striped Tang",
		style = "fish",
		length = 2.1,
		pieces = {
			{ name = "Body", role = "body", mesh = "rbxassetid://111796403032030", texture = "rbxassetid://106505404726552", size = Vector3.new(0.616, 0.69, 0.787), at = Vector3.new(0.002, -0.068, -0.11) },
			-- The tail with the tall back fins, generated as one piece.
			{ name = "Tail", role = "tail", mesh = "rbxassetid://79774310366649", texture = "rbxassetid://74663877725883", size = Vector3.new(0.354, 0.887, 0.774), at = Vector3.new(0.001, -0.001, 0.121) },
			{ name = "LeftFin", role = "fin", side = -1, mesh = "rbxassetid://137763552522873", texture = "rbxassetid://137309289385727", size = Vector3.new(0.312, 0.38, 0.185), at = Vector3.new(-0.243, -0.22, -0.151) },
			{ name = "RightFin", role = "fin", side = 1, mesh = "rbxassetid://71846440611008", texture = "rbxassetid://121988933552687", size = Vector3.new(0.177, 0.163, 0.183), at = Vector3.new(0.313, -0.111, -0.151) },
		},
	},
	pufferfish = {
		id = "pufferfish",
		name = "Pufferfish",
		style = "fish",
		length = 2.1,
		pieces = {
			{ name = "Body", role = "body", mesh = "rbxassetid://84636837175231", texture = "rbxassetid://93205593283072", size = Vector3.new(2.359, 2.072, 2.243), at = Vector3.new(0.024, 0, 0.006) },
			{ name = "Tail", role = "body", mesh = "rbxassetid://104203527477904", texture = "rbxassetid://90665461221699", size = Vector3.new(2.395, 0.701, 0.514), at = Vector3.new(0.003, -0.016, 0.66) },
			{ name = "LeftFin", role = "body", mesh = "rbxassetid://121759925231411", texture = "rbxassetid://133796997758757", size = Vector3.new(0.446, 0.408, 0.417), at = Vector3.new(-0.966, -0.017, -0.456) },
			{ name = "RightFin", role = "body", mesh = "rbxassetid://76417669277107", texture = "rbxassetid://119339719330490", size = Vector3.new(0.49, 0.695, 0.668), at = Vector3.new(0.96, -0.017, 0.581) },
		},
	},
	moonfish = {
		id = "moonfish",
		name = "Moonfish",
		style = "fish",
		length = 2.8,
		pieces = {
			{ name = "Body", role = "body", mesh = "rbxassetid://109539700024884", texture = "rbxassetid://85654701213820", size = Vector3.new(0.807, 1.372, 2.445), at = Vector3.new(0.004, 0.067, 0.003) },
			{ name = "LowerFin", role = "body", mesh = "rbxassetid://136832046494426", texture = "rbxassetid://75477989715345", size = Vector3.new(0.265, 0.691, 0.449), at = Vector3.new(0.003, -0.414, -0.451) },
			{ name = "LeftFin", role = "fin", side = -1, mesh = "rbxassetid://119553309813652", texture = "rbxassetid://77559724444597", size = Vector3.new(0.509, 0.521, 0.349), at = Vector3.new(-0.341, -0.094, -0.383) },
			{ name = "RightFin", role = "fin", side = 1, mesh = "rbxassetid://105776856021111", texture = "rbxassetid://97877264524351", size = Vector3.new(0.508, 0.519, 0.348), at = Vector3.new(0.35, -0.093, -0.384) },
		},
	},
	seahorse = {
		id = "seahorse",
		name = "Seahorse",
		style = "upright",
		length = 2.6,
		pieces = {
			{ name = "Body", role = "body", mesh = "rbxassetid://119283043497802", texture = "rbxassetid://134505108571401", size = Vector3.new(1, 2.683, 1.571), at = Vector3.new(0.005, -0.004, 0.006) },
			{ name = "TailTip", role = "body", mesh = "rbxassetid://116893863841313", texture = "rbxassetid://118254983787356", size = Vector3.new(0.249, 0.248, 0.392), at = Vector3.new(0.006, -1.008, 0.029) },
			{ name = "BackFin", role = "flutter", mesh = "rbxassetid://124150727850335", texture = "rbxassetid://96926188219710", size = Vector3.new(0.155, 0.489, 0.385), at = Vector3.new(0.005, -0.213, 0.526) },
		},
	},

	-- Batch 2: the octopus pet and the animal shopkeepers.
	octopus = {
		id = "octopus",
		name = "Octopus",
		style = "upright",
		length = 2,
		pieces = {
			{ name = "Head", role = "body", mesh = "rbxassetid://127257835490138", texture = "rbxassetid://132753456666796", size = Vector3.new(1.126, 1.772, 2.265), at = Vector3.new(0.006, 0.025, 0.005) },
			{ name = "FrontLeftArms", role = "dangle", mesh = "rbxassetid://98997370030284", texture = "rbxassetid://118413492719503", size = Vector3.new(1.237, 0.982, 1.252), at = Vector3.new(-0.58, -0.418, -0.35) },
			{ name = "FrontRightArms", role = "dangle", mesh = "rbxassetid://139088217635147", texture = "rbxassetid://134141601426388", size = Vector3.new(1.239, 0.991, 1.248), at = Vector3.new(0.582, -0.419, -0.351) },
			{ name = "BackLeftArms", role = "dangle", mesh = "rbxassetid://74187796396369", texture = "rbxassetid://81188302616808", size = Vector3.new(0.782, 0.885, 1.072), at = Vector3.new(-0.335, -0.419, 0.436) },
			{ name = "BackRightArms", role = "dangle", mesh = "rbxassetid://103330941389642", texture = "rbxassetid://123431970705754", size = Vector3.new(0.785, 0.886, 1.095), at = Vector3.new(0.346, -0.424, 0.426) },
		},
	},
	-- Pinch, at Sell Coral.
	crab = {
		id = "crab",
		name = "Crab",
		style = "upright",
		length = 4.2,
		measure = "x",
		pieces = {
			{ name = "Body", role = "body", mesh = "rbxassetid://106280854630027", texture = "rbxassetid://122855535580732", size = Vector3.new(1.924, 1.551, 1.489), at = Vector3.new(0.001, -0.302, 0.002) },
			{ name = "LeftClaw", role = "fin", side = -1, mesh = "rbxassetid://91200204367510", texture = "rbxassetid://76252505678567", size = Vector3.new(0.792, 1.4, 0.605), at = Vector3.new(-1.021, 0.395, 0.005) },
			{ name = "RightClaw", role = "fin", side = 1, mesh = "rbxassetid://78028673283245", texture = "rbxassetid://111190731085532", size = Vector3.new(0.796, 1.395, 0.608), at = Vector3.new(1.029, 0.396, 0.003) },
			{ name = "Legs", role = "body", mesh = "rbxassetid://105434801063640", texture = "rbxassetid://72473867122459", size = Vector3.new(2.646, 0.692, 1.508), at = Vector3.new(0.002, -0.759, 0.005) },
		},
	},
	-- Otto, the Kelp Forest ranger.
	otter = {
		id = "otter",
		name = "Sea Otter",
		style = "upright",
		length = 5.6,
		pieces = {
			{ name = "Body", role = "body", mesh = "rbxassetid://122217423658409", texture = "rbxassetid://126414512371422", size = Vector3.new(1.977, 2.451, 2.339), at = Vector3.new(0.012, -1.09, -0.274) },
			{ name = "HeadAndHat", role = "body", mesh = "rbxassetid://107105041632960", texture = "rbxassetid://135190564491959", size = Vector3.new(2.834, 2.283, 2.699), at = Vector3.new(0.008, 1.158, -0.244) },
			{ name = "LeftArm", role = "dangle", mesh = "rbxassetid://105620898387513", texture = "rbxassetid://75110174200972", size = Vector3.new(0.561, 1.127, 0.938), at = Vector3.new(-0.907, -0.638, -0.615) },
			{ name = "RightArm", role = "dangle", mesh = "rbxassetid://124687236708575", texture = "rbxassetid://81041092239732", size = Vector3.new(0.561, 1.125, 0.931), at = Vector3.new(0.923, -0.647, -0.616) },
			{ name = "Tail", role = "tail", mesh = "rbxassetid://128833063096383", texture = "rbxassetid://135838641209432", size = Vector3.new(1.152, 0.894, 1.687), at = Vector3.new(0.672, -1.756, 0.763) },
		},
	},
	-- Lumi, who sells abyssal coral at the bottom of the Abyss.
	lanternfish = {
		id = "lanternfish",
		name = "Lanternfish",
		style = "fish",
		length = 4.6,
		pieces = {
			{ name = "Body", role = "body", mesh = "rbxassetid://75327817944942", texture = "rbxassetid://80908995453881", size = Vector3.new(2.503, 3.05, 3.514), at = Vector3.new(0.007, -0.376, -0.161) },
			{ name = "Tail", role = "tail", mesh = "rbxassetid://118807933685629", texture = "rbxassetid://125016938043205", size = Vector3.new(1.715, 1.312, 0.839), at = Vector3.new(0.006, -0.624, 1.508) },
			{ name = "TailEdge", role = "body", mesh = "rbxassetid://95750694091175", texture = "rbxassetid://140370841808959", size = Vector3.new(0.8, 1.316, 0.813), at = Vector3.new(-0.45, -0.619, 1.522) },
			{ name = "BellyFin", role = "body", mesh = "rbxassetid://92694497960496", texture = "rbxassetid://137123155643489", size = Vector3.new(1.031, 1.274, 1.391), at = Vector3.new(0.746, -1.268, -0.409) },
			{ name = "Lure", role = "body", mesh = "rbxassetid://89078586192759", texture = "rbxassetid://97251999387546", size = Vector3.new(0.752, 1.559, 0.742), at = Vector3.new(0.005, 1.116, -1.249) },
		},
	},

	-- Batch 3: the event characters. (The Giant Octopus is the octopus above, made huge.)
	-- Marina the Mermaid Merchant, behind her stall.
	mermaid = {
		id = "mermaid",
		name = "Marina the Mermaid",
		style = "upright",
		length = 7,
		pieces = {
			{ name = "Head", role = "body", mesh = "rbxassetid://78532637941580", texture = "rbxassetid://133612140795178", size = Vector3.new(2.857, 2.94, 2.361), at = Vector3.new(0.061, 1.544, 0.007) },
			{ name = "Body", role = "body", mesh = "rbxassetid://113175668380052", texture = "rbxassetid://118679398119350", size = Vector3.new(1.385, 3.119, 1.654), at = Vector3.new(0.074, -0.803, -0.067) },
			{ name = "LeftArm", role = "dangle", mesh = "rbxassetid://70542438306551", texture = "rbxassetid://128819182394443", size = Vector3.new(1.187, 0.992, 0.583), at = Vector3.new(-0.805, -0.031, -0.245) },
			{ name = "RightArm", role = "dangle", mesh = "rbxassetid://117391496158325", texture = "rbxassetid://105724494666300", size = Vector3.new(1.264, 0.996, 0.594), at = Vector3.new(0.878, -0.032, -0.247) },
			-- A curl of the tail the generator split off to one side.
			{ name = "Tail", role = "body", mesh = "rbxassetid://122726944209040", texture = "rbxassetid://93799520664649", size = Vector3.new(1.061, 1.199, 0.815), at = Vector3.new(-0.959, -1.658, 0.779) },
			{ name = "TailFin", role = "dangle", mesh = "rbxassetid://118178529838781", texture = "rbxassetid://75843152651711", size = Vector3.new(2.128, 0.739, 2.182), at = Vector3.new(0.053, -2.666, 0.036) },
		},
	},
	-- The Shipwreck event's orcas: chubby and toy-like, with the flukes tucked under.
	orca = {
		id = "orca",
		name = "Orca",
		style = "whale",
		length = 11,
		pieces = {
			{ name = "Body", role = "body", mesh = "rbxassetid://89494039899846", texture = "rbxassetid://134959882818658", size = Vector3.new(3.92, 4.965, 5.549), at = Vector3.new(0.008, -0.522, 0.011) },
			{ name = "Flukes", role = "fluke", mesh = "rbxassetid://98506360041135", texture = "rbxassetid://102664483437364", size = Vector3.new(4.632, 0.96, 1.476), at = Vector3.new(0.006, -2.115, 1.846) },
			{ name = "LeftFlipper", role = "fin", side = -1, mesh = "rbxassetid://118016000334997", texture = "rbxassetid://71723937461473", size = Vector3.new(1.365, 1.48, 0.963), at = Vector3.new(-1.888, -1.7, -0.57) },
			{ name = "RightFlipper", role = "fin", side = 1, mesh = "rbxassetid://136721577071554", texture = "rbxassetid://81125158400039", size = Vector3.new(1.369, 1.482, 0.964), at = Vector3.new(1.908, -1.699, -0.565) },
			{ name = "Dorsal", role = "body", mesh = "rbxassetid://74765765990152", texture = "rbxassetid://105587247254533", size = Vector3.new(0.407, 1.481, 1.891), at = Vector3.new(0.012, 2.254, 0.025) },
		},
	},
	-- The Whale Pass whale, crossing high over the plaza.
	whale = {
		id = "whale",
		name = "Humpback Whale",
		style = "whale",
		length = 32,
		pieces = {
			{ name = "Body", role = "body", mesh = "rbxassetid://79434566973162", texture = "rbxassetid://122925335364282", size = Vector3.new(4.675, 5.987, 10.105), at = Vector3.new(0.024, -0.291, -0.077) },
			{ name = "Flukes", role = "fluke", mesh = "rbxassetid://89658744129233", texture = "rbxassetid://120995909224980", size = Vector3.new(5.706, 2.267, 1.53), at = Vector3.new(0.007, 2.848, 4.387) },
			{ name = "LeftFlipper", role = "fin", side = -1, mesh = "rbxassetid://111786021624410", texture = "rbxassetid://92839463882592", size = Vector3.new(3.165, 2.982, 2.107), at = Vector3.new(-3.358, -2.528, -0.87) },
			{ name = "RightFlipper", role = "fin", side = 1, mesh = "rbxassetid://129966315676287", texture = "rbxassetid://129086041637974", size = Vector3.new(3.162, 2.981, 2.105), at = Vector3.new(3.385, -2.523, -0.87) },
		},
	},

	-- Batch 4: the Sunken Ruins' rare creatures (RuinsLife).
	coelacanth = {
		id = "coelacanth",
		name = "Coelacanth",
		style = "fish",
		length = 9,
		pieces = {
			{ name = "Body", role = "body", mesh = "rbxassetid://117432180906145", texture = "rbxassetid://80901727993018", size = Vector3.new(1.688, 2.203, 2.967), at = Vector3.new(0.007, 0.031, 0.004) },
			{ name = "Tail", role = "tail", mesh = "rbxassetid://86159277500615", texture = "rbxassetid://109536409624467", size = Vector3.new(0.223, 1.256, 0.345), at = Vector3.new(0.006, -0.06, 0.737) },
			{ name = "LeftFins", role = "fin", side = -1, mesh = "rbxassetid://129401825227343", texture = "rbxassetid://112860072929745", size = Vector3.new(1.015, 1.591, 1.033), at = Vector3.new(-0.741, -0.348, -0.221) },
			{ name = "RightFins", role = "fin", side = 1, mesh = "rbxassetid://93215387459583", texture = "rbxassetid://92518018535058", size = Vector3.new(1.011, 1.591, 1.035), at = Vector3.new(0.746, -0.345, -0.22) },
		},
	},
	anglerfish = {
		id = "anglerfish",
		name = "Anglerfish",
		style = "fish",
		length = 4.5,
		pieces = {
			{ name = "Body", role = "body", mesh = "rbxassetid://74870168034863", texture = "rbxassetid://127872531372925", size = Vector3.new(1.943, 2.151, 2.71), at = Vector3.new(0.007, -0.205, 0.267) },
			-- Generated as the "tail fin", but it's the fin crest along its back and belly.
			{ name = "Crest", role = "body", mesh = "rbxassetid://118723363543708", texture = "rbxassetid://109190883986836", size = Vector3.new(0.154, 2.726, 2.172), at = Vector3.new(0.006, -0.065, 0.426) },
			{ name = "LeftFin", role = "fin", side = -1, mesh = "rbxassetid://86384066970538", texture = "rbxassetid://91127091607594", size = Vector3.new(0.718, 0.823, 0.875), at = Vector3.new(-1.137, -0.294, -0.172) },
			{ name = "RightFin", role = "fin", side = 1, mesh = "rbxassetid://139551444647223", texture = "rbxassetid://77991452642401", size = Vector3.new(0.719, 0.826, 0.874), at = Vector3.new(1.144, -0.294, -0.168) },
			{ name = "Lure", role = "body", mesh = "rbxassetid://119049659156099", texture = "rbxassetid://139008752386186", size = Vector3.new(0.292, 1.054, 0.912), at = Vector3.new(0.004, 0.894, -1.157) },
		},
	},
	seadragon = {
		id = "seadragon",
		name = "Leafy Sea Dragon",
		style = "fish",
		length = 7,
		pieces = {
			{ name = "Body", role = "body", mesh = "rbxassetid://107511880518947", texture = "rbxassetid://86198885439442", size = Vector3.new(0.753, 2.141, 2.065), at = Vector3.new(0.002, 0.247, -0.39) },
			{ name = "Tail", role = "tail", mesh = "rbxassetid://93697788363965", texture = "rbxassetid://93696152601148", size = Vector3.new(0.305, 0.808, 1.15), at = Vector3.new(0.005, -0.852, 0.856) },
			{ name = "Fronds", role = "dangle", mesh = "rbxassetid://76316387744806", texture = "rbxassetid://109324972547045", size = Vector3.new(2, 2.434, 1.199), at = Vector3.new(0.003, -0.112, 0.305) },
		},
	},
	-- Chubby and upright: the generator made the mantle one piece with everything else.
	giantSquid = {
		id = "giantSquid",
		name = "Giant Squid",
		style = "upright",
		length = 20,
		pieces = {
			{ name = "Mantle", role = "body", mesh = "rbxassetid://119288533294192", texture = "rbxassetid://118286749769844", size = Vector3.new(8, 7.592, 7.034), at = Vector3.new(0.013, -0.011, 0.014) },
			{ name = "Eyes", role = "body", mesh = "rbxassetid://94955032461893", texture = "rbxassetid://137241646646178", size = Vector3.new(1.973, 0.825, 0.762), at = Vector3.new(0.008, 1.603, -1.053) },
			{ name = "Arms", role = "dangle", mesh = "rbxassetid://103098856342476", texture = "rbxassetid://100325691848862", size = Vector3.new(4.206, 1.057, 0.606), at = Vector3.new(0.015, -0.843, 0.015) },
			{ name = "LeftTentacle", role = "dangle", mesh = "rbxassetid://117571102247150", texture = "rbxassetid://90301553917058", size = Vector3.new(2.036, 3.145, 3.472), at = Vector3.new(-1.167, -2.191, 1.784) },
			{ name = "RightTentacle", role = "dangle", mesh = "rbxassetid://128726808692703", texture = "rbxassetid://131051287265254", size = Vector3.new(4.044, 3.184, 3.628), at = Vector3.new(1.988, -2.199, 1.703) },
		},
	},

	-- Batch 5: the Abyss's deep-sea creatures (AbyssLife).
	ghostShark = {
		id = "ghostShark",
		name = "Ghost Shark",
		style = "fish",
		length = 18,
		pieces = {
			{ name = "Body", role = "body", mesh = "rbxassetid://108310560223885", texture = "rbxassetid://134310913064818", size = Vector3.new(1.968, 3.021, 9.157), at = Vector3.new(0.011, 0.477, -0.328) },
			{ name = "Tail", role = "tail", mesh = "rbxassetid://137492378769961", texture = "rbxassetid://114333249855317", size = Vector3.new(3.68, 2.334, 1.03), at = Vector3.new(0.014, -0.846, 4.423) },
			{ name = "LeftFin", role = "fin", side = -1, mesh = "rbxassetid://133571089340140", texture = "rbxassetid://102245762852773", size = Vector3.new(1.758, 1.479, 1.418), at = Vector3.new(-0.779, -0.825, -0.469) },
			{ name = "RightFin", role = "fin", side = 1, mesh = "rbxassetid://130545779245159", texture = "rbxassetid://79918477061106", size = Vector3.new(1.744, 1.481, 1.42), at = Vector3.new(0.801, -0.826, -0.467) },
		},
	},
	-- Upright and flat, its webbed cloak hanging behind.
	vampireSquid = {
		id = "vampireSquid",
		name = "Vampire Squid",
		style = "upright",
		length = 5,
		pieces = {
			{ name = "Body", role = "body", mesh = "rbxassetid://77755609998449", texture = "rbxassetid://105188901133145", size = Vector3.new(1.406, 3.985, 1.457), at = Vector3.new(0.007, -0.002, -0.111) },
			{ name = "LeftFin", role = "fin", side = -1, mesh = "rbxassetid://97754394119281", texture = "rbxassetid://93794212677858", size = Vector3.new(0.894, 1.232, 0.601), at = Vector3.new(-0.684, -0.401, -0.259) },
			{ name = "RightFin", role = "fin", side = 1, mesh = "rbxassetid://125053735530173", texture = "rbxassetid://135621602677459", size = Vector3.new(0.89, 0.908, 0.428), at = Vector3.new(0.696, -0.569, -0.341) },
			{ name = "Cloak", role = "dangle", mesh = "rbxassetid://86339813539911", texture = "rbxassetid://91297490478714", size = Vector3.new(3.693, 2.824, 1.205), at = Vector3.new(0.003, -0.598, 0.25) },
		},
	},
	-- Coiled up under its big head rather than long and thin.
	gulperEel = {
		id = "gulperEel",
		name = "Gulper Eel",
		style = "fish",
		length = 11,
		pieces = {
			{ name = "Head", role = "body", mesh = "rbxassetid://87337433601093", texture = "rbxassetid://89933401475718", size = Vector3.new(1.267, 2.044, 2.1), at = Vector3.new(0.01, 0.968, -1.363) },
			{ name = "Body", role = "body", mesh = "rbxassetid://109638734200762", texture = "rbxassetid://121647963867581", size = Vector3.new(2.139, 1.928, 2.812), at = Vector3.new(0.006, -0.878, -0.003) },
			{ name = "Tail", role = "tail", mesh = "rbxassetid://111753251744313", texture = "rbxassetid://88319273882631", size = Vector3.new(1.577, 0.644, 1.061), at = Vector3.new(0.006, -1.687, 1.891) },
		},
	},
	-- The ear fins on top flap; the webbed arms hang below.
	dumboOctopus = {
		id = "dumboOctopus",
		name = "Dumbo Octopus",
		style = "upright",
		length = 4.5,
		pieces = {
			{ name = "Head", role = "body", mesh = "rbxassetid://106679857519355", texture = "rbxassetid://128558760360920", size = Vector3.new(1.902, 1.653, 1.935), at = Vector3.new(0.011, -0.041, 0) },
			{ name = "LeftEar", role = "fin", side = -1, mesh = "rbxassetid://93419032695587", texture = "rbxassetid://80385393602919", size = Vector3.new(0.818, 1.063, 0.5), at = Vector3.new(-0.615, 1.023, 0.034) },
			{ name = "RightEar", role = "fin", side = 1, mesh = "rbxassetid://133145376964854", texture = "rbxassetid://138386191091123", size = Vector3.new(0.816, 1.066, 0.489), at = Vector3.new(0.625, 1.02, 0.033) },
			{ name = "Arms", role = "dangle", mesh = "rbxassetid://138810187669496", texture = "rbxassetid://126894983599156", size = Vector3.new(3.275, 0.734, 3.5), at = Vector3.new(0.003, -1.201, 0.005) },
		},
	},

	-- Batch 6: the Kelp Forest's catchable fish. Except on the sheephead, the generator's
	-- "tail fin" came out as a fin along the belly or middle, so it moves with the body.
	garibaldi = {
		id = "garibaldi",
		name = "Garibaldi",
		style = "fish",
		length = 2.2,
		pieces = {
			{ name = "Body", role = "body", mesh = "rbxassetid://108956244369976", texture = "rbxassetid://107845357752402", size = Vector3.new(0.793, 1.067, 1.581), at = Vector3.new(0.002, 0.04, 0.003) },
			{ name = "BellyFin", role = "body", mesh = "rbxassetid://88220121677633", texture = "rbxassetid://106130186336687", size = Vector3.new(0.12, 0.326, 0.482), at = Vector3.new(0.002, -0.372, 0.21) },
			{ name = "LeftFin", role = "fin", side = -1, mesh = "rbxassetid://114535274729002", texture = "rbxassetid://86694608108250", size = Vector3.new(0.431, 0.584, 0.34), at = Vector3.new(-0.282, -0.282, -0.193) },
			{ name = "RightFin", role = "fin", side = 1, mesh = "rbxassetid://121854202708585", texture = "rbxassetid://109881324266270", size = Vector3.new(0.432, 0.582, 0.342), at = Vector3.new(0.286, -0.283, -0.193) },
		},
	},
	kelpBass = {
		id = "kelpBass",
		name = "Kelp Bass",
		style = "fish",
		length = 2.5,
		pieces = {
			{ name = "Body", role = "body", mesh = "rbxassetid://140037315414989", texture = "rbxassetid://100900724291213", size = Vector3.new(0.689, 0.932, 1.451), at = Vector3.new(0.002, 0.048, 0.001) },
			{ name = "MidFins", role = "body", mesh = "rbxassetid://83985989080985", texture = "rbxassetid://98094940203504", size = Vector3.new(0.157, 0.831, 0.405), at = Vector3.new(0.002, -0.028, 0.275) },
			{ name = "LeftFin", role = "fin", side = -1, mesh = "rbxassetid://137133911855266", texture = "rbxassetid://83156643027836", size = Vector3.new(0.379, 0.447, 0.264), at = Vector3.new(-0.309, -0.291, -0.19) },
			{ name = "RightFin", role = "fin", side = 1, mesh = "rbxassetid://94100730535180", texture = "rbxassetid://76131102952823", size = Vector3.new(0.38, 0.448, 0.266), at = Vector3.new(0.312, -0.291, -0.19) },
		},
	},
	opaleye = {
		id = "opaleye",
		name = "Opaleye",
		style = "fish",
		length = 2.3,
		pieces = {
			{ name = "Body", role = "body", mesh = "rbxassetid://100806901183112", texture = "rbxassetid://71603101914480", size = Vector3.new(0.832, 0.832, 1.187), at = Vector3.new(0.002, -0.07, 0.001) },
			{ name = "MidFins", role = "body", mesh = "rbxassetid://125245705549542", texture = "rbxassetid://129448370403472", size = Vector3.new(0.135, 0.966, 0.75), at = Vector3.new(0.002, 0.043, 0.095) },
			{ name = "LeftFin", role = "fin", side = -1, mesh = "rbxassetid://110672779071950", texture = "rbxassetid://97434655458253", size = Vector3.new(0.338, 0.441, 0.327), at = Vector3.new(-0.329, -0.309, -0.17) },
			{ name = "RightFin", role = "fin", side = 1, mesh = "rbxassetid://92062982100961", texture = "rbxassetid://114856385597221", size = Vector3.new(0.339, 0.439, 0.324), at = Vector3.new(0.332, -0.309, -0.171) },
		},
	},
	sheephead = {
		id = "sheephead",
		name = "Sheephead",
		style = "fish",
		length = 3,
		pieces = {
			{ name = "Body", role = "body", mesh = "rbxassetid://72717868740519", texture = "rbxassetid://104514666098268", size = Vector3.new(0.966, 1.259, 1.859), at = Vector3.new(0.002, 0.037, -0.063) },
			{ name = "Tail", role = "tail", mesh = "rbxassetid://136959516113211", texture = "rbxassetid://88176046922617", size = Vector3.new(1.028, 0.681, 0.332), at = Vector3.new(0.002, -0.07, 0.835) },
			{ name = "LeftFin", role = "fin", side = -1, mesh = "rbxassetid://124328426415416", texture = "rbxassetid://94482506196906", size = Vector3.new(0.424, 0.643, 0.332), at = Vector3.new(-0.386, -0.352, -0.286) },
			{ name = "RightFin", role = "fin", side = 1, mesh = "rbxassetid://135187423962052", texture = "rbxassetid://105734063226428", size = Vector3.new(0.422, 0.644, 0.335), at = Vector3.new(0.391, -0.351, -0.285) },
		},
	},
	giantSeaBass = {
		id = "giantSeaBass",
		name = "Giant Sea Bass",
		style = "fish",
		length = 4.5,
		pieces = {
			{ name = "Body", role = "body", mesh = "rbxassetid://139873070542557", texture = "rbxassetid://89758098435956", size = Vector3.new(1.288, 1.646, 2.187), at = Vector3.new(0.004, 0.059, 0.005) },
			{ name = "BellyFin", role = "body", mesh = "rbxassetid://118925175856188", texture = "rbxassetid://128923200368022", size = Vector3.new(0.184, 0.331, 0.418), at = Vector3.new(0.003, -0.653, 0.442) },
			{ name = "LeftFin", role = "fin", side = -1, mesh = "rbxassetid://104659200527066", texture = "rbxassetid://72606710428966", size = Vector3.new(0.669, 0.721, 0.716), at = Vector3.new(-0.563, -0.528, -0.134) },
			{ name = "RightFin", role = "fin", side = 1, mesh = "rbxassetid://132974300618507", texture = "rbxassetid://105669375314300", size = Vector3.new(0.666, 0.719, 0.716), at = Vector3.new(0.569, -0.527, -0.132) },
		},
	},
}

return CreatureMeshes
