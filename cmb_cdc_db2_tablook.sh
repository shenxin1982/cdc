#!/usr/bin/env ksh


function syntax
{
  echo "syntax:"
  echo " /usr/bin/su - <DB2InstUser> -c \"/usr/bin/sh <path>/cmb_cdc_db2_tablook.sh -ACTION <GETDDL|RUNDDL|MODIFYDDL> -DBNAME <DBName> -FILEPATH <FilePath> -FILENAME <FileName> \" "
  echo
  echo " where:"
  echo "   <DB2InstUser>   : is the owner of the DB2 instance."
  echo "   <path>          : is the full path to this script, normally"
  echo " Parameters: "
  echo "   -ACTION:        : three action to use as following:"
  echo "    <GETDDL>       : Run db2look to get DDL of specified database "
  echo "    <RUNDDL>       : Run the DDL file if database name does not changed "
  echo "    <MODIFYDDL>    : Modify DDL file if instance or database name changed, then run DDL file "
  echo "   -DBNAME         : Database name "
  echo "   -FILEPATH       : Specify path for the ddl file write to or read from; "
  echo "                     same path as the script if does not given the value"
  echo "   -FILENAME       : Specify name of the ddl file;"
  echo "                     default named as ${DBName}.ddl, if does not given the value"
  echo " Samples: "
  echo "   cmb_cdc_db2_tablook.sh -ACTION GETDDL -DBNAME testdb1 "
  echo "   cmb_cdc_db2_tablook.sh -ACTION MODIFYDDL -dbname testdb5 -filename testdb5.ddl"
  exit 22
}

function f_printError
{
  echo "[Error]:$(date "+%Y%m%d.%H%M%S"):$1" | tee -a ${LogFile} ;
}

function f_printWarning
{
  echo "[Warn ]:$(date "+%Y%m%d.%H%M%S"):$1"  | tee -a ${LogFile};
}

function f_printInfo
{
  echo "[Info ]:$(date "+%Y%m%d.%H%M%S"):$1"  | tee -a ${LogFile};
}


function f_db2lookDDL
{
   f_printInfo " Extract DDL of database ${DBName} "
   f_printInfo " db2look -d ${DBName} -e -l -noview -nofed -o ${DBName}.DDL "
   db2look -d ${DBName} -e -l -noview -nofed -o "${FilePath}/${FileName}" 2>&1 >> ${LogFile}
   rc=$?

   case ${rc} in
     0) f_printInfo " Successfull. The file \" ${FilePath}/${FileName} \" is generated. ";;
     *) f_printInfo " Failed!  RC=${rc} ";;
   esac

   return ${rc}
}

function f_executeDDL
{
   f_printInfo "  Run DDL file \"${FilePath}/${FileName}\" on database ${DBName} " ;

   db2 +c -tvf "${FilePath}/${FileName}"  2>&1 >> ${LogFile}
   rc=$?

   case ${rc} in
     0) db2 "commit" | tee -a ${LogFile}  ;   f_printInfo "    Successfully!!! " ;;
     *) db2 "rollback" | tee -a ${LogFile};   f_printError "   Failed!!! ";;
   esac

   return ${rc}
}



function f_modify_executeDDL
{
   f_printInfo " Modify the DDL ${FilePath}/${FileName} file first "

   _OldDDLFile="${FilePath}/${FileName}"
   _NewDDLFile="${FilePath}/${FileName}.new"
   [ -f ${_NewDDLFile} ] && rm -f ${_NewDDLFile}
   touch  ${_NewDDLFile}

  if [ ! -f ${_OldDDLFile} ]
  then
     f_printError " Can not find file ${_OldDDLFile} "
     return -1
  fi

  cat ${_OldDDLFile} |sed -n '1,/DDL Statements for User Defined Functions/p' > "${_NewDDLFile}"
  cat "${_NewDDLFile}" | sed -n '1,/DDL Statements for stored procedures/p'  > "${_NewDDLFile}_1"

  grep -i "connect to " ${_NewDDLFile}_1 |uniq > ${_NewDDLFile}
  grep -i "CREATE BUFFERPOOL" ${_NewDDLFile}_1 >> ${_NewDDLFile}

  grep "TABLESPACE" ${_NewDDLFile}_1 |grep "CREATE"|sed 's/[ ]*\(CREATE .* TABLESPACE .*\) IN DATABASE .*/\1;/' >> ${_NewDDLFile}
  cat ${_NewDDLFile}_1 |sed -n '/DDL Statements for Table/,$p' >> ${_NewDDLFile}

  cat ${_NewDDLFile} |sed -n '1,/COMMIT WORK;/p' > ${_NewDDLFile}_1

  cat ${_NewDDLFile}_1 |sed 's/COMMIT WORK;//' > ${_NewDDLFile}

  f_printInfo " Run DDL file ${_NewDDLFile} "
  db2 +c  -tvf "${_NewDDLFile}" 2>&1 >> ${LogFile}

  rc=$( echo $(cat ${LogFile} | awk '/DB21034E||SQL2314W||SQL0958W/' | wc -l) | sed 's/^[][ ]*//g' )

  case ${rc} in
   0) db2 "commit"; f_printInfo "    Successfully!!! " ;;
   *) db2 "rollback";  f_printError "   Failed!!! " ;;
  esac

  return ${rc}
}

ShellName="$(echo $0|awk -F / '{print $NF}')"
WorkDir="$(echo $0|sed s/${ShellName}//g)"
[ -z "${WorkDir}" ] && WorkDir=$(pwd);cd ${WorkDir};WorkDir=$(pwd)

typeset ShellOption="$@"

HostName=$(hostname);UserName=$(whoami);StartTime=$(date '+%Y%m%d.%H%M%S');

for inopt in ${ShellOption}
do
  case $(echo $inopt|tr a-z A-Z) in
    -ACTION) CurOpt="-ACTION";continue;;
    -DBNAME) CurOpt="-DBNAME";continue;;
    -FILEPATH) CurOpt="-FILEPATH";continue;;
    -FILENAME) CurOpt="-FILENAME";continue;;
    -H|-*) syntax;return -1;;
  esac
  case "${CurOpt}" in
    -ACTION) Action=`echo ${inopt}| tr a-z A-Z`;;
    -DBNAME) DBName=`echo ${inopt}| tr a-z A-Z`;;
    -FILEPATH) FilePath="${inopt}";;
    -FILENAME) FileName=`echo ${inopt}| tr a-z A-Z`;;
  esac
done
[ -z "${DBName}" ] && syntax || [ -z "${Action}" ] && syntax


LogFile="/tmp/cmb_cdc_db2_tablook.log"


if [ ! -f ${LogFile} ]
then
     touch ${LogFile} || LogFile="/dev/null"
     [ "${LogFile}" != "/dev/null" ] && [ -f ${LogFile} ] && chmod 666 ${LogFile}
fi

f_printInfo ">>>>> $(date "+%Y%m%d.%H%M%S") <<<<< " > ${LogFile}

monuserhome="$( cat /etc/passwd | grep -i dbmonusr | awk -F ':' {' print $6'} )"
if [ ! -z ${monuserhome} ]; then
  [ -d "${monuserhome}/autocdc" ] && FilePath="${monuserhome}/autocdc"
else
  [ -z "${FilePath}" ] && FilePath="${WorkDir}"
fi

[ -z "${FileName}" ] && FileName="${DBName}.DDL"


rc=0

case ${Action} in
  GETDDL) f_db2lookDDL;;
  RUNDDL) f_executeDDL;;
  MODIFYDDL) f_modify_executeDDL;;
esac

exit ${rc}
