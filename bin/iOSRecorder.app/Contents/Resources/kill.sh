#!/bin/sh

#ps -ef | grep instruments | grep -v grep | cut -c 7-15 | xargs kill -s 9
killall instruments

