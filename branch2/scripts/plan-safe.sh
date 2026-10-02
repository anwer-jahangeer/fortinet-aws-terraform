#!/bin/bash
set -euo pipefail

replace_fortigate=false
if [[ ${1:-} == "--replace-fortigate" ]]; then
    replace_fortigate=true
    shift
fi

plan_file=${1:-branch2.tfplan}

if $replace_fortigate && terraform state show aws_instance.fortigate >/dev/null 2>&1; then
    terraform plan -replace=aws_instance.fortigate -out "$plan_file"
else
    if $replace_fortigate; then
        echo "Branch2 FortiGate is absent from state; planning partial-apply recovery."
    fi
    terraform plan -out "$plan_file"
fi

if terraform show -json "$plan_file" |
    jq -e '
      [.resource_changes[]? | select(.change.actions | index("delete"))] as $destructive
      | ($destructive | length) == 0
      or (
        ($destructive | length) == 1
        and $destructive[0].address == "aws_instance.fortigate"
        and $destructive[0].change.actions == ["delete", "create"]
      )
    ' >/dev/null; then
    echo "Safe plan: no unrelated destructive changes were detected."
else
    echo "Unsafe plan: destructive changes are not limited to the intended Branch2 FortiGate replacement." >&2
    exit 1
fi

terraform show "$plan_file"
