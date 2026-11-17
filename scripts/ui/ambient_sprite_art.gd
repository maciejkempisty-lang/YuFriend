class_name AmbientSpriteArt
extends RefCounted

# Small pixel-native sprites on the same three-unit grid as the room and yard.
# Textures are built once; animation only switches frames and moves Sprite2D.
const PALETTE := {"o": "574b3a", "b": "8b6949", "t": "b18a60", "c": "eddbb4", "e": "263b35", "y": "dba95a", "w": "f6edcf", "r": "bb704d", "a": "e5a25e", "h": "f5ce84"}
const BIRD := [
	[
		"................", "................", "................", "................",
		".........ooo....", "........ottbo...", ".......otwcye...", "......obtceoyy..",
		"..o..obbbcco....", ".obootobbbco....", "..obbtobbbco....", "...obttccco.....",
		"....occcco......", ".....oooo.......", ".....y..y.......", "....yy.yy.......",
	],
	[
		"................", "................", "................", "................",
		"................", "................", "......oooo......", ".....otbbbo.....",
		"..o.obbbbbtoo...", ".oboobbbbtocco..", "..obbtbbtocweo..", "...obttccoccyy..",
		"....occccoo.y...", ".....oooo.......", ".....y..y.......", "....yy.yy.......",
	],
	[
		".....oo.........", "....obbo........", "....obtbo.......", "....obttbo......",
		".....obtbbooo...", ".....obbottbbo..", "......obtwcyeo..", "......obtceoyy..",
		"..ooooobbbco....", ".obbbttbcco.....", "..ooobccco......", ".....oooo.......",
		"................", "................", "................", "................",
	],
	[
		"................", "................", "................", "................",
		".........ooo....", "........ottbo...", ".......otwcye...", "......obtceoyy..",
		"..ooooobbbco....", ".obbbttbbcco....", "..ooobbttco.....", ".....obbbo......",
		"......obbo......", ".......obo......", "........o.......", "................",
	],
]
const BUTTERFLY := [
	[
		"................",
		"................",
		".....o....o.....",
		"......o..o......",
		"..ooo..oo..ooo..",
		".orhro.oo.orhro.",
		".raharoeeorahar.",
		".raaaroeeoraaar.",
		"..raaarooraaar..",
		"...orr.oo.rro...",
		"..orahroorharo..",
		"..raharoorahar..",
		"...orr.oo.rro...",
		"....o..oo..o....",
		"................",
		"................",
	],
	[
		"................",
		"................",
		".....o....o.....",
		"......o..o......",
		".....o.oo.o.....",
		"....orooooro....",
		"....oaheehao....",
		".....raeear.....",
		".....raooar.....",
		"......oooo......",
		".....oaooao.....",
		".....orooro.....",
		"......oooo......",
		".......oo.......",
		"................",
		"................",
	],
]

const SNAIL := [
	[
		"................", "................", "................", "................",
		"................", "................", "....oooo........", "...oyhhyo.......",
		"..oyobbhyo......", "..oyohboyo.o..o.", "..oyobboyo..oo..", "...oyyyyo...cc..",
		"...oooooo..occo.", "..occcccccoceco.", ".occcccccccccco.", "..oooooooooooo..",
	],
	[
		"................", "................", "................", "................",
		"................", "................", "....oooo........", "...oyhhyo.......",
		"..oyobbhyo......", "..oyohboyo..o.o.", "..oyobboyo...o..", "...oyyyyo...cc..",
		"...oooooo..occo.", "...occccccoceco.", "..occccccccccco.", "...ooooooooooo..",
	],
	[
		"................", "................", "................", "................",
		"................", "................", "....oooo........", "...oyhhyo.......",
		"..oyobbhyo......", "..oyohboyo......", "..oyobboyo......", "...oyyyyo.......",
		"...oooooo.......", "...occcco.......", "..occcccco......", "...oooooo.......",
	],
]
const SQUIRREL := [
	[
		"..ooo...........", ".orhro..........", "orhhro..........", "orhro...........",
		"orrro.....o..o..", "orrro....orooro.", ".orrro...orrro..", "..orrro..orheo..",
		"...orrroorrrco..", "....orrrrrrccoo.", "....orrrrcccco..", ".....orrrccco...",
		".....orrrrro....", "....oro..oro....", "...oro....oro...", "...oo......oo...",
	],
	[
		".ooo............", "orhro...........", "orhhro..........", ".orhro..........",
		".orrro....o..o..", "..orrro..orooro.", "..orrro..orrro..", "...orrro.orheo..",
		"....orrroorrco..", "....orrrrrrccoo.", "....orrrrcccco..", ".....orrrccco...",
		".....orrrrro....", "......ororo.....", ".....orororo....", ".....oo..oo.....",
	],
	[
		"..ooo...........", ".orhro..........", "orhhro..........", "orhro.....o..o..",
		"orrro....orooro.", "orrro....orrro..", ".orrro...orheo..", "..orrro..orrco..",
		"...orrroorrccoo.", "....orrrrrccco..", "....orrrrccco...", "....orrrrcco....",
		"....orrrrroo....", ".....orrrro.....", ".....orooro.....", ".....oo..oo.....",
	],
]

static func frames(butterfly: bool) -> Array[Texture2D]:
	return make_frames(BUTTERFLY if butterfly else BIRD)

static func make_frames(source: Array) -> Array[Texture2D]:
	var result: Array[Texture2D] = []
	for rows in source:
		var image := Image.create(16, 16, false, Image.FORMAT_RGBA8)
		image.fill(Color.TRANSPARENT)
		for y in 16:
			for x in mini(16, rows[y].length()):
				var pixel: String = rows[y][x]
				if PALETTE.has(pixel): image.set_pixel(x, y, Color(PALETTE[pixel]))
		result.append(ImageTexture.create_from_image(image))
	return result
