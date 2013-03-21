#!/bin/bash

targets=(esr10 esr17 b2g18 b2g18_v1_0_0 b2g18_v1_0_1 release beta aurora \
         electrolysis bill-electrolysis profiling fx-team jaegermonkey \
         ionmonkey ux birch central inbound)

for x in "${targets[@]}"; do
    ./update.sh "$x" "$@"
done
