#!/bin/bash
set -e
cd "$(dirname "$0")"

flock -n ./cron.lck echo cron not running || echo '!!' cron running
flock -n ./gc.lck echo gc not running || echo '!!' gc running
