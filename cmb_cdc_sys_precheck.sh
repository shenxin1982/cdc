#!/usr/bin/env ksh

function syntax
{
  echo "syntax:"
  echo "/usr/bin/su - root -c /usr/bin/sh <path>/cmb_cdc_sys_precheck.sh"
  echo
  echo " executed by root user"
  echo " where:"
  echo "   <path>          : is the full path to this script, normally"
  echo " Parameters: "

  echo " Samples: "
  echo "   cmb_cdc_sys_precheck.sh"
  exit 22
}

# os cfg
r_oslevel7="71000305"
r_oslevel6="61000905"
r_clevel="12100"
r_pagespace="8096"
r_oslevel_1=`oslevel|awk -F \. '{print $1}'`

## maxuproc cfg
r_maxuproc=4096;
## no cfg
r_sb_max=1310720;r_rfc1323=1;r_tcp_sendspace=1048576;r_tcp_recvspace=1048576;r_udp_sendspace=262144;r_udp_recvspace=262144;
r_ipqmaxlen=250;r_somaxconn=1024;r_tcp_keepidle=300;r_tcp_keepcnt=5;r_tcp_keepintvl=12;r_tcp_keepinit=120
## vmo cfg
r_minperm=5;r_maxperm=10;r_maxclient=10;r_strict_maxclient=1;r_strict_maxperm=1;r_lru_file_repage=0;r_v_pinshm=1
##ifconfig cfg
rf_rfc1323=1;rf_tcp_sendspace=1048576;rf_tcp_recvspace=1048576
##user cfg
rf_fsize="-1";rf_cpu="-1";rf_data="-1";rf_stack="-1";rf_rss="-1";rf_nofiles="-1";
rf_fsize_hard="-1";rf_cpu_hard="-1";rf_data_hard="-1";rf_stack_hard="-1";rf_rss_hard="-1";rf_nofiles_hard="-1";
rf_capabilities="CAP_BYPASS_RAC_VMM,CAP_PROPAGATE"

function f_printError
{
  echo "[Error]:$(date "+%Y%m%d.%H%M%S"):$1" |tee -a ${LogFile};
}

function f_printWarning
{
  echo "[Warn ]:$(date "+%Y%m%d.%H%M%S"):$1"|tee -a ${LogFile} ;
}

function f_printInfo
{
  echo "[Info ]:$(date "+%Y%m%d.%H%M%S"):$1"|tee -a ${LogFile} ;
}

function f_userinfo_check
{
  lsuser -c -a id ALL|awk -F: '{if($1!~"^#" && $2>500 && $2<10000) print $1}'| while read line
  do
    typeset i_fsize="$(/usr/bin/lssec -f /etc/security/limits -s ${line} -a fsize 2>/dev/null|awk -F= '{print $NF}')"
    if [ "${i_fsize}" -ne "${rf_fsize}" ];then
      f_printWarning "/usr/bin/chsec -f /etc/security/limits -s ${line} -a fsize=-1\n";
      retcode=1
    fi
    typeset i_cpu="$(/usr/bin/lssec -f /etc/security/limits -s ${line} -a cpu 2>/dev/null|awk -F= '{print $NF}')"
    if [ "${i_cpu}" -ne "${rf_cpu}" ];then
      f_printWarning "/usr/bin/chsec -f /etc/security/limits -s ${line} -a cpu=${rf_cpu}\n";
      retcode=1
    fi
    typeset i_data="$(/usr/bin/lssec -f /etc/security/limits -s ${line} -a data 2>/dev/null|awk -F= '{print $NF}')"
    if [ "${i_data}" -ne "${rf_data}" ];then
      f_printWarning "/usr/bin/chsec -f /etc/security/limits -s ${line} -a data=${rf_data}\n";
      retcode=1
    fi
    typeset i_stack="$(/usr/bin/lssec -f /etc/security/limits -s ${line} -a stack 2>/dev/null|awk -F= '{print $NF}')"
    if [ "${i_stack}" -ne "${rf_stack}" ];then
      f_printWarning "/usr/bin/chsec -f /etc/security/limits -s ${line} -a stack=${rf_stack}\n";
      retcode=1
    fi
    typeset i_rss="$(/usr/bin/lssec -f /etc/security/limits -s ${line} -a rss 2>/dev/null|awk -F= '{print $NF}')"
    if [ "${i_rss}" -ne "${rf_rss}" ];then
      f_printWarning "/usr/bin/chsec -f /etc/security/limits -s ${line} -a rss=${rf_rss}\n";
      retcode=1
    fi
    typeset i_nofiles="$(/usr/bin/lssec -f /etc/security/limits -s ${line} -a nofiles 2>/dev/null|awk -F= '{print $NF}')"
    if [ "${i_nofiles}" -ne "${rf_nofiles}" ];then
      f_printWarning "/usr/bin/chsec -f /etc/security/limits -s ${line} -a nofiles=${rf_nofiles}\n";
      retcode=1
    fi
    typeset i_nofiles_hard="$(/usr/bin/lssec -f /etc/security/limits -s ${line} -a nofiles_hard 2>/dev/null|awk -F= '{print $NF}')"
    if [ "${i_nofiles_hard}" -ne "${rf_nofiles_hard}" ];then
      f_printWarning "/usr/bin/chsec -f /etc/security/limits -s ${line} -a nofiles_hard=${rf_nofiles_hard}\n";
      retcode=1
    fi
    typeset i_rss_hard="$(/usr/bin/lssec -f /etc/security/limits -s ${line} -a rss_hard 2>/dev/null|awk -F= '{print $NF}')"
    if [ "${i_rss_hard}" -ne "${rf_rss_hard}" ];then
      f_printWarning "/usr/bin/chsec -f /etc/security/limits -s ${line} -a rss_hard=${rf_rss_hard}\n";
      retcode=1
    fi
    typeset i_stack_hard="$(/usr/bin/lssec -f /etc/security/limits -s ${line} -a stack_hard 2>/dev/null|awk -F= '{print $NF}')"
    if [ "${i_stack_hard}" -ne "${rf_stack_hard}" ];then
      f_printWarning "/usr/bin/chsec -f /etc/security/limits -s ${line} -a stack_hard=${rf_stack_hard}\n";
      retcode=1
    fi
    typeset i_data_hard="$(/usr/bin/lssec -f /etc/security/limits -s ${line} -a data_hard 2>/dev/null|awk -F= '{print $NF}')"
    if [ "${i_data_hard}" -ne "${rf_data_hard}" ];then
      f_printWarning "/usr/bin/chsec -f /etc/security/limits -s ${line} -a data_hard=${rf_data_hard}\n";
      retcode=1
    fi
    typeset i_cpu_hard="$(/usr/bin/lssec -f /etc/security/limits -s ${line} -a cpu_hard 2>/dev/null|awk -F= '{print $NF}')"
    if [ "${i_cpu_hard}" -ne "${rf_cpu_hard}" ];then
      f_printWarning "/usr/bin/chsec -f /etc/security/limits -s ${line} -a cpu_hard=${rf_cpu_hard}\n";
      retcode=1
    fi
    typeset i_fsize_hard="$(/usr/bin/lssec -f /etc/security/limits -s ${line} -a fsize_hard 2>/dev/null|awk -F= '{print $NF}')"
    if [ "${i_fsize_hard}" -ne "${rf_fsize_hard}" ];then
      f_printWarning "/usr/bin/chsec -f /etc/security/limits -s ${line} -a fsize_hard=${rf_fsize_hard}\n";
      retcode=1
    fi
    typeset i_capabilities=$(/usr/sbin/lsuser -a capabilities ${line} 2>/dev/null|awk -F= '/capabilities/{print $NF;exit}')
    if [ "${i_capabilities}" != "${rf_capabilities}" ];then
      f_printWarning "/usr/bin/chuser capabilities=$rf_capabilities ${line}\n";
      retcode=1
    fi
  done
}

function f_sysinfo_check
{
## system cfg and some generate infomation check
  i_oslevel=`oslevel -s|awk -F- '{print $1,$2,$3}'|sed s/' '//g`
  if [ ${r_oslevel_1} == 6 ] && [ ${i_oslevel} -lt ${r_oslevel6} ];then
    f_printWarning "oslevel is not meet the version\n";
    retcode=1
  fi
  if [ ${r_oslevel_1} == 7 ] && [ ${i_oslevel} -lt ${r_oslevel7} ];then
    f_printWarning "oslevel is not meet the version\n";
    retcode=1
  fi
  i_clevel=`lslpp -l|grep -i xlc.rte|awk '{print $2}'|awk -F. '{print $1,$2,$3,$4}'|sed s/' '//g`
  if [ ${i_clevel} -lt ${r_clevel} ];then
    f_printWarning "Clevel is not meet the version;Please upgrade the oslevel\n";
    retcode=1
  fi
  i_pagespace=`lsps -a|grep -v "^Page"|awk '{print $4}'|sed s/MB//g`
  if [ ${i_pagespace} -lt ${r_pagespace} ];then
    f_printWarning "Pagespace size is not meet the size;Please change the size\n";
    retcode=1
  fi
}

function f_syscfg_check
{
  i_maxuproc=`lsattr -El sys0|grep -i "^maxuproc"|awk '{print $2}'`
  if [ $i_maxuproc -lt $r_maxuproc ];then
    f_printWarning "chdev -l sys0 -a maxuproc=$r_maxuproc\n";
    retcode=1
  fi

##System no parameter config check
  no -a > ${WorkDir}/current_no.cfg
  i_sb_max=`cat ${WorkDir}/current_no.cfg|grep -i sb_max|awk -F \ = '{print $2}'`
  i_ipqmaxlen=`cat ${WorkDir}/current_no.cfg|grep -i ipqmaxlen|awk -F \ = '{print $2}'`
  i_somaxconn=`cat ${WorkDir}/current_no.cfg|grep -i somaxconn|awk -F \ = '{print $2}'`
  i_rfc1323=`cat ${WorkDir}/current_no.cfg|grep -i "rfc1323"|awk -F \ = '{print $2}'`
  i_tcp_sendspace=`cat ${WorkDir}/current_no.cfg|grep -i tcp_sendspace|awk -F \ = '{print $2}'`
  i_tcp_recvspace=`cat ${WorkDir}/current_no.cfg|grep -i tcp_recvspace|awk -F \ = '{print $2}'`
  i_udp_sendspace=`cat ${WorkDir}/current_no.cfg|grep -i udp_sendspace|awk -F \ = '{print $2}'`
  i_udp_recvspace=`cat ${WorkDir}/current_no.cfg|grep -i udp_recvspace|awk -F \ = '{print $2}'`
  i_tcp_keepidle=`cat ${WorkDir}/current_no.cfg|grep -i tcp_keepidle|awk -F \ = '{print $2}'`
  i_tcp_keepcnt=`cat ${WorkDir}/current_no.cfg|grep -i tcp_keepcnt|awk -F \ = '{print $2}'`
  i_tcp_keepintvl=`cat ${WorkDir}/current_no.cfg|grep -i tcp_keepintvl|awk -F \ = '{print $2}'`
  i_tcp_keepinit=`cat ${WorkDir}/current_no.cfg|grep -i tcp_keepinit|awk -F \ = '{print $2}'`

  if [ $i_sb_max -lt $r_sb_max ];then
    f_printWarning "no -p -o sb_max=$r_sb_max\n";retcode=1
  fi
  if [ ${i_ipqmaxlen} -lt ${r_ipqmaxlen} ];then
    f_printWarning "no -r -o ipqmaxlen=${r_ipqmaxlen}\n";retcode=1
  fi
  if [ $i_somaxconn -lt $r_somaxconn ];then
    f_printWarning "no -p -o somaxconn=$r_somaxconn\n";retcode=1
  fi
  if [ $i_rfc1323 -ne $r_rfc1323 ];then
    f_printWarning "no -p -o rfc1323=$r_rfc1323\n";retcode=1
  fi
  if [ $i_tcp_sendspace -lt $r_tcp_sendspace ];then
    f_printWarning "no -p -o tcp_sendspace=$r_tcp_sendspace\n";retcode=1
  fi
  if [ $i_tcp_recvspace -lt $r_tcp_recvspace ];then
    f_printWarning "no -p -o tcp_recvspace=$r_tcp_recvspace\n";retcode=1
  fi
  if [ $i_udp_sendspace -lt $r_udp_sendspace ];then
    f_printWarning "no -p -o udp_sendspace=$r_udp_sendspace\n";retcode=1
  fi
  if [ $i_udp_recvspace -lt $r_udp_recvspace ];then
    f_printWarning "no -p -o udp_recvspace=$r_udp_recvspace\n";retcode=1
  fi
  if [ $i_tcp_keepidle -lt $r_tcp_keepidle ];then
    f_printWarning "no -p -o tcp_keepidle=$r_tcp_keepidle\n";retcode=1
  fi
  if [ $i_tcp_keepcnt -lt $r_tcp_keepcnt ];then
    f_printWarning "no -p -o tcp_keepcnt=$r_tcp_keepcnt\n";retcode=1
  fi
  if [ $i_tcp_keepintvl -lt $r_tcp_keepintvl ];then
    f_printWarning "no -p -o tcp_keepintvl=$r_tcp_keepintvl\n";retcode=1
  fi
  if [ $i_tcp_keepinit -lt $r_tcp_keepinit ];then
    f_printWarning "no -p -o tcp_keepinit=$r_tcp_keepinit\n";retcode=1
  fi

## System vmo parameter check
  vmo -F -a >${WorkDir}/current_vmo.cfg
  i_minperm=`cat ${WorkDir}/current_vmo.cfg|grep -i minperm%|awk -F \ = '{print $2}'`
  i_maxperm=`cat ${WorkDir}/current_vmo.cfg|grep -i maxperm%|awk -F \ = '{print $2}'`
  i_maxclient=`cat ${WorkDir}/current_vmo.cfg|grep -i maxclient%|awk -F \ = '{print $2}'`
  i_strict_maxclient=`cat ${WorkDir}/current_vmo.cfg|grep -i strict_maxclient|awk -F \ = '{print $2}'`
  i_strict_maxperm=`cat ${WorkDir}/current_vmo.cfg|grep -i strict_maxperm|awk -F \ = '{print $2}'`
  i_lru_file_repage=`cat ${WorkDir}/current_vmo.cfg|grep -i lru_file_repage|awk -F \ = '{print $2}'`
  i_v_pinshm=`cat ${WorkDir}/current_vmo.cfg|grep -i v_pinshm|awk -F \ = '{print $2}'`
  i_range_perm=`expr $i_maxperm - $i_minperm`
  if [ $i_minperm -le $r_minperm ] && [ $i_maxperm -le $r_maxperm ] && [ $i_maxclient -le $i_maxperm ] && [ $i_range_perm -ge 2 ] ;then
    f_printWarning "# current minperm%=$i_minperm,current maxperm%=$i_maxperm,current maxclient%=$i_maxclient"
  else
    f_printWarning "vmo -p -o minperm%=$r_minperm maxperm%=$r_maxperm maxclient%=$r_maxclient\n";
    retcode=1
  fi
  if [ $i_strict_maxclient -gt $r_strict_maxclient ];then
    f_printWarning "vmo -p -o strict_maxclient=$r_strict_maxclient\n";retcode=1
  fi
  if [ $i_strict_maxperm -gt $r_strict_maxperm ];then
    f_printWarning "vmo -p -o strict_maxperm=$r_strict_maxperm\n";retcode=1
  fi
  if [ $r_oslevel_1 -eq 6 ] ;then
    if [ $i_lru_file_repage -ne $r_lru_file_repage ] ;then
    printf "vmo -p -o lru_file_repage=$r_lru_file_repage\n";retcode=1
    fi
  fi
  if [ $i_v_pinshm -ne $r_v_pinshm ];then
    f_printWarning "vmo -p -o v_pinshm=$r_v_pinshm\n";retcode=1
  fi

## network ifconfig parameter check
  ifconfig -l|tr ' ' '\n' |while read line
  do
    if_tcp_sendspace=`ifconfig $line|grep -i "rfc1323"|awk '{print $2}'`
    if_tcp_recvspace=`ifconfig $line|grep -i "rfc1323"|awk '{print $4}'`
    if_rfc1323=`ifconfig $line|grep -i "rfc1323"|awk '{print $6}'`
    if [ $if_rfc1323 -ne $rf_rfc1323 ];then
      f_printWarning "chdev -l $line -a rfc1323=$rf_rfc1323\n";retcode=1
    fi
    if [ $if_tcp_recvspace -ne $rf_tcp_recvspace ];then
      f_printWarning "chdev -l $line -a tcp_recvspace=$rf_tcp_recvspace\n";retcode=1
    fi
    if [ $if_tcp_sendspace -ne $rf_tcp_sendspace ];then
      f_printWarning "chdev -l $line -a tcp_sendspace=$rf_tcp_sendspace\n";retcode=1
    fi
  done
  rm ${WorkDir}/current_no.cfg
  rm ${WorkDir}/current_vmo.cfg
  return retcode
}


ShellName="$(echo $0|awk -F / '{print $NF}')"
WorkDir="$(echo $0|sed s/${ShellName}//g)"
[ -z "${WorkDir}" ] && WorkDir=$(pwd);cd ${WorkDir};WorkDir=$(pwd)
StartTime=$(date '+%Y%m%d.%H%M%S');
LogFile="${WorkDir}/cmb_cdc_sys_precheck.log.${StartTime}"

if [ ! -f ${LogFile} ]
then
     touch ${LogFile} || LogFile="/dev/null"
     [ "${LogFile}" != "/dev/null" ] && [ -f ${LogFile} ] && chmod 666 ${LogFile}
fi

retcode=0
f_sysinfo_check
f_syscfg_check
f_userinfo_check
exit $retcode
