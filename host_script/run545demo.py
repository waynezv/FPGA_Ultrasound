import numpy as np
import scipy as sp
from scipy import signal

import matplotlib.pyplot as plt
import pylab as plb

import threading
import time
import os
import signal
import subprocess
import argparse as agp
import struct

def convBin2Num(filepath, convLen):
    f_list = []
    with open(filepath, "r") as f:
        try:
            two_byte = f.read(2)
            while two_byte and convLen:
                tmp, = struct.unpack('H', two_byte)
                f_list = f_list + [tmp & 4095]
                two_byte = f.read(2)
                convLen = convLen - 1
        finally:
            f.close()
    return np.array(f_list)

def watcher(proc, duration):
    ts = time.time()
    print("Current time: %s" % time.ctime(ts))

    tf = time.time()
    tlaps = int(tf - ts)
    while tlaps < duration:
        tf = time.time()
        tlaps = int(tf - ts)
    print("Time passed: %f s" % tlaps)

    os.killpg(os.getpgid(proc.pid), signal.SIGTERM)
    print("DAQ terminated.\n")

def daqProc(filename):
    proc = subprocess.Popen("../xillybus/demoapps/fifo 16777216 /dev/xillybus_read_32 > %s" % filename,
            stdout = subprocess.PIPE, shell = True, preexec_fn = os.setsid)
    return proc


class daqThread (threading.Thread):
    def __init__(self, threadID, threadName, filename, duration):
        threading.Thread.__init__(self)
        self.threadID = threadID
        self.name = threadName
        self.filename = filename
        self.duration = duration
    def run(self):
        print("Starting thread " + self.name)
        proc = daqProc(self.filename)
        watcher(proc, self.duration)

if __name__ == "__main__":
    ## Start DAQ
    print("="*7 + "18-545 FPGA Project Demo" + "="*7)
    print("")

    parser = agp.ArgumentParser(description = "Please choose the operation to run:")
    #  parser.add_argument('-d', '--DAQ', help = 'start data acquisition', required = True)
    parser.add_argument('-t', '--input', type = int, help = 'input sample time (sec)', required = True)
    parser.add_argument('-o', '--output', help = 'output filename', required = True)
    args = parser.parse_args()

    sampleTime = args.input
    filename = args.output

    print("Turn on the switch to START, or RESET\n")
    print("=" * 40)
    print("Start transmitting and receiving signals......")
    print("")

    # Open DAQ thread
    thrndPool = []

    thread1 = daqThread(1, "DAQ", filename, sampleTime)

    thrndPool.append(thread1)

    for t in thrndPool:
        t.setDaemon(True)
        t.start()

    t.join

    # Main thread blocker
    ts = time.time()
    tf = time.time()
    tlaps = int(tf - ts)
    while tlaps < sampleTime + 1:
        tf = time.time()
        tlaps = int(tf - ts)

    #  os.system("hexdump -v -e '1/1 \"%06_ad\" \"\t\"' -e '4/1 \"%02x \" \" | \"' -e '4/1 \"%_p\" \"\n\"'")

    ## Read and convert data
    print("Saving raw data......")
    print("")
    f = open(filename, 'rb')
    rawData = np.fromfile(f, dtype = np.int16)
    np.save(filename, rawData)
    print("Save done.")
    print("")

    print("Start converting data......")
    convLength = 20000
    filepath = "./" + filename
    convArray = convBin2Num(filepath, convLength)
    np.save(filename + "_conv", convArray)
    print("Convert done.")
    print("")

    print("Start processing data......")
    data = np.load(filename + "_conv.npy")
    print("Plot original data")
    print("")

    t = np.linspace(0, 1, 20001)
    t = t[0:19999]
    d = data[0:19999]
    #  fig = plt.figure()
    #  plt.scatter(t, d)

    fig = plt.figure()
    axl = fig.add_subplot(2,1,1)
    plt.plot(t, d, 'g.', t, d, 'b-')

    # fft
    dFft = sp.fftpack.fft(d)

    axl = fig.add_subplot(2,1,2)
    plt.plot(np.abs(sp.fftpack.fftshift(dFft)), 'c-')
    #  np.abs(sp.fftpack.fftshift(dFft))), 'c-')
    plb.show()
    print("Process done.")
    print("")

# Plot data

# DSP

# Results demo

