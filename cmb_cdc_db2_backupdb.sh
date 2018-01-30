#!/usr/bin/env ksh

function syntax
{
  echo "syntax:"
  echo
  echo " /usr/bin/su - <InstName> -c \"/usr/bin/sh <path>/cmb_cdc_db2_backupdb.sh -ACTION <Action> -DBNAME <DBName> -FILEPATH <FilePath>"
  echo " "
  echo " where:"
  echo "   <InstName>    : is the owner of the DB2 instance."
  echo "   <path>        : is the full path to this script, normally"
  echo " Parameters: "
  echo "   <Action>     : ONLINE / OFFLINE "
  echo "   <DBName>     : Name of the database "
  echo "   <FilePath>   : Backup image path "
  echo
  echo " Example: "
  echo "   cmb_cdc_db2_backupdb.sh -ACTION OFFLINE -DBNAME testdb1 -FILEPATH /tmp"
  echo "   cmb_cdc_db2_backupdb.sh -ACTION ONLINE -DBNAME testdb1 -FILEPATH /tmp"
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


function f_backupOffline
{
   f_printInfo "  Backup database offline begin ... " | tee -a ${LogFile}

   if [ ! -z "$(db2 list active databases | awk /${DBName}/)" ]; then
      f_printError "    Failed!!!  Database ${DBName} is still active " | tee -a ${LogFile}
      rc=-1
      return ${rc}
   fi

   f_printInfo "   db2 backup database ${DBName} to ${FilePath} " | tee -a ${LogFile}
   db2 backup database ${DBName} to ${FilePath} 2>&1 >> ${LogFile}  &
   _OfflinePID=$!
   wait ${_OfflinePID}
   rc=$?

   case ${rc} in
     0) f_printInfo "    Successfully!!!   " | tee -a ${LogFile};;
     *) f_printError "   Failed!!!  " | tee -a ${LogFile};;
   esac

   return ${rc}
}

function f_backupOnline
{
   f_printInfo "  Backup database online begin ... " | tee -a ${LogFile}

   f_printInfo " db2 backup database ${DBName} online to ${FilePath} " | tee -a ${LogFile}
   db2 backup database ${DBName} online to ${FilePath} 2>&1 >> ${LogFile}  &
   _OnlinePID=$!
   wait ${_OnlinePID}
   rc=$?

   case ${rc} in
     0) f_printInfo "    Successfully!!!   " | tee -a ${LogFile};;
     *) f_printError "   Failed!!!  " | tee -a ${LogFile};;
   esac
   cd ${FilePath}
   ls -l ${FilePath}| grep ${DBName} | awk '{print $NF}' |xargs chmod o+r

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
    -ACTION) CurOpt="-ACTION";;
    -DBNAME) CurOpt="-DBNAME";;
    -FILEPATH) CurOpt="-FILEPATH";continue;;
    -H|-*) syntax;return -1;;
  esac
  case "${CurOpt}" in
    -ACTION) Action=`echo ${inopt}| tr a-z A-Z`;;
    -DBNAME) DBName=`echo ${inopt}| tr a-z A-Z`;;
    -FILEPATH) FilePath="${inopt}";;
  esac
done
[ -z "${DBName}" ] && syntax || [ -z "${Action}" ] && syntax
[ -z "${FilePath}" ] && FilePath="${WorkDir}"

LogFile="${WorkDir}/cmb_cdc_db2_backupdb.log.${StartTime}"

if [ ! -f ${LogFile} ]
then
  touch ${LogFile} || LogFile="/dev/null"
  [ "${LogFile}" != "/dev/null" ] && [ -f ${LogFile} ] && chmod 666 ${LogFile}
fi

rc=0

case ${Action} in
  OFFLINE) f_backupOffline;;
  ONLINE) f_backupOnline;;
  *) f_printError "Error input action";;
esac

exit ${rc}
