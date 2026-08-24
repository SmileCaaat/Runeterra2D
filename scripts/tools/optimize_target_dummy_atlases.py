from __future__ import annotations

import json
from pathlib import Path

from PIL import Image


PROJECT_ROOT = Path(__file__).resolve().parents[2]
SOURCE_ROOT = PROJECT_ROOT / "assets" / "monsters" / "target_dummy"
ANIMATIONS = ("idle", "hurt", "death", "spawn")
ATLAS_WIDTH = 8192
PADDING = 8


def optimize_animation(animation: str) -> tuple[int, int, int]:
    folder = SOURCE_ROOT / animation
    source_data = json.loads((folder / "spritesheet.json").read_text(encoding="utf-8"))
    source_image = Image.open(folder / "spritesheet.png").convert("RGBA")
    canvas = source_data["meta"]["canvas"]
    canvas_width = int(canvas["width"])
    canvas_height = int(canvas["height"])
    entries = sorted(source_data["frames"].values(), key=lambda item: item["sourceFrameIndex"])

    trimmed_frames: list[dict] = []
    for entry in entries:
        frame = entry["frame"]
        cell = source_image.crop((
            int(frame["x"]),
            int(frame["y"]),
            int(frame["x"] + frame["w"]),
            int(frame["y"] + frame["h"]),
        ))
        alpha_bbox = cell.getchannel("A").getbbox()
        if alpha_bbox is None:
            alpha_bbox = (0, 0, 1, 1)
        left = max(0, alpha_bbox[0] - PADDING)
        top = max(0, alpha_bbox[1] - PADDING)
        right = min(canvas_width, alpha_bbox[2] + PADDING)
        bottom = min(canvas_height, alpha_bbox[3] + PADDING)
        trimmed_frames.append({
            "sourceFrameIndex": int(entry["sourceFrameIndex"]),
            "duration": int(entry.get("duration", 83)),
            "canvas_rect": [left, top, right - left, bottom - top],
            "image": cell.crop((left, top, right, bottom)),
        })

    cursor_x = 0
    cursor_y = 0
    row_height = 0
    used_width = 0
    for frame in trimmed_frames:
        width, height = frame["image"].size
        if cursor_x > 0 and cursor_x + width > ATLAS_WIDTH:
            cursor_x = 0
            cursor_y += row_height
            row_height = 0
        frame["atlas_rect"] = [cursor_x, cursor_y, width, height]
        cursor_x += width
        row_height = max(row_height, height)
        used_width = max(used_width, cursor_x)
    used_height = cursor_y + row_height

    atlas = Image.new("RGBA", (used_width, used_height), (0, 0, 0, 0))
    manifest_frames: list[dict] = []
    for frame in trimmed_frames:
        atlas_x, atlas_y, width, height = frame["atlas_rect"]
        canvas_x, canvas_y, _, _ = frame["canvas_rect"]
        atlas.alpha_composite(frame["image"], (atlas_x, atlas_y))
        manifest_frames.append({
            "sourceFrameIndex": frame["sourceFrameIndex"],
            "duration": frame["duration"],
            "region": {"x": atlas_x, "y": atlas_y, "w": width, "h": height},
            "margin": {
                "x": canvas_x,
                "y": canvas_y,
                "w": canvas_width - width,
                "h": canvas_height - height,
            },
        })

    atlas.save(folder / "runtime_atlas.png", optimize=True)
    manifest = {
        "animation": animation,
        "canvas": canvas,
        "atlas": {"width": used_width, "height": used_height},
        "frames": manifest_frames,
    }
    (folder / "runtime_manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    source_pixels = source_image.width * source_image.height
    runtime_pixels = used_width * used_height
    return source_pixels, runtime_pixels, len(trimmed_frames)


def main() -> None:
    source_total = 0
    runtime_total = 0
    frame_total = 0
    for animation in ANIMATIONS:
        source_pixels, runtime_pixels, frame_count = optimize_animation(animation)
        source_total += source_pixels
        runtime_total += runtime_pixels
        frame_total += frame_count
        print(f"{animation}: {frame_count} frames, {source_pixels:,} -> {runtime_pixels:,} pixels")
    reduction = 1.0 - runtime_total / max(source_total, 1)
    print(
        f"Target Dummy runtime atlases: {frame_total} frames, "
        f"{source_total:,} -> {runtime_total:,} pixels ({reduction:.1%} reduction)"
    )


if __name__ == "__main__":
    main()
