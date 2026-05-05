# arm-c2c — Cloud2Code Demo (ARM)

ARM templates that deploy intentionally misconfigured Azure resources to demonstrate Wiz **Cloud2Code** mapping: each cloud-side CCR finding links back to the IaC source-of-truth in this repo.

## Layout

```
.
├── modules/
│   ├── storage.json       # Storage Account + public container
│   ├── nsg.json           # NSG with SSH/RDP/all open to 0.0.0.0/0
│   ├── keyvault.json      # Key Vault, public, no soft delete, no purge protection
│   └── sql.json           # SQL Server + DB + open firewall, no auditing/AAD admin
├── deploy.sh              # az group create + 4 separate az deployment group create calls
└── destroy.sh             # tear down
```

Each module is a self-contained ARM template — `deploy.sh` runs them as four
independent deployments. Wiz IaC scans each file independently, so each cloud
finding maps cleanly back to the originating `modules/*.json` file.

## Deploy

```bash
./deploy.sh
# uses sub: CSPM Team (95dd4846-…), RG: arm-c2c-rg, location: eastus
# generates a one-time SQL admin password locally (never persisted)
```

## Tear down

```bash
./destroy.sh
```

## Expected Wiz CCR rules that should fire (Cloud + IaC)

| Resource | Rule ID | What's wrong |
|---|---|---|
| Storage Account | StorageAccount-003 | `supportsHttpsTrafficOnly: false` |
| Storage Account | StorageAccount-006 | `networkAcls.defaultAction: "Allow"` |
| Storage Account | StorageAccount-012 | `minimumTlsVersion: "TLS1_0"` |
| Storage Account | StorageAccount-033 | `allowBlobPublicAccess: true` |
| Storage Container | StorageAccount-005 / -013 | `publicAccess: "Container"` |
| NSG | NSG-001 | RDP (3389) open to `0.0.0.0/0` |
| NSG | NSG-002 | SSH (22) open to `0.0.0.0/0` |
| Key Vault | KeyVault-002 | Purge protection not enabled |
| Key Vault | KeyVault-004 | Soft delete disabled |
| Key Vault | KeyVault-034 | No firewall rules / network ACLs |
| SQL Server | CloudSQL-010 | No `auditingSettings` |
| SQL Server | CloudSQL-013 / -027 | No `securityAlertPolicies` on DB |
| SQL Server | CloudSQL-065 | No AAD-only admin |
| SQL Server | _(open firewall)_ | Server firewall rule `0.0.0.0`–`255.255.255.255` |

### Tenant-policy carve-outs

The Wiz-Playground management group enforces **deny** policies that block the
"public network access enabled" misconfig at deploy time, so the following
are intentionally NOT in the deployed templates (would have failed deploy):

- Storage Account: `publicNetworkAccess: "Enabled"` → forced `Disabled`
- Key Vault: `publicNetworkAccess: "Enabled"` → omitted
- SQL Server: `publicNetworkAccess: "Enabled"` → omitted
- SQL Server: `minimalTlsVersion: "1.0"` → omitted (region requires ≥ 1.2)

The IaC-only finding for these still surfaces from any branch where you
add them back; they just can't be flown into prod.

## Cloud2Code mapping

After Wiz scans this repo (VCS connector) **and** the deployed Azure subscription, open any CCR finding in the Wiz UI → "View IaC source" links to the matching `modules/*.json` line in `github.com/AsafIfergan/arm-c2c`.

## Tags

All resources tagged:

```
demo=cloud2code
owner=asaf.ifergan
iac_source=github.com/AsafIfergan/arm-c2c
```

Use `demo=cloud2code` filter in Wiz UI to isolate the demo blast radius.

## ⚠️ Notes

- Resources are deliberately internet-exposed — tear down within 24h.
- SQL Server costs ~$5/day. Run `./destroy.sh` when done.
- Misconfigs cross-referenced with positive test fixtures from `builtins-updater-catalog/cspm/builtinRules/`.
