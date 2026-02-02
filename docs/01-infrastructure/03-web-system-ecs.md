# ①-③ Webシステム構築実践（Network、ECS/ECR、DB）

> **区分**: 任意  
> **所要時間**: 約120分  
> **難易度**: ★★★★☆  
> **前提条件**: ①-①を完了していること

---

## 📌 概要

このハンズオンでは、コンテナベースのWebシステムをAWS ECS（Fargate）とECRを使って構築します。

### 学習目標

- コンテナイメージのビルドとECRへのプッシュ
- ECS Fargateでのコンテナ実行
- サービスディスカバリとロードバランシング
- RDSとの連携

### 構築するアーキテクチャ

```
                        インターネット
                             │
                    ┌────────┴────────┐
                    │       ALB       │
                    └────────┬────────┘
                             │
┌──────────────────────────────────────────────────────────────┐
│                        ECS Cluster                           │
│  ┌─────────────────────┐    ┌─────────────────────────────┐ │
│  │   ECS Service       │    │   ECS Service               │ │
│  │  ┌──────────────┐   │    │  ┌──────────────┐           │ │
│  │  │ Fargate Task │   │    │  │ Fargate Task │           │ │
│  │  │  (Web App)   │   │    │  │  (Web App)   │           │ │
│  │  └──────────────┘   │    │  └──────────────┘           │ │
│  └─────────────────────┘    └─────────────────────────────┘ │
└──────────────────────────────────────────────────────────────┘
                             │
                    ┌────────┴────────┐
                    │      RDS        │
                    │    (MySQL)      │
                    └─────────────────┘

          ┌─────────────────┐
          │      ECR        │
          │ (Container Reg) │
          └─────────────────┘
```

---

## 🔧 事前準備

### Dockerの確認

Dev Spaces環境でDockerが利用可能か確認：

```bash
# Dockerバージョン確認
docker --version

# または Podman（Dev Spacesでは通常こちら）
podman --version
```

### AWS認証の確認

```bash
aws sts get-caller-identity
```

---

## 📝 Step 1: サンプルアプリケーションの作成

### 1-1. アプリケーションディレクトリの作成

```bash
mkdir -p /projects/IaC-Workshop/app
cd /projects/IaC-Workshop/app
```

### 1-2. Pythonアプリケーション

`/projects/IaC-Workshop/app/app.py`:

```python
from flask import Flask, jsonify
import os
import socket
import mysql.connector
from mysql.connector import Error

app = Flask(__name__)

# 環境変数から設定を取得
DB_HOST = os.environ.get('DB_HOST', 'localhost')
DB_USER = os.environ.get('DB_USER', 'admin')
DB_PASSWORD = os.environ.get('DB_PASSWORD', '')
DB_NAME = os.environ.get('DB_NAME', 'workshop')

@app.route('/')
def index():
    return f'''
    <!DOCTYPE html>
    <html lang="ja">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>IaC Workshop - ECS</title>
        <style>
            body {{
                font-family: 'Segoe UI', sans-serif;
                background: linear-gradient(135deg, #11998e 0%, #38ef7d 100%);
                min-height: 100vh;
                display: flex;
                justify-content: center;
                align-items: center;
                margin: 0;
            }}
            .container {{
                background: white;
                padding: 40px;
                border-radius: 20px;
                box-shadow: 0 20px 60px rgba(0,0,0,0.3);
                text-align: center;
            }}
            .info {{ background: #f0f0f0; padding: 15px; border-radius: 10px; margin: 15px 0; }}
            .label {{ font-weight: bold; color: #11998e; }}
        </style>
    </head>
    <body>
        <div class="container">
            <h1>🐳 IaC Workshop - ECS Edition</h1>
            <div class="info">
                <p><span class="label">Container ID:</span> {socket.gethostname()}</p>
                <p><span class="label">Python Version:</span> {os.sys.version.split()[0]}</p>
            </div>
            <p>✅ ECS Fargateで実行中</p>
        </div>
    </body>
    </html>
    '''

@app.route('/health')
def health():
    return jsonify({"status": "healthy", "container": socket.gethostname()})

@app.route('/db-check')
def db_check():
    try:
        connection = mysql.connector.connect(
            host=DB_HOST,
            user=DB_USER,
            password=DB_PASSWORD,
            database=DB_NAME
        )
        if connection.is_connected():
            db_info = connection.get_server_info()
            connection.close()
            return jsonify({
                "status": "connected",
                "mysql_version": db_info,
                "container": socket.gethostname()
            })
    except Error as e:
        return jsonify({"status": "error", "message": str(e)}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080)
```

### 1-3. 依存関係ファイル

`/projects/IaC-Workshop/app/requirements.txt`:

```
Flask==3.0.0
mysql-connector-python==8.2.0
gunicorn==21.2.0
```

### 1-4. Dockerfile

`/projects/IaC-Workshop/app/Dockerfile`:

```dockerfile
FROM python:3.11-slim

WORKDIR /app

# 依存関係のインストール
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# アプリケーションのコピー
COPY app.py .

# 非rootユーザーで実行
RUN useradd -m appuser
USER appuser

EXPOSE 8080

CMD ["gunicorn", "-b", "0.0.0.0:8080", "app:app"]
```

### 1-5. ローカルでのビルドとテスト

```bash
cd /projects/IaC-Workshop/app

# イメージのビルド（Podmanを使用）
podman build -t workshop-app:latest .

# ローカル実行テスト
podman run -d -p 8080:8080 --name test-app workshop-app:latest

# 動作確認
curl http://localhost:8080

# クリーンアップ
podman stop test-app && podman rm test-app
```

---

## 📝 Step 2: ECRリポジトリの作成

### 2-1. Terraformモジュールの作成

```bash
mkdir -p /projects/IaC-Workshop/terraform/modules/ecr
```

`/projects/IaC-Workshop/terraform/modules/ecr/main.tf`:

```hcl
# =============================================================================
# ECR Module - Container Registry
# =============================================================================

variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

# -----------------------------------------------------------------------------
# ECR Repository
# -----------------------------------------------------------------------------

resource "aws_ecr_repository" "main" {
  name                 = "${var.project_name}-${var.environment}"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    Name = "${var.project_name}-${var.environment}"
  }
}

# -----------------------------------------------------------------------------
# Lifecycle Policy
# -----------------------------------------------------------------------------

resource "aws_ecr_lifecycle_policy" "main" {
  repository = aws_ecr_repository.main.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 10 images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 10
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# Outputs
# -----------------------------------------------------------------------------

output "repository_url" {
  value = aws_ecr_repository.main.repository_url
}

output "repository_arn" {
  value = aws_ecr_repository.main.arn
}

output "registry_id" {
  value = aws_ecr_repository.main.registry_id
}
```

---

## 📝 Step 3: ECSモジュールの作成

```bash
mkdir -p /projects/IaC-Workshop/terraform/modules/ecs
```

`/projects/IaC-Workshop/terraform/modules/ecs/main.tf`:

```hcl
# =============================================================================
# ECS Module - Fargate Cluster
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

variable "alb_target_group_arn" {
  type = string
}

variable "alb_security_group_id" {
  type = string
}

variable "ecr_repository_url" {
  type = string
}

variable "container_port" {
  type    = number
  default = 8080
}

variable "cpu" {
  type    = number
  default = 256
}

variable "memory" {
  type    = number
  default = 512
}

variable "desired_count" {
  type    = number
  default = 2
}

variable "db_host" {
  type    = string
  default = ""
}

variable "db_user" {
  type    = string
  default = "admin"
}

variable "db_password" {
  type      = string
  sensitive = true
  default   = ""
}

variable "db_name" {
  type    = string
  default = "workshop"
}

# -----------------------------------------------------------------------------
# ECS Cluster
# -----------------------------------------------------------------------------

resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-${var.environment}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-cluster"
  }
}

# -----------------------------------------------------------------------------
# Security Group
# -----------------------------------------------------------------------------

resource "aws_security_group" "ecs" {
  name        = "${var.project_name}-${var.environment}-ecs-sg"
  description = "Security group for ECS tasks"
  vpc_id      = var.vpc_id

  ingress {
    description     = "From ALB"
    from_port       = var.container_port
    to_port         = var.container_port
    protocol        = "tcp"
    security_groups = [var.alb_security_group_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-ecs-sg"
  }
}

# -----------------------------------------------------------------------------
# IAM Role for ECS Task Execution
# -----------------------------------------------------------------------------

resource "aws_iam_role" "ecs_task_execution" {
  name = "${var.project_name}-${var.environment}-ecs-task-execution"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# -----------------------------------------------------------------------------
# CloudWatch Log Group
# -----------------------------------------------------------------------------

resource "aws_cloudwatch_log_group" "main" {
  name              = "/ecs/${var.project_name}-${var.environment}"
  retention_in_days = 7

  tags = {
    Name = "${var.project_name}-${var.environment}"
  }
}

# -----------------------------------------------------------------------------
# ECS Task Definition
# -----------------------------------------------------------------------------

resource "aws_ecs_task_definition" "main" {
  family                   = "${var.project_name}-${var.environment}"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn

  container_definitions = jsonencode([
    {
      name  = "app"
      image = "${var.ecr_repository_url}:latest"
      
      portMappings = [
        {
          containerPort = var.container_port
          protocol      = "tcp"
        }
      ]

      environment = [
        { name = "DB_HOST", value = var.db_host },
        { name = "DB_USER", value = var.db_user },
        { name = "DB_PASSWORD", value = var.db_password },
        { name = "DB_NAME", value = var.db_name }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.main.name
          "awslogs-region"        = data.aws_region.current.name
          "awslogs-stream-prefix" = "ecs"
        }
      }

      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:${var.container_port}/health || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }
    }
  ])

  tags = {
    Name = "${var.project_name}-${var.environment}"
  }
}

data "aws_region" "current" {}

# -----------------------------------------------------------------------------
# ECS Service
# -----------------------------------------------------------------------------

resource "aws_ecs_service" "main" {
  name            = "${var.project_name}-${var.environment}-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.main.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = [aws_security_group.ecs.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = var.alb_target_group_arn
    container_name   = "app"
    container_port   = var.container_port
  }

  lifecycle {
    ignore_changes = [task_definition]
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-service"
  }
}

# -----------------------------------------------------------------------------
# Outputs
# -----------------------------------------------------------------------------

output "cluster_id" {
  value = aws_ecs_cluster.main.id
}

output "cluster_name" {
  value = aws_ecs_cluster.main.name
}

output "service_name" {
  value = aws_ecs_service.main.name
}

output "security_group_id" {
  value = aws_security_group.ecs.id
}
```

---

## 📝 Step 4: ALBモジュールの更新（ECS用）

`/projects/IaC-Workshop/terraform/modules/alb-ecs/main.tf`:

```bash
mkdir -p /projects/IaC-Workshop/terraform/modules/alb-ecs
```

```hcl
# =============================================================================
# ALB Module for ECS - Application Load Balancer
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

variable "container_port" {
  type    = number
  default = 8080
}

# -----------------------------------------------------------------------------
# Security Group
# -----------------------------------------------------------------------------

resource "aws_security_group" "alb" {
  name        = "${var.project_name}-${var.environment}-alb-sg"
  description = "Security group for ALB"
  vpc_id      = var.vpc_id

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
    Name = "${var.project_name}-${var.environment}-alb-sg"
  }
}

# -----------------------------------------------------------------------------
# ALB
# -----------------------------------------------------------------------------

resource "aws_lb" "main" {
  name               = "${var.project_name}-${var.environment}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.subnet_ids

  tags = {
    Name = "${var.project_name}-${var.environment}-alb"
  }
}

# -----------------------------------------------------------------------------
# Target Group
# -----------------------------------------------------------------------------

resource "aws_lb_target_group" "main" {
  name        = "${var.project_name}-${var.environment}-tg"
  port        = var.container_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = "/health"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 3
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-tg"
  }
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

output "target_group_arn" {
  value = aws_lb_target_group.main.arn
}

output "security_group_id" {
  value = aws_security_group.alb.id
}
```

---

## 📝 Step 5: ECS環境用のTerraform設定

```bash
mkdir -p /projects/IaC-Workshop/terraform/environments/dev-ecs
```

`/projects/IaC-Workshop/terraform/environments/dev-ecs/main.tf`:

```hcl
# =============================================================================
# ECS Web System - Development Environment
# =============================================================================

terraform {
  required_version = ">= 1.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment = "dev-ecs"
      Project     = "iac-workshop"
      ManagedBy   = "terraform"
    }
  }
}

# -----------------------------------------------------------------------------
# Variables
# -----------------------------------------------------------------------------

variable "aws_region" {
  type    = string
  default = "ap-northeast-1"
}

variable "project_name" {
  type    = string
  default = "iac-workshop"
}

variable "db_password" {
  type      = string
  sensitive = true
  default   = "Workshop123!"
}

# -----------------------------------------------------------------------------
# VPC
# -----------------------------------------------------------------------------

module "vpc" {
  source = "../../modules/vpc"

  project_name = var.project_name
  environment  = "dev-ecs"
  vpc_cidr     = "10.1.0.0/16"
}

# -----------------------------------------------------------------------------
# ECR
# -----------------------------------------------------------------------------

module "ecr" {
  source = "../../modules/ecr"

  project_name = var.project_name
  environment  = "dev"
}

# -----------------------------------------------------------------------------
# ALB
# -----------------------------------------------------------------------------

module "alb" {
  source = "../../modules/alb-ecs"

  project_name   = var.project_name
  environment    = "dev-ecs"
  vpc_id         = module.vpc.vpc_id
  subnet_ids     = module.vpc.public_subnet_ids
  container_port = 8080
}

# -----------------------------------------------------------------------------
# RDS
# -----------------------------------------------------------------------------

module "rds" {
  source = "../../modules/rds"

  project_name          = var.project_name
  environment           = "dev-ecs"
  vpc_id                = module.vpc.vpc_id
  subnet_ids            = module.vpc.private_subnet_ids
  ec2_security_group_id = module.ecs.security_group_id
  db_password           = var.db_password
}

# -----------------------------------------------------------------------------
# ECS
# -----------------------------------------------------------------------------

module "ecs" {
  source = "../../modules/ecs"

  project_name          = var.project_name
  environment           = "dev-ecs"
  vpc_id                = module.vpc.vpc_id
  subnet_ids            = module.vpc.public_subnet_ids
  alb_target_group_arn  = module.alb.target_group_arn
  alb_security_group_id = module.alb.security_group_id
  ecr_repository_url    = module.ecr.repository_url
  container_port        = 8080
  desired_count         = 2

  db_host     = module.rds.address
  db_user     = "admin"
  db_password = var.db_password
  db_name     = "workshop"
}

# -----------------------------------------------------------------------------
# Outputs
# -----------------------------------------------------------------------------

output "ecr_repository_url" {
  value = module.ecr.repository_url
}

output "alb_dns_name" {
  value = module.alb.alb_dns_name
}

output "ecs_cluster_name" {
  value = module.ecs.cluster_name
}

output "ecs_service_name" {
  value = module.ecs.service_name
}

output "rds_endpoint" {
  value = module.rds.endpoint
}
```

---

## 📝 Step 6: インフラのデプロイ

```bash
cd /projects/IaC-Workshop/terraform/environments/dev-ecs

# 初期化
terraform init

# 実行計画
terraform plan

# 適用
terraform apply
```

---

## 📝 Step 7: コンテナイメージのプッシュ

```bash
cd /projects/IaC-Workshop/app

# ECRログイン
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION="ap-northeast-1"

aws ecr get-login-password --region $AWS_REGION | \
  podman login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com

# ECRリポジトリURLを取得
ECR_URL=$(cd ../terraform/environments/dev-ecs && terraform output -raw ecr_repository_url)

# イメージのビルド
podman build -t $ECR_URL:latest .

# イメージのプッシュ
podman push $ECR_URL:latest
```

---

## 📝 Step 8: ECSサービスの更新

```bash
cd /projects/IaC-Workshop/terraform/environments/dev-ecs

# クラスター名とサービス名を取得
CLUSTER_NAME=$(terraform output -raw ecs_cluster_name)
SERVICE_NAME=$(terraform output -raw ecs_service_name)

# サービスを強制的に新しいデプロイに更新
aws ecs update-service \
  --cluster $CLUSTER_NAME \
  --service $SERVICE_NAME \
  --force-new-deployment

# デプロイ状況の確認
aws ecs describe-services \
  --cluster $CLUSTER_NAME \
  --services $SERVICE_NAME \
  --query 'services[0].deployments'
```

---

## 📝 Step 9: 動作確認

### 9-1. ALB経由でのアクセス

```bash
ALB_DNS=$(terraform output -raw alb_dns_name)
curl http://$ALB_DNS
```

ブラウザでも確認：
```bash
echo "http://$ALB_DNS"
```

### 9-2. ヘルスチェック

```bash
curl http://$ALB_DNS/health
```

### 9-3. DB接続確認

```bash
curl http://$ALB_DNS/db-check
```

### 9-4. CloudWatch Logsの確認

```bash
# 最新のログを確認
aws logs tail /ecs/iac-workshop-dev-ecs --follow
```

---

## 📝 Step 10: スケーリング

### 手動スケーリング

```bash
# タスク数を3に増加
aws ecs update-service \
  --cluster $CLUSTER_NAME \
  --service $SERVICE_NAME \
  --desired-count 3

# タスク数を1に縮小
aws ecs update-service \
  --cluster $CLUSTER_NAME \
  --service $SERVICE_NAME \
  --desired-count 1
```

---

## 🧹 クリーンアップ

```bash
cd /projects/IaC-Workshop/terraform/environments/dev-ecs

# ECRのイメージを削除（必要に応じて）
aws ecr batch-delete-image \
  --repository-name iac-workshop-dev \
  --image-ids imageTag=latest

# インフラを削除
terraform destroy
```

---

## ✅ チェックリスト

- [ ] ECRリポジトリが作成された
- [ ] コンテナイメージがプッシュされた
- [ ] ECSクラスターが作成された
- [ ] ECSサービスが正常に実行されている
- [ ] ALB経由でアプリケーションにアクセスできる
- [ ] RDSとの接続が確認できた

---

## 🎯 発展課題

1. **CI/CD**: GitHub ActionsでECRへの自動プッシュとECSデプロイ
2. **Auto Scaling**: Application Auto Scalingでタスク数を自動調整
3. **Blue/Green Deploy**: CodeDeployを使用したブルーグリーンデプロイメント
4. **Service Mesh**: AWS App Meshでサービス間通信を管理

---

## 📚 参考リンク

- [Amazon ECS ドキュメント](https://docs.aws.amazon.com/ja_jp/ecs/)
- [AWS Fargate ドキュメント](https://docs.aws.amazon.com/ja_jp/AmazonECS/latest/userguide/what-is-fargate.html)
- [Amazon ECR ドキュメント](https://docs.aws.amazon.com/ja_jp/ecr/)

---

[← 前のハンズオン](./02-web-system-ec2.md) | [運用ハンズオンへ →](../02-operations/01-server-reboot.md)
