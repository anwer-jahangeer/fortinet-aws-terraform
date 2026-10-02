#!/bin/bash
set -euo pipefail

mode=normal
if [[ ${1:-} == "--replace-fortigate" ]]; then
    mode=replace-fortigate
    shift
elif [[ ${1:-} == "--migrate-isps" ]]; then
    mode=migrate-isps
    shift
fi

plan_file=${1:-branch2.tfplan}

if [[ $mode == replace-fortigate ]] && terraform state show aws_instance.fortigate >/dev/null 2>&1; then
    terraform plan -replace=aws_instance.fortigate -out "$plan_file"
else
    if [[ $mode == replace-fortigate ]]; then
        echo "Branch2 FortiGate is absent from state; planning partial-apply recovery."
    fi
    terraform plan -out "$plan_file"
fi

if terraform show -json "$plan_file" |
    jq -e --arg mode "$mode" '
      [.resource_changes[]? | select(.change.actions | index("delete"))] as $destructive
      | if $mode == "normal" then
          ($destructive | length) == 0
        elif $mode == "replace-fortigate" then
          all($destructive[];
            .address == "aws_instance.fortigate"
            and (.change.actions | sort) == ["create", "delete"])
        else
          all($destructive[];
            (.address == "aws_instance.fortigate"
             or .address == "aws_network_interface.port1"
             or .address == "aws_network_interface.port3")
            and (.change.actions | sort) == ["create", "delete"])
        end
    ' >/dev/null; then
    echo "Safe plan: no unrelated destructive changes were detected."
else
    echo "Unsafe plan: destructive changes are not limited to the intended Branch2 FortiGate replacement." >&2
    exit 1
fi

terraform show "$plan_file"
