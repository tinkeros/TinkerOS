#! /bin/bash
. venv/bin/activate
python tos_server.py --mode client --type tcp --port 7777 --dir tos_xfr

