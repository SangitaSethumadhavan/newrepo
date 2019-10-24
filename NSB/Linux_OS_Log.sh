#!/bin/sh
#===================================================================================================
#
#         FILE:  Linux_check_oslog.sh
#
#        Usage: $(basename $0)
#
#  DESCRIPTION:  "Script checks the exception messages in oslog"
#
#      OPTIONS:  ---
# REQUIREMENTS:  ---
#         BUGS:  ---
#        NOTES:  ---
#       AUTHOR:  GIS Automation Team
#      COMPANY:  Wipro Technologies
#      VERSION:  1.0
#      CREATED:  2/12/2015
#     REVISION:  ---
##############################################################################
# restrict the user who can execute this script
##############################################################################

if [ root != "root" ] || [ root != "root" ]
then
        echo "NON ROOT USER: ACCESS DENIED"
        exit 1
fi

##################################################################################################
# Define program specific Variables
##################################################################################################
#Set to 1 to debug the functions called in script.
DEBUG_MODE=0                    ;                                               export DEBUG_MODE

#################################################################################################
# Edit these three variables based on the flavors supported and the account
##################################################################################################
OS_FLAVORS=""Linux""                                                              ; export OS_FLAVORS
ACCOUNT_NAME="generic"                                                              ; export ACCOUNT_NAME
SCRIPT_OBJECTIVE="Oslog_error_check"                                  ; export SCRIPT_OBJECTIVE
#===================================================================================================

##################################################################################################
# standard Variables
##################################################################################################
OS=`uname`                                                                      ; export OS
HOSTNAME=`uname -n`                                                             ; export HOSTNAME
DATE=`date +%b-%d-%Y`                                                           ; export DATE
SCRIPT_LOCATION=`dirname "$0"`                                                  ; export SCRIPT_LOCATION
#SCRIPT_LOCATION="/usr/local/bin"                                               ; export SCRIPT_LOCATION
SCRIPT_STATUS="SUCCESS"                                                         ; export SCRIPT_STATUS
BASEDIR="/var/tmp/${SCRIPT_OBJECTIVE}"                                                ; export BASEDIR
TMPDIR="/tmp"                                                                  ; export TMPDIR
LOGDIR="${BASEDIR}/logs"                                                        ; export LOGDIR
EXTENSION="${HOSTNAME}.${DATE}.$$"                                              ; export EXTENSION
LOG_FILE="${LOGDIR}/${SCRIPT_OBJECTIVE}_log.${EXTENSION}"                           ; export LOG_FILE
OUTFILE="${LOGDIR}/${SCRIPT_OBJECTIVE}_console_output_log.${EXTENSION}"            ; export OUTFILE
ERROR_LOGFILE="${LOGDIR}/${SCRIPT_OBJECTIVE}_error.log.${EXTENSION}"               ; export ERROR_LOGFILE
PATH=${PATH}:${SCRIPT_LOCATION}                                                 ; export PATH

case "${OS}" in
        SunOS)
                PATH="/usr/xpg4/bin:/bin:/usr/bin:/sbin:/usr/sbin:${PATH}"                      ; export PATH
        ;;
        *)
                PATH="/bin:/usr/bin:/sbin:/usr/sbin:${PATH}"                                    ; export PATH
        ;;
esac

##################################################################################################
# Based on the account name and the script type, determine script's pre-name
##################################################################################################
SCRIPT_PREFIX=""                                                                ; export SCRIPT_PREFIX
if [ -n "${ACCOUNT_NAME}" ] ; then SCRIPT_PREFIX="${ACCOUNT_NAME}_"; fi
if [ -n "${SCRIPT_OBJECTIVE}" ] ; then SCRIPT_PREFIX="${SCRIPT_PREFIX}${OS_FLAVORS}_${SCRIPT_OBJECTIVE}_"; fi
export SCRIPT_PREFIX

##################################################################################################
# Initialize the scripts files needed for the script execution
##################################################################################################
##################################################################################################
# Declare important scripts and config files used
##################################################################################################
CONSTANTS_FILE="${SCRIPT_LOCATION}/script_constants"                            ; export CONSTANTS_FILE
FUNCTIONS_FILE="${SCRIPT_LOCATION}/${SCRIPT_PREFIX}function_definitions"        ; export FUNCTIONS_FILE
##################################################################################################
# Clean up the temporary files on exit, abort, failed etc
##################################################################################################
trap 'Clean_fn 2> /dev/null' 0
trap 'Clean_fn 2> /dev/null; exit' 1 2 3 15


clear

##################################################################################################
# Ensure the Server's OS is supported by the script.
##################################################################################################
if [ `echo -e "${OS_FLAVORS}" | grep -c "${OS}"` -eq 0 ]
then
        echo -e "ERROR: Script currently does not support ${OS} flavor. Please check with administrator of the script."
        exit 2
fi

##################################################################################################
# Ensure all the script files needed for execution exists.
##################################################################################################
for FILE in ${CONSTANTS_FILE} 
do
        if [ ! -f ${FILE} ] ; then
                echo -e  "ERROR: ${FILE} file does not exist. Please copy the file and rerun the script."
                exit
        fi
done

##############################################################################
# Create the data and log directories
##############################################################################
if [ ! -d ${BASEDIR} ]; then mkdir -p ${BASEDIR}; fi
if [ ! -d ${LOGDIR} ]; then mkdir -p ${LOGDIR}; fi

##################################################################################################
# source the necessary global constants and  global functions used for this script
##################################################################################################

##############################################################################
# Initialise  the variables used in the script in current shell and export them
##############################################################################
. ${CONSTANTS_FILE} 2> /dev/null

##############################################################################
# Define the Functions used in the script in current shell
##############################################################################


################################################################
### Function to log the message in global log file
################################################################
Write_log_fn()
{
        TEXT="$1"
        MSG="$2"
        HEADER="$3"
        ${ECHO_CMD} "`date '+%b %d %Y %H:%M:%S'` - ${HEADER} -  ${MSG} - ${TEXT}" >> ${LOG_FILE}
}

################################################################
### Function to log formatted message
################################################################
Write_output_fn()
{
        ${ECHO_CMD} "${LLINE}\n" >> ${LOG_FILE}
        ${ECHO_CMD} "$1" >> ${LOG_FILE}
        ${ECHO_CMD} "${LLINE}\n" >> ${LOG_FILE}

}


################################################################################
# Function to write the output message in a formatted manner.
################################################################################
display_message_fn()
{
        #Get the Message and the Message Code to be displayed
        TEXT="$1"
        MSG="$2"

        #Determine the Color value based on the Message code
        case "${MSG}" in
                ERROR)
                        COLOR="${RED_F}"
                ;;
                WARN)
                        COLOR="${CYAN_F}"
                ;;
                INFO)
                        COLOR=""
                ;;
                OK)
                        COLOR="${GREEN_F}"
                ;;
        esac

        #Display the message in the screen in appropriate colour
        ${ECHO_CMD} "${COLOR}\c"
        ${ECHO_CMD} "${TEXT}" | awk -v msg="${MSG}" '{printf("%5s %-100s %10s\n","",$0,"[ "msg" ]")}'
        ${ECHO_CMD} "${NORM}\c"

        #Write the message in the script log file
        ${ECHO_CMD} "      `date +%d-%b-%Y' '%H:%M:%S` - ${MSG} - ${TEXT}" >> ${LOG_FILE}

}



#################################################################################################
# Function displays script usage
#################################################################################################
Usage_fn()
{

clear
${ECHO_CMD} "
##################################################################################################################################
#
#         FILE:  Linux_check_oslog.sh 
#
#  DESCRIPTION:  "Script checks the exception messages in oslog"
#
#        USAGE:  $(basename $0) [ -h ]
#
#                -h Help
#
##################################################################################################################################"

sleep 2
exit

}


#################################################################################################
# Function to check  Oslog_error_check
#################################################################################################
Check_oslog_fn()
{

if [ ${DEBUG_MODE} -eq 1 ] ; then set -x; fi

        PATTERN='WARN|CRIT|FAIL|NOTICE'
        TEMPFILE="/tmp/syserr.$$"                                               ; > $TEMPFILE  ;

        L_COUNT=0

        L_RC=0
        M="JanFebMarAprMayJunJulAugSepOctNovDec"
        SDATE=`perl -e "print join (':',(localtime(time-86400)));"`
        EDATE=`perl -e "print join (':',(localtime(time)));"`
        count="0"

        #
        # Based on the UNIX OS , check the relevant OS log files for any OS related errors logged in last one day
        #

        case "$OS" in
                AIX)
                        OSLOG_FILE="errpt"
                        STARTDATE=`${ECHO_CMD} $SDATE | awk  -F':' ' {printf "%02d%02d%02d%02d%02d\n",$5+1,$4,$3,$2,$6-100;}'`
                        ENDDATE=`${ECHO_CMD} $EDATE  | awk  -F':' ' {printf "%02d%02d%02d%02d%02d\n",$5+1,$4,$3,$2,$6-100;}'`
                        errpt -s $STARTDATE -e $ENDDATE -T PERM -d H,S > $TEMPFILE
                ;;
                SunOS)
                        OSLOG_FILE="/var/adm/messages"
                        if [ ! -f "${OSLOG_FILE}" ]
                        then
                                display_message_fn "OS Log : ${OSLOG_FILE} is missing" "ERROR"
                                return
                        fi

                        STARTDATE=`${ECHO_CMD} ${SDATE}  | awk  -F':' -v MN="${MONTH}" '{printf "%s %2d\n",substr(MN,1+($5*3),3),$4;}'`
                        ENDDATE=`${ECHO_CMD} ${EDATE}  | awk  -F':' -v MN="${MONTH}" '{printf "%s %2d\n",substr(MN,1+($5*3),3),$4;}'`
                        egrep -v "^${STARTDATE} [0][0-7]:" $OSLOG_FILE | \
				egrep "^${STARTDATE}" | egrep -i "${PATTERN}" | sed "s/^.*\[ID [0-9].* [a-z].*[a-z]\]//" | sort | uniq > ${TEMPFILE}
                        egrep "^${ENDDATE}" $OSLOG_FILE | egrep -i "${PATTERN}" | sed "s/^.*\[ID [0-9].* [a-z].*[a-z]\]//" | sort | uniq >> ${TEMPFILE}
                ;;
                Linux)
                        OSLOG_FILE="/var/log/messages"
                        if [ ! -f "${OSLOG_FILE}" ]
                        then
                                 display_message_fn  "OS Log : ${OSLOG_FILE} is missing" "ERROR"
                                return
                        fi
                        STARTDATE=`${ECHO_CMD} ${SDATE}  | awk  -F':' -v MN="${MONTH}" '{printf "%s %2d\n",substr(MN,1+($5*3),3),$4;}'`
                        ENDDATE=`${ECHO_CMD} ${EDATE}  | awk  -F':' -v MN="${MONTH}" '{printf "%s %2d\n",substr(MN,1+($5*3),3),$4;}'`
                        egrep -v "^${STARTDATE} [0][0-7]:" $OSLOG_FILE 2> /dev/null |\
				 egrep "^${STARTDATE}" | egrep -i "${PATTERN}" | sed "s/^.*\[ID [0-9].* [a-z].*[a-z]\]//" | sort | uniq > ${TEMPFILE}
                        egrep "^${ENDDATE}" $OSLOG_FILE 2> /dev/null | egrep -i "${PATTERN}" | sed "s/^.*\[ID [0-9].* [a-z].*[a-z]\]//" | sort | uniq >> ${TEMPFILE}

                ;;
                HP-UX)
                        OSLOG_FILE="/var/adm/syslog/syslog.log"
                        if [ ! -f "${OSLOG_FILE}" ]
                        then
                                 display_message_fn  "OS Log : ${OSLOG_FILE} is missing" "ERROR"
                                return
                        fi
                        STARTDATE=`${ECHO_CMD} ${SDATE}  | awk  -F':' -v MN="${MONTH}" '{printf "%s %2d\n",substr(MN,1+($5*3),3),$4;}'`
                        ENDDATE=`${ECHO_CMD} ${EDATE}  | awk  -F':' -v MN="${MONTH}" '{printf "%s %2d\n",substr(MN,1+($5*3),3),$4;}'`
                        egrep -v "^${STARTDATE} [0][0-7]:" $OSLOG_FILE |\
				 egrep "^${STARTDATE}" | egrep -i "${PATTERN}" | sed "s/^.*\[ID [0-9].* [a-z].*[a-z]\]//" |sort | uniq > ${TEMPFILE} 
                        egrep "^${ENDDATE}" $OSLOG_FILE | egrep -i "${PATTERN}" | sed "s/^.*\[ID [0-9].* [a-z].*[a-z]\]//" | sort | uniq >> ${TEMPFILE}
                ;;

        esac

        if [ -s "$TEMPFILE" ]
        then
                L_COUNT=`cat $TEMPFILE| wc -l`
                #printf "$L_COUNT,"
                display_message_fn "OS Log Validations failed. Errors found in ${OSLOG_FILE} output." "ERROR"
                Write_output_fn "`cat $TEMPFILE`"
                rm $TEMPFILE
                L_RC=1
        else
                #L_COUNT=0; printf "$L_COUNT,"
                display_message_fn "OS Log check" "OK"
                L_RC=0
        fi


if [ ${DEBUG_MODE} -eq 1 ] ; then set +x; fi

return ${L_RC}


}
#########################################################################################
# Main program
#########################################################################################


#########################################################################################
# Get the user input , to determine the purpose of running the script either through command prompt or through interactive method.
#########################################################################################


while getopts :h: OPTION
do
        case "${OPTION}" in

                h)       Usage_fn
                                ;;
                *)       sleep  1 ; clear
                         $ECHO_CMD "Invalid option provided"
                         sleep  1 ; clear
                         Usage_fn
                                ;;
        esac
done

clear
${ECHO_CMD} "Oslog_error_check Validation: localhost  - ${DATE}" | awk '{printf ("\n%80s\n",$0)}' | tee -a ${LOG_FILE}
${ECHO_CMD} "${LINE}\n" | tee -a ${LOG_FILE}

Check_oslog_fn

${ECHO_CMD} "${LINE}\n" | tee -a ${LOG_FILE}
display_message_fn "Log File: ${LOG_FILE}" "INFO"
${ECHO_CMD} "${LINE}\n" | tee -a ${LOG_FILE}


