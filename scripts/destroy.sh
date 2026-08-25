#!/usr/bin/env bash
# Explicitly guarded development-infrastructure teardown.

set -euo pipefail

if [[ "${CONFIRM_DESTROY:-}" != "yes" ]]; then
  echo "Refusing destroy. Re-run with CONFIRM_DESTROY=yes after reviewing the Terraform plan." >&2
  exit 2
fi

TF_DIR="${TF_DIR:-terraform/environments/dev}"
TFVARS_FILE="${TFVARS_FILE:-${TF_DIR}/terraform.tfvars}"

if [[ ! -f "$TFVARS_FILE" ]]; then
  echo "ERROR: ${TFVARS_FILE} is missing." >&2
  exit 2
fi

terraform -chdir="$TF_DIR" init -input=false
terraform -chdir="$TF_DIR" destroy -input=false -var-file="$(basename "$TFVARS_FILE")"
