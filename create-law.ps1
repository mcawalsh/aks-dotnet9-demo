$LAW_ID = az monitor log-analytics workspace show `
  -g $RG -n $LAW --query id -o tsv --only-show-errors 2>$null

if (-not $LAW_ID) {
  $LAW_ID = az monitor log-analytics workspace create `
    -g $RG -n $LAW -l $LOC --query id -o tsv --only-show-errors
}

Write-Host "LOG_ANALYTICS_WORKSPACE_ID=$LAW_ID"
