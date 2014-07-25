# author: hyxbiao(xuanbiao@baidu.com)

WORKDIR=$(cd "$(dirname "$0")"; pwd)
BINDIR="$WORKDIR/bin"

DEVICE=
MOBILEPROVISION=
ENTITLEMENTS=
IDENTITY=
RESULT_PATH="result"
ISBUNDLE=0

#log配置，指定的路径要存在
CONF_LOG_FILE="main.log"
CONF_LOG_LEVEL=16

##! **********************  internal conf ***********************
VERSION="0.7.0"

MODULE_NAME="smallapple"
#MODULE_NAME=`basename $0`

LOG_FATAL=1
LOG_WARNING=2
LOG_NOTICE=4
LOG_TRACE=8
LOG_DEBUG=16
#LOG_LEVEL_TEXT=(
#	[1]="FATAL"
#	[2]="WARNING"
#	[4]="NOTICE"
#	[8]="TRACE"
#	[16]="DEBUG"
#)
LOG_LEVEL_TEXT[1]="FATAL"
LOG_LEVEL_TEXT[2]="WARNING"
LOG_LEVEL_TEXT[4]="NOTICE"
LOG_LEVEL_TEXT[8]="TRACE"
LOG_LEVEL_TEXT[16]="DEBUG"

TTY_FATAL=1
TTY_PASS=2
TTY_TRACE=4
TTY_INFO=8
#TTY_MODE_TEXT=(
#	[1]="[FAIL ]"
#	[2]="[PASS ]"
#	[4]="[TRACE]"
#	[8]=""
#)
TTY_MODE_TEXT[1]="[FAIL ]"
TTY_MODE_TEXT[2]="[PASS ]"
TTY_MODE_TEXT[4]="[TRACE]"
TTY_MODE_TEXT[8]=""

#0  OFF  
#1  高亮显示  
#4  underline  
#5  闪烁  
#7  反白显示  
#8  不可见 

#30  40  黑色
#31  41  红色  
#32  42  绿色  
#33  43  黄色  
#34  44  蓝色  
#35  45  紫红色  
#36  46  青蓝色  
#37  47  白色 
#TTY_MODE_COLOR=(
#	[1]="1;31"	
#	[2]="1;32"
#	[4]="0;36"	
#	[8]="1;33"
#)
TTY_MODE_COLOR[1]="1;31"	
TTY_MODE_COLOR[2]="1;32"
TTY_MODE_COLOR[4]="0;36"	
TTY_MODE_COLOR[8]="1;33"

function MainUsage()
{
	echo "usage: $MODULE_NAME [tool]"
	echo "       appinfo        : get app infomation"
	echo "       resign         : resign app"
	echo "       monkey         : run monkey testing"
	exit 0
}
function MonkeyUsage()
{
	echo "usage: $MODULE_NAME monkey [options] <.ipa/.app path | bundle id>"
	echo "options:"
	echo "    -d <device id>                 : specify device id"
	echo "    -p <.mobileprovision path>     : .mobileprovision path"
	echo "    -e <entitlement path>          : entitlement path"
	echo "    -i <developer identity>        : ios developer identity"
	echo "    -b                             : use bundle id instead of app path"
	exit 0
}

##! @BRIEF: write log
##! @AUTHOR: xuanbiao
##! @IN[int]: $1 => log level
##! @IN[string]: $2 => message
##! @RETURN: 0 => sucess; 1 => failure
function WriteLog()
{
	local log_level=$1
	local message="$2"

	if [ $log_level -le ${CONF_LOG_LEVEL} ]
	then
		local time=`date "+%m-%d %H:%M:%S"`
		echo "${LOG_LEVEL_TEXT[$log_level]}: $time: ${MODULE_NAME} * $$ $message" >> ${CONF_LOG_FILE}
	fi
	return 0
}
##! @BRIEF: print info to tty
##! @AUTHOR: xuanbiao
##! @IN[int]: $1 => tty mode
##! @IN[string]: $2 => message
##! @RETURN: 0 => sucess; 1 => failure
function Print()
{
	local tty_mode=$1
	local message="$2"

	echo -e "\033[${TTY_MODE_COLOR[$tty_mode]}m${TTY_MODE_TEXT[$tty_mode]} ${message}\033[m"
	return 0
}

function AppInfo() 
{
	$BINDIR/appinfo.sh "$@"
}

function Resign() 
{
	$BINDIR/resign.sh "$@"
}

function Install()
{
	local filename="$1"
	local ext=${filename##*.}

	local app="$filename"
	local tempdir
	if [ "$ext" == "ipa" ]; then
		#create temp directory
		tempdir=`mktemp -d -t install`

		if [ $? -ne 0 ]; then
			Print $TTY_FATAL "Create temp directory fail!"
			return 1
		fi

		unzip -q "$filename" -d $tempdir

		app=`find $tempdir -name *.app`
		if [ -z "$app" ]; then
			Print $TTY_FATAL "Not found *.app!"
			rm -rf $tempdir
			return 1
		fi
	fi

	local ret=0
	$BINDIR/iosutil -s $DEVICE install $app
	ret=$?

	if [ "$ext" == "ipa" ]; then
		rm -rf $tempdir
	fi
	return $ret
}

function ResignAndInstall()
{
	local filename="$1"

	local resignapp="$RESULT_PATH/test.ipa"
	Resign -p "$MOBILEPROVISION" -e "$ENTITLEMENTS" -i "$IDENTITY" "$filename" "$resignapp"
	if [ $? -ne 0 ]; then
		Print $TTY_FATAL "Resign fail!"
		return 1
	fi
	Print $TTY_PASS "Resign success"

	#install
	Install $resignapp
	if [ $? -ne 0 ]; then
		Print $TTY_FATAL "Install fail!"
		return 1
	fi
	Print $TTY_PASS "Install success!"
	return 0
}

function RunAutomation()
{
	local device="$1"
	local app="$2"
	local result_path="$3"

	local script="$WORKDIR/monkey/UIAutoMonkey.js"
	#local template="/Applications/Xcode.app/Contents/Applications/Instruments.app/Contents/Resources/templates/Leaks.tracetemplate"
	#local template="/Applications/Xcode.app/Contents/Applications/Instruments.app/Contents/PlugIns/AutomationInstrument.xrplugin/Contents/Resources/Automation.tracetemplate"
	#local template="/Applications/Xcode.app/Contents/Applications/Instruments.app/Contents/PlugIns/AutomationInstrument.bundle/Contents/Resources/Automation.tracetemplate"
	local template=`instruments -s templates | grep Automation`

	instruments \
		-w "$device" \
		-D "$result_path/trace" \
		-t "$template" \
		"$app" \
		-e UIARESULTSPATH "$result_path" \
		-e UIASCRIPT $script
}

function ParseParams()
{
	[ $# -eq 0 ] && return -1

	while [ $# -gt 0 ]
	do
		case "$1" in 
		-d)
			DEVICE="$2"
			shift 2
			;;
		-p)
			MOBILEPROVISION="$2"
			shift 2
			;;
		-e)
			ENTITLEMENTS="$2"
			shift 2
			;;
		-i)
			IDENTITY="$2"
			shift 2
			;;
		-r)
			RESULT_PATH="$2"
			shift 2
			;;
		-b)
			ISBUNDLE=1
			shift 1
			;;
		-*)	echo "Unkown option \"$1\""
			return -1
			;;
		*)	break
			;;
		esac
	done
	return $#
}

function Monkey() 
{
	local ret=0
	#process params
	ParseParams "$@"
	ret=$?
	if [ $ret -eq 255 ]; then
		MonkeyUsage
	fi
	#if no specify device, select the first available device
	[ -z "$DEVICE" ] && DEVICE=`$BINDIR/iosutil devices | awk '{print $2; exit}'`
	if [ -z "$DEVICE" ]; then
		MonkeyUsage
	fi
	let ret=$#-ret
	shift $ret
	if [ $# -ne 1 ]; then
		MonkeyUsage
	fi

	local filename="$1"

	mkdir -p $RESULT_PATH

	#get app bundle id for uninstall later if necessary
	local bundleid
	if [ $ISBUNDLE -eq 0 ]; then
		bundleid=`AppInfo CFBundleIdentifier "$filename"`
		if [ $? -ne 0 ] || [ -z "$bundleid" ]; then
			Print $TTY_FATAL "Get bundle id fail! Is it a valid app?"
			exit 1
		fi
		Print $TTY_TRACE "Bundle id: $bundleid"

		#resign and install
		ResignAndInstall "$filename"
		if [ $? -ne 0 ]; then
			Print $TTY_FATAL "Resign and install fail!"
			exit 1
		fi
	else
		bundleid="$filename"
		$BINDIR/iosutil listapp | grep $bundleid > /dev/null 2>&1
		if [ $? -ne 0 ]; then
			Print $TTY_FATAL "No found app: $bundleid"
			exit 1
		fi
	fi

	#run monkey testing
	local start=$(date "+%Y-%m-%d-%H%M%S")
	Print $TTY_TRACE "Start monkey testing"
	RunAutomation $DEVICE $bundleid $RESULT_PATH
	if [ $? -ne 0 ]; then
		Print $TTY_FATAL "Run monkey fail!"
	fi
	local end=$(date "+%Y-%m-%d-%H%M%S")

	#collect result data
	#detect crash 
	Print $TTY_TRACE "Start collect crash and result"
	local exe=`$BINDIR/iosutil listapp | grep $bundleid | awk '{print $2}'`
	#local exe=`AppInfo CFBundleExecutable "$filename"`
	if [ $? -ne 0 ] || [ -z "$exe" ]; then
		Print $TTY_FATAL "Get process name fail!"
		exit 1
	fi

	local crashs=`$BINDIR/iosutil -s $DEVICE ls -b crash / | grep $exe | awk '{if($6 > "'"${exe}_${start}"'") print $6}'`
	if [ -z "$crashs" ]; then
		Print $TTY_TRACE "No crash file found!"
	fi

	#download crash
	for crash in $crashs
	do
		$BINDIR/iosutil -s $DEVICE pull -b crash /$crash $RESULT_PATH
	done

	#uninstall
	#$BINDIR/iosutil -s $DEVICE uninstall $bundleid
}

function Debug()
{
	local bundleid="$1"
	local device=`$BINDIR/iosutil devices | awk '{print $2; exit}'`
	local result_path="result"

	RunAutomation $device $bundleid $result_path
}

function Main()
{
	[ $# -eq 0 ] && MainUsage

	while [ $# -gt 0 ]
	do
		case "$1" in 
		appinfo)
			shift
			AppInfo "$@"
			exit $?
			break
			;;
		resign)
			shift
			Resign "$@"
			break
			;;
		monkey)
			shift
			Monkey "$@"
			break
			;;
		debug)
			shift
			Debug "$@"
			break
			;;
		-h|-help)
			MainUsage
			;;
		--)	shift
			break
			;;
		*)	echo "Unkown option \"$1\""
			MainUsage
			;;
		esac
	done
}

Main "$@"
