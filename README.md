# tmf-docker

TrackMania Forever dedicated server with XAseco and pyseco, each in its own container:

| Service    | Image                          | Purpose                                              |
|------------|--------------------------------|------------------------------------------------------|
| `tmserver` | Debian + TM server 2011-02-21 | the game server (with the tie-break fix by default)  |
| `mysql`    | MariaDB 11.4                   | XAseco's database, only reachable inside docker      |
| `xaseco`   | PHP 5.6 + XAseco 1.16          | local records, Dedimania, votes, jukebox, ...        |
| `pyseco`   | Python 3.14 + pyseco           | Discord bridge (and future replacements for XAseco)  |

You only deal with two things: **`.env`** (passwords, server account, ports) and the files in **`config/`**.

## Requirements
- Docker with the compose and buildx plugins (Manjaro/Arch: `docker docker-compose docker-buildx`)
- The software itself, which is not part of this repo:
  - the TM dedicated server 2011-02-21 (unzipped download from Nadeo)
  - XAseco 1.16
  - a pyseco checkout

  Their locations are set in `.env` (default: next to this repo). The images are built locally from
  them; don't push them to a registry, they contain Nadeo's server.

## Setup
```sh
cp .env.example .env     # fill in: at least UID/GID, passwords and TMF_MASTERADMIN_LOGIN
docker compose up -d --build
docker compose logs -f   # watch everything start
```

Without `TMF_SERVER_LOGIN` the server runs as a LAN server and Dedimania is disabled automatically.
For an internet server fill in the server account (and `TMF_PUBLIC_IP` if the host is behind NAT)
and forward `TMF_PORT` and `TMF_P2P_PORT` (TCP and UDP) to the host.

## Configuration
Files in `config/` are templates: every `${TMF_...}` is replaced with the value from `.env` when a
container starts, so passwords are only kept in `.env`. After changing something:
`docker compose restart <service>`.

- `config/tmserver/dedicated_cfg.txt`: server settings
- `config/tmserver/matchsettings.txt`: only used on the first start to create
  `data/tmserver/tracks/MatchSettings/active.txt`. After that, edit that file (XAseco may write to it too)
- `config/xaseco/*`: XAseco settings (`plugins.xml`, `config.xml`, ...). Note: XAseco can't read `<` or `>`
  in values, the container refuses to start with such a password
- `config/pyseco/`: pyseco settings and plugin settings (`plugins/discord.ini`)

## Data
Everything the services write lives in `data/` and belongs to your user (`UID`/`GID` in `.env`):

- `data/tmserver/tracks`: tracks, match settings, replays (filled with the default tracks on the first start)
- `data/tmserver/config`: files the server writes (blacklist, guestlist)
- `data/mysql`: the database. Its passwords are set when it is created: changing `TMF_MYSQL_PASSWORD`
  later requires changing it in the database too (or starting with an empty `data/mysql`)
- `data/xaseco/state`: admin/op lists, banned IPs, jfreu settings, written by XAseco
- `*/logs`: logs of every service

Back up `data/` (for the database while it is stopped, or with `mariadb-dump`) and `.env`.

## Notes
- XAseco writes into the server's track directory and asks the server for its path, so the tracks
  volume is mounted at the same path (`/opt/tmserver/GameData/Tracks`) in both containers.
- The server's XML-RPC port 5000 is only reachable inside the docker network (`xmlrpc_allowremote`
  is on for that reason). Don't publish it.
- The tie-break fix (players with equal times: the first to drive it ranks first) is applied while
  building the image. `TMF_TIEBREAK_PATCH=0` builds the original server.
- Several servers: one copy of this directory per server, with different ports and `name:` in
  `docker-compose.yml` (or `COMPOSE_PROJECT_NAME` in `.env`).
