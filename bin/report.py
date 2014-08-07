#!/usr/bin/env python

import sys
import os
import json

INSTRUMENTS_DIR="instruments"
CRASH_DIR="crash"
DATA_DIR="data"

class Report(object):
    def __init__(self, result_dir):
        self.result_dir = result_dir

    def readData(self):
        d = os.path.join(self.result_dir, DATA_DIR)
        if not os.path.isdir(d):
            print "%s is not found!" % d
            return False
        filename = os.path.join(d, "ActivityMonitor-1")
        if not os.path.isfile(filename):
            print "%s is not found!" % filename
            return False

        keys = ["CPUUsage", "ResidentSize"]
        data = {}
        data["summary"] = dict((k, []) for k in keys)
        data["samples"] = dict((k, []) for k in keys)
        try:
            rdata = False
            with open(filename, "r") as f:
                rdata = json.load(f)
                f.close()
            if not rdata or len(rdata) == 0:
                print "no found data!"
                return False
            for item in rdata:
                for k in keys:
                    data["samples"][k].append(item[k])

        except Exception, e:
            print "Exception: %s" % str(e)
            return False
        for k in keys:
            avg = sum(data["samples"][k]) / len(data["samples"][k])
            xmin = min(data["samples"][k])
            xmax = max(data["samples"][k])
            data["summary"][k] = [avg, xmin, xmax]
        return data

    def printData(self, data):
        template = "{0:10}|{1:15}|{2:15}"
        print template.format("", "CPU (%)", "Real Memory (MB)")
        summary = data["summary"]
        cpu = summary["CPUUsage"]
        mem = [v/1024.0/1024.0 for v in summary["ResidentSize"]]
        template = "{0:10}|{1:15.2f}|{2:15.2f}"
        print template.format("min", cpu[1], mem[1])
        print template.format("avg", cpu[0], mem[0])
        print template.format("max", cpu[2], mem[2])

    def readCrash(self):
        d = os.path.join(self.result_dir, CRASH_DIR)
        if not os.path.isdir(d):
            print "%s is not found!" % d
            return False
        for filename in os.listdir(d):
            if filename.endswith('ips'):
                print filename
        return False

    def show(self):
        #data = self.readData()
        #self.printData(data)

        crash = self.readCrash()
        pass

def usage():
    print "report <result_dir>"
    sys.exit(1)

def main():

    if len(sys.argv) != 2:
        usage()
    result_dir = sys.argv[1]
    if not os.path.isdir(result_dir):
        usage()
    report = Report(result_dir)
    report.show()

if __name__ == '__main__':
    main()
