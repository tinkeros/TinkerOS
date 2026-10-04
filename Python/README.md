# tos_server.py

Host-side bridge for TinkerOS's serial/TCP command protocol. TinkerOS
(running in QEMU or on real hardware) sends single-byte opcodes over a
serial link or TCP socket; this script implements the host side of each
command: proxying TCP sockets, transferring files, listing directories,
fetching URLs, and reading/writing the host clipboard.

See the module docstring at the top of `tos_server.py` for the full list
of supported commands.

## Setup

From this directory (`Python/`):

```sh
python3 -m venv venv
. venv/bin/activate
pip install -r requirements.txt
```

`pyperclip` (used for the clipboard commands) shells out to a system
clipboard tool on Linux — install `xclip` or `xsel` if you need
`CMD_GET_CB_TEXT`/`CMD_SET_CB_TEXT` to work (e.g. `sudo apt install xclip`).

## Usage

```sh
python tos_server.py --mode {client,server} [--type {tcp,serial}] [--port PORT] [--dir XFR_DIR]
```

- `--mode server --type tcp` — listen on `--port` (default `12345`) and
  service one TinkerOS connection at a time.
- `--mode client --type tcp` — connect out to `127.0.0.1:--port`, e.g. a
  QEMU instance that forwards a guest port to that host port.
- `--mode client --type serial` — open `--port` as a serial device
  (115200 baud) instead of TCP.
- `--dir` — directory used for file transfers and directory listings
  (default: `tos_xfr`), created automatically if missing.

### Example: QEMU with `qemu_srv.sh`

Add `-serial mon:stdio -serial tcp::7777,server,nowait` to you QEMU command line and boot TinkerOS.

`qemu_srv.sh` - activates the venv and runs the server in client mode
against a QEMU guest that has forwarded its TinkerOS TCP port to host
port 7777:

```sh
#! /bin/bash
. venv/bin/activate
python tos_server.py --mode client --type tcp --port 7777 --dir tos_xfr
```

Run it from this directory with the venv already created as above:

```sh
./qemu_srv.sh
```
