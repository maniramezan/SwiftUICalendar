#!/usr/bin/env bash

set -euo pipefail

swift format lint --strict --parallel --recursive Package.swift Sources Tests Examples

python3 scripts/export-localizations.py --check
