# 実装引き継ぎ書 — cmux Windows 対応 Phase 2〜3

作成: 2026-07-23(spec-loop 凍結時 / Fable 5)
対象読者: **会話文脈ゼロの新規セッション(既定モデル Sonnet)**。この文書だけで実行できる。

## 0. 必読ファイル(この順で読む)

1. `<project-root>\ROADMAP.md` — **環境メモ・ビルド再現手順(env 設定)の正**。本書には重複記載しない。
2. `<project-root>\spec\spec.md` — 凍結仕様(決定 D1〜D10・フェーズ完了条件・未検証6点)。
3. (判断に迷ったら)`<project-root>\spec\decisions.md` — 決定理由と捨てた選択肢。

## 1. 境界(必ず守る)

**触ってよいもの**
- `my-cmux\cmux\` — ただし **windows-port ブランチ上でのみ**(Step 2a-1 で作成)
- `my-cmux\bin\`(新設)・`my-cmux\docs\`(新設)・`my-cmux\samples\`(新設)・`my-cmux\README.md`(新設)
- `my-cmux\ROADMAP.md` — チェックボックスと最終更新の追記のみ
- `%APPDATA%\cmux\cmux-tui.json`(必要になった場合のみ)
- Windows Terminal の settings.json — **プロファイル1件の追加のみ。編集前にバックアップ必須**(Step 2d-1)

**触ってはいけないもの**
- `my-cmux\cmux-main\` — 参照専用の zip 展開物
- `my-cmux\cmux` の `main` ブランチ(コミットしない)・リモートへの push(一切しない)
- `my-cmux\spec\spec.md` / `decisions.md` — 凍結済み。変更が必要になったら作業を止めてユーザーに確認(新しい spec-loop ラン扱い)
- システム/ユーザーの環境変数(`EDITOR` 等は**ランチャスクリプト内のみ**で設定する)

**運用**
- 各ステップの「完了条件」はコマンドの exit code / 実ファイルで確認してから次へ進む。
- 同じエラーへの修正が2回失敗したら3回目の変種を試さず、§6 の Fable 委譲ポイントに該当すれば発動、しなければユーザーに報告する。
- フェーズ完了ごとに ROADMAP.md のチェックボックスを更新する。
- 「ユーザー確認」と記したステップは対話 TUI の実操作が必要なため自動化しない。チェックリストを提示し、ユーザーの pass 報告をもって完了とする。

## 2. Phase 2a — フォーク固定化+release ビルド

### 2a-1. windows-port ブランチ作成+パッチコミット
```powershell
git -C <project-root>\cmux status --porcelain
```
- 期待: ` M cmux-tui/crates/ghostty-vt-sys/build.rs` の1行のみ。**他の差分があれば止めてユーザー報告**。
```powershell
git -C <project-root>\cmux switch -c windows-port
git -C <project-root>\cmux add cmux-tui/crates/ghostty-vt-sys/build.rs
git -C <project-root>\cmux commit -m "windows-port: always pass -Dtarget to zig (fixes WindowsSdkNotFound on gnu-hosted Windows)"
```
- 完了条件: `git -C ...\cmux log --oneline -1` に上記コミットが表示され、`git -C ...\cmux status --porcelain` が空、`git -C ...\cmux branch --show-current` が `windows-port`。

### 2a-2. release ビルド
- ROADMAP.md「ビルド再現手順」の env 設定(PATH / LIBCLANG_PATH / BINDGEN_EXTRA_CLANG_ARGS)を**同一 PowerShell 呼び出し内で**設定してから:
```powershell
cargo build -p cmux-tui --release --target x86_64-pc-windows-gnu --locked
```
- ビルドは `run_in_background` で回してよい(数分かかる)。
- 完了条件: exit 0。`Test-Path <project-root>\cmux\cmux-tui\target\x86_64-pc-windows-gnu\release\cmux-tui.exe` が True。
- ビルド失敗が2回続いたら → 委譲ポイント F1。

### 2a-3. exe 配置+クリーン環境起動検証(未検証事項 #2 #3 の消し込み)
```powershell
New-Item -ItemType Directory -Force <project-root>\bin
Copy-Item <project-root>\cmux\cmux-tui\target\x86_64-pc-windows-gnu\release\cmux-tui.exe <project-root>\bin\cmux-tui.exe
```
- **新しいツール呼び出しで**(= ビルド用 PATH 設定を引き継がない素の状態で):
```powershell
& <project-root>\bin\cmux-tui.exe --version
```
- 完了条件: 出力 `cmux-tui 0.1.0`、`$LASTEXITCODE` = 0。DLL 不足エラー(`libgcc_s_seh-1.dll` 等)が出たら → 委譲ポイント F1。

## 3. Phase 2b — TUI 対話動作の検証(要望①、未検証事項 #1)

### 2b-1. 既定キーバインドの抽出(マニュアルの材料を兼ねる)
- `my-cmux\cmux\cmux-tui\crates\cmux-tui\src\config.rs`(冒頭のスキーマコメントと `keys` のデフォルト定義)と `my-cmux\cmux\cmux-tui\docs\` 配下の md を読み、既定キーバインド(prefix、タブ作成、ペイン分割、フォーカス移動、ペイン/タブを閉じる、サイドバー表示切替、sidebar_files 内の Enter / `o`、browser 操作)を一覧化する。
- 成果物: `my-cmux\docs\keybindings.md`(表形式。**コードから読み取った実物のみ**を書く。推測で書かない)。
- 完了条件: 上記ファイルが存在し、少なくとも prefix・新タブ・分割・フォーカス移動・サイドバー切替・Enter・`o` の実キーが埋まっている。

### 2b-2. 対話動作チェック(ユーザー確認)
- ユーザーに Windows Terminal で `<project-root>\bin\cmux-tui.exe` の起動を依頼し(この時点ではランチャ未作成のため直接起動でよい)、keybindings.md に基づく具体キー付きチェックリストを提示する:
  1. TUI が描画される(画面崩れなし) 2. 新タブ作成 3. ペイン分割 4. ペイン間フォーカス移動 5. ペイン内でシェル(pwsh)が動く(`dir` 等) 6. ペイン/タブを閉じる 7. 正常終了できる
- 完了条件: 全項目 pass のユーザー報告。描画崩れ・入力不能などの根本問題が出たら → 委譲ポイント F2。

## 4. Phase 2c — 要望②③の成立(未検証事項 #4 #5 #6)

### 2c-1. micro 導入
```powershell
winget install --id zyedidia.micro -e --accept-source-agreements --accept-package-agreements
```
- id が見つからない場合は `winget search micro` で確認してから入れ直す。
- 完了条件: **新しいツール呼び出しで** `micro --version` が exit 0(PATH 反映のため新シェルで確認)。PATH に載らない場合は実体パスを特定し 2c-2 のランチャで `EDITOR` にフルパスを設定する。

### 2c-2. ランチャスクリプト作成
- `<project-root>\bin\cmux.ps1` を作成:
```powershell
# cmux-tui ランチャ: 環境変数はこのプロセス内でのみ設定する
$env:EDITOR = "micro"
& "$PSScriptRoot\cmux-tui.exe" @args
```
- 完了条件: `powershell -NoLogo -ExecutionPolicy Bypass -File ...\bin\cmux.ps1 --version` が `cmux-tui 0.1.0` / exit 0。

### 2c-3. コード閲覧の検証(ユーザー確認)
- ユーザーにランチャ経由で起動してもらい、チェックリスト提示: sidebar_files を開く → `my-cmux` 配下へ移動 → 適当な `.md` / `.rs` を Enter → micro が新規タブで開く → 編集して Ctrl+S 保存 → Ctrl+Q で閉じる。
- 完了条件: 全項目 pass。micro が開かない場合、`EDITOR` の伝播(ランチャ→cmux-tui→PTY 子プロセス)を疑い、フルパス設定を試す(2回失敗で報告)。

### 2c-4. HTML プレビューの検証(ユーザー確認)
- テスト用 HTML を作成: `my-cmux\samples\preview-test.html`(見出し・色付き要素など目視確認しやすい内容)。
- チェックリスト提示: sidebar_files で preview-test.html を選択 → `o` キー → headful Chrome の実ウィンドウにページが表示される。
- 完了条件: Chrome 実ウィンドウでの表示をユーザーが確認。TUI ペイン側は「kitty graphics 非対応」表示のままで**正常**(spec.md D3 のとおり)。CDP 接続失敗が2回の修正で解けなければ → 委譲ポイント F3。

## 5. Phase 2d — 配布導線

### 2d-1. Windows Terminal プロファイル追加
- settings.json の場所を特定(通常 `%LOCALAPPDATA%\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json`。見つからなければ `Get-ChildItem "$env:LOCALAPPDATA\Packages" -Filter "Microsoft.WindowsTerminal*"` で探す)。
- **編集前にバックアップ**: 同ディレクトリに `settings.json.bak-YYYYMMDD` としてコピー。
- `profiles.list` に追加(JSON として正しく挿入し、既存プロファイルを壊さない):
```json
{
  "name": "cmux",
  "commandline": "powershell.exe -NoLogo -ExecutionPolicy Bypass -File C:\\Users\\user\\Documents\\claude-projects\\my-cmux\\bin\\cmux.ps1",
  "startingDirectory": "C:\\Users\\user\\Documents\\claude-projects"
}
```
- 完了条件: 編集後の settings.json が `ConvertFrom-Json` でパース成功。ユーザーが WT の新規タブメニューから「cmux」を選んで起動できることを確認(ユーザー確認)。

## 6. Phase 3 — 受け入れ検証・ドキュメント・引き渡し

### 3-1. 一気通貫シナリオ(ユーザー確認)
- WT の「cmux」プロファイルで起動 → ペイン分割して片方でシェル作業 → sidebar_files でコードを micro で開く → `o` で HTML を Chrome プレビュー → 全て同一セッション内で成立。
- 完了条件: シナリオ全体のユーザー pass 報告。

### 3-2. README 作成
- `my-cmux\README.md`: プロジェクト概要(何をどう Windows 対応したか、spec\spec.md への参照)/ 起動方法(WT プロファイル or `bin\cmux.ps1`)/ ディレクトリ構成(cmux=フォーク windows-port、cmux-main=参照専用、bin、docs、spec)/ ビルド再現は ROADMAP.md 参照、の4点を含む。
- 完了条件: 上記4点を含む README.md が存在する。

### 3-3. HTML マニュアル作成(D10)
- `my-cmux\docs\manual.html`。要件:
  - 単一 HTML・外部リソース依存なし。冒頭に目次があり、**アンカーリンクで各項目へページ内遷移できる**こと(ユーザー明示要望)。
  - 項目: ①起動方法 ②ターミナル多重化の基本操作(2b-1 の keybindings.md から実キー表を転載)③コード閲覧(sidebar_files+micro、Ctrl+S/Ctrl+Q)④HTML プレビュー(`o` キー→Chrome)⑤設定(`%APPDATA%\cmux\cmux-tui.json` の場所と keys の変え方)⑥トラブルシュート(Chrome が見つからない/micro が開かない/ビルド再現は ROADMAP.md 参照)。
  - **Phase 2 で実機検証済みの挙動のみを書く**。未検証の推測を書かない。
- 完了条件: ブラウザで開けて目次リンクが全項目へ遷移し、キー表が keybindings.md と一致する。

### 3-4. ROADMAP.md 更新+任意タスク
- Phase 2/3 のチェックボックスを実績どおり更新し「最終更新」を書き換える。
- 任意タスク(完了条件外・D8): `my-cmux\spec\upstream-issue-draft.md` に build.rs 問題の issue 下書き(英語、現象=`WindowsSdkNotFound`・原因=target==host 時に `-Dtarget` を渡さない・パッチ内容=windows-port ブランチのコミット参照)を作成。**起票はしない**(判断はユーザー)。

## 7. Fable への委譲ポイント(発動条件と依頼文)

発動方法: Agent ツールで `model: "fable"` のサブエージェントを起動し、下記依頼文に実際のエラーログ全文を添えて渡す。委譲は該当条件を満たしたときのみ(乱発しない)。

- **F1(ビルド/DLL)** 発動条件: 2a-2 のビルド失敗が2回継続、または 2a-3 で DLL 依存エラー。
  依頼文: 「cmux-tui の Windows release ビルド(x86_64-pc-windows-gnu)で失敗しています。`<project-root>\ROADMAP.md` のビルド再現手順(debug では 2026-07-23 に成功実績あり)と spec\spec.md の D1/D6 を前提に、添付エラーログの根本原因を特定し、再現可能な修正手順を提示してください。build.rs の追加変更が必要な場合は windows-port ブランチへのコミット内容まで具体化してください。」
- **F2(TUI 対話動作の根本問題)** 発動条件: 2b-2 で描画崩れ・入力不能など、設定変更で直らない根本問題。
  依頼文: 「Windows Terminal 上の cmux-tui(ratatui+crossterm、ConPTY)で対話動作に根本問題が出ています(症状の詳細とスクリーンショットを添付)。my-cmux\cmux(windows-port ブランチ)のコードを調査し、原因の切り分け(端末側/crossterm/cmux-tui 実装)と、最小の修正方針または回避策を提示してください。spec\spec.md の非スコープ(大規模な機能追加はしない)を守ってください。」
- **F3(browser pane / CDP)** 発動条件: 2c-4 で CDP 接続失敗が2回の修正で解決しない。
  依頼文: 「cmux-tui の browser pane が Windows で Chrome への CDP 接続に失敗します(エラーログ添付)。cmux-tui-core/src/browser.rs・platform.rs の chrome 探索/起動ロジックと cmux-tui-cdp/src/chrome.rs を調査し、原因特定と修正手順を提示してください。前提: Chrome はインストール済み、headful 運用(spec\spec.md D3)。」

## 8. 全体の完了定義

spec.md のフェーズ完了条件(2a〜2d, 3)がすべて満たされ、ROADMAP.md の Phase 2/3 チェックボックスが実績で埋まり、ユーザーが一気通貫シナリオ(3-1)を pass と報告していること。
