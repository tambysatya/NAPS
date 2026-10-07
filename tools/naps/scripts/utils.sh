#!/usr/bin/env bash


RED="\e[31m"
GREEN="\e[32m"
BLUE="\e[34m"
NC="\e[0m"   # No Color


red(){
	echo -e "${RED}${1}${NC}"
}

blue(){
	echo -e "${BLUE}${1}${NC}"
}
green(){
	echo -e "${GREEN}${1}${NC}"
}

bold() {
    printf '\033[1m%s\033[0m\n' "$*"
}


print_vms(){
    ACTION=$1
    VMS=$2
    if [[ -n "$VMS" ]]; then
        printf "%s" "$ACTION\n"
        printf "%s\n\n" "$VMS" |sed -s 's/^/ /'
    fi
}


