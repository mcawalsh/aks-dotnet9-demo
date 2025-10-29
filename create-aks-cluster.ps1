# Create AKS cluster (1 node, linked to ACR + Log Analytics)
az aks show -n $AKS -g $RG --only-show-errors 1>$null 2>$null
if ($LASTEXITCODE -ne 0) {
  az aks create `
    -g $RG -n $AKS `
    -l $LOC `
    --node-count 1 `
    --enable-addons monitoring `
    --workspace-resource-id $LAW_ID `
    --attach-acr $ACR `
    --generate-ssh-keys `
    --enable-managed-identity `
    --only-show-errors
}

# Fetch credentials so kubectl talks to your cluster
az aks get-credentials -g $RG -n $AKS --overwrite-existing --only-show-errors

# Verify connection
kubectl get nodes
