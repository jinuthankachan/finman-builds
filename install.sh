#!/bin/sh
# Installs, updates or removes finman on Linux (x86-64, ARM64) and macOS (Apple silicon).
#
#   curl -fsSL https://raw.githubusercontent.com/jinuthankachan/finman-builds/main/install.sh | sh
#   curl -fsSL https://raw.githubusercontent.com/jinuthankachan/finman-builds/main/install.sh | sh -s -- update
#   curl -fsSL https://raw.githubusercontent.com/jinuthankachan/finman-builds/main/install.sh | sh -s -- uninstall
#
# Everything goes in ~/.finman (FINMAN_HOME):
#
#   bin/invest   the program, from https://github.com/jinuthankachan/finman-builds/releases
#   bin/finman   the command you run: bin/invest on the data folder below
#   data/        your records, settings, statements and backups
#   VERSION      the release installed
#
# and the command finman in ~/.local/bin (FINMAN_BIN_DIR) links to bin/finman. Every download is
# checked against the release's SHA256SUMS before it is used.

set -eu

REPO=jinuthankachan/finman-builds
FINMAN_HOME=${FINMAN_HOME:-$HOME/.finman}
BIN_DIR=${FINMAN_BIN_DIR:-$HOME/.local/bin}
DATA_DIR=$FINMAN_HOME/data

usage() {
	cat <<'EOF'
usage: install.sh [install | update | uninstall] [options]

  install      install the newest release (the default)
  update       back up your records, then install the newest release
  uninstall    remove the program; your data stays in ~/.finman/data

options:
  --version V  install or update to the release V (e.g. v1.2.3) instead of the newest
  --no-backup  update without backing up the records first
  --purge      uninstall: delete ~/.finman/data too (your records, statements and backups)
  --yes        do not ask before --purge deletes the data

environment: FINMAN_HOME (default ~/.finman), FINMAN_BIN_DIR (default ~/.local/bin)
EOF
}

say() { printf '%s\n' "$*"; }
warn() { printf 'finman: %s\n' "$*" >&2; }
die() {
	printf 'finman: error: %s\n' "$*" >&2
	exit 1
}

need() {
	command -v "$1" >/dev/null 2>&1 || die "$1 is needed: install it, then run this again"
}

installed() { [ -x "$FINMAN_HOME/bin/invest" ]; }

installed_version() { cat "$FINMAN_HOME/VERSION" 2>/dev/null || echo "(unknown version)"; }

# running: is the installed program running (the app, or a command such as finman backup)?
running() {
	command -v pgrep >/dev/null 2>&1 && pgrep -f "^$FINMAN_HOME/bin/invest( |\$)" >/dev/null 2>&1
}

# platform sets ASSET, the release file for this computer.
platform() {
	os=$(uname -s)
	arch=$(uname -m)
	case $os in
	Linux) os=linux ;;
	Darwin) os=darwin ;;
	*) die "there is no finman program for $os: Linux and macOS only (on Windows use WSL, or Docker)" ;;
	esac
	case $arch in
	x86_64 | amd64) arch=amd64 ;;
	aarch64 | arm64) arch=arm64 ;;
	*) die "there is no finman program for $arch processors: use Docker (see the README)" ;;
	esac
	if [ "$os" = darwin ] && [ "$arch" = amd64 ]; then
		# A terminal running under Rosetta reports x86_64 on an Apple-silicon Mac.
		if [ "$(sysctl -n hw.optional.arm64 2>/dev/null || true)" = 1 ]; then
			arch=arm64
		else
			die "there is no finman program for Intel Macs: use Docker (see the README)"
		fi
	fi
	ASSET=invest-$os-$arch
}

# target_tag prints the release to install: --version, else the newest.
target_tag() {
	if [ -n "$VERSION" ]; then
		case $VERSION in
		v*) printf '%s\n' "$VERSION" ;;
		*) printf 'v%s\n' "$VERSION" ;;
		esac
		return
	fi
	url=$(curl -fsSLI -o /dev/null -w '%{url_effective}' "https://github.com/$REPO/releases/latest") ||
		die "cannot find the newest release at https://github.com/$REPO/releases"
	case $url in
	*/releases/tag/v*) printf '%s\n' "${url##*/}" ;;
	*) die "there is no release yet at https://github.com/$REPO/releases" ;;
	esac
}

sha256() {
	if command -v sha256sum >/dev/null 2>&1; then
		sha256sum "$1" | cut -d ' ' -f 1
	elif command -v shasum >/dev/null 2>&1; then
		shasum -a 256 "$1" | cut -d ' ' -f 1
	else
		die "sha256sum or shasum is needed to check the download"
	fi
}

# download TAG fetches the program of release TAG into $TMP/invest and checks it.
download() {
	base=https://github.com/$REPO/releases/download/$1
	say "Downloading $ASSET $1"
	curl -fSL --progress-bar --retry 3 -o "$TMP/invest" "$base/$ASSET" ||
		die "the download of $base/$ASSET failed (is $1 a release of finman?)"
	curl -fsSL --retry 3 -o "$TMP/SHA256SUMS" "$base/SHA256SUMS" ||
		die "the download of $base/SHA256SUMS failed"
	want=$(awk -v f="$ASSET" '$2 == f || $2 == "*" f { print $1 }' "$TMP/SHA256SUMS")
	[ -n "$want" ] || die "SHA256SUMS of $1 has no line for $ASSET"
	[ "$(sha256 "$TMP/invest")" = "$want" ] ||
		die "$ASSET does not match its checksum: the download is damaged; nothing was changed"
	chmod 755 "$TMP/invest"
}

# place TAG puts the checked download in place, with the launcher and the link.
place() {
	mv -f "$TMP/invest" "$FINMAN_HOME/bin/invest"
	cat >"$TMP/finman" <<EOF
#!/bin/sh
# finman: the program in $FINMAN_HOME/bin on its data folder. Written by install.sh.
INVEST_DATA_DIR="$DATA_DIR"
export INVEST_DATA_DIR
exec "$FINMAN_HOME/bin/invest" "\$@"
EOF
	chmod 755 "$TMP/finman"
	mv -f "$TMP/finman" "$FINMAN_HOME/bin/finman"
	printf '%s\n' "$1" >"$FINMAN_HOME/VERSION"
	link
}

ours() { [ "$(readlink "$BIN_DIR/finman" 2>/dev/null || true)" = "$FINMAN_HOME/bin/finman" ]; }

# check_link stops before anything is downloaded when the command name is taken.
check_link() {
	if [ -e "$BIN_DIR/finman" ] || [ -L "$BIN_DIR/finman" ]; then
		ours || die "$BIN_DIR/finman already exists and is not this finman: move it away, or set FINMAN_BIN_DIR"
	fi
}

link() {
	ours && return
	mkdir -p "$BIN_DIR"
	ln -s "$FINMAN_HOME/bin/finman" "$BIN_DIR/finman"
}

path_hint() {
	case :$PATH: in
	*:"$BIN_DIR":*) return ;;
	esac
	say ""
	say "$BIN_DIR is not on your PATH yet. Add it, then open a new terminal:"
	case ${SHELL:-} in
	*/zsh) say "    echo 'export PATH=\"$BIN_DIR:\$PATH\"' >> ~/.zshrc" ;;
	*/fish) say "    fish_add_path $BIN_DIR" ;;
	*/bash)
		if [ "$(uname -s)" = Darwin ]; then rc=~/.bash_profile; else rc=~/.bashrc; fi
		say "    echo 'export PATH=\"$BIN_DIR:\$PATH\"' >> $rc"
		;;
	*) say "    export PATH=\"$BIN_DIR:\$PATH\"    (in your shell's startup file)" ;;
	esac
	say "Until then, run it as $FINMAN_HOME/bin/finman."
}

# backup copies the SQLite records with the installed program, which is safe while it runs.
backup() {
	[ "$NO_BACKUP" = 0 ] && [ -f "$DATA_DIR/invest.db" ] || return 0
	say "Backing up your records first, with the installed finman $1"
	status=0
	INVEST_DATA_DIR=$DATA_DIR "$FINMAN_HOME/bin/invest" backup || status=$?
	case $status in
	0) ;;
	2) say "(your records are not in the SQLite file: back up that database yourself)" ;;
	*) die "the backup failed, so nothing was changed: fix the error above, or run update with --no-backup" ;;
	esac
}

# workdir makes TMP, a scratch folder on the same disk as the program, so the final move is
# a rename: a running program keeps its old file, and a new start gets the new one.
workdir() {
	mkdir -p "$FINMAN_HOME/bin"
	TMP=$(mktemp -d "$FINMAN_HOME/.download.XXXXXX")
	trap 'rm -rf "$TMP"' EXIT
	trap 'exit 1' HUP INT TERM
}

cmd_install() {
	if installed; then
		die "finman $(installed_version) is already installed in $FINMAN_HOME: run update instead"
	fi
	need curl
	platform
	check_link
	tag=$(target_tag)
	workdir
	download "$tag"
	mkdir -p "$DATA_DIR"
	chmod 700 "$DATA_DIR"
	place "$tag"
	say ""
	say "finman $tag is installed in $FINMAN_HOME; your data will be in $DATA_DIR."
	say "Start it with: finman    then open http://127.0.0.1:8790 (Ctrl+C stops it)"
	path_hint
}

cmd_update() {
	installed || die "finman is not installed in $FINMAN_HOME: run install first"
	need curl
	platform
	check_link
	current=$(installed_version)
	tag=$(target_tag)
	if [ "$tag" = "$current" ]; then
		link
		say "finman $current is up to date."
		return
	fi
	workdir
	download "$tag"
	backup "$current"
	place "$tag"
	say ""
	say "finman is updated from $current to $tag."
	if running; then
		say "It is running now: stop it (Ctrl+C) and start it again to use $tag."
	fi
	path_hint
}

confirm_purge() {
	[ "$YES" = 1 ] && return 0
	(: </dev/tty) 2>/dev/null ||
		die "--purge deletes your records: add --yes when there is no terminal to ask in"
	printf 'This deletes %s: all your records, statements and backups. Type delete to go on: ' "$DATA_DIR" >/dev/tty
	read -r answer </dev/tty || answer=
	[ "$answer" = delete ] || die "nothing was deleted"
}

cmd_uninstall() {
	if ! installed && { [ "$PURGE" = 0 ] || [ ! -d "$DATA_DIR" ]; }; then
		die "finman is not installed in $FINMAN_HOME"
	fi
	if [ "$PURGE" = 1 ]; then
		! running || die "finman is running: stop it first, then uninstall"
		[ -d "$DATA_DIR" ] && confirm_purge
	elif running; then
		warn "finman is running; it keeps running until you stop it"
	fi
	if ours; then rm -f "$BIN_DIR/finman"; fi
	rm -f "$FINMAN_HOME/bin/invest" "$FINMAN_HOME/bin/finman" "$FINMAN_HOME/VERSION"
	rmdir "$FINMAN_HOME/bin" 2>/dev/null || true
	if [ "$PURGE" = 1 ]; then
		rm -rf "$DATA_DIR"
		rmdir "$FINMAN_HOME" 2>/dev/null || true
		say "finman and its data are removed."
	else
		say "finman is removed. Your data is still in $DATA_DIR:"
		say "install again to use it, or delete it with: install.sh uninstall --purge"
	fi
}

main() {
	CMD=install
	VERSION=
	PURGE=0
	YES=0
	NO_BACKUP=0
	while [ $# -gt 0 ]; do
		case $1 in
		install | update | uninstall) CMD=$1 ;;
		--version)
			[ $# -ge 2 ] || die "--version needs a release, e.g. --version v1.2.3"
			VERSION=$2
			shift
			;;
		--version=*) VERSION=${1#*=} ;;
		--no-backup) NO_BACKUP=1 ;;
		--purge) PURGE=1 ;;
		--yes | -y) YES=1 ;;
		help | -h | --help)
			usage
			exit 0
			;;
		*) die "unknown argument $1 (see install.sh --help)" ;;
		esac
		shift
	done
	[ "$PURGE" = 0 ] || [ "$CMD" = uninstall ] || die "--purge goes with uninstall"
	[ -z "$VERSION" ] || [ "$CMD" != uninstall ] || die "--version goes with install or update"
	[ -n "${HOME:-}" ] || die "HOME is not set"
	"cmd_$CMD"
}

# The whole script is read before anything runs, so a download cut short does nothing.
main "$@"
