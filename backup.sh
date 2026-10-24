#!/bin/sh

rsync_option='-a --delete -x'

usage() {
	cat <<-EOT
		Usage: $(basename "$0") [OPTION] SRC DEST
		Backup SRC to DEST using rsync.

		  -e	exclude
		  -h	help
		  -i	include
		  -n	dryrun
		  -v	verbose
	EOT
}

while getopts "e:hi:nv" opt; do
	case $opt in
		e) rsync_option="$rsync_option --exclude='$OPTARG'";;
		h) usage && exit 0;;
		i) rsync_option="$rsync_option --include='$OPTARG'";;
		n) dryrun=1;;
		v) verbose=1;;
	esac
done

shift $(expr "$OPTIND" - 1)

[ $# -ne 2 ] && usage && exit 1
[ ! -d "$1" ] && usage && exit 1
[ ! -d "$2" ] && usage && exit 1

src=$(cd "$1" && pwd) || exit 1
dest=$(cd "$2" && pwd) || exit 1
name=$(echo "$src" | sed 's|/|_|g')
series="$dest/$name"

# lock
PIDFILE="/tmp/backup$name.pid"
if [ -e "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
	echo 'already running' 1>&2
	exit 1
fi

workdir=
cleanup() {
	[ -z "$workdir" ] || rm -rf -- "$workdir"
	rm -f -- "$PIDFILE"
}
trap cleanup 0
trap 'exit 130' 2
trap 'exit 143' 15
echo $$ > "$PIDFILE"

# Only timestamped snapshots are eligible as --link-dest references.
# In-progress copies use a hidden temporary directory and are never reused.
last=
for candidate in "$series"/[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]; do
	[ -d "$candidate" ] && last=$candidate
done

new="$series/$(date +%Y%m%d%H%M)"
if [ -e "$new" ]; then
	echo "Backup already exists: $new" >&2
	exit 1
fi

if [ -n "$dryrun" ]; then
	target=$new
	rsync_option="$rsync_option -n"
else
	mkdir -p -- "$series" || exit 1
	workdir=$(mktemp -d "$series/.incomplete.XXXXXXXX") || exit 1
	target=$workdir
fi

if [ -n "$verbose" ]; then
	rsync_option="$rsync_option -v"
fi

link_option=
if [ -n "$last" ]; then
	link_option="--link-dest=\"$last\""
fi

eval "rsync $rsync_option $link_option \"$src/\" \"$target/\""
status=$?
if [ "$status" -ne 0 ]; then
	echo "Backup failed (rsync exit status: $status)" >&2
	exit "$status"
fi

# Publish a snapshot only after rsync succeeds.
if [ -z "$dryrun" ]; then
	mv -- "$workdir" "$new" || exit 1
	workdir=

	# Keep one month of completed snapshots.
	cutoff=$(date --date 'month ago' +%Y%m%d%H%M) || exit 1
	for old in "$series"/[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]; do
		[ -d "$old" ] || continue
		[ "$(basename "$old")" -lt "$cutoff" ] || continue
		if [ -n "$verbose" ]; then
			rm -rfv -- "$old" || exit 1
		else
			rm -rf -- "$old" || exit 1
		fi
	done
fi
