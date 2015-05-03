#!/bin/sh

option='-a --delete'

# lock
PIDFILE="/tmp/`basename $0`.pid"
if [ -e $PIDFILE ] && kill -0 `cat $PIDFILE`; then
	echo 'already running' 1>&2
	exit
fi

trap "rm -f $PIDFILE; exit" INT TERM EXIT
echo $$ > $PIDFILE

function usage {
	cat <<-EOT
		Usage: $(basename $0) SRC DEST
		Backup SRC to DEST using rsync.
		
		  -n	dryrun
	EOT
}

while getopts "hnv" opt; do
	case $opt in
		h) usage && exit 0;;
		n) dryrun=1; option="$option -n";;
		v) verbose=1;;
	esac
done

shift $(expr $OPTIND - 1)

[ ! -z $verbose ] && option="$option -v"

[ $# -ne 2 ] && usage && exit 1

[ ! -d $1 ] && usage && exit 1
[ ! -d $2 ] && usage && exit 1
src=$(cd $1 && pwd)
dest=$(cd $2 && pwd)
name=$(echo $src | sed 's|/|_|g')

if [ -d $dest/$name ]; then
	ls $dest/$name | grep -v '[0-9]\{8\}' > /dev/null && echo "The structure of $dest/$name is not suitable." && exit 1
	last=$dest/$name/$(ls -t $dest/$name | head -n1)
else
	last=$src
fi
new=$dest/$name/$(date +%Y%m%d%H%M)
[ -z $dryrun ] && mkdir -p $new

command="rsync $option --link-dest=$last $src/ $new/"
[ ! -z $verbose ] && echo $command 
eval $command

oldDirs=$(ls $dest/$name | awk '$1<'$(date --date 'month ago' +'%Y%m%d%H%M')' {print}')
[ -z $verbose ] \
	&& command="(cd $dest/$name; rm -rf $oldDirs)" \
	|| command="(cd $dest/$name; rm -rfv $oldDirs)"
[ ! -z $verbose ] && echo $command 
[ -z $dryrun ] && eval $command
