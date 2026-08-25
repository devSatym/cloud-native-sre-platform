# Runbook: PodDisruptionBudget Eviction Test

**Status:** Draft — the procedure is documented, but no PDB eviction validation has
been recorded yet.
**Severity:** P2 (planned, controlled resilience exercise).
**Scope:** A non-production workload with at least two ready replicas and a
PodDisruptionBudget (PDB) that permits one voluntary disruption.

## Purpose

This exercise verifies the effect of a PDB through the Kubernetes **eviction API**.
It must not use `kubectl delete pod`: direct deletion bypasses voluntary-disruption
protection and therefore cannot validate a PDB.

The intended invariant is:

```text
two or more ready replicas → one voluntary eviction → PDB is evaluated →
minAvailable remains satisfied → controller replaces/reconciles the workload
```

This is a validation procedure, not evidence that the invariant has already held in
any environment.

## Preconditions and guardrails

- Use only a disposable or explicitly approved non-production cluster.
- Select a workload with `replicas >= 2`, a PDB, and a clear readiness signal.
- Confirm that a second ready replica exists before requesting the eviction.
- Have permission to create `pods/eviction` and to inspect PDBs, pods, events, and
  EndpointSlices.
- Do not combine this test with a rollout, load test, or incident response exercise.
- Stop immediately if the workload is serving production traffic or the actual PDB
  selector does not match the selected pod.

The examples below use a namespace convention only. They do not assert that the
namespace, release, PDB, or workload already exists.

```bash
export NAMESPACE="${NAMESPACE:-sre-platform}"
export RELEASE="${RELEASE:-cloud-native-sre-platform}"
export PDB_NAME="${PDB_NAME:-cloud-native-sre-platform-payments-pdb}"
export APP_SELECTOR="app.kubernetes.io/name=payments,app.kubernetes.io/instance=${RELEASE}"

kubectl config current-context
kubectl get namespace "$NAMESPACE"
kubectl auth can-i create pods/eviction -n "$NAMESPACE"
kubectl -n "$NAMESPACE" get pdb "$PDB_NAME" -o yaml
kubectl -n "$NAMESPACE" get deploy -l "$APP_SELECTOR"
kubectl -n "$NAMESPACE" get pods -l "$APP_SELECTOR" -o wide
kubectl -n "$NAMESPACE" get endpointslice -l kubernetes.io/service-name
```

Read the applied PDB rather than relying on this runbook. Record `minAvailable` or
`maxUnavailable`, `currentHealthy`, `desiredHealthy`, and `disruptionsAllowed`:

```bash
kubectl -n "$NAMESPACE" get pdb "$PDB_NAME" \
  -o jsonpath='{.spec.minAvailable}{"\n"}{.spec.maxUnavailable}{"\n"}{.status.currentHealthy}{"\n"}{.status.desiredHealthy}{"\n"}{.status.disruptionsAllowed}{"\n"}'
```

Proceed only when the PDB selector matches the workload, the replica count is at
least two, all required replicas are Ready, and `disruptionsAllowed` permits the
single voluntary eviction. If it is zero, capture that state as a blocked test; do
not bypass the PDB.

## Capture a baseline

Create a timestamped evidence directory only while executing the real test. The
following commands are a capture recipe, not current evidence:

```bash
export STAMP="$(date -u +%Y-%m-%dT%H%M%SZ)"
export EVIDENCE_DIR="docs/evidence/pdb/$STAMP-payments-eviction"
mkdir -p "$EVIDENCE_DIR"

kubectl -n "$NAMESPACE" get pdb "$PDB_NAME" -o yaml > "$EVIDENCE_DIR/pdb-before.yaml"
kubectl -n "$NAMESPACE" get pods -l "$APP_SELECTOR" -o wide > "$EVIDENCE_DIR/pods-before.txt"
kubectl -n "$NAMESPACE" get events --sort-by=.lastTimestamp > "$EVIDENCE_DIR/events-before.txt"
kubectl -n "$NAMESPACE" get endpointslice -l kubernetes.io/service-name -o yaml > "$EVIDENCE_DIR/endpoints-before.yaml"
```

Choose exactly one Ready pod from the baseline output. Check that it belongs to the
selected workload and is selected by the PDB before setting `POD`:

```bash
export POD='<replace-with-one-ready-payments-pod-name>'
kubectl -n "$NAMESPACE" get pod "$POD" -o yaml
```

## Perform one voluntary eviction

Run `kubectl proxy --port=8001` in **Terminal A** and keep it open only for this
test:

```bash
kubectl proxy --port=8001
```

In **Terminal B**, submit one `policy/v1` eviction request. Capturing the response is
important because it shows whether the API accepted the request or the PDB rejected
it.

```bash
curl -sS \
  -D "$EVIDENCE_DIR/eviction-response-headers.txt" \
  -o "$EVIDENCE_DIR/eviction-response.json" \
  -w '%{http_code}\n' \
  -X POST "http://127.0.0.1:8001/api/v1/namespaces/${NAMESPACE}/pods/${POD}/eviction" \
  -H 'Content-Type: application/json' \
  --data "{\"apiVersion\":\"policy/v1\",\"kind\":\"Eviction\",\"metadata\":{\"name\":\"${POD}\",\"namespace\":\"${NAMESPACE}\"}}"
```

A successful voluntary eviction is commonly an HTTP `201`; a PDB may return `429`
when no disruption is currently allowed. Record the actual status and body. Neither
outcome authorizes a direct pod deletion.

## Observe recovery and verify the invariant

Capture state immediately after the request and continue observing until the
workload controller has reached its intended ready replica count again:

```bash
kubectl -n "$NAMESPACE" get pdb "$PDB_NAME" -o yaml > "$EVIDENCE_DIR/pdb-after-request.yaml"
kubectl -n "$NAMESPACE" get pods -l "$APP_SELECTOR" -o wide > "$EVIDENCE_DIR/pods-after-request.txt"
kubectl -n "$NAMESPACE" get events --sort-by=.lastTimestamp > "$EVIDENCE_DIR/events-after-request.txt"
kubectl -n "$NAMESPACE" get endpointslice -l kubernetes.io/service-name -o yaml > "$EVIDENCE_DIR/endpoints-after-request.yaml"
kubectl -n "$NAMESPACE" get deploy -l "$APP_SELECTOR" -o yaml > "$EVIDENCE_DIR/deploy-after-request.yaml"
```

Compare the before/after snapshots and the event timeline. Success requires evidence
that the PDB was selected for the pod, the healthy count never fell below the applied
availability requirement at the observed points, a replacement or reconciled ready
replica was present, and ready endpoints remained available. A `201` alone is not
enough to prove availability was maintained.

**TO BE CAPTURED DURING VALIDATION:** cluster/context, namespace, release and image
revision; applied PDB; pre/post pod and endpoint state; eviction response; relevant
events; timestamps; and the final readiness observation. Store only real output in
[`../evidence/pdb/`](../evidence/pdb/).

## Optional node-drain variant

Use a drain only after the single-pod eviction has been validated and only on a
dedicated non-production node. It has a much larger blast radius than the eviction
API. Inspect the planned node contents first, avoid `--force` unless its consequence
is understood and explicitly approved, and always uncordon the node when done.

```bash
export NODE='<replace-with-reviewed-non-production-node>'
kubectl get pods -A -o wide --field-selector="spec.nodeName=$NODE"
# After reviewing every affected workload:
# kubectl drain "$NODE" --ignore-daemonsets --delete-emptydir-data
# kubectl uncordon "$NODE"
```

The drain variant is not required to mark the targeted eviction test complete.

## If the test does not meet success criteria

Do not retry repeatedly. Restore normal scheduling if a drain was used, wait for the
workload to become healthy, capture the real failure state, and mark the exercise
**Attempted; not validated**. Investigate the PDB selector, replica/readiness state,
controller events, scheduling capacity, and any concurrent disruption before trying
again.
