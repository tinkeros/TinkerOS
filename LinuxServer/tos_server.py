#!/usr/bin/env python

from __future__ import print_function

import serial
import socket
import struct
import sys
import time
import os
import requests
import hashlib
import signal
from pathlib import Path

def signal_handler(signal, frame):
    print("\nProgram exited!")
    sys.exit(0)

signal.signal(signal.SIGINT, signal_handler)


SERIAL_DEV = "/dev/ttyUSB0"
SERIAL_BAUD = 115200
#SERIAL_BAUD = 230400
TCP_IP = '127.0.0.1'
TCP_PORT = 7777
XFR_DIR = "xfr"
CHUNK_SIZE = 64
CHUNK_DELAY = 0.05

os.makedirs(XFR_DIR, exist_ok=True)

def md5sum(filename):
    try:
      with open(filename, mode='rb') as f:
        d = hashlib.md5()
        while True:
          buf = f.read(4096) # 128 is smaller than the typical filesystem block
          if not buf:
            break
          d.update(buf)
        return d.hexdigest()
    except:
        print("Failed to open %s to hash?"%filename)
        return b'0'

class MixedSocket:
    sock=None
    sock_type=None
    def __init__(self,sock_type):
        self.sock_type=sock_type
        if (sock_type=="tcp"):
            self.sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            self.sock.connect((TCP_IP, TCP_PORT))
        else:
            self.sock = serial.Serial(SERIAL_DEV,SERIAL_BAUD)
    def read(self,count):
        if (self.sock_type=="tcp"):
            return self.sock.recv(count)
        else:
            return self.sock.read(count)
    def write(self,data2):
        if type(data2) is tuple:
            data2=data2[0]
        if type(data2) is int:
            data=chr(data2)
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
            return self.sock.write(data)

sock = MixedSocket(sys.argv[1])

# socket #0 is never used
socks = [False]

CMD_SOCKET = 1
CMD_CLOSE = 2
CMD_CONNECT_TCP = 3
CMD_SEND = 4
CMD_RECV = 5
CMD_RECV_FILE = 6
CMD_SEND_FILE = 7
CMD_ID = 8
CMD_GET_URL = 9
CMD_HDIR = 10
CMD_GET_DIR = 11
CMD_CMP_HASH = 12

# TODO HEXEC, return stderr/out

CMD_HELLO = 0xAA

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

def run_server():
    while True:
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
            continue
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
            id = len(socks)
            print("socket(%d, %d)" % (af, type))

            socks.append(socket.socket(socket.AF_INET, socket.SOCK_STREAM))
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
            except:
                print("Failed to send file %s"%filename)
                sock.write(0)
                #raise;
        elif cmd == CMD_GET_URL:
            # note file name string length is limited
            url_length = struct.unpack('B', recvall(sock, 1))
            url = recvall(sock, url_length).decode()
            try:
                print("Got request for URL: %s"%url)
                r = requests.get(url, verify=False,stream=True)
                r.raw.decode_content = True
                #data_buffer = bytes(r.raw.read())
                data_buffer = bytes(r.content)
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

run_server()
