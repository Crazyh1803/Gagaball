class_name CollisionLayers
extends RefCounted
## 2D physics layer bit values, shared by every scene and by the walls that
## Arena.gd builds at runtime. Names mirror [layer_names] in project.godot.

const WALLS := 1       # layer 1 — octagonal pit boundary
const BALL := 2        # layer 2 — the gaga ball(s)
const CHARACTERS := 4  # layer 3 — player + CPU bodies
const HURTBOXES := 8   # layer 4 — below-the-waist sensors (elimination rule, later)
