extends RefCounted
## Save data written by tests. tools/run_game_tests.py points this at a private
## temporary directory that is removed after the run; direct runs use /tmp.
## Screenshots stay in /tmp so they can be reviewed after a run.

static func data_root() -> String:
	var root := OS.get_environment("YUFRIEND_TEST_ROOT")
	return root if not root.is_empty() else "/tmp"
