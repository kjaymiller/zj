# Explanation: how zj works and why

Understanding-oriented background. This explains the design — the reasoning, the
trade-offs, and the quirks `zj` works around. For step-by-step learning see the
[tutorial](tutorial.md); for exact values see the [reference](reference.md).

## The core idea: one picker, many targets

`zj` is a thin dispatcher in front of `zellij`. Its job is to collapse "what do I
want to work on?" into a single fuzzy list, then do the right thing with whatever
you pick. The sources are deliberately heterogeneous — running sessions,
directories you've visited, remote servers, and repos you haven't cloned yet —
because in practice those are all just "places I might want a session."

Each source is gathered independently, tagged with an ANSI color, merged,
deduplicated, and handed to `fzf`. The picker doesn't know or care what kind of
thing each line is; the *dispatch* step at the end of the script re-derives that
from the chosen string. That separation keeps the picker dumb and the routing
logic in one place.

## Why the query is treated as a fallback target

`zj` runs `fzf --print-query`, so `fzf` echoes the text you typed as its first
output line and the selected item (if any) as the second. When nothing matches,
there's no second line — and rather than erroring, `zj` treats your query as the
name of something to create. This is what lets you type a brand-new project name
and land in a freshly scaffolded directory. The picker becomes a creation tool,
not just a switcher.

## The dispatch order, and the one ambiguity

Targets are matched most-specific-first: explicit `gh:` prefix, then a recognized
GitHub URL, then any other `http(s)://` URL (a remote session), then an active
session, then an existing directory, then a bare `owner/repo`, and finally a
plain new-project name.

A bare `owner/repo` is genuinely ambiguous — it reads equally well as "clone this
GitHub repo" or "make a nested `parent/child` directory." `zj` resolves this by
*context*: an explicit `zj owner/repo` argument keeps the documented clone
behavior, but the same text typed into the picker (where you might just be naming
a nested project) prompts you to choose. Where intent is knowable it acts; where
it isn't, it asks.

## Remote sessions and the "dead shell" problem

A remote web session is attached with `zellij attach <url> --token …`. The token
comes from `fnox` (typically backed by an age-encrypted store) so it's never on
disk in the clear; if `fnox` has no value, `zj` prompts and offers to cache it
into fnox's *global* config so later runs from any directory find it.

The subtle part is attaching a remote *while already inside zellij*. A plain
`zellij attach` would nest the remote into your current pane, hijacking it. There's
no `switch-session` for a remote URL, so `zj` instead hosts the remote inside its
own local session — a switchable sibling of your other sessions — and switches the
client to it.

That host session has a lifecycle wrinkle: once the remote `attach` command exits
(e.g. you detach from the remote), the session degrades to plain local shell
panes. So a session merely *existing* doesn't mean the remote is still live.
`zj` inspects the session's layout to tell whether it still hosts a live attach;
if not, it re-attaches the remote in a fresh tab instead of dumping you into a
dead shell. (This is the fix behind issue #17.)

## The zellij session-rooting quirk

You'd expect `--default-cwd` to root a new session at a given directory. It
doesn't, reliably: the zellij server roots a session's *initial* pane at its own
working directory and ignores `--default-cwd` for that first pane. The only
dependable way to get a pane rooted at a specific directory is `new-tab --cwd`.

So `zj` creates the session, waits for the server to register it, then adds a
correctly-rooted tab — and later closes the stray misrooted default tab once a
client is attached (closing a tab requires an attached client, and we never close
the sole tab, which would kill the session). It's more dance than you'd like, but
it's the only path that lands you in the right directory every time.

## Why fzf instead of gum

An earlier version used `gum` for prompts. `gum` couldn't interact correctly when
run inside a zellij floating pane — most likely because it couldn't reach
`/dev/tty` in that context — so the picker simply didn't work in the exact
scenario `zj` is built for. `fzf` works there, and is the natural fit for a fuzzy
picker anyway, so `zj` standardized on it. (`zj`'s own token prompts deliberately
read from and write to `/dev/tty` directly, since the function's stdout is
captured as the token.)

## Caching, gracefully

The `gh:owner/repo` list comes from a single GitHub GraphQL call that fetches
every configured owner's repos at once (aliased sub-queries), rather than one REST
call per owner. The result is cached for `ZJ_GH_CACHE_TTL` minutes so the picker
stays instant. Two deliberate choices keep the cache from hurting you: a refresh
only overwrites the cache on a *non-empty* result (so a transient network or auth
failure falls back to the last good list instead of an empty picker), and the
GraphQL query prefers a token from `fnox` but falls back to `gh`'s own login.
