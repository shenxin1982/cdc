#!/usr/bin/env ksh

function syntax
{
  echo "syntax:"
  echo "/usr/bin/su - <instuser> -c /usr/bin/sh <path>/cmb_cdc_db2_precheck.sh -DBNAME <DBName> -INSTNAME <InstName>  -DBCODEPAGE <DBCodePage> -DBTERRITORY <DBTerritory>"
  echo
  echo " executed by root user"
  echo " where:"
  echo "   <path>          : is the full path to this script, normally"
  echo " Parameters: "
  echo "   <DBName>       : Name of the database "
  echo "   <INSTNAME>   :  Name of the instance "
  echo "   <DBCodePage>   :  "
  echo "   <DBTerritory>   :  "
  echo " Samples: "
  echo "   cmb_cdc_db2_precheck.sh -DBNAME testdb -INSTNAME db2inst1 -DBCODEPAGE 1386 -DBTERRITORY 86"
  exit 22
}

typeset ShellOption="$@"
for inopt in ${ShellOption}
do
  case $(echo $inopt|tr a-z A-Z) in
    -DBNAME) CurOpt="-DBNAME";continue;;
    -INSTNAME) CurOpt="-INSTNAME";continue;;
    -HOSTTYPE) CurOpt="-HOSTTYPE";continue;;
    -DBCODEPAGE) CurOpt="-DBCODEPAGE";continue;;
    -DBTERRITORY) CurOpt="-DBTERRITORY";continue;;
    -H|-*) syntax;return -1;;
  esac
  case "${CurOpt}" in
    -DBNAME) DBName=`echo ${inopt}| tr a-z A-Z`;;
    -INSTNAME) InstName=`echo ${inopt}`;;
    -HOSTTYPE) HostType=`echo ${inopt}|tr a-z A-Z`;;
    -DBCODEPAGE) DBCodePage=`echo ${inopt}`;;
    -DBTERRITORY) DBTerritory=`echo ${inopt}`;;
  esac
done

[ -z "${DBName}" ] && syntax || [ -z "${InstName}" ] && syntax || [ -z "${DBCodePage}" ] && syntax || [ -z "${DBTerritory}" ] && syntax


ShellName="$(echo $0|awk -F / '{print $NF}')"
WorkDir="$(echo $0|sed s/${ShellName}//g)"
[ -z "${WorkDir}" ] && WorkDir=$(pwd);cd ${WorkDir};WorkDir=$(pwd)
StartTime=$(date '+%Y%m%d.%H%M%S');
LogFile="${WorkDir}/cmb_cdc_db2_precheck.log.${StartTime}"

if [ ! -f ${LogFile} ]
then
     touch ${LogFile} || LogFile="/dev/null"
     [ "${LogFile}" != "/dev/null" ] && [ -f ${LogFile} ] && chmod 666 ${LogFile}
fi

##db2set cfg
Reg_DB2_LOAD_COPY_NO_OVERRIDE=NONRECOVERABLE;
Reg_DB2_USE_ALTERNATE_PAGE_CLEANING=ON;
Reg_DB2_LOGGER_NON_BUFFERED_IO=ON;
Reg_DB2_TRUST_MDC_BLOCK_FULL_HINT=YES;
Reg_DB2_MDC_ROLLOUT=DEFER;
Reg_DB2_EVALUNCOMMITTED=ON;
Reg_DB2_SKIPINSERTED=ON;
Reg_DB2SOSNDBUF=1048576;
Reg_DB2SORCVBUF=1048576;
Reg_DB2_PARALLEL_IO=*;
Reg_DB2COMM=TCPIP;
Reg_DB2CODEPAGE=${DBCodePage};
Reg_DB2TERRITORY=${DBTerritory};

##dbm cfg
Reg_DFT_MON_BUFPOOL=ON;
Reg_DFT_MON_LOCK=ON;
Reg_DFT_MON_SORT=ON;
Reg_DFT_MON_STMT=ON;
Reg_DFT_MON_TABLE=ON;
Reg_DFT_MON_TIMESTAMP=ON;
Reg_DFT_MON_UOW=ON;
Reg_HEALTH_MON=OFF;
Reg_AUTHENTICATION=SERVER;
Reg_MON_HEAP_SZ=1024;
Reg_AUDIT_BUF_SZ=1024;
Reg_SHEAPTHRES=0;
Reg_KEEPFENCED=NO;
Reg_FENCED_POOL=0;
Reg_NUM_INITFENCED=0;
Reg_INTRA_PARALLEL=NO;

##db cfg
Reg_DFT_DEGREE=1;
Reg_SELF_TUNING_MEM=OFF;
Reg_DATABASE_MEMORY=AUTOMATIC;
Reg_DB_MEM_THRESH=10;
Reg_LOCKLIST=10240;
Reg_MAXLOCKS=20;
Reg_PCKCACHESZ=10240;
Reg_SHEAPTHRES_SHR=20480;
Reg_SORTHEAP=2048;
Reg_DBHEAP=AUTOMATIC;
Reg_CATALOGCACHE_SZ=4096;
Reg_LOGBUFSZ=4096;
Reg_UTIL_HEAP_SZ=10240;
Reg_STMTHEAP=4096;
Reg_APPLHEAPSZ=AUTOMATIC;
Reg_APPL_MEMORY=AUTOMATIC;
Reg_STAT_HEAP_SZ=AUTOMATIC;
Reg_LOCKTIMEOUT=30;
Reg_TRACKMOD=YES;
Reg_MAXFILOP=61440;
Reg_LOGFILSIZ=10240;
Reg_LOGPRIMARY=20;
##LOGPRIMARY=$((ActLogSizeGB*1024*1024*6/10/4/LOGFILSIZ));
Reg_LOGSECOND=0;
Reg_NEWLOGPATH=/db/actlog/${InstName}/${DBName};
Reg_MIRRORLOGPATH=/db/mirlog/${InstName}/${DBName};
Reg_MAX_LOG=30;
Reg_NUM_LOG_SPAN=10;
##NUM_LOG_SPAN=$((LOGPRIMARY*9/10));
Reg_HADR_LOCAL_HOST=hadr1_${DBName};
Reg_HADR_LOCAL_SVC=hadr1_${InstName}_${DBName};
Reg_HADR_REMOTE_HOST=hadr2_${DBName};
Reg_HADR_REMOTE_SVC=hadr2_${InstName}_${DBName};
Reg_HADR_REMOTE_INST=${InstName};
Reg_HADR_TIMEOUT=120;
Reg_HADR_SYNCMODE=ASYNC;
Reg_HADR_PEER_WINDOW=0;
Reg_LOGARCHMETH1=DISK:/db/archm1;
Reg_LOGARCHMETH2=OFF;
Reg_LOGINDEXBUILD=ON;
Reg_BLOCKNONLOGGED=NO;
Reg_REC_HIS_RETENTN=12;
AUTO_DEL_REC_OBJ=OFF
Reg_AUTO_MAINT=OFF;
Reg_AUTO_DB_BACKUP=OFF;
Reg_AUTO_TBL_MAINT=OFF;
Reg_AUTO_RUNSTATS=OFF;
Reg_AUTO_STMT_STATS=OFF;
Reg_AUTO_STATS_PROF=OFF;
Reg_AUTO_PROF_UPD=OFF;
Reg_AUTO_REORG=OFF;

function f_printError
{
  echo "[Error]:$(date "+%Y%m%d.%H%M%S"):$1" |tee -a ${LogFile};
  exit 11
}

function f_printWarning
{
  echo "[Warn ]:$(date "+%Y%m%d.%H%M%S"):$1"|tee -a ${LogFile} ;
}

function f_printInfo
{
  echo "[Info ]:$(date "+%Y%m%d.%H%M%S"):$1"|tee -a ${LogFile} ;
}

function f_db2licm_check
{
LINCENSE_FLAG=`db2licm -l |grep -i Permanent|wc -l`
if [ ${LINCENSE_FLAG} -ne 1 ];then
    f_printWarning "db2 license need to be Registed,db2licm -a <path>/<licm file>";retcode=1
fi
}

function f_db2set_check
{
  db2set -all > ${WorkDir}/current_db2set.cfg
  CUST_DB2_LOAD_COPY_NO_OVERRIDE=`cat ${WorkDir}/current_db2set.cfg | grep -i "DB2_LOAD_COPY_NO_OVERRIDE" | awk -F= '{print $2}'|sed s/[[:space:]]//g`
  if [ "${CUST_DB2_LOAD_COPY_NO_OVERRIDE}" != "${Reg_DB2_LOAD_COPY_NO_OVERRIDE}" ]
  then
    f_printWarning "db2set DB2_LOAD_COPY_NO_OVERRIDE=${Reg_DB2_LOAD_COPY_NO_OVERRIDE}";retcode=1
  fi
  CUST_DB2_TRUST_MDC_BLOCK_FULL_HINT=`cat ${WorkDir}/current_db2set.cfg | grep -i "DB2_TRUST_MDC_BLOCK_FULL_HINT" | awk -F= '{print $2}'|sed s/[[:space:]]//g`
  if [ "${CUST_DB2_TRUST_MDC_BLOCK_FULL_HINT}" != "${Reg_DB2_TRUST_MDC_BLOCK_FULL_HINT}" ]
  then
    f_printWarning "db2set DB2_TRUST_MDC_BLOCK_FULL_HINT=${Reg_DB2_TRUST_MDC_BLOCK_FULL_HINT}";retcode=1
  fi
  CUST_DB2_LOGGER_NON_BUFFERED_IO=`cat ${WorkDir}/current_db2set.cfg | grep -i "DB2_LOGGER_NON_BUFFERED_IO" | awk -F= '{print $2}'|sed s/[[:space:]]//g`
  if [ "${CUST_DB2_LOGGER_NON_BUFFERED_IO}" != "${Reg_DB2_LOGGER_NON_BUFFERED_IO}" ]
  then
    f_printWarning "db2set DB2_LOGGER_NON_BUFFERED_IO=${Reg_DB2_LOGGER_NON_BUFFERED_IO}";retcode=1
  fi
  CUST_DB2_TRUST_MDC_BLOCK_FULL_HINT=`cat ${WorkDir}/current_db2set.cfg | grep -i "DB2_TRUST_MDC_BLOCK_FULL_HINT" | awk -F= '{print $2}'|sed s/[[:space:]]//g`
  if [ "${CUST_DB2_TRUST_MDC_BLOCK_FULL_HINT}" != "${Reg_DB2_TRUST_MDC_BLOCK_FULL_HINT}" ]
  then
    f_printWarning "db2set DB2_TRUST_MDC_BLOCK_FULL_HINT=${Reg_DB2_TRUST_MDC_BLOCK_FULL_HINT}";retcode=1
  fi
  CUST_DB2_MDC_ROLLOUT=`cat ${WorkDir}/current_db2set.cfg | grep -i "DB2_MDC_ROLLOUT" | awk -F= '{print $2}'|sed s/[[:space:]]//g`
  if [ "${CUST_DB2_MDC_ROLLOUT}" != "${Reg_DB2_MDC_ROLLOUT}" ]
  then
    f_printWarning "db2set DB2_MDC_ROLLOUT=${Reg_DB2_MDC_ROLLOUT}";retcode=1
  fi
  CUST_DB2_EVALUNCOMMITTED=`cat ${WorkDir}/current_db2set.cfg | grep -i "DB2_EVALUNCOMMITTED" | awk -F= '{print $2}'|sed s/[[:space:]]//g`
  if [ "${CUST_DB2_EVALUNCOMMITTED}" != "${Reg_DB2_EVALUNCOMMITTED}" ]
  then
    f_printWarning "db2set DB2_EVALUNCOMMITTED=${Reg_DB2_EVALUNCOMMITTED}";retcode=1
  fi
  CUST_DB2_SKIPINSERTED=`cat ${WorkDir}/current_db2set.cfg | grep -i "DB2_SKIPINSERTED" | awk -F= '{print $2}'|sed s/[[:space:]]//g`
  if [ "${CUST_DB2_SKIPINSERTED}" != "${Reg_DB2_SKIPINSERTED}" ]
  then
    f_printWarning "db2set DB2_SKIPINSERTED=${Reg_DB2_SKIPINSERTED}";retcode=1
  fi
  CUST_DB2SOSNDBUF=`cat ${WorkDir}/current_db2set.cfg | grep -i "DB2SOSNDBUF" | awk -F= '{print $2}'|sed s/[[:space:]]//g`
  if [ "${CUST_DB2SOSNDBUF}" != "${Reg_DB2SOSNDBUF}" ]
  then
    f_printWarning "db2set DB2SOSNDBUF=${Reg_DB2SOSNDBUF}";retcode=1
  fi
  CUST_DB2SORCVBUF=`cat ${WorkDir}/current_db2set.cfg | grep -i "DB2SORCVBUF" | awk -F= '{print $2}'|sed s/[[:space:]]//g`
  if [ "${CUST_DB2SORCVBUF}" != "${Reg_DB2SORCVBUF}" ]
  then
    f_printWarning "db2set DB2SORCVBUF=${Reg_DB2SORCVBUF}";retcode=1
  fi
  CUST_DB2_PARALLEL_IO=`cat ${WorkDir}/current_db2set.cfg | grep -i "DB2_PARALLEL_IO" | awk -F= '{print $2}'|sed s/[[:space:]]//g`
  if [ "${CUST_DB2_PARALLEL_IO}" != "${Reg_DB2_PARALLEL_IO}" ]
  then
    f_printWarning "db2set DB2_PARALLEL_IO=${Reg_DB2_PARALLEL_IO}";retcode=1
  fi
  CUST_DB2COMM=`cat ${WorkDir}/current_db2set.cfg | grep -i "DB2COMM" | awk -F= '{print $2}'|sed s/[[:space:]]//g`
  if [ "${CUST_DB2COMM}" != "${Reg_DB2COMM}" ]
  then
    f_printWarning "db2set DB2COMM=${Reg_DB2COMM}";retcode=1
  fi
  CUST_DB2CODEPAGE=`cat ${WorkDir}/current_db2set.cfg | grep -i "DB2CODEPAGE" | awk -F= '{print $2}'|sed s/[[:space:]]//g`
  if [ "${CUST_DB2CODEPAGE}" != "${Reg_DB2CODEPAGE}" ]
  then
    f_printWarning "db2set DB2CODEPAGE=${Reg_DB2CODEPAGE}";retcode=1
  fi
  CUST_DB2TERRITORY=`cat ${WorkDir}/current_db2set.cfg | grep -i "DB2TERRITORY" | awk -F= '{print $2}'|sed s/[[:space:]]//g`
  if [ "${CUST_DB2TERRITORY}" != "${Reg_DB2TERRITORY}" ]
  then
    f_printWarning "db2set DB2TERRITORY=${Reg_DB2TERRITORY}";retcode=1
  fi
##  rm ${WorkDir}/current_db2set.cfg
  return $retcode
}

function f_dbmcfg_check
{
  db2 get dbm cfg > ${WorkDir}/current_dbm.cfg
  CUST_DFT_MON_BUFPOOL=`cat ${WorkDir}/current_dbm.cfg | grep -i "DFT_MON_BUFPOOL" | awk -F= '{print $2}'|sed s/[[:space:]]//g`
  if [ "${CUST_DFT_MON_BUFPOOL}" != "${Reg_DFT_MON_BUFPOOL}" ]
  then
    f_printWarning "db2 update dbm cfg using  DFT_MON_BUFPOOL ${Reg_DFT_MON_BUFPOOL}";retcode=1
  fi
  CUST_DFT_MON_LOCK=`cat ${WorkDir}/current_dbm.cfg | grep -i "DFT_MON_LOCK" | awk -F= '{print $2}'|sed s/[[:space:]]//g`
  if [ "${CUST_DFT_MON_LOCK}" != "${Reg_DFT_MON_LOCK}" ]
  then
    f_printWarning "db2 update dbm cfg using  DFT_MON_LOCK ${Reg_DFT_MON_LOCK}";retcode=1
  fi
  CUST_DFT_MON_SORT=`cat ${WorkDir}/current_dbm.cfg | grep -i "DFT_MON_SORT" | awk -F= '{print $2}'|sed s/[[:space:]]//g`
  if [ "${CUST_DFT_MON_SORT}" != "${Reg_DFT_MON_SORT}" ]
  then
   f_printWarning "db2 update dbm cfg using  DFT_MON_SORT ${Reg_DFT_MON_SORT}";retcode=1
  fi
  CUST_DFT_MON_STMT=`cat ${WorkDir}/current_dbm.cfg | grep -i "DFT_MON_STMT" | awk -F= '{print $2}'|sed s/[[:space:]]//g`
  if [ "${CUST_DFT_MON_STMT}" != "${Reg_DFT_MON_STMT}" ]
  then
   f_printWarning "db2 update dbm cfg using  DFT_MON_STMT ${Reg_DFT_MON_STMT}";retcode=1
  fi
  CUST_DFT_MON_TABLE=`cat ${WorkDir}/current_dbm.cfg | grep -i "DFT_MON_TABLE" | awk -F= '{print $2}'|sed s/[[:space:]]//g`
  if [ "${CUST_DFT_MON_TABLE}" != "${Reg_DFT_MON_TABLE}" ]
  then
   f_printWarning "db2 update dbm cfg using  DFT_MON_TABLE ${Reg_DFT_MON_TABLE}";retcode=1
  fi
  CUST_DFT_MON_TIMESTAMP=`cat ${WorkDir}/current_dbm.cfg | grep -i "DFT_MON_TIMESTAMP" | awk -F= '{print $2}'|sed s/[[:space:]]//g`
  if [ "${CUST_DFT_MON_TIMESTAMP}" != "${Reg_DFT_MON_TIMESTAMP}" ]
  then
   f_printWarning "db2 update dbm cfg using  DFT_MON_TIMESTAMP ${Reg_DFT_MON_TIMESTAMP}";retcode=1
  fi
  CUST_DFT_MON_UOW=`cat ${WorkDir}/current_dbm.cfg | grep -i "DFT_MON_UOW" | awk -F= '{print $2}'|sed s/[[:space:]]//g`
  if [ "${CUST_DFT_MON_UOW}" != "${Reg_DFT_MON_UOW}" ]
  then
    f_printWarning "db2 update dbm cfg using  DFT_MON_UOW ${Reg_DFT_MON_UOW}";retcode=1
  fi
  CUST_HEALTH_MON=`cat ${WorkDir}/current_dbm.cfg | grep -i "HEALTH_MON" | awk -F= '{print $2}'|sed s/[[:space:]]//g`
  if [ "${CUST_HEALTH_MON}" != "${Reg_HEALTH_MON}" ]
  then
    f_printWarning "db2 update dbm cfg using  HEALTH_MON ${Reg_HEALTH_MON}";retcode=1
  fi
  CUST_AUTHENTICATION=`cat ${WorkDir}/current_dbm.cfg | grep -i "(AUTHENTICATION)" | awk -F= '{print $2}'|sed s/[[:space:]]//g`
  if [ "${CUST_AUTHENTICATION}" != "${Reg_AUTHENTICATION}" ]
  then
   f_printWarning "db2 update dbm cfg using AUTHENTICATION ${Reg_AUTHENTICATION}";retcode=1
  fi
  CUST_MON_HEAP_SZ=`cat ${WorkDir}/current_dbm.cfg | grep -i "MON_HEAP_SZ" | awk -F= '{print $2}'|sed s/[[:space:]]//g`
  if [ "${CUST_MON_HEAP_SZ}" != "${Reg_MON_HEAP_SZ}" ]
  then
    f_printWarning "db2 update dbm cfg using  MON_HEAP_SZ ${Reg_MON_HEAP_SZ}";retcode=1
  fi
  CUST_AUDIT_BUF_SZ=`cat ${WorkDir}/current_dbm.cfg | grep -i "AUDIT_BUF_SZ" | awk -F= '{print $2}'|sed s/[[:space:]]//g`
  if [ "${CUST_AUDIT_BUF_SZ}" != "${Reg_AUDIT_BUF_SZ}" ]
  then
    f_printWarning "db2 update dbm cfg using  AUDIT_BUF_SZ ${Reg_AUDIT_BUF_SZ}";retcode=1
  fi
  CUST_SHEAPTHRES=`cat ${WorkDir}/current_dbm.cfg | grep -i "SHEAPTHRES" | awk -F= '{print $2}'|sed s/[[:space:]]//g`
  if [ "${CUST_SHEAPTHRES}" != "${Reg_SHEAPTHRES}" ]
  then
    f_printWarning "db2 update dbm cfg using  SHEAPTHRES ${Reg_SHEAPTHRES}";retcode=1
  fi
  CUST_KEEPFENCED=`cat ${WorkDir}/current_dbm.cfg | grep -i "KEEPFENCED" | awk -F= '{print $2}'|sed s/[[:space:]]//g`
  if [ "${CUST_KEEPFENCED}" != "${Reg_KEEPFENCED}" ]
  then
    f_printWarning "db2 update dbm cfg using  KEEPFENCED ${Reg_KEEPFENCED}";retcode=1
  fi
  CUST_FENCED_POOL=`cat ${WorkDir}/current_dbm.cfg | grep -i "FENCED_POOL" | awk -F= '{print $2}'|sed s/[[:space:]]//g`
  if [ "${CUST_FENCED_POOL}" != "${Reg_FENCED_POOL}" ]
  then
    f_printWarning "db2 update dbm cfg using  FENCED_POOL ${Reg_FENCED_POOL}";retcode=1
  fi
  CUST_NUM_INITFENCED=`cat ${WorkDir}/current_dbm.cfg | grep -i "NUM_INITFENCED" | awk -F= '{print $2}'|sed s/[[:space:]]//g`
  if [ "${CUST_NUM_INITFENCED}" != "${Reg_NUM_INITFENCED}" ]
  then
    f_printWarning "db2 update dbm cfg using  NUM_INITFENCED ${Reg_NUM_INITFENCED}";retcode=1
  fi
  CUST_INTRA_PARALLEL=`cat ${WorkDir}/current_dbm.cfg | grep -i "INTRA_PARALLEL" | awk -F= '{print $2}'|sed s/[[:space:]]//g`
  if [ "${CUST_INTRA_PARALLEL}" != "${Reg_INTRA_PARALLEL}" ]
  then
    f_printWarning "db2 update dbm cfg using  INTRA_PARALLEL ${Reg_INTRA_PARALLEL}";retcode=1
  fi
## rm ${WorkDir}/current_dbm.cfg
  return $retcode
}

function f_dbcfg_check
{
  db2 get db cfg for ${DBName} > ${WorkDir}/current_db.cfg
  CUST_DFT_DEGREE=`cat ${WorkDir}/current_db.cfg | grep -i "DFT_DEGREE" | awk -F= '{print $2}'|sed s/[[:space:]]//g`
  if [ "${CUST_DFT_DEGREE}" != "${Reg_DFT_DEGREE}" ]
  then
    f_printWarning "db2 update db cfg for ${DBName} using DFT_DEGREE ${Reg_DFT_DEGREE}";retcode=1
  fi
  CUST_SELF_TUNING_MEM=`cat ${WorkDir}/current_db.cfg | grep -i "SELF_TUNING_MEM" | awk -F= '{print $2}'|sed s/[[:space:]]//g`
  if [ "${CUST_SELF_TUNING_MEM}" != "${Reg_SELF_TUNING_MEM}" ]
  then
    f_printWarning "db2 update db cfg for ${DBName} using SELF_TUNING_MEM ${Reg_SELF_TUNING_MEM}";retcode=1
  fi
  CUST_DATABASE_MEMORY=`cat ${WorkDir}/current_db.cfg | grep -i "DATABASE_MEMORY" | awk -F= '{print $2}'|sed s/[[:space:]]//g|cut -c1-9`
  if [ "${CUST_DATABASE_MEMORY}" != "${Reg_DATABASE_MEMORY}" ]
  then
    f_printWarning "db2 update db cfg for ${DBName} using DATABASE_MEMORY ${Reg_DATABASE_MEMORY}";retcode=1
  fi
  CUST_DB_MEM_THRESH=`cat ${WorkDir}/current_db.cfg | grep -i "DB_MEM_THRESH" | awk -F= '{print $2}'|sed s/[[:space:]]//g`
  if [ "${CUST_DB_MEM_THRESH}" != "${Reg_DB_MEM_THRESH}" ]
  then
    f_printWarning "db2 update db cfg for ${DBName} using DB_MEM_THRESH ${Reg_DB_MEM_THRESH}";retcode=1
  fi
  CUST_LOCKLIST=`cat ${WorkDir}/current_db.cfg | grep -i "LOCKLIST" | awk -F= '{print $2}'|sed s/[[:space:]]//g`
  if [ "${CUST_LOCKLIST}" != "${Reg_LOCKLIST}" ]
  then
    f_printWarning "db2 update db cfg for ${DBName} using LOCKLIST ${Reg_LOCKLIST}";retcode=1
  fi
  CUST_MAXLOCKS=`cat ${WorkDir}/current_db.cfg | grep -i "MAXLOCKS" | awk -F= '{print $2}'|sed s/[[:space:]]//g`
  if [ "${CUST_MAXLOCKS}" != "${Reg_MAXLOCKS}" ]
  then
    f_printWarning "db2 update db cfg for ${DBName} using MAXLOCKS ${Reg_MAXLOCKS}";retcode=1
  fi
  CUST_PCKCACHESZ=`cat ${WorkDir}/current_db.cfg | grep -i "PCKCACHESZ" | awk -F= '{print $2}'|sed s/[[:space:]]//g`
  if [ "${CUST_PCKCACHESZ}" != "${Reg_PCKCACHESZ}" ]
  then
    f_printWarning "db2 update db cfg for ${DBName} using PCKCACHESZ ${Reg_PCKCACHESZ}";retcode=1
  fi
  CUST_SHEAPTHRES_SHR=`cat ${WorkDir}/current_db.cfg | grep -i "SHEAPTHRES_SHR" | awk -F= '{print $2}'|sed s/[[:space:]]//g`
  if [ "${CUST_SHEAPTHRES_SHR}" != "${Reg_SHEAPTHRES_SHR}" ]
  then
    f_printWarning "db2 update db cfg for ${DBName} using SHEAPTHRES_SHR ${Reg_SHEAPTHRES_SHR}";retcode=1
  fi
  CUST_SORTHEAP=`cat ${WorkDir}/current_db.cfg | grep -i "SORTHEAP" | awk -F= '{print $2}'|sed s/[[:space:]]//g`
  if [ "${CUST_SORTHEAP}" != "${Reg_SORTHEAP}" ]
  then
    f_printWarning "db2 update db cfg for ${DBName} using SORTHEAP ${Reg_SORTHEAP}";retcode=1
  fi
  CUST_DBHEAP=`cat ${WorkDir}/current_db.cfg | grep -i "DBHEAP" | awk -F= '{print $2}'|sed s/[[:space:]]//g|cut -c1-9`
  if [ "${CUST_DBHEAP}" != "${Reg_DBHEAP}" ]
  then
    f_printWarning "db2 update db cfg for ${DBName} using DBHEAP ${Reg_DBHEAP}";retcode=1
  fi
  CUST_CATALOGCACHE_SZ=`cat ${WorkDir}/current_db.cfg | grep -i "CATALOGCACHE_SZ" | awk -F= '{print $2}'|sed s/[[:space:]]//g`
  if [ "${CUST_CATALOGCACHE_SZ}" != "${Reg_CATALOGCACHE_SZ}" ]
  then
    f_printWarning "db2 update db cfg for ${DBName} using CATALOGCACHE_SZ ${Reg_CATALOGCACHE_SZ}";retcode=1
  fi
  CUST_LOGBUFSZ=`cat ${WorkDir}/current_db.cfg | grep -i "LOGBUFSZ" | awk -F= '{print $2}'|sed s/[[:space:]]//g`
  if [ "${CUST_LOGBUFSZ}" != "${Reg_LOGBUFSZ}" ]
  then
    f_printWarning "db2 update db cfg for ${DBName} using LOGBUFSZ ${Reg_LOGBUFSZ}";retcode=1
  fi
  CUST_UTIL_HEAP_SZ=`cat ${WorkDir}/current_db.cfg | grep -i "UTIL_HEAP_SZ" | awk -F= '{print $2}'|sed s/[[:space:]]//g`
  if [ "${CUST_UTIL_HEAP_SZ}" != "${Reg_UTIL_HEAP_SZ}" ]
  then
    f_printWarning "db2 update db cfg for ${DBName} using UTIL_HEAP_SZ ${Reg_UTIL_HEAP_SZ}";retcode=1
  fi
  CUST_STMTHEAP=`cat ${WorkDir}/current_db.cfg | grep -i "STMTHEAP" | awk -F= '{print $2}'|sed s/[[:space:]]//g`
  if [ "${CUST_STMTHEAP}" != "${Reg_STMTHEAP}" ]
  then
    f_printWarning "db2 update db cfg for ${DBName} using STMTHEAP ${Reg_STMTHEAP}";retcode=1
  fi
  CUST_APPLHEAPSZ=`cat ${WorkDir}/current_db.cfg | grep -i "APPLHEAPSZ" | awk -F= '{print $2}'|sed s/[[:space:]]//g|cut -c1-9`
  if [ "${CUST_APPLHEAPSZ}" != "${Reg_APPLHEAPSZ}" ]
  then
    f_printWarning "db2 update db cfg for ${DBName} using APPLHEAPSZ ${Reg_APPLHEAPSZ}";retcode=1
  fi
  CUST_APPL_MEMORY=`cat ${WorkDir}/current_db.cfg | grep -i "APPL_MEMORY" | awk -F= '{print $2}'|sed s/[[:space:]]//g|cut -c1-9`
  if [ "${CUST_APPL_MEMORY}" != "${Reg_APPL_MEMORY}" ]
  then
    f_printWarning "db2 update db cfg for ${DBName} using APPL_MEMORY ${Reg_APPL_MEMORY}";retcode=1
  fi
  CUST_STAT_HEAP_SZ=`cat ${WorkDir}/current_db.cfg | grep -i "STAT_HEAP_SZ" | awk -F= '{print $2}'|sed s/[[:space:]]//g|cut -c1-9`
  if [ "${CUST_STAT_HEAP_SZ}" != "${Reg_STAT_HEAP_SZ}" ]
  then
    f_printWarning "db2 update db cfg for ${DBName} using STAT_HEAP_SZ ${Reg_STAT_HEAP_SZ}";retcode=1
  fi
  CUST_LOCKTIMEOUT=`cat ${WorkDir}/current_db.cfg | grep -i "LOCKTIMEOUT" | awk -F= '{print $2}'|sed s/[[:space:]]//g`
  if [ "${CUST_LOCKTIMEOUT}" != "${Reg_LOCKTIMEOUT}" ]
  then
    f_printWarning "db2 update db cfg for ${DBName} using LOCKTIMEOUT ${Reg_LOCKTIMEOUT}";retcode=1
  fi
  CUST_TRACKMOD=`cat ${WorkDir}/current_db.cfg | grep -i "TRACKMOD" | awk -F= '{print $2}'|sed s/[[:space:]]//g`
  if [ "${CUST_TRACKMOD}" != "${Reg_TRACKMOD}" ]
  then
    f_printWarning "db2 update db cfg for ${DBName} using TRACKMOD ${Reg_TRACKMOD}";retcode=1
  fi
  CUST_MAXFILOP=`cat ${WorkDir}/current_db.cfg | grep -i "MAXFILOP" | awk -F= '{print $2}'|sed s/[[:space:]]//g`
  if [ "${CUST_MAXFILOP}" != "${Reg_MAXFILOP}" ]
  then
    f_printWarning "db2 update db cfg for ${DBName} using MAXFILOP ${Reg_MAXFILOP}";retcode=1
  fi
  CUST_NEWLOGPATH=`cat ${WorkDir}/current_db.cfg | grep -i " Path to log files" | awk -F= '{print $2}'|sed s/[[:space:]]//g`
  if [ "${CUST_NEWLOGPATH}" != "${Reg_NEWLOGPATH}" ]
  then
    f_printWarning "db2 update db cfg for ${DBName} using NEWLOGPATH ${Reg_NEWLOGPATH}";retcode=1
  fi
  CUST_MIRRORLOGPATH=`cat ${WorkDir}/current_db.cfg | grep -i "MIRRORLOGPATH" | awk -F= '{print $2}'|sed s/[[:space:]]//g`
  if [ "${CUST_MIRRORLOGPATH}" != "${Reg_MIRRORLOGPATH}" ]
  then
    f_printWarning "db2 update db cfg for ${DBName} using MIRRORLOGPATH ${Reg_MIRRORLOGPATH}";retcode=1
  fi
  CUST_LOGPRIMARY=`cat ${WorkDir}/current_db.cfg | grep -i "LOGPRIMARY" | awk -F= '{print $2}'|sed s/[[:space:]]//g`
  if [ "${CUST_LOGPRIMARY}" != "${Reg_LOGPRIMARY}" ]
  then
    f_printWarning "db2 update db cfg for ${DBName} using LOGPRIMARY ${Reg_LOGPRIMARY}";retcode=1
  fi
  CUST_LOGSECOND=`cat ${WorkDir}/current_db.cfg | grep -i "LOGSECOND" | awk -F= '{print $2}'|sed s/[[:space:]]//g`
  if [ "${CUST_LOGSECOND}" != "${Reg_LOGSECOND}" ]
  then
    f_printWarning "db2 update db cfg for ${DBName} using LOGSECOND ${Reg_LOGSECOND}";retcode=1
  fi
  CUST_LOGFILSIZ=`cat ${WorkDir}/current_db.cfg | grep -i "LOGFILSIZ" | awk -F= '{print $2}'|sed s/[[:space:]]//g`
  if [ "${CUST_LOGFILSIZ}" != "${Reg_LOGFILSIZ}" ]
  then
    f_printWarning "db2 update db cfg for ${DBName} using LOGFILSIZ ${Reg_LOGFILSIZ}";retcode=1
  fi
  CUST_BLOCKNONLOGGED=`cat ${WorkDir}/current_db.cfg | grep -i "BLOCKNONLOGGED" | awk -F= '{print $2}'|sed s/[[:space:]]//g`
  if [ "${CUST_BLOCKNONLOGGED}" != "${Reg_BLOCKNONLOGGED}" ]
  then
    f_printWarning "db2 update db cfg for ${DBName} using BLOCKNONLOGGED ${Reg_BLOCKNONLOGGED}";retcode=1
  fi
  CUST_MAX_LOG=`cat ${WorkDir}/current_db.cfg | grep -i "MAX_LOG" | awk -F= '{print $2}'|sed s/[[:space:]]//g`
  if [ "${CUST_MAX_LOG}" != "${Reg_MAX_LOG}" ]
  then
    f_printWarning "db2 update db cfg for ${DBName} using MAX_LOG ${Reg_MAX_LOG}";retcode=1
  fi
  CUST_NUM_LOG_SPAN=`cat ${WorkDir}/current_db.cfg | grep -i "NUM_LOG_SPAN" | awk -F= '{print $2}'|sed s/[[:space:]]//g`
  if [ "${CUST_NUM_LOG_SPAN}" != "${Reg_NUM_LOG_SPAN}" ]
  then
    f_printWarning "db2 update db cfg for ${DBName} using NUM_LOG_SPAN ${Reg_NUM_LOG_SPAN}";retcode=1
  fi
  CUST_LOGARCHMETH1=`cat ${WorkDir}/current_db.cfg | grep -i "LOGARCHMETH1" | awk -F= '{print $2}'|sed s/[[:space:]]//g`
  if [ "${CUST_LOGARCHMETH1}" != "${Reg_LOGARCHMETH1}" ]
  then
    f_printWarning "db2 update db cfg for ${DBName} using LOGARCHMETH1 ${Reg_LOGARCHMETH1}";retcode=1
  fi
  CUST_LOGARCHMETH2=`cat ${WorkDir}/current_db.cfg | grep -i "LOGARCHMETH2" | awk -F= '{print $2}'|sed s/[[:space:]]//g`
  if [ "${CUST_LOGARCHMETH2}" != "${Reg_LOGARCHMETH2}" ]
  then
    f_printWarning "db2 update db cfg for ${DBName} using LOGARCHMETH2 ${Reg_LOGARCHMETH2}";retcode=1
  fi
  CUST_LOGINDEXBUILD=`cat ${WorkDir}/current_db.cfg | grep -i "LOGINDEXBUILD" | awk -F= '{print $2}'|sed s/[[:space:]]//g`
  if [ "${CUST_LOGINDEXBUILD}" != "${Reg_LOGINDEXBUILD}" ]
  then
    f_printWarning "db2 update db cfg for ${DBName} using LOGINDEXBUILD ${Reg_LOGINDEXBUILD}";retcode=1
  fi
  CUST_REC_HIS_RETENTN=`cat ${WorkDir}/current_db.cfg | grep -i "REC_HIS_RETENTN" | awk -F= '{print $2}'|sed s/[[:space:]]//g`
  if [ "${CUST_REC_HIS_RETENTN}" != "${Reg_REC_HIS_RETENTN}" ]
  then
    f_printWarning "db2 update db cfg for ${DBName} using REC_HIS_RETENTN ${Reg_REC_HIS_RETENTN}";retcode=1
  fi
  CUST_AUTO_DEL_REC_OBJ=`cat ${WorkDir}/current_db.cfg | grep -i "AUTO_DEL_REC_OBJ" | awk -F= '{print $2}'|sed s/[[:space:]]//g`
  if [ "${CUST_AUTO_DEL_REC_OBJ}" != "${Reg_AUTO_DEL_REC_OBJ}" ]
  then
    f_printWarning "db2 update db cfg for ${DBName} using AUTO_DEL_REC_OBJ ${Reg_AUTO_DEL_REC_OBJ}";retcode=1
  fi
  CUST_AUTO_MAINT=`cat ${WorkDir}/current_db.cfg | grep -i "AUTO_MAINT" | awk -F= '{print $2}'|sed s/[[:space:]]//g`
  if [ "${CUST_AUTO_MAINT}" != "${Reg_AUTO_MAINT}" ]
  then
    f_printWarning "db2 update db cfg for ${DBName} using AUTO_MAINT ${Reg_AUTO_MAINT}";retcode=1
  fi
  CUST_AUTO_DB_BACKUP=`cat ${WorkDir}/current_db.cfg | grep -i "AUTO_DB_BACKUP" | awk -F= '{print $2}'|sed s/[[:space:]]//g`
  if [ "${CUST_AUTO_DB_BACKUP}" != "${Reg_AUTO_DB_BACKUP}" ]
  then
    f_printWarning "db2 update db cfg for ${DBName} using AUTO_DB_BACKUP ${Reg_AUTO_DB_BACKUP}";retcode=1
  fi
  CUST_AUTO_TBL_MAINT=`cat ${WorkDir}/current_db.cfg | grep -i "AUTO_TBL_MAINT" | awk -F= '{print $2}'|sed s/[[:space:]]//g`
  if [ "${CUST_AUTO_TBL_MAINT}" != "${Reg_AUTO_TBL_MAINT}" ]
  then
    f_printWarning "db2 update db cfg for ${DBName} using AUTO_TBL_MAINT ${Reg_AUTO_TBL_MAINT}";retcode=1
  fi
  CUST_AUTO_RUNSTATS=`cat ${WorkDir}/current_db.cfg | grep -i "AUTO_RUNSTATS" | awk -F= '{print $2}'|sed s/[[:space:]]//g`
  if [ "${CUST_AUTO_RUNSTATS}" != "${Reg_AUTO_RUNSTATS}" ]
  then
    f_printWarning "db2 update db cfg for ${DBName} using AUTO_RUNSTATS ${Reg_AUTO_RUNSTATS}";retcode=1
  fi
  CUST_AUTO_STMT_STATS=`cat ${WorkDir}/current_db.cfg | grep -i "AUTO_STMT_STATS" | awk -F= '{print $2}'|sed s/[[:space:]]//g`
  if [ "${CUST_AUTO_STMT_STATS}" != "${Reg_AUTO_STMT_STATS}" ]
  then
    f_printWarning "db2 update db cfg for ${DBName} using AUTO_STMT_STATS ${Reg_AUTO_STMT_STATS}";retcode=1
  fi
  CUST_AUTO_REORG=`cat ${WorkDir}/current_db.cfg | grep -i "AUTO_REORG" | awk -F= '{print $2}'|sed s/[[:space:]]//g`
  if [ "${CUST_AUTO_REORG}" != "${Reg_AUTO_REORG}" ]
  then
    f_printWarning "db2 update db cfg for ${DBName} using AUTO_REORG ${Reg_AUTO_REORG}";retcode=1
  fi
  CUST_AUTO_PROF_UPD=`cat ${WorkDir}/current_db.cfg | grep -i "AUTO_PROF_UPD" | awk -F= '{print $2}'|sed s/[[:space:]]//g`
  if [ "${CUST_AUTO_PROF_UPD}" != "${Reg_AUTO_PROF_UPD}" ]
  then
    f_printWarning "db2 update db cfg for ${DBName} using AUTO_PROF_UPD ${Reg_AUTO_PROF_UPD}";retcode=1
  fi
  CUST_AUTO_STATS_PROF=`cat ${WorkDir}/current_db.cfg | grep -i "AUTO_STATS_PROF" | awk -F= '{print $2}'|sed s/[[:space:]]//g`
  if [ "${CUST_AUTO_STATS_PROF}" != "${Reg_AUTO_STATS_PROF}" ]
  then
    f_printWarning "db2 update db cfg for ${DBName} using AUTO_STATS_PROF ${Reg_AUTO_STATS_PROF}";retcode=1
  fi
  CUST_HADR_LOCAL_HOST=`cat ${WorkDir}/current_db.cfg | grep -i "HADR_LOCAL_HOST" | awk -F= '{print $2}'|sed s/[[:space:]]//g`
  if [ "${CUST_HADR_LOCAL_HOST}" != "${Reg_HADR_LOCAL_HOST}" ]
  then
    f_printWarning "db2 update db cfg for ${DBName} using HADR_LOCAL_HOST ${Reg_HADR_LOCAL_HOST}";retcode=1
  fi
  CUST_HADR_LOCAL_SVC=`cat ${WorkDir}/current_db.cfg | grep -i "HADR_LOCAL_SVC" | awk -F= '{print $2}'|sed s/[[:space:]]//g`
  if [ "${CUST_HADR_LOCAL_SVC}" != "${Reg_HADR_LOCAL_SVC}" ]
  then
    f_printWarning "db2 update db cfg for ${DBName} using HADR_LOCAL_SVC ${Reg_HADR_LOCAL_SVC}";retcode=1
  fi
  CUST_HADR_REMOTE_HOST=`cat ${WorkDir}/current_db.cfg | grep -i "HADR_REMOTE_HOST" | awk -F= '{print $2}'|sed s/[[:space:]]//g`
  if [ "${CUST_HADR_REMOTE_HOST}" != "${Reg_HADR_REMOTE_HOST}" ]
  then
    f_printWarning "db2 update db cfg for ${DBName} using HADR_REMOTE_HOST ${Reg_HADR_REMOTE_HOST}";retcode=1
  fi
  CUST_HADR_REMOTE_SVC=`cat ${WorkDir}/current_db.cfg | grep -i "HADR_REMOTE_SVC" | awk -F= '{print $2}'|sed s/[[:space:]]//g`
  if [ "${CUST_HADR_REMOTE_SVC}" != "${Reg_HADR_REMOTE_SVC}" ]
  then
    f_printWarning "db2 update db cfg for ${DBName} using HADR_REMOTE_SVC ${Reg_HADR_REMOTE_SVC}";retcode=1
  fi
  CUST_HADR_REMOTE_INST=`cat ${WorkDir}/current_db.cfg | grep -i "HADR_REMOTE_INST" | awk -F= '{print $2}'|sed s/[[:space:]]//g`
  if [ "${CUST_HADR_REMOTE_INST}" != "${Reg_HADR_REMOTE_INST}" ]
  then
    f_printWarning "db2 update db cfg for ${DBName} using HADR_REMOTE_INST ${Reg_HADR_REMOTE_INST}";retcode=1
  fi
  CUST_HADR_TIMEOUT=`cat ${WorkDir}/current_db.cfg | grep -i "HADR_TIMEOUT" | awk -F= '{print $2}'|sed s/[[:space:]]//g`
  if [ "${CUST_HADR_TIMEOUT}" != "${Reg_HADR_TIMEOUT}" ]
  then
    f_printWarning "db2 update db cfg for ${DBName} using HADR_TIMEOUT ${Reg_HADR_TIMEOUT}";retcode=1
  fi
  CUST_HADR_SYNCMODE=`cat ${WorkDir}/current_db.cfg | grep -i "HADR_SYNCMODE" | awk -F= '{print $2}'|sed s/[[:space:]]//g`
  if [ "${CUST_HADR_SYNCMODE}" != "${Reg_HADR_SYNCMODE}" ]
  then
    f_printWarning "db2 update db cfg for ${DBName} using HADR_SYNCMODE ${Reg_HADR_SYNCMODE}";retcode=1
  fi
  CUST_HADR_PEER_WINDOW=`cat ${WorkDir}/current_db.cfg | grep -i "HADR_PEER_WINDOW" | awk -F= '{print $2}'|sed s/[[:space:]]//g`
  if [ "${CUST_HADR_PEER_WINDOW}" != "${Reg_HADR_PEER_WINDOW}" ]
  then
    f_printWarning "db2 update db cfg for ${DBName} using HADR_PEER_WINDOW ${Reg_HADR_PEER_WINDOW}";retcode=1
  fi

}

retcode=0
f_db2licm_check
f_db2set_check
f_dbmcfg_check
f_dbcfg_check
exit $retcode
