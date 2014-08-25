# author: hyxbiao(xuanbiao@baidu.com)

WORKDIR=$(cd "$(dirname "$0")/.."; pwd)
BINDIR="$WORKDIR/bin"
PLUGINDIR="$WORKDIR/plugins"

INSTRUMENTS_DIR="instruments"
CRASH_DIR="crash"
DATA_DIR="data"

MODULE_NAME="automation"

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

function Usage()
{
	echo "automation <options> bundleid"
	echo "options:"
	echo "    -s <device id>"
	echo "    -t <template>                  : instruments template"
	echo "    -c <automation script>         : instruments automation js"
	echo "    -o <result dir>                : default result"
	exit 1
}

function Print()
{
	local tty_mode=$1
	local message="$2"

	echo -e "\033[${TTY_MODE_COLOR[$tty_mode]}m${TTY_MODE_TEXT[$tty_mode]} ${message}\033[m"
	return 0
}

function Run()
{
	local device="$1"
	local app="$2"
	local script="$3"
	local template="$4"
	local result_path="$5"

	local instruments_path="$result_path/$INSTRUMENTS_DIR"
	mkdir -p $instruments_path
	xcrun instruments \
		-w "$device" \
		-D "$instruments_path/${MODULE_NAME}" \
		-t "$template" \
		"$app" \
		-e UIARESULTSPATH "$instruments_path" \
		-e UIASCRIPT $script
}

function DetectCrash()
{
	local device="$1"
	local appname="$2"
	local result_path="$3"
	local start="$4"
	local end="$5"

	Print $TTY_TRACE "Start collect crash"

	local filter="${appname}_${start}"
	local crashs=`$BINDIR/iosutil -s $device ls -b crash / | grep $appname | grep -v "LatestCrash" | awk '{if($6 > "'"$filter"'") print $6}'`

	local crash_num=0

	local crash_path="$result_path/$CRASH_DIR"
	mkdir -p $crash_path
	#download crash
	for crash in $crashs
	do
		$BINDIR/iosutil -s $device pull -b crash /$crash $crash_path
		let crash_num=$crash_num+1
	done

	return $crash_num
}

function ParseInstrumentTrace()
{
	local appname="$1"
	local result_path="$2"

	local instruments_path="$result_path/$INSTRUMENTS_DIR"
	local trace="$instruments_path/${MODULE_NAME}.trace" 

	local data_path="$result_path/$DATA_DIR"
	mkdir -p "$data_path"
	$BINDIR/instruments_parser -p "$appname" -i "$trace" -o "$data_path"
}

function Main()
{
	local device
	local bundleid
	local template
	local script
	local result_path="${PWD}/result"

	[ $# -eq 0 ] && Usage

	while [ $# -gt 0 ]
	do
		case "$1" in 
		-s)
			device="$2"
			shift 2
			;;
		-t)
			template="$2"
			shift 2
			;;
		-c)
			script="$2"
			shift 2
			;;
		-o)
			result_path="$2"
			shift 2
			;;
		-*)	echo "Unkown option \"$1\""
			Usage
			;;
		*)	break
			;;
		esac
	done
	if [ $# -ne 1 ]; then
		Usage
	fi
	if [ -z "$device" ] || [ -z "$script" ] || [ -z "$template" ]; then
		Usage
	fi
	bundleid="$1"
	local appname=`$BINDIR/iosutil -s $device listapp | grep $bundleid | awk '{print $2}'`
	if [ $? -ne 0 ] || [ -z "$appname" ]; then
		Print $TTY_FATAL "Get process name fail!"
		exit 1
	fi

	local ret=0
	local start=$(date "+%Y-%m-%d-%H%M%S")
	Print $TTY_TRACE "[$start] Start automation testing..."
	Run $device $bundleid $script $template $result_path
	ret=$?
	if [ $ret -ne 0 ]; then
		Print $TTY_FATAL "Run automation fail!"
	fi
	local end=$(date "+%Y-%m-%d-%H%M%S")
	Print $TTY_TRACE "[$end] Testing finish."

	#detect crash
	local crash_num=0
	DetectCrash "$device" "$appname" "$result_path" "$start" "$end"
	crash_num=$?
	if [ $crash_num -gt 0 ]; then
		Print $TTY_FATAL "$crash_num crashs found!"
	else
		Print $TTY_PASS "No crash file found!"
	fi

	#parse trace
	Print $TTY_TRACE "Start parse instrument trace"
	ParseInstrumentTrace "$appname" "$result_path"
	if [ $? -eq 0 ]; then
		local report="$PLUGINDIR/report/main.py"
		if [ -f $report ]; then
			Print $TTY_TRACE "Start generate report"
			python $report $result_path
		fi
	fi

	return $ret
}

Main "$@"
