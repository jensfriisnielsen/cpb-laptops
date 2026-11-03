"""CLI entry point for slagskibe — Sænke Slagskibe med indbygget TCP."""

import argparse
import sys

from .board import Board
from .config import load_config
from .ui import BattleshipApp


DEFAULT_PORT = 4000


def run() -> None:
    parser = argparse.ArgumentParser(
        description="Sænke Slagskibe – TUI-netvaerksspil med indbygget TCP"
    )
    parser.add_argument(
        "connect",
        nargs="?",
        default=None,
        help="Forbind til server: [vaert]:[port] (f.eks. [IP_ADDRESS]:4000). "
        "Uden argument starter spillet som server.",
    )
    parser.add_argument(
        "--port",
        type=int,
        default=DEFAULT_PORT,
        help=f"TCP-port (server: lyt, klient: forbind). Standard: {DEFAULT_PORT}",
    )
    parser.add_argument(
        "--config", help="Sti til ships.yaml/JSON (udelades for tilfaeldigt layout)"
    )
    parser.add_argument(
        "--debug",
        action="store_true",
        help="Vis rå netvaerkstrafik i et sidepanel (tast 'l')",
    )
    parser.add_argument(
        "--log",
        default="",
        metavar="FIL",
        help="Skriv al rå trafik til FIL (kan foelges med: tail -f FIL). "
        "Praktisk til at lytte med udefra.",
    )
    args = parser.parse_args()

    # --- Board setup ---
    if args.config:
        own_board = load_config(args.config)
    else:
        import random as rmod

        own_board = Board.random_layout(seed=rmod.randrange(1_000_000))
        print(
            "Bemaerk: --config ikke givet — bruger tilfaeldigt skibslayout.",
            file=sys.stderr,
        )

    enemy_board = Board()

    # --- Determine mode ---
    connect_str = args.connect
    if connect_str:
        if ":" in connect_str:
            host, _, port_str = connect_str.partition(":")
            port = int(port_str)
        else:
            host = connect_str
            port = args.port
        connect_to = f"{host}:{port}"
        bind_port = 0
        print(f"Forbinder til {host}:{port} ...", file=sys.stderr)
    else:
        connect_to = ""
        bind_port = args.port
        print(f"Lytter paa port {bind_port} ...", file=sys.stderr)

    # --- App ---
    app = BattleshipApp(
        own_board=own_board,
        enemy_board=enemy_board,
        debug=args.debug,
        bind_port=bind_port,
        connect_to=connect_to,
        log_path=args.log,
    )

    app.run()


if __name__ == "__main__":
    run()