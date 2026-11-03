"""Textual TUI for slagskibe — horizontal boards, help overlay, built-in TCP."""

import os
import socket
import threading
from typing import Optional, Tuple

from textual import events
from textual.app import App, ComposeResult
from textual.containers import Horizontal, Vertical, Container
from textual.css.query import NoMatches
from textual.screen import Screen
from textual.widgets import Header, Input, Label, RichLog, Static

from .board import Board
from .protocol import Message


class HelpScreen(Screen):
    """Overlay screen shown when user presses ?."""

    BINDINGS = [
        ("escape", "dismiss_help", "Luk"),
    ]

    def compose(self) -> ComposeResult:
        yield Static(
            "[b]Sænke Slagskibe — Hjælp[/b]\n\n"
            "Skriv et koordinat (f.eks. B2) og tryk Enter for at skyde.\n"
            "Ram modstanderens 5 skibe for de rammer dine!\n\n"
            "  [b].[/b]  = ubeskudt felt\n"
            "  [b]O[/b]  = forbi (miss)\n"
            "  [b]X[/b]  = ramt (hit)\n"
            "  [b]#[/b]  = skib (kun eget braet)\n\n"
            "Tast [b]:[/b] for at bruge kontroltaster (feltet har fokus):\n"
            "  :?       — Vis denne hjaelp\n"
            "  :l       — Vis/skjul log\n"
            "  :q       — Afslut spil\n"
            "  Escape   — Luk hjaelp / annuller :\n\n"
            "[b]Protokol:[/b]\n"
            "  FIRE / HIT / MISS / SUNK / WIN\n"
            "  INVALID = ugyldigt skud (afvises af modstanderen)\n\n"
            "[b]Netvaerk:[/b]\n"
            "  --debug  — Vis ra netvaerkstrafik (tast l)\n"
            "  --log FIL — Skriv trafik til FIL (tail -f FIL)\n"
            "  Server: lytter kun paa eet peer — brug --log for at lytte med\n",
            id="help-text",
        )

    CSS = """
    Screen {
        align: center middle;
        background: $surface;
    }
    #help-text {
        width: 54;
        height: auto;
        border: solid $accent;
        padding: 1 2;
    }
    """

    def action_dismiss_help(self) -> None:
        self.dismiss()


class BoardWidget(Static):
    """Widget that renders a board snapshot."""

    def update_board(self, board: Board, show_ships: bool) -> None:
        self.update(board.render(show_ships=show_ships))


class CommandInput(Input):
    """Input where `:<key>` runs an app command (vim-style).

    The input has focus for typing coordinates, so plain `q`/`l`/`?` would be
    inserted as text. Prefix commands with `:` instead: `:q` quit, `:?` help,
    `:l` log. `:` is only treated as a prefix at the start of an empty field.
    """

    def __init__(self, *args, **kwargs) -> None:
        super().__init__(*args, **kwargs)
        self._cmd_mode = False

    def _leave_cmd_mode(self) -> None:
        self._cmd_mode = False
        self.value = ""
        self.placeholder = "F.eks. B2"

    async def _on_key(self, event: events.Key) -> None:
        if self._cmd_mode:
            self._leave_cmd_mode()
            app = self.app
            key = event.key
            if key == "q":
                app.action_quit()
            elif key in ("question_mark", "?"):
                app.action_show_help()
            elif key == "l":
                app.action_toggle_log()
            elif key == "escape":
                pass  # bare annuller
            event.stop()
            event.prevent_default()
            return

        if event.is_printable and event.character == ":":
            self._cmd_mode = True
            self.value = ""
            self.placeholder = ":q=afslut  :?=hjaelp  :l=log"
            event.stop()
            event.prevent_default()
            return

        await super()._on_key(event)


# ---------------------------------------------------------------------------
# Optional file-based debug logging (set SLAGSKIBE_DEBUG_LOG=/path/to/file)
# ---------------------------------------------------------------------------

_DEBUG_LOG_PATH = os.environ.get("SLAGSKIBE_DEBUG_LOG", "")


def _dbg(msg: str) -> None:
    if not _DEBUG_LOG_PATH:
        return
    try:
        with open(_DEBUG_LOG_PATH, "a", encoding="utf-8") as fh:
            fh.write(msg + "\n")
    except Exception:
        pass


# ---------------------------------------------------------------------------
# Network helpers (used in the server/client thread methods below)
# ---------------------------------------------------------------------------

def _get_local_ip() -> str:
    """Try to get a plausible non-loopback IP for the wait string."""
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.settimeout(0.1)
        s.connect(("8.8.8.8", 80))
        ip = s.getsockname()[0]
        s.close()
        return ip
    except Exception:
        pass
    return socket.getfqdn()


# ---------------------------------------------------------------------------
# Main app
# ---------------------------------------------------------------------------

class BattleshipApp(App):
    """Main Textual app with horizontal boards and built-in TCP."""

    TITLE = "Sænke Slagskibe"

    CSS = """
    Screen {
        layout: vertical;
    }
    #top-row {
        height: auto;
        layout: horizontal;
    }
    .board-box {
        width: 1fr;
        height: auto;
        border: solid $accent;
        padding: 0 1;
        margin: 0 1;
    }
    .board-box > Label {
        text-style: bold;
        text-align: center;
        width: 100%;
    }
    #bottom-row {
        height: auto;
        layout: horizontal;
    }
    .cmd-box {
        width: 1fr;
        height: auto;
        align: center middle;
        padding: 0 1;
        margin: 0 1;
    }
    .response-box {
        width: 1fr;
        height: auto;
        align: center middle;
        padding: 0 1;
        margin: 0 1;
    }
    .response-label {
        text-style: bold;
        text-align: center;
        width: 100%;
    }
    #cmd_input {
        width: 100%;
    }
    #status {
        width: 100%;
        text-align: center;
        margin: 0 0 1 0;
    }
    #latest_response {
        width: 100%;
        text-align: center;
        border: solid $accent;
        padding: 0 1;
        min-height: 3;
    }
    #log-container {
        height: auto;
        max-height: 12;
        display: none;
        border: solid green;
        margin: 0 1;
    }
    #log-container.visible {
        display: block;
    }
    #wait-panel {
        width: 100%;
        height: 100%;
        content-align: center middle;
        text-style: bold;
    }
    #wait-panel.hidden {
        display: none;
    }
    /* Hide the game until a peer connects, so the small wait screen
       fits without scrolling. */
    Screen.waiting #top-row,
    Screen.waiting #bottom-row {
        display: none;
    }
    """

    BINDINGS = [
        ("q", "quit", "Afslut"),
        ("question_mark", "show_help", "Hjaelp"),
        ("l", "toggle_log", "Log"),
    ]

    # (CommandInput class is defined after BoardWidget, below)

    def __init__(
        self,
        own_board: Board,
        enemy_board: Board,
        debug: bool = False,
        bind_port: int = 0,
        connect_to: str = "",
        log_path: str = "",
    ):
        super().__init__()
        self.own_board = own_board
        self.enemy_board = enemy_board
        self._debug = debug
        self._log_path = log_path

        self.my_turn = bool(connect_to)
        self.game_over = False
        self.connected = False
        self._stop_reader = False
        self._conn: Optional[socket.socket] = None
        self._last_fire_cell = ""

        # Network params (used in on_mount to start thread)
        self._bind_port = bind_port
        self._connect_to = connect_to

        if connect_to:
            self._wait_text = f"Forbinder til {connect_to} …"
        elif bind_port:
            self._wait_text = f"Venter på forbindelse (0.0.0.0:{bind_port})"
        else:
            self._wait_text = "Venter på forbindelse …"

        # Widget references (set in compose)
        self.wait_panel: Optional[Static] = None
        self.log_widget: Optional[RichLog] = None
        self.latest_response: Optional[Static] = None
        self.input_widget: Optional[Input] = None
        self.status_widget: Optional[Static] = None
        self._log_visible = False

    # ── Compose ──────────────────────────────────────────────────────────

    def compose(self) -> ComposeResult:
        yield Header(show_clock=False)

        # Wait panel (visible until connected)
        self.wait_panel = Static(self._wait_text, id="wait-panel")
        yield self.wait_panel

        # Main game layout (hidden until connected via CSS)
        with Horizontal(id="top-row"):
            with Vertical(classes="board-box"):
                yield Label("Modstanderens bræt")
                yield BoardWidget(id="enemy_board")
            with Vertical(classes="board-box"):
                yield Label("Dit bræt")
                yield BoardWidget(id="own_board")

        with Horizontal(id="bottom-row"):
            with Vertical(classes="cmd-box"):
                self.status_widget = Static("", id="status")
                yield self.status_widget
                self.input_widget = CommandInput(
                    placeholder="F.eks. B2", id="cmd_input"
                )
                yield self.input_widget
            with Vertical(classes="response-box"):
                yield Static("Seneste svar:", classes="response-label")
                self.latest_response = Static("", id="latest_response")
                yield self.latest_response

        # Log (initially hidden; toggled with l)
        with Container(id="log-container"):
            self.log_widget = RichLog(id="log_widget", highlight=True)
            yield self.log_widget

    # ── Mount ────────────────────────────────────────────────────────────

    def on_mount(self) -> None:
        # Only the wait screen until a peer connects (avoids scrolling).
        self.screen.add_class("waiting")
        self.log_write("Velkommen til Sænke Slagskibe!")
        self.log_write("Venter på netvaerksforbindelse …")
        self._update_displays()
        # Start network thread *after* the app is running so
        # call_from_thread() works.
        self._start_network()

    # ── Network thread startup ───────────────────────────────────────────

    def _start_network(self) -> None:
        if self._connect_to:
            host, _, port_str = self._connect_to.partition(":")
            port = int(port_str)
            t = threading.Thread(
                target=self._client_thread, args=(host, port), daemon=True
            )
        else:
            t = threading.Thread(
                target=self._server_thread, args=(self._bind_port,), daemon=True
            )
        t.start()

    def _server_thread(self, port: int) -> None:
        """Background thread: TCP server, accept one connection."""
        srv = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        srv.bind(("0.0.0.0", port))
        srv.listen(1)

        # Determine local IP for the wait string
        ip = _get_local_ip()
        _dbg(f"SERVER listening on 0.0.0.0:{port} (announcing {ip})")
        self.call_from_thread(
            self.set_wait_string, f"Venter på modstander: ncat {ip} {port}"
        )

        try:
            conn, addr = srv.accept()
        except OSError as exc:
            _dbg(f"SERVER accept failed: {exc!r}")
            return
        srv.close()
        conn.settimeout(None)
        _dbg(f"SERVER accepted {addr!r}")

        self.call_from_thread(self.set_conn, conn)
        self.call_from_thread(self.on_connected, addr)

        try:
            f = conn.makefile("r", encoding="utf-8")
            for line in f:
                line = line.strip()
                _dbg(f"SERVER read {line!r}")
                if line and not self._stop_reader:
                    self.call_from_thread(self.handle_incoming, line)
        except (OSError, EOFError) as exc:
            _dbg(f"SERVER read loop ended: {exc!r}")
        finally:
            _dbg("SERVER closing conn")
            try:
                conn.close()
            except OSError:
                pass

    def _client_thread(self, host: str, port: int) -> None:
        """Background thread: TCP client, connect to server."""
        import time as _time

        conn = None
        for _attempt in range(30):
            try:
                conn = socket.create_connection((host, port), timeout=2)
                break
            except (OSError, socket.timeout):
                _time.sleep(1)

        if conn is None:
            _dbg(f"CLIENT could not connect to {host}:{port}")
            self.call_from_thread(
                self.set_wait_string, f"Kunne ikke forbinde til {host}:{port}"
            )
            return
        # Leave connect-timeout mode: blocking reads for the rest of the game.
        # Otherwise makefile("r") raises TimeoutError after a quiet spell and
        # the read loop dies.
        conn.settimeout(None)
        _dbg(f"CLIENT connected to {host}:{port}")

        self.call_from_thread(self.set_conn, conn)
        self.call_from_thread(self.on_connected, (host, port))

        try:
            f = conn.makefile("r", encoding="utf-8")
            for line in f:
                line = line.strip()
                _dbg(f"CLIENT read {line!r}")
                if line and not self._stop_reader:
                    self.call_from_thread(self.handle_incoming, line)
        except (OSError, EOFError) as exc:
            _dbg(f"CLIENT read loop ended: {exc!r}")
        finally:
            _dbg("CLIENT closing conn")
            conn.close()

    # ── Connection callbacks ─────────────────────────────────────────────

    def set_wait_string(self, text: str) -> None:
        """Called from network thread to update the wait message."""
        self._wait_text = text
        if self.wait_panel:
            self.wait_panel.update(text)

    def on_connected(self, addr: Tuple[str, int]) -> None:
        """Called from network thread when a connection is established."""
        _dbg(f"on_connected {addr!r}")
        self.connected = True
        # Hide wait panel, show game UI
        self.screen.remove_class("waiting")
        if self.wait_panel:
            self.wait_panel.add_class("hidden")
        if self.input_widget:
            self.input_widget.focus()
        self.log_write(f"[green]Forbundet til {addr[0]}:{addr[1]}[/green]")
        if self.my_turn:
            self._set_status("Din tur — skriv et koordinat")
        else:
            self._set_status("Vent på modstanderens tur …")

    def set_conn(self, conn: socket.socket) -> None:
        """Store the socket connection for outgoing messages."""
        _dbg(f"set_conn({conn!r})")
        self._conn = conn

    # ── Logging ──────────────────────────────────────────────────────────

    def log_write(self, msg: str) -> None:
        if self.log_widget:
            self.log_widget.write(msg)

    def action_toggle_log(self) -> None:
        """Toggle the log panel."""
        self._log_visible = not self._log_visible
        try:
            lc = self.query_one("#log-container")
            if self._log_visible:
                lc.add_class("visible")
            else:
                lc.remove_class("visible")
        except NoMatches:
            pass

    # ── Help ─────────────────────────────────────────────────────────────

    def action_show_help(self) -> None:
        self.push_screen(HelpScreen())

    # ── Status ───────────────────────────────────────────────────────────

    def _set_status(self, text: str) -> None:
        if self.status_widget:
            self.status_widget.update(text)

    def _set_response(self, text: str) -> None:
        if self.latest_response:
            self.latest_response.update(text)

    # ── Board display ────────────────────────────────────────────────────

    def _update_displays(self) -> None:
        try:
            own = self.query_one("#own_board", BoardWidget)
            enemy = self.query_one("#enemy_board", BoardWidget)
            own.update_board(self.own_board, True)
            enemy.update_board(self.enemy_board, False)
        except NoMatches:
            pass

    # ── Input handling ───────────────────────────────────────────────────

    def on_input_submitted(self, event: Input.Submitted) -> None:
        if event.input.id == "cmd_input":
            self.fire_from_input()

    def fire_from_input(self) -> None:
        if self.game_over:
            self._set_status("Spillet er slut!")
            return
        if not self.my_turn:
            self._set_status("Vent på modstanderens tur …")
            return
        if not self.connected:
            self._set_status("Venter på netvaerksforbindelse …")
            return

        raw = self.input_widget.value.strip().upper() if self.input_widget else ""
        if not raw:
            return
        if raw.startswith("FIRE "):
            cell = raw[5:].strip()
        elif " " not in raw and len(raw) >= 2:
            cell = raw
        else:
            self._invalid(f"Ugyldig kommando: {raw} (brug f.eks. B2)")
            return
        try:
            self.own_board.parse_cell(cell)
        except ValueError as exc:
            self.log_write(f"[red]Ugyldigt koordinat: {exc}[/red]")
            self._invalid(f"Ugyldigt koordinat: {cell} (brug A1-J10)")
            return
        self.send_fire(cell)
        if self.input_widget:
            self.input_widget.value = ""

    def _invalid(self, message: str) -> None:
        """Visible feedback for a bad local command (log is hidden by default)."""
        self._set_status(f"[red]{message}[/red]")
        self.log_write(f"[red]{message}[/red]")
        if self.input_widget:
            self.input_widget.value = ""

    # ── Network send ─────────────────────────────────────────────────────

    def send_fire(self, cell: str) -> None:
        msg = Message(action="FIRE", cell=cell)
        self._last_fire_cell = cell
        # "Seneste svar" kun opdateres når modparten svarer — ikke af vores eget skud.
        self._send_msg(msg)
        self.my_turn = False
        self._set_status("Vent på svar fra modstander …")

    def send_line(self, line: str) -> None:
        msg = Message.parse(line)
        self._send_msg(msg)

    def _traffic_log(self, direction: str, line: str) -> None:
        """Append raw traffic to --log file so it can be monitored externally."""
        if not self._log_path:
            return
        import datetime

        ts = datetime.datetime.now().strftime("%H:%M:%S.%f")[:-3]
        try:
            with open(self._log_path, "a", encoding="utf-8") as fh:
                fh.write(f"{ts} {direction} {line}\n")
        except Exception:
            pass

    def _send_msg(self, msg: Message) -> None:
        line = str(msg)
        if self._debug:
            self.log_write(f"[yellow]>> {line}[/yellow]")
        self.log_write(f"[green]Sendt:[/green] {line}")
        self._traffic_log(">>", line)
        ok = self._write_socket(line)
        if not ok:
            self.log_write(f"[red]Kunne ikke sende – tjek forbindelsen[/red]")
            self._set_status("Sendefejl – tjek forbindelsen")

    def _write_socket(self, line: str) -> bool:
        if not self._conn:
            return False
        try:
            self._conn.sendall((line + "\n").encode("utf-8"))
            return True
        except OSError as exc:
            _dbg(f"_write_socket OSError: {exc!r}")
            self._conn = None
            return False

    # ── Incoming message handling ───────────────────────────────────────

    def handle_incoming(self, line: str) -> None:
        _dbg(f"handle_incoming {line!r}")
        self._traffic_log("<<", line)
        if self._debug:
            self.log_write(f"[yellow]<< {line.strip()}[/yellow]")
        self.log_write(f"[cyan]Modtaget:[/cyan] {line.strip()}")
        try:
            msg = Message.parse(line)
        except ValueError as exc:
            self.log_write(f"[red]Ugyldig besked: {exc}[/red]")
            return

        if msg.action == "FIRE":
            # Validate the incoming cell before touching the board.
            if not msg.cell:
                self._send_msg(
                    Message(action="INVALID", cell="-", reason="MISSING CELL")
                )
                # "Seneste svar" = vores eget svar til modstanderen.
                self._set_response("INVALID - — ugyldigt skud")
                self._set_status("Ugyldigt skud fra modstander (mangler felt) – venter …")
                self._update_displays()
                return
            try:
                self.own_board.parse_cell(msg.cell)
            except ValueError as exc:
                reason = str(exc).upper().replace(" ", "_")
                self.log_write(
                    f"[red]Ugyldigt skud fra modstander: {msg.cell} ({exc})[/red]"
                )
                self._send_msg(
                    Message(action="INVALID", cell=msg.cell, reason=reason)
                )
                # "Seneste svar" = vores eget svar til modstanderen.
                self._set_response(f"INVALID {msg.cell} — ugyldigt skud")
                # Invalid fire: turns stays with the sender (they retry).
                self._set_status("Ugyldigt skud fra modstander – venter …")
                self._update_displays()
                return

            result, ship = self.own_board.receive_fire(msg.cell)
            reply = Message(action=result, cell=msg.cell)
            if result == "SUNK" and ship:
                reply.ship = ship
            self.log_write(f"[red]Modstander affyrede på {msg.cell} => {result}[/red]")
            # "Seneste svar" = vores eget svar til modstanderens skud.
            if result == "HIT":
                self._set_response(f"HIT {msg.cell} — ramt")
            elif result == "SUNK":
                ship_txt = f" {ship}" if ship else ""
                self._set_response(f"SUNK {msg.cell}{ship_txt} — sænket")
            else:
                self._set_response(f"MISS {msg.cell} — forbi")
            self._set_status(f"Svarer: {reply}")
            self._send_msg(reply)
            if self.own_board.all_ships_sunk():
                self._send_msg(Message(action="WIN"))
                self._set_status("[red]Du har tabt![/red]")
                self.game_over = True
            else:
                self.my_turn = True
                self._set_status("Din tur")
            self._update_displays()

        elif msg.action in ("HIT", "MISS", "SUNK"):
            if msg.cell:
                self.enemy_board.apply_result(msg.cell, msg.action, msg.ship)
                if msg.action == "HIT":
                    self.log_write(f"[green]Du ramte {msg.cell}[/green]")
                elif msg.action == "SUNK":
                    self.log_write(f"[green]Du saenkede et skib på {msg.cell}![/green]")
                else:
                    self.log_write(f"[blue]Miss på {msg.cell}[/blue]")
                # Turn stays with opponent — they got it when they received our FIRE.
                self._set_status("Vent på modstanderens tur …")
            self._update_displays()

        elif msg.action == "INVALID":
            # Our own fire was rejected: take the turn back and let us retry.
            self.log_write(
                f"[red]Modstander afviste skud {msg.cell}: {msg.reason}[/red]"
            )
            self.my_turn = True
            self._set_status("Ugyldigt skud – prøv igen")

        elif msg.action == "WIN":
            self.log_write("[green]Du har vundet![/green]")
            self._set_status("[green]Du har vundet![/green]")
            self.game_over = True

    # ── Quit ─────────────────────────────────────────────────────────────

    def action_quit(self) -> None:
        self._stop_reader = True
        self.exit()