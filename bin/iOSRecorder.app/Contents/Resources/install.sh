#!/bin/bash

set -x

rootPath=${1}
appPath=${2}

app=${appPath##*.}
if [ ${app} = "ipa" ];
then
    cd ${rootPath}
    rm *.zip
    rm -rf Payload
    cp ${appPath} ${rootPath}/test.zip
    tar -zxvf test.zip
    cd Payload/*.app
    appPath=`pwd`
fi

if [ ${app} = "app" ];
then
    cd ${rootPath}
    rm *.zip
    rm -rf Payload
    rm *.app
    cp -r ${appPath} ${rootPath}/test.app
    cd test.app
    appPath=`pwd`
fi

#获取当前真机的sn
uuid=`ioreg -w 0 -rc IOUSBDevice -k SupportsIPhoneOS | grep 'USB Serial Number' | cut -d'=' -f2 | cut -d'"' -f2`

if [ ${#uuid} -eq 40 ];
then
${rootPath}/iosutil -s ${uuid} install ${appPath}
fi

#sh ${rootPath}/instruments.sh ${rootPath} ${appPath}