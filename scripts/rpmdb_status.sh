#!/bin/bash
# Figure out if the rpmdb is busted and report results
# Output is in format: "Status,summary,num yums,yum duration,num rpms,rpm duration"

function bail(){
    # exit $1 after echoing a message
    CODE="$1"
    shift
    echo "$@" && logger -t "$0" -p user.info "$@"
    exit "$CODE"
}
function get_process () {
    ps -C "$@" -o etimes=,etime=,pid=,cmd=
}
function whats_accessing_my_file () {
    fuser $1 2>/dev/null| xargs ps --no-header -o etimes=,etime=,pid=,cmd= -p 
}
function get_longest_running_process_time () {
    var=$1
    echo "${!var}" | awk -v max=0 '{if(max<$1){max=$1; line=$0; time=$2}}END{printf time FS}' | sed s/' $'//g
}
function get_number_running_processes () {
    var=$1
    if [ "${!var}" ]; then
        echo "${!var}" | wc -l
    else
        echo 0
    fi
}
yums=$(get_process yum)
rpms=$(get_process rpm)
#blocks=$(whats_accessing_my_file /var/lib/rpm/ 2>/dev/null)
num_yum=$(get_number_running_processes yums )
num_rpm=$(get_number_running_processes rpms )
#num_blocks=$(get_number_running_processes blocks )
longest_time_rpm=$(get_longest_running_process_time rpms)
longest_time_yum=$(get_longest_running_process_time yums)
#longest_time_blocks=$(get_longest_running_process_time blocks)
if [ ! -z $(which dpkg 2>/dev/null) ]; then
    bail 0 "N/A,N/A on Debian,${num_yum},${longest_time_yum},${num_rpm},${longest_time_rpm}"
elif [ "$(uname -r | grep -o 'el5')" ]; then
    bail 0 "N/A,N/A on CentOS 5,${num_yum},${longest_time_yum},${num_rpm},${longest_time_rpm}"
fi

### Main Script Logic ###
# Discover commands/paths
RPM=$(command -pv rpm 2>/dev/null)
DNF=$(command -pv dnf 2>/dev/null)
YUM=$(command -pv yum 2>/dev/null)
TIMEOUT=$(command -pv timeout 2>/dev/null)
TMSECS=30

# Make sure all discovered commands exist and are executable
[ -x "$RPM" ] || bail 2 "Error,RPM not found,${num_yum},${longest_time_yum},${num_rpm},${longest_time_rpm}"
[[ -x "$YUM" || -x "$DNF" ]] || bail 2 "Error,Yum / Dnf not found,${num_yum},${longest_time_yum},${num_rpm},${longest_time_rpm}"
[ -x "$TIMEOUT" ] || bail 2 "Error,timeout not found,${num_yum},${longest_time_yum},${num_rpm},${longest_time_rpm}"

# if yum/rpm are running, bail
#if [ $yums ] ; then bail 1 "Error,Yum Running,${num_yum},${longest_time_yum},${num_rpm},${longest_time_rpm}"; fi
#if [ $rpms ] ; then bail 1 "Error,Rpm Running,${num_yum},${longest_time_yum},${num_rpm},${longest_time_rpm}"; fi
if [ "$yums" ] ; then bail 1 "Corrupt,Yum Running,${num_yum},${longest_time_yum},${num_rpm},${longest_time_rpm}"; fi
if [ "$rpms" ] ; then bail 1 "Corrupt,Rpm Running,${num_yum},${longest_time_yum},${num_rpm},${longest_time_rpm}"; fi
#pgrep -x yum >/dev/null && bail 0 "Yum running, aborting"
#pgrep -x rpm >/dev/null && bail 0 "RPM running, aborting"

# test the rpmdb, bail with appropriate message if broken
if [ "$YUM" ] ; then "$TIMEOUT" -s 9 "$TMSECS" "$YUM" -q list installed rpm >/dev/null 2>&1; 
elif [ "$DNF" ] ; then "$TIMEOUT" -s 9 "$TMSECS" "$DNF" -q list installed rpm >/dev/null 2>&1
fi
RETVAL="$?"
case "$RETVAL" in
    124)
        # 124 means timeout killed the command, which isn't always rpmdb
        bail 1 "Corrupt,Yum command timed out,${num_yum},${longest_time_yum},${num_rpm},${longest_time_rpm}"
        ;;
    137)
        # testing showed status 137 indicates timeout kill as well
        bail 1 "Corrupt,Yum command timed out,${num_yum},${longest_time_yum},${num_rpm},${longest_time_rpm}"
        ;;
    1)
        # 1 means there was a problem figuring out whether rpm was installed
        bail 1 "Corrupt,Rpm hung,${num_yum},${longest_time_yum},${num_rpm},${longest_time_rpm}"
        ;;
    *)
        # For all other exitcodes, assume no problem and exit cleanly
        bail 0 "Optimal,Optimal,${num_yum},${longest_time_yum},${num_rpm},${longest_time_rpm}"
        ;;
esac
