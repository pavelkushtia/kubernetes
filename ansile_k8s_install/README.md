# 🚀 Production Kubernetes Cluster with Ansible

This repository provides **production-ready Ansible playbooks** for setting up robust Kubernetes clusters using kubeadm, complete with monitoring, ingress, and high availability options.

## 🌟 **Key Features**

- ✅ **Security-focused**: Firewall configuration, version pinning, systemd cgroup driver
- ✅ **Fault-tolerant**: Retry mechanisms, validation checks, health monitoring  
- ✅ **Production-ready**: External etcd, load balancing, monitoring stack
- ✅ **High Availability**: Multi-master setup with zero downtime
- ✅ **Complete Monitoring**: Prometheus + Grafana + AlertManager stack
- ✅ **Ingress Ready**: NGINX controller with automatic DNS via nip.io
- ✅ **Battle-tested**: Includes fixes for all common deployment issues

## 🆘 **TROUBLESHOOTING**

**Encountering issues?** Check our comprehensive troubleshooting guide:
📖 **[TROUBLESHOOTING.md](TROUBLESHOOTING.md)** - Solutions for all common deployment problems

**Common fixes included:**
- ✅ Sudo password issues
- ✅ Host pattern mismatches  
- ✅ Repository signature problems
- ✅ CNI plugin initialization
- ✅ Storage class issues
- ✅ Port conflicts
- ✅ Monitoring stack problems

**Quick fix for most issues:**
```bash
# Always use this flag for sudo operations
ansible-playbook -i inventory.ini improved_k8s_cluster.yaml --ask-become-pass
```

---

# 🎯 **DEPLOYMENT DECISION GUIDE**

## **Which Setup Should I Choose?**

Based on your infrastructure (6 hosts available), here's your decision matrix:

### 🏗️ **Option 1: Basic Single-Master** (Development/Testing)
```bash
ansible-playbook -i inventory.ini improved_k8s_cluster.yaml
ansible-playbook -i inventory.ini production_addons.yaml
```
**✅ Best for:** Development, testing, learning  
**📊 Resources:** 1 master + 2 workers  
**⏱️ Setup time:** ~10 minutes  
**❌ Limitation:** Single point of failure  

### 🏗️ **Option 2: High Availability Multi-Master** ⭐ **RECOMMENDED**
```bash
ansible-playbook -i ha_inventory.ini ha_multi_master.yaml
ansible-playbook -i ha_inventory.ini production_addons.yaml
```
**✅ Best for:** Production, zero downtime requirements  
**📊 Resources:** 3 masters + 3 workers + load balancer  
**⏱️ Setup time:** ~20 minutes  
**🎯 Benefits:** Zero downtime, automatic failover, external etcd  

### ⚠️ **CRITICAL: Choose ONE - Never Run Both!**

**❌ NEVER DO THIS:**
```bash
# DON'T run both cluster playbooks on same infrastructure!
ansible-playbook -i inventory.ini improved_k8s_cluster.yaml
ansible-playbook -i ha_inventory.ini ha_multi_master.yaml  # Will break everything!
```

---

# 📋 **YOUR INFRASTRUCTURE**

Your available hosts from inventory files:

| Host | IP | Role in Basic | Role in HA | User |
|------|----|--------------|-----------| -----|
| master-node | 192.168.1.82 | Master | Master 1 | sanzad |
| worker-node1 | 192.168.1.95 | Worker | Worker | sanzad |
| worker-node2 | 192.168.1.94 | Worker | Worker | sanzad |
| sanzad-ubuntu-21 | 192.168.1.93 | Available | Load Balancer | sanzad |
| sanzad-ubuntu-22 | 192.168.1.104 | Available | Master 2 | sanzad |
| sanzad-ubuntu-23 | 192.168.1.105 | Available | Master 3 | sanzad |

**All hosts use the `sanzad` user account - consistent and simple! 👍**

---

# 🚀 **QUICK START GUIDE**

## **Recommended Path: High Availability Setup**

### 1. **Pre-flight Check**
```bash
# Test connectivity to all HA nodes
ansible -i ha_inventory.ini all -m ping

# Verify resources (masters need 4GB+ RAM)
ansible -i ha_inventory.ini masters -m shell -a "free -h && nproc"
```

### 2. **Deploy HA Cluster** (20 minutes)
```bash
ansible-playbook -i ha_inventory.ini ha_multi_master.yaml
```

### 3. **Add Production Stack** (10 minutes)
```bash
ansible-playbook -i ha_inventory.ini production_addons.yaml
```

### 4. **Verify & Access**
```bash
kubectl get nodes -o wide
curl http://grafana.192.168.1.100.nip.io:30080
```

## **Alternative: Basic Development Setup**

### 1. **Deploy Basic Cluster**
```bash
ansible -i inventory.ini all -m ping
ansible-playbook -i inventory.ini improved_k8s_cluster.yaml
ansible-playbook -i inventory.ini production_addons.yaml
```

---

# 📊 **DETAILED COMPARISON**

| Feature | Basic Setup | HA Setup |
|---------|-------------|----------|
| **Masters** | 1 (master-node) | 3 (master-node, ubuntu-22, ubuntu-23) |
| **Workers** | 2 (worker-node1, worker-node2) | 3 (worker-node1, worker-node2, ubuntu-21 as LB) |
| **Load Balancer** | ❌ None | ✅ HAProxy + Keepalived |
| **etcd** | ❌ Single (on master) | ✅ External cluster (3 nodes) |
| **Downtime Risk** | ❌ High (master failure = outage) | ✅ Zero (automatic failover) |
| **Setup Time** | ~10 minutes | ~20 minutes |
| **Resource Usage** | Lower | Higher |
| **Production Ready** | ❌ Development only | ✅ Production grade |
| **API Access** | https://192.168.1.82:6443 | https://192.168.1.100:6443 |
| **Monitoring Access** | grafana.192.168.1.82.nip.io:30080 | grafana.192.168.1.100.nip.io:30080 |

---

# 🏗️ **ARCHITECTURE DIAGRAMS**

## **Basic Single-Master Setup**
```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   master-node   │    │  worker-node1   │    │  worker-node2   │
│   192.168.1.82  │    │   192.168.1.95  │    │   192.168.1.94  │
│     (sanzad)    │    │     (sanzad)    │    │     (sanzad)    │
│                 │    │                 │    │                 │
│  • API Server   │    │  • kubelet      │    │  • kubelet      │
│  • etcd         │    │  • Apps         │    │  • Apps         │
│  • Monitoring   │    │  • Ingress      │    │  • Storage      │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## **High Availability Setup (Recommended)**
```
                           ┌─────────────────┐
                           │  Load Balancer  │
                           │ sanzad-ubuntu-21│
                           │   192.168.1.93  │
                           │ HAProxy+Keepalive│
                           └─────────┬───────┘
                                     │ VIP: 192.168.1.100
        ┌────────────────────────────┼────────────────────────────┐
        │                            │                            │
┌───────▼──────┐            ┌────────▼──────┐            ┌───────▼──────┐
│  master-node │            │sanzad-ubuntu-22│           │sanzad-ubuntu-23│
│192.168.1.82  │            │ 192.168.1.104 │           │ 192.168.1.105 │
│   (sanzad)   │            │   (sanzad)    │           │   (sanzad)    │
│              │            │               │            │              │
│ • API Server │            │ • API Server  │            │ • API Server │
│ • etcd       │            │ • etcd        │            │ • etcd       │
│ • Monitoring │            │ • Controller  │            │ • Scheduler  │
└──────────────┘            └───────────────┘            └──────────────┘

        ┌─────────────────┐                      ┌─────────────────┐
        │  worker-node1   │                      │  worker-node2   │
        │   192.168.1.95  │                      │   192.168.1.94  │
        │     (sanzad)    │                      │     (sanzad)    │
        │                 │                      │                 │
        │  • Applications │                      │  • Applications │
        │  • Ingress      │                      │  • Storage      │
        └─────────────────┘                      └─────────────────┘
```

---

# 📦 **WHAT'S INCLUDED**

## **Core Cluster Components**
- ✅ **Kubernetes 1.28+** with kubeadm
- ✅ **Calico CNI** networking with network policies
- ✅ **Containerd** runtime with systemd cgroup driver
- ✅ **Security hardening** with UFW firewall rules

## **Production Add-ons**
- ✅ **Helm v3.13.0** package manager
- ✅ **NGINX Ingress** controller (NodePort 30080/30443)
- ✅ **Prometheus** monitoring with 15-day retention
- ✅ **Grafana** dashboards with persistent storage
- ✅ **AlertManager** for notifications
- ✅ **Metrics Server** for resource monitoring
- ✅ **Local Path Provisioner** for persistent storage

## **High Availability Components**
- ✅ **Multi-master** control plane (3 nodes)
- ✅ **External etcd** cluster with TLS
- ✅ **HAProxy + Keepalived** load balancing
- ✅ **Virtual IP** failover (192.168.1.100)

---

# 🔗 **ACCESS INFORMATION**

## **After Basic Setup:**
- **Cluster API**: `https://192.168.1.82:6443`
- **Grafana**: `http://grafana.192.168.1.82.nip.io:30080` (admin/admin123)
- **Prometheus**: `http://prometheus.192.168.1.82.nip.io:30080`
- **AlertManager**: `http://alertmanager.192.168.1.82.nip.io:30080`

## **After HA Setup (Recommended):**
- **Cluster API**: `https://192.168.1.100:6443` (via load balancer VIP)
- **Grafana**: `http://grafana.192.168.1.100.nip.io:30080` (admin/admin123)
- **Prometheus**: `http://prometheus.192.168.1.100.nip.io:30080`
- **AlertManager**: `http://alertmanager.192.168.1.100.nip.io:30080`

---

# 🛠️ **USEFUL COMMANDS**

## **Testing Connectivity**
```bash
# Test basic setup connectivity
ansible -i inventory.ini all -m ping

# Test HA setup connectivity
ansible -i ha_inventory.ini all -m ping
```

## **Deployment Commands**
```bash
# Basic cluster deployment
ansible-playbook -i inventory.ini improved_k8s_cluster.yaml

# HA cluster deployment (RECOMMENDED)
ansible-playbook -i ha_inventory.ini ha_multi_master.yaml

# Add monitoring to any setup
ansible-playbook -i [inventory-file] production_addons.yaml

# One-command HA deployment
ansible -i ha_inventory.ini all -m ping && \
ansible-playbook -i ha_inventory.ini ha_multi_master.yaml && \
ansible-playbook -i ha_inventory.ini production_addons.yaml
```

## **Cluster Management**
```bash
# Check cluster status
kubectl get nodes -o wide
kubectl get pods --all-namespaces

# Copy kubeconfig from master
scp sanzad@192.168.1.82:/etc/kubernetes/admin.conf ~/.kube/config

# Deploy test application
kubectl create deployment nginx --image=nginx
kubectl expose deployment nginx --port=80 --type=NodePort
```

---

# 📋 **PREREQUISITES**

## **System Requirements**
- **Operating System**: Ubuntu 20.04 LTS or 22.04 LTS
- **Memory**: 4GB+ RAM per control plane node, 2GB+ per worker
- **CPU**: 2+ CPU cores per node
- **Disk**: 20GB+ free space
- **Network**: All nodes must communicate with each other

## **Before Running**
1. **SSH Access**: Configure passwordless SSH access to all nodes
2. **Sudo Access**: Ensure `sanzad` user has passwordless sudo privileges
3. **Ansible**: Install Ansible on your control machine
4. **Network**: Ensure all nodes have internet access
5. **Virtual IP**: Ensure `192.168.1.100` is available (for HA setup)

---

# 🔧 **CONFIGURATION**

## **Key Variables (Customizable)**
```yaml
vars:
  k8s_version: "1.28.0"                    # Kubernetes version
  containerd_version: "1.7.6"             # Containerd version  
  calico_version: "v3.27.0"               # Calico CNI version
  cluster_name: "k8s-cluster"             # Cluster name
  pod_network_cidr: "192.168.0.0/16"      # Pod network CIDR
  load_balancer_ip: "192.168.1.100"       # Virtual IP (HA only)
  grafana_admin_password: "admin123"      # Grafana password
```

## **Directory Structure**
```
ansile_k8s_install/
├── improved_k8s_cluster.yaml   # Main single-master cluster setup
├── ha_multi_master.yaml        # High availability multi-master setup  
├── production_addons.yaml      # Monitoring stack (Prometheus/Grafana)
├── inventory.ini               # Basic cluster inventory
├── ha_inventory.ini           # High availability cluster inventory
└── README.md                  # This comprehensive documentation
```

---

# 🚨 **TROUBLESHOOTING**

## **Common Issues**

### **SSH Connection Failed**
```bash
# Test SSH connectivity
ssh -o ConnectTimeout=5 sanzad@192.168.1.82

# Check SSH key permissions
chmod 600 ~/.ssh/id_rsa
```

### **Nodes Not Ready**
```bash
# Check node status
kubectl describe node

# Check kubelet logs
sudo journalctl -u kubelet -f

# Check CNI pods
kubectl get pods -n kube-system | grep calico
```

### **API Server Not Accessible**
```bash
# Check firewall
sudo ufw status

# Check cluster info
kubectl cluster-info

# For HA: Check load balancer
curl -k https://192.168.1.100:6443/healthz
```

### **Reset Cluster (if needed)**
```bash
# Clean reset for fresh deployment
ansible -i inventory.ini all -m shell -a "kubeadm reset -f && rm -rf /etc/kubernetes /var/lib/kubelet /var/lib/etcd ~/.kube"

# Then redeploy
ansible-playbook -i [inventory] [playbook]
```

---

# 🔐 **SECURITY FEATURES**

- ✅ **Firewall Configuration**: UFW rules for Kubernetes ports only
- ✅ **Version Pinning**: Prevents unexpected package updates
- ✅ **SystemD Cgroup Driver**: Better integration and stability
- ✅ **TLS Certificates**: Proper etcd and API server encryption
- ✅ **Network Policies**: Calico CNI with security policies
- ✅ **RBAC**: Role-based access control configured

---

# 📈 **PRODUCTION RECOMMENDATIONS**

1. **✅ Use HA Setup**: Essential for production workloads
2. **✅ Backup Strategy**: Implement regular etcd backups
3. **✅ Resource Monitoring**: Included Prometheus/Grafana stack
4. **✅ Network Policies**: Implement Calico security policies
5. **✅ RBAC**: Configure role-based access control
6. **✅ Secrets Management**: Use external secret management
7. **✅ Pod Security**: Implement Pod Security Standards
8. **✅ Update Strategy**: Plan for rolling updates

---

# 🏁 **FINAL RECOMMENDATION**

## **🎯 Go with HA Setup!**

**Why HA is perfect for your infrastructure:**
1. **You have 6 hosts** - ideal for HA architecture
2. **Production-grade** - ready for real workloads  
3. **Future-proof** - no need to rebuild later
4. **Learning opportunity** - experience with enterprise architecture
5. **Same monitoring** - production_addons.yaml works with both

### **🚀 Deploy Everything Now:**
```bash
# One command to rule them all!
ansible -i ha_inventory.ini all -m ping && \
ansible-playbook -i ha_inventory.ini ha_multi_master.yaml && \
ansible-playbook -i ha_inventory.ini production_addons.yaml
```

### **🎉 You'll Have:**
- ✅ **Zero-downtime** Kubernetes cluster
- ✅ **Complete monitoring** with Grafana dashboards
- ✅ **Ingress controller** for web applications
- ✅ **Load balancing** with automatic failover
- ✅ **Production-ready** infrastructure

**Access your cluster at: `http://grafana.192.168.1.100.nip.io:30080` 🚀**

---

**🎯 Ready for production Kubernetes deployment!** Your infrastructure will be enterprise-grade with monitoring, high availability, and zero single points of failure. 

## **Playbook Overview**

| Playbook | Purpose | Use Case | Safety Level |
|----------|---------|----------|--------------|
| `improved_k8s_cluster.yaml` | **Fresh Installation** | New cluster setup | 🛡️ Protected |
| `production_addons.yaml` | **Add Components** | Install monitoring/ingress | ✅ Safe |
| `k8s_upgrade.yaml` | **Version Upgrade** | Upgrade existing cluster | ⚠️ Requires care |
| `ha_multi_master.yaml` | **HA Installation** | Multi-master setup | 🚨 Advanced |

### **🚨 IMPORTANT: Playbook Usage**

- **For NEW clusters**: Use `improved_k8s_cluster.yaml`
- **For EXISTING clusters**: Use `production_addons.yaml` (adds components)
- **For UPGRADES**: Use `k8s_upgrade.yaml` (version upgrades)
- **For HA setup**: Use `ha_multi_master.yaml` (advanced users)

**❌ DO NOT use `improved_k8s_cluster.yaml` on existing clusters - it will destroy them!**

# 🔄 **KUBERNETES CLUSTER UPGRADES**

## **Upgrade Your Existing Cluster**

### **⚠️ Important Notes**
- **Current playbooks are NOT for upgrades** - they're for fresh installations
- **Use `k8s_upgrade.yaml` specifically for version upgrades**
- **Always upgrade incrementally** (1.28 → 1.29 → 1.30, not 1.28 → 1.30)
- **Test in development environment first**

### **Pre-Upgrade Checklist**
```bash
# 1. Check current version
kubectl version --short
kubectl get nodes -o wide

# 2. Verify cluster health
kubectl get nodes
kubectl get pods --all-namespaces

# 3. Check upgrade path (only adjacent versions supported)
# ✅ Valid: 1.28.x → 1.29.x
# ❌ Invalid: 1.28.x → 1.30.x
```

### **Upgrade Process**

#### **Step 1: Configure Target Version**
Edit `k8s_upgrade.yaml`:
```yaml
vars:
  current_k8s_version: "1.28.0"      # Your current version
  target_k8s_version: "1.29.0"       # Target version
  target_k8s_minor: "1.29"           # Target minor version
  backup_enabled: true               # Create etcd backup
```

#### **Step 2: Run Upgrade**
```bash
# Standard upgrade with safety prompts
ansible-playbook -i inventory.ini k8s_upgrade.yaml --ask-become-pass

# Automated upgrade (no prompts)
ansible-playbook -i inventory.ini k8s_upgrade.yaml --ask-become-pass -e auto_confirm=true
```

#### **Step 3: Verify Upgrade**
```bash
kubectl version
kubectl get nodes -o wide
kubectl get pods --all-namespaces
```

### **Upgrade Sequence**
1. 💾 **Backup etcd** (automatic)
2. 🔄 **Upgrade control plane** (masters one by one)
3. 🔄 **Upgrade worker nodes** (rolling upgrade)
4. 🌐 **Upgrade CNI and components**
5. ✅ **Verify cluster health**

### **Rollback (if needed)**
```bash
# Restore etcd backup
sudo ETCDCTL_API=3 etcdctl snapshot restore /var/lib/etcd/backup-*.db

# Downgrade packages
sudo apt install kubelet=1.28.0-* kubeadm=1.28.0-* kubectl=1.28.0-*
```

**📖 For detailed upgrade instructions, see [UPGRADE_GUIDE.md](UPGRADE_GUIDE.md)**

--- 