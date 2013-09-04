#!/bin/bash

targets=(esr17 b2g18 b2g18_v1_0_0 b2g18_v1_0_1 release beta aurora \
         electrolysis profiling fx-team \
         ionmonkey ux birch larch central inbound)

for x in "${targets[@]}"; do
    ./update.sh "$x" "$@"
done
