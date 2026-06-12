# Troubleshooting

Fixes for the failure modes you're most likely to hit. Each entry lists the
symptom, the usual cause, and what to do. For the reasoning behind these
behaviors, see the [explanation](../explanation.md).

## zj asks for the token every single run

**Cause:** no fnox provider is configured, so `fnox get ZELLIJ_WEB_TOKEN` returns
nothing each time.

**Fix:** configure an age-backed fnox provider so the token is served on demand:

```sh
fnox provider add …
```

Or, when prompted, answer **yes** to "Cache this token via fnox?" — `zj` writes it
to fnox's *global* config (`~/.config/fnox/config.toml`) with `fnox set --global`
so it's found from any directory. If you say yes and still get prompted, no
provider is configured to store it — see above. Confirm with:

```sh
fnox get ZELLIJ_WEB_TOKEN
```

## Remote attach fails on TLS verification

**Symptom:** attaching a remote URL errors out on certificate verification.

**Cause:** the remote server uses a custom CA that your system trust store doesn't
have.

**Fix:** point `zj` at the CA cert (PEM):

```sh
export ZJ_CA_CERT="$HOME/.config/zj/ca.pem"
```

`zj` only adds `--ca-cert` when `ZJ_CA_CERT` is set *and* the file exists — double
check the path.

## Attaching a remote drops me into a dead local shell

**Cause:** you're inside zellij and a previous remote-host session still exists,
but its remote `zellij attach` already exited (e.g. you detached from the remote),
leaving only local panes.

**Fix:** none needed — current `zj` detects this and re-attaches the remote in a
fresh tab instead of switching you into the dead shell (issue #17). If you're on
an old copy, `git pull` and re-run `./install.sh --symlink-only`.

## The `gh:owner/repo` entries don't appear

Work through these in order:

1. **`gh` not installed or not authenticated** — `zj` silently skips the repo
   source if `gh` is missing or unauthenticated:
   ```sh
   command -v gh && gh auth status || gh auth login
   ```
2. **No orgs configured** — the source is empty without an orgs file:
   ```sh
   cat ~/.config/zj/orgs        # should list one login per line
   ```
   See [Add GitHub orgs](github-orgs.md).
3. **Stale or empty cache** — results are cached for `ZJ_GH_CACHE_TTL` minutes.
   `zj` keeps the last good list on a failed refresh, so a fixed auth issue may
   not show until the cache expires. Force a refresh by clearing it:
   ```sh
   rm -f "${XDG_CACHE_HOME:-$HOME/.cache}/zj/repos"
   ```
4. **Token without access** — if you set `GH_API_TOKEN` in fnox, make sure it has
   `repo`/read scope; otherwise unset it to fall back to `gh`'s own login.

Note GraphQL caps results at 100 repos per owner.

## The picker is empty

`zj` merges four sources; an empty picker means all four are empty:

- no active zellij sessions (`zellij list-sessions`),
- `zoxide` hasn't tracked any directories yet — visit a few, or `zoxide add <dir>`,
- no `remotes` file (see [remote sessions](remote-sessions.md)),
- no `orgs` file or `gh` unavailable (see above).

You can still type a name and press `Enter` to scaffold a new project — an empty
picker doesn't block creation.

## `zj owner/repo` cloned when I meant to create a directory

**Cause:** a bare `owner/repo` is ambiguous. As an *explicit argument*, `zj` keeps
the documented clone behavior.

**Fix:** type the name into the **picker** instead of passing it as an argument —
when nothing matches, `zj` asks whether you meant to clone the repo or create a
nested directory. See the
[explanation](../explanation.md#the-dispatch-order-and-the-one-ambiguity).

## A new session opens in the wrong directory

**Cause:** the zellij server roots a session's initial pane at its own working
directory, so the very first tab can be misrooted.

**Fix:** none needed — `zj` adds a correctly-rooted tab and closes the stray
default one once a client attaches. If you still land in the wrong place, make
sure you're on a current `zj` and that the target directory actually exists.
