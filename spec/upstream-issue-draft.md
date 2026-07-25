# Upstream issue draft (cmux-tui on native Windows / x86_64-pc-windows-gnu)

> **状態: 下書き(未起票)。** これは manaflow-ai/cmux へ報告する場合の英語ドラフトです。起票するかどうかはユーザー判断で、本ファイル作成時点では起票していません(spec D8)。
>
> 対象は `my-cmux\cmux` の `windows-port` ブランチ(base = `main` `7652d3b`)にある3コミット。いずれも `#[cfg(windows)]` / `#[cfg(unix)]` で分岐しており、**Unix 側の挙動は変えません**。下書きは「1件の親 issue + 3つの独立した修正提案」の体裁です。

---

## Parent issue: Native Windows (gnu) build + basic multiplexing / file preview

**Environment**

- Target/host: `x86_64-pc-windows-gnu` (rustup GNU host, target == host)
- Toolchain: zig 0.15.2, LLVM 20.1.8 (libclang), MSYS2 mingw64 (binutils 2.46.1, gcc 16.1.0)
- Terminal: Windows Terminal
- No MSVC Build Tools / no Windows SDK installed

Building and running `cmux-tui` natively on Windows (not WSL) surfaced three independent problems. Each has a small, platform-guarded fix that does not affect macOS/Linux. Details and proposed patches below; happy to open these as separate PRs.

---

## 1. `ghostty-vt-sys/build.rs`: `WindowsSdkNotFound` when target == host on a gnu-hosted Windows toolchain

**Symptom**

`cargo build -p cmux-tui --target x86_64-pc-windows-gnu` fails while building the vendored `ghostty-vt` static lib. The zig build aborts with `WindowsSdkNotFound` even though a full MinGW/GNU toolchain is present.

**Root cause**

`crates/ghostty-vt-sys/build.rs` only passes `-Dtarget=<zig-target>` to the zig build when `target != host`:

```rust
if target != host
    && let Some(zig_target) = zig_target_for_rust_target(&target)
{
    command.arg(format!("-Dtarget={zig_target}"));
}
```

On a gnu-hosted Windows toolchain the Rust `target` (`x86_64-pc-windows-gnu`) equals the `host`, so `-Dtarget` is skipped and zig falls back to its **native default ABI, which is msvc**. That path requires a Windows SDK, which isn't installed in a pure MinGW setup, hence `WindowsSdkNotFound`.

**Fix (proposed)** — always pass `-Dtarget` when a mapping exists, regardless of target vs host:

```rust
let _ = &host; // otherwise unused now; keep reading it for the log
if let Some(zig_target) = zig_target_for_rust_target(&target) {
    command.arg(format!("-Dtarget={zig_target}"));
}
```

This keeps behavior identical on cross builds (where `target != host` already holds) and fixes the same-target gnu case by pinning the gnu ABI explicitly. (windows-port commit `3fac740`.)

**Note:** a second, environment-side workaround is also required in this setup — `BINDGEN_EXTRA_CLANG_ARGS` must pass `--target` / `--sysroot` / `-resource-dir` so bindgen's libclang finds MinGW's builtin headers (`limits.h` etc.). That is a local env setting, not a source change, so it is not part of this patch — but it may be worth documenting for gnu-host contributors.

---

## 2. `ui/graphics.rs`: terminal capability queries (DA1 / `CSI 14 t`) leak into the pane prompt on Windows

**Symptom**

On startup, stray bytes such as `[?61;...c` and `[4;...t` appear in the active pane's shell prompt on Windows.

**Root cause**

`probe_kitty_graphics()` and `query_cell_pixels()` write terminal queries to stdout, then call `read_stdin_for()` to read the reply. `read_stdin_for` only has a real (poll(2)-based) implementation under `#[cfg(unix)]`; on Windows the `#[cfg(not(unix))]` stub just returns an empty `Vec`, so the reply is never read. The terminal's `CSI ? ... c` / `CSI 4 ; ... t` responses therefore go unconsumed and end up echoed into the pane.

Since kitty-graphics probing already resolves to "unsupported" on Windows (the reply can't be read anyway), emitting the query has no upside and only produces the leak.

**Fix (proposed)** — guard the query writes with `#[cfg(unix)]`. The subsequent empty read then yields "unsupported" / default cell size, which is the intended Windows behavior (no in-TUI kitty graphics):

```rust
pub fn probe_kitty_graphics() -> bool {
    #[cfg(unix)]
    {
        let mut stdout = std::io::stdout();
        let _ = write!(stdout, "\x1b_Gi=31,s=1,v=1,a=q,t=d,f=24;AAAA\x1b\\\x1b[c");
        let _ = stdout.flush();
    }
    let bytes = read_stdin_for(Duration::from_millis(180));
    // ...
}
```

The same guard is applied to the `\x1b[14t` write in `query_cell_pixels()`. (windows-port commit `1b5369b`.)

---

## 3. `sidebar_files/mod.rs` `file_url()`: Windows paths produce a broken `file://` URL → blank browser preview + wedged CDP page target

**Symptom**

Opening a local `.html`/`.md` from the file sidebar with `o` shows a blank page in the browser, and the CDP page target wedges (`Page.enable` hangs). Opening a fresh `about:blank` browser tab works fine — only file URLs are affected.

**Root cause**

`file_url()` percent-encodes everything that isn't an unreserved char. For a Windows path like `C:\a\b` this turns the drive letter and backslashes into percent-escapes **inside the URL authority**:

```
C:\a\b  →  file://C%3A%5Ca%5Cb
```

Chrome parses `C%3A%5C...` as a bogus host, so the page never loads and the page target wedges.

**Fix (proposed)** — on Windows, emit an empty authority (`file:///`), keep the drive colon, and map backslashes to forward slashes, so `C:\a\b` becomes `file:///C:/a/b`:

```rust
#[cfg(windows)]
if text.as_bytes().first().is_some_and(|b| b.is_ascii_alphabetic())
    && text.as_bytes().get(1) == Some(&b':')
{
    url.push('/'); // -> file:///
}
for byte in text.bytes() {
    match byte {
        b'A'..=b'Z' | b'a'..=b'z' | b'0'..=b'9' | b'-' | b'.' | b'_' | b'~' | b'/' => {
            url.push(char::from(byte));
        }
        #[cfg(windows)] b'\\' => url.push('/'),
        #[cfg(windows)] b':'  => url.push(':'),
        _ => url.push_str(&format!("%{byte:02X}")),
    }
}
```

(windows-port commit `3090c03`.)

---

## Suggested filing order

1. **#1 (build.rs)** is the highest-value upstream fix — it unblocks the native gnu-hosted Windows build for everyone and is a strict superset of the current condition.
2. **#2** and **#3** are Windows-only behavior fixes, each self-contained and guarded so they cannot cause regressions on Unix.
