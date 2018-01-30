#!/usr/bin/env ksh

function syntax
{
  echo "syntax:"
  echo " /usr/bin/su - <instusr> -c \"/usr/bin/sh <path>/cmb_cdc_db2_dbinit.sh -ACTION <CREATE/DROP> -DBNAME <DBName> -DBCODEPAGE <DBCodePage> -DBTERRITORY <DBTerritory> -DBPAGESIZE <DBPageSize> "
  echo
  echo " where:"
  echo "   <instuser>          : is the instance user "
  echo "   <path>          : is the full path to this script, normally"
  echo " Parameters:"
  echo "   <Action>        : "
      "         CREATE     :create database"
      "         DROP       :drop database "
  echo "   -DBName       : The Name of Database"
  echo "   -DBCODEPAGE   : The codepage for Database "
  echo "   -DBTERRITORY  : The territory for database "
  echo "   -DBPAGESIZE   : The PAGESIZE of Database  "
  echo
  echo " Samples: "
  echo "   cmb_cdc_db2_dbinit.sh -ACTION create -dbname testdb -dbcodepage 1208 -dbterritory us -dbpagesize 4 "
  echo "   cmb_cdc_db2_dbinit.sh -ACTION drop -dbname testdb"
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


function f_crtdb
{
  retcode=0
  ##-------------------------------------------------------------------------
  ##DBCodePage(819|1386|1208)
  case ${DBCodePage} in
   819) DBCodeSet="ISO8859-1";;
   1386) DBCodeSet="GBK";;
   1208) DBCodeSet="UTF-8";;
   *) f_printError "CodePage must be 819|1386|1208";;
  esac
  ##-------------------------------------------------------------------------
  ##DBTerritory(CN|US)
  case "${DBTerritory}" in
   CN|US) DBTerritory="$(echo ${DBTerritory}|tr a-z A-Z)";;
   *) f_printError "Territory must be CN|US";;
  esac
  ##-------------------------------------------------------------------------
  ##DBPageSize(32|16|8|4)
  case "${DBPageSize}" in
   32|16|8|4) typeset -i DBPageSizeByte=$((DBPageSize*1024));;
   *) f_printError "PageSize must be 32|16|8|4";;
  esac

  ##-------------------------------------------------------------------------
  typeset _SqlCmd="CREATE DATABASE ${DBName} USING CODESET ${DBCodeSet} TERRITORY ${DBTerritory} PAGESIZE ${DBPageSizeByte}"
  f_printInfo "db2 -v \"${_SqlCmd}\""
  _Output=$(db2 -ec "${_SqlCmd}");typeset -i _SqlCode=$(echo "${_Output}"|tail -1);
  if [ ${_SqlCode} -eq 0 ]
  then
    db2 -v "terminate"|tee -a ${LogFile}
    db2 -v "connect to ${DBName}"|tee -a ${LogFile}
    db2 -v "drop tablespace SYSTOOLSPACE"|tee -a ${LogFile}
    db2 -v "terminate"|tee -a ${LogFile}
    retcode=0
  else
    f_printError "${_Output}"
    retcode=1
  fi
  return ${retcode}
}

function f_forceappl
{
  f_printInfo " db2 force applications"
  _applcount=`db2 list applications|grep -iw ${DBName}|wc -l`
  while [ $_applcount -ne 0 ]
  do
  db2 "list applications"|grep -iw "${DBName}"|awk '{print $3}'| while read agentid
    do
    db2 -v "force application (${agentid})"| tee -a ${LogFile}
    done
  _applcount=`db2 list applications|grep -iw ${DBName}|wc -l`
  sleep 3
  done
  db2 deactivate db ${_dbname}
}

function f_dropdb
{
  retcode=0
  f_printInfo " Start DB2 first ... "
  db2start 2>&1 | tee -a ${LogFile}
  _dbname="$(db2 list db directory | grep 'Database name'|grep -i ${DBName} | awk '{print $NF}')"
  [ -z ${_dbname} ] && f_printWarning " There is no DATABASE need to be droped." && return ${retcode};

  f_forceappl

  f_printInfo "  db2 drop database ${_dbname} "
  db2 drop database ${_dbname} 2>&1 >> ${LogFile}
  retcode=$?
  if [ ${retcode} -ne 0 ]
  then
    f_printError " Failed!!! " | tee -a ${LogFile}
      return ${retcode}
  else
    f_printInfo "  Successfully!!! " | tee -a ${LogFile}
  fi
  return ${retcode}
}


typeset ShellOption="$@"
for inopt in ${ShellOption}
do
  case $(echo $inopt|tr a-z A-Z) in
    -ACTION) CurOpt="-ACTION";continue;;
    -DBNAME) CurOpt="-DBNAME";continue;;
    -DBCODEPAGE) CurOpt="-DBCODEPAGE";continue;;
    -DBTERRITORY) CurOpt="-DBTERRITORY";continue;;
    -DBPAGESIZE) CurOpt="-DBPAGESIZE";continue;;
    -H|-*) syntax;return -1;;
  esac
  case "${CurOpt}" in
    -ACTION) Action=`echo ${inopt}| tr a-z A-Z`;;
    -DBNAME) DBName=`echo ${inopt}| tr a-z A-Z`;;
    -DBCODEPAGE) DBCodePage="${inopt}";;
    -DBTERRITORY) DBTerritory=`echo ${inopt}| tr a-z A-Z`;;
    -DBPAGESIZE) DBPageSize="${inopt}";;
  esac
done

[ -z "${Action}" ] && syntax || [ -z "${DBName}" ] && syntax
[ -z "${DBCodePage}" ] && DBCodePage=1386
[ -z "${DBTerritory}" ] && DBTerritory=CN
[ -z "${DBPageSize}" ] && DBPageSize=32

ShellName="$(echo $0|awk -F / '{print $NF}')"
WorkDir="$(echo $0|sed s/${ShellName}//g)"
[ -z "${WorkDir}" ] && WorkDir=$(pwd);cd ${WorkDir};WorkDir=$(pwd)
HostName=$(hostname);UserName=$(whoami);StartTime=$(date '+%Y%m%d.%H%M%S');
LogFile="${WorkDir}/cmb_cdc_db2_dbinit.log.${StartTime}"

if [ ! -f ${LogFile} ]
then
     touch ${LogFile} || LogFile="/dev/null"
     [ "${LogFile}" != "/dev/null" ] && [ -f ${LogFile} ] && chmod 666 ${LogFile}
fi

rc=0

case ${Action} in
  CREATE) f_crtdb;;
  DROP) f_dropdb;;
esac

exit ${rc}
