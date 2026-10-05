"""Simple text protocol for Battleship."""

from dataclasses import dataclass
from typing import Optional


@dataclass
class Message:
    action: str  # FIRE, HIT, MISS, SUNK, WIN, INVALID
    cell: Optional[str] = None
    ship: Optional[str] = None
    reason: Optional[str] = None  # used by INVALID

    @classmethod
    def parse(cls, line: str) -> "Message":
        """Parse a line like 'FIRE B2' or 'SUNK B2 Destroyer'."""
        parts = line.strip().upper().split()
        if not parts:
            raise ValueError("Empty message")
        action = parts[0]
        cell = None
        ship = None
        reason = None
        if action in ("FIRE", "HIT", "MISS"):
            if len(parts) >= 2:
                cell = parts[1]
        elif action == "SUNK":
            if len(parts) >= 2:
                cell = parts[1]
            if len(parts) >= 3:
                ship = " ".join(parts[2:]).title()
        elif action == "WIN":
            pass
        elif action == "INVALID":
            if len(parts) >= 2:
                cell = parts[1]
            if len(parts) >= 3:
                reason = " ".join(parts[2:])
        else:
            raise ValueError(f"Unknown action: {action}")
        return cls(action, cell, ship, reason)

    def __str__(self) -> str:
        if self.action in ("FIRE", "HIT", "MISS"):
            return f"{self.action} {self.cell}"
        if self.action == "SUNK":
            out = f"SUNK {self.cell}"
            if self.ship:
                out += f" {self.ship.upper()}"
            return out
        if self.action == "INVALID":
            out = f"INVALID {self.cell}"
            if self.reason:
                out += f" {self.reason}"
            return out
        return self.action

    def encode(self) -> bytes:
        return (str(self) + "\n").encode("utf-8")
