# backup-container

A small Docker image bundling the Linux CLIs used to back up mail, contacts, and
calendars. It runs on a Synology NAS (or any Docker host). Each backup is a one-shot
`docker run --rm` invoked from a Synology scheduled task, so nothing has to be installed
on DSM directly and no long-lived container is left running.

## Contents

| Tool | Purpose | Version | Source |
|------|---------|---------|--------|
| [`mbsync`](https://isync.sourceforge.io/) (isync) | Mail backup (IMAP → Maildir) | `1.5.1-r1` | Alpine 3.24 community |
| [`vdirsyncer`](https://vdirsyncer.pimutils.org/) | Contacts & calendars backup (CalDAV/CardDAV) | `0.20.0-r2` | Alpine 3.24 community |
| [`pimsync`](https://pimsync.whynothugo.nl/) | Contacts & calendars backup (primary; alpha) | `0.7.0-r0` | Alpine edge community |

Base image is `alpine:3.24`, built for `linux/amd64`. pimsync is pulled from the Alpine
`edge` repo via an `@edge`-tagged repository (not yet in stable), so only pimsync comes
from edge while everything else stays on the stable base.

The image runs no daemons and no init process — it exists only to be run per task, so it
uses zero RAM between backups and only consumes memory while a tool is actually syncing.

## Usage

Run a backup as a one-shot container (e.g. from a Synology **Control Panel → Task
Scheduler** task). Pass `--user` so files are written with your own uid/gid:

```sh
docker run --rm \
  --user "$(id -u):$(id -g)" \
  -v /volume1/docker/backup/config:/config \
  -v /volume1/docker/backup/data:/data \
  ghcr.io/<owner>/backup-container:latest mbsync -a
```

One task per tool:

```sh
docker run --rm --user "$(id -u):$(id -g)" -v .../config:/config -v .../data:/data IMAGE mbsync -a
docker run --rm --user "$(id -u):$(id -g)" -v .../config:/config -v .../data:/data IMAGE pimsync sync
docker run --rm --user "$(id -u):$(id -g)" -v .../config:/config -v .../data:/data IMAGE vdirsyncer sync
```

If a provider needs root (some setups do), use `--user 0:0` for that task instead.

### Configuration & data

`HOME` is `/config`, so place config files under the mounted `/config` volume:

- `mbsync`: `/config/.mbsyncrc`
- `vdirsyncer`: `/config/.config/vdirsyncer/config`
- `pimsync`: `/config/.config/pimsync/config` (`XDG_CONFIG_HOME=/config/.config`)

Backed-up data lives under `/data` (`XDG_DATA_HOME=/data`). Point your Maildir /
storage paths in the configs there.

### Permissions

Pass `--user "$(id -u):$(id -g)"` at run time (see above) so the tools write as your own
user. Make sure the bind-mounted `config` and `data` directories on the NAS are owned by,
or writable by, that uid/gid. The image bakes in no user, so the uid is entirely your
choice per task.

## Building locally

```sh
docker build -t backup-container .

docker run --rm backup-container mbsync --version
docker run --rm backup-container vdirsyncer --version
docker run --rm backup-container pimsync --version
```

Versions can also be overridden at build time:

```sh
docker build --build-arg PIMSYNC_VERSION=0.8.0-r0 -t backup-container .
```

## Updating the tools

Versions are **pinned**. What updates automatically vs. manually:

- **Automatic (Dependabot PRs):** the base image (`FROM alpine:3.24`) and the GitHub
  Actions used in the workflow. See `.github/dependabot.yml`.
- **Manual:** `isync`, `vdirsyncer`, and `pimsync` versions. Dependabot has no ecosystem
  for Alpine `apk` packages, so bump the `ARG` lines in the `Dockerfile` yourself.

Find current versions at <https://pkgs.alpinelinux.org/packages> (check both the stable
`v3.24` and `edge` branches).

### Expected breakages (they are the signal to bump)

- When Dependabot bumps `alpine:3.24` → a newer release, the pinned apk versions may no
  longer exist in that release and the CI build will fail. That failing build is the cue
  to update `ISYNC_VERSION` / `VDIRSYNCER_VERSION` to match the new release.
- pimsync is installed from `edge`, which is rolling and garbage-collects old package
  revisions. If a later build fails because `PIMSYNC_VERSION` is gone, bump it to the
  current edge version.

## Publishing

`.github/workflows/build-publish.yml` builds and pushes to
`ghcr.io/<owner>/backup-container` on pushes to `main` and on `v*` tags. Pull requests
(including Dependabot's) build only, to validate changes without pushing.

Tag a release to publish a versioned image:

```sh
git tag v0.1.0 && git push --tags
# → ghcr.io/<owner>/backup-container:0.1.0, :0.1, :latest
```
