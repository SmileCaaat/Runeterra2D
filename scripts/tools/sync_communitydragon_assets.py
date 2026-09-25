#!/usr/bin/env python3
"""Sync explicitly configured CommunityDragon hero HUD portraits.

CommunityDragon is a development-time source only. The game loads the local
files recorded in asset_manifest.csv; it never requests CommunityDragon.
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import io
import json
import os
import re
import sys
import tempfile
import time
from datetime import datetime, timezone
from pathlib import Path, PurePosixPath
from typing import Any
from urllib.error import HTTPError, URLError
from urllib.parse import urlsplit
from urllib.request import Request, urlopen


ROOT = Path(__file__).resolve().parents[2]
SOURCES_PATH = ROOT / "data/external/communitydragon_sources.json"
LOCK_PATH = ROOT / "data/external/communitydragon.lock.json"
MANIFEST_PATH = ROOT / "data/source/asset_manifest.csv"
OUTPUT_ROOT = Path("assets/external/communitydragon/champions")
CHAMPION_JSON_ROOT = "plugins/rcp-be-lol-game-data/global/default/v1/champions"
ASSET_ROOT = "plugins/rcp-be-lol-game-data/global/default"
ASSET_PREFIX = "/lol-game-data/assets/"
USER_AGENT = "Runeterra2D-CommunityDragon-Sync/1.0 (+development asset sync)"
HTTP_TIMEOUT_SECONDS = 20
RETRY_COUNT = 3
RETRY_DELAY_SECONDS = 0.5
ALLOWED_IMAGE_EXTENSIONS = {".png", ".jpg", ".jpeg", ".webp"}
SAFE_UNIT_ID = re.compile(r"^[a-z0-9][a-z0-9_]*$")


class SyncError(RuntimeError):
    pass


def read_json(path: Path) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise SyncError(f"Cannot read {path}: {exc}") from exc
    if not isinstance(value, dict):
        raise SyncError(f"Expected a JSON object in {path}")
    return value


def request_bytes(url: str) -> bytes:
    request = Request(url, headers={"User-Agent": USER_AGENT, "Accept": "application/json,image/*,*/*;q=0.8"})
    last_error: Exception | None = None
    for attempt in range(RETRY_COUNT):
        try:
            with urlopen(request, timeout=HTTP_TIMEOUT_SECONDS) as response:
                status = getattr(response, "status", 200)
                if status < 200 or status >= 300:
                    raise SyncError(f"HTTP {status} for {url}")
                data = response.read()
                if not data:
                    raise SyncError(f"Empty response from {url}")
                return data
        except (HTTPError, URLError, TimeoutError, OSError, SyncError) as exc:
            last_error = exc
            if attempt + 1 < RETRY_COUNT:
                time.sleep(RETRY_DELAY_SECONDS * (attempt + 1))
    raise SyncError(f"Request failed after {RETRY_COUNT} attempts for {url}: {last_error}")


def select_skin(champion: dict[str, Any], selector: dict[str, Any]) -> dict[str, Any]:
    skins = champion.get("skins")
    if not isinstance(skins, list):
        raise SyncError("Champion JSON has no skins array")
    selector_type = selector.get("type")
    if selector_type == "base":
        matches = [skin for skin in skins if isinstance(skin, dict) and skin.get("isBase") is True]
    elif selector_type == "id":
        value = selector.get("value")
        try:
            skin_id = int(value)
        except (TypeError, ValueError) as exc:
            raise SyncError("skin_selector.value must be a numeric skin id when type=id") from exc
        matches = [skin for skin in skins if isinstance(skin, dict) and skin.get("id") == skin_id]
    elif selector_type == "name":
        value = selector.get("value")
        if not isinstance(value, str) or not value.strip():
            raise SyncError("skin_selector.value must be a non-empty name when type=name")
        matches = [skin for skin in skins if isinstance(skin, dict) and str(skin.get("name", "")).casefold() == value.strip().casefold()]
    else:
        raise SyncError(f"Unsupported skin_selector.type: {selector_type!r}")
    if len(matches) != 1:
        raise SyncError(f"Skin selector {selector!r} matched {len(matches)} entries; refusing to guess")
    return matches[0]


def cdragon_asset_url(base_url: str, channel: str, source_path: str) -> str:
    if not source_path.startswith(ASSET_PREFIX):
        raise SyncError(f"Unsupported CommunityDragon asset path (expected {ASSET_PREFIX}...): {source_path}")
    relative = source_path[len(ASSET_PREFIX):]
    pure = PurePosixPath(relative)
    if not relative or pure.is_absolute() or ".." in pure.parts:
        raise SyncError(f"Unsafe CommunityDragon asset path: {source_path}")
    return f"{base_url.rstrip('/')}/{channel}/{ASSET_ROOT}/{relative.lower()}"


def resolve_portrait_plan(base_url: str, channel: str, unit_id: str, config: dict[str, Any]) -> dict[str, Any]:
    if not SAFE_UNIT_ID.fullmatch(unit_id):
        raise SyncError(f"Unsafe unit id in sources config: {unit_id!r}")
    try:
        champion_id = int(config["champion_id"])
        alias = str(config["champion_alias"]).strip().casefold()
        selector = config["skin_selector"]
        assets = config["assets"]
    except (KeyError, TypeError, ValueError) as exc:
        raise SyncError(f"Invalid sources entry for {unit_id}: {exc}") from exc
    if not isinstance(selector, dict) or not isinstance(assets, dict):
        raise SyncError(f"Invalid skin_selector/assets object for {unit_id}")
    if assets.get("hud_portrait") is not True:
        raise SyncError(f"{unit_id} is selected for sync but assets.hud_portrait is not true")

    json_url = f"{base_url.rstrip('/')}/{channel}/{CHAMPION_JSON_ROOT}/{champion_id}.json"
    try:
        champion = json.loads(request_bytes(json_url).decode("utf-8-sig"))
    except (UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise SyncError(f"Invalid champion JSON from {json_url}: {exc}") from exc
    if not isinstance(champion, dict):
        raise SyncError(f"Champion JSON is not an object: {json_url}")
    if int(champion.get("id", -1)) != champion_id:
        raise SyncError(f"Champion JSON id mismatch: expected {champion_id}, got {champion.get('id')!r}")
    if alias and str(champion.get("alias", "")).casefold() != alias:
        raise SyncError(f"Champion alias mismatch for {unit_id}: expected {alias!r}, got {champion.get('alias')!r}")

    skin = select_skin(champion, selector)
    source_path = skin.get("tilePath")
    if not source_path and skin.get("isBase") is True:
        source_path = champion.get("squarePortraitPath")
    if not isinstance(source_path, str) or not source_path:
        raise SyncError(f"Selected skin for {unit_id} has no tilePath or base squarePortraitPath")
    remote_url = cdragon_asset_url(base_url, channel, source_path)
    extension = PurePosixPath(urlsplit(remote_url).path).suffix.lower()
    if extension not in ALLOWED_IMAGE_EXTENSIONS:
        raise SyncError(f"Unsupported portrait file extension {extension!r} for {remote_url}")
    local_path = (OUTPUT_ROOT / unit_id / f"portrait_hud{extension}").as_posix()
    return {
        "unit_id": unit_id,
        "asset_id": f"{unit_id}_hud_portrait",
        "champion_id": champion_id,
        "skin_id": int(skin["id"]),
        "skin_name": str(skin.get("name", "")),
        "kind": "hud_portrait",
        "source_path": source_path,
        "source_url": remote_url,
        "local_path": local_path,
    }


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def download_atomic(url: str, destination: Path) -> tuple[str, int]:
    """Download to a sibling temp file and replace only after validation."""
    destination.parent.mkdir(parents=True, exist_ok=True)
    fd, temp_name = tempfile.mkstemp(prefix=f".{destination.name}.", suffix=".tmp", dir=destination.parent)
    temp_path = Path(temp_name)
    try:
        digest = hashlib.sha256()
        size = 0
        with os.fdopen(fd, "wb") as output:
            request = Request(url, headers={"User-Agent": USER_AGENT, "Accept": "image/*,*/*;q=0.8"})
            last_error: Exception | None = None
            for attempt in range(RETRY_COUNT):
                try:
                    with urlopen(request, timeout=HTTP_TIMEOUT_SECONDS) as response:
                        status = getattr(response, "status", 200)
                        if status < 200 or status >= 300:
                            raise SyncError(f"HTTP {status} for {url}")
                        while True:
                            chunk = response.read(1024 * 128)
                            if not chunk:
                                break
                            output.write(chunk)
                            digest.update(chunk)
                            size += len(chunk)
                    last_error = None
                    break
                except (HTTPError, URLError, TimeoutError, OSError, SyncError) as exc:
                    last_error = exc
                    if attempt + 1 < RETRY_COUNT:
                        output.seek(0)
                        output.truncate(0)
                        digest = hashlib.sha256()
                        size = 0
                        time.sleep(RETRY_DELAY_SECONDS * (attempt + 1))
            if last_error is not None:
                raise SyncError(f"Download failed after {RETRY_COUNT} attempts for {url}: {last_error}") from last_error
            output.flush()
            os.fsync(output.fileno())
        if size <= 0 or temp_path.stat().st_size <= 0:
            raise SyncError(f"Downloaded file is empty: {url}")
        hexdigest = digest.hexdigest()
        os.replace(temp_path, destination)
        return hexdigest, size
    except Exception:
        try:
            temp_path.unlink(missing_ok=True)
        finally:
            raise


def manifest_rows(path: Path) -> tuple[list[str], list[dict[str, str]]]:
    try:
        with path.open("r", encoding="utf-8-sig", newline="") as source:
            reader = csv.DictReader(source)
            if reader.fieldnames is None:
                raise SyncError(f"CSV has no header: {path}")
            return list(reader.fieldnames), [dict(row) for row in reader]
    except OSError as exc:
        raise SyncError(f"Cannot read asset manifest {path}: {exc}") from exc


def upsert_manifest_portraits(path: Path, plans: list[dict[str, Any]]) -> None:
    """Upsert only configured portrait records, preserving unrelated CSV rows."""
    text = path.read_text(encoding="utf-8-sig")
    newline = "\r\n" if "\r\n" in text else "\n"
    lines = text.splitlines(keepends=True)
    rows = list(csv.reader(io.StringIO(text, newline="")))
    if not rows:
        raise SyncError(f"CSV has no header: {path}")
    header = rows[0]
    if not {"asset_id", "asset_type", "resource_path"}.issubset(header):
        raise SyncError(f"Asset manifest is missing required columns: {path}")
    id_index, type_index, path_index = (header.index(name) for name in ("asset_id", "asset_type", "resource_path"))
    line_by_id: dict[str, int] = {}
    for line_index, line in enumerate(lines[1:], start=1):
        if not line.strip():
            continue
        record = next(csv.reader([line], skipinitialspace=False), [])
        if len(record) > id_index:
            line_by_id[record[id_index]] = line_index

    updates: dict[int, str] = {}
    additions: list[str] = []
    for plan in plans:
        asset_id = str(plan["asset_id"])
        resource_path = f"res://{plan['local_path']}"
        line_index = line_by_id.get(asset_id)
        if line_index is None:
            record = [""] * len(header)
            record[id_index] = asset_id
            record[type_index] = "hero_portrait"
            record[path_index] = resource_path
            buffer = io.StringIO(newline="")
            csv.writer(buffer, lineterminator="").writerow(record)
            additions.append(buffer.getvalue() + newline)
            continue
        record = next(csv.reader([lines[line_index]], skipinitialspace=False))
        if len(record) <= max(id_index, type_index, path_index):
            record.extend([""] * (max(id_index, type_index, path_index) + 1 - len(record)))
        if record[type_index] != "hero_portrait":
            raise SyncError(f"Refusing to repurpose {asset_id}: manifest asset_type is {record[type_index]!r}, expected 'hero_portrait'")
        if record[path_index] != resource_path:
            record[path_index] = resource_path
            buffer = io.StringIO(newline="")
            csv.writer(buffer, lineterminator="").writerow(record)
            old_ending = "\r\n" if lines[line_index].endswith("\r\n") else ("\n" if lines[line_index].endswith("\n") else "")
            updates[line_index] = buffer.getvalue() + old_ending
    for line_index, value in updates.items():
        lines[line_index] = value
    if additions:
        if lines and not lines[-1].endswith(("\n", "\r")):
            lines[-1] += newline
        lines.extend(additions)
    new_text = "".join(lines)
    if new_text != text:
        path.write_text(new_text, encoding="utf-8", newline="")


def local_sha256(path: Path) -> tuple[str, int]:
    digest = hashlib.sha256()
    size = 0
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 128), b""):
            size += len(chunk)
            digest.update(chunk)
    return digest.hexdigest(), size


def verify_lock(lock: dict[str, Any], hero_filter: set[str] | None = None) -> bool:
    assets = lock.get("assets")
    if not isinstance(assets, dict):
        raise SyncError("Lock file has no assets object")
    selected = [(asset_id, asset) for asset_id, asset in assets.items() if hero_filter is None or asset.get("unit_id") in hero_filter]
    if not selected:
        raise SyncError("Lock contains no matching CommunityDragon assets to verify")
    ok = True
    for asset_id, asset in selected:
        path = ROOT / str(asset.get("local_path", ""))
        expected_hash = str(asset.get("sha256", ""))
        expected_size = int(asset.get("size", 0))
        try:
            actual_hash, actual_size = local_sha256(path)
        except OSError as exc:
            print(f"FAIL {asset_id}: missing/unreadable file {path}: {exc}")
            ok = False
            continue
        if actual_size <= 0:
            print(f"FAIL {asset_id}: file is empty: {path}")
            ok = False
        elif actual_size != expected_size or actual_hash != expected_hash:
            print(f"FAIL {asset_id}: integrity mismatch (size {actual_size}/{expected_size}, sha256 {actual_hash}/{expected_hash})")
            ok = False
        else:
            print(f"OK   {asset_id}: {path.relative_to(ROOT).as_posix()} ({actual_size} bytes, SHA256 {actual_hash})")
    return ok


def write_json_atomic(path: Path, data: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    payload = json.dumps(data, ensure_ascii=False, indent=2) + "\n"
    fd, temp_name = tempfile.mkstemp(prefix=f".{path.name}.", suffix=".tmp", dir=path.parent)
    temp = Path(temp_name)
    try:
        with os.fdopen(fd, "w", encoding="utf-8", newline="\n") as stream:
            stream.write(payload)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temp, path)
    except Exception:
        temp.unlink(missing_ok=True)
        raise


def sync(config: dict[str, Any], lock: dict[str, Any], selected_heroes: list[str], dry_run: bool, force: bool) -> bool:
    base_url = str(config.get("base_url", "https://raw.communitydragon.org")).rstrip("/")
    channel = str(config.get("channel", "latest")).strip("/")
    heroes = config.get("heroes")
    if not isinstance(heroes, dict):
        raise SyncError("sources config must contain a heroes object")
    unknown = [hero for hero in selected_heroes if hero not in heroes]
    if unknown:
        raise SyncError(f"Unknown hero(s) in --hero: {', '.join(unknown)}")
    hero_ids = selected_heroes or list(heroes.keys())
    plans = [resolve_portrait_plan(base_url, channel, hero_id, heroes[hero_id]) for hero_id in hero_ids]
    if dry_run:
        for plan in plans:
            print("\t".join([
                plan["unit_id"], str(plan["champion_id"]), str(plan["skin_id"]), plan["skin_name"],
                plan["source_url"], plan["local_path"],
            ]))
        return True

    existing_assets: dict[str, Any] = lock.setdefault("assets", {})
    new_records: list[dict[str, Any]] = []
    for plan in plans:
        destination = ROOT / plan["local_path"]
        previous = existing_assets.get(plan["asset_id"], {})
        old_path = ROOT / str(previous.get("local_path", "")) if previous.get("local_path") else None
        unchanged = False
        if not force and old_path == destination and destination.is_file() and previous.get("source_url") == plan["source_url"]:
            current_hash, current_size = local_sha256(destination)
            unchanged = current_hash == previous.get("sha256") and current_size == previous.get("size")
        if unchanged:
            print(f"UNCHANGED {plan['asset_id']}: {plan['local_path']}")
            new_records.append(previous)
            continue
        digest, size = download_atomic(plan["source_url"], destination)
        record = {
            **plan,
            "sha256": digest,
            "size": size,
            "synced_at_utc": datetime.now(timezone.utc).isoformat(timespec="seconds").replace("+00:00", "Z"),
        }
        print(f"SYNCED {plan['asset_id']}: {plan['local_path']} ({size} bytes, SHA256 {digest})")
        new_records.append(record)

    upsert_manifest_portraits(MANIFEST_PATH, plans)
    for record in new_records:
        existing_assets[record["asset_id"]] = record
    write_json_atomic(LOCK_PATH, {"schema_version": 1, "assets": existing_assets})
    return True


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--hero", action="append", default=[], help="Hero unit id to sync (repeatable); default: all configured heroes")
    parser.add_argument("--dry-run", action="store_true", help="Resolve and print URLs/paths without writing files")
    parser.add_argument("--verify", action="store_true", help="Verify local files from the lock file without network access")
    parser.add_argument("--force", action="store_true", help="Redownload assets even when their recorded file is unchanged")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    try:
        config = read_json(SOURCES_PATH)
        lock = read_json(LOCK_PATH) if LOCK_PATH.exists() else {"schema_version": 1, "assets": {}}
        if args.verify:
            return 0 if verify_lock(lock, set(args.hero) or None) else 1
        sync(config, lock, args.hero, args.dry_run, args.force)
        return 0
    except SyncError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
