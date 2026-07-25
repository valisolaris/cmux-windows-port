# 実装引き継ぎ書 — cmux Windows 対応 Phase 4(UX改善ラウンド)

作成: 2026-07-25(調査セッション / Sonnet 5)
対象読者: **会話文脈ゼロの新規セッション**。この文書だけで実行できる。

**2026-07-25 追記: 本ラウンド全タスク実装完了。** ①②③④⑤+追加検討4点(Alt+Xでペイン/タブを閉じる・サイドバーに全pane×全tabのタイトル一覧を集約表示・HTMLプレビューのSixel対応・`/copy`貼り付け時の改行暴発送信の修正)すべてビルド・ユニットテストpass。実機確認は③(タブのドラッグ&ドロップ統合)に加え、**Sixel表示と`/copy`貼り付けの2点も2026-07-25にユーザー確認でpass**(詳細は本ファイル§1および`ROADMAP.md`参照)。

**2026-07-26 追記: ①も実機確認pass(実機で見つかったスクロール不具合を修正)。** §2cに詳細。**②(Enterでファイルを新規ペインで開く)のみ実機未確認のまま次回に持ち越し**(oでの新規ペイン確認は済んだが、Enterでのファイルオープンは未検証)。マウスホイールでのサイドバー(ファイルビュー)スクロール未対応が今回わかったが、既存の別件として今回は対応していない(`app.rs`の`handle_scroll`が`SidebarView::Workspaces`のときしか処理しないため。キーボード・クリックでは操作可能)。2026-07-26、`cmux`リポジトリ(windows-portブランチ)にPhase 4一式(今回の修正含む)をコミット。詳細はROADMAP.mdのPhase 4チェックリストを参照。

## 次回セッションでまずやること

残っているのは②(サイドバーから`Enter`で開いたファイルが、既存ペインを上書きせず右に新規ペインで開くか)の実機確認だけ。手順:

1. `& "C:\Users\user\Documents\claude-projects\my-cmux\cmux\cmux-tui\target\x86_64-pc-windows-gnu\debug\cmux-tui.exe" --session verify-phase4`(隔離セッション名を必ず指定)
2. サイドバーにフォーカス(`Ctrl+B`→`Shift+S`、IME英数モード)、任意のファイル(`.html`/`.md`以外でもよい)を選び`o`ではなく`Enter`で開く
3. 既存ペインの内容が消えず、右に新しいペインが作られて`$EDITOR`(micro)がそこで起動するか確認
4. pass/failを`ROADMAP.md`②の行と本ファイル§2bに追記

マウスホイールでのサイドバー(ファイルビュー)スクロール未対応(§2c末尾)は今回スコープ外のまま残っている。対応するかはユーザー判断待ち。

## 0. これは何か

`spec/spec.md`(凍結済み、要望①②③+ドキュメント)は2026-07-25にPhase 2/3として完了・公開済み(`spec/handoff.md`参照)。その**同日**、ユーザーから追加のUX改善5点の要望が来た。これはその追加ラウンドの実装引き継ぎ書。**`spec/spec.md`・`spec/decisions.md`は凍結済みのまま変更しない**(このラウンドはその上に乗る追加作業として扱う)。

## 1. 結論: 5点中2点は決着済み・着手不要

- **④ HTMLをTUIペイン内でプレビュー**: **kitty graphicsは却下のまま、Sixelで2026-07-25に実装完了**。実機検証(cmux-tuiを介さず素のWindows Terminalタブで、32x32 PNGを生のkitty graphics APCエスケープシーケンスで直接送信)の結果、Windows Terminal自体がkitty graphicsに非対応と実証済みで、この判断は変えない。ただしその後、Windows Terminal stable(1.24系)がSixelには対応済みと判明したため、`browser.sixel`設定(既定false、opt-in。Windows上ではkittyと同様に対応をプローブできないため設定で明示的に有効化する設計)でSixelエンコードのin-TUIプレビューを実装(`cmux-tui/src/ui/graphics.rs`の`encode_sixel`/`GraphicsProtocol::Sixel`)。PNGデコードは`png` crate、量子化は固定6x6x6 RGBキューブ(216色、ディザリングなし)、RLE圧縮あり。ビルド・ユニットテスト10件pass。**実機でのSixel表示確認pass(2026-07-25、ユーザー確認)** — `%APPDATA%\cmux\cmux-tui.json`に`{"browser": {"sixel": true}}`を設定し、`verify-phase4`セッションで`samples/preview-test.html`を`o`で開いたところ、カラースウォッチ5色(RED/GREEN/BLUE/YELLOW/PURPLE)がそれぞれ判別可能な形でペイン内に描画された(多少ぼやけるのは6x6x6量子化による想定内の劣化)。見出しの下線・配色も再現。②(右に新規ペインで開く)の動作も同時に確認できた。

**`/copy`貼り付け時の改行暴発対策も実機確認pass(2026-07-25、ユーザー確認)**: `verify-phase4`セッションで15行・382文字(日英混在+Markdown記号)のクリップボードを`micro`エディタに貼り付け、欠落・文字化けなく最終行まで正しく入ることを確認。貼り付け前後のタイピングにもラグなし。PowerShellのシェルペインに直接貼り付けた場合は改行のたびに行が逐次実行される(`echo1`→`echo2`→`echo3`が別々のプロンプトで実行)が、これはPowerShell/PSReadLine側がブラケットペーストモード(mode 2004)を有効化していないために起きる現象で、cmux側`paste()`(`app.rs:8194-8226`)はUnix向けと同じロジックでmode 2004の有無を見て正しく分岐している(コード確認済み)。テキスト自体は各行とも欠落・文字化けなく完全な形で届いており、当初懸念していた「改行のたびに途中送信される」不具合は解消と判断。
- **⑤ `Ctrl+B`→`Shift+S`でサイドバーにフォーカスできず`S`がペインに入力される**: **コードのバグではなかった**。原因は複合: (a) `Ctrl+B`を2回連続で押すとtmux互換仕様で2回目がリテラル転送され、プレフィックスが不武装のまま次のキーがペインに漏れる、(b) `focus-sidebar`はトグル動作(サイドバーフォーカス中に再度押すとペインへ戻る)、(c) 視覚フィードバックが地味(色変化のみ)で成功に気づきにくい、(d) **日本語IMEが日本語入力モードのままだとプレフィックス操作にキーが届かない。英数(半角英数)モードにすると正常動作する(実機確認済み)**。`docs/keybindings.md`に注記済み。**追加実装不要**。

## 2. 今回実装する3件(優先度順・小さいものから)

### 2a. ③ 2ペインを1つのタブグループへ統合(規模: 小、最優先) — **完了(2026-07-25 実機確認pass)**

- 現状: `Pane`構造体(`cmux-tui-core/src/model.rs:391`)は元々`tabs: Vec<SurfaceId>` + `active_tab`を持つ「タブグループ」そのもの。`Mux::move_tab`(`cmux-tui-core/src/mux.rs:4415`)で他ペインへタブを移動でき、空になった移動元ペインは自動でNode split木から消える(テスト済み: `mux.rs:6679` `move_tab_across_panes_collapses_empty_source_and_preserves_surface`)。
- **マウスドラッグでタブを別ペインへドロップする機能は既に実装済み**(`cmux-tui/src/app.rs` `tab_drop_target_at`8110行付近、`Drag::Tab` → `handle_left_up`9554-9560行付近)。
- **最初のステップはコード変更ではなく実機確認**: リリース/デバッグビルドを実機で動かし、3ペイン表示でタブをマウスドラッグして別ペインへ落とし、統合されるか確認する。動けば追加実装は「キーボードだけで統合したい場合のみ」に縮小する。
- キーボード対応を追加する場合: 既存`move_tab`を呼ぶ新規Action(例 `MergeIntoAdjacentPane`)を`cmux-tui/src/keys.rs` / `config.rs`(`Action`列挙体・`Keys::default()`)に追加し、`app.rs::run_action`にハンドラを足す。データモデル変更は不要。
- 完了条件: (a) マウスドラッグでのタブ統合が実機で動作、(b) 必要ならキーボード版Actionも動作。

### 2b. ② サイドバーから開いたファイルを右の新規ペインで開く(規模: 中) — **実装完了(2026-07-25、ビルド確認済み。実機確認は未実施)**

- 現状原因(判明済み): `run_file_command`(`cmux-tui/src/app.rs:6989-7052`)の`FileCommand::OpenEditor` / `OpenBrowser`は、`Session::run_command` / `new_browser_tab`経由で`Mux::run_command_surface`(`cmux-tui-core/src/mux.rs:2415`)を呼び、**対象ペインの`tabs`に新規surfaceをpushして`active_tab`を切り替えるだけ**(`mux.rs:2561-2562`)。ペイン分割木(`Node`)には一切触れないため、既存ペイン内で表示が切り替わり前の内容が裏に隠れる(「重なる」の正体)。
- 対応方針: 既存`Mux::split`(`mux.rs:3257`)を土台に、「splitして新ペインでコマンドを直接実行して開く」新規API(例 `Mux::split_with_command`)を追加。`Session`経由で`run_file_command`のOpenEditor/OpenBrowser分岐から呼び分ける。
- 影響ファイル: `cmux-tui-core/src/mux.rs`(新規関数追加)、`cmux-tui/src/session/mod.rs`、`cmux-tui/src/app.rs`(6989-7052行付近の呼び出し変更)。
- データモデルの再設計は不要(既存splitインフラをそのまま利用)。
- 完了条件: サイドバーでファイルをEnter/`o`で開くと、既存ペインを上書きせず右に新しいペインが作られてそこで開く(実機確認)。

### 2c. ① サイドバーをエクスプローラー風に複数フォルダ同時展開(規模: 中〜大、最後) — **実機確認pass(2026-07-26、不具合修正後)**

- 現状: `FileBrowser`(`cmux-tui/src/sidebar_files/mod.rs:25-37`)は`entries: Vec<FileEntry>`(現在ディレクトリ直下のみのフラット一覧)+ `Navigation`(`navigation.rs:3-7`、`current_dir: PathBuf`を1つだけ保持)という設計。サブフォルダに入ると`entries`ごと`reload_directory`(`mod.rs:301-315`)で置換され、**展開状態を複数ノード分保持する仕組みが存在しない**。`FileEntry`(`files.rs:15-20`)も子要素や展開フラグを持たない。
- 対応方針: 展開済みパス集合(例 `HashSet<PathBuf>`)を`FileBrowser`に持たせ、描画時にルート配下のツリーをフラット化してインデント+展開アイコン(▸/▾)付きリストを都度組み立てる設計に変更。**左右矢印キーの意味(現状: ディレクトリ移動)を「展開/折りたたみ」へ再設計する必要がある**(キー体系の変更なので`docs/keybindings.md`のファイルサイドバー節も要更新)。
- 影響ファイル: `sidebar_files/{mod,files,navigation}.rs`(事実上の作り直し)、`ui/sidebar.rs::draw_files`(482-614行付近、中規模改修。ヒットテスト`Hit::SidebarFile{index}`をフラットindexからツリー行への対応付けに作り直す必要あり)。`app.rs`の`run_file_command`周辺への影響は小さい見込み。
- 既存テスト(`sidebar_files`内のユニットテスト、`navigation.rs`のテスト)は前提変更に伴い大半書き直しが必要になる見込み。
- 完了条件: サイドバーで複数のフォルダを同時に展開状態にして中身を見られる。既存の単一フォルダ表示時の挙動(フィルタ`/`、隠しファイルトグル`.`、reroot`~`等)が壊れていないこと。
- **2026-07-26 実機確認で発見・修正した不具合**: 展開でリストが画面丈を超えたとき、すでに画面内に見えている行をマウスでクリックしても、その行が常に一番下の行へ飛ばされてしまう不具合があった。原因は`ui/sidebar.rs`の`file_scroll_offset`が現在のスクロール位置を保持せず、毎フレーム`selected`(絶対行番号)だけから「選択行を画面の最終行にする」オフセットを再計算していたこと。`sidebar_files/mod.rs`の`FileBrowser`に`scroll_offset`フィールドと`update_scroll(visible_height)`(選択行がすでに画面内ならオフセット不変、画面外に出たときだけ最小限スクロール)を追加して解消。`file_scroll_offset`は削除し呼び出し側を`app.sidebar_files.update_scroll(body_height)`に置き換え。回帰テスト`sidebar_files::tests::update_scroll_keeps_offset_when_selection_is_already_visible`を追加、sidebar_files全14件pass、ユーザー実機確認pass。
- **既知の未対応(今回は対象外)**: サイドバーのファイルビューはマウスホイールでのスクロールに未対応(`app.rs`の`handle_scroll`が`SidebarView::Workspaces`のときしか処理しない)。キーボード(`↑`/`↓`/`Ctrl+j`/`Ctrl+k`)とマウスクリックでは操作可能。対応するかは次回ユーザー判断待ち。

## 3. 境界(`spec/handoff.md` §1と同じルールを踏襲)

**触ってよいもの**
- `my-cmux\cmux\` — ただし **windows-port ブランチ上でのみ**
- `my-cmux\docs\`(キーバインド表などの更新)
- `my-cmux\ROADMAP.md` — チェックボックスと最終更新の追記のみ
- この `spec/handoff-phase4.md` 自体(進捗を追記してよい)

**触ってはいけないもの**
- `my-cmux\cmux-main\` — 参照専用
- `my-cmux\cmux` の `main` ブランチ(コミットしない)・リモートへの push(一切しない)
- `my-cmux\spec\spec.md` / `decisions.md` / `handoff.md`(Phase 2/3分)— 凍結済み。変更が必要になったら作業を止めてユーザーに確認

**運用**
- ビルド環境・再現手順は `ROADMAP.md` が正(PATH / LIBCLANG_PATH / BINDGEN_EXTRA_CLANG_ARGS の設定が必須)。
- 各ステップの完了条件は実機確認(exit code・実際の画面動作)で確認してから次へ進む。未検証のままコミットしない。
- **cmux-tuiは複数クライアントが既定セッション名`main`に同時接続できる共有セッションモデル**(`main.rs` run_server)。動作確認やデバッグで対話的にcmux-tuiへ接続・キー入力を送る場合、**必ず`--session <隔離名>`を指定し、ユーザーの`main`セッション(稼働中の実セッション)には絶対に接続しないこと**。2026-07-25、これを怠ったサブエージェントがユーザーの稼働中セッションに文字を1つ紛れ込ませる実害を起こしている。
- 同じ問題への修正が2回失敗したら3回目の変種を試さず、Fableへの委譲(`model: "fable"`のAgent)かユーザーへの報告に切り替える。
- 進め方は 2a → 2b → 2c の順。各ステップ完了ごとにROADMAP.mdのPhase 4チェックボックスを更新し、実機確認のpass報告を得てから次へ進む。

## 4. 参考: この引き継ぎ書のもとになった調査(2026-07-25、同日セッション)

- サイドバー・レイアウト・ブラウザの3領域をExploreエージェントで並列調査
- ④はkitty graphics手動送信テストで実証
- ⑤はキー入力を一時的にログ出力するdebugビルドを作り実機再現ログを取得、Fable(`model: "fable"`)に根本原因調査を委譲して特定
- 詳細な経緯はこの日のセッション記録、または `C:\Users\user\.claude\projects\...\memory\cmux-windows-port-project.md` の「2026-07-25(同日追加ラウンド)」節を参照(このメモリファイルは新規セッションでも自動的に読み込まれる)
