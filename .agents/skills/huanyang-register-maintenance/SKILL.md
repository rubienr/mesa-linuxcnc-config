---
name: huanyang-register-maintenance
description: Capture, compare, validate, or render the Huanyang HY02D223B read-only register records in this repository. Use for VFD parameter-backup maintenance, not VFD writes or spindle control.
---

# Huanyang register maintenance

Read `hardware-documentation/current/AGENTS.md` and the VFD topic linked from
`hardware-documentation/current/README.md`.

Preserve these boundaries:

- The local checkout is for editing. Synchronize intended changes to
  `frida@frida:/home/frida/linuxcnc/` without `.git` or `--delete`, then run
  repository tools over SSH from `/home/frida/linuxcnc`. Treat generated files
  returned to the local checkout as pending evidence that still needs review.
- Use `hardware-documentation/current/tools/read-huanyang-vfd.py` for live
  captures. It constructs only Huanyang function `0x01` read requests.
- Never use a general VFD control loop or register-write command as a forensic
  capture substitute.
- A live capture requires explicit user intent, a verified serial device, and a
  safely stopped/unpowered spindle power stage. Do not infer authorization to
  access hardware from a documentation or comparison request.
- Store raw JSON as the primary evidence. Do not hand-edit captured frames or
  values.
- Render Markdown with `python3 hardware-documentation/current/tools/render-huanyang-register-table.py INPUT_JSON OUTPUT_MD`
  and review the resulting diff.
- Treat OCR and family manuals as aids. Physical identity and the matching
  delivered handbook take precedence; retain conflicts and unknown/reserved
  values instead of guessing.

For comparisons, distinguish raw-value changes, capture errors, unsupported
replies, and documentation-only decoding changes. Report the input files,
capture metadata, changed parameters, and whether the generated Markdown is in
sync with its JSON source.
