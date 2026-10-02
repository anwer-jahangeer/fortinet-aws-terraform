#!/bin/bash
set -euo pipefail

plan_file=${1:-branch2.tfplan}

if terraform state show aws_instance.fortigate >/dev/null 2>&1; then
    terraform plan -replace=aws_instance.fortigate -out "$plan_file"
else
    echo "Branch2 FortiGate is absent from state; planning partial-apply recovery."
    terraform plan -out "$plan_file"
fi

if terraform show -json "$plan_file" |
    jq -e '
      [.resource_changes[]? | select(.change.actions | index("delete"))] as $destructive
      | [.resource_changes[]? | select(
          .address == "aws_instance.fortigate"
          and (.change.actions == ["create"] or .change.actions == ["delete", "create"])
        )] as $fortigate_changes
      | ($fortigate_changes | length) == 1
      and (
        ($destructive | length) == 0
        or (
          ($destructive | length) == 1
          and $destructive[0].address == "aws_instance.fortigate"
          and $destructive[0].change.actions == ["delete", "create"]
        )
      )
    ' >/dev/null; then
    echo "Safe plan: Branch2 recovery/replacement contains no unrelated destructive changes."
else
    echo "Unsafe plan: destructive changes are not limited to the intended Branch2 FortiGate replacement." >&2
    exit 1
fi

terraform show "$plan_file"
