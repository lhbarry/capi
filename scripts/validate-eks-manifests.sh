#!/usr/bin/env bash
# Local-only CAPA EKS manifest check. Does not apply to cluster or AWS.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="$(mktemp -d)"
trap 'rm -rf "$BUILD"' EXIT

# Build with resources enabled in a temp dir (does not touch git tree)
cp "$ROOT/aws_eks/clusters/capi-eks-1.yaml" "$BUILD/"
cat > "$BUILD/kustomization.yaml" <<'KUST'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - capi-eks-1.yaml
configMapGenerator:
  - name: capa-eks-cluster-params
    namespace: default
    literals:
      - AWS_REGION=us-east-2
      - PUBLIC_API_CIDR=203.0.113.10/32
    options:
      disableNameSuffixHash: true
replacements:
  - source:
      kind: ConfigMap
      name: capa-eks-cluster-params
      fieldPath: data.AWS_REGION
    targets:
      - select:
          kind: AWSManagedControlPlane
        fieldPaths:
          - spec.region
  - source:
      kind: ConfigMap
      name: capa-eks-cluster-params
      fieldPath: data.PUBLIC_API_CIDR
    targets:
      - select:
          kind: AWSManagedControlPlane
        fieldPaths:
          - spec.endpointAccess.publicCIDRs.0
KUST

OUT="$BUILD/out.yaml"
kubectl kustomize "$BUILD" > "$OUT"
echo "kustomize OK ($(wc -l < "$OUT") lines)"

# Required harden markers
for needle in \
  "apiServer: true" \
  "encryptionConfig:" \
  "associateOIDCProvider: true" \
  "sshKeyName: \"\"" \
  "alias/cluster-api-provider-aws-eks-secrets"
do
  if ! grep -q "$needle" "$OUT"; then
    echo "FAIL: missing harden marker: $needle" >&2
    exit 1
  fi
done
echo "harden markers OK"

if kubectl get crd awsmanagedcontrolplanes.controlplane.cluster.x-k8s.io >/dev/null 2>&1; then
  kubectl apply --dry-run=server -f "$OUT" >/dev/null
  echo "server dry-run OK"
else
  echo "skip server dry-run (CAPA CRDs not available)"
fi

# Safety: repo kustomization must stay empty in pure-dev
if ! grep -qE '^resources: \[\]$' "$ROOT/aws_eks/clusters/kustomization.yaml"; then
  echo "WARN: aws_eks/clusters/kustomization.yaml resources is not []" >&2
  exit 2
fi
echo "repo resources: [] OK"
echo "ALL CHECKS PASSED (local only)"
