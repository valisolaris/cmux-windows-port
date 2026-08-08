# 実装引き継ぎ書 — cmux Windows 対応 Phase 4(UX改善ラウンド)

作成: 2026-07-25(調査セッション / Sonnet 5)
対象読者: **会話文脈ゼロの新規セッション**。この文書だけで実行できる。

**2026-07-25 追記: 本ラウンド全タスク実装完了。** ①②③④⑤+追加検討4点(Alt+Xでペイン/タブを閉じる・サイドバーに全pane×全tabのタイトル一覧を集約表示・HTMLプレビューのSixel対応・`/copy`貼り付け時の改行暴発送信の修正)すべてビルド・ユニットテストpass。実機確認は③(タブのドラッグ&ドロップ統合)に加え、**Sixel表示と`/copy`貼り付けの2点も2026-07-25にユーザー確認でpass**(詳細は本ファイル§1および`ROADMAP.md`参照)。

**2026-07-26 追記: ①も実機確認pass(実機で見つかったスクロール不具合を修正)。** §2cに詳細。**②(Enterでファイルを新規ペインで開く)のみ実機未確認のまま次回に持ち越し**(oでの新規ペイン確認は済んだが、Enterでのファイルオープンは未検証)。マウスホイールでのサイドバー(ファイルビュー)スクロール未対応が今回わかったが、既存の別件として今回は対応していない(`app.rs`の`handle_scroll`が`SidebarView::Workspaces`のときしか処理しないため。キーボード・クリックでは操作可能)。2026-07-26、`cmux`リポジトリ(windows-portブランチ)にPhase 4一式(今回の修正含む)をコミット。詳細はROADMAP.mdのPhase 4チェックリストを参照。

**2026-07-26 追記(4回目・完了): Phase 4全項目 実機確認pass。** ②(Enter)・ダブルクリック・①(三角クリック展開)すべてユーザー実機確認pass。詳細は§2f。**本ラウンドはこれで完了**、windows-portブランチへコミット。

## 次回セッションでまずやること

**本ラウンド(Phase 4 UX改善)は完了。** 次にユーザーから新しい要望が来たら、それに応じて新規の引き継ぎ書(または本ファイルへの追記)を作成すること。特に持ち越しの作業はない。

なお、②(Enter)が2026-07-26の1〜2回目の実機確認でfailし3回目でpassした件は、**根本原因を特定していない**(ユーザー判断により深追いせず)。将来また同様の「無反応」報告があれば、§2eに記録した調査(エラー通知経路、`split_with_command`と`split_with_browser`の非対称性)を再利用して調査を再開できる。

なお、フルテストスイート(`cargo test -p cmux-tui --target x86_64-pc-windows-gnu`)は本ラウンドと無関係な環境起因のフレーキーが約25〜29件ある(`test_mux`ヘルパーがWindows上で`/bin/sh`スポーンを前提にしており未対応、config系テストは実行順で結果が変わる)。変更前後でスタッシュ比較し、この揺れが今回の修正と無関係であることは確認済み(§2c末尾参照)。

**並行作業の注意**: 同じ`cmux`リポジトリ(windows-portブランチ、未コミット)で、別セッションが`ui/graphics.rs`(Windows Terminal向け`CSI 16 t`セルピクセルサイズ問い合わせ)を並行して編集中(ユーザー承知の上、意図した並行作業)。`git status`で自分が触っていないファイルの変更が見えても、それは別セッションの作業であり元に戻さないこと。

## 0. これは何か

`spec/spec.md`(凍結済み、要望①②③+ドキュメント)は2026-07-25にPhase 2/3として完了・公開済み(`spec/handoff.md`参照)。その**同日**、ユーザーから追加のUX改善5点の要望が来た。これはその追加ラウンドの実装引き継ぎ書。**`spec/spec.md`・`spec/decisions.md`は凍結済みのまま変更しない**(このラウンドはその上に乗る追加作業として扱う)。

## 1. 結論: 5点中2点は決着済み・着手不要

- **④ HTMLをTUIペイン内でプレビュー**: **kitty graphicsは却下のまま、Sixelで2026-07-25に実装完了**。実機検証(cmux-tuiを介さず素のWindows Terminalタブで、32x32 PNGを生のkitty graphics APCエスケープシーケンスで直接送信)の結果、Windows Terminal自体がkitty graphicsに非対応と実証済みで、この判断は変えない。ただしその後、Windows Terminal stable(1.24系)がSixelには対応済みと判明したため、`browser.sixel`設定(既定false、opt-in。Windows上ではkittyと同様に対応をプローブできないため設定で明示的に有効化する設計)でSixelエンコードのin-TUIプレビューを実装(`cmux-tui/src/ui/graphics.rs`の`encode_sixel`/`GraphicsProtocol::Sixel`)。PNGデコードは`png` crate、量子化は固定6x6x6 RGBキューブ(216色、ディザリングなし)、RLE圧縮あり。ビルド・ユニットテスト10件pass。**実機でのSixel表示確認pass(2026-07-25、ユーザー確認)** — `%APPDATA%\cmux\cmux-tui.json`に`{"browser": {"sixel": true}}`を設定し、`verify-phase4`セッションで`samples/preview-test.html`を`o`で開いたところ、カラースウォッチ5色(RED/GREEN/BLUE/YELLOW/PURPLE)がそれぞれ判別可能な形でペイン内に描画された(多少ぼやけるのは6x6x6量子化による想定内の劣化)。見出しの下線・配色も再現。②(右に新規ペインで開く)の動作も同時に確認できた。

**`/copy`貼り付け時の改行暴発対策も実機確認pass(2026-07-25、ユーザー確認)**: `verify-phase4`セッションで15行・382文字(日英混在+Markdown記号)のクリップボードを`micro`エディタに貼り付け、欠落・文字化けなく最終行まで正しく入ることを確認。貼り付け前後のタイピングにもラグなし。PowerShellのシェルペインに直接貼り付けた場合は改行のたびに行が逐次実行される(`echo1`→`echo2`→`echo3`が別々のプロンプトで実行)が、これはPowerShell/PSReadLine側がブラケットペーストモード(mode 2004)を有効化していないために起きる現象で、cmux側`paste()`(`app.rs:8194-8226`)はUnix向けと同じロジックでmode 2004の有無を見て正しく分岐している(コード確認済み)。テキスト自体は各行とも欠落・文字化けなく完全な形で届いており、当初懸念していた「改行のたびに途中送信される」不具合は解消と判断。

> **訂正(2026-08-08、Phase 7)**: この「解消と判断」は誤りだった。上記の実機確認は`micro`エディタへの
> 貼り付けのみで、Windows版crossterm特有の挙動(1キー入力ごとにPress/Releaseの2イベントが届く)を
> 考慮していなかったため、シェル(Claude Codeのプロンプト含む)への貼り付けでは実際には機能しておらず、
> 改行のたびに途中送信される不具合が残っていた。`micro`はEnterが個別キーで届いても単に改行を挿入する
> だけで実害が出ないため、この検証では見抜けなかった。詳細と修正は`README.md`のPhase 7、
> `docs/keybindings.md`の「貼り付け(paste)」節を参照。
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
- **マウスホイールスクロール未対応、2026-07-26追記で実装完了(ビルド・ユニットテストpass、実機確認は次回②とあわせて実施)**: 原因は`app.rs::handle_scroll`が`SidebarView::Workspaces`のときしか処理しておらず、Files/Sessionsビューではホイールイベントが素通りしていたこと。3ビューは`workspace_sidebar_area`(同じ矩形、`sidebar_layout_for`で計算)を共有しているため、ビュー判定の条件漏れだった。対応: `sidebar_files/mod.rs`の`move_selection`(選択行を相対移動する既存の内部関数)を`pub`化し、`app.rs::handle_scroll`の分岐条件を`self.sidebar_view == SidebarView::Workspaces` → `matches!(self.sidebar_view, SidebarView::Workspaces | SidebarView::Files)`に拡張。Filesビューのときはホイール1刻みで`sidebar_files.move_selection(±3)`を呼び、既存の`update_scroll`(①で追加済み)が描画時に選択行を画面内へ追従させる。Sessionsビューは今回スコープ外のまま(ユーザーからの要望は「ファイルビュー」のみだったため)。
  - 回帰テスト`app::tests::mouse_wheel_scrolls_file_sidebar_selection`を追加。ただし新規テストは既存の`test_mux`ヘルパー(`/bin/sh -c "sleep 30"`をハードコードしておりWindowsで`CreateProcessW`が失敗する)を使うと落ちるため、Windows上で既にpassしている`mouse_wheel_scrolls_machine_and_workspace_rail_viewports_independently`と同じパターン(`Mux::new(name, SurfaceOptions::default())` + `mux.new_workspace(..., None)`)に合わせて書いた。2回連続pass。
  - フルテストスイート(`cargo test -p cmux-tui --target x86_64-pc-windows-gnu`)は本修正と無関係な環境起因のフレーキーが約25〜29件ある。内訳は主に (a) `test_mux`ヘルパー使用テスト(`/bin/sh`前提でWindows未対応)、(b) `config::tests::*`(実行順・並列実行で結果が変わる)、(c) `machine_action_worker`/`pointer_motion`/`deferred_input`系の並行処理タイミング依存テスト。**変更前後でstash比較して検証**: 変更前(スタッシュ)でフルスイート実行→25件失敗、変更を戻して再実行→29件、さらにもう一度→26件と、失敗件数・失敗テストの組み合わせ自体が実行のたびに変動し、変更の有無と相関しないことを確認した。したがって本修正によるリグレッションではないと判断(ただしこのフレーキー自体は別途対応が要るなら次回判断)。
  - まだ**コミットしていない**(windows-portブランチの作業ツリーに変更あり)。②の実機確認とあわせてpass後にコミットする。

### 2d. ユーザー実機確認(2026-07-26、マウスホイール実装後)で新たに判明した3件

マウスホイールはpassしたが、そのあとの実機操作で3件報告あり。切り分け結果:

1. **②(Enterで新規ペイン)が無反応**: 画面下部に"send to focused pane"(実際の文言は`sent to focused pane`)は出るが、ペインもブラウザも開かない。
   - 原因(推定、未確定): `run_file_command`の`FileCommand::OpenEditor`(`app.rs:7172-7175`)は`$EDITOR`が未設定だと`vi`にフォールバックするが、Windowsに`vi`は無い。`App::split_with_command`(`app.rs:1847-1860`)は`enqueue_with_completion`で**非同期にキューイングして即座に`Ok(())`を返す**設計(`session.split_with_command`の実際の呼び出し・プロセス起動は後で完了する)ため、キューイング自体は成功して`sent to focused pane`が表示されるが、裏で`vi`のプロセス起動が失敗しても**UIには何も反映されない**(サイレント失敗)。
   - `$EDITOR`をmicroのフルパスに設定するのは`bin\cmux.ps1`ランチャ(`bin/cmux.ps1:11-17`)の役目だが、**前回の実機確認手順ではdebug exeを直接起動しており`bin\cmux.ps1`を経由していなかった**ため`$EDITOR`が未設定だった可能性が高い。次回は`bin\cmux.ps1`経由で再検証し、それでも無反応ならコードのバグとして追加調査する(候補: `enqueue_with_completion`の完了ハンドラでエラーが握り潰されている、または`split_with_command`/`split_with_browser`のWindows上でのプロセス起動そのものに問題がある等)。
2. **フォルダ左の三角(▸)をクリックしても展開されない**: コード確認の結果、**実装漏れと判明**。`ui/sidebar.rs`(旧694-697行)はディレクトリ行全体を単一の`Hit::SidebarFile{index}`として登録しており、クリック時は`select(index)`(選択)しか呼ばれず、展開/折りたたみはキーボード(→・←・Enter)からしか呼ばれていなかった。
   - 対応: `Hit::SidebarFileToggle{index}`を新設し、マーカー(▸/▾、2桁分)の矩形だけをこのHitとして行のHitより先に登録(`App::hit_at`は`self.hits.iter().find(...)`で最初に一致したHitを返すため、先に登録した狭い矩形が優先される)。クリックハンドラで`select(index)` + 新設`FileBrowser::toggle_expand_selected()`(展開中なら折りたたみ、そうでなければ展開)を呼ぶ。`collapse_selected_or_go_to_parent`から共通処理`collapse_if_expanded()`を抜き出して再利用(重複回避)。
   - 回帰テスト`app::tests::mouse_click_on_expand_marker_toggles_directory`追加、pass。
3. **ファイルのダブルクリックで開かない**: コード確認の結果、**ダブルクリック検出自体が未実装**と判明(このコードベースに既存のダブルクリック機構は無かった)。
   - 対応: `App`に`sidebar_file_last_click: Option<(Instant, usize)>`を追加し、`Hit::SidebarFile{index}`クリック時に同じ`index`への2回目のクリックが`SIDEBAR_FILE_DOUBLE_CLICK_WINDOW`(400ms)以内なら`sidebar_files.activate_selected()`(Enterと同じ処理)を呼んで`run_file_command`へ渡すよう実装。`activate_selected`を`pub`化。
   - 回帰テスト`app::tests::double_click_on_file_row_activates_it_but_a_single_click_does_not`追加、pass(単発クリックでは発火せず、2回目で発火することを確認)。

**テスト作成時の落とし穴(次回の参考)**: 上記2件のテストを最初に書いたとき、`sync_layout`が内部で呼ぶ`sync_sidebar_files_to_focus`(フォーカス中サーフェスのcwdへの自動追従、`app.rs:5181-5195`)が、`FileBrowser::new(temp)`をpin前に`sync_layout`すると**テスト用の一時ディレクトリではなく実際のプロセスのカレントディレクトリへ勝手にリルート**してしまい、想定外のディレクトリを展開してテストが落ちた(プロダクションコードのバグではなくテストの呼び出し順序の問題)。修正: `sync_layout`を`sidebar_files`差し替えの**前**に呼ぶ(以後`sync_layout`を呼ばなければ後からの差し替えは安全)。3件のテスト全てをこの順序に修正済み。

ビルドexit 0、対象ユニットテスト18件(sidebar_files全14件+新規4件のapp::testsケース含む)pass。まだ**コミットしていない**。実機確認(①の手順、上記1〜3)は次回持ち越し。

### 2e. ユーザー実機確認(2026-07-26、三角クリック・ダブルクリック実装後)で②が依然無反応

①(三角クリックでの展開)とマウスホイールはユーザー実機確認pass。しかし**②(Enter)・ダブルクリックは`bin\cmux.ps1`経由で起動しても無反応のまま**(サイドバー下部に"sent to focused pane"は出るが、新規ペインは作られない)。

- **EDITOR未設定・vi フォールバック説は否定された**: `bin\cmux.ps1`の`micro`解決ロジックをその場のPowerShellで直接実行して検証したところ、`C:\Users\user\AppData\Local\Microsoft\WinGet\Packages\zyedidia.micro_...\micro-2.0.15\micro.exe`という実在するフルパスに正しく解決された(`Test-Path`で存在確認済み)。ユーザーも今回`bin\cmux.ps1`経由で起動したことを確認済み。したがって`$EDITOR`がvi にフォールバックしている可能性は排除できる。
- **エラー通知の仕組みを特定**: `run_file_command`の`FileCommand::OpenEditor`は`App::split_with_command`(`app.rs:1847`)→`enqueue_with_completion`(`app.rs:1332`)経由で**非同期にキューイングされ即座に`Ok(())`を返す**。実際のプロセス起動(`Surface::spawn`、`cmux-tui-core/src/surface.rs:451`、`pty.slave.spawn_command(cmd)`)はバックグラウンドスレッドで後から実行され、そこで失敗すると`pending.defer(SessionMutationOutcome::Failed(error.to_string()))`が呼ばれる(`app.rs:1361`)。これが後続のポーリングで`app.rs:5847`の`SessionMutationOutcome::Failed(error) => { ...; self.status_message = Some(format!("session operation failed: {error}")); }`に到達し、**画面右下の`[session-label]`表示位置が赤字太字のエラーメッセージに置き換わる**(`ui/mod.rs:103-121`)。
- **未確認のまま持ち越し**: ユーザーに「Enterを再度試し、画面右下(通常`[verify-phase4]`と出ている場所)に赤字のエラーが出るか」を確認してもらうよう質問したが、回答を得る前にセッション切り替えとなった。**次回セッションはまずこの確認結果を聞くところから再開する**:
  - 赤字のエラーメッセージが出ていれば、その文言(`os error ...`等)がそのまま原因。`Surface::spawn`内の`pty.slave.spawn_command(cmd)?`(`surface.rs:482`)がWindows特有の理由(パス・引数のクォート、ConPTY起動時の何らかの制約等)で失敗している可能性が高いので、その文言を手掛かりに`CommandBuilder`/`portable-pty`のWindows動作を調査する。
  - 赤字が何も出ていなければ、`SessionMutationOutcome::Failed`のドレイン処理自体がこの完了経路(`SessionCompletionAction::SurfaceCreated`)まで届いていない、または`enqueue_with_completion`のクロージャに何らかの理由で到達していない(パニック・デッドロック等)可能性がある。`app.rs`の`pending_session_completions`の処理タイミング(いつ・どこでポーリングされるか)を再確認する。
  - もう一つの切り分け材料: `o`(ブラウザで開く、`FileCommand::OpenBrowser`)は同じ非同期enqueue経路でも実機で成功しているため(2026-07-26ユーザー確認、新規ペインが右に開いた)、`split_with_command`(コマンド実行)と`split_with_browser`(ブラウザ)の**差分部分**(`spawn_surface_with_command`→`Surface::spawn`の実プロセス起動、対`spawn_browser_surface`のCDP/ブラウザブートストラップ)にバグが絞り込める。
- **Windows Terminal「cmux」プロファイルでの誤起動が発覚**: ユーザーがWindows Terminalの新規タブメニューから起動したところ、`--session`指定なしで既定セッション`main`(ユーザーの普段使いの共有セッション)に接続し、実際に動いていたClaude Codeのペインが見えてしまう挙動が発生した。検証は必ずPowerShellから`--session verify-phase4`を明示して起動すること(本ファイル冒頭「次回セッションでまずやること」参照)。

### 2f. ユーザー実機確認(2026-07-26、4回目)で②・ダブルクリック・①すべてpass、Phase 4完了

前回(§2e)まで「②(Enter)・ダブルクリックが無反応」だったが、同日4回目の実機確認で状況が変わった。

- **②(Enter)が実際にはpassしていた**: `Enter`を押すと右に新規ペインが作られ、選択したファイル(`index.html`)がそこにソースコードとして表示された(スクリーンショットで確認)。その状態でIMEを英数モードにして`o`を押すと、さらに別の新規ペインが開き、同じHTMLがヘッドフルChromeでレンダリングされた(思考ダッシュボードの見た目で表示)。
- **これはバグではなく`spec/spec.md`の元仕様通りの役割分担と判明**: `spec.md`69-70行に「要望②(コード閲覧): Enter で `$EDITOR` = micro を新規PTYタブ起動。ファイル内容のin-TUI表示機能は追加実装しない」「要望③(HTMLプレビュー): `o` キーでHTMLをbrowserタブとして開く」と明記されている。つまり`Enter`は常にエディタでソースを開く設計であり、HTMLファイルであってもブラウザレンダリングにはならない。ユーザーは「Enterを押してもHTML画面(レンダリング結果)が出ない」ことを不具合だと考えていたが、確認の結果これは仕様通りの動作であり、**追加実装は不要**と判断(ユーザー了承済み)。
- **ダブルクリック(§2dで実装)も実機確認pass**: ファイル行のダブルクリックでEnterと同じ動作(新規ペインでエディタが開く)が発火することを確認。
- **①(三角クリックでの展開/折りたたみ、§2cで実装)も実機確認pass**: フォルダ左の▸クリックで展開/折りたたみが動作することを確認。
- **未解決のまま残す点(根本原因不明)**: 2026-07-26の1〜2回目の実機確認では②(Enter)・ダブルクリックとも無反応(fail)だったが、3〜4回目では同じ`bin\cmux.ps1`経由の起動でpassした。原因の切り分け(ビルドの差、タイミング依存、操作手順の違いなど)は行っていない。ユーザーの判断により**深追いしない**。将来再発した場合は、§2eに記録したエラー通知経路の調査(`app.rs:1847`の`split_with_command`→`app.rs:1332`の`enqueue_with_completion`→失敗時`app.rs:5847`の`SessionMutationOutcome::Failed`で赤字表示、または`app.rs:7220-7223`の同期`Err`経路でサイドバー下部にメッセージ表示)を再利用する。
- **結論: Phase 4(UX改善ラウンド)の要望5点+追加検討4点、すべて実機確認pass。本ラウンド完了。**

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
