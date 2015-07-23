#set -x
# author: hyxbiao(xuanbiao@baidu.com)


function Usage()
{
	echo "resign [options] <.ipa/.app path> <output path>"
	echo "options:"
	echo "    -p <.mobileprovision path>"
	echo "      or -e <entitlement path>"
	echo "    -i <developer identity>"
	exit 1
}

function GetIdentity()
{
	security find-identity -v -p codesigning | grep "iPhone Developer" | awk -F "\"" '{if(NF==3) {print $2; exit}}'
}

function GenerateEntitlement()
{
	local mobileprovision="$1"
	local outfile="$2"

	local tmpfile=`mktemp -t resign`
	security cms -D -i "$mobileprovision" > $tmpfile
	/usr/libexec/PlistBuddy -x -c "print :Entitlements " $tmpfile > $outfile
	/usr/libexec/PlistBuddy -c 'Set :get-task-allow true' $outfile
	/usr/libexec/PlistBuddy -c 'Set :aps-environment development' $outfile >/dev/null 2>&1
	rm -rf $tmpfile
}

function ProcessIPA()
{
	local identity="$1"
	local srcfile="$2"
	local dstfile="$3"
	local entitlements="$4"

	#create temp directory
	local tempdir=`mktemp -d -t resign`

	if [ $? -ne 0 ]; then
		echo "Create temp directory fail!"
		exit 1
	fi

	unzip -q "$srcfile" -d $tempdir

	local ret=0
	#fix multi .app directory bug
	local appcount=`find $tempdir/Payload -name *.app | wc -l`
	if [ $appcount != 0 ]; then
		local apps=`find $tempdir/Payload -name *.app`
		echo "$apps" | while read app
		do
			if [ -z "$app" ]; then
				echo "Not found *.app!"
				rm -rf $tempdir
				exit 1
			fi
			if [ $ret != 0 ]; then
				#echo "resign fail!"
				rm -rf $tempdir
				exit 1
			fi
        		#codesign
        		if [ -z "$entitlements" ]; then
                		codesign -f -s "$identity" "$app" >/dev/null 2>&1
                		ret=$?
        		else
                		codesign -f -s "$identity" --entitlements="$entitlements" "$app" >/dev/null 2>&1
                		#codesign -f -s "$identity" --entitlements="$entitlements" --resource-rules="$app/ResourceRules.plist" "$app" >/dev/null 2>&1
                		ret=$?
        		fi
		done
		ret=$?
	fi
	
	if [ $ret == 0 ]; then
		local appexcount=`find $tempdir/Payload -name *.appex | wc -l`
        	if [ $appexcount != 0 ]; then
                	local appexs=`find $tempdir/Payload -name *.appex`
                	echo "$appexs" | while read appex
                	do
                        	if [ -z "$appex" ]; then
                                	echo "Not found *.appex!"
                                	rm -rf $tempdir
                                	exit 1
                        	fi
                        	if [ $ret != 0 ]; then
                                	#echo "resign fail!"
                                	rm -rf $tempdir
                                	exit 1
                        	fi
                        	#codesign
                        	if [ -z "$entitlements" ]; then
                                	codesign -f -s "$identity" "$appex" >/dev/null 2>&1
                                	ret=$?
                        	else
                                	codesign -f -s "$identity" --entitlements="$entitlements" "$appex" >/dev/null 2>&1
                                	#codesign -f -s "$identity" --entitlements="$entitlements" --resource-rules="$app/ResourceRules.plist" "$app" >/dev/null 2>&1
                                	ret=$?
                        	fi
                	done
			ret=$?
        	fi
	fi

	if [ $ret == 0 ]; then
		#zip
		cd $tempdir
		zip -qry "$dstfile" .
		cd - >/dev/null 2>&1

		rm -rf $tempdir
	fi
	return $ret
}

function ProcessAPP()
{
	local identity="$1"
	local srcfile="$2"
	local dstfile="$3"
	local entitlements="$4"

	cp -r "$srcfile" "$dstfile"

	local ret=0
	if [ -z "$entitlements" ]; then
		codesign -f -s "$identity" "$dstfile" >/dev/null 2>&1
		ret=$?
	else
		codesign -f -s "$identity" --entitlements="$entitlements" "$dstfile" >/dev/null 2>&1
		ret=$?
	fi
	return $ret
}

function Main()
{
	local mobileprovision
	local filename
	local newfilename
	local identity
	local entitlements

	[ $# -eq 0 ] && Usage

	while [ $# -gt 0 ]
	do
		case "$1" in 
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
			Usage
			;;
		*)	break
			;;
		esac
	done
	if [ $# -ne 2 ]; then
		Usage
	fi
	filename="$1"
	newfilename="$2"

	newfilename=$(cd "$(dirname "$newfilename")"; pwd)/$(basename "$newfilename")
	local name="${filename%.*}"
	local ext=${filename##*.}

	if [ "$ext" != "ipa" ] && [ "$ext" != "app" ]; then
		Usage
	fi

	[ -z "$identity" ] && identity=`GetIdentity`
	if [ -z "$identity" ]; then
		echo "Not found ios developer identity!"
		exit 1
	fi

	#echo $identity
	local entitlement_file
	if [ -z "$entitlements" ]; then
		if [ ! -z "$mobileprovision" ]; then
			entitlement_file=`mktemp -t resign`
			GenerateEntitlement "$mobileprovision" "$entitlement_file"
		fi
	else
		entitlement_file="$entitlements"
	fi

	local ret=0
	#unzip
	if [ "$ext" == "ipa" ]; then
		ProcessIPA "$identity" "$filename" "$newfilename" "$entitlement_file"
		ret=$?
	else
		ProcessAPP "$identity" "$filename" "$newfilename" "$entitlement_file"
		ret=$?
	fi

	if [ -z "$entitlements" ] && [ ! -z "$entitlement_file" ]; then
		rm -rf $entitlement_file
	fi
	
	return $ret
}

Main "$@"
