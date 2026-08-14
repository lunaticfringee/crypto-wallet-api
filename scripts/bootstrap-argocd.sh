#!/usr/bin/env bash
set -euo pipefail

echo "==> Installing ArgoCD (one-time, imperative bootstrap step)..."
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update
helm install argocd argo/argo-cd \
  --namespace argocd \
  --create-namespace \
  --wait

echo "==> Waiting for ArgoCD server to be ready..."
kubectl wait --for=condition=available --timeout=300s \
  deployment/argocd-server -n argocd

echo "==> Applying root Application (app-of-apps)..."
kubectl apply -f argocd/root-app.yaml

echo "==> Bootstrap complete."
echo "ArgoCD will now reconcile all platform components (Istio, observability, Argo Rollouts)"
echo "and applications (wallet-service, compliance-service) declaratively from Git."
echo ""
echo "Retrieve the admin password with:"
echo "  kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"