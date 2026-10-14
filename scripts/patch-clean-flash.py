#!/usr/bin/env python3
"""Build the pinned Mac PPAPI runtime from the local reference bundle.

Patch reference recorded for this project:
https://github.com/darktohka/FlashPatch/blob/master/FlashPatch/Patches.cs
The exact upstream commit and the reference bundle's distribution origin have
not been independently verified. Keep the local input unchanged and write a
separate runtime bundle.
"""

from hashlib import sha256
from pathlib import Path
from shutil import copytree, rmtree


ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "runtime/flash-source.plugin"
TARGET = ROOT / ".build/flash-runtime.plugin"
BINARY = Path("Contents/MacOS/PepperFlashPlayer")
EXPECTED_SIZE = 15_313_744
EXPECTED_SHA256 = "555d8be93c491db65a97ae1de86f921ddb850eeb3213d8cd9bac20245bdc5c3a"

# Five recorded edits for this pinned Chinese Mac 64-bit Chrome PPAPI binary.
PATCHES = (
    (0x56C3F9, bytes.fromhex("74 4c"), bytes.fromhex("90 90")),
    (0x56C438, bytes.fromhex("74 0d"), bytes.fromhex("90 90")),
    (0x56C441, bytes.fromhex("0f 84 2e 03"), bytes.fromhex("e9 2f 03 00")),
    (0x56C446, bytes.fromhex("00"), bytes.fromhex("90")),
    (0x5CA720, bytes.fromhex("55 48 89 e5 41 56"), bytes.fromhex("b8 01 00 00 00 c3")),
)


def main() -> None:
    source_binary = SOURCE / BINARY
    original = source_binary.read_bytes()
    digest = sha256(original).hexdigest()
    if len(original) != EXPECTED_SIZE or digest != EXPECTED_SHA256:
        raise SystemExit(f"基准插件与已验证版本不符：size={len(original)}, sha256={digest}")

    patched = bytearray(original)
    for offset, before, after in PATCHES:
        if len(before) != len(after) or patched[offset : offset + len(before)] != before:
            raise SystemExit(f"补丁字节不匹配：0x{offset:x}")
        patched[offset : offset + len(before)] = after

    if TARGET.exists():
        rmtree(TARGET)
    TARGET.parent.mkdir(parents=True, exist_ok=True)
    copytree(SOURCE, TARGET)
    (TARGET / BINARY).write_bytes(patched)
    print(f"已生成 Flash 运行组件：{TARGET}")
    print(f"sha256={sha256(patched).hexdigest()}")


if __name__ == "__main__":
    main()
