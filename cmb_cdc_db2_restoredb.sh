#!/usr/bin/env ksh

function syntax
{
  echo "syntax:"
  echo
  echo " /usr/bin/su - <InstName> -c \"/usr/bin/sh <path>/cmb_cdc_db2_restoredb.sh -INSTNAME <InstName> -DBNAME <DBName> -FILEPATH <FilePath> -NEWDBNAME <DBName> -TIMESTAMP <TimeStamp>"
  echo " "
  echo " where:"
  echo "   <InstName>   : is the owner of the DB2 instance."
  echo "   <path>          : is the full path to this script, normally"
  echo " Parameters: "
  echo "   <InstName>   : Name of the instance "
  echo "   <DBName>     : Name of the database "
  echo "   <FilePath>   : Backup image path "
  echo "   <TimeStamp>  : backup image timestamp "
  echo
  echo " Example: "
  echo "   cmb_cdc_db2_restoredb.sh -INSTNAME db2inst1 -DBNAME testdb1 -FILEPATH /tmp -NEWDBNAME testdb9 -TIMESTAMP <Timestamp> "
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


function f_modifyRedirectFile2
{
  f_printInfo " Function f_modifyRedirectFile begin ... " | tee -a ${LogFile}
  _orgRedFile="${WorkDir}/${DBName}.redirect"
  [ ! -f ${_orgRedFile} ] && f_printError " Do not find file ${_orgRedFile} " | tee -a ${LogFile}
  NewRedirectFile="${WorkDir}/${DBName}.redirect.new"
  [ -f ${NewRedirectFile} ] && rm -f  ${NewRedirectFile}
  touch  ${NewRedirectFile}
  NewRedirectFileTmp="${WorkDir}/${DBName}.redirect.new.tmp"
  typeset NodeNum=$(grep "UPDATE COMMAND OPTIONS USING" ${_orgRedFile} | sed 's/.*_\(NODE[0-9]\{4\}\)\.out.*/\1/')
  cat ${_orgRedFile} | sed  "s/^-- ON .*/ON '\/db\/dbdata' /" > ${NewRedirectFileTmp}
  cat ${NewRedirectFileTmp} | sed  "s/^-- DBPATH ON .*/DBPATH ON '\/db\/dbdata'  /" > ${NewRedirectFile}
  mv ${NewRedirectFile} ${NewRedirectFileTmp}
  cat ${NewRedirectFileTmp} | sed "s/INTO.*/INTO ${NewDBName}/" > ${NewRedirectFile}
  _NewLogPath=" NEWLOGPATH '${_DBActlogPath}/${InstName}/${NewDBName}/'"
  cat ${NewRedirectFile} | sed "s#.*NEWLOGPATH.*#$_NewLogPath#" >  ${NewRedirectFileTmp}
  mv ${NewRedirectFileTmp} ${NewRedirectFile}
  cat ${NewRedirectFile}  | awk "/SET TABLESPACE CONTAINERS FOR/" | while read line
  do
    if [[ ! -z ${line} ]]
    then
      _TblspaceStr=T$(printf "%07d" $(echo ${line} | sed "s/SET TABLESPACE CONTAINERS FOR \([0-9]*\)/\1/" ))
      typeset _modify="N"; typeset _i=0
      cat  ${NewRedirectFile}  | awk "/SET TABLESPACE CONTAINERS FOR/||/'\/[a-zA-Z]*/" | while read inline
      do
        [[ "${line}" == "${inline}" ]] && typeset _modify="Y" && continue
        if [[ "${_modify}" == "Y" ]]
        then
          [[ ! -z $(echo ${inline} | awk '/SET TABLESPACE CONTAINERS FOR/') ]] && typeset _modify="N" && break
          _ContainerFileStr=C$(printf "%07d" ${_i}).LRG
          _ContainerPathStr=SQLT$(printf "%04d" ${_i}).0
          #echo $_ContainerFileStr
          if [[ ! -z $( echo ${inline} | awk '/^ *FILE/' ) ]]
          then
            _Pages=$(echo ${inline} | sed 's/^ *FILE.*[ ]\([0-9]*\)/\1/')
            _modifiedLine=" FILE '${_DBPath}/${InstName}/${NodeNum}/${NewDBName}/${_TblspaceStr}/${_ContainerFileStr}' ${_Pages}  "
          elif [[ ! -z $( echo ${inline} | awk '/^ *, *FILE/' ) ]]
          then
            _Pages=$(echo ${inline} | sed 's/^ *, *FILE.*[ ]\([0-9]*\)/\1/')
            _modifiedLine=", FILE '${_DBPath}/${InstName}/${NodeNum}/${NewDBName}/${_TblspaceStr}/${_ContainerFileStr}' ${_Pages}  "
          elif [[ ! -z $( echo ${inline} | awk '/^ *PATH/' ) ]]
          then
            _modifiedLine=" PATH '${_DBPath}/${InstName}/${NodeNum}/${NewDBName}/${_TblspaceStr}/${_ContainerPathStr}'  "
          elif [[ ! -z $( echo ${inline} | awk '/^ *, *PATH/' ) ]]
          then
            _modifiedLine=", PATH '${_DBPath}/${InstName}/${NodeNum}/${NewDBName}/${_TblspaceStr}/${_ContainerPathStr}'  "
          fi
          #echo "${_modifiedLine}"
          #echo $_Pages

          typeset _i=$((_i+1))
          cat ${NewRedirectFile} | sed "s#$inline#$_modifiedLine#" >  ${NewRedirectFileTmp}
          mv ${NewRedirectFileTmp} ${NewRedirectFile}
        fi
      done
    fi
  done
  cat ${NewRedirectFile} | sed "s/.*WITHOUT PROMPTING/WITHOUT PROMPTING/" > ${NewRedirectFileTmp}
  mv ${NewRedirectFileTmp} ${NewRedirectFile}
  f_printInfo " Function f_modifyRedirectFile end! " | tee -a ${LogFile}
  f_printInfo " New resotre redirect file ${NewRedirectFile} was created. " | tee -a ${LogFile}
}

function f_updatedbcfg
{
  if [ -z "${_DBArchm1Path}" ]
  then
    f_printError " No Directory for LOGARCHMETH1 " | tee -a ${LogFile}
    return -1
  else
     _LOGARCHMETH1="DISK:${_DBArchm1Path}/"
  fi
  if [ -z "${_DBArchm2Path}" ]
  then
     f_printWarning  " No Directory for LOGARCHMETH2 " | tee -a ${LogFile}
  else
     _LOGARCHMETH2=" LOGARCHMETH2 DISK:${_DBArchm2Path}/"
  fi
  if [ -z "${_DBMirlogPath}" ]
  then
      f_printWarning " No Directory for MIRRORLOGPATH " | tee -a ${LogFile}
  else
     _MIRRORLOGPATH=" MIRRORLOGPATH ${_DBMirlogPath}/${InstName}/${NewDBName}/NODE0000/"
     if [ ! -d ${_MIRRORLOGPATH} ]
     then
       mkdir -p ${_MIRRORLOGPATH}
       rc=$?
       if [ ${rc} -ne 0 ]
       then
          f_printError " update db cfg failed.  Failed on create directory ${_MIRRORLOGPATH} " | tee -a ${LogFile}
          return ${rc}
       fi
     fi
  fi
  _updateCommand="db2 update db cfg for ${NewDBName} using LOGARCHMETH1 ${_LOGARCHMETH1} ${_LOGARCHMETH2} ${_MIRRORLOGPATH} "
#  f_printInfo " db2 update db cfg for ${NewDBName} using  MIRRORLOGPATH ${_MIRRORLOGPATH} LOGARCHMETH1 ${_LOGARCHMETH1} LOGARCHMETH2 ${_LOGARCHMETH2} " | tee -a ${LogFile}
  f_printInfo " ${_updateCommand} " | tee -a ${LogFile}
#  su - ${InstName} -c db2 update db cfg for ${NewDBName} using MIRRORLOGPATH ${_MIRRORLOGPATH} LOGARCHMETH1 ${_LOGARCHMETH1} LOGARCHMETH2 ${_LOGARCHMETH2}  2>&1 >> ${LogFile}
  ${_updateCommand} 2>&1 >> ${LogFile}
  rc=$?
  case ${rc} in
    0) f_printInfo " Successfully update db cfg. "| tee -a ${LogFile};;
    *) f_printError " Failed update db cfg. " | tee -a ${LogFile};;
  esac
  return ${rc}
}

function f_updatedbmcfg
{
   _DIAGPATH="${_DBDiagPath}/${UserName}"
   if [ ! -d ${_DIAGPATH} ]
   then
     mkdir -p ${_DIAGPATH}
     rc=$?
         if [ ${rc} -ne 0 ]
    then
       f_printError " update dbm cfg failed.  Failed on create directory ${_DIAGPATH} " | tee -a ${LogFile}
       return ${rc}
    fi
   fi

  db2 update dbm cfg using DIAGPATH ${_DIAGPATH} 2>&1 >> ${LogFile}
  rc=$?

  case ${rc} in
    0) f_printInfo " Successfully update dbm cfg. "| tee -a ${LogFile};;
    *) f_printError " Failed update dbm cfg. " | tee -a ${LogFile};;
  esac
  return ${rc}
}


function f_restore2
{
   f_modifyRedirectFile2
   _NEWLOGPATH="${_DBActlogPath}/${InstName}/${NewDBName}/NODE0000/"
   if [ ! -d ${_NEWLOGPATH} ]
   then
     mkdir -p  ${_NEWLOGPATH}
     rc=$?
         if [ ${rc} -ne 0 ]
    then
       f_printError " Failed on create directory ${_NEWLOGPATH} " | tee -a ${LogFile}
       return ${rc}
    fi
   fi
   if [ ! -z "$(db2level |  awk '/DB2 v9.1/')" ]; then
     db2setcodepage=$(db2set | grep -i db2codepage | awk -F '=' {'print $2'})
     db2set DB2CODEPAGE=
     db2 terminate
   fi
   f_printInfo " restore database ${DBName} continue " | tee -a ${LogFile}
   f_printInfo " db2 -tvf ${NewRedirectFile} " | tee -a ${LogFile}
   db2 -tvf ${NewRedirectFile} >> ${LogFile}
   rc=$?
   case ${rc} in
     0|2) f_printInfo "    Successfully!!!  " | tee -a ${LogFile} ;;
     *) f_printError "     Failed!!! " | tee -a ${LogFile}; return ${rc} ;;
   esac
   db2 rollforward database ${NewDBName} query status using local time  | tee -a ${LogFile}
   if [ ! -z "$(db2level |  awk '/DB2 v9.1/')" ]; then
     db2set DB2CODEPAGE=${db2setcodepage}
     db2 terminate
   fi
   f_updatedbcfg
   rc=$?
   if [ ${rc} -ne 0 ]
   then
      f_printError "   Failed update db cfg ." | tee -a ${LogFile}
      return ${rc}
   else
      f_printInfo "   Successfully update db cfg. " | tee -a ${LogFile}
   fi
   f_updatedbmcfg
   rc=$?
   if [ ${rc} -ne 0 ]
   then
      f_printError "   Failed update dbm cfg ." | tee -a ${LogFile}
      return ${rc}
   else
      f_printInfo "   Successfully update dbm cfg. " | tee -a ${LogFile}
   fi
   return ${rc}
}

function f_restore
{
   f_printInfo "  Restore database redirect begin ... " | tee -a ${LogFile}
   rc=0
   typeset -i _fileNum=`ls -l  ${FilePath} | awk "/${DBName}.0./" | wc -l`
   if [ ${_fileNum} -eq 0 ]
   then
      f_printError " There is no database backup image files in directory ${FilePath} " | tee -a ${LogFile}
      rc=-1
      return ${rc}
   else
      if [ ! -z "$(db2level |  awk '/DB2 v9.1/')" ]; then
        db2setcodepage=$(db2set | grep -i db2codepage | awk -F '=' {'print $2'})
        db2set DB2CODEPAGE=
        db2 terminate
      fi
      if [ -f ${WorkDir}/${DBName}.redirect ]; then
         rm -f ${WorkDir}/${DBName}.redirect
      fi
      f_printInfo " restore database ${DBName} from ${FilePath} taken at ${TimeStamp} redirect generate script ${WorkDir}/${DBName}.redirect " | tee -a ${LogFile}
      db2 -v "restore database ${DBName} from ${FilePath} taken at ${TimeStamp} redirect generate script ${WorkDir}/${DBName}.redirect" | tee -a ${LogFile}
      if [ ! -z "$(db2level |  awk '/DB2 v9.1/')" ]; then
        db2set DB2CODEPAGE=${db2setcodepage}
        db2 terminate
      fi
   fi
   f_restore2
}


ShellName="$(echo $0|awk -F / '{print $NF}')"
WorkDir="$(echo $0|sed s/${ShellName}//g)"
[ -z "${WorkDir}" ] && WorkDir=$(pwd);cd ${WorkDir};WorkDir=$(pwd)
HostName=$(hostname);UserName=$(whoami);StartTime=$(date '+%Y%m%d.%H%M%S')

typeset ShellOption="$@"

NewRedirectFile=""
db2setcodepage=""

for inopt in ${ShellOption}
do
  case $(echo $inopt|tr a-z A-Z) in
    -INSTNAME) CurOpt="-INSTNAME";continue;;
    -DBNAME) CurOpt="-DBNAME";continue;;
    -FILEPATH) CurOpt="-FILEPATH";continue;;
    -NEWDBNAME) CurOpt="-NEWDBNAME";continue;;
    -TIMESTAMP) CurOpt="-TIMESTAMP";continue;;
    -H|-*) syntax;return -1;;
  esac
  case "${CurOpt}" in
    -DBNAME) DBName=`echo ${inopt}| tr a-z A-Z`;;
    -FILEPATH) FilePath="${inopt}";;
    -NEWDBNAME) NewDBName=`echo ${inopt}| tr a-z A-Z`;;
    -INSTNAME) InstName="${inopt}";;
    -TIMESTAMP) TimeStamp="${inopt}";;
  esac
done
[ -z "${DBName}" ] && syntax || [ -z "${InstName}" ] && syntax
[ -z "${FilePath}" ] && FilePath="${WorkDir}"

LogFile="${WorkDir}/cmb_cdc_db2_restoredb.log.${StartTime}"

if [ ! -f ${LogFile} ]
then
  touch ${LogFile} || LogFile="/dev/null"
  [ "${LogFile}" != "/dev/null" ] && [ -f ${LogFile} ] && chmod 666 ${LogFile}
fi


typeset _DBPath=$(df -g | awk '{if($NF~"/dbdata"){print $NF;exit}}')
typeset _DBActlogPath=$(df -g | awk '{if($NF~"/actlog"){print $NF;exit}}')
typeset _DBMirlogPath=$(df -g | awk '{if($NF~"/mirlog"){print $NF;exit}}')
typeset _DBArchm1Path=$(df -g | awk '{if($NF~"/archm1"){print $NF;exit}}')
typeset _DBArchm2Path=$(df -g | awk '{if($NF~"/archm2"){print $NF;exit}}')
typeset _DBDiagPath=$(df -g | awk '{if($NF~"/dbdiag"){print $NF;exit}}')

[ -z "${_DBPath}" ] && f_printError " Error!  There is no expected directory 'dbdata' " && exit -1
[ -z "${_DBActlogPath}" ] && f_printError "Error! There is no expected directory 'actlog' " && exit -1
[ -z "${_DBMirlogPath}" ] && f_printWarning "Error! There is no expected directory 'mirlog' "
[ -z "${_DBArchm1Path}" ] && f_printError "Error! There is no expected directory 'archm1' " && exit -1
[ -z "${_DBArchm2Path}" ] && f_printWarning "Error! There is no expected directory 'archm2' "
[ -z "${_DBDiagPath}" ] && f_printError "Error! There is no expected directory 'dbdiag' " && exit -1

rc=0
f_restore
exit ${rc}
