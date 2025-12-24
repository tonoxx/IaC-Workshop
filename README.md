# 🤖 AI駆動 Infrastructure as Code ワークショップ

> AWS CLI、Ansible、Terraform、そしてContinue AIを活用した次世代IaC開発を学ぶ

## 📋 概要

このワークショップでは、AIアシスタント（Continue）を活用しながら、モダンなInfrastructure as Code（IaC）開発手法を実践的に学びます。

### 学習内容

| ツール | 用途 |
|--------|------|
| **AWS CLI** | AWSリソースの操作・管理 |
| **Terraform** | インフラストラクチャのプロビジョニング |
| **Ansible** | 構成管理・アプリケーションデプロイ |
| **Continue** | AIによるコード生成・レビュー支援 |

## 🚀 環境セットアップ

### 前提条件

- GitHub アカウント
- AWS アカウント（アクセスキー/シークレットキー）
- VS Code または Cursor エディタ

### DevSpaces/Codespaces での起動

1. **GitHub Codespaces を使用する場合**
   
   [![Open in GitHub Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new)
   
   リポジトリページで「Code」→「Codespaces」→「Create codespace on main」をクリック

2. **ローカル Dev Container を使用する場合**
   
   ```bash
   # リポジトリをクローン
   git clone https://github.com/YOUR_USERNAME/IaC-Workshop.git
   cd IaC-Workshop
   
   # VS Code で開く
   code .
   ```
   
   VS Code で「Reopen in Container」を選択

### AWS 認証設定

環境起動後、AWS CLI の設定を行います：

```bash
aws configure
```

| 項目 | 説明 |
|------|------|
| AWS Access Key ID | IAMユーザーのアクセスキー |
| AWS Secret Access Key | IAMユーザーのシークレットキー |
| Default region name | `ap-northeast-1`（東京リージョン推奨） |
| Default output format | `json` |

## 📁 ディレクトリ構成

```
IaC-Workshop/
├── .devcontainer/          # DevSpaces 環境設定
│   ├── devcontainer.json   # コンテナ設定
│   ├── Dockerfile          # カスタムイメージ
│   └── post-create.sh      # セットアップスクリプト
├── terraform/              # Terraform コード
│   ├── modules/            # 再利用可能なモジュール
│   └── environments/       # 環境別設定
│       ├── dev/
│       ├── staging/
│       └── prod/
├── ansible/                # Ansible コード
│   ├── playbooks/          # Playbook
│   ├── roles/              # ロール
│   ├── inventory/          # インベントリ
│   ├── group_vars/         # グループ変数
│   └── host_vars/          # ホスト変数
└── README.md
```

## 🎯 ワークショップ内容

### Module 1: 環境確認と基礎（30分）

```bash
# ツールバージョン確認
aws --version
terraform version
ansible --version

# AWS 接続テスト
aws sts get-caller-identity
```

### Module 2: Continue AI の活用（20分）

**Continue の起動方法**
- ショートカット: `Cmd/Ctrl + L`
- サイドバーの Continue アイコンをクリック

**AI への質問例**
```
「VPC、パブリック/プライベートサブネット、NAT Gatewayを含む
AWS ネットワーク構成の Terraform コードを生成してください」
```

### Module 3: Terraform 実践（60分）

1. **VPCの作成**
   ```hcl
   # terraform/environments/dev/main.tf
   module "vpc" {
     source = "../../modules/vpc"
     # ...
   }
   ```

2. **リソースのデプロイ**
   ```bash
   cd terraform/environments/dev
   terraform init
   terraform plan
   terraform apply
   ```

### Module 4: Ansible 実践（60分）

1. **Playbook の作成**
   ```yaml
   # ansible/playbooks/setup-web-server.yml
   - hosts: webservers
     become: yes
     roles:
       - common
       - nginx
   ```

2. **Playbook の実行**
   ```bash
   cd ansible
   ansible-playbook playbooks/setup-web-server.yml
   ```

### Module 5: IaC セキュリティ（30分）

```bash
# Terraform セキュリティスキャン
checkov -d terraform/

# Terraform リンティング
tflint terraform/

# Ansible リンティング
ansible-lint ansible/playbooks/
```

## 🛠️ インストール済みツール

| ツール | 用途 |
|--------|------|
| AWS CLI v2 | AWS リソース管理 |
| Terraform | インフラプロビジョニング |
| tfsec | Terraform セキュリティスキャン |
| terraform-docs | ドキュメント自動生成 |
| TFLint | Terraform リンター |
| Ansible | 構成管理 |
| ansible-lint | Ansible リンター |
| Checkov | IaC セキュリティスキャナ |
| pre-commit | コミット前チェック |

## 🔧 VS Code 拡張機能

環境には以下の拡張機能がプリインストールされています：

- **HashiCorp Terraform** - Terraform 言語サポート
- **Ansible** - Ansible 言語サポート
- **AWS Toolkit** - AWS サービス統合
- **Continue** - AI コーディングアシスタント
- **Python** - Python 言語サポート
- **YAML** - YAML 言語サポート

## 💡 AI駆動開発のベストプラクティス

### Continue AI の効果的な使い方

1. **コード生成**
   ```
   「S3バケットをプライベートで作成し、バージョニングと
   暗号化を有効にする Terraform コードを書いてください」
   ```

2. **コードレビュー**
   ```
   「このTerraformコードのセキュリティ上の問題点を
   指摘してください」
   ```

3. **トラブルシューティング**
   ```
   「このエラーメッセージの原因と解決方法を教えてください：
   [エラーメッセージを貼り付け]」
   ```

4. **ベストプラクティス**
   ```
   「このAnsible Playbookをより冪等性が高く、
   再利用可能な形にリファクタリングしてください」
   ```

## ⚠️ 注意事項

- ワークショップ終了後は作成したAWSリソースを削除してください
  ```bash
  terraform destroy
  ```
- AWS認証情報は安全に管理してください
- 本番環境への適用前に十分なテストを行ってください

## 📚 参考リンク

- [Terraform Documentation](https://developer.hashicorp.com/terraform/docs)
- [Ansible Documentation](https://docs.ansible.com/)
- [AWS CLI Documentation](https://docs.aws.amazon.com/cli/)
- [Continue Documentation](https://continue.dev/docs)

## 📝 ライセンス

MIT License

---

**Happy IaC Coding! 🎉**

