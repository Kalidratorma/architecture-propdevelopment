#!/bin/bash
set -e

NAMESPACE="default"

USERS=("analyst1" "analyst2" "manager1" "security1" "security2" "devops1" "developer1" "developer2" "developer3")

for USER in "${USERS[@]}"; do
  echo "Creating serviceaccount for $USER..."
  kubectl create serviceaccount "$USER" --namespace "$NAMESPACE" || true

  SECRET_NAME=$(kubectl get serviceaccount "$USER" --namespace "$NAMESPACE" -o jsonpath='{.secrets[0].name}')
  TOKEN=$(kubectl get secret "$SECRET_NAME" --namespace "$NAMESPACE" -o jsonpath='{.data.token}' | base64 --decode)
  CA_CERT=$(kubectl get secret "$SECRET_NAME" --namespace "$NAMESPACE" -o jsonpath='{.data.ca\.crt}' | base64 --decode)

  CONTEXT_NAME=$(kubectl config current-context)
  CLUSTER_NAME=$(kubectl config get-contexts "$CONTEXT_NAME" | awk 'NR==2 {print $3}')
  SERVER_URL=$(kubectl config view --raw -o jsonpath="{.clusters[?(@.name==\"$CLUSTER_NAME\")].cluster.server}")

  echo "Generating kubeconfig for $USER..."
  KUBECONFIG_FILE="${USER}-kubeconfig.yaml"

  kubectl config set-cluster "$CLUSTER_NAME" \
    --kubeconfig="$KUBECONFIG_FILE" \
    --server="$SERVER_URL" \
    --certificate-authority=<(echo "$CA_CERT") \
    --embed-certs=true

  kubectl config set-credentials "$USER" \
    --kubeconfig="$KUBECONFIG_FILE" \
    --token="$TOKEN"

  kubectl config set-context "$USER-context" \
    --kubeconfig="$KUBECONFIG_FILE" \
    --cluster="$CLUSTER_NAME" \
    --user="$USER"

  kubectl config use-context "$USER-context" --kubeconfig="$KUBECONFIG_FILE"
done
