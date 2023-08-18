# AzureAD TF provider bug reproducer for [issue 1172 ](https://github.com/hashicorp/terraform-provider-azuread/issues/1172) 

## Overview

This repo aims at providing a simple reproducer for [issue 1172 ](https://github.com/hashicorp/terraform-provider-azuread/issues/1172).


**Bug summary**: `azuread_group_member` resource  ([AzureAD provider](https://registry.terraform.io/providers/hashicorp/azuread/latest/docs/resources/group_member)) fails to refresh when its `group_object_id` attribute in the tfstate references an AD group that does not exist anymore.

The code of this repo provides two basic modules to reproduce the error:
- `group`: creates an AAD security group
- `group_member`: creates a new member to an existing group

## Prerequisites

- Terraform >= 1.2 (tested on 1.2.9 and 1.5.5)
- Run TF with an account or an SPN that have enough permissions to manage `azuread_group` and `azuread_group_member` resources. Find the required permissions in the [provider doc](https://registry.terraform.io/providers/hashicorp/azuread/latest/docs/resources/group)
- the `group_name` input variables of the two module must match. Check `group/variables.tf` and `group_member/variables.tf` for defaults.

## Reproducing the bug

- Run TF init and apply from the `group` module to create a new AD group
```bash
cd group/
terraform init
terraform apply
```

- Run TF init and apply from the `group_member` module to create a new group member. The identity running Terraform will be added as group member of the previously created group
```bash
cd ../group_member/
terraform init
terraform apply
```

- Go back to the `group` module to destroy and recreate the AAD group. This will give a new ID to AD group.

```bash
cd ../group/
terraform destroy
terraform apply
```

- Rerun the apply command on the `group_member` module
```bash
cd ../group_member/
terraform apply
```

This second apply should fail during the TF state refresh phase with the following error message:

```
> Error: Retrieving members for group with object ID: "xxxxxxxxxxxxxxxxxxxxx"
│
│   with azuread_group_member.group_member,
│   on main.tf line 9, in resource "azuread_group_member" "group_member":
│    9: resource "azuread_group_member" "group_member" {
│ 
│ GroupsClient.BaseClient.Get(): unexpected status 404 with OData error: Request_ResourceNotFound: Resource
│ 'xxxxxxxxxxxxxxxxxxxxx' does not exist or one of its queried reference-property objects are not
│ present.
```

## Recovering from the failed state

### Skipping the refresh phase
Skipping the refresh phase allows Terraform to recreate a new `azuread_group_member` and recover from this failed state.

```bash
cd group_member/
terraform apply -refresh=false
```
This command provides the following output:
```
Apply complete! Resources: 1 added, 0 changed, 1 destroyed.
```

### Manually editing the state file

Manually editing the TF state to replace the old group ID by the new one also enables Terraform to recover from the failed state.

## Cleaning-up

```bash
cd group_member/
terraform destroy
cd ../group/
terraform destroy
```