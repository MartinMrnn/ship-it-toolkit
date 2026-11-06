#!/usr/bin/env bash
# Set a single-select field (Status, Priority) on an issue, adding the issue to the project if needed.
# Usage: set-field.sh "<project title>" <issue url> <Field> <Value>
set -euo pipefail
[ $# -eq 4 ] || { echo "Usage: set-field.sh \"<project>\" <issue-url> <Field> <Value>" >&2; exit 2; }
title=$1 url=$2 field=$3 value=$4
owner=$(cut -d/ -f4 <<<"$url")

num=$(gh project list --owner "$owner" --limit 100 --format json \
  --jq ".projects[] | select(.title==\"$title\") | .number")
[ -n "$num" ] || { echo "Project not found: $title" >&2; exit 1; }

pid=$(gh project view "$num" --owner "$owner" --format json --jq .id)
f=$(gh project field-list "$num" --owner "$owner" --format json --jq ".fields[] | select(.name==\"$field\")")
fid=$(jq -r '.id // empty' <<<"${f:-null}")
oid=$(jq -r --arg v "$value" '.options[]? | select(.name==$v) | .id' <<<"${f:-null}")
[ -n "$fid" ] && [ -n "$oid" ] || { echo "Unknown field or value: $field = $value" >&2; exit 1; }

# item-add is idempotent: it returns the existing item when the issue is already on the board.
item=$(gh project item-add "$num" --owner "$owner" --url "$url" --format json --jq .id)
gh project item-edit --id "$item" --project-id "$pid" --field-id "$fid" --single-select-option-id "$oid" >/dev/null
echo "$url → $field = $value"
