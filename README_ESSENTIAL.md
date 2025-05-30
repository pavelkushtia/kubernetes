# Essential Kubernetes Cluster Setup Scripts

This directory contains only the essential scripts needed to set up and manage the Kubernetes cluster.

## 📁 Essential Files

### Core Cluster Setup
- **`improved_k8s_cluster.yaml`** - Main Ansible playbook for complete cluster setup
- **`inventory.ini`** - Ansible inventory with all cluster nodes
- **`fixed_worker_setup.yaml`** - Ansible playbook specifically for worker node setup

### Worker Node Management Scripts
- **`rejoin-all-workers.sh`** - ⭐ **NEW** - Rejoin all worker nodes after reboot/disconnect
- **`setup_workers_with_password.sh`** - Setup worker nodes with password authentication
- **`complete_worker_setup.sh`** - Complete worker node setup script

### Utility Scripts
- **`README_ESSENTIAL.md`** - This documentation file

## 🚀 Quick Start

### 1. Full Cluster Setup (Fresh Installation)
```bash
ansible-playbook -i inventory.ini improved_k8s_cluster.yaml
```

### 2. Rejoin Worker Nodes (After Reboot)
```bash
./rejoin-all-workers.sh
```

### 3. Setup New Worker Nodes Only
```bash
ansible-playbook -i inventory.ini fixed_worker_setup.yaml
```

### 4. Check Cluster Status
```bash
kubectl get nodes -o wide
kubectl get pods -n kube-system
```

## 📋 Cluster Inventory

**Master Node:**
- `master-node` (192.168.1.82) - localhost

**Worker Nodes:**
- `worker-node1` (192.168.1.95)
- `worker-node2` (192.168.1.94)
- `sanzad-ubuntu-21` (192.168.1.93)
- `sanzad-ubuntu-22` (192.168.1.104)
- `sanzad-ubuntu-23` (192.168.1.105)

## 🔧 Current Cluster Configuration

- **Kubernetes Version:** 1.28.0
- **Container Runtime:** containerd 1.7.27
- **CNI:** Flannel (configured for 192.168.0.0/16)
- **Pod CIDR:** 192.168.0.0/16
- **Service CIDR:** 10.96.0.0/12

## 📦 Backup Files

All non-essential files (HA setup, upgrade scripts, documentation) have been moved to:
- `backup_files/` directory

## ✅ Post-Setup Verification

After running any setup script, verify the cluster:

```bash
kubectl get nodes -o wide
kubectl get pods -n kube-system
```

All nodes should show status "Ready" and all system pods should be "Running".

## 🎯 Next Steps

Once all worker nodes are joined and ready:
1. Navigate to TweetStream deployment: `cd ../tweetstream-app/helm-chart`
2. Run fresh deployment: `./deploy-fresh.sh`

## 🔧 Troubleshooting

If worker nodes are not joining:
1. Check node connectivity: `ping <worker-ip>`
2. Verify CNI is working: `kubectl get pods -n kube-flannel`
3. Check for certificate issues: `kubectl get csr`
4. Re-run rejoin script: `./rejoin-all-workers.sh` 