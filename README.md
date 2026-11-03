# finman

A personal investment manager for Indian investors that runs on your own computer. It keeps an
exact record of everything you own and owe, values it from free Indian market data, works out
your capital-gains tax, tracks goals and SIPs, flags common mistakes, and asks AI models for
advice about your money.

This repository holds the ready-made finman programs (on the
[Releases](https://github.com/jinuthankachan/finman-builds/releases) page), an install script, and
a Docker Compose file.

- [What it does](#what-it-does)
- [Choose how to run it](#choose-how-to-run-it)
- [Option 1: install the program](#option-1-install-the-program)
- [Option 2: run it with Docker](#option-2-run-it-with-docker)
- [First steps in the app](#first-steps-in-the-app)
- [AI services](#ai-services)
- [Opening it from other devices](#opening-it-from-other-devices)

## What it does

- **Holdings**: mutual funds, shares, ETFs, sovereign gold bonds, PPF, EPF, NPS, FDs, gold,
  property, cash and loans in one place, valued at today's prices.
- **Upload statements**: a detailed CAS from CAMS or KFintech, a Zerodha file, or any other
  statement an AI can read. You check the rows before anything is saved.
- **Prices**: fund NAVs, NSE and BSE share prices, indices and gold from free Indian market data,
  updated with one button and on a schedule.
- **Tax**: Indian capital gains, the tax due, and ideas to pay less.
- **Goals and Plan**: retirement, a house, education; asset allocation, insurance and retirement
  planning.
- **SIPs**: your monthly investments, planned, done and missed.
- **To-do**: common mistakes and things to check or fix.
- **Ask the AI** and **Reports**: chat about your money, and get portfolio reviews and investment
  plans written for you. The app remembers what you tell it about your life.
- **Several people, one installation**: each person signs in and sees only their own portfolio,
  goals, chats and reports.

Your records stay on your computer, and by default the app answers only on `127.0.0.1`. It goes
online for market prices, and for the AI services you set up, which receive your questions along
with the parts of your records they need to answer them.

## Choose how to run it

| | Option 1: the program | Option 2: Docker |
| --- | --- | --- |
| Runs on | Linux (x86-64, ARM64), macOS on Apple silicon; Windows through WSL | Any computer with Docker, including Intel Macs and Windows |
| Your records | A database file in `~/.finman/data` | PostgreSQL and Redis containers |
| AI services | The APIs, and the Claude, Codex and Antigravity command-line tools | The APIs only |
| You need | `curl` | Docker with the compose plugin |

## Option 1: install the program

    curl -fsSL https://raw.githubusercontent.com/jinuthankachan/finman-builds/main/install.sh | sh

To read the script before running it:

    curl -fsSLO https://raw.githubusercontent.com/jinuthankachan/finman-builds/main/install.sh
    less install.sh
    sh install.sh

The script downloads the program for your computer from the newest release and checks it
against the release's `SHA256SUMS`. It installs everything in `~/.finman`:

    ~/.finman/bin/invest    the program
    ~/.finman/bin/finman    the finman command: the program, on the data folder below
    ~/.finman/data/         your records, settings, statements and backups
    ~/.finman/VERSION       the release installed

It also creates the `finman` command in `~/.local/bin`. If that folder is not on your `PATH`, the
script prints the line to add to your shell's startup file.

### Start it

    finman

Open <http://127.0.0.1:8790> in your browser. The first time, the **Welcome** page asks for your
name, e-mail and a password, and creates the first account, which is the administrator. Leave
the terminal open while you use the app, and press Ctrl+C there to stop it.

To use another port, run `finman --port 8791`, or set `port` under `[server]` in
`~/.finman/data/config.toml`.

### Commands

    finman                          start the app (the same as finman serve; options --host, --port)
    finman check                    show the data folder, database, AI access and the command-line tools found
    finman backup [FILE]            a copy of your records, safe while the app runs
    finman create-user EMAIL [--name NAME] [--admin] [--password PASSWORD]
                                    add a person without the browser
    finman migrate                  bring the database up to date (starting the app does this too)
    finman help                     list the commands

The program calls itself `invest` in its messages: `finman` is `invest` working on
`~/.finman/data`.

### Update

    curl -fsSL https://raw.githubusercontent.com/jinuthankachan/finman-builds/main/install.sh | sh -s -- update

This backs up your records into `~/.finman/data/backups/`, then installs the newest release. If
finman is running, stop it and start it again to use the new version. To install a particular
release, add `--version v1.2.3`. Going back to an older release than the one you ran may need the
backup from before the update.

### Uninstall

    curl -fsSL https://raw.githubusercontent.com/jinuthankachan/finman-builds/main/install.sh | sh -s -- uninstall

This removes the program and the `finman` command, and keeps your data in `~/.finman/data`:
install again and everything is back. To delete your data too, use `uninstall --purge`. It asks
you to type `delete` first.

### Your data

Everything is in `~/.finman/data`:

- `invest.db`: **your records** (accounts, transactions, goals, chats, reports)
- `invest-kv.db`: sign-ins, and the status of the AI services and price updates
- `config.toml`: settings for everyone (optional; most settings are on the Settings page)
- `secrets.toml`: API keys typed on the Settings page
- `imports/` (uploaded statements), `jobs/` (every AI call, with its question and answer),
  `cache/` (downloaded market data) and `backups/`

Keep this folder on a disk of this computer, not on a network share, where the database can be
damaged.

**Backups.** `finman backup` writes a copy of your records to
`~/.finman/data/backups/invest-<date and time>.db`, even while the app runs. Copy that file
somewhere safe, along with `config.toml`, `secrets.toml` and `imports/`. When the app is stopped,
a copy of the whole `~/.finman/data` folder is a backup too. To restore one, stop the app, delete
`invest.db-wal` and `invest.db-shm` if they are there, and put the backup in place of `invest.db`.

**Data from another folder.** If you ran finman before with its data somewhere else, stop it,
install, and copy that folder's contents in before the first start:

    cp -a /path/to/old/data/. ~/.finman/data/

### Without the script

Download the file for your computer and `SHA256SUMS` from the
[Releases](https://github.com/jinuthankachan/finman-builds/releases) page:

| File | For |
| --- | --- |
| `invest-linux-amd64` | Linux, x86-64 |
| `invest-linux-arm64` | Linux, ARM 64-bit |
| `invest-darwin-arm64` | macOS, Apple silicon |

Check it: `sha256sum invest-linux-amd64` (on a Mac, `shasum -a 256 invest-darwin-arm64`) must
print the same value as its line in `SHA256SUMS`. Then:

    mkdir -p ~/.finman/bin
    mv invest-linux-amd64 ~/.finman/bin/invest
    chmod +x ~/.finman/bin/invest
    INVEST_DATA_DIR=~/.finman/data ~/.finman/bin/invest

Without `INVEST_DATA_DIR`, the program keeps its data in a `data/` folder in the folder you start
it from. On a Mac, if macOS says a program downloaded with the browser cannot be opened, run
`xattr -d com.apple.quarantine ~/.finman/bin/invest` once.

## Option 2: run it with Docker

You need [Docker](https://docs.docker.com/get-docker/) with the compose plugin
(`docker compose version` should print a version).

    mkdir finman && cd finman
    curl -fsSLO https://raw.githubusercontent.com/jinuthankachan/finman-builds/main/compose.yaml
    docker compose up -d --wait

Open <http://127.0.0.1:8790>, and create the first account on the **Welcome** page. This starts
three containers: the app (`ghcr.io/jinuthankachan/finman`), PostgreSQL with your records, and
Redis with the sign-ins. They start again by themselves after a reboot.

**Settings.** Passwords, the port, API keys and the version go in a file named `.env` next to
`compose.yaml`. To make one, download the example and remove the `#` in front of the lines you
change:

    curl -fsSL -o .env https://raw.githubusercontent.com/jinuthankachan/finman-builds/main/.env.example

Set `POSTGRES_PASSWORD` before the first `docker compose up`: PostgreSQL takes it only when it
creates its database. PostgreSQL and Redis can be reached from the app container only.

Run these from the folder with `compose.yaml`:

    docker compose ps                         what is running
    docker compose logs -f app                the app's log
    docker compose exec app invest check      the app's commands (see Option 1)
    docker compose exec app invest create-user EMAIL --admin
    docker compose stop                       stop; docker compose up -d --wait starts again
    docker compose down                       stop and remove the containers; the data stays

`docker compose down -v` **deletes all your data**. Never run it unless you want to start from
nothing.

**Update.** Pull the newest release and restart with it:

    docker compose pull && docker compose up -d --wait

To stay on one release, set `FINMAN_VERSION=1.2.3` in `.env` (without the `v`).

**Backups.** Your records are in PostgreSQL, and the app's files (`config.toml`, `secrets.toml`,
statements, jobs) are in the volume `appdata`:

    docker compose exec -T db sh -c 'pg_dump -U "$POSTGRES_USER" "$POSTGRES_DB"' > finman-db.sql
    docker compose exec -T app tar -C /data -cf - . > finman-data.tar

To restore both into a new installation, before the app's first start (the app would create
empty tables that the restore then clashes with):

    docker compose up -d --wait db redis
    docker compose exec -T db sh -c 'psql -q -U "$POSTGRES_USER" "$POSTGRES_DB"' < finman-db.sql
    docker compose run --rm -T --no-deps --entrypoint tar app -C /data -xf - < finman-data.tar
    docker compose up -d --wait

To restore over an existing installation, wipe it first with `docker compose down -v`.

**The settings file.** The app's `config.toml` is `/data/config.toml` in the container: edit it
with `docker compose exec app vi /data/config.toml`, then run `docker compose restart app`.

## First steps in the app

Home shows a short checklist until the basics are done:

1. **Settings → About you**: your income, monthly spending, how much risk you are comfortable
   with, your tax regime, and a few facts about your life. An administrator also sees
   **AI services → Check all** (which AI services are ready), **AI access** and **API keys**.
2. **Upload statements**: say what the file is, upload it, check the rows, and press *Apply
   selected rows*. Nothing reaches your records before that.
3. **Add by hand** what no statement covers: PPF, EPF, NPS, FDs, gold, property, cash and loans.
4. **Prices**: one button updates fund NAVs and share prices. They also update on a schedule.
5. Then **Goals**, **Plan**, **SIPs**, **Tax**, **To-do**, **Ask the AI** and **Reports**.

Every page has a "How does this work?" box, and words marked (?) explain themselves when you
point at them.

## AI services

The advisor, the reports and the reading of unusual statements ask AI models, so you need at
least one of these. Everything else works without one.

| Service | What you need |
| --- | --- |
| Anthropic API | an API key: on the Settings page, or `ANTHROPIC_API_KEY` |
| OpenAI API | an API key: on the Settings page, or `OPENAI_API_KEY` |
| Gemini API | an API key: on the Settings page, or `GEMINI_API_KEY` |
| Claude Code (`claude`) | signed in with a Pro or Max plan; Option 1 only |
| OpenAI Codex CLI (`codex`) | signed in with ChatGPT; Option 1 only |
| Antigravity CLI (`agy`) | signed in; Option 1 only |

- The APIs are on out of the box. An administrator turns the command-line tools on under
  **Settings → AI access**, which can also send each API to another address (a proxy, a gateway,
  or a compatible local server).
- API keys are billed per call. The command-line tools use your subscriptions.
- Keys typed on the Settings page are saved in `secrets.toml` in the data folder.
- Which service answers what (one service, a fallback list, or a committee of several) is set by
  an administrator on the Settings page.
- With Docker, a server on your own computer (a local model, a proxy) is
  `http://host.docker.internal:PORT` from the app.

## Opening it from other devices

The app answers only on this computer by default. To reach it from your home network or
Tailscale, put this in `config.toml` (`~/.finman/data/config.toml`, or `/data/config.toml` in
Docker):

    [server]
    allow_lan = true
    host = "0.0.0.0"

With Docker, also set `APP_BIND=0.0.0.0` in `.env`. Then restart the app. The app has no HTTPS
of its own, so anyone on that network can reach its sign-in page: give every account a strong
password, and open it only on networks you trust.

## License

MIT: see [LICENSE](LICENSE).
