# NOTICE

## Attribution

This project (**cmux-windows-port**) is a set of Windows-porting patches and
documentation for **cmux**, an open-source project by **Manaflow, Inc.**

- Upstream project: **cmux** — <https://github.com/manaflow-ai/cmux>
- Upstream copyright: © 2024–present **Manaflow, Inc.**
- Upstream license: **GNU General Public License v3.0 or later (GPL-3.0-or-later)**

The upstream `cmux` repository is dual-licensed by Manaflow (GPL-3.0-or-later, or
a separate commercial license). This project uses **only** the GPL-3.0-or-later
option and is licensed, in its entirety, under **GPL-3.0-or-later** (see
[`LICENSE`](LICENSE)).

## No upstream source is bundled

This repository does **not** redistribute upstream cmux source code or any
compiled binary. It contains only:

- **`patches/`** — three patches (`0001`–`0003`) that modify upstream files.
  These are **derivative works** of upstream cmux and are therefore covered by
  **GPL-3.0-or-later**. They are meant to be applied on top of upstream commit
  **`7652d3b1cf`** (`manaflow-ai/cmux`), then built from source. See
  [`README.md`](README.md) for the apply-and-build procedure.
- Original documentation, launcher scripts, and specification notes authored for
  this project.

Because no upstream source or binary is redistributed here, the GPL's
source-distribution obligations for the upstream code are satisfied by upstream
itself; this repository points to the upstream commit rather than vendoring it.

## Trademarks

**"cmux"** and **"Manaflow"** are names/trademarks of their respective owners
(Manaflow, Inc.). This is an **unofficial**, community project. It is **not**
affiliated with, sponsored by, or endorsed by Manaflow, Inc. Any references to
these names are for identification and attribution purposes only.

## Upstream report

The build issue addressed by patch `0001` (zig `-Dtarget` / `WindowsSdkNotFound`
on a GNU-hosted Windows toolchain) has been reported upstream as
**manaflow-ai/cmux#8904**.
