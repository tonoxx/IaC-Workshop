# ①-② Webシステム構築実践（Network、EC2、DB）

> **区分**: 任意  
> **所要時間**: 約90分  
> **難易度**: ★★★☆☆  
> **前提条件**: ①-①を完了していること

---

## 📌 概要

このハンズオンでは、実践的な3層Webシステムをテraformで構築し、Ansibleでアプリケーションをデプロイします。

### 学習目標

- 3層アーキテクチャ（Web/App/DB）の理解
- ALB（Application Load Balancer）の構築
- RDS（MySQL）の構築とセキュリティ設定
- AnsibleによるNginx/アプリケーションのデプロイ

### 構築するアーキテクチャ

```
                        インターネット
                             │
                    ┌────────┴────────┐
                    │       ALB       │
                    └────────┬────────┘
                             │
        ┌────────────────────┼────────────────────┐
        │                    │                    │
┌───────┴───────┐    ┌───────┴───────┐           │
│  Public-1a    │    │  Public-1c    │           │
│ ┌───────────┐ │    │ ┌───────────┐ │           │
│ │   EC2     │ │    │ │   EC2     │ │           │
│ │ (Web/App) │ │    │ │ (Web/App) │ │           │
│ └───────────┘ │    │ └───────────┘ │           │
└───────────────┘    └───────────────┘           │
        │                    │                    │
        └────────────────────┼────────────────────┘
                             │
                    ┌────────┴────────┐
                    │  Private Subnet │
                    │  ┌───────────┐  │
                    │  │    RDS    │  │
                    │  │  (MySQL)  │  │
                    │  └───────────┘  │
                    └─────────────────┘
```

---

## 🔧 事前準備

### 前提ハンズオンの完了確認

```bash
cd /projects/IaC-Workshop/terraform/environments/dev
terraform output vpc_id
```

VPC IDが表示されることを確認してください。

---

## 📝 Step 1: Terraformモジュールの作成

### 1-1. EC2モジュールの作成

```bash
mkdir -p /projects/IaC-Workshop/terraform/modules/ec2
```

`/projects/IaC-Workshop/terraform/modules/ec2/main.tf`:

```hcl
# =============================================================================
# EC2 Module - Web/Application Servers
# =============================================================================

variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
}

variable "instance_count" {
  type    = number
  default = 2
}

variable "key_name" {
  type = string
}

variable "alb_security_group_id" {
  type = string
}

# -----------------------------------------------------------------------------
# Data Sources
# -----------------------------------------------------------------------------

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

# -----------------------------------------------------------------------------
# Security Group
# -----------------------------------------------------------------------------

resource "aws_security_group" "ec2" {
  name        = "${var.project_name}-${var.environment}-ec2-sg"
  description = "Security group for EC2 instances"
  vpc_id      = var.vpc_id

  ingress {
    description     = "HTTP from ALB"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [var.alb_security_group_id]
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # 本番では踏み台サーバーからのみ許可
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-ec2-sg"
  }
}

# -----------------------------------------------------------------------------
# EC2 Instances
# -----------------------------------------------------------------------------

resource "aws_instance" "web" {
  count = var.instance_count

  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = var.instance_type
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.ec2.id]
  subnet_id              = element(var.subnet_ids, count.index)

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y python3 python3-pip
              EOF

  tags = {
    Name = "${var.project_name}-${var.environment}-web-${count.index + 1}"
  }
}

# -----------------------------------------------------------------------------
# Outputs
# -----------------------------------------------------------------------------

output "instance_ids" {
  value = aws_instance.web[*].id
}

output "private_ips" {
  value = aws_instance.web[*].private_ip
}

output "public_ips" {
  value = aws_instance.web[*].public_ip
}

output "security_group_id" {
  value = aws_security_group.ec2.id
}
```

### 1-2. ALBモジュールの作成

```bash
mkdir -p /projects/IaC-Workshop/terraform/modules/alb
```

`/projects/IaC-Workshop/terraform/modules/alb/main.tf`:

```hcl
# =============================================================================
# ALB Module - Application Load Balancer
# =============================================================================

variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
}

variable "target_instance_ids" {
  type = list(string)
}

# -----------------------------------------------------------------------------
# Security Group
# -----------------------------------------------------------------------------

resource "aws_security_group" "alb" {
  name        = "${var.project_name}-${var.environment}-alb-sg"
  description = "Security group for ALB"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTP from Internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS from Internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-alb-sg"
  }
}

# -----------------------------------------------------------------------------
# Application Load Balancer
# -----------------------------------------------------------------------------

resource "aws_lb" "main" {
  name               = "${var.project_name}-${var.environment}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.subnet_ids

  enable_deletion_protection = false

  tags = {
    Name = "${var.project_name}-${var.environment}-alb"
  }
}

# -----------------------------------------------------------------------------
# Target Group
# -----------------------------------------------------------------------------

resource "aws_lb_target_group" "main" {
  name     = "${var.project_name}-${var.environment}-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = "/"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 2
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-tg"
  }
}

# -----------------------------------------------------------------------------
# Target Group Attachments
# -----------------------------------------------------------------------------

resource "aws_lb_target_group_attachment" "main" {
  count            = length(var.target_instance_ids)
  target_group_arn = aws_lb_target_group.main.arn
  target_id        = var.target_instance_ids[count.index]
  port             = 80
}

# -----------------------------------------------------------------------------
# Listener
# -----------------------------------------------------------------------------

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }
}

# -----------------------------------------------------------------------------
# Outputs
# -----------------------------------------------------------------------------

output "alb_dns_name" {
  value = aws_lb.main.dns_name
}

output "alb_arn" {
  value = aws_lb.main.arn
}

output "security_group_id" {
  value = aws_security_group.alb.id
}

output "target_group_arn" {
  value = aws_lb_target_group.main.arn
}
```

### 1-3. RDSモジュールの作成

```bash
mkdir -p /projects/IaC-Workshop/terraform/modules/rds
```

`/projects/IaC-Workshop/terraform/modules/rds/main.tf`:

```hcl
# =============================================================================
# RDS Module - MySQL Database
# =============================================================================

variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
}

variable "ec2_security_group_id" {
  type = string
}

variable "db_name" {
  type    = string
  default = "workshop"
}

variable "db_username" {
  type    = string
  default = "admin"
}

variable "db_password" {
  type      = string
  sensitive = true
}

variable "instance_class" {
  type    = string
  default = "db.t3.micro"
}

# -----------------------------------------------------------------------------
# Security Group
# -----------------------------------------------------------------------------

resource "aws_security_group" "rds" {
  name        = "${var.project_name}-${var.environment}-rds-sg"
  description = "Security group for RDS"
  vpc_id      = var.vpc_id

  ingress {
    description     = "MySQL from EC2"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [var.ec2_security_group_id]
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-rds-sg"
  }
}

# -----------------------------------------------------------------------------
# DB Subnet Group
# -----------------------------------------------------------------------------

resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-${var.environment}-db-subnet"
  subnet_ids = var.subnet_ids

  tags = {
    Name = "${var.project_name}-${var.environment}-db-subnet"
  }
}

# -----------------------------------------------------------------------------
# RDS Instance
# -----------------------------------------------------------------------------

resource "aws_db_instance" "main" {
  identifier = "${var.project_name}-${var.environment}-mysql"

  engine               = "mysql"
  engine_version       = "8.0"
  instance_class       = var.instance_class
  allocated_storage    = 20
  max_allocated_storage = 100
  storage_type         = "gp3"

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  vpc_security_group_ids = [aws_security_group.rds.id]
  db_subnet_group_name   = aws_db_subnet_group.main.name

  multi_az               = false  # 開発環境なのでシングルAZ
  publicly_accessible    = false
  skip_final_snapshot    = true   # 開発環境なのでスナップショット不要

  backup_retention_period = 0  # 開発環境なのでバックアップ無効

  tags = {
    Name = "${var.project_name}-${var.environment}-mysql"
  }
}

# -----------------------------------------------------------------------------
# Outputs
# -----------------------------------------------------------------------------

output "endpoint" {
  value = aws_db_instance.main.endpoint
}

output "address" {
  value = aws_db_instance.main.address
}

output "port" {
  value = aws_db_instance.main.port
}

output "db_name" {
  value = aws_db_instance.main.db_name
}
```

---

## 📝 Step 2: メイン設定の更新

`/projects/IaC-Workshop/terraform/environments/dev/main.tf` に以下を追加：

```hcl
# =============================================================================
# Web System Resources
# =============================================================================

# ALB Security Group (EC2より先に作成)
resource "aws_security_group" "alb" {
  name        = "${var.project_name}-alb-sg"
  description = "Security group for ALB"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-alb-sg"
  }
}

# EC2 Module
module "ec2" {
  source = "../../modules/ec2"

  project_name          = var.project_name
  environment           = "dev"
  vpc_id                = module.vpc.vpc_id
  subnet_ids            = module.vpc.public_subnet_ids
  key_name              = aws_key_pair.workshop.key_name
  alb_security_group_id = aws_security_group.alb.id
  instance_count        = 2
}

# ALB Module
module "alb" {
  source = "../../modules/alb"

  project_name        = var.project_name
  environment         = "dev"
  vpc_id              = module.vpc.vpc_id
  subnet_ids          = module.vpc.public_subnet_ids
  target_instance_ids = module.ec2.instance_ids
}

# RDS Module
module "rds" {
  source = "../../modules/rds"

  project_name          = var.project_name
  environment           = "dev"
  vpc_id                = module.vpc.vpc_id
  subnet_ids            = module.vpc.private_subnet_ids
  ec2_security_group_id = module.ec2.security_group_id
  db_password           = var.db_password
}

# =============================================================================
# Additional Variables
# =============================================================================

variable "db_password" {
  description = "RDS master password"
  type        = string
  sensitive   = true
  default     = "Workshop123!"  # 開発環境用。本番では必ず変更
}

# =============================================================================
# Additional Outputs
# =============================================================================

output "alb_dns_name" {
  description = "ALB DNS Name"
  value       = module.alb.alb_dns_name
}

output "ec2_public_ips" {
  description = "EC2 Public IPs"
  value       = module.ec2.public_ips
}

output "rds_endpoint" {
  description = "RDS Endpoint"
  value       = module.rds.endpoint
}
```

---

## 📝 Step 3: Terraformの実行

```bash
cd /projects/IaC-Workshop/terraform/environments/dev

# 初期化
terraform init

# 実行計画
terraform plan

# 適用
terraform apply
```

⚠️ **RDSの作成には10-15分かかります**

---

## 📝 Step 4: Ansibleでのアプリケーションデプロイ

### 4-1. Nginxロールの作成

```bash
mkdir -p /projects/IaC-Workshop/ansible/roles/nginx/{tasks,templates,handlers,defaults}
```

`/projects/IaC-Workshop/ansible/roles/nginx/tasks/main.yml`:

```yaml
---
- name: Install Nginx
  ansible.builtin.dnf:
    name: nginx
    state: present

- name: Create web root directory
  ansible.builtin.file:
    path: /var/www/html
    state: directory
    owner: nginx
    group: nginx
    mode: '0755'

- name: Deploy index.html
  ansible.builtin.template:
    src: index.html.j2
    dest: /var/www/html/index.html
    owner: nginx
    group: nginx
    mode: '0644'
  notify: reload nginx

- name: Configure Nginx
  ansible.builtin.template:
    src: nginx.conf.j2
    dest: /etc/nginx/nginx.conf
    owner: root
    group: root
    mode: '0644'
  notify: reload nginx

- name: Start and enable Nginx
  ansible.builtin.service:
    name: nginx
    state: started
    enabled: true
```

`/projects/IaC-Workshop/ansible/roles/nginx/handlers/main.yml`:

```yaml
---
- name: reload nginx
  ansible.builtin.service:
    name: nginx
    state: reloaded
```

`/projects/IaC-Workshop/ansible/roles/nginx/templates/index.html.j2`:

```html
<!DOCTYPE html>
<html lang="ja">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>IaC Workshop - {{ inventory_hostname }}</title>
    <style>
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            display: flex;
            justify-content: center;
            align-items: center;
            margin: 0;
        }
        .container {
            background: white;
            padding: 40px;
            border-radius: 20px;
            box-shadow: 0 20px 60px rgba(0,0,0,0.3);
            text-align: center;
            max-width: 500px;
        }
        h1 {
            color: #333;
            margin-bottom: 20px;
        }
        .info {
            background: #f8f9fa;
            padding: 20px;
            border-radius: 10px;
            margin: 20px 0;
        }
        .label {
            font-weight: bold;
            color: #667eea;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>🚀 IaC Workshop</h1>
        <p>Webシステム構築実践 - EC2版</p>
        <div class="info">
            <p><span class="label">Hostname:</span> {{ inventory_hostname }}</p>
            <p><span class="label">IP Address:</span> {{ ansible_default_ipv4.address }}</p>
            <p><span class="label">OS:</span> {{ ansible_distribution }} {{ ansible_distribution_version }}</p>
        </div>
        <p>✅ Ansible でデプロイされました</p>
    </div>
</body>
</html>
```

`/projects/IaC-Workshop/ansible/roles/nginx/templates/nginx.conf.j2`:

```nginx
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log;
pid /run/nginx.pid;

events {
    worker_connections 1024;
}

http {
    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for"';

    access_log /var/log/nginx/access.log main;

    sendfile            on;
    tcp_nopush          on;
    tcp_nodelay         on;
    keepalive_timeout   65;
    types_hash_max_size 4096;

    include             /etc/nginx/mime.types;
    default_type        application/octet-stream;

    server {
        listen       80;
        server_name  _;
        root         /var/www/html;

        location / {
            index index.html;
        }

        # Health check endpoint for ALB
        location /health {
            access_log off;
            return 200 "healthy\n";
            add_header Content-Type text/plain;
        }
    }
}
```

### 4-2. インベントリの更新

```bash
cd /projects/IaC-Workshop/terraform/environments/dev

# EC2のIPアドレスを取得
EC2_IPS=$(terraform output -json ec2_public_ips | jq -r '.[]')

# インベントリファイルを生成
cat > /projects/IaC-Workshop/ansible/inventory/hosts.yml << EOF
---
all:
  vars:
    ansible_user: ec2-user
    ansible_ssh_private_key_file: ~/.ssh/id_rsa
    ansible_python_interpreter: auto_silent

  children:
    webservers:
      hosts:
$(echo "$EC2_IPS" | awk '{print "        web" NR ":\n          ansible_host: " $1}')
EOF
```

### 4-3. Playbookの実行

```bash
cd /projects/IaC-Workshop/ansible

# 接続テスト
ansible webservers -m ping -i inventory/hosts.yml

# Nginx デプロイ
ansible-playbook -i inventory/hosts.yml playbooks/site.yml --tags nginx
```

---

## 📝 Step 5: 動作確認

### 5-1. ALB経由でのアクセス

```bash
cd /projects/IaC-Workshop/terraform/environments/dev

# ALBのDNS名を取得
ALB_DNS=$(terraform output -raw alb_dns_name)

# アクセステスト
curl http://$ALB_DNS

# または ブラウザで開く
echo "http://$ALB_DNS"
```

### 5-2. 各EC2への直接アクセス

```bash
# EC2のIPを取得
EC2_IPS=$(terraform output -json ec2_public_ips)
echo $EC2_IPS

# 各サーバーにアクセス（IPを置き換えて実行）
curl http://<EC2_IP_1>
curl http://<EC2_IP_2>
```

リロードするたびに異なるホスト名が表示されることを確認（ALBによる負荷分散）

### 5-3. RDS接続確認

```bash
# EC2にSSH接続
ssh -i ~/.ssh/id_rsa ec2-user@<EC2_IP>

# MySQLクライアントをインストール
sudo dnf install -y mariadb105

# RDSに接続
mysql -h <RDS_ENDPOINT> -u admin -p
# パスワード: Workshop123!

# データベース確認
SHOW DATABASES;
USE workshop;
SHOW TABLES;

# 終了
exit
exit
```

---

## 🧹 クリーンアップ

```bash
cd /projects/IaC-Workshop/terraform/environments/dev
terraform destroy
```

---

## ✅ チェックリスト

- [ ] 2台のEC2インスタンスが起動した
- [ ] ALBが作成され、DNS名でアクセスできる
- [ ] RDSが作成され、EC2から接続できる
- [ ] Nginxがデプロイされ、Webページが表示される
- [ ] ALBによる負荷分散が機能している

---

## 🎯 発展課題

1. **HTTPS対応**: ACMで証明書を取得し、ALBでHTTPS対応
2. **Auto Scaling**: EC2をAuto Scaling Groupに置き換え
3. **バックエンドアプリ**: Python/Flaskアプリをデプロイし、RDSと連携

---

[← 前のハンズオン](./01-vpc-subnet-ec2.md) | [次のハンズオン →](./03-web-system-ecs.md)
