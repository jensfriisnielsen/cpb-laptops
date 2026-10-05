"""Configuration loader for ship placement."""

import json
from pathlib import Path
from typing import Any, Dict, List

from .board import Board


def load_yaml_or_json(path: str) -> Dict[str, Any]:
    raw = Path(path).read_text(encoding="utf-8")
    # Try JSON first (subset of YAML), then YAML if available
    try:
        return json.loads(raw)
    except json.JSONDecodeError:
        try:
            import yaml
            return yaml.safe_load(raw)
        except Exception as exc:
            raise RuntimeError(
                "Could not parse config as JSON or YAML. "
                "You may need pyyaml installed for YAML configs."
            ) from exc


def load_config(path: str) -> Board:
    """Load a Board from a configuration file."""
    data = load_yaml_or_json(path)
    if not isinstance(data, dict):
        raise ValueError("Config must be a dictionary/object")

    ships = data.get("ships")
    if ships is None:
        raise ValueError("Config missing top-level 'ships' list")
    if not isinstance(ships, list):
        raise ValueError("'ships' must be a list")

    board = Board()
    names_used = set()
    for entry in ships:
        if not isinstance(entry, dict):
            raise ValueError(f"Ship entry must be an object: {entry}")
        name = entry.get("name")
        cell = entry.get("cell")
        direction = entry.get("direction", "horizontal")
        if not name or not isinstance(name, str):
            raise ValueError(f"Ship missing name: {entry}")
        if not cell or not isinstance(cell, str):
            raise ValueError(f"Ship {name} missing cell")
        if name in names_used:
            raise ValueError(f"Ship {name} defined more than once")
        names_used.add(name)
        board.place_ship_from_config(name, cell, direction)

    # Validate all required ship types are placed
    from .board import SHIP_TYPES
    required = {s.name for s in SHIP_TYPES}
    missing = required - names_used
    if missing:
        raise ValueError(f"Missing ships in config: {', '.join(sorted(missing))}")

    return board
