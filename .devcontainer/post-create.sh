#!/bin/bash
set -e

echo "🚀 Setting up AI-Driven IaC Workshop Environment..."

# Create Terraform plugin cache directory
mkdir -p ~/.terraform.d/plugin-cache

# Create Ansible configuration
cat > ~/.ansible.cfg << 'EOF'
[defaults]
inventory = ./inventory
host_key_checking = False
retry_files_enabled = False
interpreter_python = auto_silent

[privilege_escalation]
become = True
become_method = sudo
become_user = root
become_ask_pass = False
EOF

# Configure AWS CLI (placeholder)
mkdir -p ~/.aws

# Check if AWS credentials are mounted
if [ ! -f ~/.aws/credentials ]; then
    echo "⚠️  AWS credentials not found. Please configure with 'aws configure'"
fi

# Verify tool installations
echo ""
echo "📦 Installed Tools:"
echo "==================="
echo -n "AWS CLI: " && aws --version 2>/dev/null || echo "Not installed"
echo -n "Terraform: " && terraform version 2>/dev/null | head -1 || echo "Not installed"
echo -n "Ansible: " && ansible --version 2>/dev/null | head -1 || echo "Not installed"
echo -n "TFLint: " && tflint --version 2>/dev/null || echo "Not installed"
echo -n "Checkov: " && checkov --version 2>/dev/null || echo "Not installed"
echo ""

# Create sample directory structure if not exists
if [ ! -d "terraform" ]; then
    mkdir -p terraform/modules
    mkdir -p terraform/environments/{dev,staging,prod}
fi

if [ ! -d "ansible" ]; then
    mkdir -p ansible/{playbooks,roles,inventory,group_vars,host_vars}
fi

echo "✅ Environment setup complete!"
echo ""
echo "📖 Quick Start:"
echo "  - Configure AWS: aws configure"
echo "  - Check Terraform: terraform version"
echo "  - Check Ansible: ansible --version"
echo "  - Use Continue AI: Press Cmd/Ctrl+L to open AI chat"
echo ""

