# cmux-windows-port

macOS 専用の [cmux](https://github.com/manaflow-ai/cmux)(manaflow-ai/cmux)のうち、
Rust 製 TUI マルチプレクサ **`cmux-tui`** を **Windows 11 でネイティブに動かす**ための
**パッチ集+ビルド/利用手順**です。次の3点を実機で成立させています:

1. **ターミナル多重化** — Windows Terminal 上で cmux-tui を動かし、タブ/ペイン分割/フォーカス移動
2. **コード閲覧** — ファイルサイドバー(sidebar_files)からコードを CLI エディタ **micro** で開く
3. **HTML プレビュー** — sidebar_files の `o` キーで HTML を **headful Chrome の実ウィンドウ**に表示

> **スコープ**: Swift 本体(macOS アプリ)は移植対象外です。Windows で動くのは `cmux-tui`(Rust)のみです。
> 決定の背景・捨てた選択肢は [`spec/spec.md`](spec/spec.md) / [`spec/decisions.md`](spec/decisions.md)(いずれも凍結済み)を参照してください。

## ライセンスと帰属(必読)

- 本リポジトリは全体を **GPL-3.0-or-later** で提供します(全文は [`LICENSE`](LICENSE))。
- 本家 cmux は **© 2024–present Manaflow, Inc.** / **GPL-3.0-or-later**。本リポジトリは
  **本体ソース・バイナリを一切同梱しません**。同梱するのは upstream に当てる **パッチ(派生物)** と
  独自ドキュメントのみです。
- **"cmux" / "Manaflow" は各権利者の名称・商標**で、本プロジェクトは **非公式**(Manaflow 社とは
  無関係・非提携)です。詳細は [`NOTICE.md`](NOTICE.md)。
- パッチ `0001`(ビルド不能の修正)は upstream に **manaflow-ai/cmux#8904** として報告済みです。

## このリポジトリの中身

本体は同梱せず、upstream の特定コミットに当てる **3つのパッチ**で Windows 対応を行います
(いずれも Unix 側の挙動は変えません)。

| パッチ | 対象ファイル | 内容 |
|---|---|---|
| `0001` | `ghostty-vt-sys/build.rs` | zig へ常に `-Dtarget` を渡す(GNU ホスト環境の `WindowsSdkNotFound` を回避) |
| `0002` | `ui/graphics.rs` | Windows では端末ケイパビリティのクエリ(DA1/ピクセルサイズ)を送らない(起動時プロンプトへの応答漏れを解消) |
| `0003` | `sidebar_files/mod.rs` | Windows パスから正しい `file:///C:/…` を組み立てる(ブラウザプレビューの空白表示と CDP タイムアウトを解消) |

## パッチを当ててビルドする

### 前提ツール(検証済みの構成)

MSVC Build Tools は不要です。GNU ホストの Rust ツールチェーンでビルドします。

| ツール | 備考 |
|---|---|
| rustup / cargo | **GNU ホスト**。ターゲット `x86_64-pc-windows-gnu` を追加(`rustup target add x86_64-pc-windows-gnu`) |
| zig 0.15.2 | libghostty-vt を zig でビルドするため必須 |
| LLVM / libclang 20.x | bindgen が使用(`LIBCLANG_PATH` に `bin` を指す) |
| MSYS2 mingw64 | `dlltool` / `as` / `gcc`(`C:\msys64\mingw64\bin`)。winget で導入可 |

### 手順(PowerShell)

```powershell
# 1) upstream を「パッチのベースコミット」で取得(ghostty は submodule なので --recursive 必須)
git clone --recursive https://github.com/manaflow-ai/cmux.git
cd cmux
git checkout 7652d3b1cf        # パッチはこのコミットの上に当てる

# 2) このリポジトリの patches/ を順に適用(作者情報付きで当てるなら git am)
git am /path/to/cmux-windows-port/patches/0001-*.patch `
       /path/to/cmux-windows-port/patches/0002-*.patch `
       /path/to/cmux-windows-port/patches/0003-*.patch
#   コミット履歴が不要なら:  git apply /path/to/.../patches/000*.patch

# 3) ビルド用の環境変数(この呼び出し内でのみ設定)
$llvm = "$env:USERPROFILE\tools\clang+llvm-20.1.8-x86_64-pc-windows-msvc"   # 実際の LLVM 展開先に合わせる
$env:PATH = "$env:USERPROFILE\.cargo\bin;$env:USERPROFILE\tools\zig-x86_64-windows-0.15.2;C:\msys64\mingw64\bin;$env:PATH"
$env:LIBCLANG_PATH = "$llvm\bin"
# bindgen の libclang はビルトインヘッダと MinGW sysroot を自己検出できないため明示する(必須の回避策):
$env:BINDGEN_EXTRA_CLANG_ARGS = "--target=x86_64-pc-windows-gnu --sysroot=C:/msys64/mingw64 -resource-dir $llvm/lib/clang/20 -isystem $llvm/lib/clang/20/include"

# 4) release ビルド
cd cmux-tui
cargo build -p cmux-tui --release --target x86_64-pc-windows-gnu --locked
# 成果物: target\x86_64-pc-windows-gnu\release\cmux-tui.exe(自己完結・外部 DLL 依存なし)
```

> **補足**: パッチ `0001` は上記 `build.rs` の修正そのものです(GNU ホスト = ターゲットのとき zig が
> MSVC ABI を選び `WindowsSdkNotFound` で失敗するのを防ぐ)。残る必須の回避策は手順3の
> `BINDGEN_EXTRA_CLANG_ARGS` のみです。ビルドは数分かかります。

## 実行する

1. ビルドした `cmux-tui.exe` を、このリポジトリの **`bin/` 直下**にコピーします
   (`bin/cmux.ps1` は同じフォルダの `cmux-tui.exe` を起動します)。
2. **コード閲覧(要望②)用**に micro を導入: `winget install --id zyedidia.micro -e`
   (`bin/cmux.ps1` が **このプロセス内だけで** `EDITOR=micro` を解決して起動します。PATH に無くても
   winget の配置から版非依存で探します。システム/ユーザー環境変数は汚しません)。
3. **HTML プレビュー(要望③)用**に Chrome をインストール済みにしておきます(headful 表示)。

### 起動

```powershell
powershell -NoLogo -ExecutionPolicy Bypass -File \path\to\cmux-windows-port\bin\cmux.ps1
```

別セッションで起動するときは `--session <名>` を付けます(共有セッションモデルの詳細はマニュアル参照)。

**任意: Windows Terminal からワンクリック起動** — `settings.json` の `profiles.list` に次を追加すると、
新規タブメニューから「cmux」で起動できます(**編集前にバックアップ必須**):

```json
{
  "name": "cmux",
  "commandline": "powershell.exe -NoLogo -ExecutionPolicy Bypass -File C:\\path\\to\\cmux-windows-port\\bin\\cmux.ps1"
}
```

**操作方法・キーバインド・トラブルシュートは HTML マニュアルを参照** → [`docs/manual.html`](docs/manual.html)(ブラウザで開く)。
既定キーバインドの一覧は [`docs/keybindings.md`](docs/keybindings.md)(コードから抽出した実物)。

## ディレクトリ構成

```
cmux-windows-port/
├─ README.md            ← このファイル
├─ LICENSE              ← GPL-3.0-or-later 全文
├─ NOTICE.md            ← 帰属・商標・本体非同梱の明記
├─ .gitignore
├─ bin/
│  └─ cmux.ps1          ← 起動ランチャ(EDITOR=micro を解決して cmux-tui.exe を起動)
├─ patches/
│  ├─ 0001-*.patch      ← build.rs(WindowsSdkNotFound 回避)
│  ├─ 0002-*.patch      ← graphics.rs(端末クエリ抑止)
│  └─ 0003-*.patch      ← sidebar_files(file:/// URL 生成)
├─ docs/
│  ├─ manual.html       ← 利用マニュアル(単一 HTML・目次アンカー遷移)
│  └─ keybindings.md    ← 既定キーバインド一覧(コードから抽出)
├─ samples/
│  └─ preview-test.html ← HTML プレビュー動作確認用サンプル
└─ spec/                ← 凍結済み仕様
   ├─ spec.md           ← 凍結仕様(決定 D1〜D10)
   ├─ decisions.md      ← 決定理由と捨てた選択肢
   ├─ handoff.md        ← 実装引き継ぎ書
   ├─ review.html       ← 仕様レビュー記録
   └─ upstream-issue-draft.md ← upstream 報告(#8904)の下書き
```

> **注**: `bin/cmux-tui.exe`(ビルド生成物=GPL バイナリ)は同梱しません。上記手順でビルドして
> `bin/` に配置してください。
