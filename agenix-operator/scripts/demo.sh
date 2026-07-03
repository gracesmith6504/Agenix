#!/usr/bin/env bash
# Demo script for the Agenix AgentIdentity happy path.
#
# Prerequisites: cluster reachable and operator deployed (README quick start steps 1–4).
#
# Usage:
#   ./scripts/demo.sh           # run the demo
#   ./scripts/demo.sh --cleanup # remove sample resources after demo
#   ./scripts/demo.sh --reset   # cleanup then run demo (useful for re-runs)

set -euo pipefail

OPERATOR_NAMESPACE="${OPERATOR_NAMESPACE:-agenix-operator-system}"
WORKLOAD_NAMESPACE="${WORKLOAD_NAMESPACE:-default}"
AGENT_IDENTITY_NAME="${AGENT_IDENTITY_NAME:-weather-agent-identity}"
DEPLOYMENT_NAME="${DEPLOYMENT_NAME:-weather-agent}"
OPERATOR_DEPLOYMENT="${OPERATOR_DEPLOYMENT:-agenix-operator-controller-manager}"
SAMPLES_DIR="${SAMPLES_DIR:-config/samples}"

VERIFIED_TIMEOUT="${VERIFIED_TIMEOUT:-120s}"
ROLLOUT_TIMEOUT="${ROLLOUT_TIMEOUT:-180s}"
OPERATOR_TIMEOUT="${OPERATOR_TIMEOUT:-180s}"

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

step() {
	echo -e "${BLUE}==>${NC} $1"
}

pass() {
	echo -e "${GREEN}✓${NC} $1"
}

fail() {
	echo -e "${RED}✗${NC} $1" >&2
	exit 1
}

require_command() {
	command -v "$1" >/dev/null 2>&1 || fail "Required command not found: $1"
}

cleanup_samples() {
	step "Removing sample workload"
	kubectl delete -k "${SAMPLES_DIR}/" --ignore-not-found
	pass "Sample resources removed (if present)"
}

check_prerequisites() {
	require_command kubectl

	step "Checking cluster connectivity"
	kubectl cluster-info >/dev/null 2>&1 || fail "Cannot reach cluster. Check kubectl context."

	step "Checking operator deployment (${OPERATOR_NAMESPACE}/${OPERATOR_DEPLOYMENT})"
	kubectl get deployment "${OPERATOR_DEPLOYMENT}" -n "${OPERATOR_NAMESPACE}" >/dev/null 2>&1 || \
		fail "Operator not found. Deploy first (README quick start steps 1–4)."

	step "Waiting for operator to be available"
	kubectl wait --for=condition=available "deployment/${OPERATOR_DEPLOYMENT}" \
		-n "${OPERATOR_NAMESPACE}" --timeout="${OPERATOR_TIMEOUT}" || \
		fail "Operator deployment not ready within ${OPERATOR_TIMEOUT}"
	pass "Operator is running"
}

run_demo() {
	echo ""
	echo "Agenix demo — automated agent identity flow"
	echo "============================================"
	echo ""

	check_prerequisites

	step "Applying sample workload (ServiceAccount + Deployment + AgentIdentity)"
	kubectl apply -k "${SAMPLES_DIR}/"

	step "Waiting for AgentIdentity phase Verified (${AGENT_IDENTITY_NAME})"
	kubectl wait --for=jsonpath='{.status.phase}'=Verified \
		"agentidentity/${AGENT_IDENTITY_NAME}" -n "${WORKLOAD_NAMESPACE}" \
		--timeout="${VERIFIED_TIMEOUT}" || \
		fail "AgentIdentity did not reach Verified within ${VERIFIED_TIMEOUT}. Try: kubectl describe agentidentity ${AGENT_IDENTITY_NAME}"
	pass "Identity verified"

	step "Waiting for Deployment rollout (${DEPLOYMENT_NAME})"
	kubectl rollout status "deployment/${DEPLOYMENT_NAME}" -n "${WORKLOAD_NAMESPACE}" \
		--timeout="${ROLLOUT_TIMEOUT}" || \
		fail "Deployment rollout did not complete within ${ROLLOUT_TIMEOUT}"
	pass "Workload rolled out with injected identity"

	step "AgentIdentity status"
	kubectl get "agentidentity/${AGENT_IDENTITY_NAME}" -n "${WORKLOAD_NAMESPACE}"

	echo ""
	step "Certificate files in pod (/var/run/agenix)"
	kubectl exec -n "${WORKLOAD_NAMESPACE}" "deploy/${DEPLOYMENT_NAME}" -- ls -la /var/run/agenix

	echo ""
	step "Agent SPIFFE ID (AGENIX_AGENT_ID)"
	kubectl exec -n "${WORKLOAD_NAMESPACE}" "deploy/${DEPLOYMENT_NAME}" -- printenv AGENIX_AGENT_ID

	echo ""
	step "Deployment verification labels"
	kubectl get "deployment/${DEPLOYMENT_NAME}" -n "${WORKLOAD_NAMESPACE}" \
		--show-labels | grep -E 'agenix.io/(identity-verified|agent-id)' || true

	echo ""
	pass "Demo complete"
}

main() {
	cd "$(dirname "$0")/.."

	case "${1:-}" in
	--cleanup)
		cleanup_samples
		;;
	--reset)
		cleanup_samples
		echo ""
		run_demo
		;;
	-h|--help)
		cat <<EOF
Usage: $(basename "$0") [OPTION]

Run the Agenix identity demo against a cluster with the operator already deployed.

Options:
  (none)       Apply samples, wait for Verified, show cert paths and SPIFFE ID
  --reset      Delete samples, then run the demo (good for re-runs)
  --cleanup    Delete sample resources only
  -h, --help   Show this help

Environment variables:
  OPERATOR_NAMESPACE   default: agenix-operator-system
  WORKLOAD_NAMESPACE   default: default
  AGENT_IDENTITY_NAME  default: weather-agent-identity
  DEPLOYMENT_NAME      default: weather-agent
  VERIFIED_TIMEOUT     default: 120s
  ROLLOUT_TIMEOUT      default: 180s

Prerequisites: kubectl configured; operator deployed (see README quick start steps 1–4).
EOF
		;;
	"")
		run_demo
		;;
	*)
		fail "Unknown option: $1 (try --help)"
		;;
	esac
}

main "$@"
