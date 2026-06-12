# Tutorial: your first session with zj

This walks you from a clean machine to switching between sessions with one
keystroke. By the end you'll have installed `zj`, opened a directory as a
session, and created a brand-new project from the picker. No prior `zj`
knowledge is assumed — follow the steps in order.

> This is a learning exercise. For looking things up later, see the
> [reference](reference.md); for one-off tasks, see the [how-to guides](how-to/).

## 1. Install zj

From the cloned repo, run the install script. It symlinks `zj` into
`~/.local/bin` and downloads any missing tools (`zellij`, `zoxide`, `fzf`, `gh`)
from their GitHub releases:

```sh
./install.sh
```

Make sure `~/.local/bin` is on your `PATH`, then check it's there:

```sh
zj --help 2>/dev/null; command -v zj
```

You should see the path to the `zj` symlink. (We're skipping `fnox` for now —
it's only needed for remote sessions, which come later.)

## 2. Open the picker

Run `zj` with no arguments:

```sh
zj
```

An `fzf` window opens. It's empty-ish on a fresh machine — that's expected. The
picker merges four sources, each in its own color:

- active zellij sessions (cyan)
- zoxide-tracked directories (blue)
- configured remote sessions (magenta)
- GitHub repos for your orgs (green, `gh:owner/repo`)

You haven't visited any directories with `zoxide` yet, so the list is short.
Press `Esc` to close it.

## 3. Seed zoxide, then open a directory as a session

`zj`'s directory entries come from `zoxide`, which learns the directories you
visit. Visit a couple so they show up:

```sh
cd ~/projects 2>/dev/null || cd ~
zoxide add "$PWD"
```

Now open the picker again and start typing the directory's name. Select it and
press `Enter`. `zj` creates a zellij session named after that directory, rooted
there, and drops you into it:

```sh
zj
```

You're now inside a zellij session. Detach with `Ctrl-o d` (the default zellij
detach binding) to come back to your shell.

## 4. Create a new project from the picker

Here's the part that makes `zj` more than a switcher. Open the picker and type a
name that **doesn't** match anything in the list — say `my-first-zj-project` —
then press `Enter`:

```sh
zj
```

Because nothing matched, `zj` treats your text as the name of a new project: it
slugifies the name, creates `~/projects/my-first-zj-project`, and opens a session
there. You just scaffolded and entered a project in one keystroke.

## 5. (Optional) wire up a keybinding

The real workflow is launching `zj` from inside zellij as a floating pane, so it
overlays your layout and disappears when you pick. Add this to
`~/.config/zellij/config.kdl`:

```kdl
keybinds {
    locked {
        bind "Ctrl y" {
            SwitchToMode "Normal"
            Run "zj" { floating true; close_on_exit true }
        }
    }
}
```

Now `Ctrl y` inside zellij pops the picker and switches you to whatever you pick.

## What you learned

- `zj` with no args opens a fuzzy picker over sessions, directories, remotes, and repos.
- Selecting a directory opens a session rooted there.
- Typing an unmatched name scaffolds a new project directory and opens it.

## Where to next

- Add **remote sessions** and **GitHub orgs**: [how-to guides](how-to/).
- Look up an **environment variable** or **dispatch rule**: [reference](reference.md).
- Understand **why** `zj` behaves the way it does: [explanation](explanation.md).
