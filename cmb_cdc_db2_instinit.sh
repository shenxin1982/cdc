#!/usr/bin/env ksh

function syntax
{
  echo "syntax:"
  echo " /usr/bin/su - root -c \"/usr/bin/sh <path>/cmb_cdc_db2_instinit.sh -ACTION <CREATE|DROP>  -VERSION <Version> -INSTNAME <InstName> -FENCNAME <FencName> -PRODINSTPATH <ProdInstPath>  \""
  echo
  echo " where:"
  echo "   <root>          : is the root account"
  echo "   <path>          : is the full path to this script, normally"
  echo " Parameters:"
  echo "   -ACTION         : "
      "         CREATE     :create instance"
      "         DROP       :Drop databases based on the instance and the instance"
  echo "   -VERSION        : version pattern.  It is  Optional"
  echo "   -INSTNAME       : The name of instance user "
  echo "   -FENCNAME       : The name of fence user  "
  echo "   -PRODINSTPATH   : The Install Path for the db2 product ,like /opt/IBM/db2/V10.5  "
  echo
  echo " Samples: "
  echo "   cmb_cdc_db2_instinit.sh -ACTION create -VERSION v10.5 -INSTNAME db2inst1 -FENCNAME db2fenc1 -SVCENAME 50000 -PRODINSTPATH /opt/IBM/db2/V10.5"
  echo "   cmb_cdc_db2_instinit.sh -ACTION drop -INSTNAME db2inst1"
  exit 22
}

function f_printError
{
  echo "[Error]:$(date "+%Y%m%d.%H%M%S"):$1" | tee -a ${LogFile};
}

function f_printWarning
{
  echo "[Warn ]:$(date "+%Y%m%d.%H%M%S"):$1" | tee -a ${LogFile};
}

function f_printInfo
{
  echo "[Info ]:$(date "+%Y%m%d.%H%M%S"):$1" | tee -a ${LogFile};
}


function f_crtinst
{
   f_printInfo " Check if DB2 user existing, version like pattern ${Version} "
   if [ -z "$(cat /etc/passwd | awk /${InstName}/)" ]
   then
     if [ ${InstName} == "cdcinst" ] && [ ${FencName} == "cdcfenc" ];then
       retcode=0;
       MaxGID=$(lsgroup -c -a id ALL|awk -F: 'BEGIN{id=500}{if($1!~"^#" && $2<=1000 && id<$2)id=$2}END{print id}');
       CGroupID=`expr ${MaxGID} + 1`
       FGroupID=`expr ${MaxGID} + 1`
       /usr/bin/mkgroup id=${CGroupID} cdcgrp
       /usr/bin/mkgroup id=${FGroupID} cdcfgrp
       retcode=$?
       MaxUID=$(lsuser -c -a id ALL|awk -F: 'BEGIN{id=500}{if($1!~"^#" && $2<=1000 && id<$2)id=$2}END{print id}');
       CUserID=`expr ${MaxUID} + 1`
       FUserID=`expr ${MaxUID} + 2`
       mkdir -p /home/cdcinst
       mkdir -p /home/cdcfenc
       /usr/bin/mkuser id=${CUserID} pgrp=cdcgrp home=/home/cdcinst cdcinst
       chown -R cdcinst:cdcgrp /home/cdcinst
       retcode=$?
       /usr/bin/mkuser id=${FUserID} pgrp=cdcfgrp home=/home/cdcfenc cdcfenc
       chown -R cdcfenc:cdcfgrp /home/cdcfenc
       echo $retcode
     else
       f_printError " There is NO account ${InstName}, pls create it first. "
       rc=-1
       return ${rc}
     fi
   else
     _instHome="$(cat /etc/passwd|grep ${InstName}|awk -F ':' '{print $6}')"
     if [ ! -z ${_instHome} ] && [ -x "${_instHome}/sqllib/db2profile" ]
     then
       f_printError " DB2 instance existing on this account ${InstName}, home is ${_instHome} "
       rc=-1
       return ${rc}
     fi
   fi

   f_printInfo " Check if DB2 Instance existing ... "

   if [ -z "${ProdInstPath}" ]
   then
     f_printError " Do NOT find DB2 images installed like pattern ${Version} "
     rc=-1
     return ${rc}
   fi

   if [ -x "${ProdInstPath}/instance/db2ilist" ]
   then
     f_printInfo " ${ProdInstPath}/instance/db2ilist |grep -i ${InstName}"
     if [ ! -z "$(${ProdInstPath}/instance/db2ilist |grep -i ${InstName})" ]
     then
        f_printInfo " The instance ${InstName} existing,  cancel creating."
        rc=0
        return ${rc}
     else
        f_printInfo " Creating instance ${InstName} from DB2 Version ${ProdInstPath} "
        f_printInfo "${ProdInstPath}/instance/db2icrt -u ${FencName} ${InstName} "
        ${ProdInstPath}/instance/db2icrt -u ${FencName} ${InstName} >> ${LogFile}
        rc=$?
     fi
  else
    f_printError " Can not executing ${_db2Dir}/instance/db2ilist "
    rc=-1
  fi

  case ${rc} in
     0) su - ${InstName} -c "db2start" | tee -a ${LogFile};
        su - ${InstName} -c "db2 update dbm cfg using SVCENAME ${SvceName}"| tee -a ${LogFile} ;
        su - ${InstName} -c "db2set DB2COMM=TCPIP" | tee -a ${LogFile};
        su - ${InstName} -c "db2stop force;db2start" | tee -a ${LogFile};
        f_printInfo "    Successfully!!! " ;;
     *) f_printError "   Failed!!! " ;;
  esac

  return ${rc}

}

function f_dropdb
{
   rc=0
   f_printInfo " Start DB2 first ... "
   su -  ${InstName} -c "db2start" 2>&1 | tee -a ${LogFile}
   _dbList="$(su - ${InstName} -c db2 list db directory | grep 'Database name' | awk '{print $NF}')"
   [ -z ${_dbList} ] && f_printWarning " There is no DATABASE need to be droped." && return ${rc};

   for _dbname in ${_dbList}
   do
      f_printInfo " db2 force applications"
      db2 "list applications"|grep -w "${DBName}"|awk '{print $2}'|while read agentid
      do
        db2 -v "force application (${agentid})"| tee -a ${LogFile}
      done
      db2 "force applications all"| tee -a ${LogFile}
      f_printInfo "  db2 drop database ${_dbname} "
      su - ${InstName} -c db2 drop database ${_dbname} 2>&1 >> ${LogFile}
      rc=$?
      if [ ${rc} -ne 0 ]
      then
          f_printError " Failed!!! "
          return ${rc}
      else
          f_printInfo "  Successfully!!! "
      fi
   done
   return ${rc}
}


function f_dropinst
{
   if [ "${InstName}" != "cdcinst" ];then
     f_printError "Drop the Error inst!!"
     exit -1
   fi
   f_printInfo "  Check and make sure no databases ... "
   if [ -z "$(su - ${InstName} -c db2 list db directory | awk /SQL1057W\|SQL1031N/)" ]
   then
     f_printError "   There is(are) database(s) under the instance ${InstName}. Drop Database first. "
     f_dropdb
   fi


   f_printInfo "  Check if the instance ${InstName} is running .. "

   _instName=$(ps -ef | grep -i db2sysc | grep -i ${InstName} | awk '{print $1}')
   if [ ${_instName} == ${InstName} ]
   then
      su - ${InstName} -c "db2stop force"
   fi

   f_printInfo " Drop instance ${InstName} "
   _prodInstPath=$(su - ${InstName} -c "db2level" | grep "Product is installed at" | awk -F '"' '{print $2}')
   f_printInfo " ${_prodInstPath}/instance/db2idrop ${InstName} "
   ${_prodInstPath}/instance/db2idrop ${InstName} >> ${LogFile}
   rc=$?

  case ${rc} in
     0) f_printInfo "    Successfully!!! ";;
     *) f_printError "   Failed!!! " ;;
  esac

  return ${rc}

}




typeset ShellOption="$@"
for inopt in ${ShellOption}
do
  case $(echo $inopt|tr a-z A-Z) in
    -ACTION) CurOpt="-ACTION";continue;;
    -VERSION) CurOpt="-VERSION";continue;;
    -INSTNAME) CurOpt="-INSTNAME";continue;;
    -FENCNAME) CurOpt="-FENCNAME";continue;;
    -SVCENAME) CurOpt="-SVCENAME";continue;;
    -PRODINSTPATH) CurOpt="-PRODINSTPATH";continue;;
    -H|-*) syntax;return -1;;
  esac
  case "${CurOpt}" in
    -ACTION) Action=`echo ${inopt}| tr a-z A-Z`;;
    -VERSION) Version="${inopt}";;
    -INSTNAME) InstName="${inopt}";;
    -FENCNAME) FencName="${inopt}";;
    -SVCENAME) SvceName="${inopt}";;
    -PRODINSTPATH) ProdInstPath="${inopt}";;
  esac
done

[ -z "${Action}" ] && syntax  ||[ -z "${InstName}" ] && syntax


ShellName="$(echo $0|awk -F / '{print $NF}')"
WorkDir="$(echo $0|sed s/${ShellName}//g)"
[ -z "${WorkDir}" ] && WorkDir=$(pwd);cd ${WorkDir};WorkDir=$(pwd)
HostName=$(hostname);StartTime=$(date '+%Y%m%d.%H%M%S');
LogFile="${WorkDir}/cmb_cdc_db2_instinit.log.${StartTime}"

if [ ! -f ${LogFile} ]
then
     touch ${LogFile} || LogFile="/dev/null"
     [ "${LogFile}" != "/dev/null" ] && [ -f ${LogFile} ] && chmod 666 ${LogFile}
fi

rc=0

case ${Action} in
  CREATE) f_crtinst;;
  DROP) f_dropinst;;
esac


exit ${rc}
