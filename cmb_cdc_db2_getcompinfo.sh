#!/usr/bin/env ksh

function syntax
{
  echo "syntax:"
  echo "/usr/bin/su - <instuser> -c /usr/bin/sh <path>/cmb_cdc_db2_getcompinfo.sh -HOSTTYPE <HostType> -DBNAME <DBName> -INSTNAME <InstName>"
  echo
  echo " executed by inst user"
  echo " where:"
  echo "   <path>          : is the full path to this script, normally"
  echo " Parameters: "
  echo "   <DBName>       : Name of the database "
  echo "   <InstName>     : Name of the instance "
  echo "   <HostType>      : must be source or target "
  echo " Samples: "
  echo "   cmb_cdc_db2_getcompinfo.sh -HOSTTYPE source -DBNAME testdb -INSTNAME db2inst1"
  exit 22
}


typeset ShellOption="$@"
for inopt in ${ShellOption}
do
  case $(echo $inopt|tr a-z A-Z) in
    -DBNAME) CurOpt="-DBNAME";continue;;
    -INSTNAME) CurOpt="-INSTNAME";continue;;
    -HOSTTYPE) CurOpt="-HOSTTYPE";continue;;
    -H|-*) syntax;return -1;;
  esac
  case "${CurOpt}" in
    -DBNAME) DBName=`echo ${inopt}| tr a-z A-Z`;;
    -INSTNAME) InstName=`echo ${inopt}`;;
    -HOSTTYPE) HostType=`echo ${inopt}|tr a-z A-Z`;;
  esac
done

[ -z "${DBName}" ] && syntax || [ -z "${InstName}" ] && syntax || [ -z "${HostType}" ] && syntax


ShellName="$(echo $0|awk -F / '{print $NF}')"
WorkDir="$(echo $0|sed s/${ShellName}//g)"
[ -z "${WorkDir}" ] && WorkDir=$(pwd);cd ${WorkDir};WorkDir=$(pwd)

CompInfoFile=${WorkDir}/${InstName}.${DBName}.db2_compinfo.${HostType}
if [ ! -f ${CompInfoFile} ]
then
  touch ${CompInfoFile} && [ -f ${CompInfoFile} ] && chmod 666 ${CompInfoFile}
fi


##DB CFG INFO
DBCFG_Territory=$(db2 get db cfg for ${DBName}|grep -i "Database territory"|awk -F= '{print $2}')
DBCFG_CodePage=$(db2 get db cfg for ${DBName}|grep -i "Database code page "|awk -F= '{print $2}')
DBCFG_CodeSet=$(db2 get db cfg for ${DBName}|grep -i "Database code set "|awk -F= '{print $2}')

echo "DBCFG_Territory:${DBCFG_Territory}"|tee -a ${CompInfoFile}
echo "DBCFG_CodePage:${DBCFG_CodePage}"|tee -a ${CompInfoFile}
echo "DBCFG_CodeSet:${DBCFG_CodeSet}"|tee -a ${CompInfoFile}

##DB2SET INFO
DB2SET_CodePage=$(db2set -all|grep -i "DB2CODEPAGE"|awk -F= '{print $2}')
DB2SET_Territory=$(db2set -all|grep -i "DB2TERRITORY"|awk -F= '{print $2}')
echo "DB2SET_Territory:${DB2SET_Territory}"|tee -a ${CompInfoFile}
echo "DB2SET_CodePage:${DB2SET_CodePage}"|tee -a ${CompInfoFile}

##HOST Info
OS_Cpu_Numb=$(lsdev -Sa -Cc processor|awk 'END{print NR}')
echo "OS_Cpu_Numb:${OS_Cpu_Numb}"|tee -a ${CompInfoFile}
OS_Memory_Size=$(lsattr -El mem0 -a goodsize -F value)
echo "OS_Memory_Size:${OS_Memory_Size}"|tee -a ${CompInfoFile}
OS_Etc_Host_File=$(cat /etc/hosts|grep -v "#")
echo "OS_Etc_Host_File:"${OS_Etc_Host_File}""|tee -a ${CompInfoFile}
OS_Etc_Services=$(cat /etc/services|grep -i ${InstName}|grep -v "#")
echo "OS_Etc_Services:"${OS_Etc_Services}""|tee -a ${CompInfoFile}

##USER Info
OS_User_List=$(lsuser -c -a id ALL|awk -F: '{if($1!~"^#" && $2>500 && $2<10000) print $1}')
echo "OS_User_List:"${OS_User_List}""|tee -a ${CompInfoFile}

##Database Info
DB_Catalogdb_Count=$(db2 list db directory|grep -i "Database name"|wc -l)
echo "DB_Catalogdb_Count:${DB_Catalogdb_Count}"|tee -a ${CompInfoFile}
DB_Catalognode_Count=$(db2 list node directorygrep -i "Node name"|wc -l)
echo "DB_Catalognode_Count:${DB_Catalognode_Count}"|tee -a ${CompInfoFile}

db2 connect to $DBName >/dev/null
DB_Application_Connected=$(db2 list applications|wc -l)
echo "DB_Application_Connected:${DB_Application_Connected}"|tee -a ${CompInfoFile}
DB_Table_count=$(db2 -x "select count(1) from syscat.tables where type='T' and tabschema not like 'SYS%' with ur")
echo "DB_Table_count:${DB_Table_count}"|tee -a ${CompInfoFile}
DB_Proc_count=$(db2 -x "select count(1) from syscat.procedures where procschema not like 'SYS%' with ur")
echo "DB_Proc_count:${DB_Proc_count}"|tee -a ${CompInfoFile}
DB_Function_count=$(db2 -x "select count(1) from syscat.functions where funcschema not like 'SYS%' with ur")
echo "DB_Function_count:${DB_Function_count}"|tee -a ${CompInfoFile}
DB_Package_count=$(db2 -x "select count(1) from syscat.packages where pkgschema not like 'SYS%' with ur")
echo "DB_Package_count:${DB_Package_count}"|tee -a ${CompInfoFile}

retcode=0
exit $retcode
