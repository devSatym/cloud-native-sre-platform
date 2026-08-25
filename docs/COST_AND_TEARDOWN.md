# Cost Control and Teardown

**Status:** Cost-conscious infrastructure is configured in Terraform; provisioning,
actual spend, and teardown have **not** been validated by evidence in this repository.
This document is an operating procedure, not a bill estimate.

## Cost posture

The development foundation in `terraform/environments/dev` is intentionally small:

- one zonal Standard GKE cluster with an autoscaled node pool configured for two to
  three nodes;
- one custom VPC and regional subnet rather than a multi-region topology;
- one regional Docker Artifact Registry repository shared by the API and Payments
  images;
- no always-on load generator, managed database, or JSON service-account key;
- keyless GitHub OIDC/Workload Identity rather than long-lived CI credentials.

These are configuration/design choices. They do not prove that resources currently
exist or that the configuration is the lowest-cost option for a particular region,
account, quota, or billing agreement. Google Cloud pricing changes and depends on
usage, so this repository makes no exact cost claim. Before creating resources, set a
project budget and billing alerts using your approved billing process.

## Before creating a development environment

1. Use a dedicated billing-enabled project or a clearly isolated development scope.
2. Copy `terraform.tfvars.example` to the ignored `terraform.tfvars`; never commit
   credentials, service-account keys, or state.
3. Review a normal `terraform plan` and identify the project, region, zone, cluster,
   network, repository, and identities it will create.
4. Limit test duration. Stop k6/load generators and remove temporary fault-injection
   settings as soon as validation is complete.
5. Capture required validation evidence before teardown; an image repository or cluster
   deleted by Terraform may make later reproduction impossible without a rebuild.

For bootstrap and configuration details, use
[`terraform/README.md`](../terraform/README.md). The Terraform root for this
procedure is `terraform/environments/dev`.

## Safe teardown procedure

Teardown destroys real cloud resources. Run it only from the intended Terraform
configuration and after checking the selected project and state backend.

### 1. Preserve necessary evidence and stop activity

- Stop load tests, port-forwards, and any scheduled/continuous validation jobs.
- Clean up an intentional Payments fault and confirm the workload is healthy before
  removing the environment.
- Save redacted cluster, test, and incident evidence in
  [`evidence/`](evidence/) if it is needed for the portfolio record.
- Record image digests, Git revision, cluster name, and Terraform workspace/state
  location. Do not commit a binary Terraform plan or Terraform state as evidence.

### 2. Verify the exact target

```bash
export TF_DIR="terraform/environments/dev"

terraform -chdir="$TF_DIR" init
terraform -chdir="$TF_DIR" workspace show
terraform -chdir="$TF_DIR" output
```

If the environment has been applied, obtain the configured project, region, and
cluster identifiers from Terraform outputs and compare them with the active gcloud
context:

```bash
export PROJECT_ID="$(terraform -chdir="$TF_DIR" output -raw project_id)"
export REGION="$(terraform -chdir="$TF_DIR" output -raw region)"
export CLUSTER_NAME="$(terraform -chdir="$TF_DIR" output -raw cluster_name)"

gcloud config get-value project
gcloud container clusters describe "$CLUSTER_NAME"   --project "$PROJECT_ID"   --location "$(terraform -chdir="$TF_DIR" output -raw cluster_location)"
```

Stop if an output is missing, the project differs from the intended target, the
backend/workspace is unfamiliar, or the listed resources are not the ones you
expect. Do not substitute a guessed project ID.

### 3. Review a destroy plan

```bash
terraform -chdir="$TF_DIR" plan -destroy -out=destroy.tfplan
terraform -chdir="$TF_DIR" show -no-color destroy.tfplan
```

Review the complete plan, especially GKE, the node pool, VPC/subnet/firewall,
Artifact Registry, Workload Identity Federation, service accounts, IAM bindings, and
project-service resources. `destroy.tfplan` can contain sensitive metadata and must
not be committed. Delete it locally after the operation or keep it in an approved
secure location.

If `deletion_protection` was deliberately set to `true`, Terraform should block
cluster deletion. Change that setting only through a reviewed configuration update
and apply the change before attempting teardown.

### 4. Destroy the Terraform-managed environment

```bash
terraform -chdir="$TF_DIR" destroy
```

Use the interactive confirmation to verify the target one final time. Do not manually
delete a Terraform-managed resource first merely to make the command shorter; that
creates drift and can leave dependent resources behind.

### 5. Verify what remains

After Terraform reports completion, inspect the state and cloud inventory. Empty
results are an outcome to record, not an assumption.

```bash
terraform -chdir="$TF_DIR" state list

gcloud container clusters list --project "$PROJECT_ID"
gcloud artifacts repositories list --project "$PROJECT_ID" --location "$REGION"
gcloud compute networks list --project "$PROJECT_ID"
gcloud compute addresses list --project "$PROJECT_ID" --regions "$REGION"
gcloud compute forwarding-rules list --project "$PROJECT_ID" --regions "$REGION"
```

Use resource labels, IDs, and the reviewed destroy plan to distinguish this project’s
resources from unrelated resources. Never bulk-delete a whole project, all networks,
or all Artifact Registry repositories.

**TO BE CAPTURED DURING VALIDATION:** the reviewed destroy plan, Terraform destroy
result, post-destroy state/inventory checks, project/region/workspace context, and
any cleanup decisions. Store redacted text evidence in
[`evidence/terraform/`](evidence/terraform/).

## Intentional leftovers and manual decisions

Terraform is deliberately configured with `disable_on_destroy = false` for the
required Google APIs, including Compute, GKE, Artifact Registry, IAM, IAM
Credentials, STS, Resource Manager, Service Usage, Logging, and Monitoring. Leaving
shared project APIs enabled avoids a surprising or disruptive project-wide action.
They may continue to appear in the project after destroy.

The following items may also remain because they are out of scope for a normal
Terraform destroy or require an explicit retention decision:

| Item | Why it can remain | Required decision |
| --- | --- | --- |
| Optional remote-state GCS bucket | It is created out of band and is not hard-coded in this Terraform configuration. | Retain according to state-retention policy, or delete through the approved bootstrap process only after state is no longer needed. |
| Billing account, project, and organization policies | They are preconditions/shared controls, not environment resources. | Keep them; do not destroy them as part of this project teardown. |
| GitHub repository variables, approvals, and workflow history | They live outside the Terraform state. | Remove or rotate obsolete deployment configuration after confirming no workflow still needs it. |
| Manually created DNS records, log sinks, snapshots, buckets, or external integrations | Terraform cannot remove resources it does not manage. | Inventory them explicitly and choose retention/deletion with the owning team. |
| Evidence retained in the repository | It is intentionally separate from cloud infrastructure. | Keep only redacted, non-secret artifacts needed for reproducibility. |

If the destroy plan includes the Artifact Registry repository, decide whether any
images/evidence must be retained first. Do not assume a package will remain available
after its repository is removed.

## Completion criteria

Teardown is complete only when the reviewed Terraform state and cloud inventory show
the intended environment resources are gone, intentional leftovers have an owner and
decision, and evidence has been captured. A successful command alone is insufficient
if the wrong workspace or project was targeted.
