#!/bin/bash
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
mkdir -p "$DIR/bin"
swiftc -O "$DIR/MenuBar.swift" -o "$DIR/bin/nosleep-menubar"
echo "Built $DIR/bin/nosleep-menubar"
