# cmux Windows 対応 仕様書

状態: **凍結済み(2026-07-23)** — 以後の変更は新しい spec-loop ラン扱い
最終更新: 2026-07-23

## 未決事項(番号付き・解消したら「決定事項」へ移動)

(なし — 1〜9 すべて解消済み。1/2/4/5 は Round 1、3/6/7/9 は Round 2 でユーザー決定、8 はフェーズ分割として D9 に司令塔設計を記載。凍結ゲートでユーザーが追加した要望「README+HTML マニュアル」は D10 として決定)

## 目的

macOS 専用 cmux(manaflow-ai/cmux)の体験を Windows 11 で得る。要望は3点:

1. ターミナル多重化(cmux 的体験)を Windows で使う
2. プロジェクトのフォルダ/コードを閲覧できる
3. HTML ファイルを実画面プレビューできる

## 前提(検証済み事実 — 2026-07-23 現物確認)

環境・ビルド再現手順の正は `my-cmux\ROADMAP.md`(ここには重複記載しない)。

- **ネイティブビルド成功**: `cargo build -p cmux-tui --target x86_64-pc-windows-gnu --locked` が exit 0、`cmux-tui.exe --version` 起動確認済み。ただし回避策2点(build.rs パッチ+`BINDGEN_EXTRA_CLANG_ARGS`)が必須。TUI 対話動作・release ビルドは未検証。
- **pane(surface)種別は Pty / Browser の2種のみ**(`cmux-tui-core/src/surface.rs:360-373`)。コードビューア pane は存在しない。
- **ファイルサイドバー `sidebar_files` が実装済み**(`cmux-tui/src/sidebar_files/mod.rs`): フォルダ閲覧・フィルタ・移動。Enter で `$EDITOR`(未設定時 `vi` フォールバック — Windows では実質破綻)を新規 PTY タブとして起動。`o` で HTML/MD を browser タブで開く。ファイル内容のアプリ内表示は無い。
- **browser pane**: 既存の Chrome/Chromium/Edge/Brave を探索して CDP で起動(ダウンロード機構なし、Windows 探索パス実装済み)。既定 headful、`browser.mode: "headless"` で切替。描画は kitty graphics protocol 専用でフォールバック無し。
- **`probe_kitty_graphics()` は Unix 専用実装**(`ui/graphics.rs:187-190`、`#[cfg(not(unix))]` は常に空応答): Windows では端末の対応有無に関わらず常に「非対応」判定。**コード修正なしでは、どの端末でも in-TUI 画像は出ない**(非対応時はエラーメッセージ表示のみ。headful Chrome の実ウィンドウ自体は開く)。
- **frontends/web**: Vite 7 + React 19 + xterm.js、npm/Node ベース(Node は本機に未導入)。PTY サーフェスへの WebSocket アタッチのみで、**browser surface の表示は未実装**(プレースホルダのみ)。cmux-tui 側は `--ws <addr>` / `--ws-token` で WebSocket サーバを opt-in 起動可。
- **設定**: `%APPDATA%\cmux\cmux-tui.json`(JSON)。`keys` セクションでキーバインド上書き可(既定 tmux 準拠、prefix `ctrl+b`)。既定シェルは pwsh → powershell → cmd の順に探索。IPC は `uds_windows` で Windows 対応済み。
- **WSL2 は未導入**。導入には管理者権限+再起動=ユーザー作業が必要。Linux 版経路は未検証。
- **git 状態**: `my-cmux\cmux` は `main` = `7652d3b`(origin 追従)。未コミット差分は `cmux-tui/crates/ghostty-vt-sys/build.rs` のローカルパッチ1件のみ。submodule は clean。

## スコープ

- cmux-tui(Rust)の Windows ネイティブ動作を、既存実装の活用+最小の環境整備で成立させる(要望①②③)
- フォークの固定化(windows-port ブランチ+build.rs パッチのコミット)
- release ビルド・配布導線(ランチャ+Windows Terminal プロファイル)
- micro の導入と `EDITOR` 設定
- 受け入れ検証(要望①②③の一気通貫シナリオ)
- 利用ドキュメントの整備: README(`my-cmux\README.md`)+ HTML マニュアル(`my-cmux\docs\manual.html`、目次アンカーで項目遷移)(D10)

## 非スコープ(やらないこと)

- Swift 本体(macOS アプリ)の移植
- WSL2 経路(導入・検証とも行わない。必要が生じたら別ラン)
- kitty graphics の Windows 移植(in-TUI 画像表示)・WezTerm 導入
- コードビューア pane の自作(cmux-tui への機能追加全般)
- frontends/web の利用(Node 導入を含む)・agent-chat・daemon 等の周辺資産
- upstream への追従(rebase)。upstream への issue 起票は任意タスク(D8、下書きまで)
- キーバインドのカスタマイズ(既定の tmux 準拠のまま)

## 決定事項

理由・捨てた選択肢の詳細は `decisions.md` が正。

- **D1(Round 1)実行形態 = ネイティブのみで go**。x86_64-pc-windows-gnu、回避策2点前提(ROADMAP.md の再現手順が正)。WSL2 は今回のスコープから完全に外す(必要が生じたら別ランで再検討)。
- **D2(Round 1)要望② = sidebar_files + CLI エディタ**。既存のファイルサイドバーでフォルダ閲覧し、Enter で CLI エディタを新規ターミナルタブとして起動。TUI 内で完結。エディタは micro(D5)、設定はランチャ側(D7)。
- **D3(Round 1)要望③ = headful Chrome 実ウィンドウ**。browser pane の既定動作(既存 Chrome を CDP で headful 起動)をそのまま使う。in-TUI 画像表示(kitty graphics の Windows 移植)は**やらない**。TUI ペイン内はエラーメッセージ表示のままで許容。**2026-07-25追記(Phase 4)**: kitty graphics に限っては上記の通り却下のまま。ただし Windows Terminal stable(1.24系)が Sixel には対応済みと判明したため、`browser.sixel`設定(既定 false、opt-in)で Sixel エンコードによる in-TUI プレビューを追加実装した(`cmux-tui/src/ui/graphics.rs`)。実機での表示確認は未実施。
- **D4(Round 1)ターミナルホスト = Windows Terminal**。導入済み・追加インストール不要。D3 により端末の graphics 対応は不要。WezTerm は導入しない。
- **D5(Round 2)エディタ = micro**。winget で導入(管理者権限不要)し、`EDITOR` 環境変数に設定。設定はシステム全体でなくランチャスクリプト側で行う(D7)。
- **D6(Round 2)フォーク保守 = 一点改造・コミット固定**。`my-cmux\cmux` に main(7652d3b)からローカルブランチ `windows-port` を切り、build.rs パッチをコミットして固定。upstream 追従(fetch/rebase)はしない(必要が生じたら別ランで判断)。
- **D7(Round 2)配布/起動 = release ビルド+ランチャ+WT プロファイル**。release ビルドした exe を固定場所に配置し、`EDITOR` 等を設定する PowerShell ランチャスクリプト経由で起動。Windows Terminal に専用プロファイルを登録してワンクリック起動。
- **D8(Round 2)upstream 報告 = 任意タスクとして記載**。build.rs 問題(zig の MSVC ABI 誤選択)の issue 起票**下書き作成**までを handoff.md の低優先・任意タスクとする。完了条件には含めない。起票判断はユーザー。
- **D9(司令塔設計)フェーズ分割 = 下記「フェーズ分割と完了条件」の 2a〜2d + 3**。検証は「ビルド成立 → TUI 対話動作 → 要望②③ → 配布導線 → 一気通貫」の順に依存関係どおり積み上げる。
- **D10(凍結ゲート・ユーザー追加)ドキュメント整備 = README + HTML マニュアルを Phase 3 で作成**。README は `my-cmux\README.md`(プロジェクト概要・起動方法・ビルドは ROADMAP.md 参照)。マニュアルは `my-cmux\docs\manual.html`(単一 HTML・目次から各項目へアンカーで遷移できるナビゲーション付き)。内容は Phase 2b/2c/2d で**実機検証済みの挙動**に基づいて書く(未検証の想定を書かない)ため、作成は最後(Phase 3)に置く。

## 実現方式

- **要望①(ターミナル多重化)**: cmux-tui ネイティブ exe を Windows Terminal 上で実行。既定シェル探索(pwsh → powershell → cmd)・IPC(uds_windows)・設定パス(%APPDATA%\cmux\cmux-tui.json)は実装済みのものを使う。キーバインドは既定(tmux 準拠、prefix ctrl+b)から変更しない。
- **要望②(コード閲覧)**: sidebar_files でフォルダ閲覧 → Enter で `$EDITOR` = micro(D5)を新規 PTY タブ起動。ファイル内容の in-TUI 表示機能は追加実装しない。
- **要望③(HTML プレビュー)**: sidebar_files の `o` キー(または browser タブの URL 指定)で HTML を browser タブとして開く → headful Chrome の実ウィンドウで表示。TUI 側ペインは操作用(画像は出ない)。
- **起動導線(D7)**: PowerShell ランチャスクリプトが `EDITOR=micro` を設定して release 版 `cmux-tui.exe` を起動(環境変数はランチャ内のみで設定し、システム/ユーザー環境変数は汚さない)。Windows Terminal のプロファイルからこのランチャを呼ぶ。

## フェーズ分割と完了条件(D9 — 凍結時に ROADMAP.md Phase 2 へ転記)

依存関係順。各フェーズの完了条件は「実行コマンドと期待結果」で定義する(詳細な手順・検証コマンドは handoff.md)。

- **Phase 2a: フォーク固定化+release ビルド**
  - windows-port ブランチ作成・build.rs パッチのコミット・release ビルド。
  - 完了条件: `git log` でパッチコミットを確認でき、`cargo build -p cmux-tui --release --target x86_64-pc-windows-gnu --locked` が exit 0。**ビルド用 PATH 設定をしていない新規 PowerShell** で release 版 `cmux-tui.exe --version` が exit 0(ランタイム DLL 依存がないことの検証を兼ねる)。
- **Phase 2b: TUI 対話動作の検証(要望①)**
  - Windows Terminal 上で起動し、タブ作成/ペイン分割/フォーカス移動/シェル実行/終了の基本操作を確認。
  - 完了条件: handoff.md の受け入れチェックリスト(要望①分)が全項目 pass。
- **Phase 2c: 要望②③の成立**
  - micro 導入(winget)+ランチャ経由の `EDITOR` 設定 → sidebar_files からファイルを開く。`o` キーで HTML → headful Chrome 実ウィンドウ表示。
  - 完了条件: sidebar_files から Enter でファイルが micro で開き編集・保存できる。HTML ファイルが Chrome 実ウィンドウに表示される。
- **Phase 2d: 配布導線**
  - exe の固定配置+ランチャスクリプト+Windows Terminal プロファイル登録。
  - 完了条件: Windows Terminal の新規タブ(専用プロファイル)から cmux-tui がワンクリックで起動する。
- **Phase 3: 受け入れ検証・ドキュメント・引き渡し**
  - 要望①②③の一気通貫シナリオ(多重化しながらコードを閲覧し HTML をプレビュー)+ドキュメント作成(D10)+ROADMAP.md 更新。
  - 完了条件(ドキュメント分): `my-cmux\README.md` が存在し概要・起動手順を含む。`my-cmux\docs\manual.html` がブラウザで開け、目次リンクで各項目(起動/多重化操作/コード閲覧/HTML プレビュー/設定/トラブルシュート)へページ内遷移できる。記載内容は Phase 2 で実機検証済みの挙動と一致している。
  - 任意タスク(完了条件外): upstream issue 下書き作成(D8)。

## 実装時の検証ポイント(未検証事項 — handoff.md で必ず確認する)

1. **TUI 対話動作は未検証**(スパイクは `--version`/`--help` のみ)。ratatui + crossterm の Windows Terminal 上での描画・入力が最初の関門。
2. **release ビルドは未検証**(スパイクは debug のみ)。
3. **ランタイム DLL 依存の有無は未検証**。windows-gnu ビルドは通常自己完結だが、MSYS2 PATH なしの新規シェルで起動確認するまで断定しない。
4. **micro が cmux-tui の PTY タブ内(ConPTY 配下)で正常描画・操作できるかは未検証**。
5. **browser pane の Windows 実動作は未検証**(Chrome 探索・CDP 接続・`o` キーでのファイルオープン)。ローカル HTML がどの URL 形式(file:// 等)で開かれるかも実機で確認する。
6. `EDITOR` はランチャ→cmux-tui→PTY 子プロセスへ環境変数継承で伝播する想定。想定どおりか Phase 2c で確認する。
