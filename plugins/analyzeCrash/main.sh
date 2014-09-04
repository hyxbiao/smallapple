#!/bin/bash

# @author xiongshuangquan@baidu.com
# @version:1.0.0
# @date:2014-9-1

#此处为Xcode的对应目录用于查找系统lib时需要使用到
#export DEVELOPER_DIR="/Applications/XCode.app/Contents/Developer"
#=== modify by xuanbiao@baidu.com ====
export DEVELOPER_DIR=`xcode-select -p`

WORKDIR=$(cd "$(dirname "$0")"; pwd)
#=== end ====

#当参数个数不为3或着当输入命令为'help'时需要打印Usage:
if [ $# -lt 3 ] || [ "$1"x == "help"x ];then 
    echo ""
    echo "Usage:"
    echo "    --------------------------Example-----------------------------"
    echo "    sh analyzeCrash.sh crashFile crashType output dSYMFile"
    echo "    --------------------------Desc---------------------------"
    echo "    @crashFile:crash文件路径"
    echo "    @dSYMFIle:dSYM文件路径"
    echo "    @crashType:有两种crash文件类型，分别是plcrashreporter收集的crash或者源生crash，分别使用'pl'和‘ori’,其它输入则为'ori'"
    echo "    Notice:"
    echo "        a)该工具默认打印到控制台，如若要输出到文件，请自己重定向，eg: ./analyzeCrash.sh crash1 ori <output> ./dsym"
    echo "        b)其中crashType必须和crashFile的类型一致"
    echo "        c)某些机器请赋予analyzeCrash.sh,plcrashutil,bd_symbolicatecrash的可执行权限"
    echo "        d)有些Crash的系统函数没有解析出来，原因是缺失该Crash对应手机版本(如7.1.2(11D257))的iOS系统Symbols文件"
    echo "        e)必须要保证产生该Crash的App与给定的dSYM文件是同一次build版本"
    echo "    sh analyzeCrash.sh help    #显示帮助说明"
    echo ""
    exit 0
fi

crashLog=$1
crashType=$2
output=$3
dSYMPath=$4

function backup()
{
	timestamp="`date +%Y%m%d%H%M%S`"

	if [ -d ./tmp ];then
		rm -rf ./tmp/*crash
	else
		mkdir tmp
	fi
	cp $crashLog ./tmp/${crashLog}_${timestamp}.plcrash
	# *.plcrash ---> *.crash
	if [ "$crashType"x == "pl"x ];then
		./plcrashutil convert --format=iphone ./tmp/"${crashLog}_${timestamp}.plcrash" > ./tmp/"${crashLog}_${timestamp}.crash"
	else
		mv ./tmp/${crashLog}_${timestamp}.plcrash ./tmp/${crashLog}_${timestamp}.crash
	fi

	#根据.crash文件解析
	./bd_symbolicatecrash ./tmp/${crashLog}_${timestamp}.crash $dSYMPath/Contents/Resources/DWARF
	rm -rf ./tmp/*
}

#add by xuanbiao@baidu.com
function process()
{
	local tmpfile
	if [ "$crashType"x == "pl"x ];then
		tmpfile=`mktemp -t crash`
		$WORKDIR/plcrashutil convert --format=iphone $crashLog > $tmpfile
		crashLog=$tmpfile
	fi
	local ret=0
	#根据.crash文件解析
	if [ -z "$dSYMPath" ]; then
		$WORKDIR/bd_symbolicatecrash -o $output $crashLog 2>/dev/null
		ret=$?
	else
		$WORKDIR/bd_symbolicatecrash -o $output $crashLog $dSYMPath/Contents/Resources/DWARF 2>/dev/null
		ret=$?
	fi
	if [ "$crashType"x == "pl"x ];then
		rm -rf $tmpfile
	fi
	return $ret
}
#=== end ====

process
