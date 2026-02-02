# 参加者セットアップガイド

> **重要**: ハンズオン開始前に必ずこの設定を完了してください

---

## 📌 概要

複数の参加者が同じAWSアカウントでハンズオンを行うため、各自のリソースが衝突しないよう**参加者ID**を設定します。

---

## 🔧 Step 1: 参加者IDの設定

### 1-1. 参加者IDを決める

講師から指定された参加者IDを使用するか、以下のルールで自分のIDを決めてください：

- **半角英数字とハイフンのみ**使用可能
- **3〜10文字**程度
- 例: `user01`, `tanaka`, `team-a`

### 1-2. 環境変数の設定

Dev Spacesのターミナルで以下を実行：

```bash
# 参加者IDを設定（例: user01）
export PARTICIPANT_ID="user01"

# .bashrcに永続化
echo 'export PARTICIPANT_ID="user01"' >> ~/.bashrc

# 設定確認
echo "Your Participant ID: $PARTICIPANT_ID"
```

### 1-3. 設定ファイルの作成

```bash
# 設定ディレクトリを作成
mkdir -p ~/.workshop

# 設定ファイルを作成
cat > ~/.workshop/config << EOF
PARTICIPANT_ID=${PARTICIPANT_ID}
AWS_REGION=ap-northeast-1
PROJECT_NAME=iac-workshop
EOF

# 確認
cat ~/.workshop/config
```

---

## 🔧 Step 2: Terraform変数ファイルの作成

各環境ディレクトリに参加者固有の変数ファイルを作成します。

### 2-1. dev環境

```bash
cd /projects/IaC-Workshop/terraform/environments/dev

# terraform.tfvars を作成
cat > terraform.tfvars << EOF
# Participant Configuration
participant_id = "${PARTICIPANT_ID}"

# Project Settings
project_name = "iac-workshop"
aws_region   = "ap-northeast-1"

# Network Settings (自動計算されるため通常は変更不要)
# vpc_cidr = "10.X.0.0/16"  # Xは参加者ごとに異なる
EOF

echo "Created terraform.tfvars for participant: $PARTICIPANT_ID"
```

### 2-2. dev-ecs環境（ECSハンズオン用）

```bash
cd /projects/IaC-Workshop/terraform/environments/dev-ecs

cat > terraform.tfvars << EOF
participant_id = "${PARTICIPANT_ID}"
project_name   = "iac-workshop"
aws_region     = "ap-northeast-1"
EOF
```

---

## 🔧 Step 3: Ansibleインベントリの準備

```bash
cd /projects/IaC-Workshop/ansible

# 参加者固有のインベントリディレクトリを作成
mkdir -p inventory/${PARTICIPANT_ID}

# 初期インベントリファイルを作成
cat > inventory/${PARTICIPANT_ID}/hosts.yml << EOF
---
# Inventory for participant: ${PARTICIPANT_ID}
all:
  vars:
    ansible_user: ec2-user
    ansible_ssh_private_key_file: ~/.ssh/${PARTICIPANT_ID}-key
    ansible_python_interpreter: auto_silent
    participant_id: "${PARTICIPANT_ID}"

  children:
    webservers:
      hosts:
        # EC2作成後にホストを追加
        # web1:
        #   ansible_host: x.x.x.x

    local:
      hosts:
        localhost:
          ansible_connection: local
          ansible_python_interpreter: "{{ ansible_playbook_python }}"
EOF

echo "Created inventory for participant: $PARTICIPANT_ID"
```

---

## 🔧 Step 4: SSHキーペアの作成

```bash
# 参加者固有のSSHキーを生成
ssh-keygen -t rsa -b 4096 -f ~/.ssh/${PARTICIPANT_ID}-key -N "" -C "${PARTICIPANT_ID}@workshop"

# 公開鍵の確認
cat ~/.ssh/${PARTICIPANT_ID}-key.pub
```

---

## ✅ セットアップ確認

以下のコマンドで設定を確認：

```bash
echo "=========================================="
echo "Participant Setup Verification"
echo "=========================================="
echo "Participant ID: $PARTICIPANT_ID"
echo "SSH Key: ~/.ssh/${PARTICIPANT_ID}-key"
echo "Terraform vars: /projects/IaC-Workshop/terraform/environments/dev/terraform.tfvars"
echo "Ansible inventory: /projects/IaC-Workshop/ansible/inventory/${PARTICIPANT_ID}/hosts.yml"
echo ""

# ファイル存在確認
[ -f ~/.workshop/config ] && echo "✅ Workshop config exists" || echo "❌ Workshop config missing"
[ -f ~/.ssh/${PARTICIPANT_ID}-key ] && echo "✅ SSH key exists" || echo "❌ SSH key missing"
[ -f /projects/IaC-Workshop/terraform/environments/dev/terraform.tfvars ] && echo "✅ Terraform vars exists" || echo "❌ Terraform vars missing"
[ -f /projects/IaC-Workshop/ansible/inventory/${PARTICIPANT_ID}/hosts.yml ] && echo "✅ Ansible inventory exists" || echo "❌ Ansible inventory missing"
```

---

## 📋 リソース命名規則

参加者IDを含むリソース名が自動的に生成されます：

| リソース | 命名パターン | 例 (user01の場合) |
|---------|-------------|-------------------|
| VPC | `{project}-{participant}-vpc` | `iac-workshop-user01-vpc` |
| Subnet | `{project}-{participant}-public-1a` | `iac-workshop-user01-public-1a` |
| EC2 | `{project}-{participant}-web-1` | `iac-workshop-user01-web-1` |
| Security Group | `{project}-{participant}-web-sg` | `iac-workshop-user01-web-sg` |
| Key Pair | `{participant}-key` | `user01-key` |
| ALB | `{project}-{participant}-alb` | `iac-workshop-user01-alb` |
| RDS | `{project}-{participant}-mysql` | `iac-workshop-user01-mysql` |

---

## ⚠️ 注意事項

1. **参加者IDは変更しない**: 一度設定したIDはハンズオン終了まで変更しないでください
2. **リソースの削除**: ハンズオン終了時は必ず `terraform destroy` でリソースを削除してください
3. **他の参加者のリソース**: 他の参加者のリソースには触れないでください

---

## 🔄 IDの変更が必要な場合

やむを得ずIDを変更する場合：

```bash
# 1. 既存リソースを削除
cd /projects/IaC-Workshop/terraform/environments/dev
terraform destroy

# 2. 新しいIDを設定
export PARTICIPANT_ID="new-id"
echo 'export PARTICIPANT_ID="new-id"' >> ~/.bashrc

# 3. このセットアップガイドを再実行
```

---

[次へ: ハンズオンを開始 →](../index.md)
