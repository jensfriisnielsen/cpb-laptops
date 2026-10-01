"""Textual TUI for Battleship."""

from typing import Optional

from textual.app import App, ComposeResult
from textual.containers import Horizontal, Vertical
from textual.widgets import Footer, Header, Input, Label, RichLog, Static

from .board import Board
from .protocol import Message


class BoardWidget(Static):
    """Widget that displays a board."""

    board = None
    show_ships = False

    def update_board(self, board: Board, show_ships: bool) -> None:
        self.board = board
        self.show_ships = show_ships
        self.update(board.render(show_ships=show_ships))


class BattleshipApp(App):
    """Main Textual app."""

    CSS = """
    Screen { align: center middle; }
    .boards { height: auto; width: auto; }
    .log { height: 1fr; border: solid green; }
    .right { width: 40%; }
    .left { width: 60%; }
    Label { margin: 1 2; }
    """

    BINDINGS = [
        ("q", "quit", "Afslut"),
    ]

    def __init__(
        self,
        own_board: Board,
        enemy_board: Board,
        outgoing_path: Optional[str],
        manual: bool = False,
    ):
        super().__init__()
        self.own_board = own_board
        self.enemy_board = enemy_board
        self.outgoing_path = outgoing_path
        self.manual = manual
        self.my_turn = True
        self.game_over = False
        self._stop_reader = False
        self._outgoing_fd: Optional[int] = None

    def compose(self) -> ComposeResult:
        yield Header(show_clock=False)
        with Horizontal():
            with Vertical(classes="left"):
                yield Label("[b]Dit bræt[/b]")
                yield BoardWidget(id="own_board")
                yield Label("[b]Modstanderens bræt[/b]")
                yield BoardWidget(id="enemy_board")
            with Vertical(classes="right"):
                yield Label("[b]Log[/b]")
                self.log_widget = RichLog(classes="log")
                yield self.log_widget
                yield Label("[b]Kommando[/b]")
                self.input_widget = Input(placeholder="F.eks. FIRE B2", id="cmd_input")
                yield self.input_widget
                self.status = Static("Status: Dit tur")
                yield self.status
        yield Footer()

    def on_mount(self) -> None:
        self._update_displays()
        self.log_widget.write("Velkommen til Sænke Slagskibe!")
        self.log_widget.write("Indtast koordinat (f.eks. B2) og tryk Enter.")
        if self.manual:
            self.log_widget.write("[b]MANUEL TILSTAND:[/b] Kopier kommandoen fra status og send med ncat.")

    def _update_displays(self) -> None:
        own = self.query_one("#own_board", BoardWidget)
        enemy = self.query_one("#enemy_board", BoardWidget)
        own.update_board(self.own_board, True)
        enemy.update_board(self.enemy_board, False)

    def on_input_submitted(self, event: Input.Submitted) -> None:
        if event.input.id == "cmd_input":
            self.fire_from_input()

    def fire_from_input(self) -> None:
        if self.game_over:
            self.status.update("Spillet er slut!")
            return
        if not self.my_turn:
            self.status.update("Vent på modstanderens tur!")
            return
        raw = self.input_widget.value.strip().upper()
        if not raw:
            return
        if raw.startswith("FIRE "):
            cell = raw[5:].strip()
        elif " " not in raw and len(raw) >= 2:
            cell = raw
        else:
            self.log_widget.write(f"[red]Ugyldig kommando: {raw}[/red]")
            return
        try:
            self.own_board.parse_cell(cell)
        except ValueError as exc:
            self.log_widget.write(f"[red]Ugyldigt koordinat: {exc}[/red]")
            return
        self.send_fire(cell)
        self.input_widget.value = ""

    def _ensure_outgoing_fd(self) -> bool:
        if self._outgoing_fd is not None:
            return True
        if not self.outgoing_path:
            return False
        try:
            import os
            self._outgoing_fd = os.open(
                self.outgoing_path, os.O_WRONLY | os.O_NONBLOCK
            )
            return True
        except OSError:
            return False

    def _write_outgoing(self, data: bytes) -> bool:
        if self.manual:
            return False
        if not self._ensure_outgoing_fd():
            return False
        try:
            import os
            os.write(self._outgoing_fd, data)
            return True
        except (OSError, BrokenPipeError):
            try:
                if self._outgoing_fd is not None:
                    import os
                    os.close(self._outgoing_fd)
            except OSError:
                pass
            self._outgoing_fd = None
            return False

    def send_fire(self, cell: str) -> None:
        msg = Message(action="FIRE", cell=cell)
        line = str(msg)
        if self.manual:
            self.status.update(f"[yellow]MANUEL:[/yellow] send: {line}")
            self.log_widget.write(f"[yellow]Send manuelt:[/yellow] {line}")
            self.my_turn = False
        else:
            if self._write_outgoing(msg.encode()):
                self.log_widget.write(f"[green]Sendt:[/green] {line}")
                self.my_turn = False
                self.status.update("Vent på svar fra modstander...")
            else:
                self.log_widget.write(f"[red]Kunne ikke sende – tjek forbindelsen[/red]")
                self.status.update("Sendefejl – tjek forbindelsen")

    def handle_incoming(self, line: str) -> None:
        self.log_widget.write(f"[cyan]Modtaget:[/cyan] {line.strip()}")
        try:
            msg = Message.parse(line)
        except ValueError as exc:
            self.log_widget.write(f"[red]Ugyldig besked: {exc}[/red]")
            return
        if msg.action == "FIRE":
            if msg.cell:
                result, ship = self.own_board.receive_fire(msg.cell)
                reply = Message(action=result, cell=msg.cell)
                if result == "SUNK" and ship:
                    reply.ship = ship
                self.log_widget.write(f"[red]Modstander affyrede på {msg.cell} => {result}[/red]")
                self.status.update(f"Dit tur – svar automatisk sendt: {reply}")
                self.send_line(str(reply))
                if self.own_board.all_ships_sunk():
                    self.send_line("WIN")
                    self.status.update("[red]Du har tabt![/red]")
                    self.game_over = True
                else:
                    self.my_turn = True
            self._update_displays()
        elif msg.action in ("HIT", "MISS", "SUNK"):
            if msg.cell:
                self.enemy_board.apply_result(msg.cell, msg.action, msg.ship)
                if msg.action == "HIT":
                    self.log_widget.write(f"[green]Du ramte {msg.cell}[/green]")
                elif msg.action == "SUNK":
                    self.log_widget.write(f"[green]Du sænkede et skib på {msg.cell}![/green]")
                else:
                    self.log_widget.write(f"[blue]Miss på {msg.cell}[/blue]")
                self.my_turn = True
                self.status.update("Dit tur")
            self._update_displays()
        elif msg.action == "WIN":
            self.log_widget.write("[green]Du har vundet![/green]")
            self.status.update("[green]Du har vundet![/green]")
            self.game_over = True

    def send_line(self, line: str) -> None:
        if self.manual:
            self.status.update(f"[yellow]MANUEL:[/yellow] send: {line}")
            self.log_widget.write(f"[yellow]Send manuelt:[/yellow] {line}")
        else:
            ok = self._write_outgoing((line + "\n").encode("utf-8"))
            if not ok:
                self.log_widget.write(f"[red]Kunne ikke sende svar[/red]")
