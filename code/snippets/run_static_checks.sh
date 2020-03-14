#!/bin/bash

if [ -z "$1" ]; then
    echo "Please specify the root drectory."
    exit 1
fi
ROOT="$1"

# python checks
find "$ROOT" -name "*.py" -print0 | xargs -0 python3 -m doctest
pylint "$ROOT/code/python_tools"
flake8 "$ROOT/code/python_tools"
MYPYPATH="$ROOT/code/python_tools" mypy "$ROOT/code/python_tools" --config-file "$ROOT/mypy.ini"

# shell checks
find "$ROOT" -path "$ROOT/vivado" -prune -o -name "*.sh" -print0 | xargs -0 shellcheck