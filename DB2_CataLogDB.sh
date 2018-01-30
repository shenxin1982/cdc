#!/usr/bin/env ksh

function syntax
{
  echo "The script is executed by OPSWare API to invoke the cmb_cdc_db2_catadb.sh scripts."
  echo "syntax:"
  echo " /home/ggroot/db2/DB2_CatalogDB.sh -HOSTNAME <HostName> -EXECUTOR <Executor> -ACTION <Action> -DBALIAS <DBAlias> -DBHOST <DBHost> -DBPORT <DBPort> -DBNAME <DBName> -INSTNAME <InstName> \" "
  echo " where:"
  echo "   <path>        : is the full path to this script, normally"
  echo " Parameters: "
  echo "   <HostName>    : must be the cdc server machine : cdcserver "
  echo "   <Executor>    : use the cdcuser "
  echo "   <Action>      : catalog | uncatalog  "
  echo "   <DBAlias>     : one of following value, SRC_<DBNAME>; TGT_<DBNAME>"
  echo "   <DBHost>      : the hostname of <DBName> existing "
  echo "   <DBPort>      : the service port of database "
  echo "   <INSTNAME>    : must be one of following value: srcinst1(v9.7 clinet),tgtinst1(v10.5 client) "
  echo " Sample: "
  echo "   DB2_CatalogDB.sh -HOSTNAME cdcserver -EXECUTOR cdcuser -ACTION catalog -DBALIAS src_sample -DBHOST dbserver.cmb.com -DBPORT 50000 -DBNAME SAMPLE -INSTNAME srcinst1"
  echo "   DB2_CatalogDB.sh -HOSTNAME cdcserver -EXECUTOR cdcuser -ACTION uncatalog -DBALIAS src_sample"
  exit 22
}

function f_printError
{
  echo "[Error]:$(date "+%Y%m%d.%H%M%S"):$1"| tee -a ${LogFile} ;
}

function f_printWarning
{
  echo "[Warn ]:$(date "+%Y%m%d.%H%M%S"):$1"| tee -a ${LogFile} ;
}

function f_printInfo
{
  echo "[Info ]:$(date "+%Y%m%d.%H%M%S"):$1"| tee -a ${LogFile} ;
}

typeset ShellOption="$@"
for inopt in ${ShellOption}
do
  case $(echo $inopt|tr a-z A-Z) in
    -HOSTNAME) CurOpt="-HOSTNAME";continue;;
    -EXECUTOR) CurOpt="-EXECUTOR";continue;;
    -ACTION) CurOpt="-ACTION";continue;;
    -DBALIAS) CurOpt="-DBALIAS";continue;;
    -DBHOST) CurOpt="-DBHOST";continue;;
    -DBPORT) CurOpt="-DBPORT";continue;;
    -DBNAME) CurOpt="-DBNAME";continue;;
    -INSTNAME) CurOpt="-INSTNAME";continue;;
    -H|-*) syntax;return -1;;
  esac
  case "${CurOpt}" in
    -HOSTNAME) HostName=`echo ${inopt}`;;
    -EXECUTOR) Executor=`echo ${inopt}`;;
    -ACTION) Action=`echo ${inopt}| tr a-z A-Z`;;
    -DBALIAS) DBAlias=`echo ${inopt}| tr a-z A-Z`;;
    -DBHOST) DBHost="${inopt}";;
    -DBPORT) DBPort="${inopt}";;
    -DBNAME) DBName="${inopt}";;
    -INSTNAME) InstName="${inopt}";;
  esac
done

[ -z "${HostName}" ] && syntax || [ -z "${Executor}" ] && syntax
[ -z "${Action}" ] && syntax || [ -z "${DBAlias}" ] && syntax
[ -z "${DBHost}" ] && syntax || [ -z "${DBPort}" ] && syntax
[ -z "${DBName}" ] && syntax || [ -z "${InstName}" ] && syntax

ShellName="$(echo $0|awk -F / '{print $NF}')"
WorkDir="$(echo $0|sed s/${ShellName}//g)"
[ -z "${WorkDir}" ] && WorkDir=$(pwd);cd ${WorkDir};WorkDir=$(pwd)
StartTime=$(date '+%Y%m%d.%H%M%S')
LogFile="${WorkDir}/logs/DB2_CatalogDB.log.${StartTime}"

if [ ! -f ${LogFile} ]
then
     touch ${LogFile} || LogFile="/dev/null"
     [ "${LogFile}" != "/dev/null" ] && [ -f ${LogFile} ] && chmod 666 ${LogFile}
fi

f_printInfo ">>>>> $(date "+%Y%m%d.%H%M%S") <<<<< " > ${LogFile}

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

ScriptName="/home/ggroot/db2/cmb_cdc_db2_catadb.sh"

if [ ! -f ${ScriptName} ]; then
   f_printError " Did not find the file \"${ScriptName}\" "
   exit -1
else
   f_printInfo " cp ${ScriptName} ${_TgtFullPath} "
   cp "${ScriptName}" "${_TgtFullPath}"
   ScriptName=$( echo ${ScriptName} | awk -F'/' '{print $NF}' )
   chmod 777 ${_TgtFullPath}/${ScriptName}
fi

ParameterString="-ACTION ${Action} -DBALIAS ${DBAlias} -DBHOST ${DBHost} -DBPORT ${DBPort} -DBNAME ${DBName} -INSTNAME ${InstName}"
_ScriptName="${_TgtWorkPath}/${ScriptName} ${ParameterString}"
f_printInfo "/opsw/bin/rosh -l root -n ${HostName} su - ${Executor} -c  \"sh ${_ScriptName}  \"  "
/opsw/bin/rosh -l root -n ${HostName} su - ${Executor} -c "sh ${_ScriptName} "
rc=$?
exit ${rc}
