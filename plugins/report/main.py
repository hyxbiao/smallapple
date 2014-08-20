#!/usr/bin/env python

__author__ = "hyxbiao(xuanbiao@baidu.com)"

import sys
import os
import json
import string
import time
import datetime
import calendar
import json

INSTRUMENTS_DIR="instruments"
CRASH_DIR="crash"
DATA_DIR="data"

class ReportTemplate(string.Template):
    delimiter = '@'
    idpattern = r'[a-z][_a-z0-9]*'

class Report(object):
    def __init__(self, work_dir, result_dir):
        self.work_dir = work_dir
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
        sample_keys = keys + ["Date"]
        data = {}
        data["summary"] = dict((k, []) for k in keys)
        data["samples"] = dict((k, []) for k in sample_keys)
        try:
            rdata = False
            with open(filename, "r") as f:
                rdata = json.load(f)
                f.close()
            if not rdata or len(rdata) == 0:
                print "no found data!"
                return False
            for item in rdata:
                for k in sample_keys:
                    v = item[k].encode('utf-8') if type(item[k]) is unicode else item[k]
                    if k == 'Date':
                        v = datetime.datetime.strptime(v, '%Y-%m-%d %H:%M:%S:%f')
                    data["samples"][k].append(v)

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
        crash = []
        for filename in os.listdir(d):
            arr = filename.split('_')
            if len(arr) < 3:
                continue
            try:
                t = arr[-2]
                d = datetime.datetime.strptime(t, '%Y-%m-%d-%H%M%S')
                crash.append([d, filename])
            except Exception, e:
                print "Exception: %s" % str(e)
                continue
        return crash

    def readScreenshot(self):
        d = os.path.join(self.result_dir, INSTRUMENTS_DIR, 'Run 1')
        if not os.path.isdir(d):
            print "%s is not found!" % d
            return False
        images = []
        for filename in os.listdir(d):
            name, ext = os.path.splitext(filename)
            if ext != '.png':
                continue
            arr = name.split('-')
            if len(arr) < 7:
                continue
            try:
                t = '-'.join(arr[-7:])
                d = datetime.datetime.strptime(t, '%Y-%m-%d-%H-%M-%S-%f')
                images.append([d, filename])
            except Exception, e:
                print "Exception: %s" % str(e)
                continue
        return images

    def generateHtml(self, trace_data, crash_data, screenshot):
        #read template
        filename = os.path.join(self.work_dir, 'template.html')

        html = None
        with open(filename, 'r') as f:
            html = f.read()
            f.close()
        if html is None:
            print 'read html template fail'
            return False
        template = ReportTemplate(html)
        render_data = {}
        render_data['workdir'] = self.work_dir
        render_data['resultdir'] = self.result_dir

        #process instrument trace
        cpudata = []
        memdata = []
        pointstart = 0
        if trace_data:
            samples = trace_data["samples"]
            for i in range(len(samples['Date'])):
                ts = int(calendar.timegm(samples['Date'][i].timetuple()) * 1000)
                cpudata.append('[%u, %.2f]' % (ts, samples['CPUUsage'][i]))
                memdata.append('[%u, %.2f]' % (ts, samples['ResidentSize'][i] / 1024.0 / 1024.0))
            pointstart = int(calendar.timegm(samples['Date'][0].timetuple()) * 1000)
        render_data['cpudata'] = ','.join(cpudata)
        render_data['memdata'] = ','.join(memdata)
        render_data['pointStart'] = pointstart

        #process crash
        crashs = []
        if crash_data:
            for crash in crash_data:
                ts = int(calendar.timegm(crash[0].timetuple()) * 1000)
                #path = os.path.join(self.result_dir, CRASH_DIR, crash[1])
                crashs.append([ts, crash[1]])
        render_data['crashs'] = json.dumps(crashs)

        #process screenshot
        screenshot_dict = {}
        screenshot_data = []
        if screenshot:
            for s in screenshot:
                ts = int(calendar.timegm(s[0].timetuple()) * 1000)
                #path = os.path.join(self.result_dir, INSTRUMENTS_DIR, 'Run 1', s[1])
                screenshot_dict[ts] = s[1]
                screenshot_data.append([ts, 0])
        screenshot_data.sort()
        render_data['screenshot_dict'] = json.dumps(screenshot_dict)
        render_data['screenshot_data'] = json.dumps(screenshot_data)

        out_data = template.substitute(render_data)
        #save
        outfile = os.path.join(self.result_dir, 'report.html')
        with open(outfile, 'w') as f:
            f.write(out_data)
            f.close()
        return True

    def generate(self):
        try:
            crash = self.readCrash()
            #print crash

            data = self.readData()
            #self.printData(data)

            screenshot = self.readScreenshot()
            #print screenshot

            return self.generateHtml(data, crash, screenshot)
        except Exception, e:
            print "Exception: %s" % str(e)
            return False
        return True

def usage():
    print "report <result_dir>"
    sys.exit(1)

def main():
    if len(sys.argv) != 2:
        usage()
    result_dir = os.path.abspath(sys.argv[1])
    bin_dir = os.path.dirname(os.path.abspath(sys.argv[0]))
    #work_dir = os.path.dirname(bin_dir)
    work_dir = bin_dir
    if not os.path.isdir(result_dir):
        usage()
    report = Report(work_dir, result_dir)
    ret = report.generate()
    retcode = 0 if ret else 1
    sys.exit(retcode)

if __name__ == '__main__':
    main()
