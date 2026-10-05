"""Battleship board logic."""

import random
from dataclasses import dataclass
from typing import Dict, List, Optional, Set, Tuple


@dataclass
class ShipType:
    name: str
    length: int


# Standard ship set
SHIP_TYPES = [
    ShipType("Carrier", 5),
    ShipType("Battleship", 4),
    ShipType("Cruiser", 3),
    ShipType("Submarine", 3),
    ShipType("Destroyer", 2),
]
SHIP_BY_NAME = {s.name: s for s in SHIP_TYPES}


class Board:
    """10×10 Battleship board."""

    SIZE = 10
    COL_LETTERS = "ABCDEFGHIJ"

    def __init__(self):
        # Track placed ships: name -> set of (x, y)
        self.ships: Dict[str, Set[Tuple[int, int]]] = {}
        # Track hits and misses on this board
        self.hits: Set[Tuple[int, int]] = set()
        self.misses: Set[Tuple[int, int]] = set()

    @staticmethod
    def parse_cell(cell: str) -> Tuple[int, int]:
        """Parse 'A1' -> (col=0, row=0). 'J10' -> (9, 9)."""
        cell = cell.strip().upper()
        if len(cell) < 2:
            raise ValueError(f"Invalid cell: {cell}")
        col_letter = cell[0]
        if not ("A" <= col_letter <= "J"):
            raise ValueError(f"Invalid column: {col_letter}")
        col = ord(col_letter) - ord("A")
        row_str = cell[1:]
        if not row_str.isdigit():
            raise ValueError(f"Invalid row: {row_str}")
        row = int(row_str) - 1
        if not (0 <= row < Board.SIZE):
            raise ValueError(f"Row {row + 1} is out of bounds")
        return col, row

    @staticmethod
    def format_cell(col: int, row: int) -> str:
        """Format (col, row) -> 'A1'."""
        if not (0 <= col < Board.SIZE and 0 <= row < Board.SIZE):
            raise ValueError(f"Coordinates out of bounds")
        return f"{chr(ord('A') + col)}{row + 1}"

    @staticmethod
    def ship_cells(
        start: Tuple[int, int], direction: str, length: int
    ) -> List[Tuple[int, int]]:
        """Return cells occupied by a ship."""
        x, y = start
        cells = []
        dx, dy = 0, 0
        d = direction.strip().upper()
        if d in ("H", "HORIZONTAL", "RIGHT"):
            dy = 1
        elif d in ("V", "VERTICAL", "DOWN"):
            dx = 1
        else:
            raise ValueError(f"Unknown direction: {direction}")
        for i in range(length):
            cells.append((x + dx * i, y + dy * i))
        return cells

    def place_ship(self, name: str, start: Tuple[int, int], direction: str) -> None:
        """Place a ship on the board. Raises on error."""
        ship_type = SHIP_BY_NAME.get(name)
        if not ship_type:
            raise ValueError(f"Unknown ship type: {name}")
        cells = self.ship_cells(start, direction, ship_type.length)
        for (x, y) in cells:
            if not (0 <= x < Board.SIZE and 0 <= y < Board.SIZE):
                raise ValueError(f"Ship {name} goes out of bounds")
            for existing, existing_cells in self.ships.items():
                if (x, y) in existing_cells:
                    raise ValueError(
                        f"Ship {name} overlaps with {existing} at {self.format_cell(x, y)}"
                    )
        self.ships[name] = set(cells)

    def place_ship_from_config(self, name: str, cell: str, direction: str) -> None:
        """Place a ship from config cell string."""
        self.place_ship(name, self.parse_cell(cell), direction)

    def receive_fire(self, cell: str) -> Tuple[str, Optional[str]]:
        """
        Handle incoming fire on this board.
        Returns (<HIT|MISS>, ship_name_or_None).
        If the ship is sunk, returns ("SUNK", ship_name).
        """
        col, row = self.parse_cell(cell)
        coord = (col, row)
        if coord in self.hits or coord in self.misses:
            # Already fired here; treat as miss/repeat hit
            for name, cells in self.ships.items():
                if coord in cells:
                    return ("HIT", name)
            return ("MISS", None)

        for name, cells in self.ships.items():
            if coord in cells:
                self.hits.add(coord)
                # Check if ship is fully sunk
                if cells.issubset(self.hits):
                    return ("SUNK", name)
                return ("HIT", name)

        self.misses.add(coord)
        return ("MISS", None)

    def apply_result(self, cell: str, result: str, ship_name: Optional[str] = None) -> None:
        """Record the result of our own shot on the enemy board."""
        col, row = self.parse_cell(cell)
        coord = (col, row)
        if result in ("HIT", "SUNK"):
            self.hits.add(coord)
        elif result == "MISS":
            self.misses.add(coord)

    def all_ships_sunk(self) -> bool:
        """Return True if every ship is sunk."""
        if not self.ships:
            return False
        return all(cells.issubset(self.hits) for cells in self.ships.values())

    def get_ship_length(self, name: str) -> int:
        return SHIP_BY_NAME[name].length

    @classmethod
    def random_layout(cls, seed: Optional[int] = None) -> "Board":
        """Create a Board with all 5 ships placed randomly without overlap."""
        rng = random.Random(seed)
        board = cls()

        for ship in SHIP_TYPES:
            placed = False
            for _attempt in range(1000):
                direction = rng.choice(["H", "V"])
                if direction == "H":
                    start_x = rng.randint(0, cls.SIZE - ship.length)
                    start_y = rng.randint(0, cls.SIZE - 1)
                else:
                    start_x = rng.randint(0, cls.SIZE - 1)
                    start_y = rng.randint(0, cls.SIZE - ship.length)

                try:
                    board.place_ship(ship.name, (start_x, start_y), direction)
                    placed = True
                    break
                except ValueError:
                    continue

            if not placed:
                raise RuntimeError(f"Could not place {ship.name} randomly")

        return board

    def render(self, show_ships: bool = False) -> str:
        """
        Render board as a properly aligned grid.
        
        Uses monospace-friendly characters:
          ·  = unresolved/empty
          #  = ship (only when show_ships=True)
          X  = hit
          O  = miss
        """
        lines = []
        # Header: column letters, each cell is 2 chars wide (char + space)
        header = "   " + " ".join(f" {c}" for c in self.COL_LETTERS)
        lines.append(header)
        for row in range(self.SIZE):
            row_label = f"{row + 1:2d}"
            cells = []
            for col in range(self.SIZE):
                coord = (col, row)
                if coord in self.hits:
                    cells.append("X")
                elif coord in self.misses:
                    cells.append("O")
                elif show_ships:
                    found = False
                    for _, ship_cells in self.ships.items():
                        if coord in ship_cells:
                            cells.append("#")
                            found = True
                            break
                    if not found:
                        cells.append("·")
                else:
                    # Unresolved enemy cell → blank
                    cells.append(" ")
            line = row_label + " " + " ".join(f" {c}" for c in cells)
            lines.append(line)
        return "\n".join(lines)