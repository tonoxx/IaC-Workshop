# AI-Driven IaC Workshop Development Container
FROM mcr.microsoft.com/devcontainers/base:ubuntu-22.04

# Avoid interactive prompts during installation
ENV DEBIAN_FRONTEND=noninteractive

# Install system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    git \
    unzip \
    jq \
    vim \
    nano \
    tree \
    htop \
    sshpass \
    software-properties-common \
    gnupg \
    lsb-release \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Install AWS Session Manager Plugin
RUN curl "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/ubuntu_64bit/session-manager-plugin.deb" -o "session-manager-plugin.deb" \
    && dpkg -i session-manager-plugin.deb \
    && rm session-manager-plugin.deb

# Install tflint (Terraform Linter)
RUN curl -s https://raw.githubusercontent.com/terraform-linters/tflint/master/install_linux.sh | bash

# Install checkov (IaC security scanner)
RUN pip3 install checkov --break-system-packages

# Install pre-commit
RUN pip3 install pre-commit --break-system-packages

# Create Terraform plugin cache directory
RUN mkdir -p /home/vscode/.terraform.d/plugin-cache \
    && chown -R vscode:vscode /home/vscode/.terraform.d

# Create Ansible configuration directory
RUN mkdir -p /home/vscode/.ansible \
    && chown -R vscode:vscode /home/vscode/.ansible

# Create workspace directory
RUN mkdir -p /workspaces \
    && chown -R vscode:vscode /workspaces

# Switch to non-root user
USER vscode

# Set working directory
WORKDIR /workspaces

