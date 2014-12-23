#!/usr/bin/env python

__author__ = "hyxbiao(xuanbiao@baidu.com), liguoqiang(liguoqiang01@baidu.com)"

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
LOG_DIR="log"

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

    def readNetworkSample(self, filename):
        keys = ["wifiBytesIn", "Timestamp"]
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
                    if k == 'Timestamp':
                        v = "%.0lf" % v
                    nitem[k] = v
                samples.append(nitem)

        except Exception, e:
            print "Exception here: %s" % str(e)
            return False
        return samples

    def readFpsSample(self, filename):
        keys = ["FramesPerSecond", "XRVideoCardRunTimeStamp"]
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
                    #if k == 'Timestamp':
                    #    v = "%.0lf" % v
                    nitem[k] = v
                samples.append(nitem)
        except Exception, e:
            print "Exception here: %s" % str(e)
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

        keys = ["CPUUsage", "ResidentSize"]
        data = {}
        sampledata = []
        data["summary"] = dict((k,[]) for k in keys)
        for item in flist:
            idx = item[0]
            filename = os.path.join(d, item[1])
            samples = self.readPerfermaceSample(filename)
            if samples:
                sampledata.append([idx, samples])
        for k in keys:
            count = 0
            size = 0
            min = sampledata[0][1][0][k]
            max = sampledata[0][1][0][k]
            for idx,samples in sampledata:
                for sample in samples:
                    count += sample[k]
                    size += 1
                    if sample[k] < min:
                        min = sample[k]
                    if sample[k] > max:
                        max = sample[k]
            if size!=0:
                avg = count/size
            data["summary"][k] = [avg,min,max]
        data["samples"] = sampledata
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

    def readNetwork(self):
        d = os.path.join(self.result_dir, DATA_DIR)
        if not os.path.isdir(d):
            print "%s is not found!" % d
            return False

        flist = []
        for filename in os.listdir(d):
            if filename.startswith("NetworkActivity"):
                idx = int(filename.split('-')[1])
                flist.append([idx, filename])
        flist.sort()

        data = {}
        samplesdata = []
        for item in flist:
            idx = item[0]
            filename = os.path.join(d, item[1])
            samples = self.readNetworkSample(filename)
            if samples:
                samplesdata.append([idx, samples])
        min = 0
        max = 0
        if(len(samplesdata)>0):
            min = samplesdata[0][1][0]["wifiBytesIn"]
            max = samplesdata[0][1][0]["wifiBytesIn"]
        avg = 0
        count = 0
        size = 0
        for idx,samples in samplesdata:
            for sample in samples:
                if sample["wifiBytesIn"]<min:
                    min = sample["wifiBytesIn"]
                if sample["wifiBytesIn"]>max:
                    max = sample["wifiBytesIn"]
                count += sample["wifiBytesIn"]
                size += 1
        if size!=0:
            avg = count/size
        summarydata = [avg, min, max]
        data["summary"] = summarydata
        data["samples"] = samplesdata
        return data

    def printNetwork(self, data):
        print(data)

    def readFps(self):
        d = os.path.join(self.result_dir, DATA_DIR)
        if not os.path.isdir(d):
            print "%s is not found!" % d
            return False

        flist = []
        for filename in os.listdir(d):
            if filename.startswith("CoreAnimation"):
                idx = int(filename.split('-')[1])
                flist.append([idx, filename])
        flist.sort()

        data = {}
        samplesdata = []
        for item in flist:
            idx = item[0]
            filename = os.path.join(d, item[1])
            samples = self.readFpsSample(filename)
            #print(samples)
            if samples:
                samplesdata.append([idx, samples])
        #print samplesdata[0]

        min = 0
        max = 0
        if(len(samplesdata)>0):
            min = samplesdata[0][1][0]["FramesPerSecond"]
            max = samplesdata[0][1][0]["FramesPerSecond"]
        avg = 0
        count = 0
        size = 0
        for idx,samples in samplesdata:
            for sample in samples:
                if sample["FramesPerSecond"]<min:
                    min = sample["FramesPerSecond"]
                if sample["FramesPerSecond"]>max:
                    max = sample["FramesPerSecond"]
                count += sample["FramesPerSecond"]
                size += 1
        #print count
        if size!=0:
            avg = count*1.0/size
        summarydata = [avg, min, max]
        #print summarydata
        data["summary"] = summarydata
        data["samples"] = samplesdata
        return data

    def readLog(self):
        d = os.path.join(self.result_dir, LOG_DIR)
        if not os.path.isdir(d):
            print "%s is not found!" % d
            return False
        logs = []
        for filename in os.listdir(d):
            logs.append(filename)
        return logs

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

    def generateHtml(self, trace_data, log_data, crash_data, screenshot):
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
        samplesdata = trace_data["samples"]
        if samplesdata:
            for item in samplesdata:
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
        render_data['avg_mem'] = "%.2f" % float(trace_data["summary"]["ResidentSize"][0]/1024.0/1024.0)
        render_data['avg_cpu'] = "%.2f" % float(trace_data["summary"]["CPUUsage"][0])

        #process logs
        render_data['logs'] = json.dumps(log_data)

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
                    #print(s[0].timetuple() * 1000)
                    ts = int(calendar.timegm(s[0].timetuple()) * 1000)
                    #print ts
                    screenshot_dict[ts] = [idx, s[1]]
                    screenshot_data.append([ts, 0])
        screenshot_data.sort()
        render_data['screenshot_dict'] = json.dumps(screenshot_dict)
        render_data['screenshot_data'] = json.dumps(screenshot_data)

        #process network
        networkdata = []
        network = self.readNetwork()
        netWorkData = network["samples"]
        render_data['avg_network'] = "%.2f" % float(network["summary"][0]/1024.0)
        if netWorkData:
            for item in netWorkData:
                idx = item[0]
                samples = item[1]
                for sample in samples:
                    ts = (int(sample['Timestamp'])+8*60*60)*1000
                    networkdata.append("[%u, %.2f]" % (ts, sample['wifiBytesIn']/1024))
        #print(networkdata)
        render_data['networkdata'] = ','.join(networkdata)
        #print(render_data['networkdata'])

        #process FPS
        fpsdata = []
        fps = self.readFps()
        fpsData = fps['samples']
        render_data['avg_fps'] = "%.2f" % float(fps["summary"][0])
        #print render_data['avg_fps']
        if fpsData:
            for item in fpsData:
                idx = item[0]
                samples = item[1]
                for sample in samples:
                    ts = (int(sample['XRVideoCardRunTimeStamp']+8*60*60)*1000)
                    fpsdata.append("[%u, %.2f]" % (ts, sample['FramesPerSecond']))
        #print fpsdata
        render_data['fpsdata'] = ','.join(fpsdata)

        out_data = template.substitute(render_data)
        #save
        outfile = os.path.join(self.result_dir, 'report.html')
        with open(outfile, 'w') as f:
            f.write(out_data)
            f.close()
        return True

    def generate(self):
        try:
            logs = self.readLog()

            crash = self.readCrash()
            #print crash

            data = self.readData()
            #print data
            #self.printData(data)

            screenshot = self.readScreenshot()
            #print screenshot

            #self.readFps()
            return self.generateHtml(data, logs, crash, screenshot)
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
