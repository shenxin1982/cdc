#!/usr/bin/env ksh

function syntax
{
  echo "The script is executed by OPSWare API to invoke the cmb_cdc_db2_precheck.sh & cmb_cdc_sys_precheck.sh scripts."
  echo "syntax:"
  echo "sh /home/ggroot/db2/DB2_Precheck.sh -HOSTNAME <HostName> -EXECUTOR <ExeCutor> -DBNAME <DBName> -INSTNAME <InstName>  -DBCODEPAGE <DBCodePage> -DBTERRITORY <DBTerritory> \" "
  echo
  echo " executed by ooflow user"
  echo " Parameters: "
  echo "   <HostName>     : Name of the DBHOST "
  echo "   <ExeCutor>     : Name of the INSTANCE "
  echo "   <DBName>       : Name of the database "
  echo "   <INSTNAME>   :  Name of the instance "
  echo "   <DBCodePage>   :  "
  echo "   <DBTerritory>   :  "
  echo " Samples: "
  echo "   DB2_Precheck.sh -HOSTNAME dba_test -EXECUTOR srcinst1 -DBNAME testdb -INSTNAME db2inst1 -DBCODEPAGE 1386 -DBTERRITORY 86"
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
    -DBNAME) CurOpt="-DBNAME";continue;;
    -INSTNAME) CurOpt="-INSTNAME";continue;;
    -DBCODEPAGE) CurOpt="-DBCODEPAGE";continue;;
    -DBTERRITORY) CurOpt="-DBTERRITORY";continue;;
    -H|-*) syntax;return -1;;
  esac
  case "${CurOpt}" in
    -HOSTNAME) HostName=`echo ${inopt}`;;
    -EXECUTOR) ExeCutor=`echo ${inopt}`;;
    -DBNAME) DBName=`echo ${inopt}| tr a-z A-Z`;;
    -INSTNAME) InstName=`echo ${inopt}`;;
    -DBCODEPAGE) DBCodePage=`echo ${inopt}`;;
    -DBTERRITORY) DBTerritory=`echo ${inopt}`;;
  esac
done

[ -z "${HostName}" ] && syntax || [ -z "${DBName}" ] && syntax

ShellName="$(echo $0|awk -F / '{print $NF}')"
WorkDir="$(echo $0|sed s/${ShellName}//g)"
[ -z "${WorkDir}" ] && WorkDir=$(pwd);cd ${WorkDir};WorkDir=$(pwd)
StartTime=$(date '+%Y%m%d.%H%M%S')

LogFile="${WorkDir}/logs/DB2_Precheck.log.${StartTime}"

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

ScriptName="/home/ggroot/db2/cmb_cdc_db2_precheck.sh"
ScriptName1="/home/ggroot/db2/cmb_cdc_sys_precheck.sh"

if [ ! -f ${ScriptName} ]; then
   f_printError " Did not find the file \"${ScriptName}\" "
   exit -1
else
   f_printInfo " cp ${ScriptName} ${_TgtFullPath} "
   cp "${ScriptName}" "${_TgtFullPath}"
   ScriptName=$( echo ${ScriptName} | awk -F'/' '{print $NF}' )
   chmod 777 ${_TgtFullPath}/${ScriptName}
    f_printInfo " cp ${ScriptName1} ${_TgtFullPath} "
   cp "${ScriptName1}" "${_TgtFullPath}"
   ScriptName1=$( echo ${ScriptName1} | awk -F'/' '{print $NF}' )
   chmod 777 ${_TgtFullPath}/${ScriptName1}
fi

ParameterString="-DBNAME ${DBName} -INSTNAME ${InstName}  -DBCODEPAGE ${DBCodePage} -DBTERRITORY ${DBTerritory}"
_ScriptName="${_TgtWorkPath}/${ScriptName} ${ParameterString}"

_ScriptName1="${_TgtWorkPath}/${ScriptName1}"

f_printInfo "/opsw/bin/rosh -l root -n ${HostName} su - ${ExeCutor} -c \" sh ${_ScriptName}  \"  "
/opsw/bin/rosh -l root -n ${HostName} su - ${ExeCutor} -c "sh ${_ScriptName} "
/opsw/bin/rosh -l root -n ${HostName} su - root -c "sh ${_ScriptName1} "
rc=$?
exit ${rc}
