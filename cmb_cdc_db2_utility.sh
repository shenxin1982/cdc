#!/usr/bin/env ksh

function syntax
{
  echo "syntax:"
  echo " /usr/bin/su - <DB2InstUser> -c \"/usr/bin/sh <path>/cmb_cdc_db2_utility.sh -ACTION <Action> -DBNAME <DBName> \" "
  echo
  echo " where:"
  echo "   <DB2InstUser>   : is the owner of the DB2 instance."
  echo "   <path>          : is the full path to this script, normally"
  echo " Parameters: "
  echo "   -Action         "
  echo "         ARCHIVELOG  : archive log manually "
  echo "         GETTIME    : Get the current time for database "
  echo "         GETVERSION : Get the db version "
  echo "   -DBName          : Name of the database "
  echo
  echo " Samples: "
  echo "   cmb_cdc_db2_utility.sh -ACTION archivelog -DBNAME testdb1 "
  echo "   cmb_cdc_db2_utility.sh -ACTION gettime  -DBNAME testdb1 "
  echo "   cmb_cdc_db2_utility.sh -ACTION getversion -DBNAME testdb1 "
  echo
  exit 22
}

function f_printError
{
  echo "[Error]:$(date "+%Y%m%d.%H%M%S"):$1"|tee -a ${LogFile} ;
}

function f_printWarning
{
  echo "[Warn ]:$(date "+%Y%m%d.%H%M%S"):$1"|tee -a ${LogFile} ;
}

function f_printInfo
{
  echo "[Info ]:$(date "+%Y%m%d.%H%M%S"):$1"|tee -a ${LogFile} ;
}



function f_gettime
{
   rc=0
   f_printInfo " Get time from databae "
   db2 -x connect to ${DBName} 2>&1 >> /dev/null
   _timestamp=$(db2 -x "values(current timestamp)")
   db2 connect reset 2>&1 >> /dev/null
   _curdate=$(date '+%Y-%m-%d')

   _tmpdate="$(echo ${_timestamp%-*})"

   if [ "${_tmpdate}" == "${_curdate}" ]
   then
      f_printInfo "  DBTimeStamp=${_timestamp} "
   else
      f_printError " Timestamp from DB is '${_timestamp}', but current date is '${_curdate}' "
      rc=-1
   fi

   return ${rc}
}

function f_archivelog
{
   f_printInfo "  Run archive command on database ${DBName} " ;
   f_printInfo "   db2 archive log for database ${DBName} " ;
   db2 archive log for database ${DBName} >> ${LogFile}
   rc=$?

   case ${rc} in
     0) f_printInfo "    Successfully!!! " ;;
     *) f_printError "   Failed!!! " ;;
   esac

   return ${rc}
}

function f_getversion
{
   f_printInfo "  Get DB2 version of the instance ${InstName} "

   _prodInstPath=$(db2level | grep "Product is installed at" | awk -F '"' '{print $2}')
   _prodInstDir=$( echo ${_prodInstPath} | awk -F '/' '{print $NF}')

   f_printInfo "  DB2LEVEL=${_prodInstDir}" | tee -a ${LogFile}

   return 0
}

ShellName="$(echo $0|awk -F / '{print $NF}')"
WorkDir="$(echo $0|sed s/${ShellName}//g)"
[ -z "${WorkDir}" ] && WorkDir=$(pwd);cd ${WorkDir};WorkDir=$(pwd)
HostName=$(hostname);UserName=$(whoami);StartTime=$(date '+%Y%m%d.%H%M%S');

typeset ShellOption="$@"

for inopt in ${ShellOption}
do
  case $(echo $inopt|tr a-z A-Z) in
    -ACTION) CurOpt="-ACTION";continue;;
    -DBNAME) CurOpt="-DBNAME";continue;;
    -H|-*) syntax;return -1;;
  esac
  case "${CurOpt}" in
    -ACTION) Action=`echo ${inopt}| tr a-z A-Z`;;
    -DBNAME) DBName=`echo ${inopt}| tr a-z A-Z`;;
  esac
done
[ -z "${Action}" ] && syntax || [ -z "${DBName}" ] && syntax

LogFile="${WorkDir}/cmb_cdc_db2_utility.log.${StartTime}"

if [ ! -f ${LogFile} ]
then
  touch ${LogFile} || LogFile="/dev/null"
  [ "${LogFile}" != "/dev/null" ] && [ -f ${LogFile} ] && chmod 666 ${LogFile}
fi

rc=0

case ${Action} in
  GETTIME) f_gettime;;
  ARCHIVELOG) f_archivelog;;
  GETVERSION) f_getversion;;
esac

exit ${rc}
