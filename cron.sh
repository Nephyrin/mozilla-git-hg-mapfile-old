#!/bin/bash
set -e
cd "$(dirname "$0")"

flock -n ./cron.lck ionice -c3 nice -n20 ./update-all.sh "$@"
