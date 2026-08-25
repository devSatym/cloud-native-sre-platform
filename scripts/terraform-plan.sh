#!/usr/bin/env bash
# Run a local, no-refresh Terraform plan after copying the example tfvars file.

set -euo pipefail

TF_DIR="${TF_DIR:-terraform/environments/dev}"
TFVARS_FILE="${TFVARS_FILE:-${TF_DIR}/terraform.tfvars}"

if [[ ! -f "$TFVARS_FILE" ]]; then
  echo "ERROR: ${TFVARS_FILE} is missing. Copy terraform.tfvars.example and set real non-secret inputs." >&2
  exit 2
fi

terraform -chdir="$TF_DIR" init -input=false
terraform -chdir="$TF_DIR" validate
terraform -chdir="$TF_DIR" plan -input=false -refresh=false -var-file="$(basename "$TFVARS_FILE")"
