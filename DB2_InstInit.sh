#!/usr/bin/env ksh

function syntax
{
  echo "The script is executed by OPSWare API to invoke the cmb_cdc_cdc_instinit.sh scripts."
  echo "syntax:"
  echo " DB2_InstInit.sh -HOSTNAME <HostName> -ACTION <CREATE|DROP> -VERSION <Version> -INSTNAME <InstName> -FENCNAME <FencName> -SVCENAME <Svcename> -PRODINSTPATH <ProdInstPath>  "
  echo
  echo " where:"
  echo " Parameters:"
  echo "   <HostName>      : database machine"
  echo "   <Action>        : "
      "         CREATE     :create instance"
      "         DROP       :drop instance and databases based on the instance"
  echo "   <Version>       : version pattern.  It is  Optional"
  echo "   <InstName>      : The name of instance user "
  echo "   <FencName>       : The name of fence user  "
  echo "   <Svcename>      : DB2 Instance port"
  echo "   <ProdInstPath>   : The Install Path for the db2 product ,like /opt/IBM/db2/V10.5  "
  echo
  echo " Samples: "
  echo "   DB2_InstInit.sh -HOSTNAME dba_test -ACTION create -VERSION v10.5 -INSTNAME db2inst1 -FENCNAME db2fenc1 -SVCENAME 50000 -PRODINSTPATH /opt/IBM/db2/V10.5"
  echo "   DB2_InstInit.sh -HOSTNAME dba_test -ACTION drop -INSTNAME db2inst1"
  exit 22
}

function f_printError
{
  echo "[Error]:$(date "+%Y%m%d.%H%M%S"):$1"  | tee -a ${LogFile};
}

function f_printWarning
{
  echo "[Warn ]:$(date "+%Y%m%d.%H%M%S"):$1"  | tee -a ${LogFile};
}

function f_printInfo
{
  echo "[Info ]:$(date "+%Y%m%d.%H%M%S"):$1"  | tee -a ${LogFile};
}

typeset ShellOption="$@"
for inopt in ${ShellOption}
do
  case $(echo $inopt|tr a-z A-Z) in
    -HOSTNAME) CurOpt="-HOSTNAME";continue;;
    -ACTION) CurOpt="-ACTION";continue;;
    -VERSION) CurOpt="-VERSION";continue;;
    -INSTNAME) CurOpt="-INSTNAME";continue;;
    -FENCNAME) CurOpt="-FENCNAME";continue;;
    -SVCENAME) CurOpt="-SVCENAME";continue;;
    -PRODINSTPATH) CurOpt="-PRODINSTPATH";continue;;
    -H|-*) syntax;return -1;;
  esac
  case "${CurOpt}" in
    -HOSTNAME) HostName=`echo ${inopt}`;;
    -ACTION) Action=`echo ${inopt}| tr a-z A-Z`;;
    -VERSION) Version="${inopt}";;
    -INSTNAME) InstName="${inopt}";;
    -FENCNAME) FencName="${inopt}";;
    -SVCENAME) SvceName="${inopt}";;
    -PRODINSTPATH) ProdInstPath="${inopt}";;
  esac
done

[ -z "${HostName}" ] && syntax || [ -z "${Action}" ] && syntax ||[ -z "${InstName}" ] && syntax

ShellName="$(echo $0|awk -F / '{print $NF}')"
WorkDir="$(echo $0|sed s/${ShellName}//g)"
[ -z "${WorkDir}" ] && WorkDir=$(pwd);cd ${WorkDir};WorkDir=$(pwd)
StartTime=$(date '+%Y%m%d.%H%M%S')

LogFile="${WorkDir}/logs/DB2_InstInit.log.${StartTime}"

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

ScriptName="/home/ggroot/db2/cmb_cdc_db2_instinit.sh"

if [ ! -f ${ScriptName} ]; then
   f_printError " Did not find the file \"${ScriptName}\" "
   exit -1
else
   f_printInfo " cp ${ScriptName} ${_TgtFullPath} "
   cp "${ScriptName}" "${_TgtFullPath}"
   ScriptName=$( echo ${ScriptName} | awk -F'/' '{print $NF}' )
   chmod 777 ${_TgtFullPath}/${ScriptName}
fi

ParameterString="-ACTION ${Action} -VERSION ${Version} -INSTNAME ${InstName} -FENCNAME ${FencName} -SVCENAME ${Svcename} -PRODINSTPATH ${ProdInstPath} "
_ScriptName="${_TgtWorkPath}/${ScriptName} ${ParameterString}"
f_printInfo "/opsw/bin/rosh -l root -n ${HostName} su - root \"-c  sh ${_ScriptName}  \"  "

/opsw/bin/rosh -l root -n ${HostName} su - root "-c sh ${_ScriptName} "
rc=$?
exit ${rc}
