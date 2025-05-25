# 🚀 Kubernetes Cluster Upgrade Guide

## 📋 **Overview**

This guide explains how to safely upgrade your Kubernetes cluster to newer versions using the dedicated `k8s_upgrade.yaml` playbook.

### ⚠️ **Important Notes**
- **Current playbooks (`improved_k8s_cluster.yaml`, `production_addons.yaml`) are NOT for upgrades**
- **Use `k8s_upgrade.yaml` specifically for version upgrades**
- **Always upgrade incrementally** (e.g., 1.28 → 1.29 → 1.30)
- **Test in development environment first**

## 🔍 **Pre-Upgrade Checklist**

### 1. **Check Current Version**
```bash
kubectl version --short
kubectl get nodes -o wide
```

### 2. **Verify Cluster Health**
```bash
kubectl get nodes
kubectl get pods --all-namespaces
kubectl get componentstatuses
```

### 3. **Check Upgrade Path**
```bash
# Kubernetes supports only adjacent minor version upgrades
# ✅ Valid: 1.28.x → 1.29.x
# ❌ Invalid: 1.28.x → 1.30.x (skip 1.29)
```

### 4. **Review Breaking Changes**
- Check [Kubernetes Release Notes](https://kubernetes.io/releases/)
- Review deprecated APIs
- Test applications in staging environment

### 5. **Backup Critical Data**
```bash
# The upgrade playbook will backup etcd automatically
# But also backup your application data
kubectl get pv,pvc --all-namespaces
```

## 🛠️ **Upgrade Process**

### **Step 1: Configure Upgrade Variables**

Edit `k8s_upgrade.yaml` variables section:

```yaml
vars:
  # UPGRADE CONFIGURATION - MODIFY THESE VALUES
  current_k8s_version: "1.28.0"      # Your current version
  target_k8s_version: "1.29.0"       # Target version
  target_k8s_minor: "1.29"           # Target minor version
  containerd_version: "1.7.*"        # Containerd version
  calico_version: "v3.28.0"          # Updated Calico version
  
  # SAFETY SETTINGS
  backup_enabled: true                # Create etcd backup
  drain_timeout: "300s"              # Node drain timeout
  upgrade_timeout: "600s"            # Upgrade timeout
```

### **Step 2: Run Upgrade Playbook**

```bash
# Standard upgrade with prompts
ansible-playbook -i inventory.ini k8s_upgrade.yaml --ask-become-pass

# Automated upgrade (no prompts)
ansible-playbook -i inventory.ini k8s_upgrade.yaml --ask-become-pass -e auto_confirm=true

# Upgrade without etcd backup (not recommended)
ansible-playbook -i inventory.ini k8s_upgrade.yaml --ask-become-pass -e backup_enabled=false
```

### **Step 3: Monitor Upgrade Progress**

The playbook will:
1. ✅ **Validate** upgrade path and cluster health
2. 💾 **Backup** etcd database
3. 🔄 **Upgrade** control plane nodes (one by one)
4. 🔄 **Upgrade** worker nodes (rolling upgrade)
5. 🌐 **Upgrade** CNI and system components
6. ✅ **Verify** upgrade completion

## 📊 **Upgrade Sequence Details**

### **Phase 1: Control Plane Upgrade**
```
Master-1: kubeadm upgrade apply → kubelet upgrade → restart
Master-2: kubeadm upgrade node → kubelet upgrade → restart
Master-3: kubeadm upgrade node → kubelet upgrade → restart
```

### **Phase 2: Worker Node Upgrade**
```
For each worker:
1. Drain node (move pods to other nodes)
2. Upgrade kubeadm
3. Run kubeadm upgrade node
4. Upgrade kubelet
5. Restart kubelet
6. Uncordon node (allow pods back)
7. Wait for node ready
8. Proceed to next worker
```

### **Phase 3: System Components**
```
1. Upgrade Calico CNI
2. Upgrade CoreDNS
3. Verify all pods running
```

## 🔧 **Version-Specific Upgrade Paths**

### **From 1.28.x to 1.29.x**
```yaml
current_k8s_version: "1.28.0"
target_k8s_version: "1.29.0"
target_k8s_minor: "1.29"
calico_version: "v3.28.0"
```

### **From 1.29.x to 1.30.x**
```yaml
current_k8s_version: "1.29.0"
target_k8s_version: "1.30.0"
target_k8s_minor: "1.30"
calico_version: "v3.28.0"
```

### **From 1.30.x to 1.31.x**
```yaml
current_k8s_version: "1.30.0"
target_k8s_version: "1.31.0"
target_k8s_minor: "1.31"
calico_version: "v3.29.0"
```

## 🚨 **Troubleshooting**

### **Common Issues**

#### **1. Node Drain Timeout**
```bash
# If node drain takes too long
kubectl drain <node> --ignore-daemonsets --delete-emptydir-data --force --timeout=600s

# Or increase timeout in playbook
drain_timeout: "600s"
```

#### **2. Upgrade Timeout**
```bash
# Increase upgrade timeout
upgrade_timeout: "900s"
```

#### **3. CNI Issues After Upgrade**
```bash
# Check CNI pods
kubectl get pods -n kube-system | grep calico

# Restart CNI if needed
kubectl delete pods -n kube-system -l k8s-app=calico-node
```

#### **4. API Server Issues**
```bash
# Check API server logs
sudo journalctl -u kubelet -f

# Check cluster info
kubectl cluster-info
```

### **Rollback Procedure**

If upgrade fails, you can rollback:

#### **1. Restore etcd Backup**
```bash
# Stop API server
sudo systemctl stop kubelet

# Restore etcd
sudo ETCDCTL_API=3 etcdctl snapshot restore /var/lib/etcd/backup-YYYYMMDD-HHMMSS.db \
  --data-dir=/var/lib/etcd-restore

# Replace etcd data
sudo rm -rf /var/lib/etcd
sudo mv /var/lib/etcd-restore /var/lib/etcd

# Start services
sudo systemctl start kubelet
```

#### **2. Downgrade Packages**
```bash
# Remove holds
sudo apt-mark unhold kubelet kubeadm kubectl

# Downgrade to previous version
sudo apt install kubelet=1.28.0-* kubeadm=1.28.0-* kubectl=1.28.0-*

# Hold packages
sudo apt-mark hold kubelet kubeadm kubectl
```

## 📈 **Post-Upgrade Tasks**

### **1. Verify Cluster Health**
```bash
kubectl get nodes -o wide
kubectl get pods --all-namespaces
kubectl get componentstatuses
```

### **2. Test Applications**
```bash
# Test critical applications
kubectl get deployments --all-namespaces
kubectl get services --all-namespaces

# Check ingress
curl -k https://grafana.192.168.1.82.nip.io:30080
```

### **3. Update Monitoring**
```bash
# Check monitoring stack
kubectl get pods -n monitoring
kubectl get svc -n monitoring
```

### **4. Review Deprecated APIs**
```bash
# Check for deprecated API usage
kubectl api-resources --api-group=extensions
```

## 🔄 **Upgrade Schedule Recommendations**

### **Production Clusters**
- **Frequency**: Every 2-3 minor versions
- **Timing**: During maintenance windows
- **Testing**: Always test in staging first

### **Development Clusters**
- **Frequency**: Stay current with latest stable
- **Timing**: Regular updates
- **Testing**: Can be more aggressive

### **Version Support**
- Kubernetes supports **3 minor versions**
- Example: If latest is 1.31, supported versions are 1.29, 1.30, 1.31
- Plan upgrades before support ends

## 📝 **Upgrade Log Locations**

```bash
# Upgrade logs
/var/log/k8s-upgrade/

# Upgrade summary
/tmp/upgrade-summary.txt

# etcd backups
/var/lib/etcd/backup-*.db

# System logs
sudo journalctl -u kubelet
sudo journalctl -u containerd
```

## 🎯 **Best Practices**

1. **Always backup before upgrading**
2. **Test in development environment first**
3. **Upgrade during maintenance windows**
4. **Monitor cluster health during upgrade**
5. **Have rollback plan ready**
6. **Update one minor version at a time**
7. **Review release notes for breaking changes**
8. **Update applications for deprecated APIs**

## 🔗 **Useful Resources**

- [Kubernetes Release Notes](https://kubernetes.io/releases/)
- [kubeadm Upgrade Guide](https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/kubeadm-upgrade/)
- [API Deprecation Guide](https://kubernetes.io/docs/reference/using-api/deprecation-guide/)
- [Version Skew Policy](https://kubernetes.io/releases/version-skew-policy/)

---

**Remember**: Upgrades are critical operations. Always test thoroughly and have a rollback plan ready! 