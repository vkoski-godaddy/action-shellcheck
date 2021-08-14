#!/bin/sh
# Returns "Yes" if a machine has an iptables rule named "Tanium Quarantine",
# otherwise returns "No".  Output of 'inactive' means iptables is inactive
# Returns 'N/A' if service/systemctl commands did not work
# Returns 'Error' if iptables commands did not work and tanium quarantine could not be determined - We don't expect to get this result.
# If any of the active IP tables rules have a comment 'Tanium Quarantine',
# then this is an indication the quarantine rules have been applied
if [ "$(which systemctl 2>/dev/null)" ]; then
    systemctl is-active --quiet iptables
    RC=$?
    if [ $RC = 0 ]; then
        iptables -L -n 2>/dev/null| grep -iq "tanium quarantine" && message="Yes" || message="No"
    else
         message="inactive"
    fi
elif [ "$(which service 2>/dev/null)" ]; then
    service iptables status > /dev/null 2>&1
    RC=$?
    if [ $RC = 0 ]; then 
        iptables -L -n 2>/dev/null| grep -iq "tanium quarantine" && message="Yes" || message="No"
    else
        message="inactive"
    fi
else
    message="N/A"
fi
if [ -z $message ]; then
    message="Error" #We don't expect to get here
fi
echo "$message"
exit 0
