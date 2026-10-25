"""Extract only baseline snapshots and their manifest into an empty directory."""
import pathlib
import re
import sys
import zipfile

source, destination = map(pathlib.Path, sys.argv[1:])
destination.mkdir(parents=True, exist_ok=False)
with zipfile.ZipFile(source) as archive:
    entries = archive.infolist()
    if sum(entry.file_size for entry in entries) > 2 * 1024**3:
        raise ValueError("Baseline exceeds the 2 GiB uncompressed limit")
    names = [entry.filename for entry in entries]
    if len(names) != len(set(names)):
        raise ValueError("Duplicate baseline entries")
    for entry in entries:
        name = entry.filename
        if entry.is_dir():
            if not re.fullmatch(r"[a-z0-9-]+/", name):
                raise ValueError(f"Invalid directory: {name}")
            continue
        if name != "manifest.json" and not re.fullmatch(
            r"[a-z0-9-]+/[a-z0-9.-]+\.(png|aria\.yml)", name
        ):
            raise ValueError(f"Invalid snapshot path: {name}")
        if (entry.external_attr >> 16) & 0o170000 == 0o120000:
            raise ValueError("Symbolic links are not baseline snapshots")
    archive.extractall(destination)
