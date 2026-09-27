#!/usr/bin/env python3
"""Patch the TMF dedicated server (build 2011-02-21, Linux or Windows) so that
ranking ties keep the player who set the time first ahead, instead of ordering
by player id.

The ranking is sorted by an insertion sort. When two entries have equal primary
value and equal best time, the comparison falls through to a final tie-break
that compares the players' id bytes and swaps if id(upper) > id(lower). We make
that tie-break return "don't swap", which makes the sort stable: an entry that
moves up stops below entries that already had the same value.

  Linux  TrackmaniaServer      sort 0x815b6e0, tie-break at 0x815b8d2
  Windows TrackmaniaServer.exe sort 0x4c7250 / compare 0x4c4420, tie-break at 0x4c447b

Usage: patch_tiebreak.py [input] [output]
"""
import hashlib
import sys


def _jmp(frm, to):
    return b"\xe9" + ((to - (frm + 5)) & 0xFFFFFFFF).to_bytes(4, "little")


TARGETS = {
    "linux": dict(
        vaddr=0x815B8D2,
        file_offset=0x815B8D2 - 0x8048000,  # .text mapped at file offset + 0x8048000
        original=bytes.fromhex(
            "891c24"      # mov [esp], ebx          ; upper entry
            "e8d60c0100"  # call 0x816c5b0          ; id(upper)
            "893424"      # mov [esp], esi          ; lower entry
            "88c3"        # mov bl, al
            "e8cc0c0100"  # call 0x816c5b0          ; id(lower)
            "38c3"        # cmp bl, al
            "0f97c0"      # seta al                 ; swap if id(upper) > id(lower)
            "0fb6c0"      # movzx eax, al
            "e9b6feffff"  # jmp 0x815b7a7
        ),
        # xor eax, eax ; jmp 0x815b7a7  -> never swap on a full tie
        patch=bytes.fromhex("31c0") + _jmp(0x815B8D4, 0x815B7A7),
    ),
    "windows": dict(
        vaddr=0x4C447B,
        file_offset=0x4C447B - 0x401000 + 0x400,  # .text VA 0x401000 at file offset 0x400
        original=bytes.fromhex(
            "53"          # push ebx
            "8bca"        # mov ecx, edx            ; upper entry
            "e8fdf5ffff"  # call 0x4c3a80           ; id(upper)
            "8bce"        # mov ecx, esi            ; lower entry
            "8ad8"        # mov bl, al
            "e8f4f5ffff"  # call 0x4c3a80           ; id(lower)
            "3ac3"        # cmp al, bl
            "5b"          # pop ebx
            "1bc0"        # sbb eax, eax
            "f7d8"        # neg eax                 ; swap if id(lower) < id(upper)
            "c3"          # ret
        ),
        # xor eax, eax ; ret  -> never swap on a full tie
        patch=bytes.fromhex("31c0c3"),
    ),
}
for t in TARGETS.values():
    t["patch"] += b"\x90" * (len(t["original"]) - len(t["patch"]))


def detect(data):
    if data[:4] == b"\x7fELF":
        return "linux"
    if data[:2] == b"MZ":
        return "windows"
    sys.exit("unknown file format")


def main():
    src = sys.argv[1] if len(sys.argv) > 1 else "TrackmaniaServer"
    if len(sys.argv) > 2:
        dst = sys.argv[2]
    elif src.lower().endswith(".exe"):
        dst = src[:-4] + ".tiebreak.exe"
    else:
        dst = src + ".tiebreak"
    data = bytearray(open(src, "rb").read())
    kind = detect(data)
    t = TARGETS[kind]
    off, orig, patch = t["file_offset"], t["original"], t["patch"]
    current = bytes(data[off:off + len(orig)])
    if current == patch:
        sys.exit(f"{src} is already patched")
    if current != orig:
        sys.exit(f"unexpected bytes at 0x{off:x}: {current.hex()} (different server build?)")
    data[off:off + len(patch)] = patch
    with open(dst, "wb") as f:
        f.write(data)
    print(f"patched {kind} build {src} -> {dst} (at 0x{t['vaddr']:x})")
    print(f"sha256 {hashlib.sha256(data).hexdigest()}")


if __name__ == "__main__":
    main()
