#!/bin/bash

set -e

dir="$1"
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

echo ":: Updating $dir"
cd "mozilla-$dir"
if [ ! -e .hg/git ] || [ ! -e .hg/git-mapfile ] || [ ! -e .hg/git-branch ]; then
    die "Branch $dir does not have the proper git files to export from hg!"
fi

oldrev=$(hg log -r tip --template='{rev}')

# Mozilla bug: https://bugzilla.mozilla.org/show_bug.cgi?id=737865
# Sometimes pulling corrupts our repo. Yay. Revert any changes that hit the tree
# and strip from our old (and presumably known-good) revision forward, then do
# an |hg up -C && hg purge --all| to clean the working tree. The next update
# should detect a change and proceed normally.
recover() {
    echo "!! Hg pull/update failed, possibly corrupt, running recovery"
    > .hg/bookmarks
    hg strip --no-backup $oldrev:
    die "!! Attempted recovery, bailing"
}

hg pull || recover

newrev=$(hg log -r tip --template='{rev}')
if [ "$oldrev" != "$newrev" ] || [ ! -z "$force" ]; then
    echo ":: Updating $oldrev -> $newrev"
    changes=1
    bookmark="$(cat .hg/git-branch)"
    rm -v .hg/bookmarks
      # Bookmark tip
    hg bookmark -r tip "$bookmark"
      # Convert all non-default heads to tags (will be blown away by hg up -C)
    while read -r line; do
        branch="${line% *}"
        node="${line#* }"
        [ "$branch" != "None" ] || branch="$node"
        if [ "$branch" != "default" ]; then
            hg bookmark -r "$node" heads/"$bookmark"/"$branch"
        fi
    done < <(hg heads --template '{branch} {node}\n')
    hg bookmarks
    hg gexport -v || recover
fi

cd ..

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
	git commit hg-git-mapfile -m "Sync'd branch $dir with upstream @ $(date)"
	  # As of git v1.7.5.4, it can take two of these to update everything
	  # (some refs don't get pushed the first time, no idea)
	  # (actually this could just be github's weird custom git server having some
	  #  delay...)
	git push github --mirror
	git push github --mirror
)
