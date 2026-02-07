# WSL Smart Home Camera 📷🏠

**WSL2 + USBカメラ + Nature Remo で、AIエージェントが部屋を見て家電を操作する**

AI エージェント（[OpenClaw](https://github.com/openclaw/openclaw)）が USB カメラで部屋を撮影・分析し、Nature Remo API 経由で照明・エアコン・テレビなどを操作するためのガイドです。

## 構成図

```
┌─────────────────────────────────────────────┐
│  Windows PC                                 │
│  ┌────────────┐     ┌────────────────────┐  │
│  │ USB Camera │────▶│  WSL2 (Ubuntu)     │  │
│  │ (Depstech) │     │  ┌──────────────┐  │  │
│  └────────────┘     │  │  OpenClaw    │  │  │
│    usbipd-win       │  │  (AI Agent)  │  │  │
│                     │  └──────┬───────┘  │  │
│                     └─────────┼──────────┘  │
└─────────────────────────────────┼────────────┘
                                  │ HTTPS
                      ┌───────────▼───────────┐
                      │  Nature Remo Cloud API │
                      └───────────┬───────────┘
                                  │ IR
                      ┌───────────▼───────────┐
                      │  家電（照明/エアコン/TV）│
                      └───────────────────────┘
```

## できること

- 📷 **部屋の撮影** — USBカメラで定期的に撮影
- 👁️ **画像分析** — AI が部屋の状態を判定（電気ON/OFF、人の在/不在、散らかり具合）
- 💡 **家電操作** — Nature Remo API で照明・エアコン・テレビを制御
- 🔄 **操作→撮影→確認ループ** — 操作結果をカメラで検証

## 必要なもの

| 項目 | 詳細 |
|------|------|
| **OS** | Windows 10/11 + WSL2 (Ubuntu) |
| **カメラ** | USB Webカメラ（例: Depstech webcam） |
| **スマートリモコン** | [Nature Remo](https://nature.global/) |
| **ツール** | ffmpeg, usbipd-win |
| **AI エージェント** | [OpenClaw](https://github.com/openclaw/openclaw)（推奨）または任意の LLM |

## セットアップ

### 1. usbipd-win のインストール

Windows 側で USB デバイスを WSL に転送するためのツール。

```powershell
# Windows PowerShell (管理者)
winget install --id dorssel.usbipd-win
```

> ⚠️ **インストール後、UACダイアログが表示されたら「はい」を押す**

### 2. USB カメラを WSL にアタッチ

```powershell
# Windows PowerShell (管理者)

# カメラの BUSID を確認
usbipd list

# 出力例:
# BUSID  VID:PID    DEVICE                          STATE
# 1-3    1d6c:0103  Depstech webcam                 Not shared

# バインド（初回のみ）
usbipd bind --busid 1-3

# WSL にアタッチ
usbipd attach --wsl --busid 1-3
```

```bash
# WSL 側で権限を設定
sudo chmod 666 /dev/video0 /dev/video1
```

### 3. ffmpeg のインストール

```bash
# WSL (Ubuntu)
sudo apt install -y ffmpeg
```

### 4. 撮影テスト

```bash
# MJPEG フォーマット、1920x1080 で撮影
ffmpeg -f v4l2 -input_format mjpeg -video_size 1920x1080 \
  -i /dev/video0 -frames:v 1 -update 1 /tmp/camera.jpg -y
```

> Windows 側からは `\\wsl$\Ubuntu\tmp\camera.jpg` で確認できます

### 5. Nature Remo API の設定

1. https://home.nature.global/ にログイン
2. 右上のメニューから「アクセストークン発行」
3. トークンを安全に保存:

```bash
mkdir -p ~/.config/nature-remo
echo -n "YOUR_TOKEN_HERE" > ~/.config/nature-remo/token
chmod 600 ~/.config/nature-remo/token
```

4. 家電一覧の取得:

```bash
TOKEN=$(cat ~/.config/nature-remo/token)
curl -s -H "Authorization: Bearer $TOKEN" \
  https://api.nature.global/1/appliances | python3 -m json.tool
```

### 6. 家電操作

```bash
TOKEN=$(cat ~/.config/nature-remo/token)

# 照明 ON
curl -s -X POST \
  "https://api.nature.global/1/appliances/{APPLIANCE_ID}/light" \
  -H "Authorization: Bearer $TOKEN" \
  -d "button=on"

# 照明 OFF
curl -s -X POST \
  "https://api.nature.global/1/appliances/{APPLIANCE_ID}/light" \
  -H "Authorization: Bearer $TOKEN" \
  -d "button=off"

# エアコン設定
curl -s -X POST \
  "https://api.nature.global/1/appliances/{APPLIANCE_ID}/aircon_settings" \
  -H "Authorization: Bearer $TOKEN" \
  -d "operation_mode=warm&temperature=26"
```

## はまりどころ 🪤

昨日のセットアップで遭遇した問題と解決策をまとめました。

### 1. usbipd のパスが通らない

**症状**: WSL から `usbipd` コマンドが見つからない

**原因**: インストール直後はシェルのPATHに反映されない

**解決策**: フルパスで実行
```powershell
& "C:\Program Files\usbipd-win\usbipd.exe" list
```

### 2. bind/attach に管理者権限が必要

**症状**: `usbipd bind` で "Access denied" エラー

**原因**: USB デバイスのバインドには管理者権限が必須

**解決策**: PowerShell またはコマンドプロンプトを**「管理者として実行」**で開いてから実行
```powershell
# 管理者 PowerShell で実行
usbipd bind --busid 1-3
usbipd attach --wsl --busid 1-3
```

### 3. カメラを物理的に動かすと USB が切れる

**症状**: カメラの位置を変えた後、`/dev/video0` が消える

**原因**: USB の物理的な抜き差しで usbipd のアタッチが解除される

**解決策**: Windows 側で再アタッチ + WSL で権限再設定
```powershell
# Windows (管理者)
usbipd attach --wsl --busid 1-3
```
```bash
# WSL
sudo chmod 666 /dev/video0 /dev/video1
```

### 4. WSL 再起動のたびにアタッチが必要

**症状**: WSL を再起動すると `/dev/video*` が消える

**原因**: usbipd のアタッチはセッション単位。WSL 再起動で解除される

**解決策**: 毎回手動でアタッチするか、Windows のタスクスケジューラで自動化
```powershell
# 自動化スクリプト例 (attach-camera.ps1)
usbipd attach --wsl --busid 1-3
```

### 5. /dev/video0 の権限エラー

**症状**: `PermissionError: [Errno 13] Permission denied: '/dev/video0'`

**原因**: ユーザーが `video` グループに所属していない

**解決策A（一時的）**:
```bash
sudo chmod 666 /dev/video0 /dev/video1
```

**解決策B（永続的）**:
```bash
sudo usermod -aG video $USER
# ログアウト→ログインが必要
```

### 6. 画像の色がおかしい（紫/マゼンタのノイズ）

**症状**: 撮影した画像の一部が紫色になる

**原因**: デフォルトの YUYV フォーマットでの色変換の問題

**解決策**: MJPEG フォーマットを明示的に指定
```bash
# ❌ デフォルト（YUYV） — 色がおかしくなることがある
ffmpeg -f v4l2 -i /dev/video0 -frames:v 1 /tmp/camera.jpg -y

# ✅ MJPEG 指定 — 色が正確
ffmpeg -f v4l2 -input_format mjpeg -video_size 1920x1080 \
  -i /dev/video0 -frames:v 1 -update 1 /tmp/camera.jpg -y
```

### 7. 画像が上下逆

**症状**: カメラの設置方向によって画像が上下逆になる

**解決策**: `vflip` フィルタで反転（カメラの向きに合わせて使う/使わないを決める）
```bash
# 上下反転が必要な場合
ffmpeg -f v4l2 -input_format mjpeg -video_size 1920x1080 \
  -i /dev/video0 -frames:v 1 -vf "vflip" -update 1 /tmp/camera.jpg -y
```

### 8. カメラの対応フォーマット確認

```bash
# 利用可能なフォーマットとサイズの一覧
ffmpeg -f v4l2 -list_formats all -i /dev/video0
```

## 操作→撮影→確認ループ

AI エージェントの信頼性を高めるために、操作後にカメラで確認するループが重要です。

```
1. 📷 撮影 → 部屋の状態を分析
2. 🤔 判断 → 「ベッド側の電気がついてる、消すべきか？」
3. 💡 操作 → Nature Remo API で電気を消す
4. 📷 再撮影 → 本当に消えたか確認
5. ✅ 検証 → 左側（ベッド側）が暗くなっている → 成功
```

Nature Remo の赤外線信号は届かないこともあるため、この確認ステップが重要です。

## Nature Remo API リファレンス

### 家電一覧取得
```bash
curl -s -H "Authorization: Bearer $TOKEN" \
  https://api.nature.global/1/appliances
```

### 照明操作
| ボタン | 動作 |
|--------|------|
| `on` | 点灯 |
| `off` | 消灯 |
| `on-100` | 全灯 |
| `night` | 常夜灯 |
| `bright-up` | 明るく |
| `bright-down` | 暗く |

### エアコン操作
| パラメータ | 値 |
|-----------|-----|
| `operation_mode` | `cool`, `warm`, `dry`, `blow`, `auto` |
| `temperature` | 温度 (例: `26`) |
| `air_volume` | `auto`, `1`-`10` |
| `air_direction` | `auto`, `swing`, `still` |
| `button` | 空文字=変更適用, `power-off`=電源OFF |

### テレビ操作
```bash
curl -s -X POST \
  "https://api.nature.global/1/appliances/{ID}/tv" \
  -H "Authorization: Bearer $TOKEN" \
  -d "button=power"
```

## 定点観測システム 📸

カメラ + AI + git を組み合わせた、部屋の状態変化を自動追跡するシステム。

### コンセプト

```
撮影 → AI分析 → 状態JSON生成 → 前回との差分検出 → git commit
                                                      ↓
                                              git log = 生活ログ
```

**ファイルはたった3つ:**

| ファイル | 内容 |
|----------|------|
| `camera.jpg` | 最新の撮影画像 |
| `state.json` | 現在のオブジェクト状態 |
| `diff.md` | 前回との差分レポート |

毎回上書き → コミットするだけ。`git log` が時系列データベースになります。

### state.json の構造

```json
{
  "timestamp": "2026-02-07T09:00:00+09:00",
  "lights": {
    "living_kitchen": "on",
    "living_garden": "on",
    "living_bed": "off",
    "bedroom": "off"
  },
  "ac": {
    "living": { "mode": "warm", "temp": 26 }
  },
  "tv": "on",
  "people": {
    "count": 1,
    "locations": ["desk"]
  },
  "room": {
    "floor_clean": true,
    "bed_made": false,
    "curtain": "closed"
  }
}
```

### diff.md の例

```markdown
## 🔄 変化検出 (09:00 → 09:30)

- 💡 リビングベッド側: on → **off**
- 🧑 人数: 2 → **1** (じゅんちゃんが外出？)
- 📺 テレビ: on → **off**
```

### git を時系列データベースとして使う

```bash
# 最新の状態
cat state.json

# 前回との差分
git diff HEAD~1 state.json

# 全変化の履歴
git log -p state.json

# 特定の日の状態
git log --after="2026-02-07" --before="2026-02-08" --oneline state.json

# 「電気が消えた」タイミングを探す
git log -p state.json | grep -A2 -B2 '"living_kitchen"'
```

### cron ジョブでの自動化（OpenClaw）

OpenClaw の cron 機能で定期実行:

```
15分おき: 撮影 → 分析 → state.json更新 → git commit
変化あり: Discord に差分を報告
変化なし: 静かにコミットだけ
```

### なぜ git なのか

| 方式 | メリット | デメリット |
|------|----------|------------|
| **CSV/DB に蓄積** | クエリが楽 | ファイルが肥大化、別途管理が必要 |
| **git で管理** | ファイルは常に最新3つだけ、全履歴はgitに | 複雑なクエリは苦手 |

git の利点:
- 🗂️ ファイルは常にスリム（最新状態のみ）
- 📜 全履歴が `git log` で追える
- 🔍 `git diff` で任意の2時点を比較できる
- 💾 GitHub にバックアップされる
- 🤖 AI エージェントが `git log` を読んでパターンを学習できる

## OpenClaw スキル

このセットアップを OpenClaw スキルとしても公開しています。
詳しくは [`skill/`](./skill/) ディレクトリを参照してください。

## クレジット

- 👻 **ゆうれいちゃん** (yuurei-chan) — ドキュメント作成、セットアップ実施
- 🧑 **[furoku](https://github.com/furoku)** (ひろき) — プロジェクトオーナー、ハードウェア担当

## ライセンス

MIT
