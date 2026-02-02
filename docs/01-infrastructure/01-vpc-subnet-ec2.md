# ①-① Terraform × AI：基本リソースの生成

> **区分**: 必須  
> **所要時間**: 約60分  
> **学習目標**: AIを使ってTerraformコードを効率的に生成する方法を学ぶ  
> **前提条件**: [参加者セットアップ](../00-setup/participant-setup.md)を完了していること

---

## 📌 このハンズオンで学ぶこと

1. **AIへの効果的なプロンプトの書き方**
   - 条件を明確に伝える方法
   - 既存の変数・リソースを参照させる方法

2. **Terraformコードの構造**
   - リソース定義の基本構文
   - 変数と出力の使い方
   - モジュールの参照方法

3. **AI生成コードのレビュー**
   - 生成されたコードの確認ポイント
   - ベストプラクティスとの照合

---

## 🔧 事前準備

```bash
# 参加者IDの確認
echo "Participant ID: $PARTICIPANT_ID"

# 作業ディレクトリへ移動
cd /projects/IaC-Workshop/terraform/environments/dev

# 設定ファイルの確認
cat terraform.tfvars
```

---

## 📝 課題1: 既存コードをAIに説明させる

### 課題内容

既存のTerraformモジュールをAIに読み込ませ、構造を説明させてください。

### 条件

| 項目 | 値 |
|-----|---|
| 対象ファイル | `terraform/modules/vpc/main.tf` |
| 説明させる内容 | コードの構造、リソース間の関係 |
| 出力形式 | 箇条書きで整理 |

### ポイント

- AIにコードを理解させることで、後続の課題でそのコンテキストを活用できる
- 「このモジュールを使って〜」という指示が可能になる

<details>
<summary>📖 正解例（クリックで展開）</summary>

### 💬 プロンプト例

```
terraform/modules/vpc/main.tf を読んで、以下を説明してください：

1. このモジュールで定義されているリソースの一覧
2. 入力変数（variable）と出力（output）
3. local変数の使い方
4. リソース間の依存関係

Terraform初心者にもわかるように、箇条書きで整理してください。
```

### 📘 期待される回答のポイント

- **入力変数**: `project_name`, `participant_id`, `environment`, `vpc_cidr`
- **ローカル変数**: `name_prefix` でリソース名を統一
- **出力**: `vpc_id`, `public_subnet_ids`, `private_subnet_ids`
- **依存関係**: VPC → Subnet → Route Table の順

</details>

---

## 📝 課題2: Security Groupリソースの生成

### 課題内容

AIにTerraformのSecurity Groupリソースを生成させてください。

### 条件

| 項目 | 値 |
|-----|---|
| リソースタイプ | `aws_security_group` |
| リソース名 | `web` |
| 属性: name | `${local.name_prefix}-web-sg` |
| 属性: vpc_id | `module.vpc.vpc_id` |
| インバウンド1 | SSH（ポート22） |
| インバウンド2 | HTTP（ポート80） |
| アウトバウンド | 全て許可 |
| タグ | Name = リソース名と同じ |

### ポイント

- **条件を表形式で整理**してからプロンプトを作成すると、AIが正確に理解しやすい
- 既存の変数（`local.name_prefix`）やモジュール出力（`module.vpc.vpc_id`）を明示する

<details>
<summary>📖 正解例（クリックで展開）</summary>

### 💬 プロンプト例

```
以下の条件でTerraformのaws_security_groupリソースを作成してください：

リソース定義:
- resource "aws_security_group" "web"
- name = "${local.name_prefix}-web-sg"
- description = "Security group for web server"
- vpc_id = module.vpc.vpc_id

インバウンドルール:
1. SSH: from_port=22, to_port=22, protocol="tcp", cidr_blocks=["0.0.0.0/0"]
2. HTTP: from_port=80, to_port=80, protocol="tcp", cidr_blocks=["0.0.0.0/0"]

アウトバウンドルール:
- 全トラフィック許可: from_port=0, to_port=0, protocol="-1"

タグ:
- Name = "${local.name_prefix}-web-sg"

各ブロックにdescriptionを付けてください。
```

### 🖥️ 生成されるコード

```hcl
resource "aws_security_group" "web" {
  name        = "${local.name_prefix}-web-sg"
  description = "Security group for web server"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "SSH from anywhere"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.name_prefix}-web-sg"
  }
}
```

</details>

---

## 📝 課題3: Key Pairリソースの生成

### 課題内容

SSHキーペアのTerraformリソースを生成させてください。

### 条件

| 項目 | 値 |
|-----|---|
| リソースタイプ | `aws_key_pair` |
| リソース名 | `workshop` |
| 属性: key_name | `${var.participant_id}-key` |
| 属性: public_key | `file("~/.ssh/${var.participant_id}-key.pub")` |
| タグ | Name = key_nameと同じ |

### 事前作業

SSHキーを生成（AIに聞いてもOK）

<details>
<summary>📖 正解例（クリックで展開）</summary>

### 💬 プロンプト例（SSHキー生成）

```
SSHキーペアを生成するbashコマンドを教えてください。
条件:
- 鍵ファイル: ~/.ssh/${PARTICIPANT_ID}-key
- 形式: RSA 4096bit
- パスフレーズ: なし
```

### 🖥️ SSHキー生成コマンド

```bash
ssh-keygen -t rsa -b 4096 -f ~/.ssh/${PARTICIPANT_ID}-key -N ""
```

### 💬 プロンプト例（Terraform）

```
以下の条件でTerraformのaws_key_pairリソースを作成してください：

- resource "aws_key_pair" "workshop"
- key_name = "${var.participant_id}-key"
- public_key = file関数で ~/.ssh/${var.participant_id}-key.pub を読み込み
- tags: Name = key_nameと同じ値
```

### 🖥️ 生成されるコード

```hcl
resource "aws_key_pair" "workshop" {
  key_name   = "${var.participant_id}-key"
  public_key = file("~/.ssh/${var.participant_id}-key.pub")

  tags = {
    Name = "${var.participant_id}-key"
  }
}
```

</details>

---

## 📝 課題4: EC2インスタンスの生成

### 課題内容

EC2インスタンスのTerraformコードを生成させてください。
**Data Source**を使った動的なAMI取得も含めます。

### 条件

| 項目 | 値 |
|-----|---|
| Data Source | `aws_ami`（Amazon Linux 2023の最新を取得） |
| リソースタイプ | `aws_instance` |
| リソース名 | `web` |
| 属性: instance_type | `t3.micro` |
| 属性: subnet_id | `module.vpc.public_subnet_ids[0]` |
| 属性: key_name | `aws_key_pair.workshop.key_name` |
| 属性: security_groups | `[aws_security_group.web.id]` |
| 属性: associate_public_ip | `true` |
| root_block_device | 20GB, gp3 |
| タグ | Name = `${local.name_prefix}-web-server` |

### ポイント

- **Data Source**と**Resource**の違いをAIに説明させてもよい
- 他のリソースの参照方法（`aws_key_pair.workshop.key_name`）を学ぶ

<details>
<summary>📖 正解例（クリックで展開）</summary>

### 💬 プロンプト例

```
以下の条件でTerraformコードを作成してください：

1. Data Source: aws_ami
   - 名前: amazon_linux_2023
   - most_recent = true
   - owners = ["amazon"]
   - filter: name = "al2023-ami-*-x86_64"
   - filter: virtualization-type = "hvm"

2. Resource: aws_instance
   - リソース名: web
   - ami = data.aws_ami.amazon_linux_2023.id
   - instance_type = "t3.micro"
   - key_name = aws_key_pair.workshop.key_name
   - vpc_security_group_ids = [aws_security_group.web.id]
   - subnet_id = module.vpc.public_subnet_ids[0]
   - associate_public_ip_address = true
   - root_block_device: volume_size=20, volume_type="gp3"
   - tags: Name = "${local.name_prefix}-web-server"

3. Output:
   - ec2_public_ip: EC2のパブリックIP
   - ssh_command: SSH接続コマンド文字列
```

### 🖥️ 生成されるコード

```hcl
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_instance" "web" {
  ami                         = data.aws_ami.amazon_linux_2023.id
  instance_type               = "t3.micro"
  key_name                    = aws_key_pair.workshop.key_name
  vpc_security_group_ids      = [aws_security_group.web.id]
  subnet_id                   = module.vpc.public_subnet_ids[0]
  associate_public_ip_address = true

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }

  tags = {
    Name = "${local.name_prefix}-web-server"
  }
}

output "ec2_public_ip" {
  description = "EC2 Public IP"
  value       = aws_instance.web.public_ip
}

output "ssh_command" {
  description = "SSH command to connect"
  value       = "ssh -i ~/.ssh/${var.participant_id}-key ec2-user@${aws_instance.web.public_ip}"
}
```

</details>

---

## 📝 課題5: Terraformの実行

### 課題内容

生成したコードを実行し、リソースを作成してください。

### 条件

| コマンド | 目的 |
|---------|------|
| `terraform init` | プロバイダーのダウンロード |
| `terraform plan` | 実行計画の確認 |
| `terraform apply` | リソースの作成 |
| `terraform output` | 出力値の確認 |

### 検証

SSH接続してEC2が動作していることを確認

<details>
<summary>📖 正解例（クリックで展開）</summary>

### 💬 プロンプト例

```
Terraformでインフラを構築する手順を教えてください。
init, plan, apply, output の各コマンドの役割を説明してください。
```

### 🖥️ 実行コマンド

```bash
cd /projects/IaC-Workshop/terraform/environments/dev

# 初期化
terraform init

# 実行計画
terraform plan

# 適用（yesで確認）
terraform apply

# 出力確認
terraform output

# SSH接続
ssh -i ~/.ssh/${PARTICIPANT_ID}-key ec2-user@$(terraform output -raw ec2_public_ip)
```

</details>

---

## 📝 課題6: Ansibleインベントリの生成

### 課題内容

Terraform出力を使ってAnsibleインベントリを生成するスクリプトをAIに作成させてください。

### 条件

| 項目 | 値 |
|-----|---|
| 出力形式 | YAML |
| パス | `ansible/inventory/${PARTICIPANT_ID}/hosts.yml` |
| 変数: ansible_user | `ec2-user` |
| 変数: ansible_ssh_private_key_file | `~/.ssh/${PARTICIPANT_ID}-key` |
| グループ: webservers | EC2のIPを含む |

### 検証

`ansible webservers -m ping` で接続確認

<details>
<summary>📖 正解例（クリックで展開）</summary>

### 💬 プロンプト例

```
以下の条件でAnsibleインベントリを生成するbashスクリプトを作成してください：

条件:
- Terraform outputからEC2のIPを取得
- YAML形式のインベントリを生成
- 保存先: ansible/inventory/${PARTICIPANT_ID}/hosts.yml

インベントリの内容:
- all.vars:
  - ansible_user: ec2-user
  - ansible_ssh_private_key_file: ~/.ssh/${PARTICIPANT_ID}-key
  - ansible_python_interpreter: auto_silent
- children.webservers.hosts:
  - web1: ansible_host=<EC2のIP>
```

### 🖥️ 生成されるスクリプト

```bash
#!/bin/bash
EC2_IP=$(terraform output -raw ec2_public_ip)

mkdir -p /projects/IaC-Workshop/ansible/inventory/${PARTICIPANT_ID}

cat > /projects/IaC-Workshop/ansible/inventory/${PARTICIPANT_ID}/hosts.yml << EOF
---
all:
  vars:
    ansible_user: ec2-user
    ansible_ssh_private_key_file: ~/.ssh/${PARTICIPANT_ID}-key
    ansible_python_interpreter: auto_silent

  children:
    webservers:
      hosts:
        web1:
          ansible_host: ${EC2_IP}
EOF

echo "Created: ansible/inventory/${PARTICIPANT_ID}/hosts.yml"
```

### 検証コマンド

```bash
cd /projects/IaC-Workshop/ansible
ansible webservers -m ping -i inventory/${PARTICIPANT_ID}/hosts.yml
```

</details>

---

## 🧹 クリーンアップ

```bash
cd /projects/IaC-Workshop/terraform/environments/dev
terraform destroy
```

---

## ✅ チェックリスト

- [ ] 課題1: AIに既存コードを説明させた
- [ ] 課題2: Security Groupのコードを生成させた
- [ ] 課題3: Key Pairのコードを生成させた
- [ ] 課題4: EC2のコードを生成させた
- [ ] 課題5: Terraformを実行してリソースを作成した
- [ ] 課題6: Ansibleインベントリを生成した

---

## 💡 振り返り

### 効果的だったプロンプトの特徴

1. **条件を明確に**：表形式やリスト形式で整理
2. **既存リソースを明示**：変数名やモジュール出力を伝える
3. **出力形式を指定**：タグやdescriptionの有無など

### 改善できる点

- プロンプトが長すぎた/短すぎた箇所
- AIの回答で修正が必要だった箇所

---

## 🎯 発展課題（オプション）

### 発展1: 複数リソースの一括生成

```
「EC2を2台作成し、それぞれ異なるAZに配置するTerraformコードを生成してください」
というプロンプトで、count や for_each の使い方を学ぶ
```

### 発展2: 既存コードのリファクタリング

```
「このTerraformコードをモジュール化してください」
というプロンプトで、モジュール設計を学ぶ
```

### 発展3: エラー解決

```
Terraformエラーが発生したら、エラーメッセージをAIに貼り付けて
解決策を聞いてみましょう
```

---

[← 戻る](../index.md) | [次のハンズオン →](./02-web-system-ec2.md)
