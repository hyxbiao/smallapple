# author: hyxbiao(xuanbiao@baidu.com)

WORKDIR=$(cd "$(dirname "$0")"; pwd)
BINDIR="$WORKDIR/bin"

#log config
CONF_LOG_FILE="main.log"
CONF_LOG_LEVEL=16

##! **********************  internal conf ***********************
VERSION="0.9.5"

MODULE_NAME="smallapple"

LOG_FATAL=1
LOG_WARNING=2
LOG_NOTICE=4
LOG_TRACE=8
LOG_DEBUG=16
LOG_LEVEL_TEXT[1]="FATAL"
LOG_LEVEL_TEXT[2]="WARNING"
LOG_LEVEL_TEXT[4]="NOTICE"
LOG_LEVEL_TEXT[8]="TRACE"
LOG_LEVEL_TEXT[16]="DEBUG"

TTY_FATAL=1
TTY_PASS=2
TTY_TRACE=4
TTY_INFO=8
TTY_MODE_TEXT[1]="[FAIL ]"
TTY_MODE_TEXT[2]="[PASS ]"
TTY_MODE_TEXT[4]="[TRACE]"
TTY_MODE_TEXT[8]="[INFO ]"

TTY_MODE_COLOR[1]="1;31"	
TTY_MODE_COLOR[2]="1;32"
TTY_MODE_COLOR[4]="0;36"	
TTY_MODE_COLOR[8]="1;33"

function MainUsage()
{
	echo "$MODULE_NAME version $VERSION"
	echo ""
	echo "       install        : install app"
	echo "       appinfo        : get app infomation"
	echo "       resign         : resign app"
	echo ""
	echo "       record         : record & playback tool"
	echo ""
	echo "       automation     : automation testing"
	echo "       vcheck         : version compatibility testing"
	exit 0
}
function AutomationUsage()
{
	echo "usage: $MODULE_NAME automation [options] <.ipa/.app path | bundle id>"
	echo "options:"
	echo "    -s <device id>                 : specify device id. default the first found device"
	echo "    -b                             : use bundle id instead of app path"
	echo "    -o <result dir>                : result direcotry. default \$PWD/result"
	echo ""
	echo "script options:"
	echo "    -t <template>                  : instruments template. default SMALLAPPLE/templates/Automation_Monitor_CoreAnimation_Energy_Network.tracetemplate"
	echo "    -c <script>                    : instruments automation js. default SMALLAPPLE/scripts/UIAutoMonkey.js"
	echo ""
	echo "resign options:"
	echo "    -p <.mobileprovision path>     : .mobileprovision path"
	echo "      or  -e <entitlement path>    : entitlement path"
	echo "    -i <developer identity>        : ios developer identity"
	echo ""
	echo "crash options:"
	echo "    -d <dsym path>                 : dSYM path for crash analyze"
	echo ""
	echo "example:"
	echo "    $MODULE_NAME automation test.ipa"
	echo "    $MODULE_NAME automation -b com.baidu.BaiduMobile"
	echo "    $MODULE_NAME automation -c <testcase> -b com.baidu.BaiduMobile"
	echo "    $MODULE_NAME automation -s <device> -p <provision> -i <identity> -c <testcase> test.ipa"
	exit 0
}

function VersionCheckUsage()
{
	echo "usage: $MODULE_NAME vcheck [options] <old .ipa/.app path> <new .ipa/.app path>"
	echo "options:"
	echo "    -s <device id>                 : specify device id. default the first found device"
	echo "    -o <result dir>                : result direcotry prefix. default \$PWD/result"
	echo ""
	echo "script options:"
	echo "    -c <script>                    : instruments automation js. default SMALLAPPLE/scripts/UIAutoMonkey.js"
	echo ""
	echo "resign options:"
	echo "    -p <.mobileprovision path>     : .mobileprovision path"
	echo "      or  -e <entitlement path>    : entitlement path"
	echo "    -i <developer identity>        : ios developer identity"
	echo ""
	echo "example:"
	echo "    $MODULE_NAME vcheck old.ipa new.ipa"
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

function Record() 
{
	open $BINDIR/iOSRecorder.app
}

function Install()
{
	if [ $# -ne 1 ]; then
		echo "usage: $MODULE_NAME install <.ipa/.app path>"
		exit 1
	fi
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

		app=`find $tempdir/Payload -name *.app`
		if [ -z "$app" ]; then
			Print $TTY_FATAL "Not found *.app!"
			rm -rf $tempdir
			return 1
		fi
	fi

	local ret=0
	[ -z "$device" ] && device=`$BINDIR/iosutil devices | awk '{print $2; exit}'`
	if [ -z "$device" ]; then
		Print $TTY_FATAL "Not found device!"
		ret=1
	else
		$BINDIR/iosutil -s $device install $app >/dev/null 2>&1
		ret=$?
	fi

	if [ "$ext" == "ipa" ]; then
		rm -rf $tempdir
	fi
	return $ret
}

function StartInstall()
{
	if [ $# -ne 1 ]; then
		echo "usage: $MODULE_NAME install <.ipa/.app path>"
		exit 1
	fi
	Print $TTY_TRACE "Start install, please wait..."
	local ret=0
	Install "$1"
	ret=$?
	if [ $ret -eq 254 ]; then
		Print $TTY_FATAL "Install fail, your application failed code-signing checks, please try Smallapple resign"
		return 1
	elif [ $ret -ne 0 ]; then
		Print $TTY_FATAL "Install fail!"
		return 1
	fi
	Print $TTY_PASS "Install success!"
	return 0
}

function ResignAndInstall()
{
	local filename="$1"

	local app="$2"

	if [ -z "$mobileprovision" ] && [ -z "$entitlements" ]; then
		app="$filename"
	else
		Resign -p "$mobileprovision" -e "$entitlements" -i "$identity" "$filename" "$app"
		if [ $? -ne 0 ]; then
			Print $TTY_FATAL "Resign fail!"
			return 1
		fi
		Print $TTY_PASS "Resign success"
	fi

	#install
	Print $TTY_TRACE "Start install ($filename), please wait..."
	local ret=0
	Install $app
	ret=$?
	if [ $ret -eq 254 ]; then
		Print $TTY_FATAL "Install fail, your application failed code-signing checks, please try Smallapple resign"
		return 1
	elif [ $ret -ne 0 ]; then
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
	local script="$3"
	local template="$4"
	local result_path="$5"
	local dsym_path="$6"

	$BINDIR/automation.sh -s "$device" -t "$template" -c "$script" -d "$dsym_path" -o "$result_path" "$app"
}

function Automation() 
{
	local ret=0
	local device
	local result_path="${PWD}/result"
	local isbundle=0

	local template="$WORKDIR/templates/Automation_Monitor_CoreAnimation_Energy_Network.tracetemplate"
	local script="$WORKDIR/scripts/UIAutoMonkey.js"

	local mobileprovision
	local entitlements
	local identity

	local dsym_path

	[ $# -eq 0 ] && AutomationUsage

	while [ $# -gt 0 ]
	do
		case "$1" in 
		-s)
			device="$2"
			shift 2
			;;
		-o)
			result_path="$2"
			shift 2
			;;
		-b)
			isbundle=1
			shift 1
			;;
		-t)
			template="$2"
			shift 2
			;;
		-c)
			script="$2"
			shift 2
			;;
		-p)
			mobileprovision="$2"
			shift 2
			;;
		-e)
			entitlements="$2"
			shift 2
			;;
		-i)
			identity="$2"
			shift 2
			;;
		-d)
			dsym_path="$2"
			shift 2
			;;
		-*)	echo "Unkown option \"$1\""
			AutomationUsage
			;;
		*)	break
			;;
		esac
	done
	if [ $# -ne 1 ]; then
		AutomationUsage
	fi
	#if no specify device, select the first available device
	[ -z "$device" ] && device=`$BINDIR/iosutil devices | awk '{print $2; exit}'`
	if [ -z "$device" ]; then
		AutomationUsage
	fi

	local filename="$1"

	ps aux | grep -i instrument[s] >/dev/null 2>&1
	if [ $? -eq 0 ]; then
		Print $TTY_FATAL "Another instruments process running!"
		exit 1
	fi

	mkdir -p $result_path
	#get app bundle id
	local bundleid
	if [ $isbundle -eq 0 ]; then
		bundleid=`AppInfo CFBundleIdentifier "$filename"`
		if [ $? -ne 0 ] || [ -z "$bundleid" ]; then
			Print $TTY_FATAL "Get bundle id fail! Is it a valid app?"
			exit 1
		fi
		Print $TTY_TRACE "Bundle id: $bundleid"

		#resign and install
		local tmpfile="$result_path/test.ipa"
		ResignAndInstall "$filename" "$tmpfile"
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

	#run testing
	RunAutomation $device $bundleid $script $template $result_path $dsym_path
	ret=$?

	#uninstall
	#$BINDIR/iosutil -s $device uninstall $bundleid
	return $ret
}

function VersionCheck()
{
	local ret=0
	local device
	local result_path="${PWD}/result"

	local script="$WORKDIR/scripts/UIAutoMonkey.js"

	local mobileprovision
	local entitlements
	local identity

	[ $# -eq 0 ] && VersionCheckUsage

	while [ $# -gt 0 ]
	do
		case "$1" in 
		-s)
			device="$2"
			shift 2
			;;
		-o)
			result_path="$2"
			shift 2
			;;
		-c)
			script="$2"
			shift 2
			;;
		-p)
			mobileprovision="$2"
			shift 2
			;;
		-e)
			entitlements="$2"
			shift 2
			;;
		-i)
			identity="$2"
			shift 2
			;;
		-*)	echo "Unkown option \"$1\""
			VersionCheckUsage
			;;
		*)	break
			;;
		esac
	done
	if [ $# -ne 2 ]; then
		VersionCheckUsage
	fi
	local version_a="$1"
	local version_b="$2"

	Print $TTY_INFO "=========== Start version A ($version_a) testing"
	Automation -s "$device" -c "$script" -o "${result_path}/a" "$version_a"

	Print $TTY_INFO "=========== Start version B ($version_b) testing"
	Automation -s "$device" -c "$script" -o "${result_path}/b" "$version_b"
}

function Debug()
{
	local bundleid="$1"
	local device=`$BINDIR/iosutil devices | awk '{print $2; exit}'`
	local result_path="result"

	local script="$WORKDIR/test/test.js"
	#local script="$WORKDIR/scripts/UIAutoMonkey.js"
	local template="$WORKDIR/templates/Automation_Monitor.tracetemplate"
	#local template=`instruments -s templates | grep Automation`
	RunAutomation $device $bundleid $script $template $result_path $dsym_path
}

function Main()
{
	local ret=0
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
		record)
			shift
			Record "$@"
			exit $?
			break
			;;
		resign)
			shift
			Resign "$@"
			ret=$?
			break
			;;
		install)
			shift
			StartInstall "$@"
			break
			;;
		automation)
			shift
			Automation "$@"
			break
			;;
		vcheck)
			shift
			VersionCheck "$@"
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

	return $ret
}

Main "$@"
