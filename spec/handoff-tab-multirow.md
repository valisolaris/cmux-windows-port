# 実装引き継ぎ書: ペイン内タブバーの2段(複数行)表示

作成: 2026-07-26 / 仕様は同ディレクトリの spec.md(凍結済み)・decisions.md(決定経緯)・review.html(視覚モック)を正とする。本書だけで実装を開始できるよう要点を再掲するが、齟齬があれば spec.md を優先。

## 0. リポジトリ運用(最初に読むこと)

- このリポジトリ(`my-cmux`)は **upstream cmux(macOS 本体)の Windows 移植パッチ集**。実体コードは `C:\Users\user\Documents\claude-projects\my-cmux\cmux\`(独立した git リポジトリ)にある。
- 変更は `cmux\` 側で行い、テスト・実機確認後に `cmux\` 内で1コミットにまとめ、`git format-patch` で生成したパッチを `..\patches\` に置く。**新パッチの連番は `0007`**(現時点の最新は `0006-windows-port-accept-a-launch-time-cwd-positional-pat.patch`)。
- 本件は Windows 固有バグ修正ではなく一般 UX 改善だが、パッチとして追加してよいことは合意済み(Phase 4/5 に前例あり)。
- コミットメッセージ作成時の注意(ユーザー環境共通): Bash ツールで PowerShell の here-string(`@"..."@`)を使わない。`git commit -m "..."` か `git commit -F <一時ファイル>` を使う。

## 1. 仕様サマリ(凍結済み)

- タブがペイン幅に入りきらないときだけ、タブバー(bar)を動的に2行化し、content を1行減らす(bar 高さ 1 or 2。content.height = rect.height - 1 - bar高さ)。
- 最大2段。2段でも入りきらない分は既存の `tab_scroll`(先頭可視タブのインデックス、意味論不変)+ `‹`/`›` 矢印スクロールを併用。`‹` は1段目左端(tab_scroll > 0 のとき)、`›` は2段目右端(末尾側に非可視タブがあるとき)。`+`(新規タブ)は最終可視タブの直後(現行踏襲)。
- 小ペイン: `rect.height >= 5`(bar2 + content2 + 下枠1)のときのみ2段化。未満は従来の1段+スクロールへフォールバック。
- 設定: `tabs.max_rows` を新設、既定値 `2`(新挙動が既定ON)。`1` で従来動作に完全復帰。有効値は 1/2 で、3以上は 2、0以下は 1 にクランプ。
- 視覚: 1段目は `┌`〜`┐`(現行)、2段目は左右端 `│`・段間区切り線なし。**bar 領域(高さ bar.height)は全セル draw_tab_bar 担当、draw_box は bar 領域に触れない**(現行の「上端行に触れない」ルールを高さ方向に一般化)。折り返しはタブ境界(ラベル途中で改行しない)。
- D&D: ポインタの Y でまず対象行を確定し、行内は現行同様 X の中点判定。行の右端より右で離す=「その行の末尾=次行の先頭」。`tab_drop_target_at` のソートキーを `(rect.y, rect.x, index)` に変更。
- リサイズハンドル: `push_resize_hits` は**変更なし**(1段目のみ)。2段目の `─` 埋めは不感帯。
- 対象外(触らない): タブ名のファイル名化・16文字上限緩和(`tab_label()`/`min_width`/`show_titles`)、スタック表示(`stacked_header_parts_for_rect`)の挙動。

モックは review.html の5図(通常1段/2段全可視/2段+‹›/D&D▼/小ペイン)を参照。

## 2. タスク分解(依存順)

パッチは1つ(テスト更新同梱)。T2 の時点で既存テストが赤になるため、T5 は T2〜T4 と並走させ、最終的に1コミットへまとめる。

### T1. 設定スキーマ追加(依存なし)
- `config.rs:642-666` の `Tabs` に `max_rows`(整数、既定 2)を追加。読み取り側でクランプ(0以下→1、3以上→2)。
- 完了条件: `max_rows` の既定値とクランプを検証するユニットテストが通る(既存の config 既定値テストの流儀に合わせる)。

### T2. レイアウト計算(T1 に依存)
- `pane_parts_for_rect`(app.rs:3256-3297)を「必要 bar 高さ(1 or 2)」を決められる形に変更。**設計上の注意**: 現在この関数は rect のみで決まるが、2段化にはそのペインのタブ本数・ラベル幅・max_rows が必要。呼び出し元 `sync_layout`(app.rs:5230-5374)からタブ情報を渡すシグネチャ変更が要る。
- 2段の条件: max_rows>=2 かつ タブが1段に入りきらない かつ `rect.height >= 5`。content.height = rect.height - 1 - bar高さ。
- PTY resize は既存機構(`enqueue_surface_resize`/`attach_surface`、app.rs:5341-5372)が content 変化を自動処理する。**新しい resize 配線を書かないこと**。
- 完了条件: 新テスト「2段時に content.height = rect.height - 3」「rect.height==4 では2段化しない」「max_rows=1 で常に従来と同一」が通る。

### T3. 描画の折り返し(T2 に依存)
- `draw_tab_bar`(pane.rs:163-335)を bar.height==2 に対応: タブ境界で折り返し、1段目 `┌`…`┐`、2段目 `│`…(`─`埋め)…`│`。`+` は最終可視タブ直後、`‹` は1段目左端、`›` は2段目右端。`tab_scroll` はそのまま流用。各タブ・`+`・`‹›` の Hit Rect は実際の描画位置で push(hit_at は無改修で成立)。
- `draw_box`(pane.rs:116-158)は「bar 領域(bar.height 行)に触れない」よう一般化(現行は上端1行のみ想定)。
- 完了条件: cargo test(描画まわりの既存テスト)+ 実機目視(§4 のシナリオ)。

### T4. 当たり判定の改修(T3 に依存)
- `tab_drop_target_at`(app.rs:8287-8315): ソートキーを `(rect.y, rect.x, index)` に変更し、ポインタ Y で行を確定 → 行内 X 中点判定 → 行右端より右は行末尾扱い、を実装。
- `push_resize_hits`(pane.rs:498-536)は変更しない(1段目のみのままであることを確認)。
- 完了条件: D&D の行またぎを検証するテスト(2段レイアウトで「2段目の t5/t6 間」「1段目右端より右」への drop 先が仕様どおり)が通る。

### T5. 既存テスト fixture 更新(T2〜T4 と並走)
- `alt_n_uses_zellij_default_vertical_distribution`(app.rs:10854、10911-10930): `bar Rect{height:1}` / `content = rect.height - 2` の pin を新ロジックに合わせ更新。
- `browser_omnibar_reduces_content_rect_for_graphics_and_input` 等(app.rs:11257 以降)の同種算術も更新。
- `PaneArea` リテラル直書き fixture(app.rs:11317、11470、11647、11697、14059、14109、14209)を監査・更新(タブ1〜2個の fixture は bar 1行のままのはず — 機械的に書き換えず、各 fixture のタブ数から正しい bar 高さを判断すること)。
- 完了条件: `cargo test` 全通過。

### T6. 実機確認とパッチ生成(T1〜T5 完了後)
- `cmux\cmux-tui` で `cargo build` →実機確認(§4)→ `cmux\` 内で1コミット → `git format-patch` で `patches\0007-*.patch` を生成。
- 完了条件: patches\0007 が存在し、クリーンな upstream に適用(`git apply --check`)できること。

## 3. 触ってよい範囲 / 触ってはいけない範囲

**触ってよい**(すべて `cmux\cmux-tui\crates\cmux-tui\src\` 配下):
- `ui/pane.rs`: `draw_tab_bar`、`draw_box`(bar 領域回避の一般化のみ)、`draw_all`(必要なら)
- `app.rs`: `pane_parts_for_rect`、`sync_layout`(タブ情報の受け渡しのみ)、`tab_drop_target_at`、`PaneArea` 関連、テスト・fixture
- `config.rs`: `Tabs`(642-666)への `max_rows` 追加

**触ってはいけない**:
- `tab_label()` / `min_width` / `show_titles` のロジック(別軸で検討中)
- `stacked_header_parts_for_rect` の挙動(bar=rect 全体の別モード)
- `push_resize_hits`(変更なしが仕様)
- 既存パッチ 0001〜0006 が触った箇所の再変更(コンフリクトを作らない)。sidebar_files 等の無関係機能。`.env` は読まない。
- `cmux_tui_core::layout_screen`(クレート外の split 計算)— bar/content の分配は pane_parts_for_rect 側で完結させる

## 4. 検証方法

1. **自動テスト**: `cmux\cmux-tui` で `cargo test`(run_in_background 推奨)。全通過が必須。テストをスキップ・無効化しない。
2. **実機確認**(Windows Terminal 上で起動、以下を順に目視):
   - タブを増やして幅を溢れさせる → bar が2段化し content が1行減る(内部のシェル表示が乱れない)
   - タブを閉じて1段に収まる → bar が1行に戻る
   - 2段でも溢れるまで増やす → `‹`(1段目左端)/`›`(2段目右端)が出てスクロールできる
   - 2段表示中にタブを D&D → 2段目内・行またぎの並べ替えが仕様どおり
   - ペインを高さ4以下まで縮める → 2段化せず従来の1段+スクロール
   - 2段目の `─` 隙間をドラッグ → 何も起きない(不感帯)。1段目の隙間 → 従来どおり上端リサイズ
   - `tabs.max_rows = 1` を設定 → 完全に従来動作
3. 実機確認の結果は「検証済み/未検証」で区別して報告する(自動テスト通過のみで完了を宣言しない)。

## 5. 実装上の注意(ハマりどころ)

- bar 高さの決定にはタブ幅の合計が要るため、レイアウト(app.rs)とラベル幅計算(pane.rs/config.rs)の間で計算を重複させないこと。折り返し位置の計算は1箇所にまとめ、draw_tab_bar とレイアウト側の両方から同じ結果が得られるようにする(描画とレイアウトで段数がズレると content と bar が重なる)。
- `tab_scroll` の既存のクランプ処理(タブ削除時など)が2段の可視本数と整合するか確認。
- 実装はこの handoff の範囲に限定し、仕様変更が必要になったら実装で勝手に決めず、spec.md の凍結解除(decisions.md に理由を記録)を経ること。
