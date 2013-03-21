#!/bin/bash

set -e
cd "$(dirname "$0")"/moz-git
# Assert clean
[ -z "$(git status -s)" ]
rev=$1
[ ! -z "$rev" ]

cat hg-git-mapfile | sed -r "/$rev/ d" > new
mv new hg-git-mapfile
git diff
