# c_debug_common

Shared C/C++ sources for the AON / dbg_ss trace-tree bring-up tests
(trace_config, CTI/CTM, HiFi5s TRAX, crash dump).

## Line endings: LF only (no CRLF)

This folder is shared between Windows and Linux (TOT) sessions.
CRLF must NOT be committed or copied to the TOT - Linux editors show ^M.

Rules:
- `.gitattributes` here enforces `eol=lf` for all source files. Do not remove it.
- Do not save these files with CRLF endings.
- If you see ^M in vi, the file was saved with CRLF:
  run `dos2unix <file>` (or strip \r) before committing or copying.
