#!/bin/bash

# Fix Local Registry Configuration on All Nodes
# This configures all worker nodes to trust the local registry

set -e

REGISTRY_HOST="192.168.1.82:5555"
ANSIBLE_INVENTORY="../ansile_k8s_install/inventory.ini"

echo "🔧 Configuring local Docker registry on all nodes..."

# Create Ansible playbook for registry configuration
cat > configure-registry.yml << EOF
---
- name: Configure Docker Registry on All Nodes
  hosts: all
  become: yes
  tasks:
    - name: Create Docker directory
      file:
        path: /etc/docker
        state: directory
        mode: '0755'

    - name: Configure Docker daemon for insecure registry
      copy:
        content: |
          {
            "insecure-registries": ["$REGISTRY_HOST"],
            "log-driver": "json-file",
            "log-opts": {
              "max-size": "10m",
              "max-file": "3"
            }
          }
        dest: /etc/docker/daemon.json
        mode: '0644'
      notify: restart docker

    - name: Ensure Docker is started and enabled
      systemd:
        name: docker
        state: started
        enabled: yes

    - name: Test registry connectivity
      shell: "docker pull $REGISTRY_HOST/tweetstream/api:1.0.0"
      register: pull_result
      ignore_errors: yes

    - name: Display pull result
      debug:
        msg: "Registry pull test: {{ 'SUCCESS' if pull_result.rc == 0 else 'FAILED' }}"

  handlers:
    - name: restart docker
      systemd:
        name: docker
        state: restarted
EOF

# Run Ansible playbook
if [ -f "$ANSIBLE_INVENTORY" ]; then
    echo "📋 Running Ansible playbook to configure all nodes..."
    ansible-playbook -i "$ANSIBLE_INVENTORY" configure-registry.yml -K
    
    echo "✅ Registry configuration completed!"
    echo "🧪 Testing image pull from worker nodes..."
    
    # Test from worker nodes
    ansible worker_nodes -i "$ANSIBLE_INVENTORY" -m shell -a "docker images | grep tweetstream" -K
else
    echo "❌ Ansible inventory not found at $ANSIBLE_INVENTORY"
    echo "Please run this script from the helm-chart directory"
    exit 1
fi

# Clean up
rm -f configure-registry.yml

echo "🎉 Local registry is now properly configured on all nodes!" 