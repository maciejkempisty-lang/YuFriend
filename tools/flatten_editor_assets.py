"""Move editor artwork into one flat PNG directory and update source paths.

Run once from the repository root. Existing names gain their previous directory
prefix, so similarly named home and yard assets remain distinct.
"""

from __future__ import annotations

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
EDITOR = ROOT / "level-editor/assets"
TEXT_SUFFIXES = {".gd", ".js", ".json", ".md", ".py", ".cfg", ".html", ".import", ".txt", ".ts", ".mjs"}


def target_for(path: Path) -> Path:
    if path.is_relative_to(EDITOR):
        parts = path.relative_to(EDITOR).parts
        name = "-".join(part.replace(" ", "_") for part in parts)
    else:
        parts = path.relative_to(ROOT / "assets/art").parts
        if parts[:2] == ("yard", "sprites"):
            name = "yard-" + parts[-1]
        elif parts[:2] == ("home", "sprites"):
            name = "home-" + parts[-1]
        else:
            name = "environment-" + parts[-1]
    return EDITOR / name


def main() -> None:
    sources = [p for p in EDITOR.rglob("*.png") if p.parent != EDITOR]
    for folder in ("yard/sprites", "home/sprites", "environments"):
        sources += list((ROOT / "assets/art" / folder).glob("*.png"))
    mapping = {source: target_for(source) for source in sources}
    targets = list(mapping.values())
    if len(set(targets)) != len(targets) or any(p.exists() for p in targets):
        raise RuntimeError("Asset filename collision; no files moved")

    replacements = {
        source.relative_to(ROOT).as_posix(): target.relative_to(ROOT).as_posix()
        for source, target in mapping.items()
    }
    for source, target in mapping.items():
        target.parent.mkdir(parents=True, exist_ok=True)
        source.rename(target)
        meta = source.with_name(source.name + ".import")
        if meta.exists():
            meta.rename(target.with_name(target.name + ".import"))

    atlas_dir = ROOT / "level-editor/atlases"
    for atlas in EDITOR.rglob("atlas.json"):
        atlas_dir.mkdir(exist_ok=True)
        rel = atlas.relative_to(EDITOR)
        atlas.rename(atlas_dir / ("-".join(part.replace(" ", "_") for part in rel.parts[:-1]) + ".json"))

    excluded = {".git", ".godot", "node_modules", "Pods", "build", ".gradle", ".next"}
    for parent, dirs, files in __import__("os").walk(ROOT):
        dirs[:] = [d for d in dirs if d not in excluded]
        for name in files:
            path = Path(parent) / name
            if path.suffix not in TEXT_SUFFIXES:
                continue
            try:
                old = path.read_text(encoding="utf-8")
            except (UnicodeError, OSError):
                continue
            new = old
            for before, after in replacements.items():
                new = new.replace(before, after)
            if new != old:
                path.write_text(new, encoding="utf-8")
                print("updated", path.relative_to(ROOT))
    print(f"moved {len(mapping)} PNG files to {EDITOR.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
