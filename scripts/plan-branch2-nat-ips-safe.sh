#!/bin/bash
set -euo pipefail

plan_file=${1:-branch2-nat-ips.tfplan}

# The deployed main stack contains unrelated AMI and manually managed drift.
# Targeting is intentional here so Stage 1 can only extend the existing ENI.
terraform plan \
    -target=aws_network_interface.internet_router_outside \
    -out "$plan_file"

if terraform show -json "$plan_file" |
    jq -e '
      [.resource_changes[]? | select(.change.actions != ["no-op"])] as $changes
      | all($changes[];
          .address == "aws_network_interface.internet_router_outside"
          and (.change.actions == ["update"]))
    ' >/dev/null; then
    echo "Safe plan: only the existing Debian outside ENI will be updated in place."
else
    echo "Unsafe plan: changes are not limited to the Debian outside ENI." >&2
    exit 1
fi

terraform show "$plan_file"
