# Az the application-insights extension (mute success output)
az extension add --name application-insights --upgrade --only-show-errors 1>$null

# Get the ID of the application insights component
$AI_ID = az monitor app-insights component show `
  -g $RG -a $APPINSIGHTS --query "id" --output "tsv" --only-show-errors 2>$null

# If $AI_ID is emppty then it doesn't exist so create it
if (-not $AI_ID) {
# Create Application Insights component linked to the log analytics workspace
  $AI_ID = az monitor app-insights component create `
    -g $RG -a $APPINSIGHTS -l $LOC `
    --workspace $LAW_ID `
    --kind web --application-type web `
    --query "id" --output "tsv" --only-show-errors
}

# Get the connection string for the application insights component
$AI_CONN = az monitor app-insights component show `
  -g $RG -a $APPINSIGHTS --query "connectionString" --output "tsv" --only-show-errors

Write-Host "APPINSIGHTS_CONNECTION_STRING=$AI_CONN"
