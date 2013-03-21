#!/bin/bash
set -e
cd "$(dirname "$0")"/moz-git

# Assert clean
[ -z "$(git status -s)" ]

total="$(wc -l ../moz-git-map/hg-git-mapfile | cut -d ' ' -f 1)"
i=0
deleted=0
while read line; do
  x=${line% *};
  if ! git show --format="" $x >/dev/null; then
    echo ":: Deleting $x"
    (( deleted++ )) || true
  else
    echo "$line" >> ../moz-git-map/hg-git-mapfile.new
  fi
  (( i++ )) || true
  pct=$(printf "%04i" $(( (i * 10000) / total )))
  echo -en "\r$x :: $i/$total ${pct%??}.${pct:(-2)}%"
done < ../moz-git-map/hg-git-mapfile

echo ":: Deleted $deleted missing commits, wrote hg-git-mapfile.new"
