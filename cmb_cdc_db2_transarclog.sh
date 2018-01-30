#!/usr/bin/env ksh

function syntax
{
  echo "syntax:"
  echo " /usr/bin/su - <instuser> -c \"/usr/bin/sh <path>/cmb_cdc_db2_arclogftp.sh  -ACTION <upload/download> -FILEPATH <FilePath>\n "
  echo " -BEGINNUM <BeginNum>  -ENDNUM <EndNum> -FTPSERVER <FtpServer> -FTPUSER <FtpUser> -FTPPASSWD <FtpPasswd> \" "
  echo
  echo " where:"
  echo "   <instuser>   : is the owner of the instance."
  echo "   <path>      : is the full path to this script, normally"
  echo " Parameters: "
  echo "   <Action>      : upfull|updelta|downfull|downdelta "
  echo "       upfull    :   export the table full to local and ftp it to the ftp server "
  echo "       downfull  :   download the table full data from ftp server and load it replace into the table "
  echo "    "
  echo "     "
  echo "     "
  echo "   Sample  :   "
  echo "        ftp_cmb.sh -ACTION upfull -dbname testdb -tabname db2inst1.test"

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



function f_ftpupload
{
  ArclogListFile=/tmp/arcloglistfile
  >${ArclogListFile}
  while [ ${BeginNum} -lt ${EndNum} ];
  do
    BeginNum=$((${BeginNum}+1))
    ArcLogNum=$((100000000+${BeginNum}))
    ArcLogNum=`echo ${ArcLogNum}|cut -c2-9`
    ArcLogName="S"${ArcLogNum}".LOG"
    echo ${ArcLogName} >> ${ArclogListFile}
  done
  ArcLogFile=`cat ${ArclogListFile}|tr '\n' ''`
  ArcLogFile1="${ArcLogFile}"
ftp -v -n <<!
  open ${FtpServer} 21
  user ${FtpUser} ${FtpPasswd}
  bin
  lcd ${FilePath}
  mput ${ArcLogFile1}
  quit
!
}

function f_ftpdownload
{
  ArclogListFile=/tmp/arcloglistfile
  >${ArclogListFile}
  while [ ${BeginNum} -lt ${EndNum} ];
  do
    BeginNum=$((${BeginNum}+1))
    ArcLogNum=$((100000000+${BeginNum}))
    ArcLogNum=`echo ${ArcLogNum}|cut -c2-9`
    ArcLogName="S"${ArcLogNum}".LOG"
    echo $ArcLogName >> ${ArcloglistFile}
  done
  ArcLogFile=`echo $ArcloglistFile`

ftp -v -n <<!
  open ${FtpServer} 21
  user ${FtpUser} ${FtpPasswd}
  bin
  lcd ${FilePath}
  mget $ArcLogFile
  quit
!
}


typeset ShellOption="$@"

for inopt in ${ShellOption}
do
  case $(echo $inopt|tr a-z A-Z) in
    -ACTION) CurOpt="-ACTION";continue;;
    -FILEPATH) CurOpt="-FILEPATH";continue;;
    -BEGINNUM) CurOpt="-BEGINNUM";continue;;
    -ENDNUM) CurOpt="-ENDNUM";continue;;
    -FTPSERVER) CurOpt="-FTPSERVER";continue;;
    -FTPUSER) CurOpt="-FTPUSER";continue;;
    -FTPPASSWD) CurOpt="-FTPPASSWD";continue;;
    -H|-*) syntax;return -1;;
  esac
  case "${CurOpt}" in
    -ACTION) Action=`echo ${inopt}| tr a-z A-Z`;;
    -FILEPATH) FilePath="${inopt}";;
    -BEGINNUM) BeginNum="${inopt}";;
    -ENDNUM) EndNum="${inopt}";;
    -FTPSERVER) FtpServer="${inopt}";;
    -FTPUSER) FtpUser="${inopt}";;
    -FTPPASSWD) FtpPasswd="${inopt}";;
  esac
done

[ -z "${Action}" ] && syntax || [ -z "${FilePath}" ] && syntax
[ -z "${BeginNum}" ] && syntax ||[ -z "${EndNum}" ] && syntax ||

FtpServer=9.110.78.47
FtpUser=root
FtpPasswd=rootroot

ShellName="$(echo $0|awk -F / '{print $NF}')"
WorkDir="$(echo $0|sed s/${ShellName}//g)"
[ -z "${WorkDir}" ] && WorkDir=$(pwd);cd ${WorkDir};WorkDir=$(pwd)
StartTime=$(date '+%Y%m%d.%H%M%S');

LogFile="${WorkDir}/ftp_cmb.log.${StartTime}"


if [ ! -f ${LogFile} ]
then
     touch ${LogFile} || LogFile="/dev/null"
     [ "${LogFile}" != "/dev/null" ] && [ -f ${LogFile} ] && chmod 666 ${LogFile}
fi

rc=0

case ${Action} in
  UPLOAD) f_ftpupload;;
  DOWNLOAD) f_ftpdownload;;
esac

exit ${rc}
