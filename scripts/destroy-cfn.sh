#!/usr/bin/env bash
set -euo pipefail

# Tear down EKS provisioned via CloudFormation templates in cloudformation/
# Deletes nodegroup stack first, then cluster stack.

# Load variables from an env file if present (default: env/cfn.env)
ENV_FILE=${ENV_FILE:-env/cfn.env}
if [[ -f "${ENV_FILE}" ]]; then
  echo "[info] Loading variables from ${ENV_FILE}"
  set -a
  # shellcheck disable=SC1090
  . "${ENV_FILE}"
  set +a
fi

AWS_REGION=${AWS_REGION:-us-east-1}
AWS_PROFILE=${AWS_PROFILE:-}
CLUSTER_STACK=${CLUSTER_STACK:-eks-cluster-stack}
NODEGROUP_STACK=${NODEGROUP_STACK:-eks-nodegroup-stack}

if ! command -v aws >/dev/null 2>&1; then
  echo "[error] aws CLI is required." >&2
  exit 1
fi

if [[ "${AWS_REGION}" != "us-east-1" && "${AWS_REGION}" != "us-west-2" ]]; then
  echo "[error] Learner Lab restricts regions to us-east-1 or us-west-2. Set AWS_REGION accordingly." >&2
  exit 1
fi

export AWS_REGION
if [[ -n "${AWS_PROFILE}" ]]; then
  export AWS_PROFILE
  echo "[info] Using AWS profile: ${AWS_PROFILE}"
fi

stack_exists() {
  local name=$1
  local status
  status=$(aws cloudformation describe-stacks --stack-name "$name" --query 'Stacks[0].StackStatus' --output text 2>/dev/null || true)
  [[ -n "$status" && "$status" != "None" && "$status" != "STACK_NOT_FOUND" ]]
}

# Delete nodegroup stack first
if stack_exists "${NODEGROUP_STACK}"; then
  echo "[info] Deleting stack: ${NODEGROUP_STACK} (nodegroup)"
  aws cloudformation delete-stack --stack-name "${NODEGROUP_STACK}"
  aws cloudformation wait stack-delete-complete --stack-name "${NODEGROUP_STACK}"
  echo "[done] Deleted ${NODEGROUP_STACK}"
else
  echo "[info] Stack ${NODEGROUP_STACK} not found. Skipping."
fi

# Delete cluster stack
if stack_exists "${CLUSTER_STACK}"; then
  echo "[info] Deleting stack: ${CLUSTER_STACK} (cluster)"
  aws cloudformation delete-stack --stack-name "${CLUSTER_STACK}"
  aws cloudformation wait stack-delete-complete --stack-name "${CLUSTER_STACK}"
  echo "[done] Deleted ${CLUSTER_STACK}"
else
  echo "[info] Stack ${CLUSTER_STACK} not found. Skipping."
fi

echo "[done] CloudFormation teardown complete."
