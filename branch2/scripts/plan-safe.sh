#!/bin/bash
set -euo pipefail

plan_file=${1:-branch2.tfplan}

terraform plan -out "$plan_file"

if terraform show -json "$plan_file" |
    jq -e '[.resource_changes[]? | select(.change.actions | index("delete"))] | length == 0' >/dev/null; then
    echo "Safe plan: no delete or replacement actions were detected."
else
    echo "Unsafe plan: at least one delete or replacement action was detected." >&2
    exit 1
fi

terraform show "$plan_file"
