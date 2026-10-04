"""
tos_server.py - TCP/serial bridge between a TinkerOS instance and the host.

TinkerOS (running under QEMU or on real hardware) speaks a small binary
command protocol over either a TCP socket or a serial port. This script
implements the host side of that protocol so TinkerOS can ask the host to:
  - open/read/write/close TCP sockets on its behalf (CMD_SOCKET, CMD_CONNECT_TCP,
    CMD_SEND, CMD_RECV, CMD_CLOSE)
  - send/receive files into a local transfer directory, with an MD5 hash
    check to skip unchanged files (CMD_SEND_FILE, CMD_RECV_FILE, CMD_CMP_HASH)
  - list files in the transfer directory (CMD_HDIR, CMD_GET_DIR)
  - fetch a URL, raw or HTML-stripped (CMD_GET_URL_RAW, CMD_GET_URL_TEXT)
  - get/set the host clipboard (CMD_GET_CB_TEXT, CMD_SET_CB_TEXT)
  - run a host shell command and return its output (CMD_HOST_EXEC)
  - report the host OS name, e.g. "Linux" (CMD_GET_OS)

Usage:
    python tos_server.py --mode {client,server} [--type {tcp,serial}]
                          [--port PORT] [--dir XFR_DIR]

  --mode server --type tcp     Listen on --port (default 12345) and accept
                                one connection at a time from TinkerOS.
  --mode client --type tcp     Connect out to 127.0.0.1:--port, e.g. a QEMU
                                instance forwarding a guest serial/TCP port
                                to that host port (see qemu_srv.sh).
  --mode client --type serial  Open --port as a serial device (115200 baud)
                                instead of a TCP socket.
  --dir                        Directory used for file transfers and
                                directory listings (default: tos_xfr).

See qemu_srv.sh in this directory for an example invocation, and README.md
for the venv setup this script expects.

Dependencies: pyserial, requests, pyperclip, beautifulsoup4 (see
requirements.txt).
"""

import serial
import sys
import time
import socket
import argparse
import os
import platform
import hashlib
import struct
import signal
import threading
import subprocess
import pyperclip as pc
import requests
from pathlib import Path
from bs4 import BeautifulSoup

# Constants
TCP_IP = '0.0.0.0'
TCP_PORT = "12345"
XFR_DIR = "tos_xfr"
CHUNK_SIZE = 64
CHUNK_DELAY = 0.05
SERIAL_BAUD = 115200
SERIAL_CHUNK_SIZE = 64
SERIAL_CHUNK_DELAY = 0.001

CMD_SOCKET = 1
CMD_CLOSE = 2
CMD_CONNECT_TCP = 3
CMD_SEND = 4
CMD_RECV = 5
CMD_RECV_FILE = 6
CMD_SEND_FILE = 7
CMD_ID = 8
CMD_GET_URL_RAW = 9
CMD_HDIR = 10
CMD_GET_DIR = 11
CMD_CMP_HASH = 12
CMD_GET_CB_TEXT = 13
CMD_SET_CB_TEXT = 14
CMD_HOST_EXEC = 15
CMD_GET_URL_TEXT = 16
CMD_GET_OS = 17

CMD_HELLO = 0xAA

socks = [False]

def alloc_sockfd():
    for i in range(1, len(socks)):
        if socks[i] is None:
            return i
    socks.append(None)
    return len(socks) - 1

os.makedirs(XFR_DIR, exist_ok=True)

def md5sum(filename):
    try:
        with open(filename, mode='rb') as f:
            d = hashlib.md5()
            while True:
                buf = f.read(4096)
                if not buf:
                    break
                d.update(buf)
            return d.hexdigest()
    except:
        print("Failed to open %s to hash?"%filename)
        return '0'

class MixedSocket:
    def __init__(self, sock_type, port):
        self.sock_type = sock_type
        self.port = port
        if sock_type == "client":
            self.sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            self.sock.connect(("127.0.0.1", int(port)))
            self.sock_type="tcp"
        elif sock_type == "tcp":
            self.sock = port
            self.sock_type="tcp"
        elif sock_type == "sock":
            self.sock = socket.socket(socket.AF_UNIX)
            self.sock.bind('/tmp/tos%2.sock' % int(port))
        else:
            self.sock = serial.Serial(port, SERIAL_BAUD)

    def read(self, count):
        if self.sock_type == "tcp":
            return self.sock.recv(count)
        else:
            return self.sock.read(count)
    def write(self,data2):
        if type(data2) is tuple:
            data2=data2[0]
        if type(data2) is int:
            data=bytes([data2])
        else:
            data=data2
        if type(data) is str:
            try:
                data=data.encode()
            except:
                pass #don't care if it fails for non-printable ascii
        if (self.sock_type=="tcp"):
            #return self.sock.send(data)
            for i in range(len(data)//CHUNK_SIZE+1):
                self.sock.send(data[i*CHUNK_SIZE:(i+1)*CHUNK_SIZE])
                time.sleep(CHUNK_DELAY)
        else:
            #return self.sock.write(data)
            for i in range(len(data)//SERIAL_CHUNK_SIZE+1):
                self.sock.write(data[i*SERIAL_CHUNK_SIZE:(i+1)*SERIAL_CHUNK_SIZE])
                time.sleep(SERIAL_CHUNK_DELAY)

def recvall(sock, count2):
    if (type(count2) is tuple) and len(count2)==1:
        count=int(count2[0])
    else:
        count=int(count2)
    s = b''
    while len(s) < count:
        part = sock.read(count - len(s))
        if part is None: break
        s += part

    return s

def run_server_iter(sock):
    cmd = None
    try:
        cmd = ord(sock.read(1))
    except SystemExit:
        raise
    except:
        time.sleep(0.1)
        pass
    #print('%02X' % cmd)
    if cmd is None:
        time.sleep(0.1)
        #continue
        return
    if cmd == CMD_HELLO:
        print('hello!')
        sock.write(b'\xAA')
        print('sent 0xAA')
    elif cmd == CMD_ID:
        print('Got ID command')
        sock.write(b'TOSSERVER')
        print('sent TOSSERVER')
    elif cmd == CMD_CLOSE:
        sockfd = ord(sock.read(1))
        print('close(%d)' % (sockfd))

        if 0 < sockfd < len(socks) and socks[sockfd]:
            socks[sockfd].close()
            socks[sockfd] = None
        sock.write(struct.pack('B', 0))
    elif cmd == CMD_CONNECT_TCP:
        sockfd, length = struct.unpack('BB', recvall(sock, 2))
        hostname = recvall(sock, length).decode()
        port, = struct.unpack('H', recvall(sock, 2))
        print('connectTcp(%d, %s, %d)' % (sockfd, hostname, port))

        try:
            socks[sockfd].connect((hostname, port))
            rc = 0
            print("Connected to %s"%hostname)
        except socket.error as e:
            print(e)
            rc = 0xff

        sock.write(struct.pack('B', rc))
    elif cmd == CMD_RECV:
        sockfd, length, flags = struct.unpack('BBB', recvall(sock, 3))
        print('recv(%d, %d, %d)' % (sockfd, length, flags))

        try:
            data = socks[sockfd].recv(length)
        except socket.error as e:
            print(e)
            data = b''

        sock.write(struct.pack('B', len(data)))
        sock.write(data)
    elif cmd == CMD_SEND:
        sockfd, length, flags = struct.unpack('BBB', recvall(sock, 3))
        data = recvall(sock, length)
        print('send(%d, %s, %d)' % (sockfd, data, flags))
        print('send(%d, %d bytes, %d)' % (sockfd, len(data), flags))

        rc = socks[sockfd].send(data)
        sock.write(struct.pack('B', rc))
    elif cmd == CMD_SOCKET:
        af, type = struct.unpack('BB', recvall(sock, 2))
        id = alloc_sockfd()
        print("socket(%d, %d)" % (af, type))

        socks[id] = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.write(struct.pack('B', id))
    elif cmd == CMD_RECV_FILE:
        length_length = struct.unpack('B', recvall(sock, 1))
        length_str = recvall(sock, length_length).decode()
        length=int(length_str)
        # note file name string length is limited
        filename_length = struct.unpack('B', recvall(sock, 1))
        filename = recvall(sock, filename_length).decode()
        print("Preparing to receive file %s of size %d"%(filename,length));
        try:
            data_buffer = recvall(sock, length)
            filename = XFR_DIR + os.path.sep + filename
            filedir = os.path.dirname(os.path.abspath(filename))
            os.makedirs(filedir, exist_ok=True)
            if filename.endswith(".Z"):
                filename = filename[:-2]
            output_file = open(filename, "wb")
            output_file.write(data_buffer)
            output_file.close()
            print("Recieved file %s"%filename)
            Path(filename).touch()
            sock.write(filename_length)
        except:
            sock.write(0)
            raise
    elif cmd == CMD_CMP_HASH:
        length_length = struct.unpack('B', recvall(sock, 1))
        length_str = recvall(sock, length_length).decode()
        length=int(length_str)
        # note file name string length is limited
        filename_length = struct.unpack('B', recvall(sock, 1))
        filename = recvall(sock, filename_length).decode()
        print("Preparing to receive file %s of size %d"%(filename,length));
        try:
            if (length == 32):
                data_buffer = recvall(sock, length)
                filename = XFR_DIR + os.path.sep + filename
                if filename.endswith(".Z"):
                    filename = filename[:-2]
                    #print("HERE1 %s"%filename)
                #print("HERE2 %s"%filename)
                filedir = os.path.dirname(os.path.abspath(filename))
                os.makedirs(filedir, exist_ok=True)
                Path(filename).touch()
                local_hash = md5sum(filename)
                remote_hash = str(data_buffer.decode('utf-8'))
                print("here hashing %s"%filename)
                print("Local hash: %s"%local_hash)
                print("Remote hash: %s"%remote_hash)
                if local_hash == remote_hash:
                    print("Hashes match for filename: %s"%filename)
                    sock.write(filename_length)
                else:
                    print("Hashes do not match for filename: %s"%filename)
                    sock.write(0)
            else:
                sock.write(0)
        except:
            sock.write(0)
            raise
    elif cmd == CMD_SEND_FILE:
        # note file name string length is limited
        filename_length = struct.unpack('B', recvall(sock, 1))
        filename = recvall(sock, filename_length).decode()
        filename = XFR_DIR + os.path.sep + filename
        try:
            if filename.endswith(".Z"):
                filename = filename[:-2]
            input_file = open(filename,"rb")
            data_buffer = input_file.read()
            length_str = str(len(data_buffer))
            sock.write(chr(len(length_str)))
            sock.write(length_str)
            time.sleep(0.1)
            ack=struct.unpack('B',sock.read(1))[0]
            if (ack != len(length_str)):
              print("Bad ack, got %d, expected %d!",ack,length_str)
              print("Failed to send file %s"%filename)
            else:
              print("Sending file %s"%filename)
              sock.write(data_buffer)
              print("Sent file %s"%filename)
        except:
            print("Failed to send file %s"%filename)
            sock.write(0)
            #raise;
    elif cmd == CMD_GET_URL_RAW or cmd == CMD_GET_URL_TEXT:
        print("HERE CMD_GET_URL")
        # note file name string length is limited
        url_length = struct.unpack('B', recvall(sock, 1))
        url = recvall(sock, url_length).decode()
        try:
            print("Got request for URL: %s"%url)
            r = requests.get(url, verify=False,stream=True)
            if cmd == CMD_GET_URL_RAW:
                r.raw.decode_content = True
                data_buffer = bytes(r.content)
            else:
                soup = BeautifulSoup(r.content, 'html.parser')
                data_buffer=soup.get_text(separator=' ', strip=True)
            length_str = str(len(data_buffer))
            sock.write(chr(len(length_str)))
            sock.write(length_str)
            time.sleep(0.1)
            ack=struct.unpack('B',sock.read(1))[0]
            if (ack != len(length_str)):
              print("Bad ack, got %d, expected %d!",ack,length_str)
              print("Failed to send raw data")
            else:
              print("Sending raw data of length %s"%length_str)
              sock.write(data_buffer)
        except:
            print("Failed to send raw data")
            sock.write(0)
            raise;
    elif cmd == CMD_HDIR:
        # note file name string length is limited
        dir_length = struct.unpack('B', recvall(sock, 1))
        dirname = recvall(sock, dir_length).decode()
        try:
            print("Got request for directory listing of: %s"%dirname)
            dirlist=""
            for item in sorted(os.listdir(XFR_DIR + os.path.sep + dirname)):
                dirlist+="\n"+item
            dirlist+="\n\0"
            data_buffer = dirlist
            length_str = str(len(data_buffer))
            sock.write(chr(len(length_str)))
            sock.write(length_str)
            time.sleep(0.1)
            ack=struct.unpack('B',sock.read(1))[0]
            if (ack != len(length_str)):
              print("Bad ack, got %d, expected %d!",ack,length_str)
              print("Failed to send raw data")
            else:
              print("Sending raw data of length %s"%length_str)
              sock.write(data_buffer)
        except:
            print("Failed to send raw data")
            sock.write(0)
            raise;
    elif cmd == CMD_GET_DIR:
        # note file name string length is limited
        dir_length = struct.unpack('B', recvall(sock, 1))
        dirname = recvall(sock, dir_length).decode()
        try:
            print("Got request for directory listing of: %s"%dirname)
            dirlist=""
            dir_walk_list = [os.path.join(dp, f) for dp, dn, fn in os.walk(os.path.expanduser(XFR_DIR + os.path.sep + dirname)) for f in fn]
            for item in sorted(dir_walk_list):
                if os.path.isfile(item):
                    tmpitem = dirname + os.path.sep + ''.join(item.split(dirname+os.path.sep)[1:])
                    #dirlist+="\n"+item[len(XFR_DIR)+3:]
                    dirlist+="\n"+tmpitem
            dirlist+="\n\0"
            data_buffer = dirlist
            length_str = str(len(data_buffer))
            sock.write(chr(len(length_str)))
            time.sleep(0.1)
            sock.write(length_str)
            time.sleep(0.1)
            ack=struct.unpack('B',sock.read(1))[0]
            time.sleep(0.1)
            if (ack != len(length_str)):
              print("Bad ack, got %d, expected %d!",ack,length_str)
              print("Failed to send raw data")
            else:
              print("Sending raw data of length %s"%length_str)
              sock.write(data_buffer)
        except:
            print("Failed to send raw data")
            sock.write(0)
            raise;
    elif cmd == CMD_GET_CB_TEXT:
        try:
            clip_text=pc.paste()
        except:
            clip_text="Error or no clipboard text!"
        try:
            length_str = str(len(clip_text))
            sock.write(chr(len(length_str)))
            time.sleep(0.1)
            sock.write(length_str)
            time.sleep(0.1)
            ack=struct.unpack('B',sock.read(1))[0]
            time.sleep(0.1)
            if (ack != len(length_str)):
              print("Bad ack, got %d, expected %d!",ack,length_str)
              print("Failed to send raw data")
            else:
              print("Sending raw data of length %s"%length_str)
              sock.write(clip_text)
        except:
            print("Failed to send raw data")
            sock.write(0)
            raise;
    elif cmd == CMD_SET_CB_TEXT:
        try:
            length_length = struct.unpack('B', recvall(sock, 1))
            length_str = recvall(sock, length_length).decode()
            length=int(length_str)
            clip_str = recvall(sock, length).decode()
            pc.copy(clip_str)
        except:
            print("Failed to set clipboard data!")
            sock.write(0)
            raise;
    elif cmd == CMD_HOST_EXEC:
        try:
            length_length = struct.unpack('B', recvall(sock, 1))
            length_str = recvall(sock, length_length).decode()
            length=int(length_str)
            cmd_str = recvall(sock, length).decode()
            try:
                result = subprocess.run(cmd_str, shell=True, check=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
                cmd_res = result.stdout
            except subprocess.CalledProcessError as e:
                # If the command returns a non-zero exit code, you can handle it here
                cmd_res=f"Error executing command: {e}\nOutput:\n{e.stdout}"
            except:
                cmd_res="Error running command: " + cmd_str
        except:
            print("Failed to execute host command!")
            sock.write(0)
            raise;
        try:
            length_str = str(len(cmd_res))
            sock.write(chr(len(length_str)))
            time.sleep(0.1)
            sock.write(length_str)
            time.sleep(0.1)
            ack=struct.unpack('B',sock.read(1))[0]
            time.sleep(0.1)
            if (ack != len(length_str)):
              print("Bad ack, got %d, expected %d!",ack,length_str)
              print("Failed to send raw data")
            else:
              print("Sending raw data of length %s"%length_str)
              sock.write(cmd_res)
        except:
            print("Failed to send raw data")
            sock.write(0)
            raise;
    elif cmd == CMD_GET_OS:
        try:
            os_name = platform.system()
        except:
            os_name = "Unknown"
        try:
            length_str = str(len(os_name))
            sock.write(chr(len(length_str)))
            time.sleep(0.1)
            sock.write(length_str)
            time.sleep(0.1)
            ack=struct.unpack('B',sock.read(1))[0]
            time.sleep(0.1)
            if (ack != len(length_str)):
              print("Bad ack, got %d, expected %d!",ack,length_str)
              print("Failed to send raw data")
            else:
              print("Sending raw data of length %s"%length_str)
              sock.write(os_name)
        except:
            print("Failed to send raw data")
            sock.write(0)
            raise;
    else:
        print("Got unknown cmd %d!\n"%cmd)


def run_server(port):
    server_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server_socket.bind((TCP_IP, port))
    server_socket.listen(5)
    print("Server listening on port %d" % port)
    try:
        while True:
            client_sock, addr = server_socket.accept()
            print("Accepted connection from %s" % str(addr))
            #client_thread = threading.Thread(target=handle_client, args=(client_sock,))
            #client_thread.start()
            client = MixedSocket('tcp',client_sock)
            while True:
                try:
                    run_server_iter(client)
                except:
                    print("Encountered disconnect or error, closing connection!")
                    break
    finally:
        server_socket.close()

def main():
    parser = argparse.ArgumentParser(description='TCP/Serial Communication Tool')
    parser.add_argument('--mode', choices=['client', 'server'], help='Run as client or server', required=True)
    parser.add_argument('--port', type=str, default=TCP_PORT, help='Port number (tcp) or device (serial) to connect or listen on')
    parser.add_argument('--type', choices=['serial','tcp'], default="tcp", help='Type of port to use (serial or tcp)')
    parser.add_argument('--dir', type=str, default="tos_xfr", help='Transfer directory to use')
    args = parser.parse_args()
    global XFR_DIR
    XFR_DIR = args.dir

    if args.mode == 'server' and args.type == "tcp":
        run_server(int(args.port))
    else:
        if args.type=="tcp":
            client = MixedSocket("client", int(args.port))
        else:
            client = MixedSocket(args.type, args.port)
        while True:
            try:
                run_server_iter(client)
            except:
                raise ValueError("Encountered disconnect or error, closing!")

def signal_handler(signal, frame):
    print("\nProgram exited!")
    sys.exit(0)

signal.signal(signal.SIGINT, signal_handler)

if __name__ == '__main__':
    main()



