# ②-① Ansible × AI：Playbook生成の基本

> **区分**: 必須  
> **所要時間**: 約30分  
> **学習目標**: AIを使ってAnsible Playbookを効率的に生成する方法を学ぶ  
> **前提条件**: ①-①完了、[参加者セットアップ](../00-setup/participant-setup.md)完了

---

## 📌 このハンズオンで学ぶこと

1. **Ansible Playbookの構造をAIに生成させる**
   - hosts, become, gather_facts などの基本構造
   - pre_tasks, tasks, post_tasks の使い分け
   - handlers の定義

2. **条件を正確に伝えるプロンプト作成**
   - モジュール名と属性を明示
   - 変数の使い方を指定
   - エラーハンドリングの要求

3. **AI生成Playbookのレビュー**
   - 冪等性の確認
   - changed_when, failed_when の適切な使用

---

## 🔧 事前準備

```bash
cd /projects/IaC-Workshop/ansible

# 接続確認
ansible webservers -m ping -i inventory/${PARTICIPANT_ID}/hosts.yml
```

---

## 📝 課題1: 基本的なPlaybook構造の生成

### 課題内容

サーバー再起動用のPlaybookをAIに生成させてください。

### 条件

| 項目 | 値 |
|-----|---|
| ファイル | `playbooks/reboot.yml` |
| hosts | `webservers` |
| become | `true` |
| serial | `1`（1台ずつ実行） |

### 機能要件

| フェーズ | 処理内容 |
|---------|----------|
| pre_tasks | ホスト情報表示、再起動前のuptime取得 |
| tasks | `ansible.builtin.reboot`で再起動、接続待機 |
| post_tasks | 再起動後のuptime表示、サービス確認 |

### 変数

| 変数名 | 値 | 説明 |
|--------|---|------|
| reboot_timeout | 300 | 再起動タイムアウト秒 |
| pre_reboot_delay | 5 | 再起動前の待機秒 |
| post_reboot_delay | 30 | 再起動後の待機秒 |

<details>
<summary>📖 正解例（クリックで展開）</summary>

### 💬 プロンプト例

```
以下の条件でAnsible Playbookを作成してください：

ファイル: playbooks/reboot.yml

基本設定:
- hosts: webservers
- become: true
- gather_facts: true
- serial: 1

変数(vars):
- reboot_timeout: 300
- pre_reboot_delay: 5
- post_reboot_delay: 30

処理フロー:
1. pre_tasks:
   - ansible.builtin.debug でホスト情報を表示
     （inventory_hostname, ansible_host, ansible_distribution）
   - ansible.builtin.command で uptime を取得、registerで保存
   - 取得したuptimeをdebugで表示

2. tasks:
   - ansible.builtin.reboot モジュールで再起動
     - msg, pre_reboot_delay, post_reboot_delay, reboot_timeout を設定
   - ansible.builtin.wait_for_connection で接続待機

3. post_tasks:
   - 再起動後のuptimeを取得・表示
   - ansible.builtin.service でsshd, chronydの起動確認
   - 完了メッセージをdebugで表示

全てのタスクにnameを付けてください。
commandモジュールにはchanged_when: falseを付けてください。
```

### 🖥️ 生成されるコード

```yaml
---
- name: Server Reboot Playbook
  hosts: webservers
  become: true
  gather_facts: true
  serial: 1

  vars:
    reboot_timeout: 300
    pre_reboot_delay: 5
    post_reboot_delay: 30

  pre_tasks:
    - name: Display host information
      ansible.builtin.debug:
        msg: |
          Host: {{ inventory_hostname }}
          IP: {{ ansible_host }}
          OS: {{ ansible_distribution }} {{ ansible_distribution_version }}

    - name: Get uptime before reboot
      ansible.builtin.command: uptime
      register: uptime_before
      changed_when: false

    - name: Display uptime before reboot
      ansible.builtin.debug:
        msg: "Before: {{ uptime_before.stdout }}"

  tasks:
    - name: Reboot the server
      ansible.builtin.reboot:
        msg: "Ansible triggered reboot"
        pre_reboot_delay: "{{ pre_reboot_delay }}"
        post_reboot_delay: "{{ post_reboot_delay }}"
        reboot_timeout: "{{ reboot_timeout }}"

    - name: Wait for connection
      ansible.builtin.wait_for_connection:
        delay: 10
        timeout: "{{ reboot_timeout }}"

  post_tasks:
    - name: Get uptime after reboot
      ansible.builtin.command: uptime
      register: uptime_after
      changed_when: false

    - name: Display uptime after reboot
      ansible.builtin.debug:
        msg: "After: {{ uptime_after.stdout }}"

    - name: Verify services are running
      ansible.builtin.service:
        name: "{{ item }}"
        state: started
      loop:
        - sshd
        - chronyd

    - name: Display completion message
      ansible.builtin.debug:
        msg: "✅ Reboot complete: {{ inventory_hostname }}"
```

</details>

---

## 📝 課題2: ドライランと実行オプション

### 課題内容

Ansibleの実行オプションをAIに説明させ、実際に使用してください。

### 条件

以下のオプションについて説明と使用例を生成させる：

| オプション | 用途 |
|-----------|------|
| `--check` | ドライラン |
| `-v` / `-vv` | 詳細ログ |
| `--limit` | 対象ホスト制限 |
| `--diff` | 変更差分表示 |
| `--extra-vars` | 変数のオーバーライド |

<details>
<summary>📖 正解例（クリックで展開）</summary>

### 💬 プロンプト例

```
Ansible Playbookの実行オプションについて教えてください：
--check, -v, --limit, --diff, --extra-vars

それぞれの用途と、playbooks/reboot.yml を例にした使用例を示してください。
```

### 🖥️ 生成されるコマンド例

```bash
# ドライラン（実際には実行しない）
ansible-playbook -i inventory/${PARTICIPANT_ID}/hosts.yml playbooks/reboot.yml --check

# 詳細ログ
ansible-playbook -i inventory/${PARTICIPANT_ID}/hosts.yml playbooks/reboot.yml -v
ansible-playbook -i inventory/${PARTICIPANT_ID}/hosts.yml playbooks/reboot.yml -vvv

# 特定ホストのみ
ansible-playbook -i inventory/${PARTICIPANT_ID}/hosts.yml playbooks/reboot.yml --limit web1

# 変数のオーバーライド
ansible-playbook -i inventory/${PARTICIPANT_ID}/hosts.yml playbooks/reboot.yml \
  --extra-vars "reboot_timeout=600"

# 組み合わせ
ansible-playbook -i inventory/${PARTICIPANT_ID}/hosts.yml playbooks/reboot.yml \
  --check --diff -v
```

</details>

---

## 📝 課題3: 条件分岐の追加

### 課題内容

「再起動が必要な場合のみ再起動する」条件付きPlaybookを生成させてください。

### 条件

| 項目 | 値 |
|-----|---|
| ファイル | `playbooks/reboot-if-needed.yml` |
| 判定方法 | シェルスクリプトで判定 |
| 条件 | 終了コード1なら再起動必要 |

### 機能要件

| 処理 | 説明 |
|------|------|
| 判定 | `needs-restarting -r` または カーネルバージョン比較 |
| 表示 | 判定結果をメッセージで表示 |
| 再起動 | `when` 条件で必要時のみ実行 |

<details>
<summary>📖 正解例（クリックで展開）</summary>

### 💬 プロンプト例

```
再起動が必要かどうかを判定し、必要な場合のみ再起動するAnsible Playbookを作成してください。

ファイル: playbooks/reboot-if-needed.yml
hosts: webservers
serial: 1

処理フロー:
1. ansible.builtin.shell で再起動要否を判定
   - needs-restarting -r コマンドを使用
   - コマンドがない場合はカーネルバージョン比較でフォールバック
   - register: needs_reboot
   - changed_when: false
   - failed_when: false（コマンド失敗を許容）

2. ansible.builtin.debug で判定結果を表示
   - needs_reboot.rc == 1 なら「⚠️ 再起動が必要」
   - それ以外なら「✅ 再起動不要」

3. ansible.builtin.reboot で再起動
   - when: needs_reboot.rc == 1

4. wait_for_connection
   - when: needs_reboot.rc == 1
```

### 🖥️ 生成されるコード

```yaml
---
- name: Conditional Reboot Playbook
  hosts: webservers
  become: true
  gather_facts: true
  serial: 1

  vars:
    reboot_timeout: 300

  tasks:
    - name: Check if reboot is required
      ansible.builtin.shell: |
        if command -v needs-restarting &> /dev/null; then
          needs-restarting -r
          exit $?
        else
          RUNNING=$(uname -r)
          INSTALLED=$(rpm -q --last kernel | head -1 | awk '{print $1}' | sed 's/kernel-//')
          [ "$RUNNING" != "$INSTALLED" ] && exit 1 || exit 0
        fi
      register: needs_reboot
      changed_when: false
      failed_when: false

    - name: Display reboot status
      ansible.builtin.debug:
        msg: "{{ '⚠️ Reboot REQUIRED' if needs_reboot.rc == 1 else '✅ No reboot needed' }}"

    - name: Reboot if required
      ansible.builtin.reboot:
        reboot_timeout: "{{ reboot_timeout }}"
      when: needs_reboot.rc == 1

    - name: Wait for connection
      ansible.builtin.wait_for_connection:
        timeout: "{{ reboot_timeout }}"
      when: needs_reboot.rc == 1
```

</details>

---

## 📝 課題4: ヘルスチェックの追加

### 課題内容

再起動前後にヘルスチェックを行うPlaybookを生成させてください。

### 条件

| 項目 | 値 |
|-----|---|
| ファイル | `playbooks/reboot-with-healthcheck.yml` |
| ヘルスチェックURL | `http://localhost/health` |
| リトライ | 30回、10秒間隔 |

### 機能要件

| フェーズ | 処理 |
|---------|------|
| pre_tasks | ヘルスチェック、nginx停止、10秒待機 |
| tasks | 再起動、接続待機 |
| post_tasks | nginx起動、ポート待機、ヘルスチェック（リトライ付き） |

<details>
<summary>📖 正解例（クリックで展開）</summary>

### 💬 プロンプト例

```
ヘルスチェック付きの再起動Ansible Playbookを作成してください。

ファイル: playbooks/reboot-with-healthcheck.yml
hosts: webservers
serial: 1

変数:
- health_check_url: http://localhost/health
- health_check_retries: 30
- health_check_delay: 10
- reboot_timeout: 300

処理フロー:
1. pre_tasks:
   - ansible.builtin.uri でヘルスチェック（failed_when: false）
   - 結果を表示
   - ansible.builtin.service でnginx停止（ヘルスチェック成功時のみ）
   - ansible.builtin.pause で10秒待機

2. tasks:
   - 再起動と接続待機

3. post_tasks:
   - nginx起動
   - ansible.builtin.wait_for でポート80待機
   - ansible.builtin.uri でヘルスチェック
     - retries, delay, until を使用してリトライ
   - 成功メッセージ表示
```

### 🖥️ 生成されるコード

```yaml
---
- name: Reboot with Health Check
  hosts: webservers
  become: true
  gather_facts: true
  serial: 1

  vars:
    health_check_url: "http://localhost/health"
    health_check_retries: 30
    health_check_delay: 10
    reboot_timeout: 300

  pre_tasks:
    - name: Pre-reboot health check
      ansible.builtin.uri:
        url: "{{ health_check_url }}"
        status_code: 200
        timeout: 10
      register: pre_health
      failed_when: false

    - name: Display pre-health status
      ansible.builtin.debug:
        msg: "Pre-reboot: {{ 'HEALTHY' if pre_health.status == 200 else 'UNHEALTHY' }}"

    - name: Stop nginx gracefully
      ansible.builtin.service:
        name: nginx
        state: stopped
      when: pre_health.status == 200

    - name: Wait for connections to drain
      ansible.builtin.pause:
        seconds: 10

  tasks:
    - name: Reboot the server
      ansible.builtin.reboot:
        reboot_timeout: "{{ reboot_timeout }}"

    - name: Wait for connection
      ansible.builtin.wait_for_connection:
        timeout: "{{ reboot_timeout }}"

  post_tasks:
    - name: Start nginx
      ansible.builtin.service:
        name: nginx
        state: started

    - name: Wait for port 80
      ansible.builtin.wait_for:
        port: 80
        timeout: 60

    - name: Post-reboot health check with retry
      ansible.builtin.uri:
        url: "{{ health_check_url }}"
        status_code: 200
      register: post_health
      retries: "{{ health_check_retries }}"
      delay: "{{ health_check_delay }}"
      until: post_health.status == 200

    - name: Display success
      ansible.builtin.debug:
        msg: "✅ Health check passed"
```

</details>

---

## 📝 課題5: cronジョブの管理

### 課題内容

定期再起動のスケジュールを管理するPlaybookを生成させてください。

### 条件

| 項目 | 値 |
|-----|---|
| ファイル | `playbooks/schedule-reboot.yml` |
| スクリプトパス | `/usr/local/bin/scheduled-reboot.sh` |
| スケジュール | 毎週日曜 03:00 |
| 制御変数 | `schedule_enabled`（true/false） |

<details>
<summary>📖 正解例（クリックで展開）</summary>

### 💬 プロンプト例

```
cronジョブで定期再起動を設定するAnsible Playbookを作成してください。

ファイル: playbooks/schedule-reboot.yml
hosts: webservers

変数:
- schedule_enabled: true（falseでcron削除）
- reboot_schedule:
    minute: "0"
    hour: "3"
    weekday: "0"

処理:
1. ansible.builtin.copy でスクリプト作成
   - パス: /usr/local/bin/scheduled-reboot.sh
   - mode: 0755
   - 内容: ログ出力とshutdown -r

2. ansible.builtin.cron でジョブ登録
   - state: present（enabled時）/ absent（disabled時）

3. 設定状態をメッセージ表示
```

### 🖥️ 生成されるコード

```yaml
---
- name: Schedule Reboot
  hosts: webservers
  become: true
  gather_facts: true

  vars:
    schedule_enabled: true
    reboot_schedule:
      minute: "0"
      hour: "3"
      weekday: "0"

  tasks:
    - name: Create reboot script
      ansible.builtin.copy:
        dest: /usr/local/bin/scheduled-reboot.sh
        mode: '0755'
        content: |
          #!/bin/bash
          echo "Scheduled reboot at $(date)" >> /var/log/scheduled-reboot.log
          sync
          /sbin/shutdown -r +1 "Scheduled reboot"

    - name: Configure cron job
      ansible.builtin.cron:
        name: "Scheduled server reboot"
        minute: "{{ reboot_schedule.minute }}"
        hour: "{{ reboot_schedule.hour }}"
        weekday: "{{ reboot_schedule.weekday }}"
        job: "/usr/local/bin/scheduled-reboot.sh"
        state: "{{ 'present' if schedule_enabled else 'absent' }}"

    - name: Display status
      ansible.builtin.debug:
        msg: "Schedule: {{ 'ENABLED' if schedule_enabled else 'DISABLED' }}"
```

</details>

---

## 📝 課題6: 安全装置付きPlaybook

### 課題内容

確認変数がないと実行されない「安全装置」付きPlaybookを生成させてください。

### 条件

| 項目 | 値 |
|-----|---|
| ファイル | `playbooks/emergency-reboot.yml` |
| 安全装置変数 | `confirm_emergency`（デフォルトfalse） |
| 動作 | falseなら即座に失敗、trueなら実行 |

<details>
<summary>📖 正解例（クリックで展開）</summary>

### 💬 プロンプト例

```
安全装置付きの緊急再起動Ansible Playbookを作成してください。

ファイル: playbooks/emergency-reboot.yml
hosts: webservers
gather_facts: false（高速化）

変数:
- confirm_emergency: false（安全装置）

処理:
1. pre_tasks で ansible.builtin.fail を使用
   - when: not confirm_emergency
   - 警告メッセージと実行方法を表示

2. 確認後は即座に再起動
   - shutdown -r now（async: 0, poll: 0）
   - wait_for_connection で復帰待機
```

### 🖥️ 生成されるコード

```yaml
---
- name: Emergency Reboot (Safety Lock)
  hosts: webservers
  become: true
  gather_facts: false

  vars:
    confirm_emergency: false

  pre_tasks:
    - name: Safety check
      ansible.builtin.fail:
        msg: |
          ⚠️ EMERGENCY REBOOT BLOCKED
          
          Run with: --extra-vars "confirm_emergency=true"
      when: not confirm_emergency

  tasks:
    - name: Force reboot
      ansible.builtin.command: shutdown -r now
      async: 0
      poll: 0
      ignore_errors: true

    - name: Wait for recovery
      ansible.builtin.wait_for_connection:
        delay: 30
        timeout: 600

    - name: Confirm recovery
      ansible.builtin.command: uptime
      register: result
      changed_when: false

    - name: Display status
      ansible.builtin.debug:
        msg: "✅ {{ inventory_hostname }}: {{ result.stdout }}"
```

### 実行コマンド

```bash
# 安全装置によりブロック
ansible-playbook -i inventory/${PARTICIPANT_ID}/hosts.yml playbooks/emergency-reboot.yml

# 確認付きで実行
ansible-playbook -i inventory/${PARTICIPANT_ID}/hosts.yml playbooks/emergency-reboot.yml \
  --extra-vars "confirm_emergency=true"
```

</details>

---

## ✅ チェックリスト

- [ ] 課題1: 基本的なPlaybook構造を生成した
- [ ] 課題2: 実行オプションを理解し使用した
- [ ] 課題3: 条件分岐付きPlaybookを生成した
- [ ] 課題4: ヘルスチェック付きPlaybookを生成した
- [ ] 課題5: cronジョブ管理Playbookを生成した
- [ ] 課題6: 安全装置付きPlaybookを生成した

---

## 💡 振り返り

### 効果的だったプロンプトのパターン

1. **モジュール名を明示**: `ansible.builtin.reboot` など
2. **属性を列挙**: `changed_when: false` など
3. **処理フローを番号付きで**: pre_tasks → tasks → post_tasks

### よくあるAI生成コードの修正ポイント

- `changed_when` の追加忘れ
- `failed_when` の適切な設定
- 変数のクォート（`"{{ var }}"` vs `{{ var }}`）

---

## 🎯 発展課題（オプション）

### 発展1: Slack通知の追加

```
「再起動の開始と完了をSlackに通知するタスクを追加してください」
→ ansible.builtin.uri でWebhook送信
```

### 発展2: エラー時のロールバック

```
「再起動後のヘルスチェックが失敗した場合に通知するPlaybookを作成してください」
→ block/rescue の使い方を学ぶ
```

---

[← 戻る](../01-infrastructure/01-vpc-subnet-ec2.md) | [次のハンズオン →](./02-agent-install.md)
