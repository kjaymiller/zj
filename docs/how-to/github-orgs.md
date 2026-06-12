# How to add GitHub orgs to the picker

Goal: have an owner's or org's repos appear in the picker as `gh:owner/repo`
(green) so selecting one clones it on demand and opens a session there.

## 1. List the owners

Add each GitHub login (a user or an org) to `~/.config/zj/orgs`, one per line:

```sh
$EDITOR ~/.config/zj/orgs
```

```
kjaymiller
zellij-org
```

If the file doesn't exist yet:

```sh
mkdir -p ~/.config/zj
cp orgs.example ~/.config/zj/orgs
```

Override the location with `$ZJ_ORGS_FILE`.

## 2. Make sure gh is authenticated

`zj` fetches every owner's repos in one GitHub GraphQL call via `gh`, which must
be installed and authenticated:

```sh
gh auth status || gh auth login
```

To authenticate the GraphQL call with a *specific* token instead of `gh`'s login,
stash a classic PAT or fine-grained token (with `repo`/read access) in fnox under
`GH_API_TOKEN`; `zj` exports it as `GH_TOKEN` for the call. Override the secret
name with `$ZJ_GH_TOKEN_KEY`. When fnox has no value, `gh`'s normal auth is used.

## 3. Open the picker

```sh
zj
```

Green `gh:owner/repo` entries now appear. Selecting one clones the repo into
`$ZJ_REPOS_DIR` (default `~/projects`) if it isn't already there, then opens a
session named after the repo.

The repo list is cached for `ZJ_GH_CACHE_TTL` minutes (default 60) so the picker
stays instant; set it to `0` to disable caching. GraphQL caps results at 100
repos per owner.

## Grab a one-off repo not in your orgs

You don't need to add an owner just to clone one repo. Pass any GitHub URL or
`owner/repo` slug straight to `zj`:

```sh
zj https://github.com/zellij-org/zellij      # https URL
zj git@github.com:zellij-org/zellij.git      # ssh URL
zj zellij-org/zellij                         # owner/repo slug
```

Not seeing your repos? See [troubleshooting](troubleshooting.md#the-ghownerrepo-entries-dont-appear).
