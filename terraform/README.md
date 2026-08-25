# Terraform — GCP development foundation

This directory creates the minimum GCP foundation for the Cloud Native SRE
Platform. It is intentionally a small, zonal Standard GKE environment rather
than a production multi-region design.

## What it creates

`environments/dev` composes four modules:

| Module | Resources and purpose |
| --- | --- |
| `network` | Custom VPC, one regional subnet, alias-IP secondary ranges for GKE Pods and Services, and a NodePort health-check firewall rule limited to Google Load Balancer ranges. |
| `gke` | Zonal Standard GKE, Calico NetworkPolicy enforcement, Kubernetes Workload Identity, a dedicated node service account, and a 2–3 node autoscaled pool. |
| `artifact-registry` | One regional Docker repository. Its packages are `api` and `payments`, and images must use immutable Git SHA tags. |
| `github-wif` | GitHub OIDC workload identity pool/provider, a low-privilege deployer identity, and a separate Terraform executor identity. |

No resource creates, stores, or references a JSON service-account key.

The configuration enables only the APIs needed by these resources. They are
left enabled on `terraform destroy`, because disabling shared project APIs is a
surprising and potentially disruptive teardown action.

## Prerequisites and first bootstrap

You need a billing-enabled GCP project and a human or CI bootstrap principal
that can enable the listed APIs, manage project IAM, create service accounts,
and create GKE, networking, Artifact Registry, and Workload Identity resources.
The first apply cannot use the WIF identity it is about to create.

Use Application Default Credentials for that one-time bootstrap; do not create
a service-account key:

```bash
gcloud auth application-default login
cd terraform/environments/dev
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your project and exact owner/repository name.
terraform init
terraform fmt -recursive
terraform validate
terraform plan
terraform apply
```

Remote state is optional for local evaluation. For shared use, first create a
dedicated, versioned GCS bucket through your organization’s approved bootstrap
process. Copy `backend.tf.example` to `backend.tf`, replace its bucket
placeholder, then run `terraform init -reconfigure`. The bucket name is never
hard-coded in this repository.

## GitHub Actions variables

After the bootstrap apply, set repository or environment variables from these
outputs. The values are intentionally aligned with the workflows:

| GitHub variable | Source or value |
| --- | --- |
| `GCP_PROJECT_ID` | `terraform output -raw project_id` |
| `GCP_REGION` | `terraform output -raw region` |
| `GCP_ZONE` | `terraform output -raw zone` |
| `ARTIFACT_REGISTRY_REPOSITORY` | `terraform output -raw artifact_registry_repository` |
| `GCP_WORKLOAD_IDENTITY_PROVIDER` | `terraform output -raw workload_identity_provider` |
| `GCP_DEPLOYER_SERVICE_ACCOUNT` | `terraform output -raw deployer_service_account_email` |
| `GKE_CLUSTER_NAME` | `terraform output -raw cluster_name` |
| `GKE_CLUSTER_LOCATION` | `terraform output -raw cluster_location` |
| `GCP_TERRAFORM_SERVICE_ACCOUNT` | `terraform output -raw terraform_service_account_email` |
| `HELM_RELEASE_NAME` | Choose a release name, for example `cloud-native-sre-platform`. |
| `KUBERNETES_NAMESPACE` | Choose its namespace, for example `sre-platform`. |

Image references are always immutable:

```text
REGION-docker.pkg.dev/PROJECT/REPOSITORY/api:GIT_SHA
REGION-docker.pkg.dev/PROJECT/REPOSITORY/payments:GIT_SHA
```

`latest` is never a deployment tag.

## Keyless GitHub authentication

The provider maps GitHub’s `assertion.repository` claim and enforces this
condition before it issues credentials:

```text
assertion.repository == "<github_repository>"
```

It also grants `roles/iam.workloadIdentityUser` only to that repository’s
principal set. In GitHub Actions, jobs must request `id-token: write` and pass
the full `GCP_WORKLOAD_IDENTITY_PROVIDER` output plus the appropriate service
account email to `google-github-actions/auth`.

The deployer identity is separate from the Terraform executor:

| Identity | Access |
| --- | --- |
| GitHub deployer | Repository-scoped `roles/artifactregistry.writer` plus project `roles/container.developer` for GKE deployment. |
| GKE node service account | Repository-scoped `roles/artifactregistry.reader` plus GKE’s `roles/container.defaultNodeServiceAccount`. |
| GitHub Terraform executor | The scoped administrative roles necessary to manage only this Terraform-owned foundation: network, GKE, Artifact Registry, WIF, service accounts, project IAM bindings, and required APIs. |

The Terraform executor has deliberately higher privileges than the deployer
because it manages IAM and infrastructure. Restrict its workflow to protected,
manually approved Terraform applies. The same exact GitHub repository condition
protects both identities; GitHub environment protection is an additional
recommended control outside this Terraform configuration.

The guarded `terraform-apply.yml` workflow deliberately refuses to run without a
reviewed `terraform/environments/dev/backend.tf`. Copy the example only after an
approved remote-state bucket exists, review the bucket and prefix, and commit the
non-secret backend configuration to the protected deployment branch (or provide it
through an equally reviewed protected-environment mechanism). An ephemeral runner
must never create the authoritative Terraform state locally.

## Operation and teardown

Use a reviewed plan before each apply. The development cluster defaults to
`deletion_protection = false` so it can be removed after validation:

```bash
cd terraform/environments/dev
terraform plan -destroy
terraform destroy
```

Destroy removes Terraform-managed infrastructure but intentionally does not
disable project APIs or delete an out-of-band GCS state bucket. Empty Artifact
Registry packages are removed with the repository; retain anything needed as
evidence before teardown.
