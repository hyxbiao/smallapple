#!/bin/sh

exec 6<>/dev/tcp/127.0.0.1/5566
echo "From client.js">&6
returnStr=`cat<&6`
exec 6<&- ;
exec 6>&- ;

echo $returnStr

exit 0


