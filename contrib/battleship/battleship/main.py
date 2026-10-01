"""CLI entry point for the Battleship TUI game."""

import argparse
import os
import threading
import time

from .board import Board
from .config import load_config
from .ui import BattleshipApp


def read_incoming(path: str, app: BattleshipApp) -> None:
    """Background thread reading lines from the incoming fifo/file."""
    # Poll until fifo exists (user has connected ncat)
    while not app._stop_reader:
        try:
            fd = os.open(path, os.O_RDONLY | os.O_NONBLOCK)
            os.close(fd)
            break
        except OSError:
            time.sleep(0.5)

    # Blocking line-oriented reads
    with open(path, "r", encoding="utf-8") as fh:
        for line in fh:
            if app._stop_reader:
                break
            line = line.strip()
            if line:
                try:
                    app.call_from_thread(app.handle_incoming, line)
                except Exception:
                    pass


def run() -> None:
    parser = argparse.ArgumentParser(description="Sænke Slagskibe – TUI-netværksspil")
    parser.add_argument("--config", required=True, help="Sti til ships.yaml/JSON")
    parser.add_argument("--incoming", required=True, help="Sti til fifo/fil med beskeder fra modstander")
    parser.add_argument("--outgoing", required=True, help="Sti til fifo/fil hvor vi skriver beskeder")
    parser.add_argument("--manual", action="store_true", help="Send ikke automatisk – vis kommando i stedet")
    args = parser.parse_args()

    own_board = load_config(args.config)
    enemy_board = Board()

    app = BattleshipApp(
        own_board=own_board,
        enemy_board=enemy_board,
        outgoing_path=args.outgoing,
        manual=args.manual,
    )

    t = threading.Thread(target=read_incoming, args=(args.incoming, app), daemon=True)
    t.start()

    app.run()


if __name__ == "__main__":
    run()
