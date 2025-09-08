#!/usr/bin/env bash

set -euo pipefail

swift format lint --strict --parallel --recursive Package.swift Sources Tests Examples
