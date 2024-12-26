from dooit.api import Todo
from dooit.ui.api import DooitAPI, subscribe
from dooit.ui.api.events import Startup
from dooit.api.theme import DooitThemeBase
from dooit.ui.api.widgets import TodoWidget
from rich.style import Style
from dooit_extras.formatters import *
from dooit_extras.bar_widgets import *
from dooit_extras.scripts import *
from rich.text import Text


class DooitThemeRosePine(DooitThemeBase):
    _name: str = "dooit-rosepine"

    # background colors
    background1: str = "#191724"  # Base
    background2: str = "#1f1d2e"  # Surface
    background3: str = "#26233a"  # Overlay

    # foreground colors
    foreground1: str = "#908caa"  # Muted
    foreground2: str = "#e0def4"  # Text
    foreground3: str = "#faf4ed"  # Subtle

    # other colors
    red: str = "#eb6f92"      # Rose
    orange: str = "#f6c177"   # Gold
    yellow: str = "#f6c177"   # Gold (Rose Pine uses same color for orange/yellow)
    green: str = "#31748f"    # Pine
    blue: str = "#9ccfd8"     # Foam
    purple: str = "#c4a7e7"   # Iris
    magenta: str = "#ebbcba"  # Rose
    cyan: str = "#9ccfd8"     # Foam (Rose Pine uses same color for blue/cyan)

    # accent colors
    primary: str = purple
    secondary: str = blue


@subscribe(Startup)
def setup_colorscheme(api: DooitAPI, _):
    api.css.set_theme(DooitThemeRosePine)


@subscribe(Startup)
def setup_formatters(api: DooitAPI, _):
    fmt = api.formatter
    theme = api.vars.theme

    # ------- WORKSPACES -------
    format = Text(" ({}) ", style=theme.primary).markup
    fmt.workspaces.description.add(description_children_count(format))

    # --------- TODOS ---------
    # status formatter
    fmt.todos.status.add(status_icons(completed=" ", pending=" ", overdue=" "))

    # urgency formatte
    u_icons = {1: "  󰯬", 2: "  󰯯", 3: "  󰯲", 4: "  󰯵"}
    fmt.todos.urgency.add(urgency_icons(icons=u_icons))

    # due formatter
    fmt.todos.due.add(due_casual_format())
    fmt.todos.due.add(due_icon(completed="󱫐 ", pending="󱫚 ", overdue="󱫦 "))

    # effort formatter
    fmt.todos.effort.add(effort_icon(icon="󱠇 "))

    # description formatter
    format = Text("  {completed_count}/{total_count}", style=theme.green).markup
    fmt.todos.description.add(todo_description_progress(fmt=format))
    fmt.todos.description.add(description_highlight_tags(fmt=" {}"))
    fmt.todos.description.add(description_strike_completed())


@subscribe(Startup)
def setup_layout(api: DooitAPI, _):
    api.layouts.todo_layout = [
        TodoWidget.status,
        TodoWidget.effort,
        TodoWidget.description,
        TodoWidget.due,
    ]


@subscribe(Startup)
def setup_bar(api: DooitAPI, _):
    theme = api.vars.theme

    widgets = [
        TextBox(api, " 󰄛 ", bg=theme.magenta),
        Spacer(api, width=1),
        Mode(api, format_normal=" 󰷸 NORMAL ", format_insert=" 󰛿 INSERT "),
        Spacer(api, width=0),
        WorkspaceProgress(api, fmt=" 󰞯 {}% ", bg=theme.secondary),
        Spacer(api, width=1),
        Date(api, fmt=" 󰃰 {} "),
    ]
    api.bar.set(widgets)


@subscribe(Startup)
def setup_dashboard(api: DooitAPI, _):
    theme = api.vars.theme

    ascii_art = r"""
   ,-.       _,---._ __  / \
 /  )    .-'       `./ /   \
(  (   ,'            `/    /|
 \  `-"             \'\   / |
  `.              ,  \ \ /  |
   /`.          ,'-`----Y   |
  (            ;        |   '
  |  ,-.    ,-'         |  /
  |  | (   |      TODOS | /
  )  |  \  `.___________|/
  `--'   `--'
    """

    ascii_art = Text(ascii_art, style=theme.primary)
    ascii_art.highlight_words(["TODOS"], style=theme.red)

    due_today = sum([1 for i in Todo.all() if i.is_due_today and i.is_pending])
    overdue = sum([1 for i in Todo.all() if i.is_overdue])

    header = Text(
        "Another day, another opportunity to organize my todos and then procrastinate",
        style=Style(color=theme.secondary, bold=True, italic=True),
    )

    items = [
        header,
        ascii_art,
        "",
        "",
        Text("󰠠 Tasks pending today: {}".format(due_today), style=theme.green),
        Text("󰁇 Tasks still overdue: {}".format(overdue), style=theme.red),
    ]
    api.dashboard.set(items)