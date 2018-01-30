#!/usr/bin/env ksh

function syntax
{
  echo "The script is executed by OPSWare API to invoke the cmb_cdc_db2_backupdb.sh scripts."
  echo "syntax:"
  echo " DB2_BackupDB.sh -HOSTNAME <HostName> -EXECUTOR <Executor> -ACTION <Action> -DBNAME <DBName> -FILEPATH <FilePath>  "
  echo
  echo " where:"
  echo "   <HostName>       : The database machine"
  echo "   <EXECUTOR>       : Name of the instance"
  echo "   <Action>         :  "
  echo "         <ONLINE>   :  online backup"
  echo "         <OFFLINE>  :  offline backup "
  echo "   <DBName>         : Name of the database "
  echo "   <FilePath>       : Backup image path "
  echo " Samples: "
  echo "   DB2_BackupDB.sh -HOSTNAME dba_test -EXECUTOR db2inst1 -ACTION OFFLINE -DBNAME testdb1 -FILEPATH /tmp"
  echo "   DB2_BackupDB.sh -HOSTNAME dba_test -EXECUTOR db2inst1 -ACTION ONLINE -DBNAME testdb1 -FILEPATH /tmp"
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
    -ACTION) CurOpt="-ACTION";;
    -DBNAME) CurOpt="-DBNAME";;
    -FILEPATH) CurOpt="-FILEPATH";continue;;
    -H|-*) syntax;return -1;;
  esac
  case "${CurOpt}" in
    -HOSTNAME) HostName=`echo ${inopt}`;;
    -EXECUTOR) ExeCutor=`echo ${inopt}`;;
    -ACTION) Action=`echo ${inopt}| tr a-z A-Z`;;
    -DBNAME) DBName=`echo ${inopt}| tr a-z A-Z`;;
    -FILEPATH) FilePath="${inopt}";;
  esac
done

[ -z "${HostName}" ] && syntax [ -z "${DBName}" ] && syntax || [ -z "${Action}" ] && syntax

ShellName="$(echo $0|awk -F / '{print $NF}')"
WorkDir="$(echo $0|sed s/${ShellName}//g)"
[ -z "${WorkDir}" ] && WorkDir=$(pwd);cd ${WorkDir};WorkDir=$(pwd)
StartTime=$(date '+%Y%m%d.%H%M%S')

LogFile="${WorkDir}/logs/DB2_BackupDB.log.${StartTime}"

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

ScriptName="/home/ggroot/db2/cmb_cdc_db2_backupdb.sh"

if [ ! -f ${ScriptName} ]; then
   f_printError " Did not find the file \"${ScriptName}\" "
   exit -1
else
   f_printInfo " cp ${ScriptName} ${_TgtFullPath} "
   cp "${ScriptName}" "${_TgtFullPath}"
   ScriptName=$( echo ${ScriptName} | awk -F'/' '{print $NF}' )
   chmod 777 ${_TgtFullPath}/${ScriptName}
fi

ParameterString="-ACTION ${Action} -DBNAME ${DBName} -FILEPATH ${FilePath} "
_ScriptName="${_TgtWorkPath}/${ScriptName} ${ParameterString}"
f_printInfo "/opsw/bin/rosh -l root -n ${HostName} su - ${ExeCutor} -c \"sh ${_ScriptName}  \"  "

/opsw/bin/rosh -l root -n ${HostName} su - ${ExeCutor}  -c "sh ${_ScriptName} "
rc=$?
exit ${rc}
