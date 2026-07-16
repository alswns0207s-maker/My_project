import argparse, socket, struct
MAGIC_READ=b"MBRD"

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument('--fpga-ip',default='192.168.1.10')
    ap.add_argument('--port',type=int,default=5005)
    ap.add_argument('--addr',type=lambda x:int(x,0),default=0)
    ap.add_argument('--words',type=int,default=16)
    args=ap.parse_args()
    sock=socket.socket(socket.AF_INET,socket.SOCK_DGRAM); sock.settimeout(1)
    pkt=MAGIC_READ+struct.pack('>I I H H',1,args.addr,args.words,0)
    sock.sendto(pkt,(args.fpga_ip,args.port))
    data,_=sock.recvfrom(65535)
    print(data[:64].hex(' '))
    print(data[:64])
if __name__=='__main__': main()
