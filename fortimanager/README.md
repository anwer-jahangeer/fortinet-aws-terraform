# FortiManager AWS interface template

`aws-interface-template.j2` is a FortiManager 7.6 Jinja CLI template for all
three AWS FortiGates. It configures the exact four-port AWS address plan and
the underlay routes required to preserve FortiManager Cloud connectivity.

## Metadata variables

Create these device-level metadata variables in the FortiManager ADOM:

| Variable | Type | Purpose |
|---|---|---|
| `site_name` | String | Site name used in interface aliases |
| `port1_ip` | IPv4/string | ISP1 and private-management address |
| `port1_gateway` | IPv4/string | AWS subnet gateway for ISP1 |
| `port2_ip` | IPv4/string | Protected LAN address |
| `port3_ip` | IPv4/string | ISP2 address |
| `port3_gateway` | IPv4/string | AWS subnet gateway for ISP2 |
| `port4_ip` | IPv4/string | Private MPLS address |

Assign the values from `device-metadata.csv` to each managed device. Metadata
variable locations vary slightly by FortiManager build; in 7.6 they are
available at the ADOM level and can be assigned from Device Manager.

## Create and assign the template

1. Open the FortiOS 7.6 ADOM containing the three FortiGates.
2. Create the seven device-level metadata variables listed above.
3. Assign each device's values from `device-metadata.csv`.
4. Go to **Device Manager > Provisioning Templates > CLI Template**.
5. Create a template named `AWS-FortiGate-Interfaces`.
6. Select **Jinja Script** as the template type.
7. Paste the contents of `aws-interface-template.j2`.
8. Assign the template to all three AWS FortiGates.
9. Preview the rendered configuration for each device before installation.
10. Install first on Branch1, confirm management and internet access, and then
    install on Hub1 and Hub2.

Do not select a plain CLI template. Metadata variables in this file use Jinja
syntax such as `{{ port1_ip }}` and require the Jinja Script template type.

## Route behavior

The template installs:

- Route `10`: primary default route through port1/ISP1, distance 10.
- Route `20`: backup default route through port3/ISP2, distance 20.
- Route `100`: management route to `10.10.252.0/24` through port1.

The gateway on each WAN interface is the AWS subnet router at `.1`. The AWS
route table then forwards the packet to the corresponding Debian ENI at `.254`.
Do not configure `.254` as the FortiGate gateway; EC2 guests always send to the
AWS subnet router.

The primary/backup defaults provide stable connectivity before SD-WAN
configuration. A later FortiManager SD-WAN template may replace routes 10 and
20 with an SD-WAN-zone default route. Route 100 should remain outside SD-WAN
so jumpbox management continues to use port1.

## Verification

After each install, verify from the FortiGate CLI:

```text
get system interface physical
get router info routing-table all
execute ping-options reset
execute ping-options interface port1
execute ping 8.8.8.8
execute traceroute-options device port1
execute traceroute 8.8.8.8
```

The expected ISP1 first hops are:

| Device | First hop |
|---|---:|
| Hub1 | `10.10.111.254` |
| Hub2 | `10.10.112.254` |
| Branch1 | `10.10.113.254` |

Reset diagnostic interface selection afterward:

```text
execute ping-options reset
execute traceroute-options reset
```

From the Windows jumpbox, confirm HTTPS and SSH access to:

```text
10.10.111.20
10.10.112.20
10.10.113.20
```
