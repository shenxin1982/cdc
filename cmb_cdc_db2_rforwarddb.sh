#!/usr/bin/env ksh

function syntax
{
  echo "syntax:"
  echo
  echo " /usr/bin/su - <DB2InstUser> -c \"/usr/bin/sh <path>/cmb_cdc_db2_dbrforward.sh -ACTION <STOP|UNSTOP> -DBNAME <DBName> -ISOTIME <Isotime> -OVERFLOWLOGPATH <OverflowLogPath>"
  echo " "
  echo " where:"
  echo "   <DB2InstUser>   : is the owner of the DB2 instance."
  echo "   <path>          : is the full path to this script, normally"
  echo " Parameters: "
  echo "   <Action>         :  "
  echo "         <STOP>     :  rollforward to end of logs and stop"
  echo "         <UNSTOP>   :  rollforward to end of logs "
  echo "   <DBName>         : Name of the database "
  echo "   <Isotime>      : ISOTIME for rollforward "
  echo "   <OverflowLogPath>    : Log path to rollforward "

  echo
  echo " Example: "
  echo "   cmb_cdc_db2_dbrforward.sh  -ACTION STOP -DBNAME TESTDB -ISOTIME 2017-12-03-11.24.10 -OVERFLOWLOGPATH /db/sys/dbdata/overflow"
  echo "   cmb_cdc_db2_dbrforward.sh  -ACTION UNSTOP -DBNAME TESTDB -OVERFLOWLOGPATH /db/sys/dbdata/overflow"
  echo "      Note: If the db2 instance was changed during restore nbu, need ask NBU Adamin to grant authority"
  exit 22
}

function f_printError
{
  echo "[Error]:$(date "+%Y%m%d.%H%M%S"):$1" |tee -a ${LogFile};
}

function f_printWarning
{
  echo "[Warn ]:$(date "+%Y%m%d.%H%M%S"):$1" |tee -a ${LogFile};
}

function f_printInfo
{
  echo "[Info ]:$(date "+%Y%m%d.%H%M%S"):$1" |tee -a ${LogFile};
}

function f_rollforward_unstop
{
   [ -z "${Isotime}"] && typeset _Isotime="${Isotime} using local time" || typeset _Isotime="end of logs"

   f_printInfo "Rollforward database ${DBName} to ${_Isotime} overflow log path (${OverflowLogPath})"

   db2 -v "rollforward database ${DBName} to ${_Isotime} overflow log path (${OverflowLogPath})" >> ${LogFile}

   rc=$?

   if [ ${rc} -ne 0 ]
   then
     if [ "$(db2 rollforward db ${DBName} query status using local time | grep 'Rollforward status' | awk '{print $NF}')" == "working" ]
     then
        rc=0
     fi
   fi

   case ${rc} in
     0) f_printInfo "    Successfully!!!  " ;;
     *) f_printError "     Failed!!! " ;;
   esac

   return ${rc}
}


function f_rollforward_stop
{
   [ -z "${Isotime}"] && typeset _Isotime="${Isotime} using local time" || typeset _Isotime="end of logs"

   f_printInfo "Rollforward database ${DBName} to ${_Isotime} overflow log path (${OverflowLogPath})"

   db2 -v "rollforward database ${DBName} to ${_Isotime} overflow log path (${OverflowLogPath})"

   rc=$?
   echo $rc

   if [ ${rc} -ne 0 ]
   then
     if [ "$(db2 rollforward db ${DBName} query status using local time | grep 'Rollforward status' | awk '{print $NF}')" == "working" ]
     then
        db2 -v "rollforward database ${DBName} complete"
        rc=$?
     fi
   fi

   case ${rc} in
     0) f_printInfo "    Successfully!!!  " ;;
     *) f_printError "     Failed!!! " ;;
   esac

   return ${rc}
}



ShellName="$(echo $0|awk -F / '{print $NF}')"
WorkDir="$(echo $0|sed s/${ShellName}//g)"
[ -z "${WorkDir}" ] && WorkDir=$(pwd);cd ${WorkDir};WorkDir=$(pwd)
HostName=$(hostname);UserName=$(whoami);StartTime=$(date '+%Y%m%d.%H%M%S')

typeset ShellOption="$@"


for inopt in ${ShellOption}
do
  case $(echo $inopt|tr a-z A-Z) in
    -ACTION) CurOpt="-ACTION";continue;;
    -DBNAME) CurOpt="-DBNAME";continue;;
    -ISOTIME) CurOpt="-ISOTIME";continue;;
    -OVERFLOWLOGPATH) CurOpt="-OVERFLOWLOGPATH";continue;;
    -H|-*) syntax;return -1;;
  esac
  case "${CurOpt}" in
    -ACTION) Action=`echo ${inopt}| tr a-z A-Z`;;
    -DBNAME) DBName=`echo ${inopt}| tr a-z A-Z`;;
    -ISOTIME) Isotime="${inopt}";;
    -OVERFLOWLOGPATH) OverflowLogPath="${inopt}";;
  esac
done
[ -z "${DBName}" ] && syntax

LogFile="${WorkDir}/cmb_cdc_db2_rforwarddb.log"

if [ ! -f ${LogFile} ]
then
     touch ${LogFile} || LogFile="/dev/null"
     [ "${LogFile}" != "/dev/null" ] && [ -f ${LogFile} ] && chmod 666 ${LogFile}
fi

[ -z "${FilePath}" ] && FilePath="${WorkDir}"

rc=0

case "${Action}" in
  STOP) f_rollforward_stop;;
  UNSTOP) f_rollforward_unstop;;
esac

exit ${rc}
