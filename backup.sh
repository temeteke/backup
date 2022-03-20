#!/bin/sh

rsync_option='-a --delete'

# lock
PIDFILE="/tmp/`basename $0`.pid"
if [ -e $PIDFILE ] && kill -0 `cat $PIDFILE`; then
	echo 'already running' 1>&2
	exit 1
fi

trap "rm -f $PIDFILE; exit" INT TERM EXIT
echo $$ > $PIDFILE

myeval() {
	[ -n "$verbose" ] && echo "$*"
	[ -z "$dryrun" ] && eval "$*"
}

usage() {
	cat <<-EOT
		Usage: $(basename $0) [OPTION] SRC DEST
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

shift $(expr $OPTIND - 1)

[ $# -ne 2 ] && usage && exit 1

[ ! -d $1 ] && usage && exit 1
[ ! -d $2 ] && usage && exit 1

src=$(cd $1 && pwd)
dest=$(cd $2 && pwd)
name=$(echo $src | sed 's|/|_|g')

if [ -d $dest/$name ]; then
	ls $dest/$name | grep -v '[0-9]\{8\}' > /dev/null && echo "The structure of $dest/$name is not suitable." && exit 1
	last=$dest/$name/$(ls $dest/$name | tail -n1)
else
	last=$src
fi
new=$dest/$name/$(date +%Y%m%d%H%M)
myeval "mkdir -p $new"

if [ -n "$dryrun" ]; then
	rsync_option="$rsync_option -n"
fi
if [ -n "$verbose" ]; then
	rsync_option="$rsync_option -v"
fi
(unset dryrun; myeval "rsync $rsync_option --link-dest=$last $src/ $new/")

old_dirs=$(ls $dest/$name | awk '$1<'$(date --date 'month ago' +'%Y%m%d%H%M')' {print}')
if [ -n "$old_dirs" ]; then
	if [ -z "$verbose" ]; then
		myeval "(cd $dest/$name; rm -rf $old_dirs)"
	else
		myeval "(cd $dest/$name; rm -rfv $old_dirs)"
	fi
fi
