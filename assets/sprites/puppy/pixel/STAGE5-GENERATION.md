# Etap 5 — grafiki

Wygenerowano wbudowanym image_gen 17 listopada 2026. Oryginały PNG skopiowano do projektu bez przekształcania kanału alfa.

- `sheets/spin-roll-v1.png`: atlas 1536×1024, 4 klatki obrotu i 4 klatki turlania. Referencja: `sheets/walk.png`. Regiony, podparcie i tempo są w manifeście. To krótkie animacje na obecnej siatce renderowania.
- `level-editor/assets/environment-decor-v1.png`: dywan z łapką, słonecznik i półka z trofeum. `RoomArtwork.DECOR_REGIONS` wyznacza prostokąty obiektów w oryginalnym arkuszu.

## Prompt — sztuczki

Use case stylized-concept. Production transparent pixel-art sprite atlas for YuFriend. Reference is exact character identity and art style: golden puppy, caramel floppy ears, cream muzzle/paws, dark eyes, head tuft. 1536x1024 canvas, exactly 4 columns x 2 rows of 384x512 equal cells without grid or text. Top row four chronological frames of SPIN IN PLACE: facing right, facing viewer, facing left, back to viewer; feet on same baseline at 85% cell height, body centered identically. Bottom row four chronological frames of ROLL OVER: lying on right side, belly up paws in air, lying on other side, returning to standing facing right. Same dog size and colors throughout. Full body with margins. Crisp chunky pixel art, true alpha transparent background, no floor, no shadows, no objects, no glow. These are animations, not four similar walking poses.

## Prompt — dekoracje

Use case stylized-concept. Single production transparent pixel-art decorative furniture sprite atlas for cozy golden-puppy game YuFriend. Three equally spaced cells in one horizontal row on 1536x1024 transparent canvas. Left cell: small oval sage-green floor rug with cream paw-print motif, shallow side-view perspective. Middle cell: terracotta pot holding one cheerful sunflower, side view. Right cell: wooden wall shelf displaying a small golden paw-shaped trophy and two tiny books, front view. Chunky crisp pixel art, warm cream/caramel/sage palette, dark restrained outlines matching cozy retro pet game. Each item entirely isolated within its own one-third cell with generous clear margins. No text, labels, room, floor, shadow, glow or checkerboard; real transparent alpha. Keep assets distinct and usable as sprites.
