# 状態: 凍結済み(2026-07-26)

# エディタタブのファイル名表示と16文字上限の緩和 — 仕様書

最終更新: 2026-07-26(視覚レビュー承認により凍結。実装引き継ぎは handoff.md)

## 目的

cmux-tui で sidebar_files から `Enter` でファイルを開くと、$EDITOR が新規 PTY タブとして起動するが、タブ表示は現状「番号のみ」。これを「開いたファイル名」にする。あわせて、タブラベルの表示文字数がハードコードで16文字上限になっている点を緩和する。

ユーザー要望(原文): 「HTMLのヘッダータブのようにタブの表示をファイル名にすることはできないか。すべて見えなくてもいい。いまより少し幅を広げて見える範囲で文字がでればいい」

## スコープ

### やること
- sidebar_files の `Enter` → `FileCommand::OpenEditor(path)` 経路で開いたタブに、ファイル名を表示させる方式の設計
- タブラベルの16文字上限(`truncate(t, 16)`)の緩和方法の設計
- 有効化の形(常時ON/設定)・名前の中身(ファイル名のみ/親ディレクトリ込み)の決定
- パッチ分割方針(Windows 移植パッチ集への新規パッチ追加)

### やらないこと(対象外)
- **前回の2段(複数行)タブバー(`20260726-pane-tab-multirow`)は完全に別件・対象外**。既に凍結済み・実装引き継ぎ済み(handoff.md 発行済み、パッチ 0007 想定)。本仕様と混同しないこと。
- sidebar_files 以外の経路(agent タブ等)への命名拡張
- ghostty-vt 側の OSC タイトル処理の改修・検証強化(方式選択の判断材料としてのみ扱う)
- `show_titles` の既存挙動の変更

## 前提(現状のコード事実)

Explore 済み(再調査不要)。対象: `cmux/cmux-tui/crates/cmux-tui/src/{config.rs, app.rs, ui/pane.rs, ui/mod.rs, sidebar_files/mod.rs}`、`cmux/cmux-tui/crates/cmux-tui-core/src/{surface.rs, mux.rs}`、`cmux/cmux-tui/crates/ghostty-vt/src/terminal.rs`。

1. **タブ名は既に2系統ある**:
   - `title`: PTY の OSC 0/2 由来。`Terminal::title()`(terminal.rs:1121-1123)。OSC 2 はテスト検証済み(ghostty-vt/tests/terminal.rs:51-67)、OSC 0 は doc コメントのみ(未検証)。**エディタが実際にファイル名をタイトルとして送るかはエディタ側依存の不確定要素**。
   - `name`: `Surface` の `Mutex<Option<String>>`(surface.rs:910-916)。`tab_label()`(config.rs:1523-1539)は **name が非空なら最優先でそのまま返す**(title/show_titles より優先)。
2. **name をセットする既存パスが2つある**:
   - 手動: `Action::RenameTab`(config.rs:829)→ `open_rename_tab_prompt`(app.rs:7647-7656)→ `Mux::rename_surface`(mux.rs:3933-3967)→ `Surface::set_name`。
   - プログラム的: `Mux::run_command_surface_with_options`(mux.rs:2451-2453, 2544-2546)が `RunCommandOptions.name: Option<String>` を受け取り生成直後に `set_name` する**既存の汎用前例**。
3. **sidebar_files のオープン経路は名前付きパスを通っていない**: `activate_selected()`(sidebar_files/mod.rs:364-371)→ `FileCommand::OpenEditor(path)`(この時点で絶対パス確定)→ ハンドラ(app.rs:7182-7207)→ `split_with_command`(mux.rs:3272-3283、session/mod.rs:714-730、app.rs:1847-1860 の非同期ラッパー)。**`split_with_command` に name パラメータは無い**。非同期ラッパーは `Result<()>` しか返さず、Surface は後から `SessionCompletionAction::SurfaceCreated`(app.rs:4732-4736)で戻る。名前を通すには (i) `split_with_command` 系のシグネチャに `name: Option<String>` を追加して生成直後 `set_name`、(ii) `SurfaceCreated` 完了ハンドラ側で紐付けて `set_name`、のどちらかの改修が要る。
4. **`show_titles` はグローバル1個の bool**(config.rs:644-666)。`tab_label()` はタブ種別(shell/agent/browser/editor)を区別しない。エディタタブだけ挙動を変える既存の仕組みは無い。
5. **16文字上限の実体**: `truncate(t, 16)`(pane.rs:240-252 のラベル生成内。`truncate` 本体は ui/mod.rs:138-146、文字数ベース、省略時 `…` 付与)。`min_width`(既定7、上限40)は**パディング側のみ**で16とは独立(min_width を上げても17文字目以降は出ない)。16 の変更はラベル幅計算の最前段なので `widths`/`fits`(横スクロール当たり判定)には自動反映され、**下流の追加改修は不要**(Explore 結論)。
6. **既存テストへの影響は軽微**: `tab_labels_are_numbers_except_agents`(config.rs:2295-2312)は truncate(16) の対象外。pane.rs のテスト(539-594)は `client_border_labels` のみで、draw_tab_bar/truncate(16) を検証する既存テストは**ゼロ**(壊れないが新規カバレッジも無い)。
7. **リポジトリ運用**: Windows 移植パッチ集。実体は `cmux/` 配下で変更し `patches/` に連番パッチを追加(現最新 0006、2段表示が 0007 想定)。

### 設計上の自明事項(質問にしない前提)
- `name` は生成時に一度セットするだけなので、その後の `RenameTab` 手動上書きと衝突しない(以後は手動が勝つ)。
- `tab_label()` は name 非空を最優先で返すため、name 方式なら描画側の改修は不要(16文字上限の緩和を除く)。
- 16 の設定値化/引き上げは下流(widths/fits)に自動反映される。

## 確定事項(Round 1、経緯は decisions.md)

- **(a) 実現方式 = split_with_command チェーンに name パラメータ追加**: mux.rs:3272-3283 / session/mod.rs:714-730 / app.rs:1847-1860 の3層に `name: Option<String>` を通し、生成直後に `Surface::set_name`。`RunCommandOptions.name`(mux.rs:2451-2453, 2544-2546)と同型の既存前例に倣う。`FileCommand::OpenEditor` ハンドラ(app.rs:7182-7207)で名前を作って渡す。
- **(b) 有効化 = 常時ON(設定なし)**: sidebar_files からのオープンでは常にファイル名をセット。個別に戻すのは既存の RenameTab(config.rs:829)。
- **(c) 名前の中身 = ファイル名のみ(拡張子込み)**: `path.file_name()`。同名ファイルの複数オープンは区別しない(必要なら RenameTab で手動区別)。※区切り文字の論点(旧・未決7)は本決定により消滅。
- **(d) 16文字上限 = 設定値化(既定24)**: `Tabs`(config.rs:642-666)に上限設定を新設し、`truncate(t, 16)`(pane.rs:240-252)の 16 を置換。`min_width`(パディング)とは独立させ既存設定の意味を変えない。項目名は Round 2 で最終確定(仮称 `max_width`)。

## 確定事項(Round 2、経緯は decisions.md)

- **(e) パッチ = 独立パッチ 0008、0007 の後に積む**: 0007(2段表示)を先に実装し、その上に本件 0008 を書く(発行済み 0007 handoff.md の行番号の正確性を保つため)。機能的依存はなく、順序はテキスト衝突回避のため。0007 だけ適用した状態も成立する。
- **設定命名 = `tabs.max_width` のまま(既定24)**: 既存 `min_width` との min/max 対を優先。doc コメントで3項目の対象を明記して誤読を防ぐ: `max_width`「1タブのラベルの最大文字数」、`min_width`「ラベルの最小幅(パディング)」、`max_rows`「タブバーの最大段数」(0007)。
- **全角文字 = 現状踏襲(文字数ベース)**: 表示幅(East Asian Width)対応は min_width のパディングや widths/fits の座標計算全体に及ぶため本件の範囲外。文字数ベース起因の座標ズレは RenameTab 日本語名で今も存在する既存制約であり、実害が出たら別件として起票する。
- **テスト = ユニット2点+実機確認**: (1) `tab_label()` が name 非空でファイル名を最優先で返す(config.rs:2295-2312 の既存テストの隣に追加)、(2) ラベル切り詰めが `max_width` 設定値に従う(既定24・境界値)。name の3層伝搬は結合レベルの実機確認(sidebar_files から開いてタブ名を目視)で担保。

## 未決事項

(なし — 全項目決定済み・凍結。仕様変更が必要になった場合は凍結を解除し、decisions.md に理由を記録してからここへ差し戻す)
