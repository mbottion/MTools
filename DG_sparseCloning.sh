VERSION=1.0 (Michelin PROD 07/2023)
_____________________________TraceFormating() { : ;}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#     Trace
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#  Usage
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
usage() 
{
 echo "$SCRIPT :

Usage :
 $SCRIPT -d DBNAME -a ACTION [-S SUFFIX] [-T SNAPDB] [-n] [-h|-?]

      $SCRIPT_LIB

         -d DBNAME    : Name of the source stand-by
         -a ACTION    : Action to run +--- CLONE_DG         --> Create a clone for DG (used for next iteration)
                                      |    CLONE_LIST       --> List the hierarchy of the clones
                                      |    TRACK_CREATE     --> Test only : Create tracking table on the primary
                                      |    TRACK_UPDATE     --> Test only : Update tracking table
                                      |    TRACK_DROP       --> Test only : Drop tracking table
                                      |    TRACK_LIST       --> Test only : List Tracking table on all databases
                                      |    TM_START         --> Start the Test MASTER for a given clone (create it if not exists)
                                      |    TM_STOP          --> Stop the test Master
                                      |    TM_DROP          --> Drop the test Master
                                      |    TM_STATUS        --> List the status of the test masters
                                      |    SNAP_CREATE      --> Create a snapshot DB
                                      |    SNAP_DROP        --> Drop a snapshot DB
                                      +--- DROP_ALL         --> Drop everything
         -S SUFFIX    : Suffix to use in place of YYYYMM (6 characters maximum)
         -T SNAPDB    : DB Name of the snapshot
         -n           : Don't log the output to file
         -?|-h        : Help

  Version : $VERSION
  "
  exit
}
libAction()
{
  local mess="$1"
  local indent="$2"
  [ "$indent" = "" ] && indent="  - "
  printf "%-90.90s : " "${indent}${mess}"
}
infoAction()
{
  local mess="$1"
  local indent="$2"
  [ "$indent" = "" ] && indent="  - "
  printf "%-s\n" "${indent}${mess}"
}
startRun()
{
  START_INTERM_EPOCH=$(date +%s)
  START_INTERM_FMT=$(date +"%d/%m/%Y %H:%M:%S")
  echo   "========================================================================================"
  echo   " Execution start"
  echo   "========================================================================================"
  echo   "  - $1"
  echo   "  - Started at     : $START_INTERM_FMT"
  echo   "========================================================================================"
  echo
}
endRun()
{
  END_INTERM_EPOCH=$(date +%s)
  END_INTERM_FMT=$(date +"%d/%m/%Y %H:%M:%S")
  all_secs2=$(expr $END_INTERM_EPOCH - $START_INTERM_EPOCH)
  mins2=$(expr $all_secs2 / 60)
  secs2=$(expr $all_secs2 % 60 | awk '{printf("%02d",$0)}')
  echo
  echo   "========================================================================================"
  echo   "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - "
  echo   "  - Ended at      : $END_INTERM_FMT"
  echo   "  - Duration      : ${mins2}:${secs2}"
  echo   "========================================================================================"
  echo   "Script LOG in : $LOG_FILE"
  echo   "========================================================================================"
  if [ "$CMD_FILE" != "" ]
  then
    echo   "Commands Logged to : $CMD_FILE"
    echo   "========================================================================================"
  fi
}
startStep()
{
  STEP="$1"
  STEP_START_EPOCH=$(date +%s)
  echo
  echo "       - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - "
  echo "       - Step (start)  : $STEP"
  echo "       - Started at    : $(date)"
  echo "       - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - "
  echo
}
endStep()
{
  STEP_END_EPOCH=$(date +%s)
  all_secs2=$(expr $STEP_END_EPOCH - $STEP_START_EPOCH)
  mins2=$(expr $all_secs2 / 60)
  secs2=$(expr $all_secs2 % 60 | awk '{printf("%02d",$0)}')
  echo
  echo "       - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - "
  echo "       - Step (end)    : $STEP"
  echo "       - Ended at      : $(date)"
  echo "       - Duration      : ${mins2}:${secs2}"
  echo "       - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - "
}
die()
{
  [ "$START_INTERM_EPOCH" != "" ] && endRun
  echo "
ERROR :
  $*"

  rm -f $PID_FILE

  exit 1
}
_____________________________Environment() { : ;}
setASMEnv()
{
  libAction "Set ASM environment"
  . oraenv <<< +ASM1 >$TMP1 2>&1 && echo "OK" || { echo ERROR ; cat $TMP1 ; rm -f $TMP1 ; die "Unable to set environment for ASM" ; }
}
setDbEnv()
{
  libAction "Set $1 environment"
  . $HOME/$1.env && echo OK || { echo ERROR ; die "Unable to set database envirronment" ; } 
}
setScriptEnv()
{
echo "
    +--------------------------------------------------------------------------------+
    |   Set main script environment variables                                        |
    +--------------------------------------------------------------------------------+
      ACTION=$ACTION
"
  if [    "$(echo $ACTION | cut -c1-5)" != "TRACK" \
       -a "$ACTION" != "CLONE_LIST" \
       -a "$ACTION" != "TM_STATUS" \
       -a "$ACTION" != "TM_STOP" \
     ] 
  then
    setASMEnv
    SPARSE_DG=$(exec_sql "/ as sysdba" "
SELECT
  name
FROM
  v\$asm_diskgroup
WHERE
  group_number IN (
    SELECT
      group_number
    FROM
      v\$asm_diskgroup_sparse
  ); 
") || die "Databse Error ($SPARSE_DG)"
    libAction "SPARSE Disk Group" ; echo "$SPARSE_DG"
    [ "$SPARSE_DG" = "" ] && die "No sparse disk group found"
    
    DATA_DG=$(exec_sql "/ as sysdba" "
SELECT
  name
FROM
  v\$asm_diskgroup
WHERE
  group_number NOT IN (
    SELECT
      group_number
    FROM
      v\$asm_diskgroup_sparse
  ) and name like '%DATA%';
") || die "Databse Error ($DATA_DG)"

    RECO_DG=$(exec_sql "/ as sysdba" "
SELECT
  name
FROM
  v\$asm_diskgroup
WHERE
  group_number NOT IN (
    SELECT
      group_number
    FROM
      v\$asm_diskgroup_sparse
  ) and name like '%RECO%';
") || die "Databse Error ($RECO_DG)"

    libAction "DATA Disk Group" ; echo "$DATA_DG"
    libAction "RECO Disk Group" ; echo "$RECO_DG"
  fi
  
  setDbEnv $SOURCE_STANDBY
  
  DB_PASSWORD=$(getPassDB)
  DO_TRACKING=$(trackingTest)
  
  case $SOURCE_STANDBY in
    *AME*) ZONE=1 ;;
    *EUR*) ZONE=2 ;;
    *ACJ*) ZONE=3 ;;
    *MBO*) ZONE=4 ;;
    *)     ZONE=0 ;;
  esac
  
  TEST_MASTER="TM${ZONE}${SUFFIX}"
  TM_UNIQUE_NAME="${TEST_MASTER}_TM${ZONE}_${SUFFIX}"
}
showEnv()
{
echo "

   Environment variable used (ACTION=$ACTION):
   
   Database information:
   ====================
   
   SOURCE_STANDBY                    : $SOURCE_STANDBY
   ORACLE_UNQNAME                    : $ORACLE_UNQNAME
   DATA_DG                           : $DATA_DG    
   RECO_DG                           : $RECO_DG    
   SPARSE_DG                         : $SPARSE_DG  
   DB_PASSWORD                       : $( test -z "$DB_PASSWORD" && echo "Not Found" || echo "Set")
   
   Test Master Operations
   ======================
   
   SUFFIX                            : $SUFFIX
   ZONE                              : $ZONE
   TEST_MASTER                       : $TEST_MASTER
   TM_UNIQUE_NAME                    : $TM_UNIQUE_NAME
   
   Script Behaviour:
   ================
   
   DO_TRACKING                       : $DO_TRACKING  
   LOG_DIR                           : $LOG_DIR
   INFO_DIR                          : $INFO_DIR
"
}
_____________________________Utilities() { : ;}
getPassDB()
{
  local dir=""
  if [ -d /acfs01/dbaas_acfs/$ORACLE_UNQNAME/db_wallet ]
  then
    dir=/acfs01/dbaas_acfs/$ORACLE_UNQNAME/db_wallet
  elif [ -d /acfs01/dbaas_acfs/$ORACLE_SID/db_wallet ]
  then
    dir=/acfs01/dbaas_acfs/$ORACLE_SID/db_wallet
  elif [ -d /acfs01/dbaas_acfs/$(echo $ORACLE_SID|sed -e "s;.$;;")/db_wallet ]
  then
    dir=/acfs01/dbaas_acfs/$(echo $ORACLE_SID|sed -e "s;.$;;")/db_wallet
  else
    echo
  fi
  mkstore -wrl $dir -viewEntry passwd | grep passwd | sed -e "s;^ *passwd = ;;"
}
exec_sql()
{
#
#  Don't forget to use : set -o pipefail un the main program to have error managempent
#
  local VERBOSE=N
  local SILENT=N
  if [ "$1" = "-silent" ]
  then 
    SILENT=Y
    shift
  fi
  if [ "$1" = "-no_error" ]
  then
    err_mgmt="whenever sqlerror continue"
    shift
  else
    err_mgmt="whenever sqlerror exit failure"
  fi
  if [ "$1" = "-verbose" ]
  then
    VERBOSE=Y
    shift
  fi
  local login="$1"
  local loginSecret=$(echo "$login" | sed -e "s;/[^@ ]*;/SecretPasswordToChange;" -e "s;^/SecretPasswordToChange;/;")
  local stmt="$2"
  local lib="$3"
  local bloc_sql="$err_mgmt
set recsep off
set head off 
set feed off
set pages 0
set lines 2000
connect ${login}
$stmt"
  if [ "$CMD_FILE" != "" ]
  then
    echo "\
===============================================================================
SQLPLUS : ${lib:-No description}
===============================================================================
sqlplus \"$loginSecret\" <<%%
$bloc_sql
%%
    " >> $CMD_FILE
  fi
  REDIR_FILE=""
  REDIR_FILE=$(mktemp)
  if [ "$lib" != "" ] 
  then
     libAction "$lib"
     sqlplus -s /nolog >$REDIR_FILE 2>&1 <<%EOF%
$bloc_sql
%EOF%
    status=$?
  else
     sqlplus -s /nolog <<%EOF% | tee $REDIR_FILE  
$bloc_sql
%EOF%
    status=$?
  fi
  if [ $status -eq 0 -a "$(egrep "SP2-" $REDIR_FILE)" != "" ]
  then
    status=1
  fi
  if [ "$lib" != "" ]
  then
    [ $status -ne 0 ] && { echo "*** ERREUR ***" ; test -f $REDIR_FILE && cat $REDIR_FILE ; rm -f $REDIR_FILE ; } \
                      || { echo "OK" ; [ "$VERBOSE" = "Y" ] && test -f $REDIR_FILE && sed -e "s;^;    > ;" $REDIR_FILE ; }
  fi 
  rm -f $REDIR_FILE
  [ $status -ne 0 ] && return 1
  return $status
}
exec_srvctl()
{
  SILENT=N
  [ "$1" = "-silent" ] &&  { local SILENT=Y ; shift ; }
  local cmd=$1
  local lib=$2
  local okMessage=$3
  local koMessage=$4
  local dieMessage=$5
  local tmpOut=${TMPDIR:-/tmp}/$$.tmp
  if [ "$CMD_FILE" != "" ]
  then
    echo "\
===============================================================================
SRVCTL : ${lib:-No description}
===============================================================================
srvctl $cmd
    " >> $CMD_FILE
  fi
  [ "$lib" != "" ] &&  libAction "$lib"
  if srvctl $cmd > $tmpOut 2>&1
  then
    [ "$lib" != "" ] && echo "${okMessage:-OK}"
    [ "$lib" = "" ]  && cat "$tmpOut"
    rm -f "$tmpOut"
    return 0
  else
    [ "$lib" != "" ] && echo "${koMessage:-ERROR}"
    [ "$SILENT" = "N" ] && cat $tmpOut
    rm -f $tmpOut
    [ "$diemessage" = "" ] && return 1 || die "$dieMessage"
  fi
}
exec_dgmgrl()
{
  if [ "$3" != "" ]
  then
    local connect="$1"
    shift
  else
    local connect="sys/${dbPassword}@${primDbUniqueName}"
  fi
  local connectSecret=$(echo "$connect" | sed -e "s;/[^@ ]*;/SecretPasswordToChange;" -e "s;^/SecretPasswordToChange;/;")
  local cmd=$1
  local lib=$2
  if [ "$CMD_FILE" != "" ]
  then
    echo "\
===============================================================================
DGMGRL : ${lib:-No description}
===============================================================================
dgmgrl -silent \"$connectSecret\" \"$cmd\"
    " >> $CMD_FILE
  fi
  # echo "    - $cmd"
  [ "$lib" != "" ] && libAction "$lib"
  dgmgrl -silent "$connect" "$cmd" > $$.tmp 2>&1 \
    && { [ "$lib" != "" ] && echo "OK" ; [ "$lib" = "" ] && cat $$.tmp ; rm -f $$.tmp ; return 0 ; } \
    || { [ "$lib" != "" ] && echo "ERROR" ; cat $$.tmp ; rm -f $$.tmp ; return 1 ; }
}
exec_asmcmd()
{
  local cmd=$1
  local lib=$2
  local okMessage=${3:-OK}
  local koMessage=${4:-ERROR}
  local dieMessage=$5
  local tmpOut=${TMPDIR:-/tmp}/$$.tmp
  if [ "$CMD_FILE" != "" ]
  then
    echo "\
===============================================================================
ASMCMD : ${lib:-No description}
===============================================================================
asmcmd --privilege sysdba $cmd
    " >> $CMD_FILE
  fi

  libAction "$lib"
  if asmcmd --privilege sysdba $cmd > $tmpOut 2>&1
  then
    echo "$okMessage"
    rm -f $tmpOut
    return 0
  else
    echo "$koMessage"
    cat $tmpOut
    rm -f $tmpOut
    [ "$diemessage" = "" ] && return 1 || die "$dieMessage"
  fi
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
createASMDir()
{
  libAction "Creating $1" "    - "
  if [ "$CMD_FILE" != "" ]
  then
    echo "\
===============================================================================
ASMCMD : Creating $1 If non existent
===============================================================================
asmcmd --privilege sysdba mkdir $1
    " >> $CMD_FILE
  fi
  if [ "$(asmcmd --privilege sysdba ls -ld $1)" = "" ] 
  then
    asmcmd --privilege sysdba mkdir $1 > $TMP1 2>&1 \
                && { echo "OK" ; rm -f $TMP1 ; } \
                || { echo "ERROR" ; cat $TMP1 ; rm -f $TMP1 ; die "Unable to create $1" ; }
  else
    echo "Exists"
  fi
}
removeASMDir()
{
  libAction "Removing ASM Folder $1" "    - "
  if [ "$CMD_FILE" != "" ]
  then
    echo "\
===============================================================================
ASMCMD : Removing ASM Folder $1
===============================================================================
asmcmd --privilege sysdba rm -rf $1
    " >> $CMD_FILE
  fi
  if [ "$(asmcmd --privilege sysdba ls -ld $1 2>/dev/null)" != "" ] 
  then
    asmcmd --privilege sysdba rm -rf $1 > $TMP1 2>&1 \
                && { echo "OK" ; rm -f $TMP1 ; } \
                || { echo "ERROR" ; cat $TMP1 ; rm -f $TMP1 ; die "Unable to remove $1" ; }
  else
    echo "Not exists"
  fi
}
_____________________________ACL_Under_Grid() { : ;}
sudoGrid()
{
  local cmd="$1"
  sudo -nu grid sh -c ". \$HOME/.bash_profile ; $cmd " 
}
setAccessControl_grid()
{
  libAction "Set ASM access control"
  if [ "$CMD_FILE" != "" ]
  then
    echo "\
===============================================================================
SQLPLUS (Grid) : Removing ASM access control
===============================================================================
sqlplus -s / as sysasm <<%%
whenever sqlerror exit failure 
alter diskgroup $DATA_DG SET ATTRIBUTE 'access_control.enabled' = 'true' ;
%%

    " >> $CMD_FILE
  fi
  sudoGrid "
. oraenv <<< +ASM1
sqlplus -s / as sysasm <<%%
whenever sqlerror exit failure 
alter diskgroup $DATA_DG SET ATTRIBUTE 'access_control.enabled' = 'true' ;
%%
exit \$?
" >$TMP1 2>&1 \
              && { echo "OK" ; rm -f $TMP1 ; } \
              || { echo "ERROR" ; cat $TMP1 ; rm -f $TMP1 ; die "Unable to remove access control" ; }
}
removeAccessControl_grid()
{
  libAction "Removing ASM access control"
  if [ "$CMD_FILE" != "" ]
  then
    echo "\
===============================================================================
SQLPLUS (Grid) : Removing ASM access control
===============================================================================
sqlplus -s / as sysasm <<%%
whenever sqlerror exit failure 
alter diskgroup $DATA_DG SET ATTRIBUTE 'access_control.enabled' = 'false' ;
%%

    " >> $CMD_FILE
  fi
  sudoGrid "
. oraenv <<< +ASM1
sqlplus -s / as sysasm <<%%
whenever sqlerror exit failure 
alter diskgroup $DATA_DG SET ATTRIBUTE 'access_control.enabled' = 'false' ;
%%
exit \$?
" >$TMP1 2>&1 \
              && { echo "OK" ; rm -f $TMP1 ; } \
              || { echo "ERROR" ; cat $TMP1 ; rm -f $TMP1 ; die "Unable to remove access control" ; }
}
filesReadOnly_grid()
{
  libAction "Set ASM ACL and set Files Read Only"
  if [ "$CMD_FILE" != "" ]
  then
    echo "\
===============================================================================
SQLPLUS (Grid) : Set ASM ACL and set Files Read Only
===============================================================================
sqlplus -s / as sysasm <<%%
alter diskgroup $DATA_DG SET ATTRIBUTE 'access_control.enabled' = 'true' ;
alter diskgroup $SPARSE_DG SET ATTRIBUTE 'access_control.enabled' = 'true' ;
ALTER DISKGROUP $DATA_DG ADD USER 'oracle';
ALTER DISKGROUP $SPARSE_DG ADD USER 'oracle';
whenever sqlerror exit failure 
ALTER DISKGROUP $DATA_DG SET ATTRIBUTE 'access_control.umask' = '026';
ALTER DISKGROUP $SPARSE_DG SET ATTRIBUTE 'access_control.umask' = '026';
start $scriptROFor_StandBy
%%

    " >> $CMD_FILE
  fi
  sudoGrid "
. oraenv <<< +ASM1 >/dev/null
sqlplus -s / as sysasm <<%%
alter diskgroup $DATA_DG SET ATTRIBUTE 'access_control.enabled' = 'true' ;
alter diskgroup $SPARSE_DG SET ATTRIBUTE 'access_control.enabled' = 'true' ;
ALTER DISKGROUP $DATA_DG ADD USER 'oracle';
ALTER DISKGROUP $SPARSE_DG ADD USER 'oracle';
whenever sqlerror exit failure 
ALTER DISKGROUP $DATA_DG SET ATTRIBUTE 'access_control.umask' = '026';
ALTER DISKGROUP $SPARSE_DG SET ATTRIBUTE 'access_control.umask' = '026';
start $scriptROFor_StandBy
%%
exit \$?
" >$TMP1 2>&1 \
              && { echo "OK" ; rm -f $TMP1 ; } \
              || { echo "ERROR" ; cat $TMP1 ; rm -f $TMP1 ; die "error renaming file" ; }
}
_____________________________TrakingTableManagement_ForTests() { : ;}
trackingCreate()
{
  startStep "Create the tracking table in the PRIMARY Database"
  if [ "$PRIMARY_CONNECT" = "" ]
  then
    dgmgrl / "show configuration" >/dev/null || die "The database is not part of a DG configuration, provide primary connect string (-P CONNECT)" 
    PRIMARY_CONNECT=$(dgmgrl / "show configuration" | grep -i "Primary database" | awk '{print $1}')
  fi
  [ "$DB_PASSWORD" = "" ] && die "DB Password not set"
  libAction "Try connection to the Primary"
  exec_sql "sys/${DB_PASSWORD}@$PRIMARY_CONNECT as sysdba" "select 1 from v\$database;" > /dev/null && echo "OK" || die "unable to connect to the primary"

  exec_sql "sys/${DB_PASSWORD}@$PRIMARY_CONNECT as sysdba" "
create table system.sparse_tracking(d date,lib varchar2(100)) ;
insert into system.sparse_tracking values(sysdate,'INITIAL Situation') ;
commit ;" "Create table system.sparse_tracking in the PRIMARY CDB (for testing purposes)"
  endStep
}
trackingUpdate()
{
  startStep "TRACKING : Update the tracking table in the PRIMARY Database"
  if [ "$PRIMARY_CONNECT" = "" ]
  then
    dgmgrl / "show configuration" >/dev/null || die "The database is not part of a DG configuration, provide primary connect string (-P CONNECT)" 
    PRIMARY_CONNECT=$(dgmgrl / "show configuration" | grep -i "Primary database" | awk '{print $1}')
  fi
  [ "$DB_PASSWORD" = "" ] && die "DB Password not set"
  libAction "TRACKING :Try connection to the Primary"
  exec_sql "sys/${DB_PASSWORD}@$PRIMARY_CONNECT as sysdba" "select 1 from v\$database;" > /dev/null && echo "OK" || die "unable to connect to the primary"

  [ $(exec_sql "sys/${DB_PASSWORD}@$PRIMARY_CONNECT as sysdba" \
      "select count(*) from dba_tables
       where  owner='SYSTEM'
       and    table_name = 'SPARSE_TRACKING' ;") != 1 ] && return
       
  exec_sql "sys/${DB_PASSWORD}@$PRIMARY_CONNECT as sysdba" "
insert into system.sparse_tracking (d,lib) values (sysdate,'${1:-Test update}') ;
  " "TRACKING : Update table system.sparse_tracking in the PRIMARY CDB"
  endStep
}
trackingDrop()
{
  startStep "Drop the tracking table in the PRIMARY Database"
  if [ "$PRIMARY_CONNECT" = "" ]
  then
    dgmgrl / "show configuration" >/dev/null || die "The database is not part of a DG configuration, provide primary connect string (-P CONNECT)" 
    PRIMARY_CONNECT=$(dgmgrl / "show configuration" | grep -i "Primary database" | awk '{print $1}')
  fi
  [ "$DB_PASSWORD" = "" ] && die "DB Password not set"
  libAction "Try connection to the Primary"
  exec_sql "sys/${DB_PASSWORD}@$PRIMARY_CONNECT as sysdba" "select 1 from v\$database;" > /dev/null && echo "OK" || die "unable to connect to the primary"

  exec_sql -no_error "sys/${DB_PASSWORD}@$PRIMARY_CONNECT as sysdba" "
whenever sqlerror continue ;
drop table system.sparse_tracking ;
  " "Drop table system.sparse_tracking in the PRIMARY CDB"
  endStep
}
trackingList()
{
  if [ "$PRIMARY_CONNECT" = "" ]
  then
    dgmgrl / "show configuration" >/dev/null || die "The database is not part of a DG configuration, provide primary connect string (-P CONNECT)" 
    PRIMARY_CONNECT=$(dgmgrl / "show configuration" | grep -i "Primary database" | awk '{print $1}')
  fi
  [ "$DB_PASSWORD" = "" ] && die "DB Password not set"
  if exec_sql "sys/${DB_PASSWORD}@$PRIMARY_CONNECT as sysdba" "select 1 from v\$database;" > /dev/null
  then
    echo ""
    echo "  Tracking table in the primary database : $PRIMARY_CONNECT"
    echo "  =================================================================="
    [ $(exec_sql "sys/${DB_PASSWORD}@$PRIMARY_CONNECT as sysdba" \
        "select count(*) from dba_tables
         where  owner='SYSTEM'
         and    table_name = 'SPARSE_TRACKING' ;") != 1 ] && return
    echo
    exec_sql "sys/${DB_PASSWORD}@$PRIMARY_CONNECT as sysdba" "
set feed off
set head on pages 10000
select to_char(d,'dd/mm/yyyy hh24:mi:ss')\"Date\" ,lib \"Operation\" from system.sparse_tracking order by d desc ;
  "
  fi
  if exec_sql "sys/${DB_PASSWORD}@$PRIMARY_CONNECT as sysdba" "select 1 from v\$database;" > /dev/null
  then
    echo ""
    echo "  Tracking table in the current database : $ORACLE_UNQNAME"
    echo "  =================================================================="
    echo
    m=$(exec_sql "/ as sysdba" "select open_mode from v\$database;")
    libAction "Open MODE" 
    if [ "$m" = "OPEN" -o "$m" = "READ ONLY" -o "$m" = "READ ONLY WITH APPLY" ]
    then
      echo "$m"
      [ $(exec_sql "/ as sysdba" \
          "select count(*) from dba_tables
           where  owner='SYSTEM'
           and    table_name = 'SPARSE_TRACKING' ;") != 1 ] && return
      echo
      exec_sql "/ as sysdba" "
set feed off
set head on pages 10000
select to_char(d,'dd/mm/yyyy hh24:mi:ss')\"Date\" ,lib \"Operation\" from system.sparse_tracking order by d desc ;
    "
    else
      echo "$m"
    fi
  fi

  listSparseStandBy | grep "^TM" | sort | while read s
  do
    export ORACLE_SID=$s
    echo ""
    echo "  Tracking table in cloned databases : $ORACLE_SID"
    echo "  =================================================================="
    echo
    libAction "Database $ORACLE_SID is"
    if [ "$(ps -ef | grep smon_$ORACLE_SID | grep -v grep)" != "" ]
    then
      echo "Started"
      libAction "Open MODE" "    -"
      m="$(exec_sql "/ as sysdba" "select open_mode from v\$database;")"
      if [ "$m" = "OPEN" -o "$m" = "READ ONLY" -o "$m" = "READ ONLY WITH APPLY" ]
      then
        echo "$m"
        [ $(exec_sql "/ as sysdba" \
            "select count(*) from dba_tables
             where  owner='SYSTEM'
             and    table_name = 'SPARSE_TRACKING' ;") != 1 ] && return
        echo
        exec_sql "/ as sysdba" "
set feed off
set head on pages 10000
select to_char(d,'dd/mm/yyyy hh24:mi:ss')\"Date\" ,lib \"Operation\" from system.sparse_tracking order by d desc ;
  "
      else
        echo "$m"
      fi
    else
      echo "NOT Started"
    fi
  done
}
trackingTest()
{
  if [ "$PRIMARY_CONNECT" = "" ]
  then
    dgmgrl / "show configuration" >/dev/null || { echo "NO1" ; return ; }
    PRIMARY_CONNECT=$(dgmgrl / "show configuration" | grep -i "Primary database" | awk '{print $1}')
  fi
  [ "$DB_PASSWORD" = "" ]  && { echo "NO2" ; return ; }
  exec_sql "sys/${DB_PASSWORD}@$PRIMARY_CONNECT as sysdba" "select 1 from v\$database;" > /dev/null  || { echo "NO3" ; return ; }

  [ $(exec_sql "sys/${DB_PASSWORD}@$PRIMARY_CONNECT as sysdba" \
      "select count(*) from dba_tables
       where  owner='SYSTEM'
       and    table_name = 'SPARSE_TRACKING' ;") != 1 ]  && { echo "NO4" ; return ; }
  echo YES
}
_____________________________SparseStandByManagement() { : ;}
dropALL()
{
  removeAccessControl_grid
  infoAction "Drop test masters"
  
  listSparseStandBy | grep ^TM | sed -e "s;^STBY;;" | while read s
  do
    TEST_MASTER="$s"
    TM_UNIQUE_NAME="${TEST_MASTER}_TM${ZONE}_${SUFFIX}"
    testMasterDROP
  done
  
  infoAction "Removing the stand-by for $SOURCE_STANDBY"
  setDbEnv $SOURCE_STANDBY
  echo y | /home/oracle/mbo/setupDG_MICHELIN.sh -m RunOnStandBY -d $SOURCE_STANDBY -U $ORACLE_UNQNAME -s parx01-zf5km-scan.oci.michelin.com:1521 -R | sed -e "s;^;         | ;"
  status=$?
  echo -n "         +----> "
  [ $status -eq 0 ] && echo "OK" || { echo "ERROR" ; die "Unable to remove $SOURCE_STANDBY" ; }

  removeASMDir +SPRC2/$ORACLE_UNQNAME
  
  echo "=============== SPRC2 Content ==========================================="
  asmcmd --privilege sysdba ls +SPRC2
  echo "=============== DATAC2 Content =========================================="
  asmcmd --privilege sysdba ls +DATAC2
  echo "=============== RECOC2 Content =========================================="
  asmcmd --privilege sysdba ls +RECOC2

}
# ---------------------------------------------------------------------------------------------------------
#      This procedure will clone the stand-by database to be able to apply the logs on the copy while
# the main files will be used as test master.
#
#      Clones are identified by a suffix which is used to rename files. This suffix is used by 
# the script and many operations depend on it.
#
#      By default, we use the current month YYYYMM, but the -S flag can be used to force a different prefix.
#
#      Prefixes must be short 4 to 6 characters.
#
#  Example:
#  =======
#
#      ./DG_sparseCloning.sh -d RFOPMBOC -a clone_dg -S CL01
#
# --------------------------------------------------------------------------------------------------------- 
cloneDG()
{
  setDbEnv $SOURCE_STANDBY
  showEnv
  SOURCE_STANDBY_DBU=$ORACLE_UNQNAME
  startStep "Prepare database cloning"
  libAction "Check that the database is a stand-by"
  [ "$(exec_sql "/ as sysdba" "select database_role from v\$database;")" = "PHYSICAL STANDBY" ] && echo "OK" || { echo ERROR ; die "$ORACLE_UNQNAME is not a physical stand-by" ; }
  if [ "$SUFFIX" = "" ]
  then
    SUFFIX="$(date +%Y%m)"
  fi
  fileSuffix="STBY${SUFFIX}"
  
  scriptRenameFor_StandBy=$INFO_DIR/$SOURCE_STANDBY/$SUFFIX/renameFor_${fileSuffix}.sql
  scriptROFor_StandBy=$INFO_DIR/$SOURCE_STANDBY/$SUFFIX/ROFor_${fileSuffix}.sql
  scriptCreateControlFile=$INFO_DIR/$SOURCE_STANDBY/$SUFFIX/ctrlFile_${fileSuffix}.sql
  scriptInitOra=$INFO_DIR/$SOURCE_STANDBY/$SUFFIX/initOra_${fileSuffix}.ora
  
  libAction "File Suffix" ; echo "$fileSuffix"
  libAction "Check if $fileSuffix is used"
  tmp=$(exec_sql "/ as sysdba" "select count(*) from v\$datafile where upper(name) like '%$fileSuffix' ;")  
  if [ $tmp -eq 0 ]
  then
    echo "Not used"
    echo
    echo "         The suffix is free, cloning operation will now "
    echo "       continue...."
    echo

    endStep
    
    [ "$DO_TRACKING" = "YES" ] && trackingUpdate "Before $SUFFIX Cloning"

    startStep "Stop $SOURCE_STANDBY and re-open Read-Only"
    libAction "Creating $INFO_DIR/$SOURCE_STANDBY/$SUFFIX"
    rm -rf $INFO_DIR/$SOURCE_STANDBY/$SUFFIX
    mkdir -p $INFO_DIR/$SOURCE_STANDBY/$SUFFIX && echo "OK" || { echo ERROR ; die "Error creating directory" ; }

    exec_srvctl "stop database -d $ORACLE_UNQNAME"                               "Stop $SOURCE_STANDBY"
    exec_srvctl "modify database -d $ORACLE_UNQNAME -startoption MOUNT"          "Set start option to MOUNT"
    exec_srvctl "start database -d $ORACLE_UNQNAME -o open"                      "Start database (OPEN/READ ONLY)"
    infoAction "Database status ..."
    exec_srvctl "status database -d $ORACLE_UNQNAME -v"
    infoAction "Pluggable databases status ..."
    exec_sql "/ as sysdba" "
alter pluggable database all close instances=all;
alter pluggable database all open read only instances=all;
set pages 20 heading on
show pdbs ;
  " || die "Incorrect status"

    endStep
    startStep "Stop Apply and rename scripts preparation"

    exec_dgmgrl "edit database '$SOURCE_STANDBY_DBU' set state = apply-off" "Stop REDO APPLY for $SOURCE_STANDBY_DBU"
  
    libAction "Generate ASM dir List"
    dirList=$(exec_sql "/ as sysdba" "
select
  replace (dir,'$DATA_DG','$SPARSE_DG') a
from (
            select distinct         substr(name,1,instr(name,'/',-1,1)-1) dir                                    from v\$datafile 
      union select distinct         substr(name,1,instr(name,'/',-1,2)-1)                                        from v\$datafile 
      union select distinct         substr(name,1,instr(name,'/',-1,3)-1)                                        from v\$datafile 
      union select distinct         substr(name,1,instr(name,'/',-1,4)-1)                                        from v\$datafile 
      union select distinct         substr(name,1,instr(name,'/',-1,5)-1)                                        from v\$datafile 
      union select distinct         substr(name,1,instr(name,'/',-1,6)-1)                                        from v\$datafile 
     )
where 
  nvl(dir,'+$DATA_DG') not in ('+$DATA_DG','+$RECO_DG','+$SPARSE_DG') ; ") && echo "OK" || die "Error generating directories list ($dirList)"

    
    exec_sql "/ as sysdba" "
spool $scriptRenameFor_StandBy
set trimspool on
set echo off
set feed off 
set verify off
select 'BEGIN dbms_dnfs.clonedb_renamefile ('|| chr(10) ||
       '    '''||name||''''||chr(10)||
       '   ,'||''''||replace(
                       replace(
                          regexp_replace(name,'_*STBY.*$','',1,1,'i')
                         ,'.','_')
                       ,'$DATA_DG/','$SPARSE_DG/'
                            ) ||'_$fileSuffix'''||chr(10)||
       '                                     ); END ; ' || chr(10) || '/' from v\$datafile;
spool off
                           " "Generating file Rename Command for sparse stand-by" || die "Error generating the file renaming command for standby"

    exec_sql "/ as sysdba" " 
spool $scriptROFor_StandBy
set trimspool on
set echo off
set feed off 
set verify off
SELECT distinct 'ALTER DISKGROUP '||substr(name,2,regexp_instr(name,'\/')-2)||' set ownership owner=''oracle'' for file '''||name||''';' from v\$datafile;
SELECT distinct 'ALTER DISKGROUP '||substr(name,2,regexp_instr(name,'\/')-2)||' set permission owner=read only, group=read only, other=none for file '''||name||''';' from v\$datafile;
spool off
                           " "Generate set files Read Only" || die "Error generating the file Read Only command for standby"

    exec_sql "/ as sysdba" " 
set newpage 0 linesize 999 pagesize 0 feedback off heading off echo off space 0 tab off trimspool on
col trc new_value trc
SELECT value trc FROM v\$diag_info WHERE name = 'Default Trace File';
alter database backup controlfile to trace ;
host cp &trc $scriptCreateControlFile 
                           " "Backup Control File" || die "Error backuping the control file"

    exec_sql "/ as sysdba" " 
create pfile='$scriptInitOra' from spfile ;
                           " "Backup SPFILE" || die "Error backuping the SPFILE"
                           
    endStep
    
    
    startStep "Clone the stand-by"
    
    infoAction "Create ASM Directories ... "
    for d in $(echo "$dirList")
    do
      createASMDir $d
    done
  
    exec_srvctl "stop database -d $ORACLE_UNQNAME" "Stop database $ORACLE_UNQNAME"
    
    filesReadOnly_grid

    exec_srvctl "start instance -d $ORACLE_UNQNAME -i $ORACLE_SID" "Start instance $ORACLE_SID"
    exec_sql "/ as sysdba" "
alter system set standby_file_management=manual scope=both ;
start $scriptRenameFor_StandBy
alter system set standby_file_management=auto scope=both ;" "Rename datafiles to SPARSE" || { removeAccessControl_grid ; die "Error renaming the data files" ; }

#    exec_srvctl "stop database -d $ORACLE_UNQNAME" "Stop database $ORACLE_UNQNAME"
    exec_srvctl "start database -d $ORACLE_UNQNAME -o OPEN" "Start whole DB"
    exec_sql -no_error "/ as sysdba" "alter database open read only;" "Open the database read only"
    exec_srvctl "status database -d $ORACLE_UNQNAME -v"
  
    exec_dgmgrl "edit database $ORACLE_UNQNAME set state=apply-on" "Restart redo apply"
    infoAction "Waiting 30 seconds ..."
    sleep 30
    endStep
    [ "$DO_TRACKING" = "YES" ] && trackingUpdate "After $SUFFIX Cloning"
  else
    echo "Used, no clone operation needed"
    echo
    echo "         The suffix is not free, a cloning operation has already been  "
    echo "       done, list the DB INFORMATION ...."
    echo
    echo "         Or use -S Suffix to change the default"
    echo
  fi
  startStep "Database Information"
  infoAction "Standby status"
  exec_dgmgrl "show configuration" 
  exec_dgmgrl "show database $ORACLE_UNQNAME" 
  exec_dgmgrl "validate database $ORACLE_UNQNAME" 
  libAction "List datafiles folders" ; echo ; echo
  exec_sql "/ as sysdba" "select distinct substr(name,1,instr(name,'/',-1)-1) from v\$datafile order by 1;"
  echo
  removeAccessControl_grid
  endStep
  echo "
    
         The $SOURCE_STANDBY database has been sucessfully cloned. All datafiles are in the
     $SPARSE_DG disk group and their names have been suffixed by _$fileSuffix.
     
     The following scripts were used to make the clone
     
     Folder : $INFO_DIR/$SOURCE_STANDBY/$SUFFIX
     Files :
           $(printf "%-30.30s" $(basename $scriptRenameFor_StandBy)) --> File renaming script
           $(printf "%-30.30s" $(basename $scriptROFor_StandBy)) --> File renaming script
           
        The previous datafiles can be used to start a temporary test-master database (with this script)
     This database can in turn be cloned to create the HOTFIX database, or any other SPARSE database.
     
     The following files will be necessary to create and launch this test master DB
     
     Folder : $INFO_DIR/$SOURCE_STANDBY/$SUFFIX
     Files :
           $(printf "%-30.30s" $(basename $scriptCreateControlFile)) --> To create Control file of the test master
           $(printf "%-30.30s" $(basename $scriptInitOra)) --> To create INIT.ORA of the test Master
     
         "
}
listSparseStandBy() 
{
  setDbEnv $SOURCE_STANDBY
  SOURCE_STANDBY_DBU=$ORACLE_UNQNAME
  testFile=$(exec_sql "/ as sysdba" "
SELECT
  regexp_replace(regexp_replace(lower(name),'^(.*)/([^/]*)$','\2'),'_stby.*$','')
FROM
  (SELECT   name
   FROM     v\$datafile
   ORDER BY file#
  )
WHERE
  ROWNUM = 1;")
  testFileOrig=$(echo $testFile | sed -e "s;_;.;g")
  setASMEnv
  infoAction "Get the cloning hierarchy (can be long)"
  exec_sql "/ as sysdba" "
define testFile=$testFile
define testFileOrig=$testFileOrig
define zone=$ZONE
define db=$ORACLE_UNQNAME
define data_dg=DATAC
set lines 200
set verify off
col file_hierarchy format a200
col lvl noprint
col clone_type noprint
select
    'TM&ZONE'||regexp_replace(clonefilename,'.*_STBY([^_.]*).*$','\1') file_hierarchy
   ,0                                                               lvl
   ,'00-MAIN' clone_type
from
  v\$clonedfile
where
  snapshotfilename  like '+DATA%&TestFile%'
  and regexp_like(clonefilename , '.*_STBY[^_]*$')
UNION
select
             decode (typ              
                    ,'01-TESTMASTER_SNAP'  ,'SM'      || suffix
                    ,'02-SNAPSHOT'         ,'SN'      || suffix
                    ,'03-TESTMASTER'       ,'TM&ZONE' || suffix
                    ,'04-SPARSE'           ,'STBY'    || suffix
                    ,'?' || suffix) file_hierarchy
            ,lev
            ,typ
from ( ----------------------------------------------------------- Below select is the same in listSparseStandby --------------------------------------------
    select
       level lev
      ,decode(regexp_replace(fi.code,'([^ ]*) ([^ ]*)','\1') || cl.cloned
             ,'SM'            ,'01-TESTMASTER_SNAP'
             ,'SN'            ,'02-SNAPSHOT'
             ,'STBYYES'       ,'03-TESTMASTER'
             ,'STBY'          ,'04-SPARSE'
             ,'UNKNOWN') typ
      ,nvl(cl.suffix_of_clone,regexp_replace(fi.code,'([^ ]*) ([^ ]*)','\2')) suffix
      ,fi.clone f
      ,fi.parent f
      ,cl.suffix_of_clone f
    from
      (select
         lower(regexp_replace(SNAPSHOTFILENAME,'^(.*)/([^/]*)$','\2')) parent
        ,lower(
             regexp_replace(
               regexp_replace( CLONEFILENAME
                              ,'^(.*)/([^/]*)$'
                              ,'\2')
                              ,'\.[0-9.]*$'
                              ,''
                             )
                           ) clone
        ,regexp_replace(
           regexp_replace(
             regexp_replace(upper(CLONEFILENAME)
                           ,'^(.*)/([^/]*)$'
                           ,'\2')
                         ,'\.[0-9.]*$'
                         ,''
                         )
                       ,'.*_(STBY|SM|SN)([^_]*)$'
                       ,'\1 \2'
                       ) code
      --  ,lower(regexp_replace(regexp_replace(CLONEFILENAME,'^(.*)/([^/]*)$','\2'),'\.[0-9.]*$','')) clone_folder
      --  ,lower(regexp_replace(regexp_replace(SNAPSHOTFILENAME,'^(.*)/([^/]*)$','\2'),'\.[0-9.]*$',''))  parent_folder
        ,SNAPSHOTFILENAME
        ,CLONEFILENAME
      from 
         v\$clonedfile
      where
         CLONEFILENAME like '%&testFile%'
      ) fi
      left join (select
              'YES' cloned
              ,lower(
                   regexp_replace(
                     regexp_replace( SNAPSHOTFILENAME
                                    ,'^(.*)/([^/]*)$'
                                    ,'\2')
                                    ,'\.[0-9.]*$'
                                    ,''
                                   )
                                 ) master
              ,lower(
                   regexp_replace(
                     regexp_replace( CLONEFILENAME
                                    ,'^(.*)/([^/]*)$'
                                    ,'\2')
                                    ,'\.[0-9.]*$'
                                    ,''
                                   )
                                 ) clone_of_clone
              ,upper(
                 regexp_replace(
                   regexp_replace(
                     regexp_replace( CLONEFILENAME
                                    ,'^(.*)/([^/]*)$'
                                    ,'\2')
                                    ,'\.[0-9.]*$'
                                    ,''
                                   )
                       ,'.*_(STBY|SM|SN)([^_]*)$'
                       ,'\2'
                       )
                                 ) suffix_of_clone
            from
              v\$clonedfile
            where
               SNAPSHOTFILENAME like '%&testFile%'
           ) cl on (fi.clone = cl.master)
    connect by parent = prior fi.clone
    start with parent='&testFileOrig' 
    )
order by 2,3
;
"
  setDbEnv $SOURCE_STANDBY
  SOURCE_STANDBY_DBU=$ORACLE_UNQNAME
}
cloneLIST()
{
  setDbEnv $SOURCE_STANDBY
  SOURCE_STANDBY_DBU=$ORACLE_UNQNAME
  
  libAction "Choose a single file of the database"
  testFile=$(exec_sql "/ as sysdba" "
SELECT
  regexp_replace(regexp_replace(lower(name),'^(.*)/([^/]*)$','\2'),'_*stby.*$','')
FROM
  (SELECT   name
   FROM     v\$datafile
   ORDER BY file#
  )
WHERE
  ROWNUM = 1;")
  testFileOrig=$(echo $testFile | sed -e "s;_;.;g")
  echo "$testFile/$testFileOrig"
  echo "    The following operation can be very long"
  echo
  echo "   +--------------------------------------------------------------------------------------+"
  echo "   |           C L O N E   H I E R A R C H Y   O F   T H I S   D A T A B A S E            |"
  echo "   +--------------------------------------------------------------------------------------+"
  echo
  setASMEnv
  echo
  exec_sql "/ as sysdba" "
define testFile=$testFile
define testFileOrig=$testFileOrig
define zone=$ZONE
define db=$ORACLE_UNQNAME
define data_dg=DATAC
set lines 200
set verify off
set heading on
col file_hierarchy format a200
col lvl noprint
col clone_type noprint
select
    rpad('    TM&ZONE'||regexp_replace(clonefilename,'.*_STBY([^_.]*).*$','\1'),70) || '- ORIGINAL Database Copy/Test master (Files for snapshots)' file_hierarchy
   ,0                                                               lvl
   ,'00-MAIN' clone_type
from
  x\$ksfdsscloneinfo /*v\$clonedfile*/
where
  snapshotfilename  like '+DATA%&TestFile%'
  and regexp_like(clonefilename , '.*_STBY[^_]*$')
UNION
select
  rpad(
   lpad(' ' , (lev*5) - 1,' ') || 
             decode (typ              
                    ,'01-TESTMASTER_SNAP'  ,'SM' || suffix
                    ,'02-SNAPSHOT'         ,'  SN' || suffix
                    ,'03-TESTMASTER'       ,'     TM&ZONE' || suffix
                    ,'04-SPARSE'           ,'* STBY' || suffix
                    ,'?' || suffix)
       ,70) || '- ' ||
             decode (typ              
                    ,'01-TESTMASTER_SNAP'  ,'Test master snapshot (RO)'
                    ,'02-SNAPSHOT'         ,'Snapshot (RW)'
                    ,'03-TESTMASTER'       ,'Test master (Files for snapshots)'
                    ,'04-SPARSE'           ,'Sparse standby (Redo Apply)'
                    ,'Unknown') file_hierarchy
  ,lev
  ,typ
from ( ----------------------------------------------------------- Below select is the same in listSparseStandby --------------------------------------------
    select
       level lev
      ,decode(regexp_replace(fi.code,'([^ ]*) ([^ ]*)','\1') || cl.cloned
             ,'SM'            ,'01-TESTMASTER_SNAP'
             ,'SN'            ,'02-SNAPSHOT'
             ,'STBYYES'       ,'03-TESTMASTER'
             ,'STBY'          ,'04-SPARSE'
             ,'UNKNOWN') typ
      ,nvl(cl.suffix_of_clone,regexp_replace(fi.code,'([^ ]*) ([^ ]*)','\2')) suffix
      ,fi.clone f
      ,fi.parent f
      ,cl.suffix_of_clone f
    from
      (select
         lower(regexp_replace(SNAPSHOTFILENAME,'^(.*)/([^/]*)$','\2')) parent
        ,lower(
             regexp_replace(
               regexp_replace( CLONEFILENAME
                              ,'^(.*)/([^/]*)$'
                              ,'\2')
                              ,'\.[0-9.]*$'
                              ,''
                             )
                           ) clone
        ,regexp_replace(
           regexp_replace(
             regexp_replace(upper(CLONEFILENAME)
                           ,'^(.*)/([^/]*)$'
                           ,'\2')
                         ,'\.[0-9.]*$'
                         ,''
                         )
                       ,'.*_(STBY|SM|SN)([^_]*)$'
                       ,'\1 \2'
                       ) code
      --  ,lower(regexp_replace(regexp_replace(CLONEFILENAME,'^(.*)/([^/]*)$','\2'),'\.[0-9.]*$','')) clone_folder
      --  ,lower(regexp_replace(regexp_replace(SNAPSHOTFILENAME,'^(.*)/([^/]*)$','\2'),'\.[0-9.]*$',''))  parent_folder
        ,SNAPSHOTFILENAME
        ,CLONEFILENAME
      from 
        x\$ksfdsscloneinfo /*v\$clonedfile*/
      where
         CLONEFILENAME like '%&testFile%'
      ) fi
      left join (select
              'YES' cloned
              ,lower(
                   regexp_replace(
                     regexp_replace( SNAPSHOTFILENAME
                                    ,'^(.*)/([^/]*)$'
                                    ,'\2')
                                    ,'\.[0-9.]*$'
                                    ,''
                                   )
                                 ) master
              ,lower(
                   regexp_replace(
                     regexp_replace( CLONEFILENAME
                                    ,'^(.*)/([^/]*)$'
                                    ,'\2')
                                    ,'\.[0-9.]*$'
                                    ,''
                                   )
                                 ) clone_of_clone
              ,upper(
                 regexp_replace(
                   regexp_replace(
                     regexp_replace( CLONEFILENAME
                                    ,'^(.*)/([^/]*)$'
                                    ,'\2')
                                    ,'\.[0-9.]*$'
                                    ,''
                                   )
                       ,'.*_(STBY|SM|SN)([^_]*)$'
                       ,'\2'
                       )
                                 ) suffix_of_clone
            from
              x\$ksfdsscloneinfo /*v\$clonedfile*/
            where
               SNAPSHOTFILENAME like '%&testFile%'
           ) cl on (fi.clone = cl.master)
    connect by parent = prior fi.clone
    start with parent='&testFileOrig' 
    )
order by 2,3
;
  "
}
_____________________________SnapshotsManagement() { : ;}
snapCREATE()
{
  [ "$SUFFIX" = "" ] && die "Suffix is mandatory for snapshot creation"
  [ "$SNAPDB" = "" ] && die "SNAPSHOT DB Name required for SNAPSHOT creation"
  
  [ "$(listSparseStandBy | grep TM${ZONE}${SUFFIX} | grep -v grep)" = "" ] && die "No test master for ZONE $ZONE with Suffix $SUFFIX" 
  [ ! -f /var/opt/oracle/creg/$SNAPDB.ini ] && die "$SNAPDB is not a cloud managed DATABASE"
  setDbEnv $SOURCE_STANDBY
  SOURCE_DB_UNIQUE_NAME=$ORACLE_UNQNAME
  
  startStep "Ckeck that $SNAPDB Cannot be started"
  setDbEnv $SNAPDB
  
  libAction "Status of $SNAPDB"
  mode=$(exec_sql "/ as sysdba" "select open_mode from v\$database;")
  [ $? -ne 0 ] && mode="Not Accessible" 
  echo $mode
  if [ "$mode" = "Not Accessible" ]
  then
    libAction "Try to start $SNAPDB"
    exec_srvctl "start database -d $ORACLE_UNQNAME" >/dev/null 2>&1
    if [ $? -eq 0 ]
    then
      echo "Database has started"
      die "$SNAPDB has been started, please drop it first"
    else
      echo "Not startable ... Continuing"
    fi
  else
    die "$SNAPDB is $mode, please drop it first"
  fi

  endStep
  
  startStep "Create the snapshot"

  existingClones="$(listSparseStandBy | grep "^TM${ZONE}" | sed -e "s;TM${ZONE};;")" 
  libAction "Check if $SUFFIX is available as a test master"
  [ "$(echo "$existingClones" | grep $SUFFIX)" = "" ] && { echo "ERROR" ; die "A test master with suffix $SUFFIX does not exists" ; } || echo OK

  setASMEnv
  libAction "Copy Wallet of the STANDBY on $(hostname -s)"
  test -d /var/opt/oracle/dbaas_acfs && \
     rm -rf /var/opt/oracle/dbaas_acfs/$SNAPDB && \
     mkdir -p /var/opt/oracle/dbaas_acfs/$SNAPDB && \
     cp -rp /var/opt/oracle/dbaas_acfs/$SOURCE_STANDBY/* /var/opt/oracle/dbaas_acfs/$SNAPDB && \
     echo OK || { echo ERROR ; die "Unable to copy the Wallet" ; } 
     
  
    libAction "Generate controlfile creation script"
    sed -e '1,/--     Set #2. RESETLOGS case/d' \
        -e "/ONLINELOG/ s/'+${DATA_DG}.*'/'+${DATA_DG}'/" \
        -e "/ONLINELOG/ s/'+${RECO_DG}.*'/'+${RECO_DG}'/" \
        -e "/CREATE CONTROLFILE/ s/REUSE/REUSE SET/" \
        -e "/CREATE CONTROLFILE/ s/FORCE LOGGING //" \
        -e "/^RECOVER/d" \
        -e "/^STARTUP/d" \
        -e "/^CREATE CONTROLFILE/ s/${SOURCE_STANDBY}/${SNAPDB}/g" \
        -e"/-- Configure RMAN configuration record 1/,$ d" \
        $INFO_DIR/$SOURCE_STANDBY/$SUFFIX/ctrlFile_STBY${SUFFIX}.sql > $INFO_DIR/$SNAPDB/ctrlFile_$SNAPDB.sql && \
      echo OK || { echo ERROR ; die "Unable to generate the controlfile creation script" ; } 

  setDbEnv $SNAPDB

    exec_sql -no_error "/ as sysdba" "shutdown abort" "Stop the database"
    exec_sql "/ as sysdba" "startup nomount" "Starting NOMOUNT"
    exec_sql "/ as sysdba" " 
alter system set cluster_database=false scope=spfile;" "Remove cluster database"    
    exec_sql -no_error "/ as sysdba" "shutdown immediate" "Stop the database"
    exec_sql "/ as sysdba" "startup nomount" "Startup nomount" || die "unable to start the database (NOMOUNT)"
    exec_sql "/ as sysdba" " 
start $INFO_DIR/$SNAPDB/ctrlFile_$SNAPDB.sql
  " "Create the controlfile"
  
    libAction "Get controlfile name"
    ctr=$(exec_sql "/ as sysdba" "
set pages 0 lines 500
select value from v\$parameter where name='control_files' ;") || die "Unable to get the controlfile name"
    echo "$ctr"

    exec_sql "/ as sysdba" "alter system set control_files='$ctr' scope=spfile ;" "Set the control file in SPFILE" || die "Unable to change the controlfile name"
    exec_sql -no_error "/ as sysdba" "shutdown immediate" "Stop the database"
    exec_sql "/ as sysdba" "startup mount" "starting in mount mode" || die "Unable to start the database (MOUNT)"
    
    libAction "Create ASM folders" ; echo ".../..."
    dirList=$(exec_sql "/ as sysdba" "
select
  /**/replace(replace (dir,'${DATA_DG}','${SPARSE_DG}'),'$SOURCE_DB_UNIQUE_NAME','$ORACLE_UNQNAME') a
/**/from (
            select distinct         substr(name,1,instr(name,'/',-1,1)-1) dir                                    from v\$datafile 
      union select distinct         substr(name,1,instr(name,'/',-1,2)-1)                                        from v\$datafile 
      union select distinct         substr(name,1,instr(name,'/',-1,3)-1)                                        from v\$datafile 
      union select distinct         substr(name,1,instr(name,'/',-1,4)-1)                                        from v\$datafile 
      union select distinct         substr(name,1,instr(name,'/',-1,5)-1)                                        from v\$datafile 
      union select distinct         substr(name,1,instr(name,'/',-1,6)-1)                                        from v\$datafile 
     )
where 
  /**/nvl(dir,'+${DATA_DG}') not in ('+${DATA_DG}','+${RECO_DG}','+${SPARSE_DG}') ;     ") || die "Unable to create folders creation statements"
  echo "$dirList" | while read d
  do
    createASMDir "$d" "    - "
  done

    exec_sql "/ as sysdba" "
set newpage 0 linesize 999 pagesize 0 feedback off heading off echo off space 0 tab off trimspool on
SPOOL $INFO_DIR/$SNAPDB/renameFor_$SNAPDB.sql
select 'EXECUTE dbms_dnfs.clonedb_renamefile ('||''''||name||''''||','||''''||replace(replace(replace(name,'.','_'),'${DATA_DG}/','${SPARSE_DG}/'),'$SOURCE_DB_UNIQUE_NAME','$ORACLE_UNQNAME')||'_SN${SUFFIX}'''||');' from v\$datafile;
" "Generate rename files statements"    
  echo "    - Rename script : $INFO_DIR/$SNAPDB/renameFor_$SNAPDB.sql"

  setAccessControl_grid
  
    exec_sql "/ as sysdba" "
start $INFO_DIR/$SNAPDB/renameFor_$SNAPDB.sql
" "Renaming datafiles for $ORACLE_UNQNAME" || { removeAccessControl_grid ; die "Unable to rename the files" ; }
    exec_sql "/ as sysdba" "alter database open resetlogs;" "Opening the database with RESETLOGS" || { removeAccessControl_grid ; die "Unable to open RESETLOGS" ; }

   removeAccessControl_grid
    mode=$(exec_sql "/ as sysdba" "select open_mode from v\$database;")
    libAction "Database $ORACLE_UNQNAME is" ; echo $mode
    [ "$mode" != "READ WRITE" ] && die "Database is not OPENED READ WRITE"
    exec_sql "/ as sysdba" "alter system set cluster_database=true scope=spfile;" "Set cluster database to true" || die "unable to stop the database"
    exec_sql "/ as sysdba" "shutdown immediate" "Stop database" || die "unable to stop the database"
    
    exec_srvctl "start database -d $ORACLE_UNQNAME" "Start with srvctl"
    exec_srvctl "status database -d $ORACLE_UNQNAME"

    
    nb_pdb=$(exec_sql "/ as sysdba" "select to_char(count(*)) from v\$pdbs where name != 'PDB\$SEED' ;")
    if [ "$nb_pdb" = "1" ]
    then
      new_pdb=$(echo $SNAPDB | sed -e "s;.$;;")
      echo 
      echo "    There is only one PDB, renaming it to $new_pdb"
      echo
      pdb=$(exec_sql "/ as sysdba" "select name from v\$pdbs where name != 'PDB\$SEED' ;")
      exec_sql "/ as sysdba" "
alter pluggable database $pdb close immediate instances=all ;
alter pluggable database $pdb open restricted ;
alter session set container=$pdb ;
alter pluggable database $pdb rename global_name to $new_pdb ;
alter pluggable database $new_pdb close immediate instances=all ;
alter pluggable database $new_pdb open instances=all ;" "rename $pdb to $new_pdb"
    fi
    exec_sql "/ as sysdba" "
show pdbs" 
    
# TODO
# rename file + open
# stop
# start
    
  endStep
}
snapDROP()
{
  [ "$SNAPDB" = "" ] && die "SNAPSHOT DB Name required for SNAPSHOT creation"
  [ ! -f /var/opt/oracle/creg/$SNAPDB.ini ] && die "$SNAPDB is not a cloud managed DATABASE"
  setDbEnv $SNAPDB
  
  libAction "Status of $SNAPDB"
  mode=$(exec_sql "/ as sysdba" "select open_mode from v\$database;")
  [ $? -ne 0 ] && mode="Not Accessible" 
  echo $mode
  if [ "$mode" = "Not Accessible" ]
  then
    exec_srvctl "start database -d $ORACLE_UNQNAME" "Try to start $SNAPDB"
    if [ $? -ne 0 ] 
    then
      started=NO
      echo ""
      echo "Database cannot be started ..."
      echo
      libAction "Test if backup of init file exists"
      [ "$(ls $INFO_DIR/$SNAPDB/init_*)" != "" ] && echo OK || { echo ERROR ; die "No init file backup available" ; }
      libAction "Test if backup of init file exists"
      [ "$(ls $INFO_DIR/$SNAPDB/passwd_*)" != "" ] && echo OK || { echo ERROR ; die "No password file backup available" ; }
    fi
  fi
  if [ "$started" != "NO" ]
  then
    d=$(date +%Y%m%d_%H%M%S)
    mkdir -p $INFO_DIR/$SNAPDB
    chmod 775 $INFO_DIR/$SNAPDB
    exec_sql "/ as sysdba" "create pfile='$INFO_DIR/$SNAPDB/init_${SNAPDB}_${d}.ora' from spfile;" "Saving INIT.ora" || die "Unable to save the init.ora file"
    pwfile=$(srvctl config database -d $ORACLE_UNQNAME | grep "Password file" | cut -f2 -d: | sed -e "s; ;;")
    exec_asmcmd "pwcopy $pwfile $INFO_DIR/$SNAPDB/passwd_${SNAPDB}_${d}.ora" "Saving password file" || die "unable to save the password file"
    exec_srvctl "config database -d $ORACLE_UNQNAME"
  fi

  
  exec_srvctl "stop database -d $ORACLE_UNQNAME -o abort"      "Stopping $ORACLE_UNQNAME" 
  [ "$(srvctl status database -d $ORACLE_UNQNAME | grep -vi "not running" | grep -v grep | grep "running")" != "" ] && die "Database not stopped"
  sleep 10
  
  setASMEnv
  d=+$DATA_DG/$ORACLE_UNQNAME
  if [ "$(asmcmd --privilege sysdba ls -d $d 2>/dev/null)" != "" ] 
  then
    exec_asmcmd "rm -rf $d" "Removing $d" || die "Error in ASM Operation"
  fi
  d=+$RECO_DG/$ORACLE_UNQNAME
  if [ "$(asmcmd --privilege sysdba ls -d $d 2>/dev/null)" != "" ] 
  then
    exec_asmcmd "rm -rf $d" "Removing $d" || die "Error in ASM Operation"
  fi
  d=+$SPARSE_DG/$ORACLE_UNQNAME
  if [ "$(asmcmd --privilege sysdba ls -d $d 2>/dev/null)" != "" ] 
  then
    exec_asmcmd "rm -rf $d" "Removing $d" || die "Error in ASM Operation"
  fi
  
  exec_asmcmd "mkdir +$DATA_DG/$ORACLE_UNQNAME"                "Creating +$DATA_DG/$ORACLE_UNQNAME"                  || die "Error in ASM Operation"
  exec_asmcmd "mkdir +$DATA_DG/$ORACLE_UNQNAME/PARAMETERFILE" "Creating +$DATA_DG/$ORACLE_UNQNAME/PARAMETERFILE"     || die "Error in ASM Operation"
  exec_asmcmd "mkdir +$DATA_DG/$ORACLE_UNQNAME/PASSWD"        "Creating +$DATA_DG/$ORACLE_UNQNAME/PASSWD"            || die "Error in ASM Operation"
  exec_asmcmd "mkdir +$RECO_DG/$ORACLE_UNQNAME"               "Creating +$RECO_DG/$ORACLE_UNQNAME"                   || die "Error in ASM Operation"
  pwfile=$(ls -1rt $INFO_DIR/$SNAPDB/passwd_* | tail -1)
  exec_asmcmd "pwcopy $pwfile +$DATA_DG/$ORACLE_UNQNAME/PASSWD/pw$SNAPDB.ora" "Creating password file" || die "unable to create the password file"
  
  setDbEnv $SNAPDB

  exec_srvctl "modify database -d $ORACLE_UNQNAME -pwfile  +$DATA_DG/$ORACLE_UNQNAME/PASSWD/pw$SNAPDB.ora" "Setting password file in clusterware"
  
  # exec_sql "/ as sysdba" "startup nomount" "Startup nomount to create spfile"
  initfile=$(ls -1rt $INFO_DIR/$SNAPDB/init_* | tail -1)
  exec_sql "/ as sysdba" "create spfile='+$DATA_DG/$ORACLE_UNQNAME/PARAMETERFILE/spfile$SNAPDB.ora' from pfile='$initfile';" "Creating spfile"
  # exec_sql "/ as sysdba" "shutdown abort" "Shutdown"
  exec_srvctl "modify database -d $ORACLE_UNQNAME -spfile  +$DATA_DG/$ORACLE_UNQNAME/PARAMETERFILE/spfile$SNAPDB.ora" "Setting password file in clusterware"

  exec_srvctl "config database -d $ORACLE_UNQNAME" 
}

_____________________________TestMasterManagement() { : ;}
testMasterSTART()
{
  setDbEnv $SOURCE_STANDBY
  SOURCE_DB_UNIQUE_NAME=$ORACLE_UNQNAME

  [ "$SUFFIX" = "" ] && die "Suffix is mandatory for test Master Operations"

  export ORACLE_SID=$TEST_MASTER

  startStep "Check test master Existence"
  showEnv
  existingClones="$(listSparseStandBy | grep "^TM${ZONE}" | sed -e "s;TM${ZONE};;")" 
  libAction "Check if $SUFFIX is available as a test master"

  [ "$(echo "$existingClones" | grep $SUFFIX)" = "" ] && { echo "ERROR" ; die "A test master with suffix $SUFFIX does not exists" ; } || echo OK
  
  libAction "Check $TEST_MASTER database"
  if [ ! -f $INFO_DIR/$SOURCE_STANDBY/$SUFFIX/init${TEST_MASTER}.ora ]
  then
    echo "Not Created"
    next=CREATION
  else
    echo "Init.ora exists"
  fi
  
  export ORACLE_SID=$TEST_MASTER
  
  if [ "$(ps -ef | grep smon_$ORACLE_SID | grep -v grep)" != "" ]
  then
    exec_sql "/ as sysdba" "select open_mode from v\$database;" "DB started, testing if $ORACLE_SID is accessible"
    status=$?
  else
    exec_sql "/ as sysdba" "startup mount pfile='$INFO_DIR/$SOURCE_STANDBY/$SUFFIX/init${TEST_MASTER}.ora';
    alter database open read only ;
    " "Try to start $TEST_MASTER"
    status=$?
  fi
  if [ $status -ne 0 ]
  then
    exec_sql "/ as sysdba" "Shutdown abort" "Unable to start, stopping the instance" || die "Unable to stop the $TEST_MASTER database"
    next=CREATION
  fi
  
  endStep

  if [ "$next" = "CREATION" ]
  then
    startStep "Create test Master for $SUFFIX ($TEST_MASTER)"
    setDbEnv $SOURCE_STANDBY
    echo "\
    INFORMATION:
    ===========
    
       This database is a temporary database, not integrated in the cloud tooling and not RACed
  It is only needed if you want to query its structure or original data. It uses the same ORACLE
  HOME than the sparse stand-by and is only managed by this script....
   
  To be able to open this database, we create a snapshot, which remains read-only
  
      ORACLE_HOME    : $ORACLE_HOME
      ORACLE_SID     : $TEST_MASTER
      DB_NAME        : $TEST_MASTER
      DB_UNIQUE_NAME : $TM_UNIQUE_NAME
      initFile       : $INFO_DIR/$SOURCE_STANDBY/$SUFFIX/init${TEST_MASTER}.ora
    "
    
    libAction "Copy Wallet of the STANDBY"
    test -d /var/opt/oracle/dbaas_acfs && \
       rm -rf /var/opt/oracle/dbaas_acfs/$TEST_MASTER && \
       mkdir -p /var/opt/oracle/dbaas_acfs/$TEST_MASTER && \
       cp -rp /var/opt/oracle/dbaas_acfs/$SOURCE_STANDBY/* /var/opt/oracle/dbaas_acfs/$TEST_MASTER && \
       echo OK || { echo ERROR ; die "Unable to copy the Wallet" ; } 

    libAction "Create init.ora"
    sed -e "s;$ORACLE_UNQNAME;$TM_UNIQUE_NAME;g" \
        -e "s;$SOURCE_STANDBY;$TEST_MASTER;g" \
        -e "s;cluster_database=true;cluster_database=false;g" \
           $INFO_DIR/$SOURCE_STANDBY/$SUFFIX/initOra_STBY${SUFFIX}.ora > $INFO_DIR/$SOURCE_STANDBY/$SUFFIX/init${TEST_MASTER}.ora && \
      echo OK || { echo ERROR ; die "Unable to create the INIT.ORA for test master" ; } 
      
    libAction "Create a single instance INIT.ORA" ; echo ".../..."
    libAction "Remove instance 2 parameters" "    -" 
    sed -i "/^[^\.]*2\./ d" $INFO_DIR/$SOURCE_STANDBY/$SUFFIX/init${TEST_MASTER}.ora && echo OK || { echo ERROR ; die "Unable to modify init" ; }
    libAction "Remove instance 3 parameters" "    -" 
    sed -i "/^[^\.]*3\./ d" $INFO_DIR/$SOURCE_STANDBY/$SUFFIX/init${TEST_MASTER}.ora && echo OK || { echo ERROR ; die "Unable to modify init" ; }
    libAction "Transform instance 1 parameters" "    -" 
    sed -i "s/^${TEST_MASTER}1\./${TEST_MASTER}./" $INFO_DIR/$SOURCE_STANDBY/$SUFFIX/init${TEST_MASTER}.ora && echo OK || { echo ERROR ; die "Unable to modify init" ; }
    
    libAction "Generate controlfile creation script"
    sed -e '1,/--     Set #2. RESETLOGS case/d' \
        -e "/ONLINELOG/ s/'+${DATA_DG}.*'/'+${DATA_DG}'/" \
        -e "/ONLINELOG/ s/'+${RECO_DG}.*'/'+${RECO_DG}'/" \
        -e "/CREATE CONTROLFILE/ s/REUSE/REUSE SET/" \
        -e "/CREATE CONTROLFILE/ s/FORCE LOGGING //" \
        -e "/^RECOVER/d" \
        -e "/^STARTUP/d" \
        -e "/^CREATE CONTROLFILE/ s/${SOURCE_STANDBY}/${TEST_MASTER}/g" \
        -e"/-- Configure RMAN configuration record 1/,$ d" \
        $INFO_DIR/$SOURCE_STANDBY/$SUFFIX/ctrlFile_STBY${SUFFIX}.sql > $INFO_DIR/$SOURCE_STANDBY/$SUFFIX/ctrlFile_$TEST_MASTER.sql && \
      echo OK || { echo ERROR ; die "Unable to generate the controlfile creation script" ; } 
    
    
    export ORACLE_SID=$TEST_MASTER 

    exec_sql "/ as sysdba" "
startup nomount pfile='$INFO_DIR/$SOURCE_STANDBY/$SUFFIX/init${TEST_MASTER}.ora'
start $INFO_DIR/$SOURCE_STANDBY/$SUFFIX/ctrlFile_$TEST_MASTER.sql
  " "Create the database $TEST_MASTER"
  
    libAction "Get controlfile name"
    ctr=$(exec_sql "/ as sysdba" "
set pages 0 lines 500
select value from v\$parameter where name='control_files' ;")
    echo "$ctr"
    
    libAction "Set control_file in init.ora"
    sed -i "s;^.*control_files=.*$;*.control_files=$ctr;g" \
      $INFO_DIR/$SOURCE_STANDBY/$SUFFIX/init${TEST_MASTER}.ora && echo OK || { echo ERROR ; die "Unable to modify init" ; }

    exec_sql -no_error "/ as sysdba" "shutdown immediate" "Stopping $TEST_MASTER"
    exec_sql "/ as sysdba" "
startup mount pfile='$INFO_DIR/$SOURCE_STANDBY/$SUFFIX/init${TEST_MASTER}.ora'
             " "Starting $TEST_MASTER and mounting"
    infoAction "Create ASM folders ($SOURCE_DB_UNIQUE_NAME --> $TM_UNIQUE_NAME)" 
    dirList=$(exec_sql "/ as sysdba" "
select
  /**/replace(replace (dir,'${DATA_DG}','${SPARSE_DG}'),'$SOURCE_DB_UNIQUE_NAME','$TM_UNIQUE_NAME') a
/**/from (
            select distinct         substr(name,1,instr(name,'/',-1,1)-1) dir                                    from v\$datafile 
      union select distinct         substr(name,1,instr(name,'/',-1,2)-1)                                        from v\$datafile 
      union select distinct         substr(name,1,instr(name,'/',-1,3)-1)                                        from v\$datafile 
      union select distinct         substr(name,1,instr(name,'/',-1,4)-1)                                        from v\$datafile 
      union select distinct         substr(name,1,instr(name,'/',-1,5)-1)                                        from v\$datafile 
      union select distinct         substr(name,1,instr(name,'/',-1,6)-1)                                        from v\$datafile 
     )
where 
/**/  nvl(dir,'+${DATA_DG}') not in ('+${DATA_DG}','+${RECO_DG}','+${SPARSE_DG}') ;     ") || die "Unable to create folders creation statements"
  echo "$dirList" | while read d
  do
    createASMDir "$d" "    - "
  done

    exec_sql "/ as sysdba" "
set newpage 0 linesize 999 pagesize 0 feedback off heading off echo off space 0 tab off trimspool on
SPOOL $INFO_DIR/$SOURCE_STANDBY/$SUFFIX/renameFor_$TEST_MASTER.sql
select 'EXECUTE dbms_dnfs.clonedb_renamefile ('||''''||name||''''||','||''''||replace(replace(replace(name,'.','_'),'${DATA_DG}/','${SPARSE_DG}/'),'$SOURCE_DB_UNIQUE_NAME','$TM_UNIQUE_NAME')||'_SM${SUFFIX}'''||');' from v\$datafile;
" "Generate rename files statements"    
  echo "    - Rename script : $INFO_DIR/$SOURCE_STANDBY/$SUFFIX/renameFor_$TEST_MASTER.sql"

  setAccessControl_grid
  
    exec_sql "/ as sysdba" "
start $INFO_DIR/$SOURCE_STANDBY/$SUFFIX/renameFor_$TEST_MASTER.sql
" "Renaming datafiles for $TM_UNIQUE_NAME" || { removeAccessControl_grid ; die "Unable to rename the files" ; }
    exec_sql "/ as sysdba" "alter database open resetlogs;" "Opening the database with RESETLOGS" || { removeAccessControl_grid ; die "Unable to open RESETLOGS" ; }

   removeAccessControl_grid
   
    exec_sql "/ as sysdba" "
shutdown immediate
startup mount pfile='$INFO_DIR/$SOURCE_STANDBY/$SUFFIX/init${TEST_MASTER}.ora'
alter database open read only ;
  " "Stop $TEST_MASTER and restart read only"
    mode=$(exec_sql "/ as sysdba" "select open_mode from v\$database;")
    libAction "Database $TEST_MASTER is" ; echo $mode
    [ "$mode" != "READ ONLY" ] && die "Database is not OPENED READ ONLY"
    endStep
  fi
  
}
testMasterSTOP()
{
  setDbEnv $SOURCE_STANDBY

  [ "$SUFFIX" = "" ] && die "Suffix is mandatory for test Master Operations"
  startStep "Stop database $TEST_MASTER"
  export ORACLE_SID=$TEST_MASTER
  exec_sql "/ as sysdba" "Shutdown abort;" #"Unable to start, stopping the instance" || die "Unable to stop the $ORACLE_SID database"
  endStep
  
}
testMasterDROP()
{
  setDbEnv $SOURCE_STANDBY

  [ "$SUFFIX" = "" ] && die "Suffix is mandatory for test Master Operations"
  startStep "Stop database $TEST_MASTER"
  export ORACLE_SID=$TEST_MASTER
  exec_sql "/ as sysdba" "Shutdown abort;" #"Unable to start, stopping the instance (errors ignored)"
  endStep
  setASMEnv
  startStep "Drop ASM and FS directories $TEST_MASTER/$TM_UNIQUE_NAME"
  libAction "Remove ASM directories" ; echo ".../..."
  removeASMDir "+${SPARSE_DG}/${TM_UNIQUE_NAME}"
  removeASMDir "+${DATA_DG}/${TM_UNIQUE_NAME}"
  removeASMDir "+${RECO_DG}/${TM_UNIQUE_NAME}" 
  libAction "Remove $ORACLE_BASE/diag/rdbms/${ORACLE_UNQNAME,,}"
  rm -rf $ORACLE_BASE/diag/rdbms/${ORACLE_UNQNAME,,} && echo ok || die "Unable to remove trace folder"
  endStep
}
testMasterSTATUS()
{
  setDbEnv $SOURCE_STANDBY

  startStep "TEST Masters status"
  echo
  listSparseStandBy | grep "^TM" | while read tm
  do
    libAction "Test master $tm" 
    if [ "$(ps -ef | grep smon_$tm | grep -v grep)" = "" ] 
    then
      echo "Not Started"
    else
      echo "Started"
      libAction "Database open mode" "    -"
      export ORACLE_SID=$tm
      s=$(exec_sql "/ as sysdba" "select open_mode from v\$database;")
      echo "$s"
    fi
  done    
  echo
  endStep
  
}
_____________________________main() { : ; }
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

set -o pipefail

#if tty -s
if false
then
  die "Please run this script in nohup mode"
fi


set -o pipefail

SCRIPT=$(basename $0)
SCRIPT_BASE=$(basename $SCRIPT .sh)
SCRIPT_LIB="Database sparse cloning over DATAGUARD utility"

#[ "$(id -un)" != "oracle" ] && die "Merci de lancer ce script depuis l'utilisateur \"oracle\""
#[ "$(hostname -s | sed -e "s;.*\([0-9]\)$;\1;")" != "1" ] && die "Lancer ce script depuis le premier noeud du cluster"

# [ "$1" = "" ] && usage
toShift=0
while getopts d:P:T:a:S:nh opt
do
  case $opt in
   # --------- Source Database --------------------------------
   d)   SOURCE_STANDBY=$OPTARG      ; toShift=$(($toShift + 2)) ;;
   P)   PRIMARY_CONNECT=$OPTARG     ; toShift=$(($toShift + 2)) ;;
   # --------- Target Database --------------------------------
   T)   SNAPDB=$OPTARG              ; toShift=$(($toShift + 2)) ;;
   # --------- Modes de fonctionnement ------------------------
   a)   ACTION=$OPTARG              ; toShift=$(($toShift + 2)) ;;
   S)   SUFFIX=$OPTARG              ; toShift=$(($toShift + 2)) ;;
   # --------- Usage ------------------------------------------
   n)   logOutput=NO                ; toShift=$(($toShift + 1)) ;;
   ?|h) usage "Help requested";;
  esac
done
shift $toShift 
# -----------------------------------------------------------------------------
#
#       Analyse des paramètres et valeurs par défaut
#
# -----------------------------------------------------------------------------


[ "$SOURCE_STANDBY" = "" ] && die "Main stand-by databaseis mandatory (-d)"
[ "$ACTION" = "" ] && die "Action not specified (-a)"

LOG_DIR=$HOME/scriptsLOG/$SCRIPT_BASE/$SOURCE_STANDBY
LOG_FILE=$LOG_DIR/${SCRIPT_BASE}_ACTION_$(date +%Y%m%d_%H%M%S).log
CMD_FILE=$LOG_DIR/${SCRIPT_BASE}_ACTION_$(date +%Y%m%d_%H%M%S).cmd
INFO_DIR=$HOME/sparseClonesInfo

ACTION=${ACTION^^}
case $ACTION in
  DROP_ALL)     subLib="Drop all elements to recreate DG"
                LOG_FILE=$(echo $LOG_FILE | sed -e "s;ACTION;$ACTION;")
                CMD_FILE=$(echo $CMD_FILE | sed -e "s;ACTION;$ACTION;")
                ;;
  CLONE_DG)     subLib="Clone DATAGUARD to prepare for a new master"
                LOG_FILE=$(echo $LOG_FILE | sed -e "s;ACTION;$ACTION;")
                CMD_FILE=$(echo $CMD_FILE | sed -e "s;ACTION;$ACTION;")
                ;;
  CLONE_LIST)   subLib="List current clones of the database"
                LOG_FILE=/dev/null
                CMD_FILE=$(echo $CMD_FILE | sed -e "s;ACTION;$ACTION;")
                ;;
  SHOW_ENV)     subLib="Show environment"
                LOG_FILE=/dev/null
                CMD_FILE=""
                ;;
  TRACK_CREATE) subLib="Create the tracking table"
                LOG_FILE=/dev/null
                CMD_FILE=""
                ;;
  TRACK_UPDATE) subLib="Create the tracking table"
                LOG_FILE=/dev/null
                CMD_FILE=""
                ;;
  TRACK_DROP)   subLib="Create the tracking table"
                LOG_FILE=/dev/null
                CMD_FILE=""
                ;;
  TRACK_LIST)   subLib="List the tracking table"
                LOG_FILE=/dev/null
                CMD_FILE=""
                ;;
  TM_START)     subLib="Start (and create) a test master"
                LOG_FILE=$(echo $LOG_FILE | sed -e "s;ACTION;$ACTION;")
                CMD_FILE=$(echo $CMD_FILE | sed -e "s;ACTION;$ACTION;")
                ;;
  TM_STOP)      subLib="Stop a test master"
                LOG_FILE=$(echo $LOG_FILE | sed -e "s;ACTION;$ACTION;")
                CMD_FILE=$(echo $CMD_FILE | sed -e "s;ACTION;$ACTION;")
                ;;
  TM_DROP)      subLib="Drop a test master"
                LOG_FILE=$(echo $LOG_FILE | sed -e "s;ACTION;$ACTION;")
                CMD_FILE=$(echo $CMD_FILE | sed -e "s;ACTION;$ACTION;")
                ;;
  TM_STATUS)    subLib="Test masters status"
                LOG_FILE=$(echo $LOG_FILE | sed -e "s;ACTION;$ACTION;")
                CMD_FILE=""
                ;;
  SNAP_CREATE)  subLib="Setup a snapshot in an existing DB"
                LOG_FILE=$(echo $LOG_FILE | sed -e "s;ACTION;$ACTION;")
                CMD_FILE=$(echo $CMD_FILE | sed -e "s;ACTION;$ACTION;")
                ;;
  SNAP_DROP)  subLib="Drop a snapshot DB"
                LOG_FILE=$(echo $LOG_FILE | sed -e "s;ACTION;$ACTION;")
                CMD_FILE=$(echo $CMD_FILE | sed -e "s;ACTION;$ACTION;")
                ;;
  *)            die "Unrecognized ACTION ($ACTION)"
                ;;
esac

[ "$logOutput" = "NO" ] && { LOG_FILE=/dev/null ; CMD_FILE="" ; }
TMP1=/tmp/$$.tmp
[ "$LOG_FILE" != "" -a "$LOG_FILE" != "/dev/null" ] && mkdir -p $LOG_DIR

mkdir -p $INFO_DIR/$SOURCE_STANDBY

SCRIPT_LIB="$SCRIPT_LIB ($subLib)"

setScriptEnv
 
#[ "$OCI_CONFIG_FILE" = "" ] && OCI_CONFIG_FILE=$HOME/.oci/config
#[ ! -f $OCI_CONFIG_FILE ] && die "UNable to find OCICLI config file"

if ! sudoGrid "id" >/dev/null 2>&1
then
  echo -n "
+====================================================================================================+
|    UNABLE to sudo to grid, some command will need to be manually submitted as 'grid' user,         |
| in this case, the script will not be able to run unattended. To avoid this, you can press          |
| CTRL-C in the next 30 seconds and add the following line in the /etc/sudoers file                  |
|                                                                                                    |
| oracle ALL=(grid) NOPASSWD: ALL                                                                    |
|                                                                                                    |
+====================================================================================================+
  Press ENTER to continue or CTRL-C to abort :"
  read -t 30 rep
  echo
fi

{
  startRun "$SCRIPT_LIB"

  case $ACTION in
    DROP_ALL)       dropALL          ;;
    CLONE_DG)       cloneDG          ;;
    CLONE_LIST)     cloneLIST        ;;
    SHOW_ENV)       showEnv          ;;
    TRACK_CREATE)   trackingCreate   ;;
    TRACK_UPDATE)   trackingUpdate   ;;
    TRACK_DROP)     trackingDrop     ;;
    TRACK_LIST)     trackingList     ;;
    TM_START)       testMasterSTART  ;;
    TM_STOP)        testMasterSTOP   ;;
    TM_DROP)        testMasterDROP   ;;
    TM_STATUS)      testMasterSTATUS ;;
    SNAP_CREATE)    snapCREATE       ;;
    SNAP_DROP)      snapDROP         ;;
  esac ;
  endRun
  
} | tee $LOG_FILE
finalStatus=$?

LOGS_TO_KEEP=10
i=0
ls -1t $LOG_DIR/*.log | while read f
do
  i=$(($i + 1))
  [ $i -gt $LOGS_TO_KEEP ] && { echo "  - Removing $f" ; rm -f $f ; }
done
i=0
ls -1t $LOG_DIR/*.cmd | while read f
do
  i=$(($i + 1))
  [ $i -gt $LOGS_TO_KEEP ] && { echo "  - Removing $f" ; rm -f $f ; }
done

exit $finalStatus