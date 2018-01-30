#!/usr/bin/env ksh

function syntax
{
  echo "The script is executed to compare the collect data in source host and target host."
  echo "syntax:"
  echo " /home/ggroot/db2/DB2_CompDiff.sh -SOURCE_HOST <Source_Host> -TARGET_HOST <Target_Host> -SOURCE_DBNAME <Source_DBName> -SOURCE_INST <Source_InstName> \n"
  echo " -TARGET_DBNAME <Target_DBName> -TARGET_INST <Target_InstName> \" "
  echo " where:"
  echo "   <path>      : is the full path to this script, normally"
  echo " Parameters: "
  echo "   <Source_Host>    : The hostname of source machine,general is the host which have low db2 version . "
  echo "   <Target_Host>    : The hostname of source machine,general is the host which have high db2 version . "
  echo "   <Source_DBName>       : The Name of the source database,db2 v9.5  dbname   "
  echo "   <Target_DBName>       : The Name of the source database,db2 v10.5  dbname    "
  echo "   <Source_INST>     : The Name of the target instance,db2 v9.5 instname"
  echo "   <Target_INST>     : The Name of the target instance,db2 v10.5 instname"
  echo " Sample: "
  echo "   DB2_CompDiff.sh -SOURCE_HOST dba_test -SOURCE_DBNAME testdb -SOURCE_INST db2inst1 -TARGET_HOST dba_test -TARGET_DBNAME testdb -TARGET_INST db2inst1"
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

typeset ShellOption="$@"
for inopt in ${ShellOption}
do
  case $(echo $inopt|tr a-z A-Z) in
    -SOURCE_HOST) CurOpt="-SOURCE_HOST";continue;;
    -TARGET_HOST) CurOpt="-TARGET_HOST";continue;;
    -SOURCE_INST) CurOpt="-SOURCE_INST";continue;;
    -TARGET_INST) CurOpt="-TARGET_INST";continue;;
    -SOURCE_DBNAME) CurOpt="-SOURCE_DBNAME";continue;;
    -TARGET_DBNAME) CurOpt="-TARGET_DBNAME";continue;;
    -H|-*) syntax;return -1;;
  esac
  case "${CurOpt}" in
    -SOURCE_HOST) Source_Host="${inopt}";;
    -TARGET_HOST) Target_Host="${inopt}";;
    -SOURCE_DBNAME) Source_DBName=`echo ${inopt}| tr a-z A-Z`;;
    -TARGET_DBNAME) Target_DBName=`echo ${inopt}| tr a-z A-Z`;;
    -SOURCE_INST) Source_Inst="${inopt}";;
    -TARGET_INST) Target_Inst="${inopt}";;
  esac
done

[ -z "${Source_Host}" ] && syntax || [ -z "${Target_Host}" ] && syntax
[ -z "${Source_Inst}" ] && syntax || [ -z "${Target_Inst}" ] && syntax
[ -z "${Source_DBName}" ] && syntax || [ -z "${Target_DBName}" ] && syntax

ShellName="$(echo $0|awk -F / '{print $NF}')"
WorkDir="$(echo $0|sed s/${ShellName}//g)"
[ -z "${WorkDir}" ] && WorkDir=$(pwd);cd ${WorkDir};WorkDir=$(pwd)
StartTime=$(date '+%Y%m%d.%H%M%S')
LogFile="${WorkDir}/logs/DB2_CompDiff.log.${StartTime}"

if [ ! -f ${LogFile} ]
then
     touch ${LogFile} || LogFile="/dev/null"
     [ "${LogFile}" != "/dev/null" ] && [ -f ${LogFile} ] && chmod 666 ${LogFile}
fi

f_printInfo ">>>>> $(date "+%Y%m%d.%H%M%S") <<<<< "

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


Source_FullPath="${_TgtFullPath_S}"
Target_FullPath="${_TgtFullPath_T}"

#Src_FileName="${Source_FullPath}/${Source_Inst}.${Source_DBName}.db2_compinfo.SOURCE"
#Tgt_FileName="${Target_FullPath}/${Target_Inst}.${Target_DBName}.db2_compinfo.TARGET"
Src_FileName="${WorkDir}/${Source_Inst}.${Source_DBName}.db2_compinfo.SOURCE"
Tgt_FileName="${WorkDir}/${Target_Inst}.${Target_DBName}.db2_compinfo.TARGET"

if [ ! -f ${Src_FileName} ];then
  f_printError "no source compare file exist,Please use cmb_cdc_db2_getcominfo.sh source to collect data\n"
fi
if [ ! -f ${Tgt_FileName} ];then
  f_printError "no target compare file exist,Please use cmb_cdc_db2_getcominfo.sh target to collect data\n"
fi

function f_compare_src_tgt_data
{
  Src_DBCFG_Territory=$(cat $Src_FileName|grep -i "DBCFG_Territory"|awk -F: '{print $2}')
  Tgt_DBCFG_Territory=$(cat $Tgt_FileName|grep -i "DBCFG_Territory"|awk -F: '{print $2}')
  if [ "$Src_DBCFG_Territory" != "$Tgt_DBCFG_Territory" ];then
    f_printWarning "The DBCFG_Territory value is not same in Source and Target machine\n";retcode=1
  fi
  Src_DBCFG_CodePage=$(cat $Src_FileName|grep -i "DBCFG_CodePage"|awk -F: '{print $2}')
  Tgt_DBCFG_CodePage=$(cat $Tgt_FileName|grep -i "DBCFG_CodePage"|awk -F: '{print $2}')
  if [ "$Src_DBCFG_CodePage" != "$Tgt_DBCFG_CodePage" ];then
    f_printWarning "The DBCFG_CodePage value is not same in Source and Target machine\n";retcode=1
  fi
  Src_DBCFG_CodeSet=$(cat $Src_FileName|grep -i "DBCFG_CodeSet"|awk -F: '{print $2}')
  Tgt_DBCFG_CodeSet=$(cat $Tgt_FileName|grep -i "DBCFG_CodeSet"|awk -F: '{print $2}')
  if [ "$Src_DBCFG_CodeSet" != "$Tgt_DBCFG_CodeSet" ];then
    f_printWarning "The DBCFG_CodeSet value is not same in Source and Target machine\n";retcode=1
  fi
  Src_DB2SET_CodePage=$(cat $Src_FileName|grep -i "DB2SET_CodePage"|awk -F: '{print $2}')
  Tgt_DB2SET_CodePage=$(cat $Tgt_FileName|grep -i "DB2SET_CodePage"|awk -F: '{print $2}')
  if [ "$Src_DB2SET_CodePage" != "$Tgt_DB2SET_CodePage" ];then
    f_printWarning "The DB2SET_CodePage value is not same in Source and Target machine\n";retcode=1
  fi
  Src_DB2SET_Territory=$(cat $Src_FileName|grep -i "DB2SET_Territory"|awk -F: '{print $2}')
  Tgt_DB2SET_Territory=$(cat $Tgt_FileName|grep -i "DB2SET_Territory"|awk -F: '{print $2}')
  if [ "$Src_DB2SET_Territory" != "$Tgt_DB2SET_Territory" ];then
    f_printWarning "The DB2SET_Territory value is not same in Source and Target machine\n";retcode=1
  fi
  Src_OS_Cpu_Numb=$(cat $Src_FileName|grep -i "OS_Cpu_Numb"|awk -F: '{print $2}')
  Tgt_OS_Cpu_Numb=$(cat $Tgt_FileName|grep -i "OS_Cpu_Numb"|awk -F: '{print $2}')
  if [ "$Src_OS_Cpu_Numb" != "$Tgt_OS_Cpu_Numb" ];then
    f_printWarning "The OS_Cpu_Numb value is not same in Source and Target machine\n";retcode=1
  fi
  Src_OS_Memory_Size=$(cat $Src_FileName|grep -i "OS_Memory_Size"|awk -F: '{print $2}')
  Tgt_OS_Memory_Size=$(cat $Tgt_FileName|grep -i "OS_Memory_Size"|awk -F: '{print $2}')
  if [ "$Src_OS_Memory_Size" != "$Tgt_OS_Memory_Size" ];then
    f_printWarning "The OS_Memory_Size value is not same in Source and Target machine\n";retcode=1
  fi
  Src_OS_Etc_Host_File=$(cat $Src_FileName|grep -i "OS_Etc_Host_File"|awk -F: '{print $2}')
  Tgt_OS_Etc_Host_File=$(cat $Tgt_FileName|grep -i "OS_Etc_Host_File"|awk -F: '{print $2}')
  if [ "$Src_OS_Etc_Host_File" != "$Tgt_OS_Etc_Host_File" ];then
    f_printWarning "The OS_Etc_Host_File value is not same in Source and Target machine\n";retcode=1
  fi
  Src_OS_Etc_Services=$(cat $Src_FileName|grep -i "OS_Etc_Services"|awk -F: '{print $2}')
  Tgt_OS_Etc_Services=$(cat $Tgt_FileName|grep -i "OS_Etc_Services"|awk -F: '{print $2}')
  if [ "$Src_OS_Etc_Services" != "$Tgt_OS_Etc_Services" ];then
    f_printWarning "The OS_Etc_Services value is not same in Source and Target machine\n";retcode=1
  fi
  Src_OS_User_List=$(cat $Src_FileName|grep -i "OS_User_List"|awk -F: '{print $2}')
  Tgt_OS_User_List=$(cat $Tgt_FileName|grep -i "OS_User_List"|awk -F: '{print $2}')
  if [ "$Src_OS_User_List" != "$Tgt_OS_User_List" ];then
    f_printWarning "The OS_User_List value is not same in Source and Target machine\n";retcode=1
  fi
  Src_DB_Catalogdb_Count=$(cat $Src_FileName|grep -i "DB_Catalogdb_Count"|awk -F: '{print $2}')
  Tgt_DB_Catalogdb_Count=$(cat $Tgt_FileName|grep -i "DB_Catalogdb_Count"|awk -F: '{print $2}')
  if [ "$Src_DB_Catalogdb_Count" != "$Tgt_DB_Catalogdb_Count" ];then
    f_printWarning "The DB_Catalogdb_Count value is not same in Source and Target machine\n";retcode=1
  fi
  Src_DB_Catalognode_Count=$(cat $Src_FileName|grep -i "DB_Catalognode_Count"|awk -F: '{print $2}')
  Tgt_DB_Catalognode_Count=$(cat $Tgt_FileName|grep -i "DB_Catalognode_Count"|awk -F: '{print $2}')
  if [ "$Src_DB_Catalognode_Count" != "$Tgt_DB_Catalognode_Count" ];then
    f_printWarning "The DB_Catalognode_Count value is not same in Source and Target machine\n";retcode=1
  fi
  Src_DB_Application_Connected=$(cat $Src_FileName|grep -i "DB_Application_Connected"|awk -F: '{print $2}')
  Tgt_DB_Application_Connected=$(cat $Tgt_FileName|grep -i "DB_Application_Connected"|awk -F: '{print $2}')
  if [ "$Src_DB_Application_Connected" != "$Tgt_DB_Application_Connected" ];then
    f_printWarning "The DB_Application_Connected value is not same in Source and Target machine\n";retcode=1
  fi
  Src_DB_Table_count=$(cat $Src_FileName|grep -i "DB_Table_count"|awk -F: '{print $2}')
  Tgt_DB_Table_count=$(cat $Tgt_FileName|grep -i "DB_Table_count"|awk -F: '{print $2}')
  if [ "$Src_DB_Table_count" != "$Tgt_DB_Table_count" ];then
    f_printWarning "The DB_Table_count value is not same in Source and Target machine\n";retcode=1
  fi
  Src_DB_Proc_count=$(cat $Src_FileName|grep -i "DB_Proc_count"|awk -F: '{print $2}')
  Tgt_DB_Proc_count=$(cat $Tgt_FileName|grep -i "DB_Proc_count"|awk -F: '{print $2}')
  if [ "$Src_DB_Proc_count" != "$Tgt_DB_Proc_count" ];then
    f_printWarning "The DB_Proc_count value is not same in Source and Target machine\n";retcode=1
  fi
  Src_DB_Function_count=$(cat $Src_FileName|grep -i "DB_Function_count"|awk -F: '{print $2}')
  Tgt_DB_Function_count=$(cat $Tgt_FileName|grep -i "DB_Function_count"|awk -F: '{print $2}')
  if [ "$Src_DB_Function_count" != "$Tgt_DB_Function_count" ];then
    f_printWarning "The DB_Function_count value is not same in Source and Target machine\n";retcode=1
  fi
  Src_DB_Package_count=$(cat $Src_FileName|grep -i "DB_Package_count"|awk -F: '{print $2}')
  Tgt_DB_Package_count=$(cat $Tgt_FileName|grep -i "DB_Package_count"|awk -F: '{print $2}')
  if [ "$Src_DB_Package_count" != "$Tgt_DB_Package_count" ];then
    f_printWarning "The DB_Package_count value is not same in Source and Target machine\n";retcode=1
  fi
  return retcode
}

retcode=0
f_compare_src_tgt_data
exit ${retcode}
