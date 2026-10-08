#! /bin/bash
. venv/bin/activate
python tos_server.py --mode server --type serial --port /dev/ttyUSB0 --dir tos_xfr

