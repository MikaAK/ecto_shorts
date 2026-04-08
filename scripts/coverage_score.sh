#!/usr/bin/env bash
set -euo pipefail
# Run ExCoveralls in JSON mode, capture all output, then extract the final
# coverage percentage line printed by excoveralls (e.g. "[87.4%]").
mix coveralls.json >/tmp/cov.out 2>&1
grep '\[TOTAL\]' /tmp/cov.out | grep -oE '[0-9]+\.[0-9]+'
