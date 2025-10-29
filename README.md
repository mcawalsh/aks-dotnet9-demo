# AKS Minimal Demo - .NET 9 API with Helm, HPA (Horizontal Pod Autoscaling), and Application Insights

## Overview
A play with **Kubernetes (AKS)** and how it fits into the **Azure ecosystem** - focusing on how to containerize, deploy, scale, and observe a minimal **.NET 9 API** end-to-end.

## Architecture

```text

               ┌────────────────────────────────┐
               │        Azure Portal            │
               │ (App Insights / Log Analytics) │
               └────────────┬───────────────────┘
                            │ telemetry
                            ▼
               ┌─────────────────────────────┐
               │   Azure Kubernetes Service  │
               │          (AKS)              │
               │                             │
               │  ┌──────────────────────┐   │
   Requests →  │  │  Service (demoapi)   │   │
               │  └──────────┬───────────┘   │
               │             │ selector      │
               │  ┌──────────▼──────────┐    │
               │  │ Deployment / Pods   │    │
               │  │ (.NET 9 API image)  │    │
               │  └──────────┬──────────┘    │
               │             │ scaled by     │
               │  ┌──────────▼───────────┐   │
               │  │ Horizontal Pod Auto  │   │
               │  │     Scaler (HPA)     │   │
               │  └──────────────────────┘   │
               └─────────────────────────────┘
                            ▲
                            │ pulls image
               ┌────────────┴────────────┐
               │ Azure Container Registry│
               │        (ACR)            │
               └─────────────────────────┘
```

## Prerequisites
- Azure CLI (az)
- Docker Desktop running
- kubectl
- Helm
- .NET 9 SDK

## Step-by-Step Setup

Where appropriate a ```.ps1``` script has been provided with complete, idempotent implementations of the required commands. When these are provided then they should be used and the snippet shown should be taken as a talking point.

### 1. Variables

Define key variables to make the following commands reusable and consistent:

```bash
RG=rg-aks-demo
LOC=westeurope
AKS=aks-demo
ACR=acrdemouk
APPINSIGHTS=ai-aks-demo
LAW=law-aks-demo
```

### 2. Resource Group & Telemetry

These commands create a resource group, a Log Analytics workspace, and lastly an Application Insights component.

The files [create-law.ps1](create-law.ps1) and [create-app-insights.ps1](create-app-insights.ps1) contain more complete, idempotent implementations of the following commands.

Create a resource group to contain the components we'll create.

```bash
az group create -n $RG -l $LOC --tags purpose=aks-demo
```

Next, we need to create a Log Analytics workspace.

```bash
az monitor log-analytics workspace create -g $RG -n $LAW -l $LOC
```

Finally, we'll create the Application Insights component.

> `$LAW_ID` refers to the Log Analytics workspace resource ID.
> Retrieve it with:
> ```bash
> $LAW_ID = az monitor log-analytics workspace show `
>   -g $RG -n $LAW --query id -o tsv --only-show-errors 2>$null
> ```

Now, we create the Application Insights component.

```bash
az monitor app-insights component create \
    -g $RG -a $APPINSIGHTS -l $LOC \
    --workspace $LAW_ID \
    --kind web --application-type web \
    --query "id" --output "tsv" --only-show-errors
```

### 3. ACR & AKS

Next, we're need an **Azure Container Registry (ACR)** to store our docker images.

[create-acr-azure-container-registry.ps1](create-acr-azure-container-registry.ps1)

```bash
az acr create -n $ACR -g $RG -sku Basic
```

This command creates an ACR named $ACR inside the resource group $RG, using the **Basic SKU** tier.

Now, create the **Azure Kubernetes Service (AKS)** cluster.

[create-aks-cluster.ps1](create-aks-cluster.ps1)

```bash
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
```

#### Explanation of key parameters:
- ```--node-count 1``` Starts the cluster with a single node (VM).
- ```enable-addons monitoring``` Installs the Azure Monitor / Log Analytics agenet for container metrics and logs.
- ```--workspace-resource-id $LAW_ID``` Links the AKS cluster directly to the previously created Log Analytics workspace, so telemetry flows automatically.
- ```attach-acr $ACR``` Grans the clsuter permission to pull images from the ACR created earlier without requiring credentials.
- ```generate-ssh-keys``` Creates a local SSH key pair (if none exists) used for admin access to the cluster nodes -- primarily for debugging or node-level maintenance.
- ```enable-manage-identity``` Assigns Azure Managed Identity to the AKS cluster, allowing it to authenticate securely to other Azure services without storing secrets.

Next, get the kubeconfig details and merge them in your local config file. This causes your local ```kubectl``` commands to be automatically authenticated to the AKS cluster.

```bash
az aks get-credentials -g $RG -n $AKS --overwrite-existing
```

### 4. Build & Push Docker Image

Build the .Net 9 web api **Docker** image using. A Dockerfile exists at ```/src/DemoApi/dockerfile```.

```bash
$IMAGE_TAG="$ACR_LOGIN_SERVER/demoapi:v1"
docker build -t $IMAGE_TAG ./src/DemoApi

docker push $IMAGE_TAG
```

### 5. Deploy with Helm

From the helm folder, deploy (or upgrade) the API:

```bash
helm upgrade --install demoapi ./helm/demoapi --namespace default
```

This command installs the Helm chart if it doesn't exist, or upgrades it if it does - ensuring idempotent deployments.

Once deployed, check the Pods and Service are running:

```bash
kubectl get pods
kubectl get svc
```

### 6. Verify the API

Forward local port ```8080``` to the ```demoapi`` service running inside AKS:

```bash
kubectl port-forward svc/demoapi 8080:8080
```

Then, in a separate terminal, verify the API is responsing:

```bash
curl http://localhost:8080
```

A successful response (```200 OK```) confirms that:

- The Helm deployment succeeded.
- The Service is routing traffic to the Pod correctly.
- The containerized .NET API is running as expected.

### 7. Horizontal Pod Autoscaling (HPA)

The **Horizonal Pod Autoscaler (HPA)** automatically scales the number of pods in a deployment based on observed CPU or memory usage.

The targets for these are defined in ```helm/demoapi/values.yaml```.

Our chart already includes a HPA definition that targets CPU utilization of 50%.

Check that the HPA has been created:

```bash
kubectl get hpa
```

You should see something similar to:

| NAME     | REFERENCE           | TARGETS     | MINPODS | MAXPODS | REPLICAS | AGE |
|-----------|---------------------|--------------|----------|----------|-----------|------|
| demoapi  | Deployment/demoapi  | cpu: 5%/50% | 1        | 5        | 1         | 2m   |


### 8. Simulate Load to Triffer Scaling

To verify that autoscaling works, we'll generate synthetic load against the API using a lightweight **busybox** pod inside the cluster.

Start a temporary load generator pod:

```bash
kubectl run loader --image=busybox --restart=Never --command -- \
  /bin/sh -c "while true; do wget -q -O- http://demoapi.default.svc.cluster.local:8080 > /dev/null; done"
```

Monitor the scaling activity in real time:

```bash
kubectl get hpa -w
```

After a while, you should see the ```TARGETS``` percentage increase and the ```REPLICAS``` count scale up (e.g. from 1 -> 3).

Once testing is complete, clean up the load generator:

```bash
kubectl delete pod loader
```

### 9. Observaibility in Azure Monitor

Telemetry from your pods and cluster flows automatically to:

- **Log Analytics Workspace** - for container logs, CPU/memory metrics, and KQL queries.
- **Application Insights** - for request traces, dependency calls, and performance insights.

Example KQL queries to run in **Azure Monitor → Logs**:

**View recent requests:**

```kql
requests
| where timestamp > ago(30m)
| summarize count() by resultCode, operation_Name
| order by count_ desc
```

**View average request duration:**

```kql
requests
| summarize avg(duration) by bin(timestamp, 5m)
```


### 10. Teardown / Cleanup

To remove all the resources and avoid incurring any costs in Azure:

```bash
helm uninstall demoapi --namespace default
az group delete -g $RG --yes --no-wait
```

This deletes the Helm deployment and the entire resource group (including AKS, ACR, App Insights, and Log Analytics).

✅ At this point you have:

- Deployed a .NET 9 API to AKS using Helm
- Verified liveness/readiness probes, scaling, and service routing
- Observed telemetry in Azure Monitor & Application Insights
- Cleanly removed all resources to avoid ongoing costs