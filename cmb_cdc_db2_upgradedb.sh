#!/usr/bin/env ksh

function syntax
{
  echo "syntax:"
  echo " /usr/bin/su - <root> -c \"/usr/bin/sh <path>/cmb_cdc_db2_upgradedb.sh -DBLEVEL <DBLevel> -DBINST <DBInstUser> -V97PATH <V97path> -V105PATH <V105path>\" "
  echo
  echo " where:"
  echo "   <path>          : is the full path to this script, normally"
  echo " Parameters: "
  echo "   <DBName>     : Name of the database "
  echo "   <DBLEVEL>    : v10.5 or v9.7."
  echo "   <V97path>    : DB2 V9.7 Product install path."
  echo "   <V105path>   : DB2 V10.5 Product install path."
  echo " Samples: "
  echo "   cmb_cdc_db2_upgradedb.sh -DBLEVEL v10.5 -DBINST srcinst1 -V97PATH /opt/IBM/db2/V9.7 -V105PATH /opt/IBM/db2/V10.5"
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


function f_delupgradefiles
{
   f_printInfo " remove directories like sqllib_v9 " | tee -a ${LogFile}
   su - ${DBInstUser} -c "find ~/ -type d -name "sqllib_v91" -exec rm -rf {} \;" | tee -a ${LogFile}
   su - ${DBInstUser} -c "find ~/ -type d -name "sqllib_v95" -exec rm -rf {} \;" | tee -a ${LogFile}
   su - ${DBInstUser} -c "find ~/ -type d -name "sqllib_v97" -exec rm -rf {} \;" | tee -a ${LogFile}
   su - ${DBInstUser} -c "find ~/ -type f -name "upgrade.log" -exec rm -rf {} \;" | tee -a ${LogFile}
}


function f_upgrade97
{
   f_printInfo "  Upgrade DB2 Instance to V9.7 " | tee -a ${LogFile}
   rc=0

  _InstallDir=${V97path}
  if [ ! -d "${_InstallDir}" ]
  then
      f_printError " It seems DB2 V9.7 was not installed in /opt/IBM/db2 " | tee -a ${LogFile}
      rc=-1
      return ${rc}
  fi

  f_printInfo " Stop DB2 first ... " | tee -a ${LogFile}
  su -  ${DBInstUser} -c "db2stop force" 2>&1 | tee -a ${LogFile}
  f_printInfo "${_InstallDir}/instance/db2iupgrade ${DBInstUser} " | tee -a ${LogFile}
  ${_InstallDir}/instance/db2iupgrade ${DBInstUser}
  rc=$?

  case ${rc} in
    0) f_printInfo "  Successfully!!! " | tee -a ${LogFile};;
    *) f_printError "  Failed!!! " | tee -a ${Logfile};;
  esac

  return ${rc}
}

function f_upgrade10a
{
   f_printInfo "  Upgrade DB2 Instance to V10 or above" | tee -a ${LogFile}
   rc=0

  _InstallDir=${V105path}

  if [ ! -d "${_InstallDir}" ]
  then
      f_printError " It seems DB2 V10 or above version was not installed in /opt/IBM/db2 " | tee -a ${LogFile}
      rc=-1
      return ${rc}
  fi

  f_printInfo " Stop DB2 first ... " | tee -a ${LogFile}
  su -  ${DBInstUser} -c "db2stop force" 2>&1 | tee -a ${LogFile}
  f_printInfo "${_InstallDir}/instance/db2iupgrade ${DBInstUser} " | tee -a ${LogFile}
  ${_InstallDir}/instance/db2iupgrade ${DBInstUser}
  rc=$?


  case ${rc} in
    0) f_printInfo "  Successfully!!! " | tee -a ${LogFile};;
    *) f_printError "  Failed!!! " | tee -a ${Logfile};;
  esac

  return ${rc}
}

function f_upgradedatabase
{
   rc=0
   f_printInfo " Start DB2 first ... " | tee -a ${LogFile}
   su -  ${DBInstUser} -c "db2start" | tee -a ${LogFile}

   _dbList="$(su - ${DBInstUser} -c db2 list db directory | grep 'Database name' | awk '{print $NF}')"
   [ -z ${_dbList} ] && f_printWarning " There is no DATABASE need to be upgraded." | tee -a ${LogFile} && return ${rc};

   for _dbname in ${_dbList}
   do
     su - ${DBInstUser} -c db2 terminate
     _tmpDBVersion=`su - ${DBInstUser} -c db2 connect to ${_dbname}`
     if [ -z "$(echo ${_tmpDBVersion} | awk /SQL5035N/)" ]
     then
        f_printInfo " Database ${_dbname} 's level is same as instance, ignore upgrade it" | tee -a ${LogFile}
     else
        f_printInfo "  db2 upgrade database ${_dbname} " | tee -a ${LogFile}
        su - ${DBInstUser} -c db2 upgrade database ${_dbname} 2>&1 >> ${LogFile}
        rc=$?
        if [ ${rc} -ne 0 ]
        then
           f_printError " Failed!!! " | tee -a ${LogFile}
           return ${rc}
        else
           f_printInfo "  Successfully!!! " | tee -a ${LogFile}
           f_printInfo " Start Bind ... " | tee -a ${LogFile}
           su - ${DBInstUser} -c "db2 terminate; cd ~/sqllib/bnd; db2 connect to ${_dbname}; db2 bind db2schema.bnd BLOCKING ALL GRANT PUBLIC SQLERROR CONTINUE; db2 terminate" | tee -a ${LogFile}
           su - ${DBInstUser} -c "db2 terminate; cd ~/sqllib/bnd; db2 connect to ${_dbname}; db2 bind @db2ubind.lst BLOCKING ALL GRANT PUBLIC ACTION REPLACE; db2 terminate" | tee -a ${LogFile}
           su - ${DBInstUser} -c "db2 terminate; cd ~/sqllib/bnd; db2 connect to ${_dbname}; db2 bind @db2cli.lst BLOCKING ALL GRANT PUBLIC ACTION REPLACE; db2 terminate " | tee -a ${LogFile}
           su - ${DBInstUser} -c "db2 terminate; db2rbind ${_dbname} -l db2rbind.log"
           rc=$?
        fi
     fi
   done

   return ${rc}
}


function f_upgrade
{
   rc=0
   f_printInfo " upgrade DB2 Instance ... " | tee -a ${LogFile}

   f_printInfo " Make sure there is no applications running on the instance " | tee -a ${LogFile}

   _AppList="$(su - ${DBInstUser} -c db2 list applications )"
   if [ ! -z "${_AppList}" ] && [ -z $(echo ${_AppList} | awk '/SQL1611W/') ]
   then
     f_printError "   There are applications running  on the instance. Upgrade operation was CANCELED. " | tee -a ${LogFile}
     rc=-1
     return ${rc}
   fi

   _tmpLevel=$(su - ${DBInstUser} -c "db2level" | grep "Product is installed" | awk -F '/' '{print $NF}')
   if [ ! -z "$(echo ${_tmpLevel} | awk /${DBLevel}/)" ]
   then
     f_printInfo "  Current DB2 Level is ${_tmpLevel}, same as expected Level ${DBLevel}. Do not need upgrade DB2 instance " | tee -a ${LogFile}
     f_upgradedatabase
     rc=$?
     return ${rc}
   fi

   if [ ! -z $(echo ${_tmpLevel} | awk '/9.1/') ]
   then
      _origDBLevel="V9.1"

   elif [ ! -z $(echo ${_tmpLevel} | awk '/9.5/') ]
   then
      _origDBLevel="V9.5"

   elif [ ! -z $(echo ${_tmpLevel} | awk '/9.7/') ]
   then
      _origDBLevel="V9.7"

   elif [ ! -z $(echo ${_tmpLevel} | awk '/10.5/') ]
   then
      _origDBLevel="V10.5"

   else
      _origDBLevel="unknown"
   fi

   if [ -z $(echo ${DBLevel} | awk '/[0-9]*.[0-9]*/') ]
   then
     f_printError " Value of DBLEVEL is not correct " | tee -a ${LogFile}
     rc=-1
     return ${rc}
   fi
   _newDBLevel="${DBLevel%%.*}"

   f_delupgradefiles

   case ${_origDBLevel} in
     V9.1|V9.5)case ${_newDBLevel} in
            V9) f_upgrade97;rc=$?;
                [ ${rc} -eq 0 } ] && f_upgradedatabase;;
            *) f_upgrade97; rc=$?;
                [ ${rc} -eq 0 ] && f_upgradedatabase;rc=$?;
                 [ ${rc} -eq 0 ] && f_upgrade10a;rc=$?
                  [ ${rc} -eq 0 ] && f_upgradedatabase;;
          esac;;

     V9.7) f_upgrade10a;rc=$?
           [ ${rc} -eq 0 ] && f_upgradedatabase;;
     *) f_printWarning " Current DB Level is ${_origDBLevel}, does not support. " | tee -a ${LogFile};;
   esac

   return ${rc}
}


typeset ShellOption="$@"

for inopt in ${ShellOption}
do
  case $(echo $inopt|tr a-z A-Z) in
    -DBLEVEL) CurOpt="-DBLEVEL";continue;;
    -DBINST) CurOpt="-DBINST";continue;;
    -V97PATH) CurOpt="-V97PATH";continue;;
    -V105PATH) CurOpt="-V105PATH";continue;;
    -H|-*) syntax;return -1;;
  esac
  case "${CurOpt}" in
    -DBLEVEL) DBLevel=`echo ${inopt}| tr a-z A-Z`;;
    -DBINST) DBInstUser="${inopt}";;
    -V97PATH) V97path="${inopt}";;
    -V105PATH) V105path="${inopt}";;
  esac
done

[ -z "${DBInstUser}" ] && syntax || [ -z "${V105path}" ] && syntax || [ -z "${DBLevel}" ] && syntax


ShellName="$(echo $0|awk -F / '{print $NF}')"
WorkDir="$(echo $0|sed s/${ShellName}//g)"
[ -z "${WorkDir}" ] && WorkDir=$(pwd);cd ${WorkDir};WorkDir=$(pwd)
StartTime=$(date '+%Y%m%d.%H%M%S');

LogFile="${WorkDir}/cmb_cdc_db2_upgradedb.log.${StartTime}"


if [ ! -f ${LogFile} ]
then
     touch ${LogFile} || LogFile="/dev/null"
     [ "${LogFile}" != "/dev/null" ] && [ -f ${LogFile} ] && chmod 666 ${LogFile}
fi

f_printInfo ">>>>> $(date "+%Y%m%d.%H%M%S") <<<<< " > ${LogFile}

rc=0

f_upgrade

exit ${rc}
