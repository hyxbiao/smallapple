# author: hyxbiao(xuanbiao@baidu.com)

function Usage()
{
	echo "appinfo [key] <.ipa/.app/.plist path>"
	exit 1
}

function GetInfo() 
{
	local key
	local file

	if [ $# -eq 1 ]; then
		file="$1"
	elif [ $# -eq 2 ]; then
		key="$1"
		file="$2"
	else
		Usage
	fi

	local ext=${file##*.}

	local plist=$file
	if [ "$ext" == "ipa" ]; then
		local tmpfile=`mktemp -t appinfo`
		#unzip ipa
		rm -rf /tmp/Payload
		unzip -q $file Payload/*.app/Info.plist -d  /tmp
		cat /tmp/Payload/*.app/Info.plist > $tmpfile
		plist=$tmpfile
	elif [ "$ext" == "app" ]; then
		plist="$file/Info.plist"
	fi
	local ret=0
	if [ -z "$key" ]; then
		/usr/libexec/PlistBuddy -c Print "$plist"
		ret=$?
	else
		/usr/libexec/PlistBuddy -c Print:$key "$plist"
		ret=$?
	fi
	if [ "$ext" == "ipa" ]; then
		rm $plist
	fi
	return $ret
}

function Main()
{
	GetInfo "$@"
	return $?
}

Main "$@"
