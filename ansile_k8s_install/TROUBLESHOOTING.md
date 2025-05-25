# Kubernetes Deployment Troubleshooting Guide

This guide documents common issues encountered during Kubernetes cluster deployment and their solutions, based on real deployment experiences.

## Table of Contents
1. [Sudo Password Issues](#sudo-password-issues)
2. [Host Pattern Mismatches](#host-pattern-mismatches)
3. [CPU Requirements](#cpu-requirements)
4. [Repository Issues](#repository-issues)
5. [Port Conflicts](#port-conflicts)
6. [CNI Plugin Issues](#cni-plugin-issues)
7. [Storage Issues](#storage-issues)
8. [Monitoring Stack Issues](#monitoring-stack-issues)

## Sudo Password Issues

**Problem**: Playbook fails with "Missing sudo password" errors.

**Solution**: Always use the `--ask-become-pass` flag when running playbooks:
```bash
ansible-playbook -i inventory.ini improved_k8s_cluster.yaml --ask-become-pass
```

**Prevention**: The playbooks now include proper `become: true` directives and error handling.

## Host Pattern Mismatches

**Problem**: Playbooks fail with "No hosts matched" errors when using `hosts: masters[0]` but inventory uses `master` (singular).

**Solution**: Updated all playbooks to use consistent host patterns:
- Use `hosts: master` for single master deployments
- Use `hosts: masters[0]` only for multi-master HA deployments

**Files Updated**:
- `production_addons.yaml` - Changed from `masters[0]` to `master`
- All playbooks now use consistent naming

## CPU Requirements

**Problem**: Some hosts fail minimum CPU requirements (originally required 2 cores).

**Solutions**:
1. **Bypass for testing**: Use `--limit` to deploy only to suitable hosts:
   ```bash
   ansible-playbook -i inventory.ini production_addons.yaml --limit master-node --ask-become-pass
   ```

2. **Relaxed requirements**: Updated playbooks to require minimum 1 CPU core for single-node setups.

**Prevention**: The improved playbook now has more flexible CPU requirements.

## Repository Issues

**Problem**: Old Kubernetes repositories cause signature verification failures.

**Symptoms**:
- `NO_PUBKEY` errors
- `The following signatures were invalid` errors
- Package installation failures

**Solution**: The improved playbook now includes repository cleanup:
```yaml
- name: Remove old Kubernetes repository files
  file:
    path: "{{ item }}"
    state: absent
  loop:
    - /etc/apt/sources.list.d/kubernetes.list
    - /etc/apt/keyrings/kubernetes-apt-keyring.gpg
```

**Manual Fix** (if needed):
```bash
# Remove old repositories
sudo rm -f /etc/apt/sources.list.d/kubernetes.list
sudo rm -f /etc/apt/keyrings/kubernetes-apt-keyring.gpg

# Update package cache
sudo apt update
```

## Port Conflicts

**Problem**: Kubernetes initialization fails due to ports already in use from previous installations.

**Symptoms**:
- `port 6443 already in use`
- `port 10259 already in use`
- `port 10257 already in use`

**Solution**: Reset the cluster before initialization:
```bash
sudo kubeadm reset -f --cri-socket unix:///var/run/containerd/containerd.sock
sudo iptables -F && sudo iptables -t nat -F && sudo iptables -t mangle -F && sudo iptables -X
```

**Prevention**: The improved playbook includes comprehensive cleanup in the "Clean up previous installations" section.

## CNI Plugin Issues

**Problem**: Nodes remain in "NotReady" state with "cni plugin not initialized" error.

**Symptoms**:
```bash
kubectl get nodes
# Shows: NotReady ... runtime network not ready: cni plugin not initialized
```

**Solution**: Restart containerd and kubelet services:
```bash
sudo systemctl restart containerd
sudo systemctl restart kubelet
```

**Prevention**: The improved playbook now includes automatic service restarts after CNI installation:
```yaml
- name: Restart containerd to ensure CNI plugin initialization
  systemd:
    name: containerd
    state: restarted

- name: Restart kubelet to ensure proper CNI integration
  systemd:
    name: kubelet
    state: restarted
```

## Storage Issues

**Problem**: Prometheus StatefulSet fails to create due to missing storage class.

**Symptoms**:
- Prometheus pods stuck in `Pending` state
- Events show `persistentvolumeclaim "prometheus-..." is pending`

**Solution**: Install local-path-provisioner before deploying monitoring stack:
```bash
kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/v0.0.24/deploy/local-path-storage.yaml
kubectl patch storageclass local-path -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
```

**Prevention**: The updated production addons playbook now installs storage provisioner first.

## Monitoring Stack Issues

**Problem**: Prometheus operator doesn't recognize new storage class immediately.

**Solution**: Restart the Prometheus operator:
```bash
kubectl delete pod -l app.kubernetes.io/name=kube-prometheus-stack-operator -n monitoring
```

**Prevention**: The updated playbook includes automatic operator restart detection and handling.

## General Troubleshooting Commands

### Check Cluster Status
```bash
kubectl get nodes -o wide
kubectl get pods --all-namespaces
kubectl get svc --all-namespaces
```

### Check System Logs
```bash
sudo journalctl -u kubelet -f
sudo journalctl -u containerd -f
```

### Check Pod Logs
```bash
kubectl logs -f <pod-name> -n <namespace>
kubectl describe pod <pod-name> -n <namespace>
```

### Check Events
```bash
kubectl get events --sort-by=.metadata.creationTimestamp
kubectl get events -n <namespace>
```

### Network Troubleshooting
```bash
# Check CNI pods
kubectl get pods -n kube-system | grep calico

# Check network policies
kubectl get networkpolicies --all-namespaces

# Test DNS resolution
kubectl run test-pod --image=busybox --rm -it -- nslookup kubernetes.default
```

## Recovery Procedures

### Complete Cluster Reset
```bash
# On all nodes
sudo kubeadm reset -f --cri-socket unix:///var/run/containerd/containerd.sock
sudo iptables -F && sudo iptables -t nat -F && sudo iptables -t mangle -F && sudo iptables -X
sudo rm -rf /etc/cni/net.d /var/lib/kubelet /var/lib/etcd /etc/kubernetes ~/.kube

# Remove network interfaces
for iface in cni0 flannel.1 cali0 cali1 docker0; do
  sudo ip link delete $iface 2>/dev/null || true
done

# Restart services
sudo systemctl restart containerd
sudo systemctl restart kubelet
```

### Monitoring Stack Reset
```bash
# Remove monitoring namespace
kubectl delete namespace monitoring

# Remove Helm releases
helm uninstall prometheus -n monitoring
helm uninstall ingress-nginx -n ingress-nginx

# Clean up storage
kubectl delete pvc --all -n monitoring
```

## Prevention Best Practices

1. **Always use the latest playbooks** - They include all discovered fixes
2. **Run with proper flags**: `--ask-become-pass` for sudo operations
3. **Check prerequisites** before deployment (CPU, memory, network)
4. **Clean up previous installations** before new deployments
5. **Monitor logs** during deployment for early issue detection
6. **Test connectivity** between nodes before cluster initialization
7. **Verify storage** availability before deploying stateful applications

## Getting Help

If you encounter issues not covered in this guide:

1. Check the Ansible playbook output for specific error messages
2. Review Kubernetes events: `kubectl get events --sort-by=.metadata.creationTimestamp`
3. Check system logs: `sudo journalctl -u kubelet -f`
4. Verify network connectivity between nodes
5. Ensure all prerequisites are met (CPU, memory, storage)

Remember: Most issues can be resolved by following the cleanup procedures and re-running the playbooks with the latest fixes included. 