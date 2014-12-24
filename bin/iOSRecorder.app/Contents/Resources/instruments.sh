#!/bin/bash

#set -x

resource=$1
appPath=$2

ipa="${appPath##*.}"
if [ ${ipa} = "ipa" ];
then
    cd ${resource}/Payload/*.app
    appPath=`pwd`
echo "---------------------------"${appPath}
fi

cd $resource
mkdir -p images
cd images
rm -rf *
cd ..
rm -rf *.trace

#获取当前真机的sn
uuid=`ioreg -w 0 -rc IOUSBDevice -k SupportsIPhoneOS | grep 'USB Serial Number' | cut -d'=' -f2 | cut -d'"' -f2`
xcodeVersion=`xcodebuild -version | grep Xcode | cut -d' ' -f2 | cut -d'.' -f1`

if [ ${#uuid} -eq 40 ];
then
    instruments -w ${uuid} -t Automation.tracetemplate "$appPath" -e UIASCRIPT client.js -e UIARESULTSPATH images
else if [ ${xcodeVersion} -ge 6 ]; #xcode version如果大于等于6则需要获取模拟器ID
	then
	    uuid=`instruments -s | grep 'iPhone 4s (8.1 Simulator)' | cut -d'[' -f2 | cut -d']' -f1`
	    instruments -w ${uuid} -t Automation.tracetemplate "$appPath" -e UIASCRIPT client.js -e UIARESULTSPATH images
	else #xcode6.0一下不需要指定模拟器设备ID
		instruments -t Automation.tracetemplate "$appPath" -e UIASCRIPT client.js -e UIARESULTSPATH images
	fi
fi

#instruments -w B91F3160-4372-498C-950B-6E294B8A068 -t Automation.tracetemplate $appPath -e UIASCRIPT client.js -e UIARESULTSPATH images