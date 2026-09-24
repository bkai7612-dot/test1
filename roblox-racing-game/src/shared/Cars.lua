-- The five drivable cars. Each is modelled after a well-known real-world
-- car archetype but carries no brand names, logos or badges.
--
-- Stat units:
--   topSpeed  studs / second
--   accel     studs / second^2
--   handling  max yaw rate (radians / second)
--   grip      lateral velocity correction rate (per second)
--   brake     studs / second^2
--   nitro     seconds of boost in a full tank
local Cars = {}

Cars.Order = { "Hatch", "Rally", "Muscle", "Tuner", "Hyper", "Burger" }

Cars.List = {
	Hatch = {
		id = "Hatch",
		name = "Street Hatch",
		class = "Hot Hatchback",
		inspiration = "Classic European 2-door hot hatch",
		description = "Light, nimble and forgiving. The perfect car to learn every corner.",
		price = 0,
		level = 1,
		defaultPaint = "Racing Red",
		upgradeBase = 250,
		stats = { topSpeed = 112, accel = 50, handling = 2.5, grip = 7.5, brake = 95, nitro = 2.5 },
		body = {
			length = 13,
			width = 6.4,
			height = 2.3,
			bottom = -0.6,
			noseLen = 2.4,
			noseDrop = 0.9,
			wheelRadius = 1.15,
			wheelWidth = 0.9,
			wheelBase = 8.2,
			track = 6.0,
			cabin = { z = 1.8, length = 5.4, height = 2.3, inset = 0.35, windshield = 2.2, rear = 1.0 },
			spoiler = "roof",
			extras = { sideSkirts = true },
		},
	},
	Rally = {
		id = "Rally",
		name = "Rally Sport",
		class = "AWD Rally Sedan",
		inspiration = "Turbocharged all-wheel-drive rally sedan",
		description = "All-wheel-drive grip, a big rear wing and a hood scoop. Loves dirt and tight turns.",
		price = 6000,
		level = 3,
		defaultPaint = "Rally Blue",
		upgradeBase = 400,
		stats = { topSpeed = 124, accel = 56, handling = 2.6, grip = 8.5, brake = 100, nitro = 3.0 },
		body = {
			length = 14.4,
			width = 6.8,
			height = 2.3,
			bottom = -0.6,
			noseLen = 2.6,
			noseDrop = 0.9,
			wheelRadius = 1.25,
			wheelWidth = 1.0,
			wheelBase = 9.0,
			track = 6.4,
			cabin = { z = 0.6, length = 4.6, height = 2.2, inset = 0.4, windshield = 2.4, rear = 1.8 },
			spoiler = "wing",
			extras = { scoop = true, mudflaps = true, roofVent = true, sideSkirts = true },
		},
	},
	Muscle = {
		id = "Muscle",
		name = "Muscle V8",
		class = "American Muscle Coupe",
		inspiration = "Long-hood fastback V8 muscle car",
		description = "Huge V8 torque and brutal straight-line speed. Needs a steady hand in corners.",
		price = 14000,
		level = 6,
		defaultPaint = "Grabber Orange",
		upgradeBase = 650,
		stats = { topSpeed = 140, accel = 62, handling = 2.1, grip = 6.0, brake = 90, nitro = 3.0 },
		body = {
			length = 16,
			width = 7.2,
			height = 2.5,
			bottom = -0.6,
			noseLen = 1.6,
			noseDrop = 0.6,
			wheelRadius = 1.35,
			wheelWidth = 1.2,
			wheelBase = 10,
			track = 6.8,
			cabin = { z = 1.6, length = 3.6, height = 2.0, inset = 0.5, windshield = 2.6, rear = 3.4 },
			spoiler = "ducktail",
			extras = { scoop = true, stripes = true },
		},
	},
	Tuner = {
		id = "Tuner",
		name = "Tuner GT",
		class = "Japanese Sports Coupe",
		inspiration = "Iconic 90s twin-turbo Japanese GT coupe",
		description = "Twin-turbo tuner legend. Balanced, fast, and happiest sideways.",
		price = 28000,
		level = 10,
		defaultPaint = "Pearl White",
		upgradeBase = 950,
		stats = { topSpeed = 152, accel = 64, handling = 2.45, grip = 7.5, brake = 105, nitro = 3.5 },
		body = {
			length = 15,
			width = 7.0,
			height = 2.1,
			bottom = -0.6,
			noseLen = 3.2,
			noseDrop = 1.0,
			wheelRadius = 1.25,
			wheelWidth = 1.1,
			wheelBase = 9.6,
			track = 6.6,
			cabin = { z = 1.4, length = 3.4, height = 2.0, inset = 0.5, windshield = 2.6, rear = 2.4 },
			spoiler = "gtwing",
			extras = { sideSkirts = true, splitter = true },
		},
	},
	Hyper = {
		id = "Hyper",
		name = "Hyper X",
		class = "Mid-Engine Supercar",
		inspiration = "Italian-style V12 wedge supercar",
		description = "A mid-engine missile with scissor-door attitude. The fastest thing on four wheels.",
		price = 65000,
		level = 15,
		defaultPaint = "Lime Rush",
		upgradeBase = 1500,
		stats = { topSpeed = 172, accel = 74, handling = 2.55, grip = 8.5, brake = 120, nitro = 4.0 },
		body = {
			length = 15.6,
			width = 7.6,
			height = 1.7,
			bottom = -0.6,
			noseLen = 4.2,
			noseDrop = 0.9,
			wheelRadius = 1.3,
			wheelWidth = 1.3,
			wheelBase = 9.8,
			track = 7.2,
			cabin = { z = 0.2, length = 2.6, height = 2.0, inset = 1.0, windshield = 3.6, rear = 3.6 },
			spoiler = "wing",
			extras = { intakes = true, engineVents = true, splitter = true },
		},
	},
	-- Level 50 reward. Can't be bought: it's given to every player who
	-- reaches the level cap (see DataService.GrantRewardCars).
	Burger = {
		id = "Burger",
		name = "Double Cheese Cruiser",
		class = "Level 50 Legend",
		inspiration = "A double cheeseburger. Seriously.",
		description = "Only racers who reach level 50 get the keys. Fastest car in the game, with french-fry exhausts and a sesame-seed roof.",
		price = 0,
		level = 50,
		reward = true,
		defaultPaint = "Racing Red",
		defaultCustom = { accent = "Sunburst Yellow", glow = "Gold", rim = "Gold" },
		upgradeBase = 1500,
		stats = { topSpeed = 180, accel = 78, handling = 2.7, grip = 9, brake = 125, nitro = 5.0 },
		body = {
			style = "burger",
			length = 12, -- burger diameter
			width = 9,
			height = 5,
			bottom = -0.6,
			noseLen = 0,
			noseDrop = 0,
			wheelRadius = 1.3,
			wheelWidth = 1.2,
			wheelBase = 8.4,
			track = 7.4,
			cabin = { z = 0.8, length = 3, height = 2, inset = 1, windshield = 1, rear = 1 },
			seat = Vector3.new(0, 2.3, 0.8), -- driver pops out of a hatch in the top bun
			spoiler = "none",
			extras = {},
		},
	},
}

-- Maximums used to normalise the stat bars in the UI.
Cars.StatMax = { topSpeed = 240, accel = 115, handling = 3.4, grip = 12, brake = 185, nitro = 7 }

function Cars.Get(id)
	return Cars.List[id]
end

return Cars
