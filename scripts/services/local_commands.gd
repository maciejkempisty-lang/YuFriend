class_name LocalCommands
extends RefCounted

const ALIASES := {"come": ["przyjdz", "do mnie", "chodz", "chodz tutaj"],
	"sit": ["siad", "usiadz", "siadaj"], "paw": ["lapa", "daj lape", "podaj lape"]}

static func interpret(text: String) -> String:
	var value := text.to_lower().strip_edges()
	for pair in [["ą", "a"], ["ć", "c"], ["ę", "e"], ["ł", "l"], ["ń", "n"], ["ó", "o"], ["ś", "s"], ["ź", "z"], ["ż", "z"]]:
		value = value.replace(pair[0], pair[1])
	for mark in ["!", "?", ".", ","]:
		value = value.replace(mark, "")
	for key in ALIASES:
		if ALIASES[key].has(value): return key
	return ""
