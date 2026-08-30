#!/usr/bin/env bash
# A moved public API needs a changelog entry in the same change.
# Usage: script/check_api_changelog.sh [base-ref]
set -euo pipefail

base="${1:-origin/master}"
changed="$(git diff --name-only "$base"...HEAD)"

if ! grep -qx 'spec/fixtures/public_api.json' <<<"$changed"; then
  exit 0
fi

if grep -qx 'CHANGELOG.md' <<<"$changed"; then
  exit 0
fi

cat >&2 <<MSG
The public API moved and CHANGELOG.md did not.

spec/fixtures/public_api.json changed in this branch, which means a name or a
shape that someone's code can depend on is different. Say what changed and
what to write instead, under ## [Unreleased] in CHANGELOG.md.

docs/stability.md says what counts as a break.
MSG
exit 1
