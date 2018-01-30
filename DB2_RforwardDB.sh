#!/usr/bin/env ksh

function syntax
{
  echo "The script is executed by OPSWare API to invoke the cmb_cdc_db2_rforwarddb.sh scripts."
  echo "syntax:"
  echo " DB2_RforwardDB.sh -HOSTNAME <HostName> -EXECUTOR <Executor> -ACTION <STOP|UNSTOP> -DBNAME <DBName> -ISOTIME <Isotime> -OVERFLOWLOGPATH <OverflowLogPath>   "
  echo
  echo " where:"
  echo "   <HostName>   : The database machine"
  echo "   <EXECUTOR>     : Name of the instance"
  echo "   <Action>         :  "
  echo "         <STOP>     :  rollforward to end of logs and stop"
  echo "         <UNSTOP>   :  rollforward to end of logs "
  echo "   <DBName>         : Name of the database "
  echo "   <Isotime>      : ISOTIME for rollforward "
  echo "   <OverflowLogPath>    : Log path to rollforward "
  echo " Samples: "
  echo "   DB2_RforwardDB.sh -HOSTNAME dba_test -EXECUTOR db2inst1 -ACTION UNSTOP -DBNAME TESTDB -OVERFLOWLOGPATH /db/sys/dbdata/overflow"
  exit 22
}

function f_printError
{
  echo "[Error]:$(date "+%Y%m%d.%H%M%S"):$1" | tee -a ${LogFile};
}

function f_printWarning
{
  echo "[Warn ]:$(date "+%Y%m%d.%H%M%S"):$1" | tee -a ${LogFile};
}

function f_printInfo
{
  echo "[Info ]:$(date "+%Y%m%d.%H%M%S"):$1" | tee -a ${LogFile};
}

typeset ShellOption="$@"
for inopt in ${ShellOption}
do
  case $(echo $inopt|tr a-z A-Z) in
    -HOSTNAME) CurOpt="-HOSTNAME";continue;;
    -EXECUTOR) CurOpt="-EXECUTOR";continue;;
    -ACTION) CurOpt="-ACTION";continue;;
    -DBNAME) CurOpt="-DBNAME";continue;;
    -ISOTIME) CurOpt="-ISOTIME";continue;;
    -OVERFLOWLOGPATH) CurOpt="-OVERFLOWLOGPATH";continue;;
    -H|-*) syntax;return -1;;
  esac
  case "${CurOpt}" in
    -HOSTNAME) HostName=`echo ${inopt}`;;
    -EXECUTOR) ExeCutor=`echo ${inopt}`;;
    -ACTION) Action=`echo ${inopt}| tr a-z A-Z`;;
    -DBNAME) DBName=`echo ${inopt}| tr a-z A-Z`;;
    -ISOTIME) Isotime="${inopt}";;
    -OVERFLOWLOGPATH) OverflowLogPath="${inopt}";;
  esac
done

[ -z "${HostName}" ] && syntax

ShellName="$(echo $0|awk -F / '{print $NF}')"
WorkDir="$(echo $0|sed s/${ShellName}//g)"
[ -z "${WorkDir}" ] && WorkDir=$(pwd);cd ${WorkDir};WorkDir=$(pwd)
StartTime=$(date '+%Y%m%d.%H%M%S')

LogFile="${WorkDir}/logs/DB2_RforwardDB.log.${StartTime}"

if [ ! -f ${LogFile} ]
then
     touch ${LogFile} || LogFile="/dev/null"
     [ "${LogFile}" != "/dev/null" ] && [ -f ${LogFile} ] && chmod 666 ${LogFile}
fi

f_printInfo ">>>>> $(date "+%Y%m%d.%H%M%S") <<<<< "

## change file target to /home/dbmonusr
_dbmonusrPath="/home/dbmonusr"
_dbmonusrFullPath="/opsw/Server/@/${HostName}/files/root${_dbmonusrPath}"

_TgtWorkPath=""
_TgtFullPath="/opsw/Server/@/${HostName}/files/root"


if [ -d "${_dbmonusrFullPath}" ]; then
   _TgtWorkPath="${_dbmonusrPath}/autocdc"
   _TgtFullPath="${_TgtFullPath}${_TgtWorkPath}"
else
   _TgtWorkPath="/tmp/autocdc"
   _TgtFullPath="${_TgtFullPath}${_TgtWorkPath}"
fi

if [ ! -d "${_TgtFullPath}" ]; then
   mkdir -p  "${_TgtFullPath}"
fi

chmod 777 ${_TgtFullPath}

ScriptName="/home/ggroot/db2/cmb_cdc_db2_rforwarddb.sh"

if [ ! -f ${ScriptName} ]; then
   f_printError " Did not find the file \"${ScriptName}\" "
   exit -1
else
   f_printInfo " cp ${ScriptName} ${_TgtFullPath} "
   cp "${ScriptName}" "${_TgtFullPath}"
   ScriptName=$( echo ${ScriptName} | awk -F'/' '{print $NF}' )
   chmod 777 ${_TgtFullPath}/${ScriptName}
fi

ParameterString="-ACTION ${Action} -DBNAME ${DBName} -ISOTIME ${Isotime} -OVERFLOWLOGPATH ${OverflowLogPath} "
_ScriptName="${_TgtWorkPath}/${ScriptName} ${ParameterString}"
f_printInfo "/opsw/bin/rosh -l root -n ${HostName} su - ${ExeCutor} -c \"sh ${_ScriptName}  \"  "

/opsw/bin/rosh -l root -n ${HostName} su - ${ExeCutor}  -c "sh ${_ScriptName} "
rc=$?
exit ${rc}
