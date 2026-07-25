# cmux-tui 既定キーバインド111

出典(コードから読み取った実物のみ。推測なし):

- `cmux/cmux-tui/crates/cmux-tui/src/config.rs` の `Keys::default()`(prefix と全アクションの既定チャード)
- `cmux/cmux-tui/crates/cmux-tui/src/sidebar_files/mod.rs` の `handle_key()`(ファイルサイドバー内のキー)

対象コミット: windows-port ブランチ(main = 7652d3b からの一点改造)。既定は tmux 準拠。

## 押し方の基本(重要)

- **prefix = `Ctrl+B`**。非 Alt 系のキーは、まず `Ctrl+B` を押して離し、続けて対象キーを押す(tmux と同じ 2 段階)。
- **Alt 系はモードレス**: `Alt+<キー>` は prefix なしでそのまま効く(`config.rs` の `modeless_action_for`: Alt 修飾のチャードのみモードレス)。
- 大文字表記(例 `X`, `B`, `W`, `S`)は Shift 併用を意味する(`Ctrl+B` のあと `Shift+x` 等)。
- 設定 `%APPDATA%\cmux\cmux-tui.json` の `keys` で上書き可能。`alt_shortcuts: false` で Alt 系モードレスを一括無効化できる。

## タブ(tab)

| 操作 | prefix 経由 | Alt モードレス |
|---|---|---|
| 新規タブ (new-tab) | `Ctrl+B` → `t` | `Alt+t` |
| 新規ブラウザタブ (new-browser-tab) | `Ctrl+B` → `Shift+b`(`B`) | — |
| 次のタブ (next-tab) | `Ctrl+B` → `Tab` | — |
| 前のタブ (prev-tab) | `Ctrl+B` → `Shift+Tab` | — |
| タブを閉じる (close-tab) | `Ctrl+B` → `Shift+x`(`X`) | — |

## ペイン(pane)

| 操作 | prefix 経由 | Alt モードレス |
|---|---|---|
| スマート分割/新ペイン (new-pane-smart) | — | `Alt+n` |
| 右に分割 (split-right) | `Ctrl+B` → `%` | — |
| 下に分割 (split-down) | `Ctrl+B` → `"` | — |
| ペインを閉じる (close-pane) | `Ctrl+B` → `x` | — |
| ペイン最大化トグル (zoom-pane) | `Ctrl+B` → `z` | — |
| ペインを前へ入れ替え (swap-pane-prev) | `Ctrl+B` → `{` | — |
| ペインを後へ入れ替え (swap-pane-next) | `Ctrl+B` → `}` | — |
| ペイン拡大 (resize-grow) | — | `Alt+=` |
| ペイン縮小 (resize-shrink) | — | `Alt+-` |
| スクロールアップ (scroll-up) | `Ctrl+B` → `[` または `PageUp` | — |
| スクロールダウン (scroll-down) | `Ctrl+B` → `PageDown` | — |

## フォーカス移動

| 操作 | prefix 経由 | Alt モードレス |
|---|---|---|
| 左のペインへ (focus-left) | `Ctrl+B` → `h` または `←` | `Alt+h` / `Alt+←` |
| 右のペインへ (focus-right) | `Ctrl+B` → `l` または `→` | `Alt+l` / `Alt+→` |
| 上のペインへ (focus-up) | `Ctrl+B` → `k` または `↑` | `Alt+k` / `Alt+↑` |
| 下のペインへ (focus-down) | `Ctrl+B` → `j` または `↓` | `Alt+j` / `Alt+↓` |
| 次のペインへ巡回 (focus-next-pane) | `Ctrl+B` → `o` | — |
| サイドバーへフォーカス (focus-sidebar) | `Ctrl+B` → `Shift+s`(`S`) | — |

## サイドバー

| 操作 | prefix 経由 |
|---|---|
| サイドバー表示トグル (toggle-sidebar) | `Ctrl+B` → `s` |
| サイドバーのビュー切替 (toggle-sidebar-view) | `Ctrl+B` → `e` |
| サイドバーへフォーカス (focus-sidebar) | `Ctrl+B` → `Shift+s`(`S`) |

## スクリーン(screen)

| 操作 | prefix 経由 | Alt モードレス |
|---|---|---|
| 新規スクリーン (new-screen) | `Ctrl+B` → `c` | — |
| 前のスクリーン (prev-screen) | `Ctrl+B` → `p` | `Alt+[` |
| 次のスクリーン (next-screen) | `Ctrl+B` → `n` | `Alt+]` |
| スクリーン 1〜9 を選択 (select-screen-N) | `Ctrl+B` → `1`〜`9` | — |
| スクリーン 0 を選択 (select-screen-0) | `Ctrl+B` → `0` | — |
| スクリーン名変更 (rename-screen) | `Ctrl+B` → `,` | — |
| スクリーンを閉じる (close-screen) | `Ctrl+B` → `&` | — |

## ワークスペース(workspace)

| 操作 | prefix 経由 |
|---|---|
| 次のワークスペース (next-workspace) | `Ctrl+B` → `w` |
| 新規ワークスペース (new-workspace) | `Ctrl+B` → `Shift+w`(`W`) |
| ワークスペース名変更 (rename-workspace) | `Ctrl+B` → `$` |

## ブラウザペイン操作

| 操作 | prefix 経由 |
|---|---|
| 戻る (browser-back) | `Ctrl+B` → `<` |
| 進む (browser-forward) | `Ctrl+B` → `>` |
| 再読み込み (browser-reload) | `Ctrl+B` → `r` |
| URL を編集 (browser-edit-url) | `Ctrl+B` → `u` |

## その他

| 操作 | prefix 経由 |
|---|---|
| デタッチ (detach) | `Ctrl+B` → `d` |

## ファイルサイドバー内のキー(sidebar_files)

サイドバーにフォーカスがあるとき(`Ctrl+B` → `Shift+s` でフォーカス)に有効。prefix は不要。
プレーンな文字キーのみ作用し、Ctrl/Alt 併用は基本無効(例外は `Ctrl+j` / `Ctrl+k`)。

| キー | 動作 |
|---|---|
| `↑` / `Ctrl+k` | 選択を1つ上へ |
| `↓` / `Ctrl+j` | 選択を1つ下へ |
| `→` | 選択中のディレクトリに入る |
| `Enter` | 選択を開く。ディレクトリ=移動、ファイル=`$EDITOR` で新規ペインに開く |
| `←` / `h` | 親ディレクトリへ |
| `.` | 隠しファイルの表示トグル |
| `/` | フィルタ(絞り込み)モード開始 |
| `~` | 表示ルートを再設定(reroot) |
| `c` | 選択ディレクトリへの `cd` をフォーカスペインへ送る |
| `o` | 選択した `.html` / `.md` をブラウザタブで開く(それ以外は「.html/.md のみ」メッセージ) |

### 補足(実装挙動)

- `Enter` でファイルを開くと `$EDITOR` を新規コマンドとして起動する(`app.rs` の `FileCommand::OpenEditor`)。
  `$EDITOR` 未設定/空のときは `vi` にフォールバックするため、**Windows ではランチャで `EDITOR=micro` を設定する**(spec.md D5/D7)。
- `o` は `file://` URL を組み立ててブラウザタブで開く(`FileCommand::OpenBrowser` → `file_url()`)。
