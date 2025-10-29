# Check if the azure container registry exists
az acr show -n $ACR --only-show-errors 1>$null 2>$null

## If it doesn't then the last exit code will be non-zero
if ($LASTEXITCODE -ne 0) {
    # Create the Azure Container Registry
    az acr create -n $ACR -g $RG -l $LOC --sku Basic --admin-enabled true --only-show-errors
}

# Get login server name, use this later for pushing images
$ACR_LOGIN_SERVER = az acr show -n $ACR --query "loginServer" --output "tsv"
Write-Host "ACR_LOGIN_SERVER=$ACR_LOGIN_SERVER"

# Log in locally so Docker can push
az acr login -n $ACR --only-show-errors
