# IaC × AI Workshop 🤖

**AIアシスタントを活用したInfrastructure as Code（IaC）実践ワークショップ**

---

## 🎯 本ワークショップの目的

このワークショップでは、**AIアシスタント（Cursor / Continue）を使ってIaCコードを効率的に生成・管理する方法**を学びます。

### ⚠️ 注意：これはAWS学習ではありません

- ❌ AWSサービスの詳細を学ぶワークショップではない
- ✅ **Terraform / Ansible のコード生成をAIで効率化**する方法を学ぶ
- ✅ **効果的なプロンプトの書き方**を習得する
- ✅ **IaCのベストプラクティス**をAIと一緒に実践する

---

## 🧠 学ぶこと

### 1. AIへの効果的なプロンプト作成

```
悪い例：「VPCを作って」
良い例：「以下の条件でTerraformのaws_vpcリソースを作成してください：
        - CIDR: 10.0.0.0/16
        - DNS有効化
        - タグ: Name = my-vpc」
```

### 2. IaCコードの構造化

- Terraformモジュールの設計
- Ansibleロールの作成
- 変数・出力の適切な定義

### 3. AI生成コードのレビュー

- 生成されたコードの妥当性確認
- セキュリティ観点でのチェック
- ベストプラクティスとの照合

---

## 📋 前提条件

- Red Hat Developer Suite (Dev Spaces) へのアクセス
- AWSアカウント（リソース作成用）
- 基本的なLinuxコマンドの知識
- **TerraformやAnsibleの事前知識は不要**（AIと一緒に学びます）

---

## 🚀 環境セットアップ

### ⚠️ 最初に必ず実施

👉 **[参加者セットアップガイド](./00-setup/participant-setup.md)**

複数の参加者が同じAWSアカウントを使用するため、参加者IDを設定します。

---

## 📚 ハンズオン一覧

### 0. セットアップ（必須）

| No. | タイトル | 説明 |
|-----|---------|------|
| 0-1 | [参加者セットアップ](./00-setup/participant-setup.md) | 参加者ID設定、環境準備 |

### ① Terraform × AI（システム構築）

| No. | タイトル | 区分 | 所要時間 | 学習内容 |
|-----|---------|------|----------|----------|
| ①-① | [VPC/EC2構築](./01-infrastructure/01-vpc-subnet-ec2.md) | **必須** | 60分 | AIでTerraformコードを生成する基本 |
| ①-② | [Webシステム（EC2版）](./01-infrastructure/02-web-system-ec2.md) | 任意 | 90分 | 複数リソースの構成をAIに依頼 |
| ①-③ | [Webシステム（ECS版）](./01-infrastructure/03-web-system-ecs.md) | 任意 | 120分 | コンテナ構成のIaCをAIで生成 |

### ② Ansible × AI（システム運用）

| No. | タイトル | 区分 | 所要時間 | 学習内容 |
|-----|---------|------|----------|----------|
| ②-① | [サーバー再起動](./02-operations/01-server-reboot.md) | **必須** | 30分 | AIでAnsible Playbookを生成する基本 |
| ②-② | [Agentインストール](./02-operations/02-agent-install.md) | 任意 | 45分 | Ansibleロールの設計をAIに依頼 |
| ②-③ | [サーバー情報取得](./02-operations/03-server-info.md) | 任意 | 30分 | 情報収集・レポート生成のIaC |

---

## 💡 ワークショップの進め方

### Step 1: 課題と条件を読む

各課題には「何を作るか」と「条件」が明記されています。

### Step 2: 自分でプロンプトを考える

条件を元に、AIへのプロンプトを自分で考えてみましょう。

### Step 3: AIにコード生成を依頼

考えたプロンプトをAIに入力し、コードを生成させます。

### Step 4: 正解例と比較

- **プロンプトの書き方**は適切だったか？
- **生成されたコード**は正解例と比べてどうか？
- より良いプロンプトの書き方はあるか？

---

## 🔑 効果的なプロンプトのコツ

### 1. 具体的な条件を明記する

```
❌ 「Security Groupを作って」
✅ 「以下の条件でaws_security_groupリソースを作成：
    - 名前: web-sg
    - SSH(22)とHTTP(80)を許可
    - VPC ID: module.vpc.vpc_id」
```

### 2. 出力形式を指定する

```
❌ 「EC2の情報を取得するPlaybookを作って」
✅ 「EC2の情報を取得するAnsible Playbookを作成：
    - ファイル名: gather-info.yml
    - 対象: webservers
    - 取得項目: hostname, IP, OS, memory
    - 出力形式: 整形されたdebugメッセージ」
```

### 3. 既存の変数・リソースを伝える

```
✅ 「既存の変数:
    - var.project_name
    - var.participant_id
    - local.name_prefix
    これらを使ってリソース名を構成してください」
```

---

## 🗂️ プロジェクト構成

```
IaC-Workshop/
├── docs/                          # ハンズオンドキュメント
├── terraform/                     # Terraformコード
│   ├── environments/dev/          # 実行環境
│   └── modules/                   # 再利用モジュール
├── ansible/                       # Ansibleコード
│   ├── inventory/                 # インベントリ
│   ├── playbooks/                 # Playbook
│   └── roles/                     # ロール
└── devfile.yaml                   # Dev Spaces設定
```

---

## ⚠️ 注意事項

1. **コスト**: AWSリソースは課金されます。終了後は `terraform destroy` で削除
2. **セキュリティ**: 認証情報はコミットしない
3. **AI生成コード**: 必ず内容を確認してから実行する

---

## 📞 サポート

問題が発生した場合は、講師またはファシリテーターにお声がけください。
