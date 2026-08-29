# WSL Smart Home Camera 📷🏠

**WSL2 + USBカメラ + Nature Remoで、AIエージェントが部屋の状態を確認し、家電を操作するための参考ガイドです。**

このリポジトリは、USBカメラで撮影した画像をAIが分析し、Nature Remo API経由で照明・エアコン・テレビなどを操作したうえで、もう一度撮影して結果を確認する流れをまとめています。

> **Status:** 実環境で行ったセットアップをもとにした実験・参考実装です。完成済みの製品や、そのまま本番運用できるセキュリティ監査済みパッケージではありません。

## 最初に確認する安全上の境界

- カメラ画像には、人物・室内・生活時間などの個人情報が写る可能性があります
- `camera.jpg`、`state.json`、`diff.md`などの実運用データは、この公開リポジトリへコミットしないでください
- 履歴をGitで残す場合は、ローカルのみ、またはアクセスを制限した**非公開リポジトリ**を使用してください
- Nature Remoのアクセストークンを、README、ログ、Issue、コミットへ貼らないでください
- 家電操作は誤動作する可能性があります。高温・低温、火気、防犯、生命や財産に関わる操作をAIだけへ任せないでください
- 自動化する場合も、実行回数、対象家電、停止条件、操作後の確認を明示してください

## 構成

```text
┌─────────────────────────────────────────────┐
│ Windows PC                                  │
│  ┌────────────┐      ┌───────────────────┐  │
│  │ USB Camera │ ───▶ │ WSL2 / Ubuntu     │  │
│  └────────────┘      │  ┌─────────────┐  │  │
│      usbipd-win      │  │ AI Agent    │  │  │
│                      │  └──────┬──────┘  │  │
│                      └─────────┼─────────┘  │
└────────────────────────────────┼────────────┘
                                 │ HTTPS
                     ┌───────────▼────────────┐
                     │ Nature Remo Cloud API  │
                     └───────────┬────────────┘
                                 │ IR
                     ┌───────────▼────────────┐
                     │ 照明 / エアコン / TV   │
                     └────────────────────────┘
```

## できること

- USBカメラで部屋を撮影する
- AIで照明、人の在・不在、室内の変化などを参考分析する
- Nature Remo APIで家電を操作する
- 操作後に再撮影し、実際に状態が変わったか確認する
- 最新状態と前回との差分を、ローカルのGit履歴として残す

## 必要なもの

| 項目 | 内容 |
| --- | --- |
| OS | Windows 10 / 11 + WSL2（Ubuntu） |
| カメラ | USB Webカメラ |
| スマートリモコン | Nature Remo |
| ツール | `usbipd-win`、`ffmpeg` |
| AIエージェント | OpenClawまたは同等の仕組み |

## セットアップ

### 1. usbipd-winを入れる

管理者権限のWindows PowerShellで実行します。

```powershell
winget install --id dorssel.usbipd-win
```

インストール後にUACダイアログが表示された場合は、内容を確認して許可します。

### 2. USBカメラをWSLへ接続する

```powershell
# Windows PowerShell（管理者）
usbipd list

# 初回だけ共有を許可
usbipd bind --busid 1-3

# WSLへ接続
usbipd attach --wsl --busid 1-3
```

`1-3`は例です。`usbipd list`に表示された実際のBUSIDへ置き換えてください。

WSL側では、まず現在のユーザーを`video`グループへ追加する方法を推奨します。

```bash
sudo usermod -aG video "$USER"
```

反映にはログアウトまたはWSLの再起動が必要です。撮影テストのために一時的に権限を緩める場合でも、共有PCや常用環境で`chmod 666`を恒久運用しないでください。

### 3. ffmpegを入れる

```bash
sudo apt install -y ffmpeg
```

### 4. 撮影を確認する

```bash
ffmpeg -f v4l2 -input_format mjpeg -video_size 1920x1080 \
  -i /dev/video0 -frames:v 1 -update 1 /tmp/camera.jpg -y
```

Windowsから確認する場合の例:

```text
\\wsl$\Ubuntu\tmp\camera.jpg
```

### 5. Nature Remoトークンを保存する

1. Nature RemoのWeb画面でアクセストークンを発行します
2. トークンはリポジトリ外の、権限を制限したファイルへ保存します

```bash
mkdir -p ~/.config/nature-remo
printf '%s' 'YOUR_TOKEN_HERE' > ~/.config/nature-remo/token
chmod 600 ~/.config/nature-remo/token
```

トークンの中身を画面共有、ログ、AIへの入力、Git差分へ出さないでください。

### 6. 接続と操作を確認する

家電一覧を取得します。

```bash
TOKEN=$(cat ~/.config/nature-remo/token)
curl -s -H "Authorization: Bearer $TOKEN" \
  https://api.nature.global/1/appliances | python3 -m json.tool
```

照明操作の例:

```bash
TOKEN=$(cat ~/.config/nature-remo/token)

curl -s -X POST \
  "https://api.nature.global/1/appliances/{APPLIANCE_ID}/light" \
  -H "Authorization: Bearer $TOKEN" \
  -d "button=on"
```

エアコン操作の例:

```bash
curl -s -X POST \
  "https://api.nature.global/1/appliances/{APPLIANCE_ID}/aircon_settings" \
  -H "Authorization: Bearer $TOKEN" \
  -d "operation_mode=warm&temperature=26"
```

`APPLIANCE_ID`や操作パラメータは、取得した家電情報と実機の設定に合わせてください。

## 操作後に必ず確認する

Nature Remoの赤外線信号は、遮蔽物、距離、家電の状態などによって届かない場合があります。APIが成功を返しただけで完了とせず、次の確認ループを使います。

```text
1. 撮影して現在の状態を確認
2. 必要な操作を決める
3. Nature Remo APIで操作
4. 再撮影する
5. 画像またはセンサーで結果を確認
6. 確認できない場合は停止し、むやみに連続実行しない
```

## よくある問題

### usbipdが見つからない

インストール直後はPATHが反映されていない場合があります。新しいPowerShellを開くか、フルパスで確認します。

```powershell
& "C:\Program Files\usbipd-win\usbipd.exe" list
```

### bind / attachでAccess deniedになる

`bind`は管理者権限のPowerShellで実行します。

### カメラを動かしたあと`/dev/video0`が消えた

USBの再接続後は、Windows側で`usbipd attach`をやり直します。

### WSL再起動後にカメラが見えない

`usbipd`の接続はセッション単位です。再起動後は再度attachします。自動化する場合も、対象BUSIDと停止条件を固定してください。

### Permission deniedになる

`video`グループへの所属を確認します。

```bash
id
ls -l /dev/video*
```

### 画像が紫色・マゼンタになる

カメラが対応している場合は、`-input_format mjpeg`を明示します。

### 画像が上下逆になる

設置方向に応じて`vflip`を追加します。

```bash
ffmpeg -f v4l2 -input_format mjpeg -video_size 1920x1080 \
  -i /dev/video0 -frames:v 1 -vf "vflip" -update 1 /tmp/camera.jpg -y
```

### 対応フォーマットを確認したい

```bash
ffmpeg -f v4l2 -list_formats all -i /dev/video0
```

## 定点観測をGitで残す場合

実運用データは、この公開ガイドとは別の場所へ保存します。

```text
camera.jpg  # 最新画像。公開リポジトリへ入れない
state.json  # 現在状態。生活パターンを含み得る
 diff.md    # 前回との差分。人物や在宅情報を含み得る
```

例となる流れ:

```text
撮影 → AI分析 → 状態更新 → 前回との差分確認 → ローカルcommit
```

Gitを使う利点は、最新ファイルを小さく保ちながら差分を追えることです。ただし、履歴には削除前の情報も残ります。誤って公開した場合は、通常のファイル削除だけでは履歴から消えません。

運用前に次を確認してください。

```bash
git remote -v
git status
```

リモートが公開設定でないこと、画像・状態ファイルが意図せず追跡されていないことを確認します。

## OpenClawスキル

このセットアップをOpenClaw向けに整理した資料は [`skill/`](./skill/) にあります。

## クレジット

- 👻 **ゆうれいちゃん** — ドキュメント作成、セットアップ支援
- 🧑 **[furoku](https://github.com/furoku)** — プロジェクトオーナー、ハードウェア担当

## ライセンス

[MIT License](LICENSE)
