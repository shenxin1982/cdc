#!/usr/bin/env ksh


function syntax
{
  echo "syntax:"
  echo " /usr/bin/su - <cdcuser> -c \"/usr/bin/sh <path>/cmb_cdc_db2_catadb.sh  -ACTION <catalog|uncatalog> -DBALIAS <DBAlias> -DBHOST <DBHost> -DBPORT <DBPort> -DBNAME <DBName> -INSTNAME <InstName>\" "
  echo
  echo " where:"
  echo "   <cdcuser>   : is the owner of the CDC."
  echo "   <path>      : is the full path to this script, normally"
  echo " Parameters: "
  echo "   <Action>      : catalog | uncatalog  "
  echo "   <DBAlias>   : one of following value, SRC_<DBNAME>; TGT_<DBNAME>"
  echo "   <DBHost>    : the hostname of <DBName> existing "
  echo "   <DBPort>    : the service port of database "
  echo "   <INSTNAME>    :must be one of following value: srcinst1(v9.7 clinet),tgtinst1(v10.5 client) "
  echo " Sample: "
  echo "   cmb_cdc_db2_catadb.sh -ACTION catalog -DBALIAS src_sample -DBHOST dbserver.cmb.com -DBPORT 50000 -DBNAME SAMPLE -INSTNAME v97inst1"
  echo "   cmb_cdc_db2_catadb.sh -ACTION uncatalog -DBALIAS src_sample"
  exit 22
}

function f_printError
{
  echo "[Error]:$(date "+%Y%m%d.%H%M%S"):$1" ;
}

function f_printWarning
{
  echo "[Warn ]:$(date "+%Y%m%d.%H%M%S"):$1" ;
}

function f_printInfo
{
  echo "[Info ]:$(date "+%Y%m%d.%H%M%S"):$1" ;
}


function f_db2profile
{
  echo " f_db2profile "
  _Db2Profile="$(cat /etc/passwd | grep -i "${InstName}" | awk -F ':' '{print $6}')/sqllib/db2profile"
  echo ${_Db2Profile}

  if [ ! -f ${_DB2Profile} ]; then
    f_printError " Did not find the file ${_Db2Profile} " | tee -a ${LogFile}
    rc=-1
    return ${rc}
  fi

  f_printInfo " Apply following db2profile to cdcuser " | tee -a ${LogFile}
  f_printInfo "    \". ${_Db2Profile}\"   " | tee -a ${LogFile}
  . ${_Db2Profile} 2>&1 >> ${LogFile}
  rc=$?

  f_printInfo " The db2level is : " | tee -a ${LogFile}
  db2level | tee -a ${LogFile}

  return ${rc}
}

function f_catalog
{
  f_printInfo "catalog tcpip node ${NodeName} remote ${DBHost} server ${DBPort}" | tee -a ${LogFile}
  db2 "catalog tcpip node ${NodeName} remote ${DBHost} server ${DBPort}"  2>&1 >> ${LogFile}
  rc=$?
  if [ ${rc} -ne 0 ]; then
    f_printError " Failed catalog node ${NodeName}.  "  | tee -a ${LogFile}
  else
    f_printInfo " Successfully catalog node ${NodeName}. " | tee -a ${LogFile}
    f_printInfo "catalog db ${DBName} as ${DBAlias} at node ${NodeName}" | tee -a ${LogFile}
    db2 "catalog db ${DBName} as ${DBAlias} at node ${NodeName}"  2>&1 >> ${LogFile}
    rc=$?
    if [ ${rc} -ne 0 ]; then
      f_printError " Failed catalog db ${DBName}. " | tee -a ${LogFile}
    else
      f_printInfo " Successfully catalog db ${DBName}. " | tee -a ${LogFile}
    fi
  fi
  return ${rc}
}

function f_uncatalog
{
  f_printInfo "uncatalog db ${DBAlias} " | tee -a ${LogFile}
  db2 "uncatalog db ${DBAlias} "  2>&1 >> ${LogFile}
  rc=$?
  if [ $? -ne 0 ]; then
    f_printError " Failed uncatalog db ${DBAlias}. " | tee -a ${LogFile}
    return -1
  else
    f_printInfo "uncatalog node ${NodeName}"   | tee -a ${LogFile}
    db2 "uncatalog node ${NodeName}"  2>&1 >> ${LogFile}
    if [ $? -ne 0 ]; then
      f_printError " Failed uncatalog node ${NodeName}." | tee -a ${LogFile}
      return -1
    fi
  fi
}


typeset ShellOption="$@"

for inopt in ${ShellOption}
do
  case $(echo $inopt|tr a-z A-Z) in
    -ACTION) CurOpt="-ACITION";continue;;
    -DBALIAS) CurOpt="-DBALIAS";continue;;
    -DBHOST) CurOpt="-DBHOST";continue;;
    -DBPORT) CurOpt="-DBPORT";continue;;
    -DBNAME) CurOpt="-DBNAME";continue;;
    -INSTNAME) CurOpt="-INSTNAME";continue;;
    -H|-*) syntax;return -1;;
  esac
  case "${CurOpt}" in
    -ACITION) Action=`echo ${inopt}| tr a-z A-Z`;;
    -DBALIAS) DBAlias=`echo ${inopt}| tr a-z A-Z`;;
    -DBHOST) DBHost="${inopt}";;
    -DBPORT) DBPort="${inopt}";;
    -DBNAME) DBName="${inopt}";;
    -INSTNAME) InstName="${inopt}";;
  esac
done

[ -z "${DBAlias}" ] && syntax || [ -z "${Action}" ] && syntax


NodeName="N_${DBAlias}"
ShellName="$(echo $0|awk -F / '{print $NF}')"
WorkDir="$(echo $0|sed s/${ShellName}//g)"
[ -z "${WorkDir}" ] && WorkDir=$(pwd);cd ${WorkDir};WorkDir=$(pwd)
StartTime=$(date '+%Y%m%d.%H%M%S');

LogFile="${WorkDir}/cmb_cdc_cdc_catadb.log.${StartTime}"

if [ ! -f ${LogFile} ]
then
     touch ${LogFile} || LogFile="/dev/null"
     [ "${LogFile}" != "/dev/null" ] && [ -f ${LogFile} ] && chmod 666 ${LogFile}
fi

rc=0
f_db2profile
[ $? -ne 0 ] && exit -1

case ${Action} in
  CATALOG) f_catalog;;
  UNCATALOG) f_uncatalog;;
esac

exit ${rc}
