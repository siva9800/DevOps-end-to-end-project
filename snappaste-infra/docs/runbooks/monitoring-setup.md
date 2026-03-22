# Monitoring Stack Setup

Installs: **Loki** (logs) + **Mimir** (metrics) + **Grafana** (UI) + **k8s-monitoring** (collectors)

Run all commands from the **jumpbox** after configuring kubectl.

---

## Prerequisites

- EKS cluster running
- kubectl configured: `aws eks update-kubeconfig --name snappaste-dev-eks --region us-east-1`
- Helm installed on jumpbox
- Terraform outputs available (for S3 bucket names)

---

## Step 1 — Get values from Terraform

Run from your **laptop**:

```bash
cd snappaste-infra/terraform/environments/dev

terraform output loki_bucket_name
terraform output mimir_bucket_name
```

Note these values — you'll need them in Step 3 and 4.

---

## Step 2 — Add Helm repos

> **Note:** Grafana OSS charts moved repos in early 2026:
> - `grafana/loki` and `grafana/grafana` moved to `grafana-community`
> - `grafana/mimir-distributed` and `grafana/k8s-monitoring` stayed on original repo

```bash
# Original grafana repo (mimir, k8s-monitoring)
helm repo add grafana https://grafana.github.io/helm-charts

# Community repo (loki, grafana UI)
helm repo add grafana-community https://grafana-community.github.io/helm-charts

helm repo update
```

## Step 2b — Apply Mimir CRDs (required for mimir-distributed 6.0+)

```bash
kubectl apply -f https://raw.githubusercontent.com/grafana/helm-charts/main/charts/rollout-operator/crds/replica-templates-custom-resource-definition.yaml
kubectl apply -f https://raw.githubusercontent.com/grafana/helm-charts/main/charts/rollout-operator/crds/zone-aware-pod-disruption-budget-custom-resource-definition.yaml
```

---

## Step 3 — Install Loki (log storage → S3)

Replace `LOKI_BUCKET_NAME` with the value from Step 1:

```bash
# Clone repo on jumpbox to get values files
git clone https://github.com/siva9800/DevOps-end-to-end-project.git
cd DevOps-end-to-end-project

# Edit the bucket name in values file
sed -i 's/LOKI_BUCKET_NAME/<your-loki-bucket-name>/g' \
  snappaste-infra/monitoring/loki/values.yaml

# Install
helm upgrade --install loki grafana-community/loki \
  --namespace monitoring \
  --create-namespace \
  --values snappaste-infra/monitoring/loki/values.yaml \
  --wait \
  --timeout 5m

# Verify
kubectl get pods -n monitoring | grep loki
```

---

## Step 4 — Install Mimir (metrics storage → S3)

Replace `MIMIR_BUCKET_NAME` with the value from Step 1:

```bash
sed -i 's/MIMIR_BUCKET_NAME/<your-mimir-bucket-name>/g' \
  snappaste-infra/monitoring/mimir/values.yaml

helm upgrade --install mimir grafana/mimir-distributed \
  --namespace monitoring \
  --values snappaste-infra/monitoring/mimir/values.yaml \
  --wait \
  --timeout 10m

# Verify
kubectl get pods -n monitoring | grep mimir
```

---

## Step 5 — Install Grafana (UI)

```bash
helm upgrade --install grafana grafana-community/grafana \
  --namespace monitoring \
  --values snappaste-infra/monitoring/grafana/values.yaml \
  --wait \
  --timeout 3m

# Verify
kubectl get pods -n monitoring | grep grafana
```

---

## Step 6 — Install k8s-monitoring (collectors)

This installs Grafana Alloy + kube-state-metrics + node-exporter.
Must be installed **after** Loki and Mimir are running.

```bash
helm upgrade --install k8s-monitoring grafana/k8s-monitoring \
  --namespace monitoring \
  --values snappaste-infra/monitoring/k8s-monitoring/values.yaml \
  --wait \
  --timeout 5m

# Verify
kubectl get pods -n monitoring
```

---

## Step 7 — Access Grafana

```bash
# Port-forward Grafana to your jumpbox (then SSM port forward to laptop)
kubectl port-forward svc/grafana 3000:80 -n monitoring
```

From your laptop (new terminal):
```bash
aws ssm start-session \
  --target <jumpbox-instance-id> \
  --document-name AWS-StartPortForwardingSession \
  --parameters '{"portNumber":["3000"],"localPortNumber":["3000"]}' \
  --region us-east-1
```

Then open: **http://localhost:3000**
- Username: `admin`
- Password: `snappaste-grafana-2024`

---

## Verify Everything is Working

```bash
# All monitoring pods should be Running
kubectl get pods -n monitoring

# Check Alloy is shipping logs to Loki
kubectl logs -n monitoring deployment/k8s-monitoring-alloy-logs --tail=20

# Check Alloy is shipping metrics to Mimir
kubectl logs -n monitoring deployment/k8s-monitoring-alloy-metrics --tail=20
```

---

## Pre-loaded Grafana Dashboards

These are automatically imported on install:

| Dashboard | ID | Shows |
|-----------|-----|-------|
| Node Exporter Full | 1860 | Node CPU, memory, disk, network |
| K8s Global | 15757 | Cluster-wide overview |
| K8s Pods | 15760 | Per-pod drill down |
| K8s Logs Pod | 15141 | Logs for a specific pod |
| K8s Logs Cluster | 15142 | All pod logs in one view |

---

## Uninstall

```bash
helm uninstall k8s-monitoring -n monitoring
helm uninstall grafana -n monitoring
helm uninstall mimir -n monitoring
helm uninstall loki -n monitoring
kubectl delete namespace monitoring
```
