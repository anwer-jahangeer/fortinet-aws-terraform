#!/bin/bash
set -euo pipefail

plan_file=${1:-branch2.tfplan}

terraform plan -replace=aws_instance.fortigate -out "$plan_file"

if terraform show -json "$plan_file" |
    jq -e '
      [.resource_changes[]? | select(.change.actions | index("delete"))] as $destructive
      | ($destructive | length) == 1
      and $destructive[0].address == "aws_instance.fortigate"
      and $destructive[0].change.actions == ["delete", "create"]
    ' >/dev/null; then
    echo "Safe plan: only the Branch2 FortiGate instance will be replaced."
else
    echo "Unsafe plan: destructive changes are not limited to the intended Branch2 FortiGate replacement." >&2
    exit 1
fi

terraform show "$plan_file"
