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

本体は同梱せず、upstream の特定コミットに当てる **9つのパッチ**で Windows 対応を行います
(いずれも Unix 側の挙動は変えません)。`0001`〜`0003` は Phase 2/3(要望①②③の基本実装)、
`0004`〜`0005` は Phase 4(実機での利用を通じて追加した UX 改善ラウンド)、`0006` は Phase 5
(起動時ディレクトリ指定)、`0007`〜`0009` は Phase 6(タブバーのUX改善+バグ修正)です。詳細な
変更点は[更新履歴](#更新履歴)を参照してください。

| パッチ | 対象ファイル | 内容 |
|---|---|---|
| `0001` | `ghostty-vt-sys/build.rs` | zig へ常に `-Dtarget` を渡す(GNU ホスト環境の `WindowsSdkNotFound` を回避) |
| `0002` | `ui/graphics.rs` | Windows では端末ケイパビリティのクエリ(DA1/ピクセルサイズ)を送らない(起動時プロンプトへの応答漏れを解消) |
| `0003` | `sidebar_files/mod.rs` | Windows パスから正しい `file:///C:/…` を組み立てる(ブラウザプレビューの空白表示と CDP タイムアウトを解消) |
| `0004` | `mux.rs`/`session/mod.rs`/`app.rs`/`sidebar_files/*`/`ui/graphics.rs`ほか | Phase 4 UX改善ラウンド: サイドバーの複数フォルダ同時展開・ファイルを右の新規ペインで開く・Sixel HTML プレビュー(opt-in)・`/copy`貼り付け時の改行暴発修正ほか |
| `0005` | `app.rs`/`sidebar_files/mod.rs`/`ui/sidebar.rs` | Phase 4 follow-ups: スクロール位置保持の修正・マウスホイール対応・フォルダ▸クリックでの展開/折りたたみ・ファイルのダブルクリックオープン |
| `0006` | `main.rs` | 起動時に `--cwd <path>` または位置引数で新規ペインの開始ディレクトリを指定できるようにする(既定はホームディレクトリ) |
| `0007` | `app.rs`/`config.rs`/`ui/pane.rs` | タブがペイン幅に入りきらないとき、タブバーを動的に2段化(設定 `tabs.max_rows`、既定2) |
| `0008` | `mux.rs`/`session/mod.rs`/`app.rs`/`ui/pane.rs`/`config.rs` | sidebar_files から開いたエディタタブにファイル名を表示、ラベル文字数上限を設定 `tabs.max_width` 化(既定24) |
| `0009` | `app.rs`/`config.rs` | `0007` のバグ修正: 2段化したタブバーで新規タブ/split作成時に content 高さが1行ズレる不整合を修正、`tabs.max_width` を4〜200にclamp(codexの第三者レビューで検出) |

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
       /path/to/cmux-windows-port/patches/0003-*.patch `
       /path/to/cmux-windows-port/patches/0004-*.patch `
       /path/to/cmux-windows-port/patches/0005-*.patch `
       /path/to/cmux-windows-port/patches/0006-*.patch `
       /path/to/cmux-windows-port/patches/0007-*.patch `
       /path/to/cmux-windows-port/patches/0008-*.patch `
       /path/to/cmux-windows-port/patches/0009-*.patch
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

起動時に作業ディレクトリを固定したい場合は、`commandline` の末尾にパスを追記します(`0006` の
`--cwd`/位置引数。`bin/cmux.ps1` は受け取った引数をそのまま `cmux-tui.exe` へ渡します):

```json
{
  "name": "cmux (my-project)",
  "commandline": "powershell.exe -NoLogo -ExecutionPolicy Bypass -File C:\\path\\to\\cmux-windows-port\\bin\\cmux.ps1 C:\\path\\to\\my-project"
}
```

### パッチ追加後に `cmux-tui.exe` を更新する

新しいパッチを取り込んでも **Windows Terminal の `settings.json` は変更不要**です。
`bin/cmux.ps1` は常に「同じフォルダの `cmux-tui.exe`」を起動する固定エントリポイントなので、
入れ替えるのは実行ファイルだけで済みます。

1. ローカルの upstream clone で、追加分まで `git am`/`git apply` を当て直す(前掲コマンド参照)
2. 前提ツール・release ビルドの手順(3・4)を再実行
3. 生成された `target\x86_64-pc-windows-gnu\release\cmux-tui.exe` を、このリポジトリの
   `bin\cmux-tui.exe` に上書きコピー

Windows Terminal は次にタブを開いたときから新しい exe を使います(プロファイルの再作成や
ターミナル自体の再起動は不要)。

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
│  ├─ 0003-*.patch      ← sidebar_files(file:/// URL 生成)
│  ├─ 0004-*.patch      ← Phase 4 UX改善ラウンド(複数フォルダ展開・右split新規ペイン・Sixelプレビュー等)
│  ├─ 0005-*.patch      ← Phase 4 follow-ups(スクロール修正・マウスホイール・▸クリック展開・ダブルクリック)
│  ├─ 0006-*.patch      ← 起動時 --cwd/位置引数で開始ディレクトリ指定
│  ├─ 0007-*.patch      ← タブバー2段化(tabs.max_rows)
│  ├─ 0008-*.patch      ← エディタタブのファイル名表示(tabs.max_width)
│  └─ 0009-*.patch      ← 0007のバグ修正(2段タブバーの content 高さ不整合・max_widthのclamp)
├─ docs/
│  ├─ manual.html       ← 利用マニュアル(単一 HTML・目次アンカー遷移)
│  └─ keybindings.md    ← 既定キーバインド一覧(コードから抽出)
├─ samples/
│  └─ preview-test.html ← HTML プレビュー動作確認用サンプル
└─ spec/                ← 凍結済み仕様
   ├─ spec.md / decisions.md / handoff.md      ← Phase 2/3 仕様一式(決定 D1〜D10)
   ├─ review.html                              ← Phase 2/3 仕様レビュー記録
   ├─ handoff-phase4.md                        ← Phase 4 実装引き継ぎ書
   ├─ spec-tab-multirow.md 他3点               ← Phase 6(0007)仕様一式(spec/decisions/handoff/review)
   ├─ spec-tab-filename.md 他3点               ← Phase 6(0008)仕様一式(spec/decisions/handoff/review)
   └─ upstream-issue-draft.md ← upstream 報告(#8904)の下書き
```

> **注**: `bin/cmux-tui.exe`(ビルド生成物=GPL バイナリ)は同梱しません。上記手順でビルドして
> `bin/` に配置してください。

## 更新履歴

### Phase 6 — タブバーUX改善+バグ修正(2026-07-26、パッチ `0007`・`0008`・`0009`)

Phase 4 公開後、実機での利用を通じて次の改善を実装。仕様は spec-loop で凍結・実装・実機確認まで
完了(手順・決定経緯は [`spec/spec-tab-multirow.md`](spec/spec-tab-multirow.md) /
[`spec/spec-tab-filename.md`](spec/spec-tab-filename.md) と対応する decisions/handoff/review を参照)。

- **タブバーの2段化(`0007`)** — ペイン幅にタブが入りきらないとき、タブバーを自動で2段表示に
  切り替える(設定 `tabs.max_rows`、既定2)。`1` にすると従来の1段+スクロールに戻る。2段でも
  入りきらない分は既存の `‹`/`›` スクロールを併用。タブの D&D も2段レイアウトに対応。
- **エディタタブのファイル名表示(`0008`)** — sidebar_files から開いたファイルのタブに、番号ではなく
  ファイル名を表示。ラベルの文字数上限は設定 `tabs.max_width`(既定24)で調整可能。
- **`0007` のバグ修正(`0009`)** — 2段化したペインで新規タブ/split/ブラウザタブを作成すると
  content の高さが1行ズレる不整合があり、codex の第三者レビューで検出・修正した。`tabs.max_width`
  に極端な値を設定した際の内部計算オーバーフローも同時に 4〜200 の clamp で防止。自動テストは追加
  済み(この修正自体の実機再確認は、更新版 `cmux-tui.exe` への入れ替え後に実施推奨)。
- **既知の制限(未解決)** — 複数ペインを並べた状態で、ファイル名タブを表示しているペインの
  **隣のペインを閉じて**幅が変わると、そのタブ表示が番号タブに戻ることがある(境界ドラッグのみ
  の幅変更では再現しない)。コードレビューでは該当箇所を特定できておらず、実運用で支障が出た
  場合に調査する方針で保留中。詳細は [`spec/decisions-tab-filename.md`](spec/decisions-tab-filename.md) を参照。

### Phase 5 — 起動時ディレクトリ指定(2026-07-26、パッチ `0006`)

`cmux-tui.exe` の起動時に `--cwd <path>` または位置引数で新規ペインの開始ディレクトリを指定できる
ようにした(従来はホームディレクトリ固定)。Windows Terminal のプロファイルの `commandline` に
パスを渡すことで、特定のプロジェクトフォルダに固定した起動プロファイルを作れる(具体例は
[起動](#起動)節を参照)。

### Phase 4 — UX改善ラウンド(2026-07-26、パッチ `0004`・`0005`)

Phase 2/3 公開後、実機での利用を通じて次の改善を実装。全項目、実機確認 pass 済み。

- **ファイルサイドバーのツリー表示** — 複数フォルダを同時展開できるエクスプローラー風ツリーに刷新。
  フォルダ左の `▸` クリックまたは `→`/`←` キーで展開・折りたたみ。
- **ファイルを新規ペインで開く** — サイドバーから `Enter`(または対象行のダブルクリック)でファイルを開くと、
  既存ペインを上書きせず右に新しいペインが作られてそこで開く。`o` キーでの HTML ブラウザプレビューも同様。
- **タブグループの統合** — 2つのペインのタブをマウスドラッグで1つのタブグループへ統合できる。
- **HTML の in-TUI プレビュー(opt-in)** — `browser.sixel: true` を設定すると、Windows Terminal の
  Sixel 対応を使って HTML を TUI ペイン内で直接プレビューできる(既定は無効。既定の headful Chrome
  プレビューはそのまま利用可能)。
- **`Ctrl+B` → `Shift+S` でサイドバーにフォーカスできない件** — 実装のバグではなく、`Ctrl+B` 連続押下時の
  tmux 互換挙動・`focus-sidebar` のトグル仕様・日本語 IME が影響することが判明。
  [`docs/keybindings.md`](docs/keybindings.md) に注記済み。
- そのほか: `Alt+X` でペイン/タブを閉じる、サイドバーに全ペイン×全タブのタイトル一覧を集約表示、
  `/copy` 貼り付け時に改行のたびに途中送信されていた問題の修正、ファイルサイドバーのマウスホイール
  スクロール対応。

詳細な調査・実装経緯は [`spec/handoff-phase4.md`](spec/handoff-phase4.md) を参照。

### Phase 2/3 — 初期実装(2026-07-25、パッチ `0001`〜`0003`)

要望①②③(ターミナル多重化・コード閲覧・HTML プレビュー)の基本実装と受け入れ検証。
詳細は [`spec/spec.md`](spec/spec.md) / [`spec/handoff.md`](spec/handoff.md)。
