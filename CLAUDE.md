# my-cmux (cmux Windows 移植) agent notes

## サブディレクトリの CLAUDE.md について
- `cmux/CLAUDE.md`・`cmux-main/CLAUDE.md` は upstream(macOS 用)のエージェントノート。
  この Windows 移植では従わない(reload.sh / xcodebuild 等は macOS 専用手順)。編集もしない。

## 実機検証(Real-machine verification)
- コード確認だけでタスク完了を宣言しない。TUI/端末系の機能(Sixel、セルピクセル問い合わせ、
  タブ描画、キーバインド)は、既存 cmux ペイン内にネストさせず、実 Windows Terminal
  ウィンドウで検証する(ネストすると CSI 応答が親 cmux に飲まれる)。
- テスト用 cmux セッションの起動は `--socket` を明示する(`--session` 省略は既定 `main`
  =稼働中セッションに接続する罠)。セッション名も稼働中と衝突しない一意名にする。
- 起動先セッション内のデバッグログは環境変数頼みにせず、絶対パスのログファイルへ書く。

## Windows 固有の罠
- 実行中の `.exe` を上書きしない。cmux-tui.exe は現在の Claude セッション自身を
  ホストしていることが多く、ファイルロックされている。旧バイナリを rename してから
  新バイナリを copy するか、タイムスタンプ付きの別パスへビルドする。
- タブ名などの表示幅計算: 絵文字・CJK は幅2として扱う。`.len()`(バイト長)で
  計算せず、表示幅で計算する。
