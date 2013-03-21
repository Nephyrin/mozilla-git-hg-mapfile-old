#!/bin/bash
set -e
cd "$(dirname "$0")"

cd moz-git
flock -n ../gc.lck ionice -c3 nice -n20 git gc --no-prune
cd ../moz-git-map
flock -n ../gc.lck ionice -c3 nice -n20 git gc --no-prune
