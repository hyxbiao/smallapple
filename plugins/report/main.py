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

    def readPerfermaceSample(self, filename):
        keys = ["CPUUsage", "ResidentSize", "Date"]
        samples = []
        try:
            rdata = False
            with open(filename, "r") as f:
                rdata = json.load(f)
                f.close()
            if not rdata or len(rdata) == 0:
                print "no found data in '%'!" % (filename)
                return False
            for item in rdata:
                nitem = {}
                for k in keys:
                    v = item[k]
                    v = v.encode('utf-8') if type(v) is unicode else v
                    if k == 'Date':
                        v = datetime.datetime.strptime(v, '%Y-%m-%d %H:%M:%S:%f')
                    nitem[k] = v
                samples.append(nitem)

        except Exception, e:
            print "Exception: %s" % str(e)
            return False
        return samples

    def readData(self):
        d = os.path.join(self.result_dir, DATA_DIR)
        if not os.path.isdir(d):
            print "%s is not found!" % d
            return False

        flist = []
        for filename in os.listdir(d):
            if filename.startswith("ActivityMonitor"):
                idx = int(filename.split('-')[1])
                flist.append([idx, filename])
        flist.sort()

        data = []
        for item in flist:
            idx = item[0]
            filename = os.path.join(d, item[1])
            samples = self.readPerfermaceSample(filename)
            if samples:
                data.append([idx, samples])
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

    def readMatchImages(self, dirname):
        images = []
        for filename in os.listdir(dirname):
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

    def readScreenshot(self):
        d = os.path.join(self.result_dir, INSTRUMENTS_DIR)
        if not os.path.isdir(d):
            print "%s is not found!" % d
            return False
        dlist = []
        for name in os.listdir(d):
            if name.startswith("Run"):
                idx = int(name.split(' ')[1])
                dlist.append([idx, name])
        dlist.sort()

        screenshots = []
        for item in dlist:
            idx = item[0]
            path = os.path.join(d, item[1])
            images = self.readMatchImages(path)
            if images:
                screenshots.append([idx, images])
        return screenshots

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
        start_times = []
        if trace_data:
            for item in trace_data:
                idx = item[0]
                samples = item[1]
                for sample in samples:
                    ts = int(calendar.timegm(sample['Date'].timetuple()) * 1000)
                    cpudata.append('[%u, %.2f]' % (ts, sample['CPUUsage']))
                    memdata.append('[%u, %.2f]' % (ts, sample['ResidentSize'] / 1024.0 / 1024.0))
                first_ts = int(calendar.timegm(samples[0]['Date'].timetuple()) * 1000)
                start_times.append([first_ts, idx])
            pointstart = start_times.pop(0)
        render_data['cpudata'] = ','.join(cpudata)
        render_data['memdata'] = ','.join(memdata)
        render_data['pointStart'] = pointstart
        render_data['start_times'] = json.dumps(start_times)

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
            for item in screenshot:
                idx = item[0]
                images = item[1]
                for s in images:
                    ts = int(calendar.timegm(s[0].timetuple()) * 1000)
                    screenshot_dict[ts] = [idx, s[1]]
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
            #print data
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
