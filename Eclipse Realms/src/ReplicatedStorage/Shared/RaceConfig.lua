--!strict
-- Race definitions. Shared by the server (teams, spawns) and the client (selection UI).
-- Order here is the order the zones are laid out around the map (clockwise).

export type Race = {
	Name: string,
	Plural: string,
	TeamName: string,
	TeamColor: string, -- BrickColor name, must match the Team in Teams
	Tagline: string,
	Description: string,
	Color: Color3,
	Accent: Color3,
	Powers: { string },
	StartZone: string,
	MissionZone: string,
}

local RaceConfig = {}

RaceConfig.Races = {
	{
		Name = "Vampire",
		Plural = "Vampires",
		TeamName = "Vampires",
		TeamColor = "Crimson",
		Tagline = "Feed. Fly. Rule the night.",
		Description = "Fast, fragile at dawn, deadly at dusk. Drain enemies to heal and grow stronger.",
		Color = Color3.fromRGB(140, 20, 35),
		Accent = Color3.fromRGB(255, 60, 80),
		Powers = { "Blood Drain", "Bat Form", "Night Veil" },
		StartZone = "Castle Noctis",
		MissionZone = "Crimson Crypts",
	},
	{
		Name = "Wolf",
		Plural = "Wolves",
		TeamName = "Wolves",
		TeamColor = "Bright orange",
		Tagline = "The pack hunts together.",
		Description = "Brutal melee and raw speed. Stronger near packmates and under the full moon.",
		Color = Color3.fromRGB(90, 60, 30),
		Accent = Color3.fromRGB(255, 150, 60),
		Powers = { "Feral Lunge", "Howl of the Pack", "Blood Scent" },
		StartZone = "Moonfang Forest",
		MissionZone = "Howling Hollow",
	},
	{
		Name = "Witch",
		Plural = "Witches",
		TeamName = "Witches",
		TeamColor = "Royal purple",
		Tagline = "Hex first. Ask never.",
		Description = "Ranged curses, traps and potions. Weak up close, lethal from a distance.",
		Color = Color3.fromRGB(70, 25, 110),
		Accent = Color3.fromRGB(190, 90, 255),
		Powers = { "Hex Bolt", "Cauldron Trap", "Broom Dash" },
		StartZone = "Hexwood Coven",
		MissionZone = "Thornveil Marsh",
	},
	{
		Name = "Human",
		Plural = "Humans",
		TeamName = "Humans",
		TeamColor = "Bright blue",
		Tagline = "Steel, gold and grit.",
		Description = "Balanced fighters with crafted gear. Earn the most gold and build the best weapons.",
		Color = Color3.fromRGB(40, 70, 130),
		Accent = Color3.fromRGB(90, 160, 255),
		Powers = { "Silver Volley", "Shield Wall", "War Horn" },
		StartZone = "Aldermere Keep",
		MissionZone = "Ironfield Outpost",
	},
	{
		Name = "Monk",
		Plural = "Monks",
		TeamName = "Monks",
		TeamColor = "Bright yellow",
		Tagline = "Still mind. Striking fist.",
		Description = "Martial arts and inner energy. Chain combos, deflect attacks and heal allies.",
		Color = Color3.fromRGB(150, 120, 40),
		Accent = Color3.fromRGB(255, 220, 90),
		Powers = { "Palm Strike", "Iron Meditation", "Spirit Step" },
		StartZone = "Jade Monastery",
		MissionZone = "Serene Summit",
	},
} :: { Race }

function RaceConfig.GetByName(name: string): Race?
	for _, race in RaceConfig.Races do
		if race.Name == name then
			return race
		end
	end
	return nil
end

function RaceConfig.GetIndex(name: string): number?
	for i, race in RaceConfig.Races do
		if race.Name == name then
			return i
		end
	end
	return nil
end

return RaceConfig
