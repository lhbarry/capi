#!/usr/bin/env bash
# Local-only CAPA EKS manifest check (Services + Workload). Does not apply to cluster or AWS.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="$(mktemp -d)"
trap 'rm -rf "$BUILD"' EXIT

build_one() {
  local name="$1"
  local src="$2"
  local dir="$BUILD/$name"
  mkdir -p "$dir"
  cp "$src" "$dir/cluster.yaml"
  cat > "$dir/kustomization.yaml" <<'KUST'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - cluster.yaml
configMapGenerator:
  - name: capa-eks-cluster-params
    namespace: default
    literals:
      - AWS_REGION=us-east-2
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
KUST
  local out="$dir/out.yaml"
  kubectl kustomize "$dir" > "$out"
  echo "kustomize OK $name ($(wc -l < "$out") lines)"

  for needle in \
    "apiServer: true" \
    "encryptionConfig:" \
    "associateOIDCProvider: true" \
    "sshKeyName: \"\"" \
    "alias/cluster-api-provider-aws-eks-secrets" \
    "availabilityZoneUsageLimit: 3" \
    "public: false" \
    "encrypted: true"
  do
    if ! grep -q "$needle" "$out"; then
      echo "FAIL $name: missing SEC/harden marker: $needle" >&2
      exit 1
    fi
  done
  echo "SEC harden markers OK $name"

  if kubectl get crd awsmanagedcontrolplanes.controlplane.cluster.x-k8s.io >/dev/null 2>&1; then
    kubectl apply --dry-run=server -f "$out" >/dev/null
    echo "server dry-run OK $name"
  else
    echo "skip server dry-run $name (CAPA CRDs not available)"
  fi
}

build_one services "$ROOT/aws_eks/clusters/services/cluster.yaml"
build_one workload "$ROOT/aws_eks/clusters/workload/cluster.yaml"

for f in \
  "$ROOT/aws_eks/clusters/kustomization.yaml" \
  "$ROOT/aws_eks/clusters/services/kustomization.yaml" \
  "$ROOT/aws_eks/clusters/workload/kustomization.yaml"
do
  if ! grep -qE '^resources: \[\]$' "$f"; then
    echo "WARN: $f resources is not []" >&2
    exit 2
  fi
done
echo "repo resources: [] OK"

test -f "$ROOT/aws_security/detection.yaml"
test -f "$ROOT/aws_iam/karpenter-irsa.yaml"
test -f "$ROOT/aws_eks/security/namespaces-pss.yaml"
echo "SEC packages present"

echo "ALL CHECKS PASSED (local only)"
