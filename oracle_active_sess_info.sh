# ##########################################################################################################
# Script to show all Active Sessions info.#
#
# ##########################################################################################################
export SCRIPT_NAME="active_sessions"

# ##################
# VARIABLES SECTION:
# ##################

# SQLPlus linesize
export OPTIMIZER="/*+RULE*/"
export SQLLINESIZE=190

# Excluded Modules from Active Sessions List:
EXCLUDED_MODULES="'OGG-USE_OCI_THREAD','OGG-OCI_META_THREAD'"
EXCLUDED_MODULES="'xxxxx'"

# Excluded Events from Active Sessions List:
EXCLUDED_EVENTS="
'SQL*Net message from client'
,'class slave wait'
,'PL/SQL lock timer'
,'rdbms ipc message'
,'OFS idle'
,'Space Manager: slave idle wait'
,'PX Deq: Execute Reply'
,'PX Deq: Execution Msg'
,'Streams AQ: waiting for messages in the queue'
,'Streams capture: waiting for archive log'
,'Streams AQ: waiting for time management or cleanup tasks'
,'LogMiner client: transaction'
,'LogMiner preparer: idle'
,'LogMiner builder: idle'
,'LogMiner reader: redo (idle)'
,'LogMiner merger: idle'
"


# #######################################
# Excluded INSTANCES:
# #######################################
# Here you can mention the instances the script will IGNORE and will NOT run against:
# Use pipe "|" as a separator between each instance name.
# e.g. Excluding: -MGMTDB, ASM instances:

EXL_DB="\-MGMTDB|ASM|APX"                           #Excluded INSTANCES [Will not get reported offline].


# ##############################
# SCRIPT ENGINE STARTS FROM HERE ............................................
# ##############################

# #########################
# Check if the OS is Linux: [Disaply the RMAN PAUSE/RESUME command if a backup is currently running]
# #########################
case `uname` in
        Linux ) export SHOW_OS_COMMAND="";;
	*)	export SHOW_OS_COMMAND="--";;
esac



# ###########################
# Listing Available Databases:
# ###########################

# Count Instance Numbers:
INS_COUNT=$( ps -ef|grep pmon|grep -v grep|egrep -v ${EXL_DB}|wc -l )

# Exit if No DBs are running:
if [ $INS_COUNT -eq 0 ]
 then
   echo "No Database is Running !"
   echo
   return
fi

# If there is ONLY one DB set it as default without prompt for selection:
if [ $INS_COUNT -eq 1 ]
 then
   export ORACLE_SID=$( ps -ef|grep pmon|grep -v grep|egrep -v ${EXL_DB}|awk '{print $NF}'|sed -e 's/ora_pmon_//g'|grep -v sed|grep -v "s///g" )

# If there is more than one DB ASK the user to select:
elif [ $INS_COUNT -gt 1 ]
 then
    echo
    echo "Select the ORACLE_SID:[Enter the number]"
    echo "---------------------"
    select DB_ID in $( ps -ef|grep pmon|grep -v grep|egrep -v ${EXL_DB}|awk '{print $NF}'|sed -e 's/ora_pmon_//g'|grep -v sed|grep -v "s///g" )
     do
                integ='^[0-9]+$'
                if ! [[ ${REPLY} =~ ${integ} ]] || [ ${REPLY} -gt ${INS_COUNT} ] || [ ${REPLY} -eq 0 ]
                        then
                        echo
                        echo "Error: Not a valid number!"
                        echo
                        echo "Enter a valid NUMBER from the displayed list !: i.e. Enter a number from [1 to ${INS_COUNT}]"
                        echo "----------------------------------------------"
                else
                        export ORACLE_SID=$DB_ID
                        echo 
                        printf "`echo "Selected Instance: ["` `echo -e "\033[33;5m${DB_ID}\033[0m"` `echo "]"`\n"
                        echo
                        break
                fi
     done

fi
# Exit if the user selected a Non Listed Number:
        if [ -z "${ORACLE_SID}" ]
         then
          echo "You've Entered An INVALID ORACLE_SID"
          exit
        fi



# #########################
# Getting ORACLE_HOME
# #########################
  ORA_USER=`ps -ef|grep ${ORACLE_SID}|grep pmon|grep -v grep|egrep -v ${EXL_DB}|grep -v "\-MGMTDB"|awk '{print $1}'|tail -1`
  USR_ORA_HOME=`grep -i "^${ORA_USER}:" /etc/passwd| cut -f6 -d ':'|tail -1`

# SETTING ORATAB:
if [ -f /etc/oratab ]
  then
ORATAB=/etc/oratab
export ORATAB
## If OS is Solaris:
elif [ -f /var/opt/oracle/oratab ]
  then
ORATAB=/var/opt/oracle/oratab
export ORATAB
fi

# ATTEMPT1: Get ORACLE_HOME using pwdx command:
export PGREP=`which pgrep`
export PWDX=`which pwdx`
if [[ -x ${PGREP} ]] && [[ -x ${PWDX} ]]
then
PMON_PID=`pgrep  -lf _pmon_${ORACLE_SID}|awk '{print $1}'`
export PMON_PID
ORACLE_HOME=`pwdx ${PMON_PID} 2>/dev/null|awk '{print $NF}'|sed -e 's/\/dbs//g'`
export ORACLE_HOME
fi

# ATTEMPT2: If ORACLE_HOME not found get it from oratab file:
if [ ! -f ${ORACLE_HOME}/bin/sqlplus ]
 then
## If OS is Linux:
if [ -f /etc/oratab ]
  then
ORATAB=/etc/oratab
ORACLE_HOME=`grep -v '^\#' ${ORATAB} | grep -v '^$'| grep -i "^${ORACLE_SID}:" | perl -lpe'$_ = reverse' | cut -f3 | perl -lpe'$_ = reverse' |cut -f2 -d':'`
export ORACLE_HOME

## If OS is Solaris:
elif [ -f /var/opt/oracle/oratab ]
  then
ORATAB=/var/opt/oracle/oratab
ORACLE_HOME=`grep -v '^\#' ${ORATAB} | grep -v '^$'| grep -i "^${ORACLE_SID}:" | perl -lpe'$_ = reverse' | cut -f3 | perl -lpe'$_ = reverse' |cut -f2 -d':'`
export ORACLE_HOME
fi
fi

# ATTEMPT3: If ORACLE_HOME is in /etc/oratab, use dbhome command:
if [ ! -f ${ORACLE_HOME}/bin/sqlplus ]
 then
ORACLE_HOME=`dbhome "${ORACLE_SID}"`
export ORACLE_HOME
fi

# ATTEMPT4: If ORACLE_HOME is still not found, search for the environment variable: [Less accurate]
if [ ! -f ${ORACLE_HOME}/bin/sqlplus ]
 then
ORACLE_HOME=`env|grep -i ORACLE_HOME|sed -e 's/ORACLE_HOME=//g'`
export ORACLE_HOME
fi

# ATTEMPT5: If ORACLE_HOME is not found in the environment search user's profile: [Less accurate]
if [ ! -f ${ORACLE_HOME}/bin/sqlplus ]
 then
ORACLE_HOME=`grep -h 'ORACLE_HOME=\/' ${USR_ORA_HOME}/.bash_profile ${USR_ORA_HOME}/.*profile | perl -lpe'$_ = reverse' |cut -f1 -d'=' | perl -lpe'$_ = reverse'|tail -1`
export ORACLE_HOME
fi

# ATTEMPT6: If ORACLE_HOME is still not found, search for orapipe: [Least accurate]
if [ ! -f ${ORACLE_HOME}/bin/sqlplus ]
 then
	if [ -x /usr/bin/locate ]
 	 then
ORACLE_HOME=`locate -i orapipe|head -1|sed -e 's/\/bin\/orapipe//g'`
export ORACLE_HOME
	fi
fi

# TERMINATE: If all above attempts failed to get ORACLE_HOME location, EXIT the script:
if [ ! -f ${ORACLE_HOME}/bin/sqlplus ]
 then
  echo "Please export ORACLE_HOME variable in your .bash_profile file under oracle user home directory in order to get this script to run properly"
  echo "e.g."
  echo "export ORACLE_HOME=/u01/app/oracle/product/11.2.0/db_1"
exit
fi

export LD_LIBRARY_PATH=${ORACLE_HOME}/lib

# Neutralize login.sql file:
# #########################
# Existance of login.sql file under current working directory eliminates many functions during the execution of this script:

        if [ -f ./login.sql ]
         then
mv ./login.sql   ./login.sql_NeutralizedBy${SCRIPT_NAME}
        fi

# ########################################
# Exit if the user is not the Oracle Owner:
# ########################################
#CURR_USER=`whoami`
#        if [ ${ORA_USER} != ${CURR_USER} ]; then
#          echo ""
#          echo "You're Running This Sctipt with User: \"${CURR_USER}\" !!!"
#          echo "Please Run This Script With The Right OS User: \"${ORA_USER}\""
#          echo "Script Terminated!"
#          exit
#        fi

# ###################################
# SQLPLUS: Getting All Sessions Info:
# ###################################
${ORACLE_HOME}/bin/sqlplus -s '/ as sysdba' << EOF
-- Set an identifier for this session:
EXEC DBMS_SESSION.set_identifier('${SCRIPT_NAME}');

set feedback off
prompt ================================
prompt ACTIVE Sessions in the Database: [Excluding Background Processes and Idle Events]
prompt ================================

set feedback off linesize ${SQLLINESIZE} pages 1000
col inst for 99
col module for a27
col event for a24
col MACHINE for a27
col "ST|WAITD|ACT_SINC|LOGIN" for a35
col "INST|USER|SID,SERIAL#" for a30
col "INS|USER|SID,SER|MACHIN|MODUL" for a64
col "PREV|CURR SQLID" for a27
col "I|BLK_BY" for a9
col "CURRENT SQL" for a14
select
substr(s.INST_ID||'|'||s.USERNAME||'| '||s.sid||','||s.serial#||' |'||substr(s.MACHINE,1,20)||'|'||substr(s.MODULE,1,18),1,64)"INS|USER|SID,SER|MACHIN|MODUL"
,substr(s.status||'|'||round(w.WAIT_TIME_MICRO/1000000)||'|'||LAST_CALL_ET||'|'||to_char(LOGON_TIME,'ddMon HH24:MI'),1,40) "ST|WAITD|ACT_SINC|LOGIN"
,substr(w.event,1,24) "EVENT"
--,s.PREV_SQL_ID||'|'||s.SQL_ID "PREV|CURR SQLID"
,s.SQL_ID "CURRENT SQL"
,s.FINAL_BLOCKING_INSTANCE||'|'||s.FINAL_BLOCKING_SESSION "I|BLK_BY"
from 	gv\$session s, gv\$session_wait w
where 	s.USERNAME is not null
and 	s.sid=w.sid
and	s.STATUS='ACTIVE'
AND MODULE  NOT IN ( ${EXCLUDED_MODULES} )
AND w.EVENT NOT IN ( ${EXCLUDED_EVENTS} )
order by "I|BLK_BY" desc,"CURRENT SQL",w.event,"INS|USER|SID,SER|MACHIN|MODUL","ST|WAITD|ACT_SINC|LOGIN" desc;

set pages 0
PROMPT
PROMPT SESSIONS STATUS:
PROMPT ----------------

select 'ACTIVE:     '||count(*) 	from gv\$session where USERNAME is not null and status='ACTIVE';
select ${OPTIMIZER} 'INACTIVE:   '||count(*)         from gv\$session where USERNAME is not null and status='INACTIVE';
select ${OPTIMIZER} 'BACKGROUND: '||count(*)         from gv\$session where USERNAME is null;
select ${OPTIMIZER} 'TOTAL:      '||count(*)         from gv\$session;



prompt
prompt =======================
Prompt Running Jobs:
prompt =======================

set pages 1000
col INS                         for 999
col "JOB_NAME|OWNER|SPID|SID"   for a55
col ELAPSED_TIME                for a17
col CPU_USED                    for a17
col "WAIT_SEC"                  for 9999999999
col WAIT_CLASS                  for a15
col "BLKD_BY"                   for 9999999
col "WAITED|WCLASS|EVENT"       for a45
select ${OPTIMIZER} j.RUNNING_INSTANCE INS,j.JOB_NAME ||' | '|| j.OWNER||' |'||SLAVE_OS_PROCESS_ID||'|'||j.SESSION_ID"JOB_NAME|OWNER|SPID|SID"
,s.FINAL_BLOCKING_SESSION "BLKD_BY",ELAPSED_TIME
,substr(s.SECONDS_IN_WAIT||'|'||s.WAIT_CLASS||'|'||s.EVENT,1,45) "WAITED|WCLASS|EVENT",S.SQL_ID
from dba_scheduler_running_jobs j, gv\$session s
where   j.RUNNING_INSTANCE=S.INST_ID(+)
and     j.SESSION_ID=S.SID(+)
order by "JOB_NAME|OWNER|SPID|SID",ELAPSED_TIME;

prompt
prompt =======================
Prompt Long Running Operations:
prompt =======================

set linesize ${SQLLINESIZE} pages 1000
col OPERATION                    for a21
col "%DONE"                      for 999.999
col "STARTED|MIN_ELAPSED|REMAIN" for a26
col MESSAGE                      for a77
col "USERNAME| SID,SERIAL#"      for a28
        select ${OPTIMIZER} USERNAME||'| '||SID||','||SERIAL# "USERNAME| SID,SERIAL#",SQL_ID
        --,OPNAME OPERATION
	--,substr(SOFAR/TOTALWORK*100,1,5) "%DONE"
	,round(SOFAR/TOTALWORK*100,2) "%DONE"
        ,to_char(START_TIME,'DD-Mon HH24:MI')||'| '||trunc(ELAPSED_SECONDS/60)||'|'||trunc(TIME_REMAINING/60) "STARTED|MIN_ELAPSED|REMAIN" ,MESSAGE
        from v\$session_longops
	where SOFAR/TOTALWORK*100 <>'100'
	and TOTALWORK <> '0'
        order by "STARTED|MIN_ELAPSED|REMAIN" desc, "USERNAME| SID,SERIAL#";

EOF


# #########################
# Checking Running Backups:
# #########################

BACKUPJOBCOUNTRAW=$(${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" <<EOF
set pages 0 feedback off;
prompt
SELECT ${OPTIMIZER} count(*) FROM v\$rman_backup_job_details WHERE status like 'RUNNING%';
exit;
EOF
)
BACKUPJOBCOUNT=`echo ${BACKUPJOBCOUNTRAW}|perl -lpe'$_ = reverse' |awk '{print $1}'|perl -lpe'$_ = reverse'|cut -f1 -d '.'`

  if [ ${BACKUPJOBCOUNT} -gt 0 ]
   then
${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" << EOF
set pages 0 termout off echo off feedback off linesize ${SQLLINESIZE}
col name for A40
EXEC DBMS_SESSION.set_identifier('${SCRIPT_NAME}');
set feedback off

prompt
prompt =======================
Prompt Running Backups:
prompt =======================

set feedback off linesize ${SQLLINESIZE} pages 1000
col START_TIME for a15
col END_TIME for a15
col TIME_TAKEN_DISPLAY for a10
col INPUT_BYTES_DISPLAY heading "DATA SIZE" for a10
col OUTPUT_BYTES_DISPLAY heading "Backup Size" for a11
col OUTPUT_BYTES_PER_SEC_DISPLAY heading "Speed/s" for a10
col output_device_type heading "Device_TYPE" for a11
SELECT ${OPTIMIZER} to_char (start_time,'DD-MON-YY HH24:MI') START_TIME, to_char(end_time,'DD-MON-YY HH24:MI') END_TIME, time_taken_display, status,
input_type, output_device_type,input_bytes_display, output_bytes_display, output_bytes_per_sec_display,COMPRESSION_RATIO COMPRESS_RATIO
FROM v\$rman_backup_job_details
WHERE status like 'RUNNING%';

set pages 0
${SHOW_OS_COMMAND} PROMPT
${SHOW_OS_COMMAND} select ${OPTIMIZER} '*TO PAUSE THE RUNNING RMAN BACKUP RUN OS COMMAND:  kill -STOP '||listagg (p.spid, ' ')  WITHIN GROUP (ORDER BY p.spid) from v\$session s, v\$process p where s.program like 'rman@%' and p.addr=s.paddr; 
${SHOW_OS_COMMAND} select ${OPTIMIZER} '*TO RESUME A "PAUSED" RMAN BACKUP RUN OS COMMAND:  kill -CONT '||listagg (p.spid, ' ')  WITHIN GROUP (ORDER BY p.spid) from v\$session s, v\$process p where s.program like 'rman@%' and p.addr=s.paddr; 
${SHOW_OS_COMMAND} select ${OPTIMIZER} '*TO KILL  THE RUNNING RMAN BACKUP RUN OS COMMAND:  kill -9    '||listagg (p.spid, ' ')  WITHIN GROUP (ORDER BY p.spid) from v\$session s, v\$process p where s.program like 'rman@%' and p.addr=s.paddr; 

exit;
EOF
echo ""
  fi

# ######################################################
# Checking Active Sessions Running for More Than 1 Hour:
# ######################################################

ACTIVE_SESS_COUNT_RAW=$(${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" <<EOF
set pages 0 feedback off;
prompt
select ${OPTIMIZER} count(*) from v\$session where
username is not null
and module is not null
-- 1 is the number of hours
and last_call_et > 60*60*1
AND MODULE NOT IN ( ${EXCLUDED_MODULES} )
AND EVENT NOT IN ( ${EXCLUDED_EVENTS} )
and status = 'ACTIVE';
exit;
EOF
)
ACTIVE_SESS_COUNT=`echo ${ACTIVE_SESS_COUNT_RAW}|perl -lpe'$_ = reverse' |awk '{print $1}'|perl -lpe'$_ = reverse'|cut -f1 -d '.'`

# If ASM DISKS Are Exist, Check the size utilization:
  if [ ${ACTIVE_SESS_COUNT} -gt 0 ]
   then

${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" << EOF
PROMPT
prompt ====================================
PROMPT Active Sessions for More Than 1 Hour:
PROMPT ====================================

set lines ${SQLLINESIZE} pages 1000
col "MODULE | MACHINE" for a63
col DURATION_HOURS for 99999.9
col STARTED_AT for a13
col "USERNAME| SID,SERIAL#| OSPID" for a35
col "SQL_ID | SQL_TEXT" for a120
select ${OPTIMIZER} s.username||'| '||s.sid ||','|| s.serial# ||' |'||p.spid "USERNAME| SID,SERIAL#| OSPID",substr(s.MODULE,1,30)||' | '||substr(s.MACHINE,1,30) "MODULE | MACHINE", to_char(sysdate-s.last_call_et/24/60/60,'DD-MON HH24:MI') STARTED_AT, s.last_call_et/60/60 "DURATION_HOURS", SQL_ID
from v\$session s , v\$process p
where s.username is not null
and p.addr = s.paddr
and s.module is not null
AND s.MODULE NOT IN ( ${EXCLUDED_MODULES} )
AND s.EVENT NOT IN ( ${EXCLUDED_EVENTS} )
-- 1 is the number of hours
and s.last_call_et > 60*60*1
and s.status = 'ACTIVE'
order by "DURATION_HOURS";

set pages 0 echo off feedback off linesize ${SQLLINESIZE}
PROMPT
PROMPT Providing Kill Command for Active Sessions since more than 1 Hour: [Don't kill unless you investigate these sessions first ;-)]
PROMPT ------------------------------------------------------------------

select ${OPTIMIZER} 'ALTER SYSTEM DISCONNECT SESSION '''||sid ||','|| serial#||''' IMMEDIATE;'from v\$session where
username is not null
and module is not null
AND MODULE NOT IN ( ${EXCLUDED_MODULES} )
AND EVENT NOT IN ( ${EXCLUDED_EVENTS} )
-- 1 is the number of hours
and last_call_et > 60*60*1
and status = 'ACTIVE'
order by last_call_et/60/60;

PROMPT

EOF
  fi


# De-Neutralize login.sql file:
# ############################
# If login.sql was renamed during the execution of the script revert it back to its original name:
        if [ -f ./login.sql_NeutralizedBy${SCRIPT_NAME} ]
         then
mv ./login.sql_NeutralizedBy${SCRIPT_NAME}  ./login.sql
        fi

# #############
# END OF SCRIPT
# #############
