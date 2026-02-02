# ②-③ サーバ情報取得

> **区分**: 任意  
> **所要時間**: 約30分  
> **難易度**: ★★☆☆☆  
> **前提条件**: ①-①で構築したEC2が稼働していること、[参加者セットアップ](../00-setup/participant-setup.md)完了

---

## 📌 概要

このハンズオンでは、AIアシスタントを活用してサーバー情報を収集・レポート化するAnsible Playbookを作成します。

### 学習目標

- AIを活用した情報収集Playbook生成
- Ansibleファクトの活用
- レポートの自動生成
- JSON形式でのデータ出力

### 取得する情報

| カテゴリ | 情報 |
|---------|------|
| 基本情報 | ホスト名、OS、カーネルバージョン |
| ハードウェア | CPU、メモリ、ディスク |
| ネットワーク | IPアドレス、インターフェース |
| プロセス | CPU/メモリ使用上位 |
| サービス | 実行中のサービス |

---

## 🔧 事前準備

```bash
cd /projects/IaC-Workshop/ansible
ansible webservers -m ping -i inventory/${PARTICIPANT_ID}/hosts.yml
```

---

## 📝 課題1: 基本情報取得Playbookの作成

### 課題内容

AIを使って、サーバーの基本情報を収集して表示するPlaybookを作成してください。

### 🤖 AIへのプロンプト例

```
サーバーの基本情報を収集して見やすく表示するAnsible Playbookを作成してください。

収集する情報:
- ホスト名、FQDN
- OS名、バージョン、カーネル
- CPUコア数、モデル
- メモリ合計、空き
- プライマリIPアドレス
- Uptime

ansible_* ファクトを使用して、整形されたメッセージで表示してください。
ファイル名: playbooks/gather-info.yml
```

<details>
<summary>📖 正解例（クリックで展開）</summary>

`/projects/IaC-Workshop/ansible/playbooks/gather-info.yml`:

```yaml
---
- name: Gather Server Information
  hosts: webservers
  become: true
  gather_facts: true

  tasks:
    - name: Display System Information
      ansible.builtin.debug:
        msg: |
          ╔══════════════════════════════════════════════════════════════════╗
          ║                      SERVER INFORMATION                          ║
          ╠══════════════════════════════════════════════════════════════════╣
          ║ Hostname       : {{ ansible_hostname }}
          ║ FQDN           : {{ ansible_fqdn }}
          ║ OS             : {{ ansible_distribution }} {{ ansible_distribution_version }}
          ║ Kernel         : {{ ansible_kernel }}
          ║ Architecture   : {{ ansible_architecture }}
          ╠══════════════════════════════════════════════════════════════════╣
          ║                        HARDWARE                                  ║
          ╠══════════════════════════════════════════════════════════════════╣
          ║ CPU Cores      : {{ ansible_processor_vcpus }}
          ║ CPU Model      : {{ ansible_processor[2] | default('Unknown') }}
          ║ Total Memory   : {{ (ansible_memtotal_mb / 1024) | round(2) }} GB
          ║ Free Memory    : {{ (ansible_memfree_mb / 1024) | round(2) }} GB
          ╠══════════════════════════════════════════════════════════════════╣
          ║                        NETWORK                                   ║
          ╠══════════════════════════════════════════════════════════════════╣
          ║ IPv4 Address   : {{ ansible_default_ipv4.address | default('N/A') }}
          ║ Gateway        : {{ ansible_default_ipv4.gateway | default('N/A') }}
          ║ Interface      : {{ ansible_default_ipv4.interface | default('N/A') }}
          ╠══════════════════════════════════════════════════════════════════╣
          ║                        UPTIME                                    ║
          ╠══════════════════════════════════════════════════════════════════╣
          ║ Uptime         : {{ (ansible_uptime_seconds | int // 86400) }} days, {{ (ansible_uptime_seconds | int % 86400 // 3600) }} hours
          ╚══════════════════════════════════════════════════════════════════╝
```

### 実行

```bash
ansible-playbook -i inventory/${PARTICIPANT_ID}/hosts.yml playbooks/gather-info.yml
```

</details>

---

## 📝 課題2: 詳細情報取得Playbookの作成

### 課題内容

ディスク使用量、プロセス情報、サービス状態など詳細情報を取得するPlaybookを作成してください。

### 🤖 AIへのプロンプト例

```
サーバーの詳細情報を収集するAnsible Playbookを作成してください。

収集する情報:
1. ディスク使用量（df -h）
2. マウントポイント（ansible_mounts から）
3. CPU使用率上位10プロセス
4. メモリ使用率上位10プロセス
5. 実行中のサービス
6. リッスン中のポート
7. 利用可能なアップデート数

各情報はセクションに分けて表示してください。
ファイル名: playbooks/gather-detailed-info.yml
```

<details>
<summary>📖 正解例（クリックで展開）</summary>

`/projects/IaC-Workshop/ansible/playbooks/gather-detailed-info.yml`:

```yaml
---
- name: Gather Detailed Server Information
  hosts: webservers
  become: true
  gather_facts: true

  tasks:
    - name: Get disk usage
      ansible.builtin.shell: df -h --output=source,fstype,size,used,avail,pcent,target | grep -v tmpfs
      register: disk_usage
      changed_when: false

    - name: Display disk information
      ansible.builtin.debug:
        msg: |
          === DISK USAGE ===
          {{ disk_usage.stdout }}

    - name: Display mount points
      ansible.builtin.debug:
        msg: |
          === MOUNT POINTS ===
          {% for mount in ansible_mounts %}
          - {{ mount.mount }}: {{ mount.device }} ({{ mount.fstype }})
            Size: {{ (mount.size_total / 1073741824) | round(2) }} GB
            Free: {{ (mount.size_available / 1073741824) | round(2) }} GB
          {% endfor %}

    - name: Get top CPU processes
      ansible.builtin.shell: ps aux --sort=-%cpu | head -11
      register: top_cpu
      changed_when: false

    - name: Display top CPU processes
      ansible.builtin.debug:
        msg: |
          === TOP CPU PROCESSES ===
          {{ top_cpu.stdout }}

    - name: Get top memory processes
      ansible.builtin.shell: ps aux --sort=-%mem | head -11
      register: top_mem
      changed_when: false

    - name: Display top memory processes
      ansible.builtin.debug:
        msg: |
          === TOP MEMORY PROCESSES ===
          {{ top_mem.stdout }}

    - name: Get running services
      ansible.builtin.shell: systemctl list-units --type=service --state=running --no-pager | head -20
      register: running_services
      changed_when: false

    - name: Display running services
      ansible.builtin.debug:
        msg: |
          === RUNNING SERVICES ===
          {{ running_services.stdout }}

    - name: Get listening ports
      ansible.builtin.shell: ss -tlnp
      register: listening_ports
      changed_when: false

    - name: Display listening ports
      ansible.builtin.debug:
        msg: |
          === LISTENING PORTS ===
          {{ listening_ports.stdout }}

    - name: Check for updates
      ansible.builtin.shell: dnf check-update --quiet | wc -l
      register: updates_available
      changed_when: false
      failed_when: false

    - name: Display updates
      ansible.builtin.debug:
        msg: "Available updates: {{ updates_available.stdout }} packages"
```

</details>

---

## 📝 課題3: レポート生成Playbookの作成

### 課題内容

収集した情報をファイルに保存するPlaybookを作成してください。

### 🤖 AIへのプロンプト例

```
サーバー情報をレポートファイルとして保存するAnsible Playbookを作成してください。

要件:
1. レポートは ansible/reports/ ディレクトリに保存
2. ファイル名: {hostname}_{timestamp}.txt
3. 基本情報、ハードウェア、ネットワーク、ディスクなどを含む
4. delegate_to: localhost でローカルに保存
5. 全サーバーのサマリーレポートも生成
```

<details>
<summary>📖 正解例（クリックで展開）</summary>

`/projects/IaC-Workshop/ansible/playbooks/generate-report.yml`:

```yaml
---
- name: Generate Server Report
  hosts: webservers
  become: true
  gather_facts: true

  vars:
    report_dir: "{{ playbook_dir }}/../reports"
    report_date: "{{ lookup('pipe', 'date +%Y%m%d_%H%M%S') }}"

  tasks:
    - name: Create reports directory
      ansible.builtin.file:
        path: "{{ report_dir }}"
        state: directory
        mode: '0755'
      delegate_to: localhost
      run_once: true
      become: false

    - name: Get disk usage
      ansible.builtin.shell: df -h
      register: disk_info
      changed_when: false

    - name: Get memory info
      ansible.builtin.shell: free -h
      register: memory_info
      changed_when: false

    - name: Get uptime
      ansible.builtin.command: uptime
      register: uptime_info
      changed_when: false

    - name: Generate report
      ansible.builtin.copy:
        dest: "{{ report_dir }}/{{ inventory_hostname }}_{{ report_date }}.txt"
        content: |
          ================================================================================
          SERVER REPORT: {{ inventory_hostname }}
          Generated: {{ ansible_date_time.iso8601 }}
          ================================================================================
          
          == BASIC INFORMATION ==
          Hostname:       {{ ansible_hostname }}
          OS:             {{ ansible_distribution }} {{ ansible_distribution_version }}
          Kernel:         {{ ansible_kernel }}
          
          == HARDWARE ==
          CPU Cores:      {{ ansible_processor_vcpus }}
          Total Memory:   {{ ansible_memtotal_mb }} MB
          
          == NETWORK ==
          Primary IP:     {{ ansible_default_ipv4.address | default('N/A') }}
          
          == UPTIME ==
          {{ uptime_info.stdout }}
          
          == MEMORY USAGE ==
          {{ memory_info.stdout }}
          
          == DISK USAGE ==
          {{ disk_info.stdout }}
          
          ================================================================================
        mode: '0644'
      delegate_to: localhost
      become: false

    - name: Display report location
      ansible.builtin.debug:
        msg: "Report: {{ report_dir }}/{{ inventory_hostname }}_{{ report_date }}.txt"

- name: Generate Summary
  hosts: localhost
  gather_facts: false

  vars:
    report_dir: "{{ playbook_dir }}/../reports"

  tasks:
    - name: Create summary
      ansible.builtin.copy:
        dest: "{{ report_dir }}/summary_{{ lookup('pipe', 'date +%Y%m%d_%H%M%S') }}.txt"
        content: |
          ================================================================================
          INFRASTRUCTURE SUMMARY
          Generated: {{ lookup('pipe', 'date') }}
          ================================================================================
          
          Total Servers: {{ groups['webservers'] | length }}
          
          {% for host in groups['webservers'] %}
          - {{ host }}: {{ hostvars[host]['ansible_host'] | default('N/A') }}
          {% endfor %}
          ================================================================================
        mode: '0644'
```

### 実行

```bash
ansible-playbook -i inventory/${PARTICIPANT_ID}/hosts.yml playbooks/generate-report.yml

# レポート確認
ls -la reports/
cat reports/web1_*.txt
```

</details>

---

## 📝 課題4: JSON形式でのデータ収集

### 課題内容

構造化されたJSONデータとしてサーバー情報を収集するPlaybookを作成してください。

### 🤖 AIへのプロンプト例

```
サーバー情報をJSON形式で収集するAnsible Playbook を作成してください。

要件:
1. set_fact で server_data 変数に情報を構造化
2. to_nice_json フィルターでファイルに保存
3. 保存先: reports/json/{hostname}_{timestamp}.json
4. 最後に全サーバーのJSONを1つのファイルに結合
```

<details>
<summary>📖 正解例（クリックで展開）</summary>

`/projects/IaC-Workshop/ansible/playbooks/gather-json.yml`:

```yaml
---
- name: Gather Server Information as JSON
  hosts: webservers
  become: true
  gather_facts: true

  vars:
    output_dir: "{{ playbook_dir }}/../reports/json"
    timestamp: "{{ lookup('pipe', 'date +%Y%m%d_%H%M%S') }}"

  tasks:
    - name: Create output directory
      ansible.builtin.file:
        path: "{{ output_dir }}"
        state: directory
        mode: '0755'
      delegate_to: localhost
      run_once: true
      become: false

    - name: Collect server data
      ansible.builtin.set_fact:
        server_data:
          hostname: "{{ ansible_hostname }}"
          fqdn: "{{ ansible_fqdn }}"
          timestamp: "{{ ansible_date_time.iso8601 }}"
          os:
            distribution: "{{ ansible_distribution }}"
            version: "{{ ansible_distribution_version }}"
            kernel: "{{ ansible_kernel }}"
          hardware:
            cpu_cores: "{{ ansible_processor_vcpus }}"
            memory_total_mb: "{{ ansible_memtotal_mb }}"
            memory_free_mb: "{{ ansible_memfree_mb }}"
          network:
            ipv4_address: "{{ ansible_default_ipv4.address | default('N/A') }}"
            gateway: "{{ ansible_default_ipv4.gateway | default('N/A') }}"
          uptime_seconds: "{{ ansible_uptime_seconds }}"

    - name: Save JSON data
      ansible.builtin.copy:
        dest: "{{ output_dir }}/{{ inventory_hostname }}_{{ timestamp }}.json"
        content: "{{ server_data | to_nice_json }}"
        mode: '0644'
      delegate_to: localhost
      become: false

    - name: Display data
      ansible.builtin.debug:
        var: server_data

- name: Combine JSON Reports
  hosts: localhost
  gather_facts: false

  vars:
    output_dir: "{{ playbook_dir }}/../reports/json"

  tasks:
    - name: Find JSON files
      ansible.builtin.find:
        paths: "{{ output_dir }}"
        patterns: "*.json"
        excludes: "combined_*.json"
      register: json_files

    - name: Read JSON files
      ansible.builtin.slurp:
        src: "{{ item.path }}"
      register: json_contents
      loop: "{{ json_files.files }}"

    - name: Combine data
      ansible.builtin.set_fact:
        combined:
          generated_at: "{{ lookup('pipe', 'date --iso-8601=seconds') }}"
          server_count: "{{ json_files.files | length }}"
          servers: "{{ json_contents.results | map(attribute='content') | map('b64decode') | map('from_json') | list }}"

    - name: Save combined JSON
      ansible.builtin.copy:
        dest: "{{ output_dir }}/combined_{{ lookup('pipe', 'date +%Y%m%d_%H%M%S') }}.json"
        content: "{{ combined | to_nice_json }}"
        mode: '0644'
```

</details>

---

## 📝 課題5: アドホックコマンドでの情報取得

### 課題内容

Playbookを使わずに、コマンドラインで直接情報を取得する方法を学びましょう。

### 🤖 AIへの質問例

```
Ansibleのアドホックコマンドで以下の情報を取得する方法を教えてください：
- 全サーバーのホスト名
- OSバージョン
- メモリ使用量
- ディスク使用量
- ansible_* ファクトの取得方法
```

<details>
<summary>📖 正解例（クリックで展開）</summary>

```bash
cd /projects/IaC-Workshop/ansible
INVENTORY="inventory/${PARTICIPANT_ID}/hosts.yml"

# ホスト名
ansible webservers -i $INVENTORY -m command -a "hostname"

# OSバージョン
ansible webservers -i $INVENTORY -m command -a "cat /etc/os-release"

# メモリ
ansible webservers -i $INVENTORY -m command -a "free -h"

# ディスク
ansible webservers -i $INVENTORY -m command -a "df -h"

# uptime
ansible webservers -i $INVENTORY -m command -a "uptime"

# 全ファクト
ansible webservers -i $INVENTORY -m setup

# 特定のファクト
ansible webservers -i $INVENTORY -m setup -a "filter=ansible_distribution*"

# メモリ関連
ansible webservers -i $INVENTORY -m setup -a "filter=ansible_mem*"
```

</details>

---

## ✅ チェックリスト

- [ ] 基本情報取得Playbookを作成した
- [ ] 詳細情報取得Playbookを作成した
- [ ] レポート生成Playbookを作成した
- [ ] JSON形式での収集を実行した
- [ ] アドホックコマンドを使えるようになった

---

## 🎯 発展課題（オプション）

1. **HTMLレポート**: 「Jinja2テンプレートを使って、見やすいHTMLレポートを生成するPlaybookを作成してください」

2. **CSV出力**: 「複数サーバーの情報をCSV形式でまとめて出力するPlaybookを作成してください」

3. **S3アップロード**: 「生成したレポートをS3バケットに自動アップロードするPlaybookを作成してください」

4. **差分レポート**: 「前回と今回のサーバー情報を比較して、変更点を表示するPlaybookを作成してください」

---

## 📚 参考資料

### よく使うAnsibleファクト

| ファクト名 | 説明 |
|-----------|------|
| `ansible_hostname` | ホスト名 |
| `ansible_distribution` | OS名 |
| `ansible_kernel` | カーネルバージョン |
| `ansible_memtotal_mb` | 総メモリ（MB） |
| `ansible_processor_vcpus` | CPUコア数 |
| `ansible_default_ipv4` | デフォルトIPv4情報 |
| `ansible_mounts` | マウントポイント一覧 |
| `ansible_uptime_seconds` | 稼働時間（秒） |

---

[← 前のハンズオン](./02-agent-install.md) | [インデックスに戻る →](../index.md)
