#!/usr/bin/env python3
import os
import re
import sys
from pathlib import Path

def restore(directory):
    path = Path(directory).expanduser().resolve()
    if not path.is_dir():
        print(f"Error: {path} is not a directory")
        return
        
    # Match filenames ending in _1, _2, etc. before the extension
    pattern = re.compile(r"^(.*?)(_\d+)(\.[^.]+)$")
    
    renamed_count = 0
    # Walk bottom-up to avoid issues if directories were renamed
    for p in sorted(path.rglob('*'), key=lambda x: len(x.parts), reverse=True):
        if not p.is_file():
            continue
        
        match = pattern.match(p.name)
        if match:
            base, suffix, ext = match.groups()
            original_name = base + ext
            original_path = p.with_name(original_name)
            
            if not original_path.exists():
                print(f"Renaming: {p.relative_to(path)} -> {original_path.relative_to(path)}")
                os.rename(p, original_path)
                renamed_count += 1
            else:
                print(f"Skipping (target exists): {p.relative_to(path)} -> original {original_name} exists")
                
    print(f"\nRestored {renamed_count} files.")

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Usage: python3 restore_names.py <directory>")
        sys.exit(1)
    restore(sys.argv[1])
