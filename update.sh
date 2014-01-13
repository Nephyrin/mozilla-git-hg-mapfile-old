#!/bin/bash

set -e

branch="$1"
force="$2"

die() {
    echo "!! $*"
    exit 1
}

[ $# -eq 2 ] || [ $# -eq 1 ] || die "Usage: ./update.sh branch [force]"
[ $# -ne 2 ] || [ "$2" = "force" ] || die "Second argument must be 'force'"

cd "$(dirname "$0")"

hg --version

# If this cron is killed for some reason, it can leave hg-git-mapfile empty
# so if forwhatever reason we didn't commit our last changes to hg-git-mapfile,
# nuke it
#echo >&2 "!! FIX INCOMPLETE CHANGE NUKING AND SYNC"
echo ":: Nuking any incomplete changes"
(
  cd "moz-git-map"
  git checkout -f
)

echo ":: Updating $branch"
cd "mozilla-hg"
if [ ! -e .hg/git ] || [ ! -e .hg/git-mapfile ]; then
    die "Branch $branch does not have the proper git files to export from hg!"
fi

# Mozilla bug: https://bugzilla.mozilla.org/show_bug.cgi?id=737865
# Sometimes pulling corrupts our repo. Yay. Save the old (presumably good)
# tipand strip everything since then if a command fails
recover() {
    echo "!! Hg pull/update failed, possibly corrupt, running recovery"
    > .hg/bookmarks
    hg strip --no-backup $oldtip:
    die "!! Attempted recovery, bailing"
}

oldrev=$(hg log -r tip --template='{rev}')
oldtip=$(hg log -r tip --template='{node}')
# Use python API to get all branches from remote to save as bookmarks. Do
# this before pulling, so races wont try to bookmark an unpulled rev
new_branches="$(cat <<EOF | python2
from mercurial import ui, hg, node

peer = hg.peer(ui.ui(), {}, "$(hg showconfig paths.$branch)")
for name, rev in peer.branchmap().items():
    print("heads/$branch/%s %s" % (name, node.short(rev[0])))
EOF
)"
hg pull $branch || recover

newrev=$(hg log -r tip --template='{rev}')
if [ "$oldrev" != "$newrev" ] || [ ! -z "$force" ]; then
    echo ":: Updating $oldrev -> $newrev"
    changes=1
    bookmarkfile=".hg/bookmarks-$branch"
    # Bookmark tip (and blow-away bookmark file)
    echo "$branch $(hg identify -r default $branch)" > "$bookmarkfile"
    echo "$new_branches" >> "$bookmarkfile"
    cat .hg/bookmarks-* > .hg/bookmarks
    hg bookmarks
    hg gexport -v || recover
fi

cd ..

echo "!! NOT COMMITTING"
exit 1

export GIT_COMMITTER_EMAIL="johns@mozilla.com"
export GIT_COMMITTER_NAME="John Schoenick"
export GIT_AUTHOR_EMAIL="noreply@bangles.mv.mozilla.com"
export GIT_AUTHOR_NAME="Bangles"

if [ -z "$changes$force" ]; then
    echo ":: No changes, done"
    exit
fi

(
	echo ":: Updating main repo"
	export GIT_SSH="$PWD/ssh_github_key.sh"
	cd "moz-git"
	git push github --mirror
	git push github --mirror
)

(
	export GIT_SSH="$PWD/ssh_github_map_key.sh"
	cd "moz-git-map"
	echo ":: Updating mapfile"
	git commit hg-git-mapfile -m "Sync'd branch $branch with upstream @ $(date)"
	  # As of git v1.7.5.4, it can take two of these to update everything
	  # (some refs don't get pushed the first time, no idea)
	  # (actually this could just be github's weird custom git server having some
	  #  delay...)
	git push github --mirror
	git push github --mirror
)
