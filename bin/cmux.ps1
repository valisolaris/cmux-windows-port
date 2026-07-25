# cmux-tui ランチャ (windows-port)
#
# 目的: EDITOR=micro を設定して bin\cmux-tui.exe を起動する。
# 環境変数はこのプロセス内でのみ設定し、システム/ユーザー環境変数は汚さない(spec.md D7)。
#
# micro の解決順:
#   1) PATH に micro があればそれ(winget 導入後、新しいシェルでは PATH に載る)
#   2) 無ければ winget のパッケージ配置から探す(バージョン番号に依存しない glob。
#      winget upgrade で版が上がっても壊れない)
#   3) それも無ければ素の "micro"(最後のフォールバック)
$micro = (Get-Command micro -ErrorAction SilentlyContinue).Source
if (-not $micro) {
    $micro = Get-ChildItem "$env:LOCALAPPDATA\Microsoft\WinGet\Packages\zyedidia.micro_*\*\micro.exe" -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1 -ExpandProperty FullName
}
$env:EDITOR = if ($micro) { $micro } else { "micro" }

& "$PSScriptRoot\cmux-tui.exe" @args
exit $LASTEXITCODE
