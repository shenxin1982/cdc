#!/usr/bin/env ksh

function syntax
{
  echo "The script is executed by OPSWare API to invoke the cmb_cdc_cdc_tablook.sh scripts."
  echo "syntax:"
  echo " DB2_TabLook.sh -SOURCE_HOST <Source_Host> -TARGET_HOST <Target_Host> -SOURCE_INST <Source_Inst> -TARGET_INST <Target_Inst> -DBNAME <DBName> -FILEPATH <FilePath> -FILENAME <FileName> \" "
  echo " Parameters:"
  echo "   <Source_Host>      : The source database machine"
  echo "   <Target_Host>      : The target database machine"
  echo "   <Source_Inst>     : Name of the source instance"
  echo "   <Target_Inst>     : Name of the target instance"
  echo "   -DBNAME         : Database name "
  echo "   -FILEPATH       : Specify path for the ddl file write to or read from; "
  echo "                     same path as the script if does not given the value"
  echo "   -FILENAME       : Specify name of the ddl file;"
  echo "                     default named as ${DBName}.ddl, if does not given the value"
  echo " Samples: "
  echo "   DB2_TabLook.sh -SOURCE_HOST test1 -TARGET_HOST test2 -SOURCE_INST db2inst1 -Target_inst cdcinst -DBNAME testdb1 "
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
    -SOURCE_HOST) CurOpt="-SOURCE_HOST";continue;;
    -TARGET_HOST) CurOpt="-TARGET_HOST";continue;;
    -SOURCE_INST) CurOpt="-SOURCE_INST";continue;;
    -TARGET_INST) CurOpt="-TARGET_INST";continue;;
    -DBNAME) CurOpt="-DBNAME";continue;;
    -FILEPATH) CurOpt="-FILEPATH";continue;;
    -FILENAME) CurOpt="-FILENAME";continue;;
    -H|-*) syntax;return -1;;
  esac
  case "${CurOpt}" in
    -SOURCE_HOST) Source_Host="${inopt}";;
    -TARGET_HOST) Target_Host="${inopt}";;
    -SOURCE_INST) Source_Inst=`echo ${inopt}`;;
    -TARGET_INST) Target_Inst=`echo ${inopt}`;;
    -DBNAME) DBName=`echo ${inopt}| tr a-z A-Z`;;
    -FILEPATH) FilePath="${inopt}";;
    -FILENAME) FileName=`echo ${inopt}| tr a-z A-Z`;;
  esac
done

[ -z "${Source_Host}" ] && syntax || [ -z "${Source_Host}" ] && syntax
[ -z "${Source_Inst}" ] && syntax || [ -z "${Target_Inst}" ] && syntax || [ -z "${DBName}" ] && syntax


ShellName="$(echo $0|awk -F / '{print $NF}')"
WorkDir="$(echo $0|sed s/${ShellName}//g)"
[ -z "${WorkDir}" ] && WorkDir=$(pwd);cd ${WorkDir};WorkDir=$(pwd)

LogFile="${WorkDir}/logs/DB2_Tablook.log"

if [ ! -f ${LogFile} ]
then
     touch ${LogFile} || LogFile="/dev/null"
     [ "${LogFile}" != "/dev/null" ] && [ -f ${LogFile} ] && chmod 666 ${LogFile}
fi

f_printInfo ">>>>> $(date "+%Y%m%d.%H%M%S") <<<<< "

## change file target to /home/dbmonusr
_dbmonusrPath="/home/dbmonusr"
_dbmonusrFullPath_S="/opsw/Server/@/${Source_Host}/files/root${_dbmonusrPath}"
_dbmonusrFullPath_T="/opsw/Server/@/${Target_Host}/files/root${_dbmonusrPath}"

_TgtWorkPath=""
_TgtFullPath_S="/opsw/Server/@/${Source_Host}/files/root"
_TgtFullPath_T="/opsw/Server/@/${Target_Host}/files/root"


if [ -d "${_dbmonusrFullPath_S}" ]; then
   _TgtWorkPath_S="${_dbmonusrPath_S}/autocdc"
   _TgtFullPath_S="${_TgtFullPath_S}${_TgtWorkPath_S}"
else
   _TgtWorkPath_S="/tmp/autocdc"
   _TgtFullPath_S="${_TgtFullPath_S}${_TgtWorkPath_S}"
fi

if [ ! -d "${_TgtFullPath_S}" ]; then
   mkdir -p  "${_TgtFullPath_S}"
fi

chmod 777 ${_TgtFullPath_S}

if [ -d "${_dbmonusrFullPath_T}" ]; then
   _TgtWorkPath_S="${_dbmonusrPath_T}/autocdc"
   _TgtFullPath_S="${_TgtFullPath_T}${_TgtWorkPath_T}"
else
   _TgtWorkPath_S="/tmp/autocdc"
   _TgtFullPath_S="${_TgtFullPath_T}${_TgtWorkPath_T}"
fi

if [ ! -d "${_TgtFullPath_T}" ]; then
   mkdir -p  "${_TgtFullPath_T}"
fi

chmod 777 ${_TgtFullPath_T}

ScriptName="/home/ggroot/db2/cmb_cdc_db2_tablook.sh"

if [ ! -f ${ScriptName} ]; then
   f_printError " Did not find the file \"${ScriptName}\" "
   exit -1
else
   f_printInfo " cp ${ScriptName} ${_TgtFullPath_S} "
   cp "${ScriptName}" "${_TgtFullPath_S}"
   f_printInfo " cp ${ScriptName} ${_TgtFullPath_T} "
   cp "${ScriptName}" "${_TgtFullPath_T}"
   ScriptName=$( echo ${ScriptName} | awk -F'/' '{print $NF}' )
   chmod 777 ${_TgtFullPath_S}/${ScriptName}
   chmod 777 ${_TgtFullPath_T}/${ScriptName}
fi

[ -z "${FileName}" ] && FilePath="${_dbmonusrPath}/autocdc"
[ -z "${FileName}" ] && FileName="${DBName}.DDL"

f_printInfo " get ${FileName} from source machine "
ParameterString="-ACTION GETDDL -DBNAME ${DBName} -FILEPATH ${FilePath} -FILENAME ${FileName}"
_ScriptName="${_TgtWorkPath_S}/${ScriptName} ${ParameterString}"
f_printInfo "/opsw/bin/rosh -l root -n ${Source_Host} su - ${Source_Inst} \"-c  sh ${_ScriptName}  \"  " | tee -a ${LogFile}
/opsw/bin/rosh -l root -n ${Source_Host} su - ${Source_Inst} "-c sh ${_ScriptName} "

f_printInfo "cp the ${FileName} file from source machine to target machine "
cp /opsw/Server/@/${Source_Host}/files/root/${FilePath}/${FileName} /opsw/Server/@/${Target_Host}/files/root/${FilePath}/${FileName}
if [ ! -f /opsw/Server/@/${Source_Host}/files/root/${FilePath}/${FileName}]; then
   f_printError " Did not find the ${DBName}.DDL file "
   exit -1
fi

f_printInfo "modifile ${DBName}.DDL file and run it in the target machine "
ParameterString="-ACTION MODIFYDDL -DBNAME ${DBName} -FILEPATH ${FilePath} -FILENAME ${FileName}"
_ScriptName="${_TgtWorkPath_T}/${ScriptName} ${ParameterString}"
f_printInfo "/opsw/bin/rosh -l root -n ${Target_Host} su - ${Target_Inst} \"-c  sh ${_ScriptName}  \"  " | tee -a ${LogFile}
/opsw/bin/rosh -l root -n ${Target_Host} su - ${Target_Inst} "-c sh ${_ScriptName} "
rc=$?
exit ${rc}
