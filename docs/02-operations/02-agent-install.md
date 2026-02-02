# ②-② Agentインストールセットアップ

> **区分**: 任意  
> **所要時間**: 約45分  
> **難易度**: ★★★☆☆  
> **前提条件**: ①-①で構築したEC2が稼働していること、[参加者セットアップ](../00-setup/participant-setup.md)完了

---

## 📌 概要

このハンズオンでは、AIアシスタントを活用して監視・管理エージェントをインストールするAnsibleロールを作成します。

### 学習目標

- AIを活用したAnsibleロール生成
- CloudWatch Agentの設定とデプロイ
- SSM Agentの確認と設定
- 再利用可能なロール設計

### インストールするエージェント

| エージェント | 用途 |
|-------------|------|
| CloudWatch Agent | メトリクス・ログ収集 |
| SSM Agent | リモート管理 |
| Node Exporter | Prometheus用メトリクス（オプション）|

---

## 🔧 事前準備

```bash
cd /projects/IaC-Workshop/ansible
ansible webservers -m ping -i inventory/${PARTICIPANT_ID}/hosts.yml
```

---

## 📝 課題1: CloudWatch Agentロールの作成

### 課題内容

AIを使って、CloudWatch Agentをインストール・設定するAnsibleロールを生成してください。

### 要件

1. ロールディレクトリ構造: `roles/cloudwatch_agent/{tasks,templates,handlers,defaults}`
2. 変数でメトリクス収集間隔を設定可能
3. CPU、メモリ、ディスクのメトリクスを収集
4. 設定変更時にエージェントを再起動

### 🤖 AIへのプロンプト例

```
CloudWatch Agentをインストール・設定するAnsibleロールを作成してください。

ディレクトリ構造:
roles/cloudwatch_agent/
├── defaults/main.yml    # デフォルト変数
├── tasks/main.yml       # タスク
├── handlers/main.yml    # ハンドラー
└── templates/amazon-cloudwatch-agent.json.j2  # 設定テンプレート

要件:
1. エージェントのRPMをダウンロードしてインストール
2. Jinja2テンプレートで設定ファイルを生成
3. 収集するメトリクス: CPU, Memory, Disk, Network
4. 設定変更時は amazon-cloudwatch-agent-ctl で再読み込み
5. サービスを有効化して起動
```

<details>
<summary>📖 正解例（クリックで展開）</summary>

### ディレクトリ作成

```bash
mkdir -p /projects/IaC-Workshop/ansible/roles/cloudwatch_agent/{tasks,templates,handlers,defaults}
```

### defaults/main.yml

```yaml
---
cloudwatch_agent_url: "https://s3.amazonaws.com/amazoncloudwatch-agent/amazon_linux/amd64/latest/amazon-cloudwatch-agent.rpm"
cloudwatch_agent_config_path: "/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json"
metrics_collection_interval: 60
collect_logs: true
log_group_prefix: "/ec2"
```

### tasks/main.yml

```yaml
---
- name: Check if CloudWatch Agent is installed
  ansible.builtin.stat:
    path: /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl
  register: agent_installed

- name: Download CloudWatch Agent
  ansible.builtin.get_url:
    url: "{{ cloudwatch_agent_url }}"
    dest: /tmp/amazon-cloudwatch-agent.rpm
    mode: '0644'
  when: not agent_installed.stat.exists

- name: Install CloudWatch Agent
  ansible.builtin.dnf:
    name: /tmp/amazon-cloudwatch-agent.rpm
    state: present
    disable_gpg_check: true
  when: not agent_installed.stat.exists

- name: Create CloudWatch Agent configuration
  ansible.builtin.template:
    src: amazon-cloudwatch-agent.json.j2
    dest: "{{ cloudwatch_agent_config_path }}"
    mode: '0644'
  notify: restart cloudwatch agent

- name: Configure CloudWatch Agent
  ansible.builtin.command:
    cmd: >
      /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl
      -a fetch-config -m ec2 -s
      -c file:{{ cloudwatch_agent_config_path }}
  register: agent_config_result
  changed_when: "'Configuration has been updated' in agent_config_result.stdout"

- name: Ensure CloudWatch Agent is running
  ansible.builtin.service:
    name: amazon-cloudwatch-agent
    state: started
    enabled: true

- name: Verify agent status
  ansible.builtin.command:
    cmd: /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -m ec2 -a status
  register: agent_status
  changed_when: false

- name: Display agent status
  ansible.builtin.debug:
    msg: "{{ agent_status.stdout }}"
```

### handlers/main.yml

```yaml
---
- name: restart cloudwatch agent
  ansible.builtin.command:
    cmd: >
      /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl
      -a fetch-config -m ec2 -s
      -c file:{{ cloudwatch_agent_config_path }}
```

### templates/amazon-cloudwatch-agent.json.j2

```json
{
  "agent": {
    "metrics_collection_interval": {{ metrics_collection_interval }},
    "run_as_user": "root"
  },
  "metrics": {
    "namespace": "CWAgent",
    "metrics_collected": {
      "cpu": {
        "measurement": ["cpu_usage_idle", "cpu_usage_user", "cpu_usage_system"],
        "totalcpu": true
      },
      "disk": {
        "measurement": ["used_percent", "inodes_free"],
        "resources": ["/"]
      },
      "mem": {
        "measurement": ["mem_used_percent", "mem_available", "mem_total"]
      },
      "net": {
        "measurement": ["bytes_sent", "bytes_recv"],
        "resources": ["*"]
      }
    },
    "append_dimensions": {
      "InstanceId": "${aws:InstanceId}"
    }
  }
}
```

</details>

---

## 📝 課題2: SSM Agentロールの作成

### 課題内容

SSM Agentの状態を確認・設定するロールを作成してください。

### 🤖 AIへのプロンプト例

```
SSM Agentの確認と設定を行うAnsibleロールを作成してください。

要件:
1. SSM Agentがインストールされているか確認
2. インストールされていない場合はインストール
3. サービスが起動していることを確認
4. バージョンとステータスを表示
5. ロール名: ssm_agent
```

<details>
<summary>📖 正解例（クリックで展開）</summary>

### ディレクトリ作成

```bash
mkdir -p /projects/IaC-Workshop/ansible/roles/ssm_agent/{tasks,defaults}
```

### defaults/main.yml

```yaml
---
ssm_ensure_running: true
ssm_agent_url: "https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/linux_amd64/amazon-ssm-agent.rpm"
```

### tasks/main.yml

```yaml
---
- name: Check if SSM Agent is installed
  ansible.builtin.command:
    cmd: rpm -q amazon-ssm-agent
  register: ssm_installed
  failed_when: false
  changed_when: false

- name: Install SSM Agent if not present
  ansible.builtin.dnf:
    name: "{{ ssm_agent_url }}"
    state: present
    disable_gpg_check: true
  when: ssm_installed.rc != 0

- name: Get SSM Agent version
  ansible.builtin.command:
    cmd: amazon-ssm-agent --version
  register: ssm_version
  changed_when: false
  failed_when: false

- name: Display SSM Agent version
  ansible.builtin.debug:
    msg: "SSM Agent version: {{ ssm_version.stdout | default('Unknown') }}"

- name: Ensure SSM Agent is running
  ansible.builtin.service:
    name: amazon-ssm-agent
    state: started
    enabled: true
  when: ssm_ensure_running

- name: Check SSM Agent status
  ansible.builtin.command:
    cmd: systemctl status amazon-ssm-agent --no-pager
  register: ssm_status
  changed_when: false
  failed_when: false

- name: Display SSM status summary
  ansible.builtin.debug:
    msg: "SSM Agent: {{ 'Running' if 'active (running)' in ssm_status.stdout else 'Not Running' }}"
```

</details>

---

## 📝 課題3: Node Exporterロールの作成（オプション）

### 課題内容

Prometheus用のNode Exporterをインストールするロールを作成してください。

### 🤖 AIへのプロンプト例

```
Prometheus Node ExporterをインストールするAnsibleロールを作成してください。

要件:
1. バージョン: 1.7.0
2. 専用ユーザー node_exporter を作成
3. systemdサービスとして登録
4. ポート9100でメトリクスを公開
5. ヘルスチェックで動作確認
```

<details>
<summary>📖 正解例（クリックで展開）</summary>

### ディレクトリ作成

```bash
mkdir -p /projects/IaC-Workshop/ansible/roles/node_exporter/{tasks,templates,handlers,defaults}
```

### defaults/main.yml

```yaml
---
node_exporter_version: "1.7.0"
node_exporter_user: "node_exporter"
node_exporter_port: 9100
```

### tasks/main.yml

```yaml
---
- name: Create node_exporter user
  ansible.builtin.user:
    name: "{{ node_exporter_user }}"
    shell: /sbin/nologin
    system: true
    create_home: false

- name: Check if Node Exporter is installed
  ansible.builtin.stat:
    path: /usr/local/bin/node_exporter
  register: node_exporter_binary

- name: Download Node Exporter
  ansible.builtin.get_url:
    url: "https://github.com/prometheus/node_exporter/releases/download/v{{ node_exporter_version }}/node_exporter-{{ node_exporter_version }}.linux-amd64.tar.gz"
    dest: /tmp/node_exporter.tar.gz
  when: not node_exporter_binary.stat.exists

- name: Extract Node Exporter
  ansible.builtin.unarchive:
    src: /tmp/node_exporter.tar.gz
    dest: /tmp
    remote_src: true
  when: not node_exporter_binary.stat.exists

- name: Install Node Exporter binary
  ansible.builtin.copy:
    src: "/tmp/node_exporter-{{ node_exporter_version }}.linux-amd64/node_exporter"
    dest: /usr/local/bin/node_exporter
    remote_src: true
    mode: '0755'
  when: not node_exporter_binary.stat.exists
  notify: restart node_exporter

- name: Create systemd service
  ansible.builtin.template:
    src: node_exporter.service.j2
    dest: /etc/systemd/system/node_exporter.service
  notify:
    - reload systemd
    - restart node_exporter

- name: Start Node Exporter
  ansible.builtin.service:
    name: node_exporter
    state: started
    enabled: true

- name: Verify Node Exporter is responding
  ansible.builtin.uri:
    url: "http://localhost:{{ node_exporter_port }}/metrics"
    status_code: 200
  register: check
  retries: 3
  delay: 5
  until: check.status == 200

- name: Display status
  ansible.builtin.debug:
    msg: "Node Exporter running on port {{ node_exporter_port }}"
```

### handlers/main.yml

```yaml
---
- name: reload systemd
  ansible.builtin.systemd:
    daemon_reload: true

- name: restart node_exporter
  ansible.builtin.service:
    name: node_exporter
    state: restarted
```

### templates/node_exporter.service.j2

```ini
[Unit]
Description=Prometheus Node Exporter
After=network-online.target

[Service]
User={{ node_exporter_user }}
Type=simple
ExecStart=/usr/local/bin/node_exporter --web.listen-address=:{{ node_exporter_port }}
Restart=always

[Install]
WantedBy=multi-user.target
```

</details>

---

## 📝 課題4: エージェントインストールPlaybookの作成

### 課題内容

作成したロールを使用するPlaybookを作成してください。

### 🤖 AIへのプロンプト例

```
作成した3つのロール（cloudwatch_agent, ssm_agent, node_exporter）を
使用するPlaybookを作成してください。

要件:
1. 各エージェントのインストール有無を変数で制御
2. タグで個別に実行可能
3. 実行結果のサマリーを表示
```

<details>
<summary>📖 正解例（クリックで展開）</summary>

`/projects/IaC-Workshop/ansible/playbooks/install-agents.yml`:

```yaml
---
- name: Install Monitoring Agents
  hosts: webservers
  become: true
  gather_facts: true

  vars:
    install_cloudwatch_agent: true
    install_ssm_agent: true
    install_node_exporter: false

  pre_tasks:
    - name: Display installation plan
      ansible.builtin.debug:
        msg: |
          ========================================
          Target: {{ inventory_hostname }}
          ========================================
          CloudWatch Agent: {{ install_cloudwatch_agent }}
          SSM Agent: {{ install_ssm_agent }}
          Node Exporter: {{ install_node_exporter }}
          ========================================

  roles:
    - role: cloudwatch_agent
      tags: [cloudwatch]
      when: install_cloudwatch_agent

    - role: ssm_agent
      tags: [ssm]
      when: install_ssm_agent

    - role: node_exporter
      tags: [node_exporter]
      when: install_node_exporter

  post_tasks:
    - name: Installation complete
      ansible.builtin.debug:
        msg: "✅ Agent installation completed on {{ inventory_hostname }}"
```

### 実行

```bash
cd /projects/IaC-Workshop/ansible

# 全エージェント
ansible-playbook -i inventory/${PARTICIPANT_ID}/hosts.yml playbooks/install-agents.yml

# CloudWatchのみ
ansible-playbook -i inventory/${PARTICIPANT_ID}/hosts.yml playbooks/install-agents.yml --tags cloudwatch

# Node Exporterを有効化
ansible-playbook -i inventory/${PARTICIPANT_ID}/hosts.yml playbooks/install-agents.yml \
  --extra-vars "install_node_exporter=true" --tags node_exporter
```

</details>

---

## 📝 課題5: 動作確認

### 課題内容

インストールしたエージェントが正しく動作しているか確認してください。

### 🤖 AIへの質問例

```
CloudWatch AgentとSSM Agentの動作確認方法を教えてください。
EC2内でのコマンドと、AWSコンソールでの確認ポイントを教えてください。
```

<details>
<summary>📖 正解例（クリックで展開）</summary>

### EC2での確認

```bash
# EC2にSSH接続
ssh -i ~/.ssh/${PARTICIPANT_ID}-key ec2-user@<EC2_IP>

# CloudWatch Agent状態
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -m ec2 -a status

# SSM Agent状態
sudo systemctl status amazon-ssm-agent

# Node Exporter（インストールした場合）
curl http://localhost:9100/metrics | head -20
```

### AWSコンソールでの確認

1. **CloudWatch** → **メトリクス** → **CWAgent**
2. **Systems Manager** → **Fleet Manager** → インスタンス確認

</details>

---

## ✅ チェックリスト

- [ ] CloudWatch Agentロールを作成した
- [ ] SSM Agentロールを作成した
- [ ] インストールPlaybookを作成した
- [ ] エージェントをインストールした
- [ ] 動作確認ができた

---

## 🎯 発展課題（オプション）

1. **カスタムメトリクス**: 「アプリケーション固有のメトリクスを収集するCloudWatch Agent設定を追加してください」

2. **ログ収集**: 「/var/log/messagesと/var/log/secureをCloudWatch Logsに送信する設定を追加してください」

3. **エージェント更新**: 「インストール済みエージェントを最新版に更新するPlaybookを作成してください」

---

[← 前のハンズオン](./01-server-reboot.md) | [次のハンズオン →](./03-server-info.md)
