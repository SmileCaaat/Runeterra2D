from __future__ import annotations

import json
from pathlib import Path

from PIL import Image


PROJECT_ROOT = Path(__file__).resolve().parents[2]
SOURCE_ROOT = PROJECT_ROOT / "assets" / "monsters" / "scuttle_crab"
ANIMATIONS = ("idle", "run", "hurt", "dash", "spawn")
ATLAS_WIDTH = 8192
PADDING = 8


def optimize_animation(animation: str) -> tuple[int, int, int]:
    folder = SOURCE_ROOT / animation
    data = json.loads((folder / "spritesheet.json").read_text(encoding="utf-8"))
    source = Image.open(folder / "spritesheet.png").convert("RGBA")
    canvas = data["meta"]["canvas"]
    width, height = int(canvas["width"]), int(canvas["height"])
    entries = sorted(data["frames"].values(), key=lambda item: item["sourceFrameIndex"])
    frames: list[dict] = []
    for entry in entries:
        rect = entry["frame"]
        cell = source.crop((rect["x"], rect["y"], rect["x"] + rect["w"], rect["y"] + rect["h"]))
        bbox = cell.getchannel("A").getbbox() or (0, 0, 1, 1)
        left, top = max(0, bbox[0] - PADDING), max(0, bbox[1] - PADDING)
        right, bottom = min(width, bbox[2] + PADDING), min(height, bbox[3] + PADDING)
        frames.append({
            "sourceFrameIndex": int(entry["sourceFrameIndex"]),
            "duration": int(entry.get("duration", 83)),
            "canvas_rect": [left, top, right - left, bottom - top],
            "image": cell.crop((left, top, right, bottom)),
        })
    x = y = row_height = used_width = 0
    for frame in frames:
        frame_width, frame_height = frame["image"].size
        if x and x + frame_width > ATLAS_WIDTH:
            x, y, row_height = 0, y + row_height, 0
        frame["atlas_rect"] = [x, y, frame_width, frame_height]
        x += frame_width
        row_height = max(row_height, frame_height)
        used_width = max(used_width, x)
    used_height = y + row_height
    atlas = Image.new("RGBA", (used_width, used_height), (0, 0, 0, 0))
    manifest_frames: list[dict] = []
    for frame in frames:
        atlas_x, atlas_y, frame_width, frame_height = frame["atlas_rect"]
        canvas_x, canvas_y, _, _ = frame["canvas_rect"]
        atlas.alpha_composite(frame["image"], (atlas_x, atlas_y))
        manifest_frames.append({
            "sourceFrameIndex": frame["sourceFrameIndex"], "duration": frame["duration"],
            "region": {"x": atlas_x, "y": atlas_y, "w": frame_width, "h": frame_height},
            "margin": {"x": canvas_x, "y": canvas_y, "w": width - frame_width, "h": height - frame_height},
        })
    atlas.save(folder / "runtime_atlas.png", optimize=True)
    (folder / "runtime_manifest.json").write_text(json.dumps({
        "animation": animation, "canvas": canvas,
        "atlas": {"width": used_width, "height": used_height}, "frames": manifest_frames,
    }, ensure_ascii=False, indent=2), encoding="utf-8")
    return source.width * source.height, used_width * used_height, len(frames)


def main() -> None:
    source_total = runtime_total = frame_total = 0
    for animation in ANIMATIONS:
        source_pixels, runtime_pixels, frame_count = optimize_animation(animation)
        source_total += source_pixels
        runtime_total += runtime_pixels
        frame_total += frame_count
        print(f"{animation}: {frame_count} frames, {source_pixels:,} -> {runtime_pixels:,} pixels")
    print(f"Scuttle Crab runtime atlases: {frame_total} frames, {source_total:,} -> {runtime_total:,} pixels")


if __name__ == "__main__":
    main()
