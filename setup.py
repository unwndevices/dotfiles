#!/usr/bin/env python3
"""
Dotfiles TUI installer — interactive curses interface for package installation
and dotfile deployment.  No external dependencies; Python 3 stdlib only.

Run directly:  ./setup.py
Via bootstrap: curl -sSL .../setup.sh | bash
"""

import curses
import os
import shutil
import subprocess
import sys
import time
from pathlib import Path

# ── Repo / path constants ────────────────────────────────────────────────────

REPO_ROOT = Path(__file__).resolve().parent
HOME_SRC = REPO_ROOT / "home"
REPO_URL = "https://github.com/unwn/dotfiles.git"

# ── Package lists (mirrored from install_packages.sh) ────────────────────────

PACMAN_PACKAGES = [
    "git", "base-devel", "zsh", "neovim", "kitty",
    "tmux", "github-cli", "lazygit", "yazi", "starship",
]

AUR_PACKAGES = ["claude-code", "oh-my-zsh-git"]

ZSH_PLUGINS = [
    ("https://github.com/zsh-users/zsh-autosuggestions", "zsh-autosuggestions"),
    ("https://github.com/zsh-users/zsh-syntax-highlighting.git", "zsh-syntax-highlighting"),
    ("https://github.com/joshskidmore/zsh-fzf-history-search", "zsh-fzf-history-search"),
]

# ── Rose Pine palette ────────────────────────────────────────────────────────

RP = {
    "base":    (25,  23,  36),
    "surface": (31,  29,  46),
    "overlay": (38,  35,  58),
    "muted":   (110, 106, 134),
    "subtle":  (144, 140, 170),
    "text":    (224, 222, 244),
    "love":    (235, 111, 146),
    "gold":    (246, 193, 119),
    "rose":    (234, 154, 151),
    "pine":    (49,  116, 143),
    "foam":    (156, 207, 216),
    "iris":    (196, 167, 231),
}

# Color-pair IDs
CP_NORMAL   = 1
CP_HEADER   = 2
CP_SELECTED = 3
CP_SUCCESS  = 4
CP_ERROR    = 5
CP_ACCENT   = 6
CP_DIM      = 7
CP_BORDER   = 8
CP_BANNER   = 9
CP_GROUP    = 10

# ── Curses color helpers ─────────────────────────────────────────────────────

_use_256 = False

def _idx(r, g, b):
    """Map 0-255 RGB to the nearest xterm-256 color index (16-231 cube)."""
    ri = round(r / 255 * 5)
    gi = round(g / 255 * 5)
    bi = round(b / 255 * 5)
    return 16 + 36 * ri + 6 * gi + bi


def _init_colors():
    global _use_256
    curses.start_color()
    curses.use_default_colors()
    _use_256 = curses.COLORS >= 256

    if _use_256:
        for name, (r, g, b) in RP.items():
            cid = 20 + list(RP.keys()).index(name)
            curses.init_color(cid, r * 1000 // 255, g * 1000 // 255, b * 1000 // 255)

        bg = 20 + list(RP.keys()).index("base")
        fg = 20 + list(RP.keys()).index("text")
        curses.init_pair(CP_NORMAL,   fg, bg)
        curses.init_pair(CP_HEADER,   20 + list(RP.keys()).index("pine"), bg)
        curses.init_pair(CP_SELECTED, 20 + list(RP.keys()).index("foam"), bg)
        curses.init_pair(CP_SUCCESS,  20 + list(RP.keys()).index("foam"), bg)
        curses.init_pair(CP_ERROR,    20 + list(RP.keys()).index("love"), bg)
        curses.init_pair(CP_ACCENT,   20 + list(RP.keys()).index("gold"), bg)
        curses.init_pair(CP_DIM,      20 + list(RP.keys()).index("muted"), bg)
        curses.init_pair(CP_BORDER,   20 + list(RP.keys()).index("overlay"), bg)
        curses.init_pair(CP_BANNER,   20 + list(RP.keys()).index("iris"), bg)
        curses.init_pair(CP_GROUP,    20 + list(RP.keys()).index("subtle"), bg)
    else:
        curses.init_pair(CP_NORMAL,   curses.COLOR_WHITE, -1)
        curses.init_pair(CP_HEADER,   curses.COLOR_CYAN,  -1)
        curses.init_pair(CP_SELECTED, curses.COLOR_CYAN,  -1)
        curses.init_pair(CP_SUCCESS,  curses.COLOR_GREEN,  -1)
        curses.init_pair(CP_ERROR,    curses.COLOR_RED,    -1)
        curses.init_pair(CP_ACCENT,   curses.COLOR_YELLOW, -1)
        curses.init_pair(CP_DIM,      curses.COLOR_WHITE,  -1)
        curses.init_pair(CP_BORDER,   curses.COLOR_WHITE,  -1)
        curses.init_pair(CP_BANNER,   curses.COLOR_MAGENTA,-1)
        curses.init_pair(CP_GROUP,    curses.COLOR_WHITE,  -1)


def cp(pair_id):
    return curses.color_pair(pair_id)

# ── Drawing helpers ──────────────────────────────────────────────────────────

BANNER = r"""
     _       _    __ _ _
  __| | ___ | |_ / _(_) | ___  ___
 / _` |/ _ \| __| |_| | |/ _ \/ __|
| (_| | (_) | |_|  _| | |  __/\__ \
 \__,_|\___/ \__|_| |_|_|\___||___/
"""


def draw_box(win, y, x, h, w, pair):
    """Draw a Unicode box-drawing border."""
    try:
        win.addstr(y, x,         "┌" + "─" * (w - 2) + "┐", pair)
        for row in range(y + 1, y + h - 1):
            win.addstr(row, x,       "│", pair)
            win.addstr(row, x + w - 1, "│", pair)
        win.addstr(y + h - 1, x, "└" + "─" * (w - 2) + "┘", pair)
    except curses.error:
        pass


def safe_addstr(win, y, x, text, attr=0):
    h, w = win.getmaxyx()
    if y < 0 or y >= h or x >= w:
        return
    available = w - x - 1
    if available <= 0:
        return
    try:
        win.addnstr(y, x, text, available, attr)
    except curses.error:
        pass

# ── Step definitions ─────────────────────────────────────────────────────────

class Step:
    def __init__(self, id_, label, group, fn, skip_check=None):
        self.id = id_
        self.label = label
        self.group = group
        self.fn = fn
        self.selected = True
        self.skip_reason = None
        if skip_check:
            reason = skip_check()
            if reason:
                self.selected = False
                self.skip_reason = reason


def _run(cmd, **kw):
    """Run a command, return (success, output_lines)."""
    lines = []
    try:
        proc = subprocess.Popen(
            cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
            text=True, bufsize=1, **kw,
        )
        for line in proc.stdout:
            lines.append(line.rstrip("\n"))
        proc.wait()
        return proc.returncode == 0, lines
    except FileNotFoundError:
        return False, [f"Command not found: {cmd[0]}"]
    except Exception as e:
        return False, [str(e)]


def _has(cmd):
    return shutil.which(cmd) is not None

# -- individual step functions ------------------------------------------------

def step_install_yay(log):
    if _has("yay"):
        log("yay already installed.")
        return True
    log("Installing yay from AUR...")
    import tempfile
    tmpdir = tempfile.mkdtemp()
    ok, out = _run(["sudo", "pacman", "-S", "--noconfirm", "--needed", "git", "base-devel"])
    for l in out: log(l)
    if not ok:
        return False
    ok, out = _run(["git", "clone", "--depth", "1", "https://aur.archlinux.org/yay.git", "."], cwd=tmpdir)
    for l in out: log(l)
    if not ok:
        return False
    ok, out = _run(["makepkg", "-si", "--noconfirm"], cwd=tmpdir)
    for l in out: log(l)
    shutil.rmtree(tmpdir, ignore_errors=True)
    return ok


def step_install_official(log):
    log(f"Installing {len(PACMAN_PACKAGES)} official packages...")
    ok, out = _run(["sudo", "pacman", "-S", "--noconfirm", "--needed"] + PACMAN_PACKAGES)
    for l in out: log(l)
    return ok


def step_install_aur(log):
    if not _has("yay"):
        log("yay not found; cannot install AUR packages.")
        return False
    log(f"Installing {len(AUR_PACKAGES)} AUR packages...")
    ok, out = _run(["yay", "-S", "--noconfirm", "--needed"] + AUR_PACKAGES)
    for l in out: log(l)
    return ok


def step_zsh_plugins(log):
    zsh_custom = os.environ.get("ZSH_CUSTOM", os.path.expanduser("~/.oh-my-zsh/custom"))
    plugins_dir = Path(zsh_custom) / "plugins"
    if not plugins_dir.is_dir():
        log(f"Oh-My-Zsh plugins dir not found: {plugins_dir}")
        return False
    all_ok = True
    for url, name in ZSH_PLUGINS:
        dest = plugins_dir / name
        if dest.is_dir():
            log(f"  {name} already present.")
            continue
        log(f"  Cloning {name}...")
        ok, out = _run(["git", "clone", "--depth", "1", url, str(dest)])
        for l in out: log(l)
        if not ok:
            all_ok = False
    return all_ok


def step_bootstrap_lazyvim(log):
    lazy_dir = Path.home() / ".local/share/nvim/lazy/lazy.nvim"
    if lazy_dir.is_dir():
        log("lazy.nvim already present.")
        return True
    log("Bootstrapping lazy.nvim...")
    lazy_dir.parent.mkdir(parents=True, exist_ok=True)
    ok, out = _run([
        "git", "clone", "--depth", "1", "--branch", "stable",
        "https://github.com/folke/lazy.nvim.git", str(lazy_dir),
    ])
    for l in out: log(l)
    return ok


def step_set_shell(log):
    import pwd
    try:
        current = pwd.getpwnam(os.environ["USER"]).pw_shell
    except (KeyError, Exception):
        log("Could not detect current shell.")
        return False
    zsh = shutil.which("zsh")
    if not zsh:
        log("zsh not found on PATH.")
        return False
    if current == zsh:
        log("Default shell is already zsh.")
        return True
    log("Setting default shell to zsh...")
    ok, out = _run(["chsh", "-s", zsh])
    for l in out: log(l)
    return ok


def step_link_home(log):
    if not HOME_SRC.is_dir():
        log(f"No home/ directory in {REPO_ROOT}")
        return False
    home = Path.home()
    for f in sorted(HOME_SRC.iterdir()):
        name = f.name
        target = home / name
        try:
            if target.is_symlink():
                if target.resolve() == f.resolve():
                    log(f"  [skip] {name} (already linked)")
                    continue
                target.unlink()
                log(f"  [relink] {name} (replacing existing symlink)")
            elif target.exists():
                bak = home / f"{name}.bak"
                log(f"  [backup] {name} -> {name}.bak")
                target.rename(bak)
            target.symlink_to(f.resolve())
            log(f"  [link]  {name} -> {target}")
        except OSError as e:
            log(f"  [error] {name}: {e}")
            return False
    return True

# -- build the step list ------------------------------------------------------

def _check_yay():
    return "already installed" if _has("yay") else None

def _check_lazyvim():
    d = Path.home() / ".local/share/nvim/lazy/lazy.nvim"
    return "already present" if d.is_dir() else None

def _check_zsh_default():
    import pwd
    try:
        current = pwd.getpwnam(os.environ["USER"]).pw_shell
        zsh = shutil.which("zsh")
        if zsh and current == zsh:
            return "already default"
    except Exception:
        pass
    return None


def build_steps():
    return [
        Step("yay",         "Install yay (AUR helper)",           "Packages",         step_install_yay,      _check_yay),
        Step("official",    "Official packages (pacman)",         "Packages",         step_install_official),
        Step("aur",         "AUR packages (yay)",                 "Packages",         step_install_aur),
        Step("zsh_plugins", "Oh-My-Zsh plugins",                  "Shell & Plugins",  step_zsh_plugins),
        Step("lazyvim",     "Bootstrap lazy.nvim",                "Shell & Plugins",  step_bootstrap_lazyvim, _check_lazyvim),
        Step("shell",       "Set zsh as default shell",           "Shell & Plugins",  step_set_shell,        _check_zsh_default),
        Step("home",        "Link home dotfiles (.zshrc, .bashrc)", "Dotfiles",         step_link_home),
    ]

# ── TUI screens ──────────────────────────────────────────────────────────────

SPINNER = "⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"


def screen_select(stdscr, steps):
    """Checkbox selection screen.  Returns True to proceed, False to quit."""
    curses.curs_set(0)
    cursor = 0
    banner_lines = [l for l in BANNER.splitlines() if l.strip()]

    while True:
        stdscr.erase()
        h, w = stdscr.getmaxyx()
        draw_box(stdscr, 0, 0, h, w, cp(CP_BORDER))

        # banner
        for i, line in enumerate(banner_lines):
            safe_addstr(stdscr, 1 + i, max(2, (w - len(line)) // 2), line, cp(CP_BANNER) | curses.A_BOLD)

        top = len(banner_lines) + 2
        safe_addstr(stdscr, top, 3, "Select what to install", cp(CP_HEADER) | curses.A_BOLD)
        top += 1
        safe_addstr(stdscr, top, 3, "↑/↓ navigate  ␣ toggle  a all  Enter confirm  q quit", cp(CP_DIM))
        top += 2

        # grouped items
        current_group = None
        row = top
        item_rows = []
        for i, s in enumerate(steps):
            if s.group != current_group:
                current_group = s.group
                safe_addstr(stdscr, row, 4, f"  {current_group}", cp(CP_GROUP) | curses.A_BOLD)
                row += 1
            check = "◆" if s.selected else "◇"
            is_cursor = (i == cursor)
            if is_cursor:
                attr = cp(CP_SELECTED) | curses.A_BOLD
            elif s.selected:
                attr = cp(CP_NORMAL)
            else:
                attr = cp(CP_DIM)

            marker = "▸ " if is_cursor else "  "
            line = f"{marker}  {check}  {s.label}"
            if s.skip_reason:
                line += f"  ({s.skip_reason})"
            safe_addstr(stdscr, row, 4, line, attr)
            item_rows.append(row)
            row += 1

        # selected count
        sel = sum(1 for s in steps if s.selected)
        safe_addstr(stdscr, h - 2, 3, f" {sel}/{len(steps)} selected ", cp(CP_ACCENT))

        stdscr.refresh()
        key = stdscr.getch()

        if key in (ord("q"), ord("Q"), 27):
            return False
        elif key == curses.KEY_UP or key == ord("k"):
            cursor = (cursor - 1) % len(steps)
        elif key == curses.KEY_DOWN or key == ord("j"):
            cursor = (cursor + 1) % len(steps)
        elif key == ord(" "):
            steps[cursor].selected = not steps[cursor].selected
        elif key == ord("a"):
            all_on = all(s.selected for s in steps)
            for s in steps:
                s.selected = not all_on
        elif key in (curses.KEY_ENTER, 10, 13):
            return True


def screen_execute(stdscr, steps):
    """Run selected steps with live progress.  Returns list of (step, ok)."""
    curses.curs_set(0)
    selected = [s for s in steps if s.selected]
    if not selected:
        return []

    results = []
    log_lines = []
    h, w = stdscr.getmaxyx()

    # layout: top area for step status, bottom for scrolling log
    status_area_h = len(selected) + 5
    log_top = min(status_area_h + 1, h - 4)
    log_h = h - log_top - 2

    def log(line):
        log_lines.append(line)

    def draw(current_idx, running, spin_frame):
        stdscr.erase()
        draw_box(stdscr, 0, 0, h, w, cp(CP_BORDER))

        safe_addstr(stdscr, 1, 3, "Installing", cp(CP_HEADER) | curses.A_BOLD)
        safe_addstr(stdscr, 2, 3, "─" * (w - 6), cp(CP_BORDER))

        for i, s in enumerate(selected):
            row = 3 + i
            if i < current_idx:
                ok = results[i][1]
                icon = "✓" if ok else "✗"
                pair = CP_SUCCESS if ok else CP_ERROR
                safe_addstr(stdscr, row, 5, f" {icon}  {s.label}", cp(pair))
            elif i == current_idx and running:
                ch = SPINNER[spin_frame % len(SPINNER)]
                safe_addstr(stdscr, row, 5, f" {ch}  {s.label} ...", cp(CP_ACCENT) | curses.A_BOLD)
            else:
                safe_addstr(stdscr, row, 5, f" ·  {s.label}", cp(CP_DIM))

        # log pane
        safe_addstr(stdscr, log_top - 1, 3, "─" * (w - 6), cp(CP_BORDER))
        visible = log_lines[-(log_h):] if log_lines else []
        for j, line in enumerate(visible):
            safe_addstr(stdscr, log_top + j, 4, line, cp(CP_DIM))

        # progress bar
        done = current_idx + (0 if running else 1)
        pct = done / len(selected) if selected else 1
        bar_w = w - 8
        filled = int(bar_w * pct)
        bar = "█" * filled + "░" * (bar_w - filled)
        safe_addstr(stdscr, h - 2, 3, f" {bar} {int(pct*100):>3}% ", cp(CP_ACCENT))

        stdscr.refresh()

    for idx, step in enumerate(selected):
        # animate spinner while running
        stdscr.nodelay(True)
        frame = 0
        draw(idx, True, frame)

        import threading
        result_holder = [None]

        def run_step(s, lg, rh):
            rh[0] = s.fn(lg)

        t = threading.Thread(target=run_step, args=(step, log, result_holder))
        t.start()

        while t.is_alive():
            draw(idx, True, frame)
            frame += 1
            curses.napms(80)
            # drain any keypress
            try:
                stdscr.getch()
            except Exception:
                pass

        t.join()
        ok = result_holder[0] if result_holder[0] is not None else False
        results.append((step, ok))
        draw(idx, False, frame)

    stdscr.nodelay(False)
    return results


def screen_summary(stdscr, results):
    """Show final results.  Blocks until user presses q or Enter."""
    curses.curs_set(0)
    h, w = stdscr.getmaxyx()

    stdscr.erase()
    draw_box(stdscr, 0, 0, h, w, cp(CP_BORDER))

    successes = sum(1 for _, ok in results if ok)
    failures = len(results) - successes

    if failures == 0:
        safe_addstr(stdscr, 2, 3, "All done!", cp(CP_SUCCESS) | curses.A_BOLD)
    else:
        safe_addstr(stdscr, 2, 3, f"Completed with {failures} issue(s)", cp(CP_ERROR) | curses.A_BOLD)

    safe_addstr(stdscr, 3, 3, "─" * (w - 6), cp(CP_BORDER))

    for i, (step, ok) in enumerate(results):
        icon = "✓" if ok else "✗"
        pair = CP_SUCCESS if ok else CP_ERROR
        safe_addstr(stdscr, 5 + i, 5, f" {icon}  {step.label}", cp(pair))

    safe_addstr(stdscr, h - 2, 3, " Press q or Enter to exit ", cp(CP_DIM))
    stdscr.refresh()

    while True:
        key = stdscr.getch()
        if key in (ord("q"), ord("Q"), curses.KEY_ENTER, 10, 13, 27):
            break

# ── Plain-text fallback (non-TTY) ───────────────────────────────────────────

def run_plain(steps):
    """Non-interactive fallback when stdout is not a terminal."""
    RED = "\033[0;31m"
    GREEN = "\033[0;32m"
    BLUE = "\033[0;34m"
    NC = "\033[0m"
    failures = []

    print(BANNER)
    print(f"{BLUE}::{NC} Running all steps (non-interactive mode)\n")

    for step in steps:
        if not step.selected:
            continue
        print(f"{BLUE}[*]{NC} {step.label}...")
        ok = step.fn(lambda l: print(f"    {l}"))
        if ok:
            print(f"{GREEN}[+]{NC} {step.label} — done")
        else:
            print(f"{RED}[!]{NC} {step.label} — failed")
            failures.append(step.label)
        print()

    if failures:
        print(f"\n{RED}[!]{NC} Issues: {', '.join(failures)}")
        sys.exit(1)
    else:
        print(f"\n{GREEN}[+]{NC} All steps completed.")

# ── Main ─────────────────────────────────────────────────────────────────────

def tui_main(stdscr):
    _init_colors()
    if _use_256:
        bg = RP["base"]
        curses.init_color(20, bg[0] * 1000 // 255, bg[1] * 1000 // 255, bg[2] * 1000 // 255)

    steps = build_steps()

    if not screen_select(stdscr, steps):
        return

    results = screen_execute(stdscr, steps)
    if results:
        screen_summary(stdscr, results)


def main():
    if not sys.stdout.isatty():
        steps = build_steps()
        run_plain(steps)
        return

    try:
        curses.wrapper(tui_main)
    except KeyboardInterrupt:
        print("\nAborted.")
        sys.exit(130)


if __name__ == "__main__":
    main()
