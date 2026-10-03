# tmf-docker

TrackMania Forever dedicated server with the pyseco controller, each in its own container:

| Service    | Image                          | Purpose                                                          |
|------------|--------------------------------|------------------------------------------------------------------|
| `tmserver` | Debian + TM server 2011-02-21 | the game server (with the tie-break fix by default)              |
| `pyseco`   | Python 3.14 + pyseco           | local records, Dedimania, TMX, jukebox, votes, moderation, Discord |

You only deal with two things: **`.env`** (passwords, server account, ports) and the files in **`config/`**.

The setup with XAseco (PHP 5.6, MariaDB, Records-Eyepiece) is kept as the git tag `xaseco-1.0` and the branch
`xaseco`; it needs pyseco at its `xaseco-1.0` tag too.

## Requirements
- Docker with the compose and buildx plugins (Manjaro/Arch: `docker docker-compose docker-buildx`)
- The software itself, which is not part of this repo:
  - the TM dedicated server 2011-02-21 (unzipped download from Nadeo)
  - a pyseco checkout

  Their locations are set in `.env` (default: next to this repo). The images are built locally from
  them; don't push them to a registry, they contain Nadeo's server.

## Setup
```sh
cp .env.example .env     # fill in: at least UID/GID, passwords and TMF_MASTERADMIN_LOGIN
docker compose up -d --build
docker compose logs -f   # watch everything start
```

Without `TMF_SERVER_LOGIN` the server runs as a LAN server and Dedimania is off.
For an internet server fill in the server account (and `TMF_PUBLIC_IP` if the host is behind NAT)
and forward `TMF_PORT` and `TMF_P2P_PORT` (TCP and UDP) to the host.

## Configuration
Files in `config/` are templates: every `${TMF_...}` is replaced with the value from `.env` when a
container starts, so passwords are only kept in `.env`. After changing something:
`docker compose restart <service>`.

- `config/tmserver/dedicated_cfg.txt`: server settings
- `config/tmserver/matchsettings.txt`: only used on the first start to create
  `data/tmserver/tracks/MatchSettings/active.txt`. After that, edit that file
- `config/pyseco/pyseco.toml`: pyseco settings, one section per plugin. The plugins are chosen with
  `TMF_PLUGINS` in `.env`; `discord` is added when a bot token is set, `dedimania` when there is a server login
  (with `TMF_DEDIMANIA_CODE`, or the server password)

Maps are the server's business: they are in the match settings file
(`data/tmserver/tracks/MatchSettings/active.txt`), restart `tmserver` after editing it. Admins add maps from TMX in
game for one play (`/add <id>`, `/rtmx`), `/addthis` keeps one; `/admin remove` takes a map off the list (the file
stays). pyseco saves such changes in the match settings file. The `admin_panel` plugin shows buttons for next map,
replay, restart and remove to operators and admins.
The time per map is kept by pyseco's flexitime plugin (default 60 minutes, admins change it with `/timeleft`), so
the server's own `timeattack_limit` is 0 (off).

Roles: the masteradmin (`TMF_MASTERADMIN_LOGIN`) gives roles in game with `/setrole`; `/pyseco` lists the commands.
Discord accounts are linked to TM logins with `/link` in game and `!link <code>` in discord.

## Data
Everything the services write lives in `data/` and belongs to your user (`UID`/`GID` in `.env`):

- `data/tmserver/tracks`: tracks, match settings, replays; default tracks that are missing (e.g. deleted) are
  copied from the server download on every start, nothing existing is overwritten. Maps from TMX are in
  `Challenges/TMX`. Maps listed in the match settings that don't exist are reported in `docker compose logs tmserver`
  (the server does not start when it can't load any)
- `data/tmserver/config`: files the server writes (blacklist, guestlist)
- `data/pyseco`: pyseco's database (`pyseco.db`: players, roles, records, bans, ...) and logs
- `*/logs`: logs of every service

Back up `data/` (`pyseco.db` while pyseco is stopped, or with `sqlite3 pyseco.db ".backup copy.db"`) and `.env`.

Coming from the XAseco setup: `data/mysql` and `data/xaseco` are no longer used, local records from XAseco are not
taken over.

## Notes
- The server's XML-RPC port 5000 is only reachable inside the docker network (`xmlrpc_allowremote`
  is on for that reason). Don't publish it.
- The tie-break fix (players with equal times: the first to drive it ranks first) is applied while
  building the image. `TMF_TIEBREAK_PATCH=0` builds the original server.
- Several servers: one copy of this directory per server, with different ports and `name:` in
  `docker-compose.yml` (or `COMPOSE_PROJECT_NAME` in `.env`).
