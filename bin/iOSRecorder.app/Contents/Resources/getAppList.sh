#!/bin/bash

${1}/iosutil listapp | grep com | awk -F' ' '{print $1}'