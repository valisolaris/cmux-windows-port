# 実装引き継ぎ書: エディタタブのファイル名表示と文字数上限の緩和

作成: 2026-07-26 / 仕様は同ディレクトリの spec.md(凍結済み)・decisions.md(決定経緯)・review.html(視覚モック)を正とする。本書だけで実装を開始できるよう要点を再掲するが、齟齬があれば spec.md を優先。0007(2段表示)の handoff.md とは独立して読める。

## 0. リポジトリ運用(最初に読むこと)

- このリポジトリ(`my-cmux`)は **upstream cmux(macOS 本体)の Windows 移植パッチ集**。実体コードは `C:\Users\user\Documents\claude-projects\my-cmux\cmux\`(独立した git リポジトリ)にある。
- 変更は `cmux\` 側で行い、テスト・実機確認後に1コミットへまとめ、`git format-patch` で生成したパッチを `..\patches\` に置く。**本件のパッチ連番は `0008`**(0007 = 2段表示タブバー、別仕様 `20260726-pane-tab-multirow` の後)。
- **前提: 0007 が `cmux\` に実装・コミット済みであること**。まだなら 0007 の実装(同ディレクトリ構成の別 handoff.md)を先に行う。本件は 0007 の上に積む(機能的依存はなく、pane.rs / config.rs のテキスト衝突回避のための順序)。
- 本書が引用する行番号は **0007 適用前の値**。0007 実装後はずれている可能性があるため、行番号は目安とし、シンボル名(関数名・フィールド名)を一次参照にすること。
- コミットメッセージ作成時の注意(ユーザー環境共通): Bash ツールで PowerShell の here-string(`@"..."@`)を使わない。`git commit -m "..."` か `git commit -F <一時ファイル>` を使う。

## 1. 仕様サマリ(凍結済み)

- sidebar_files から `Enter` でファイルを開いたエディタタブに、**開いた時点で `path.file_name()`(拡張子込み)を `Surface::set_name` でセット**する。`tab_label()`(config.rs:1523-1539)は name 非空を最優先で返すため、描画側の追加改修は不要。
- 実現方式: `split_with_command` チェーン3層(mux.rs:3272-3283 → session/mod.rs:714-730 → app.rs:1847-1860 の非同期ラッパー)に `name: Option<String>` を追加し、生成直後に `set_name`。既存の `RunCommandOptions.name`(mux.rs:2451-2453, 2544-2546)と同型。
- 常時ON(設定なし)。個別に戻すのは既存の RenameTab(以後は手動名が勝つ。name は生成時に一度セットするだけなので衝突しない)。
- 同名ファイルの複数オープンは**自動区別しない**(必要時は RenameTab で手動区別)。
- ラベル文字数上限: `truncate(t, 16)`(pane.rs:240-252、truncate 本体は ui/mod.rs:138-146)の 16 を **新設定 `tabs.max_width`(既定 24)** に置換。`min_width`(パディング・既定7)とは独立で、既存の意味を変えない。下流(widths/fits)は自動反映で無改修。
- 全角文字は**文字数ベースを現状踏襲**(表示幅対応は別件。文字数ベース起因の座標ズレは RenameTab 日本語名で今も存在する既存制約)。
- doc コメントで3項目の対象を明記: `max_width`「1タブのラベルの最大文字数」/`min_width`「ラベルの最小幅(パディング)」/`max_rows`「タブバーの最大段数」(0007 新設)。
- 対象外(触らない): RenameTab のロジック、show_titles の挙動、ghostty-vt(OSC タイトル)、sidebar_files 以外の経路への命名拡張。

## 2. タスク分解(依存順)

パッチは1つ(テスト同梱)。

### T1. 設定スキーマ追加(依存なし)
- `config.rs` の `Tabs`(642-666)に `max_width`(整数、既定 24)を追加。特別なクランプ仕様は定めず、値の取り扱い(デシリアライズ・既定値の書き方)は既存 `min_width` の流儀に合わせる。
- `max_width`/`min_width`/`max_rows`(0007 で追加済みのはず)の doc コメントを§1の文言どおり整備。
- 完了条件: 既定値 24 を検証するユニットテストが通る(既存 config 既定値テストの流儀)。

### T2. name パラメータの3層追加(T1 と独立、並行可)
- `Mux::split_with_command`(mux.rs:3272-3283)→ `Session`(session/mod.rs:714-730)→ app.rs の非同期ラッパー(1847-1860)に `name: Option<String>` を追加し、Surface 生成直後に `set_name(name)`。実装は `run_command_surface_with_options` の `RunCommandOptions.name` 処理(mux.rs:2451-2453, 2544-2546)を踏襲。
- 他の全呼び出し元は `None` を渡す(呼び出し元はコンパイルエラーで網羅的に洗い出せる)。
- 完了条件: コンパイル通過+既存テスト無退行(`cargo test`)。

### T3. OpenEditor ハンドラで名前を渡す(T2 に依存)
- `FileCommand::OpenEditor(path)` ハンドラ(app.rs:7182-7207)で `path.file_name()` から `Option<String>` を作り、T2 のパラメータへ渡す。`file_name()` が None の場合は None(従来どおり番号表示)。
- 完了条件: ユニットは T5、結合は §4 の実機確認で担保。

### T4. 文字数上限の置換(T1 に依存)
- pane.rs のラベル生成(240-252)の `truncate(t, 16)` を `tabs.max_width` の値に置換。下流(widths/fits)は無改修。
- 完了条件: `cargo test` 通過。

### T5. ユニットテスト2点(T1〜T4 に依存)
- (1) `tab_label()` が name 非空のときファイル名を最優先で返す(既存 `tab_labels_are_numbers_except_agents`、config.rs:2295-2312 の隣に追加)。
- (2) ラベル切り詰めが `max_width` 設定値に従う(既定24。境界値: 上限ちょうどは切り詰めなし/超過時は `…` 付き。truncate の正確な境界意味論は ui/mod.rs:138-146 の実装を読んで合わせる)。
- 完了条件: `cargo test` 全通過。テストのスキップ・無効化は不可。

### T6. 実機確認とパッチ生成(T1〜T5 完了後)
- `cmux\cmux-tui` で `cargo build` → §4 の実機確認 → `cmux\` 内で1コミット → `git format-patch` で `patches\0008-*.patch` を生成。
- 完了条件: patches\0008 が存在し、0001〜0007 適用済みの upstream に `git apply --check` が通ること。

## 3. 触ってよい範囲 / 触ってはいけない範囲

**触ってよい**(すべて `cmux\cmux-tui\crates\` 配下):
- `cmux-tui\src\config.rs`: `Tabs`(max_width 追加・doc コメント)、テスト追加
- `cmux-tui\src\app.rs`: split ラッパー(1847-1860)、OpenEditor ハンドラ(7182-7207)
- `cmux-tui\src\ui\pane.rs`: ラベル生成の truncate 呼び出し(240-252)のみ
- `cmux-tui-core\src\mux.rs`: `split_with_command`(3272-3283)
- `cmux-tui\src\session\mod.rs`: split_with_command 中継(714-730)

**触ってはいけない**:
- RenameTab のロジック(`open_rename_tab_prompt`/`rename_surface`)— 読むのは可、変更不可
- `show_titles` の挙動、`tab_label()` の優先順位ロジック(name 最優先は既存のまま使う)
- 0007 が実装した2段表示のレイアウト計算(`pane_parts_for_rect`/`sync_layout` のレイアウト部分)・`push_resize_hits`・`tab_drop_target_at`・`draw_box` — 本件と無関係
- `stacked_header_parts_for_rect`、ghostty-vt(OSC タイトル処理)、sidebar_files\mod.rs(`activate_selected` は変更不要)
- `truncate` 本体(ui/mod.rs:138-146)の意味論変更(文字数ベースのまま)
- 既存パッチ 0001〜0007 の機能挙動を変える変更。`.env` は読まない。

## 4. 検証方法

1. **自動テスト**: `cmux\cmux-tui` で `cargo test`(run_in_background 推奨)。全通過が必須。
2. **実機確認**(Windows Terminal 上で起動、以下を順に目視):
   - sidebar_files から複数ファイル(例: main.rs、config.rs)を開く → 各タブにファイル名が表示される。シェルタブは番号のまま
   - 同名ファイル2つ(例: 別ディレクトリの mod.rs ×2)を開く → 両タブとも同じ表示で区別されない(仕様どおり)
   - RenameTab でエディタタブを手動リネーム → 上書きされ、以後保持される
   - 24文字を超える長いファイル名を開く → 24文字相当で `…` 切り詰め
   - 日本語ファイル名を開く → 文字数ベースで表示される(セル幅が広くなるのは仕様どおり)
   - `tabs.max_width` を変更(例: 40)して再起動 → 切り詰め位置が変わる
3. 実機確認の結果は「検証済み/未検証」で区別して報告する(自動テスト通過のみで完了を宣言しない)。

## 5. 実装上の注意(ハマりどころ)

- 行番号はすべて 0007 適用前の値。0007 実装後の実コードではシンボル名で探すこと。
- `split_with_command` の呼び出し元は複数ある想定。シグネチャ変更後のコンパイルエラーを網羅リストとして使い、OpenEditor 経路以外はすべて `None`。
- `set_name` は既存 RenameTab と同じ `Surface::set_name` 経路なので、永続化・表示の追加対応は不要のはず。挙動が違ったら仕様判断をせず報告する。
- 実装はこの handoff の範囲に限定し、仕様変更が必要になったら実装で勝手に決めず、spec.md の凍結解除(decisions.md に理由を記録)を経ること。
