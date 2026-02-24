# Repository Guidelines

## Project Structure & Module Organization
- `install.sh` drives the whiptail installer; keep the `CATEGORIES` and `COMPONENTS` maps in sync when adding or renaming modules.
- `home/` mirrors dotfiles copied into `$HOME`; avoid host-specific paths and keep login shells working out of the box.
- Wayland pieces (`hypr/`, `waybar/`, `scripts/`) share theme tokens with `resources/` and `themes/`, so update related palettes together.
- App configs (Kitty, Neovim, VS Code, Cursor, etc.) live in their matching directories; note unusual plugin requirements in a local `README.md` when needed.

## Build, Test, and Development Commands
- `./install.sh` — launch the interactive installer for full deployments.
- `./install.sh` → option 7 — Preview pending changes before touching the filesystem.
- `./install.sh` → option 2 or 3 — Run category or component installs to verify only the area you edited.
- `tail -f /tmp/dotfiles_install.log` — Watch installer output for permission or dependency issues.

## Coding Style & Naming Conventions
- Bash scripts use `#!/bin/bash`, `set -euo pipefail`, four-space indentation inside blocks, and snake_case function names.
- Keep configuration keys grouped and alphabetised where they already are (Kitty color blocks, Waybar modules, JSON settings).
- Script names stay lowercase without spaces or hyphens; ensure files in `scripts/` remain executable.
- Respect JSON5 syntax in `Code/` and `Cursor/` settings so the editors’ formatters keep working.

## Testing Guidelines
- For Hyprland or Waybar edits, reload live sessions with `hyprctl reload` or `waybar-msg cmd reload` and confirm no errors.
- Test Kitty themes via `kitty @ set-colors -a ~/.config/kitty/current-theme.conf` to verify palettes before committing.
- Validate Neovim Lua by running `nvim --headless "+lua print('ok')" +qa`; add Stylua formatting only when a file already opts in.

## Commit & Pull Request Guidelines
- Follow the existing conventional commit style: `type(scope): short imperative`, e.g. `fix(kitty): switch to abstract socket for instant reloads`.
- Consolidate work into reviewable commits, tidy history before pushing, and link issues or TODOs that the change addresses.
- PRs should describe the motivation, list affected components, and include screenshots or recordings for visual tweaks (Waybar, eww, theming).

## Secrets & Local Overrides
- Never commit personal tokens, machine IDs, or generated binaries; stash them under `.gitignore`d paths such as `$HOME/.local/`.
- If behaviour must change per host, gate it behind environment checks or call out the requirement in the nearest README.
