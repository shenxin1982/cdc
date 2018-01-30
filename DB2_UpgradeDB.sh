#!/usr/bin/env ksh

function syntax
{
  echo "The script is executed by OPSWare API to invoke the cmb_cdc_db2_upgradedb.sh scripts."
  echo "syntax:"
  echo " DB2_UpgradeDB.sh -HOSTNAME <HostName> -DBLEVEL <DBLevel> -DBINST <DBInstUser> -V97PATH <V97path> -V105PATH <V105path>  \" "
  echo
  echo " where:"
  echo "   <HostName>   : The database machine"
  echo "   <DBName>     : Name of the database"
  echo "   <DBLEVEL>    : v10.5 or v9.7."
  echo "   <V97path>    : DB2 V9.7 Product install path."
  echo "   <V105path>   : DB2 V10.5 Product install path."
  echo " Samples: "
  echo "   DB2_UpgradeDB.sh -HOSTNAME dba_test -DBLEVEL v10.5 -DBINST srcinst1 -V97PATH /opt/IBM/db2/V9.7.8 -V105PATH /opt/IBM/db2/V10.5.5"
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
    -DBINST) CurOpt="-DBINST";continue;;
    -V97PATH) CurOpt="-V97PATH";continue;;
    -V105PATH) CurOpt="-V105PATH";continue;;
    -H|-*) syntax;return -1;;
  esac
  case "${CurOpt}" in
    -HOSTNAME) HostName=`echo ${inopt}`;;
    -DBLEVEL) DBLevel=`echo ${inopt}| tr a-z A-Z`;;
    -DBINST) DBInstUser="${inopt}";;
    -V97PATH) V97path="${inopt}";;
    -V105PATH) V105path="${inopt}";;
  esac
done

[ -z "${HostName}" ] && syntax  || [ -z "${DBInstUser}" ] && syntax || [ -z "${V105path}" ] && syntax || [ -z "${DBLevel}" ] && syntax

ShellName="$(echo $0|awk -F / '{print $NF}')"
WorkDir="$(echo $0|sed s/${ShellName}//g)"
[ -z "${WorkDir}" ] && WorkDir=$(pwd);cd ${WorkDir};WorkDir=$(pwd)
StartTime=$(date '+%Y%m%d.%H%M%S')

LogFile="${WorkDir}/logs/DB2_UpgradeDB.log.${StartTime}"

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

ScriptName="/home/ggroot/db2/cmb_cdc_cdc_upgradedb.sh"

if [ ! -f ${ScriptName} ]; then
   f_printError " Did not find the file \"${ScriptName}\" "
   exit -1
else
   f_printInfo " cp ${ScriptName} ${_TgtFullPath} "
   cp "${ScriptName}" "${_TgtFullPath}"
   ScriptName=$( echo ${ScriptName} | awk -F'/' '{print $NF}' )
   chmod 777 ${_TgtFullPath}/${ScriptName}
fi

ParameterString="-DBLEVEL ${DBLevel} -DBINST ${DBInstUser} "
_ScriptName="${_TgtWorkPath}/${ScriptName} ${ParameterString}"
f_printInfo "/opsw/bin/rosh -l root -n ${HostName} -c "sh ${_ScriptName}  \"  "

/opsw/bin/rosh -l root -n ${HostName} -c "sh ${_ScriptName} "
rc=$?
exit ${rc}
