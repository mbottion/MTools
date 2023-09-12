#!/bin/bash
VERSION="1.2"

#
#  History
#
#  Version           Date          Comment
# ------------------ ------------- ------------------------------------------------------------------------------
#  1.0                             Used for HFX1 Cloning : Aug 2023
#  1.1                             Used for HFX1 september & PRF1 
#  1.2               09/09/2023    Fixed redo-log creation on thread 2 & change dbid (optional)
#                                  Fixed the root cause of 'failed' databases (to be used for HFX3 Sept 23)
# ------------------ ------------- ------------------------------------------------------------------------------
#
_____________________________TraceFormating() { : ;}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#     Trace
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#  Usage
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
usage() 
{
# -----------------------------------------------------------------------------------------------
#
#       Usage function
#
# -----------------------------------------------------------------------------------------------
 echo "$SCRIPT :

Usage $1 :
 $SCRIPT -d DBNAME -a ACTION [-S SUFFIX] [-T SNAPDB] [-n] [-f] [-h|-?]

      $SCRIPT_LIB

         -d DBNAME    : Name of the source stand-by
         -a ACTION    : Action to run +--- CLONE_DG         --> Create a clone for DG (used for next iteration)
                                      |    CLONE_LIST       --> List the hierarchy of the clones"
if [ "${1^^}" = "FULL" ]
then
echo "\
                                      |    CLONE_LIST_CB    --> List the hierarchy of the clones (connect-by, very long)
                                      |    TRACK_CREATE     --> Test only : Create tracking table on the primary
                                      |    TRACK_UPDATE     --> Test only : Update tracking table
                                      |    TRACK_DROP       --> Test only : Drop tracking table
                                      |    TRACK_LIST       --> Test only : List Tracking table on all databases
                                      |    TM_START         --> Start the Test MASTER for a given clone (create it if not exists)
                                      |    TM_STOP          --> Stop the test Master
                                      |    TM_DROP          --> Drop the test Master
                                      |    TM_STATUS        --> List the status of the test masters"
fi
echo "                                      |    SNAP_CREATE      --> Create a snapshot DB
                                      |    SNAP_DROP        --> Drop a snapshot DB
                                      |    AUTOTEST         --> Run a test sequence
                                      +--- DROP_ALL         --> Drop everything
         -S SUFFIX    : Suffix to use in place of YYYYMM (6 characters maximum)
         -T SNAPDB    : DB Name of the snapshot
         -f           : Force operation (drop sapshot DB ...)
         -n           : Don't log the output to file
         -?|-h        : Help (-h shows debug and devel options)

  Version : $VERSION
  "
  exit
}
libAction()
{
# -----------------------------------------------------------------------------------------------
#
#       Print a formatted message $1 with indentation $2 and no new line to help formatting a 
#  trace file
#
# -----------------------------------------------------------------------------------------------
  local mess="$1"
  local indent="$2"
  [ "$indent" = "" ] && indent="  - "
  printf "%-90.90s : " "${indent}${mess}"
}
infoAction()
{
# -----------------------------------------------------------------------------------------------
#
#       Print a formatted message $1 with indentation $2 with new line to help formatting a 
#  trace file
#
# -----------------------------------------------------------------------------------------------
  local mess="$1"
  local indent="$2"
  [ "$indent" = "" ] && indent="  - "
  printf "%-s\n" "${indent}${mess}"
}
startRun()
{
# -----------------------------------------------------------------------------------------------
#
#       STart message $1 , keep start-time to calculate run time at the end
#
# -----------------------------------------------------------------------------------------------
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
# -----------------------------------------------------------------------------------------------
#
#       End message , prints the run-time min:secs
#
# -----------------------------------------------------------------------------------------------
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
# -----------------------------------------------------------------------------------------------
#
#       Step Start message $1 , keep start-time to calculate run time at the end of the step
#
# -----------------------------------------------------------------------------------------------
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
# -----------------------------------------------------------------------------------------------
#
#       Step End message , prints the run-time min:secs
#
# -----------------------------------------------------------------------------------------------
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
# -----------------------------------------------------------------------------------------------
#
#       Print error and exit
#
# -----------------------------------------------------------------------------------------------
  [ "$START_INTERM_EPOCH" != "" ] && endRun
  echo "

    ERROR :
      $*
  
  "

  rm -f $PID_FILE

  exit 1
}
_____________________________Environment() { : ;}
setASMEnv()
{
# -----------------------------------------------------------------------------------------------
#
#       Set environment for ASM (node 1 only for now)
#
# -----------------------------------------------------------------------------------------------
  libAction "Set ASM environment"
  . oraenv <<< +ASM1 >$TMP1 2>&1 && echo "OK" || { echo ERROR ; cat $TMP1 ; rm -f $TMP1 ; die "Unable to set environment for ASM" ; }
}
setDbEnv()
{
# -----------------------------------------------------------------------------------------------
#
#       Set oracle env for a specific DATABASE (cloud, for non-cloud, modify according to
#   the customer tools)
#
# -----------------------------------------------------------------------------------------------
  libAction "Set $1 environment"
  . $HOME/$1.env && echo OK || { echo ERROR ; die "Unable to set database environment" ; } 
}
setScriptEnv()
{
# -----------------------------------------------------------------------------------------------
#
#       Main variables needed by the script
#
# -----------------------------------------------------------------------------------------------
echo "
    +--------------------------------------------------------------------------------+
    |   Set main script environment variables                                        |
    +--------------------------------------------------------------------------------+
      ACTION=$ACTION
"
  if [    "$DG_NAMES_NEEDED" = "Y" ] 
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
  SOURCE_STANDBY_UNQNAME=$ORACLE_UNQNAME
  
  DB_PASSWORD=$(getPassDB)
  DO_TRACKING=$(trackingTest)
  
  case $SOURCE_STANDBY in
    *AME*) ZONE=1 ; ZONE_LIB=AME ;;
    *EUR*) ZONE=2 ; ZONE_LIB=EUR ;;
    *ACJ*) ZONE=3 ; ZONE_LIB=ACJ ;;
    *MBO*) ZONE=4 ; ZONE_LIB=MBO ;; # Testing purposes ;-)
    *)     ZONE=0 ;;
  esac
  
  TEST_MASTER="M${ZONE}${SUFFIX}"
  TM_UNIQUE_NAME="${TEST_MASTER}_TM${ZONE}_${SUFFIX}"
}
showEnv()
{
# -----------------------------------------------------------------------------------------------
#
#       Prints script env
#
# -----------------------------------------------------------------------------------------------
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
   doDBID                            : $doDBID
"
}
_____________________________Utilities() { : ;}
getPassDB()
{
# -----------------------------------------------------------------------------------------------
#
#             Get database password in the cloud Wallet
#
# -----------------------------------------------------------------------------------------------
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
# -----------------------------------------------------------------------------------------------
#
#     Execute SQLPLUS command(s), by default if a label is passed, nothing is printed
#  if there is no error
#
# -----------------------------------------------------------------------------------------------

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
# -----------------------------------------------------------------------------------------------
#
#     Execute SRVCTL command, by default if a label is passed, nothing is printed
#  if there is no error
#
# -----------------------------------------------------------------------------------------------
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
# -----------------------------------------------------------------------------------------------
#
#     Execute DGMGRL command, by default if a label is passed, nothing is printed
#  if there is no error
#
# -----------------------------------------------------------------------------------------------
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
# -----------------------------------------------------------------------------------------------
#
#     Execute ASMCMD command, by default if a label is passed, nothing is printed
#  if there is no error
#
# -----------------------------------------------------------------------------------------------
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
# -----------------------------------------------------------------------------------------------
#
#     Create an ASM DIr if non existent, with formatted message
#
# -----------------------------------------------------------------------------------------------
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
# -----------------------------------------------------------------------------------------------
#
#     Remove an ASM DIr if existent, with formatted message
#
# -----------------------------------------------------------------------------------------------
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
# -----------------------------------------------------------------------------------------------
#
#       Execute a command under grid, or prompt the user to run it if sudo not possible
#
# -----------------------------------------------------------------------------------------------
  local cmd="$1"
  if [ "$GRID_SUDO" = "Y" ]
  then
    sudo -nu grid sh -c ". \$HOME/.bash_profile ; $cmd " 
  else
    echo 
    echo "------------------------- To execute under grid --------------------------------------"
    echo "    The following command need to be executed as grid"
    echo "--------------------------------------------------------------------------------------"
    echo
    echo "$cmd"
    echo
    echo "--------------------------------------------------------------------------------------"
    echo "Once done, please press ENTER"
    echo "--------------------------------------------------------------------------------------"
    read rep
  fi
}
setAccessControl_grid()
{
# -----------------------------------------------------------------------------------------------
#
#       ENABLE access control, needed to clone files
#
# -----------------------------------------------------------------------------------------------
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
# -----------------------------------------------------------------------------------------------
#
#     Remove access control
#
# -----------------------------------------------------------------------------------------------
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
# -----------------------------------------------------------------------------------------------
#
#     Set files read-only with a script generated earlier
#
# -----------------------------------------------------------------------------------------------
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
# -----------------------------------------------------------------------------------------------
#
#
#         The functions below are used for test &debugging, they manage a specific table in the primary
#    This section can be useful for people who want to observe the 
#
#
# -----------------------------------------------------------------------------------------------
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

  listSparseStandByFast | grep "^TM" | sort | while read s
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
# -----------------------------------------------------------------------------------------------
#
#         This function drops everithing. it can be used at the end of a cycle before re-creating or re-initializing the 
#   stand-by.
#
# -----------------------------------------------------------------------------------------------
  removeAccessControl_grid
  echo
  infoAction "Drop all databases databases cloned from : $SOURCE_STANDBY"
  echo
  
  listClonesFile=$(mktemp).clones
  tempFile=$(mktemp).tmp

  listSparseStandByFast > $listClonesFile
  
  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -  
  #
  #      Extract the list of snapshots, show them to the user for deletion confirmation
  #
  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -  
  
  grep "^ *SN" $listClonesFile | sed -e "s;^ *;;"  > $tempFile
  
  infoAction "  Snapshot databases" 
  infoAction "  ==============================="
  echo
  printf "       %-10.10s %-10.10s %-10.10s %-20.20s\n" "Code" "DB Name" "Suffix" "DB Unique Name"
  printf "       %-10.10s %-10.10s %-10.10s %-20.20s\n" "------------------------------------------" "------------------------------------------" "------------------------------------------" "------------------------------------------"
  snToDrop=""
  while read s u
  do
    SNAP="$s"
    SUFFIX=$(echo $SNAP | sed -e "s;SN;;")
    SN_UNIQUE_NAME="$u"
    SN=$(echo $SN_UNIQUE_NAME | sed -e "s;_.*$;;")
    printf "       %-10.10s %-10.10s %-10.10s %-20.20s\n" "$SNAP" "$SN" "$SUFFIX" "$SN_UNIQUE_NAME"
    snToDrop="${snToDrop}
$SN"
  done < $tempFile
  
  if [ "$snToDrop" != "" ]
  then
    echo
    echo -n "            The above snapshots may exist, do you want to drop the corresponding databases [Y]|n : "
    [ "$FORCE_FLAG" = "N" ] && read DROP_SN || DROP_SN=Y
    [ "$DROP_TM" = "" ] && DROP_SN=Y
    echo
  else
    DROP_SN=N
  fi  
  
  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -  
  #
  #      Extract the list of test-master databases (if any has been created) , show them to the user for deletion confirmation
  #
  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -  
  
  grep "^ *== M" $listClonesFile | sed -e "s;^STBY;;" -e "s;^ *== ;;"  > $tempFile
  echo 
  infoAction "  Potential test-master databases" 
  infoAction "  ==============================="
  echo

  printf "       %-10.10s %-10.10s %-20.20s\n" "DB Name" "Suffix" "DB Unique Name"
  printf "       %-10.10s %-10.10s %-20.20s\n" "------------------------------------------" "------------------------------------------" "------------------------------------------"
  tmToDrop=""
  while read s
  do
    TEST_MASTER="$s"
    SUFFIX=$(echo $TEST_MASTER | sed -e "s;M${ZONE};;")
    TM_UNIQUE_NAME="${TEST_MASTER}_TM${ZONE}_${SUFFIX}"
    printf "       %-10.10s %-10.10s %-20.20s\n" "$TEST_MASTER" "$SUFFIX" "$TM_UNIQUE_NAME"
    tmToDrop="${tmToDrop}
$TEST_MASTER $SUFFIX $TM_UNIQUE_NAME"
  done < $tempFile
  
  echo
  echo -n "          The above test-master may exist, do you want to drop the corresponding databases [Y]|n : "
  [ "$FORCE_FLAG" = "N" ] && read DROP_TM || DROP_TM=Y
  [ "$DROP_TM" = "" ] && DROP_TM=Y
  echo

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -  
  #
  #      Ask for confirmation of stand-by database
  #
  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -  
  
  echo
  echo -n "                            Do you want to remove $SOURCE_STANDBY and its corresponding DATAGUARD [Y|n] : "
  [ "$FORCE_FLAG" = "N" ] && read DROP_SOURCE || DROP_SOURCE=Y
  [ "$DROP_SOURCE" = "" ] && DROP_SOURCE=Y

  setDbEnv $SOURCE_STANDBY
    
  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -  
  #
  #      Drop the snapshots
  #
  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -  
  
  if [ "${DROP_SN^^}" = "Y" ]
  then
    echo "$snToDrop" | while read SNAPDB SNU
    do
      [ "$SNAPDB" = "" ] && continue
      echo
      snapDROP
    done
  fi  
  
  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -  
  #
  #      Drop the test-masters
  #
  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -  

  if [ "${DROP_TM^^}" = "Y" ]
  then
    echo "$tmToDrop" | while read TEST_MASTER SUFFIX TM_UNIQUE_NAME
    do
      [ "$TEST_MASTER" = "" ] && continue
      testMasterDROP
    done
  fi  

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -  
  #
  #      Drop the stand-by
  #
  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -  
  
  if [ "${DROP_SOURCE^^}" = "Y" ]
  then
    echo
    if [ "$(exec_dgmgrl "show configuration" | grep -vi connected | grep $SOURCE_STANDBY)" != "" ]
    then
      libAction "Primary is"
      prim=$(exec_dgmgrl "show configuration" | grep "Primary database" | awk '{print $1}')
      echo $prim
      libAction "Fast Start Failover for primary is"
      fsf=$(exec_dgmgrl "show database $prim FastStartFailoverTarget" | grep FastStartFailoverTarget | cut -f2 -d"=" | sed -e "s;[ '];;g")
      echo $fsf
      if [ "$fsf" = "$ORACLE_UNQNAME" ]
      then
        exec_dgmgrl "edit database \"$prim\" set property FastStartFailoverTarget=''" "Reset FastStartFailoverTarget property"
      fi
      exec_dgmgrl "remove database \"$ORACLE_UNQNAME\"" "Removing $SOURCE_STANDBY from DG configuration"
    fi    
    saveSpfile=$LOG_DIR/init_${SOURCE_STANDBY}.ora
    exec_sql "/ as sysdba" "
whenever sqlerror continue
startup nomount;
whenever sqlerror exit failure
create pfile='$saveSpfile' from spfile;" "Backup SPFILE" ; status=$?
    exec_srvctl "stop database -d $ORACLE_UNQNAME" "Stop the database"
#
#   This command fails when ran by ORACLE, need to use sudoGrid
#
#    exec_asmcmd "rm -rf $SPARSE_DG/$ORACLE_UNQNAME" "Removing $SPARSE_DG/$ORACLE_UNQNAME"
    libAction "Removing $SPARSE_DG/$ORACLE_UNQNAME"
    sudoGrid "
. oraenv <<< +ASM1
asmcmd rm -rf $SPARSE_DG/$ORACLE_UNQNAME
exit \$?
" >$TMP1 2>&1 \
              && { echo "OK" ; rm -f $TMP1 ; } \
              || { echo "ERROR" ; cat $TMP1 ; rm -f $TMP1 ; }

    exec_asmcmd "rm -rf $RECO_DG/$ORACLE_UNQNAME" "Removing $RECO_DG/$ORACLE_UNQNAME"
    exec_asmcmd "rm -rf $DATA_DG/$ORACLE_UNQNAME" "Removing $DATA_DG/$ORACLE_UNQNAME"
    
    exec_asmcmd "mkdir $DATA_DG/$ORACLE_UNQNAME" "Create $DATA_DG/$ORACLE_UNQNAME" 
    exec_asmcmd "mkdir $DATA_DG/$ORACLE_UNQNAME/PARAMETERFILE" "Create $DATA_DG/$ORACLE_UNQNAME/PARAMETERFILE"
    
    exec_sql "/ as sysdba" "
whenever sqlerror continue
startup nomount pfile='$LOG_DIR/init_${SOURCE_STANDBY}.ora';
whenever sqlerror exit failure
create spfile='+$DATA_DG/$ORACLE_UNQNAME/PARAMETERFILE/spfile.ora' from pfile='$LOG_DIR/init_${SOURCE_STANDBY}.ora' ;
shutdown abort; " \
             "Recreate SPFILE" 
    srvctl modify database -d $ORACLE_UNQNAME -spfile +$DATA_DG/$ORACLE_UNQNAME/PARAMETERFILE/spfile.ora
  
  fi
    
  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -  
  #
  #      List Disk Groups
  #
  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -  
  
  echo "=============== SPRC2 Content ==========================================="
  asmcmd --privilege sysdba ls +SPRC2
  echo "=============== DATAC2 Content =========================================="
  asmcmd --privilege sysdba ls +DATAC2
  echo "=============== RECOC2 Content =========================================="
  asmcmd --privilege sysdba ls +RECOC2

  rm -f $listClonesFile $tempFile
  
}
cloneDG()
{
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

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -  
  #
  #         Open the stand-by in read-only mode and take informations needed later for the
  #  clones. These informations are stored in folders under $HOME/sparseCloningInfo
  #
  #         At this stage, the redo-apply is stopped, it will be restarted after datafiles
  #  cloning
  #
  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -  
  
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

    #
    #     Identify the list of folders used by the database, needed to 
    # create the folder structure in the SPARSE disk group
    #    
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

    #
    #       Generate file rename statements
    #
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

    #
    #      Generate a script to put the original files in read-only
    #
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

    #
    #       Save the original control-file, it will be used to create contolfiles for the clones
    #   after modification
    #
    exec_sql "/ as sysdba" " 
set newpage 0 linesize 999 pagesize 0 feedback off heading off echo off space 0 tab off trimspool on
col trc new_value trc
SELECT value trc FROM v\$diag_info WHERE name = 'Default Trace File';
alter database backup controlfile to trace ;
host cp &trc $scriptCreateControlFile 
                           " "Backup Control File" || die "Error backuping the control file"

    #
    #     Get the original init.ora file
    #
    exec_sql "/ as sysdba" " 
create pfile='$scriptInitOra' from spfile ;
                           " "Backup SPFILE" || die "Error backuping the SPFILE"
                           
    endStep
    
  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -  
  #               Source is prepared and we gathered all required information, start the clone 
  #    now. At the end, the STAND-BY will be composed of SPARSE files in which the redo will
  #    be applied, leaving the original files immutable.
  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -  
    
    startStep "Clone the stand-by"
    
    infoAction "Create ASM Directories ... "
    for d in $(echo "$dirList")
    do
      createASMDir $d
    done
  
    exec_srvctl "stop database -d $ORACLE_UNQNAME" "Stop database $ORACLE_UNQNAME"
    
    #
    #      SOurce files need to be marked as RO to be cloned.
    #
    filesReadOnly_grid

    exec_srvctl "start instance -d $ORACLE_UNQNAME -i $ORACLE_SID" "Start instance $ORACLE_SID"
    #
    #   Rename (clone) the original adatafiles, with only one instance running
    #
    exec_sql "/ as sysdba" "
alter system set standby_file_management=manual scope=both ;
start $scriptRenameFor_StandBy
alter system set standby_file_management=auto scope=both ;" "Rename datafiles to SPARSE" || { removeAccessControl_grid ; die "Error renaming the data files" ; }

    #
    #     STart and opent the database
    #
    exec_srvctl "start database -d $ORACLE_UNQNAME -o OPEN" "Start whole DB"
    exec_sql -no_error "/ as sysdba" "alter database open read only;" "Open the database read only"
    exec_srvctl "status database -d $ORACLE_UNQNAME -v"

    #
    #        Restart the redo-apply
    #
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
  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -  
  #
  #     Check the dataguard status
  #
  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -  
  startStep "Database Information"
  infoAction "Standby status"
  exec_dgmgrl "show configuration" 
  exec_dgmgrl "show database $ORACLE_UNQNAME" 
  exec_dgmgrl "validate database $ORACLE_UNQNAME" 
  libAction "List datafiles folders" ; echo ; echo
  exec_sql "/ as sysdba" "select distinct substr(name,1,instr(name,'/',-1)-1) from v\$datafile order by 1;"
  echo
  #
  #     Remove access control on the disk group since it can have impacts on other databases.
  #
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
findTestMaster()
{
# -----------------------------------------------------------------------------------------------
#
#         Determine if a specific test-master exists.
#
# -----------------------------------------------------------------------------------------------
  infoAction "Check if test master exists for zone : $ZONE_LIB / Suffix : $SUFFIX"
  setDbEnv $SOURCE_STANDBY
  SOURCE_STANDBY_DBU=$ORACLE_UNQNAME
  libAction "Get a file from DB"
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
  echo $testFile
  testFileOrig=$(echo $testFile | sed -e "s;_;.;g")
  setASMEnv
  libAction "Test file existence in ASM"
    nb=$(exec_sql "/ as sysdba" "
define testFile=$testFile
define testFileOrig=$testFileOrig
define suffix=$SUFFIX
set lines 200
set verify off
select to_char(count(*)) from v\$asm_alias where name = '&testFile._STBY&SUFFIX' ;
") || die "Error executind SQL Command $nb"
  
  [ $nb -eq 0 ] && { echo "Not exists ($nb)" ; setDbEnv $SOURCE_STANDBY ; return 1 ; } || { echo "Exists ($nb)" ; setDbEnv $SOURCE_STANDBY ; return 0 ; }
}

listSparseStandByFast() 
{
# -----------------------------------------------------------------------------------------------
#
#         LIsts hierarchy in a simple script usable formal.
#
# -----------------------------------------------------------------------------------------------
  cloneLISTFast SIMPLE
  setDbEnv $SOURCE_STANDBY
  SOURCE_STANDBY_DBU=$ORACLE_UNQNAME
}

cloneLISTFast()
{
# -----------------------------------------------------------------------------------------------
#
#         Lists the hierarchy in a readable format, along with existing databases.
#
#         The "normal" way to do this is to use a connect by, but the statement takes too
#    much time to run (see cloneList()). Here, the statement is complex, but faster
#
# -----------------------------------------------------------------------------------------------
  [ "$1" != "SIMPLE" ] && setDbEnv $SOURCE_STANDBY
  SOURCE_STANDBY_DBU=$ORACLE_UNQNAME
  
  #
  #         We base the analysis on a single file of the database. The one with the
  #   lower file#, it normally belongs to the system TABLESPACE and will not be removed
  #
  [ "$1" != "SIMPLE" ] && libAction "Choose a single file of the database"
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
  if [ "$1" != "SIMPLE" ] 
  then
    echo "$testFile/$testFileOrig"
    echo "    The following operation can be very long"
    echo
    echo "   +--------------------------------------------------------------------------------------+"
    echo "   |           C L O N E   H I E R A R C H Y   O F   T H I S   D A T A B A S E            |"
    echo "   +--------------------------------------------------------------------------------------+"
    echo
  fi
  setASMEnv
  [ "$1" != "SIMPLE" ] && echo
#
#      This statement is replacin a connect-by. The output lookks like :
#
#        +--------------------------------------------------------------------------------------+
#        |           C L O N E   H I E R A R C H Y   O F   T H I S   D A T A B A S E            |
#        +--------------------------------------------------------------------------------------+
#     
#       - Set ASM environment                                                                    : OK
#     
#     TM4202309                                                    - Test master (Files for snapshots)       Cloned on     : 09/09/2023 00:45:55 (Level 1)
#      SN202309                                                    - Snapshot (RW)                           Created on    : 09/09/2023 01:12:46 (Level 1) Target database   : SFOPMBOC_2GN_PAR
#         TM4202310                                                - Test master (Files for snapshots)       Cloned on     : 10/09/2023 15:59:34 (Level 2)
#         == M4202310                                              - Test master snapshot (RO)               Created on    : 10/09/2023 16:13:20 (Level 2)
#             TM4202311                                            - Test master (Files for snapshots)       Cloned on     : 10/09/2023 16:07:38 (Level 3)
#                 * STBY                                           - Sparse standby (Redo Apply)             Syncing since : 10/09/2023 16:07:38 (Level 4) Stand-by database : RFOPMBOC_2GN_PAR 

  exec_sql "/ as sysdba" "
Rem
Rem     Parameters from the Shell
Rem
define testFile=$testFile
define testFileOrig=$testFileOrig
define zone=$ZONE
define db=$ORACLE_UNQNAME
define data_dg=DATAC
define mode='${1:-NORMAL}'
set tab off
set lines 200
set verify off
set heading on
col file_hierarchy format a200
select /* ******************************************************************************* *
        *     Final output, there are two different outputs depending on the value of     *
        * the mode variable                                                               *
        * ******************************************************************************* */
  /**/rpad( 
    /**/lpad(' ' , ((clone_level-1)*4), ' ' ) ||
       /**/decode (clone_type_label              
              ,'01-TESTMASTER'       ,'TM&ZONE' || clone_code
              ,'03-SNAPSHOT'         ,' SN'  || clone_code
              ,'02-TESTMASTER_SNAP'  ,'== M&ZONE'    || clone_code
              ,'04-SPARSE'           ,'* STBY'  || clone_code
              ,'?' ) 
     ,60 ) ||
    case
      when '&mode' != 'SIMPLE' then
        ' - ' ||
             /**/rpad(decode (clone_type_label              
                    ,'01-TESTMASTER'       ,'Test master (Files for snapshots)'
                    ,'02-TESTMASTER_SNAP'  ,'Test master snapshot (RO)'
                    ,'03-SNAPSHOT'         ,'Snapshot (RW)'
                    ,'04-SPARSE'           ,'Sparse standby (Redo Apply)'
                    ,'Unknown' || ' ' || name), 40 ) || case
                                                          when clone_type_label = '01-TESTMASTER' then 'Cloned on     : ' || lead(creation_date,1) over (partition by clone_type order by creation_date)
                                                          when clone_type_label = '04-SPARSE'     then 'Syncing since : ' || creation_date
                                                          else                                         'Created on    : ' || creation_date 
                                                        end || ' (Level ' || clone_level || ') ' 
      else ''
      end ||
                                                        case
                                                          when clone_type_label = '03-SNAPSHOT' then 
                                                            case
                                                              when '&mode' != 'SIMPLE' then
                                                               'Target database   : ' 
                                                              else ''
                                                            end ||
                                                                 (
                                                                    select 
                                                                      folder 
                                                                    /**/from (
                                                                          SELECT
                                                                             gnum
                                                                            ,filnum
                                                                            ,aname folder
                                                                            ,level
                                                                          /**/FROM (
                                                                                 SELECT 
                                                                                    g.name gname
                                                                                   ,a.parent_index pindex
                                                                                   ,a.name aname
                                                                                   ,a.reference_index rindex
                                                                                   ,a.group_number gnum
                                                                                   ,a.file_number filnum
                                                                                 FROM 
                                                                                    v\$asm_alias a
                                                                                   ,v\$asm_diskgroup g
                                                                                 WHERE 
                                                                                     a.group_number = g.group_number
                                                                                 and a.group_number=pre_result.group_number
                                                                                  )
                                                                           START WITH (filnum=pre_result.file_number and gnum=pre_result.group_number)
                                                                           CONNECT BY PRIOR pindex = rindex
                                                                          order by level desc
                                                                         )
                                                                    where 
                                                                      rownum = 1
                                                                 )
                                                          when clone_type_label = '04-SPARSE' then 
                                                            case
                                                              when '&mode' != 'SIMPLE' then
                                                               'Stand-by database : $SOURCE_STANDBY_UNQNAME'
                                                              else ''
                                                            end
                                                         else ''
                                                        end file_hierarchy
/**/from (
     ---------------------------------------------------------------------------------------------------------------------
          select /* ********************************************************************** *
                  *     Finally propagate the LEVEL to other lines other than STBY         *
                  * ********************************************************************** */
             creation_date
            ,name
            ,clone_type
            ,clone_code
            ,case 
               when clone_type = 'SN' then last_value(clone_level) over (order by clone_code)
               when clone_type = 'SM' then last_value(clone_level) over (order by clone_code)
               else clone_level
             end clone_level
            ,clone_type_label
            ,file_number
            ,group_number
          /**/from ( /* ********************************************************************** *
                      *    Determine final clone type, this select might have been avoided     *
                      * ********************************************************************** */
                 select 
                   creation_date
                  ,name
                  ,clone_type
                  ,clone_code
                  ,clone_level
                  ,case clone_type
                    when 'SM'   then '02-TESTMASTER_SNAP'
                    when 'SN'   then '03-SNAPSHOT'
                    when 'STBY' then 
                      case 
                        when clone_code is null then '04-SPARSE'
                        else           '01-TESTMASTER'
                      end
                    else '?'
                   end clone_type_label
                  ,file_number
                  ,group_number
                /**/from (select /* ***************************************************************** *
                                  *      Calculate a level based on the Sparse stand-by clones        *
                                  * and their creation dates                                          *
                                  * ***************************************************************** */
                         creation_date
                        ,name
                        ,clone_type
                        ,case
                          when clone_type = 'STBY'
                            then lead(clone_code,1) over (partition by clone_type order by creation_date) 
                            else clone_code 
                          end clone_code
                        ,case 
                          when clone_type = 'STBY' then rank() over (partition by clone_type order by creation_date)
                          else -1
                         end clone_level
                        ,file_number
                        ,group_number
                      /**/from (select /* ********************************************** *
                                        *    From the file name, extract the type of     *
                                        * clone and the suffix (date). Must be coherent  *
                                        * with the script and the way files are renamed  *
                                        * ********************************************** */
                               creation_date
                              ,name
                              ,regexp_replace(file_code,'^(STBY|SN|SM)(.*)','\1') clone_type
                              ,regexp_replace(file_code,'^(STBY|SN|SM)(.*)','\2') clone_code
                              ,file_number
                              ,group_number
                            /**/from (select  /* *************************************************************** *
                                               *       Get all ASM files where part of the name corresponds to   *
                                               * the file chosen in the database. To have this work, the cloning *
                                               * process must preserve thi part of the name                      *
                                               * *************************************************************** */
                                     /**/to_char(f.creation_date ,'dd/mm/yyyy hh24:mi:ss') creation_date
                                    ,a.name
                                    ,regexp_replace(regexp_replace(case 
                                                                   when lower(a.name) = '&testFileOrig'
                                                                     then lower(replace(a.name,'.','_')) || '_STBY000000'
                                                                   else
                                                                     a.name
                                                                   end 
                                                                  ,'^&testFile._',''),'\.[.0-9]*$','') file_code
                                     ,a.file_number
                                     ,a.group_number
                                  from v\$asm_alias a  
                                  join v\$asm_file  f on (    a.group_number = f.group_number
                                                         and a.file_number = f.file_number )
                                  /**/where (lower(a.name) like '&testFile%' or lower(a.name) = '&testFileOrig' )
                                  and   system_created='Y'
                                 )
                           )
                     )
                 )
     ---------------------------------------------------------------------------------------------------------------------
     ) pre_result
order by 
   clone_level
  ,clone_type_label
  ,to_date(creation_date,'dd/mm/yyyy hh24:mi:ss')
/
  "
}
_____________________________SnapshotsManagement() { : ;}
checkIfCloned()
{
# -----------------------------------------------------------------------------------------------
#
#         Detremine if a given database is a clone of the source stand-by
#
# -----------------------------------------------------------------------------------------------
  echo
  infoAction "Check if $SNAPDB is a clone of $SOURCE_STANDBY"
  setDbEnv $SOURCE_STANDBY
  SOURCE_STANDBY_DBU=$ORACLE_UNQNAME
  libAction "Get a file from DB"
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
  echo $testFile
  setDbEnv $SNAPDB
 libAction "Check existence of a file like $testFile"
nb=$(exec_sql "/ as sysdba" "
SELECT
  to_char(count(*))
FROM
   v\$datafile
WHERE
  name like '%/$testFile%';")
  [ "$nb" = "0" ] && { echo "No ($nb)" ; die "

      $SNAPDB is NOT a clone of $SOURCE_STANDBY, aborting (If this is the first snapshot and 
  if you are sure of the target name, use the -f option)

" ; } || echo "OK, continue to drop"
}
snapCREATE()
{
# -----------------------------------------------------------------------------------------------
#
#         Re-create the SNAPDB database as a clone of the tes-master associated to
#   the source stand-by.
#
# -----------------------------------------------------------------------------------------------
  [ "$SUFFIX" = "" ] && die "Suffix is mandatory for snapshot creation"
  [ "$SNAPDB" = "" ] && die "SNAPSHOT DB Name required for SNAPSHOT creation"
 
  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -  
  #
  #      Check if the test-master exists
  #
  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -  
  findTestMaster $ZONE_LIB $SUFFIX || die "No test master for ZONE $ZONE ($ZONE_LIB) with Suffix $SUFFIX" 
  [ ! -f /var/opt/oracle/creg/$SNAPDB.ini ] && die "$SNAPDB is not a cloud managed DATABASE"
  setDbEnv $SOURCE_STANDBY
  SOURCE_DB_UNIQUE_NAME=$ORACLE_UNQNAME
  
  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -  
  #
  #      We continue only if the SNAPDB cannot be started if the DB can be started, we stop
  # and you must remove it manually
  #
  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -  
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
  
  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -  
  #
  #      We are good to create the snapshot. Snapshot creation is basically
  #
  #      1) Copy the wallet
  #      2) Clone test-master datafiles
  #      3) Creare a new control-file using these cloned datafiles
  #
  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -  
  startStep "Create the snapshot"


  setASMEnv
  libAction "Copy Wallet of the STANDBY on $(hostname -s)"
  test -d /var/opt/oracle/dbaas_acfs/$SNAPDB/wallet_root && \
     rm -rf /var/opt/oracle/dbaas_acfs/$SNAPDB/wallet_root && \
     cp -rp /var/opt/oracle/dbaas_acfs/$SOURCE_STANDBY/wallet_root /var/opt/oracle/dbaas_acfs/$SNAPDB/wallet_root && \
     echo OK || { echo ERROR ; die "Unable to copy the Wallet" ; } 
     
    #
    #     Based on the source database control-file, we generate a create controlfile script
    # without the OPEN RESETLOGS
    #
    libAction "Generate controlfile creation script"
    sed -e '1,/--     Set #2. RESETLOGS case/d' \
        -e "/ONLINELOG/ s/'+${DATA_DG}.*'/'+${DATA_DG}'/" \
        -e "/ONLINELOG/ s/'+${RECO_DG}.*'/'+${RECO_DG}'/" \
        -e "/ADD TEMPFILE/ s/'+${RECO_DG}.*'/'+${RECO_DG}'/" \
        -e "/ADD TEMPFILE/ s/'+${DATA_DG}.*'/'+${DATA_DG}'/" \
        -e "/CREATE CONTROLFILE/ s/REUSE/REUSE SET/" \
        -e "/CREATE CONTROLFILE/ s/FORCE LOGGING //" \
        -e "/^RECOVER/d" \
        -e "/^STARTUP/d" \
        -e "/^CREATE CONTROLFILE/ s/${SOURCE_STANDBY}/${SNAPDB}/g" \
        -e "/-- Configure RMAN configuration record 1/,/-- Create log files for threads other than thread one./ d" \
        -e "/-- Database can now be opened zeroing the online logs/,$ d" \
        -e "/---------/ d" \
        $INFO_DIR/$SOURCE_STANDBY/$SUFFIX/ctrlFile_STBY${SUFFIX}.sql > $INFO_DIR/$SNAPDB/ctrlFile_$SNAPDB.sql && \
      echo OK || { echo ERROR ; die "Unable to generate the controlfile creation script" ; } 

    #
    #    We also get the tmpfiles creation script in a separated file since it muse be run after cloning
    #
    libAction "Generate tempfiles creation script"
    sed -e '1,/--     Set #2. RESETLOGS case/d' \
        -e "/ONLINELOG/ s/'+${DATA_DG}.*'/'+${DATA_DG}'/" \
        -e "/ONLINELOG/ s/'+${RECO_DG}.*'/'+${RECO_DG}'/" \
        -e "/ADD TEMPFILE/ s/'+${RECO_DG}.*'/'+${RECO_DG}'/" \
        -e "/ADD TEMPFILE/ s/'+${DATA_DG}.*'/'+${DATA_DG}'/" \
        -e "/CREATE CONTROLFILE/ s/REUSE/REUSE SET/" \
        -e "/CREATE CONTROLFILE/ s/FORCE LOGGING //" \
        -e "/^RECOVER/d" \
        -e "/^STARTUP/d" \
        -e "/^CREATE CONTROLFILE/ s/${SOURCE_STANDBY}/${SNAPDB}/g" \
        -e "1,/-- Other tempfiles may require adjustment./ d" \
        -e "/-- End of tempfile additions./,$ d" \
        -e "/---------/ d" \
        $INFO_DIR/$SOURCE_STANDBY/$SUFFIX/ctrlFile_STBY${SUFFIX}.sql > $INFO_DIR/$SNAPDB/tempFile_$SNAPDB.sql && \
      echo OK || { echo ERROR ; die "Unable to generate the tempfiles creation script" ; } 
      
      
    setDbEnv $SNAPDB

    #
    #     Prepare the database to create controlfile and create it 
    #
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
    #
    #          Create the ASM Forlders before cloning the files
    #
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

  #
  #     Generate the script to rename the files
  #
    exec_sql "/ as sysdba" "
set newpage 0 linesize 999 pagesize 0 feedback off heading off echo off space 0 tab off trimspool on
SPOOL $INFO_DIR/$SNAPDB/renameFor_$SNAPDB.sql
select 'EXECUTE dbms_dnfs.clonedb_renamefile ('||''''||name||''''||','||''''||replace(replace(replace(regexp_replace(name,'_(STBY|stby).*$',''),'.','_'),'${DATA_DG}/','${SPARSE_DG}/'),'$SOURCE_DB_UNIQUE_NAME','$ORACLE_UNQNAME')||'_SN${SUFFIX}'''||');' from v\$datafile;
" "Generate rename files statements"    
  echo "    - Rename script : $INFO_DIR/$SNAPDB/renameFor_$SNAPDB.sql"

  #
  #      Rename the files and, once done, open restelogs
  #
  setAccessControl_grid
  exec_sql "/ as sysdba" "
start $INFO_DIR/$SNAPDB/renameFor_$SNAPDB.sql
" "Renaming datafiles for $ORACLE_UNQNAME" || { removeAccessControl_grid ; die "Unable to rename the files" ; }
  exec_sql "/ as sysdba" "alter database open resetlogs;" "Opening the database with RESETLOGS" || { removeAccessControl_grid ; die "Unable to open RESETLOGS" ; }
   removeAccessControl_grid

   #
   #   Optional DBID change, keeping the original DBID is acceptable for most cases.
   #
   if [ "$doDBID" = "Y" ]
   then   
      exec_sql -no_error "/ as sysdba" "shutdown immediate" "Stop database"
    
      exec_sql "/ as sysdba" "startup mount exclusive;" "Start DB in exclusive mode" || die "Unable to mount in exclusive mode"
      infoAction "Changing the DB ID using nid"
      echo Y | $ORACLE_HOME/bin/nid target=sys/dummy pdb=all
      if [ $? -ne 0 ] 
      then
        echo "Error"
        exec_sql -no_error "/ as sysdba" "
whenever sqlerror continue
prompt shutdown abort
shutdown abort
prompt startup/shutdown
startup
shutdown immediate
" "Stop Database to try Again"
        exec_sql "/ as sysdba" "startup mount exclusive;" "Start DB in exclusive mode" || die "Unable to mount in exclusive mode"
        infoAction "Changing the db name using nid (last try)"
        echo Y | $ORACLE_HOME/bin/nid target=sys/dummy pdb=all
        [ $? -ne 0 ] && { die "Error Changing DB NAME" ; }
    fi
    exec_sql "/ as sysdba" "Startup mount" "Starting mount" || { die "Unable to START" ; }
    exec_sql "/ as sysdba" "alter database open resetlogs;" "Opening the database with RESETLOGS" || { die "Unable to open RESETLOGS" ; }
  fi
   
   
  mode=$(exec_sql "/ as sysdba" "select open_mode from v\$database;")
  libAction "Database $ORACLE_UNQNAME is" ; echo $mode
  [ "$mode" != "READ WRITE" ] && die "Database is not OPENED READ WRITE"
  exec_sql "/ as sysdba" "alter system set cluster_database=true scope=spfile;" "Set cluster database to true" || die "unable to stop the database"
  exec_sql "/ as sysdba" "shutdown immediate" "Stop database" || die "unable to stop the database"
    
  exec_srvctl "start database -d $ORACLE_UNQNAME" "Start with srvctl"
  exec_srvctl "status database -d $ORACLE_UNQNAME -v"

  exec_sql -no_error "/ as sysdba " "
alter pluggable database all open ;
start $INFO_DIR/$SNAPDB/tempFile_$SNAPDB.sql" "Create online tempfiles"
  
  
  #
  #    If the database contains only one PDB, rename it according to MICHELIN rules
  #
  nb_pdb=$(exec_sql "/ as sysdba" "select to_char(count(*)) from v\$pdbs where name != 'PDB\$SEED' ;")
  if [ "$nb_pdb" = "1" ]
  then
    new_pdb=$(echo $SNAPDB | sed -e "s;C$;;")
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
alter pluggable database $new_pdb open instances=all ;
alter pluggable database $new_pdb save state;" "rename $pdb to $new_pdb"
  fi
  exec_sql "/ as sysdba" "
show pdbs" 
    
  endStep
}
snapDROP()
{
# -----------------------------------------------------------------------------------------------
#
#       Drop the snapshot (stop database and drop the files in ASM (SPFile preserved)
#
# -----------------------------------------------------------------------------------------------
  [ "$SNAPDB" = "" ] && die "SNAPSHOT DB Name required for SNAPSHOT removal"
  [ ! -f /var/opt/oracle/creg/$SNAPDB.ini ] && die "$SNAPDB is not a cloud managed DATABASE"
  
  startStep "Removing $SNAPDB"
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
  else
    [ "$FORCE_FLAG" = "N" ] && die "Database cannot be started, please check and remove manually if needed (or use force mode -f)"
  fi

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -  
  #
  #      Dop the database, only if it is a clone of the source_standby. The first time, 
  # the -f flag must be used.
  #
  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -  

  [ "$FORCE_FLAG" = "Y" ] || checkIfCloned
  
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
  endStep
  
}

_____________________________TestMasterManagement() { : ;}
#
#        The below functions are dedicated to test-master databases creation
#  these databases are mainly used for tests or validation. They should not be necessary 
#  for normal operations.
#
testMasterSTART()
{
  setDbEnv $SOURCE_STANDBY
  SOURCE_DB_UNIQUE_NAME=$ORACLE_UNQNAME

  [ "$SUFFIX" = "" ] && die "Suffix is mandatory for test Master Operations"

  export ORACLE_SID=$TEST_MASTER

  startStep "Check test master Existence"
  showEnv
  
  findTestMaster $ZONE_LIB $SUFFIX || die "No test master for ZONE $ZONE ($ZONE_LIB) with Suffix $SUFFIX" 
  
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
select 'EXECUTE dbms_dnfs.clonedb_renamefile ('||''''||name||''''||','||''''||replace(replace(replace(regexp_replace(name,'_(STBY|stby).*$',''),'.','_'),'${DATA_DG}/','${SPARSE_DG}/'),'$SOURCE_DB_UNIQUE_NAME','$TM_UNIQUE_NAME')||'_SM${SUFFIX}'''||');' from v\$datafile;
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
  listSparseStandByFast | grep "^TM" | while read tm
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
_____________________________unused() { : ; }
cloneLIST()
{
# -----------------------------------------------------------------------------------------------
#
#         This function is the connect-by version of the hierarchy display. It is not used 
# anymore in the script. It has been let here for reference only.
#
# -----------------------------------------------------------------------------------------------

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
oneTest()
{
  echo "---+-------------------------------------------------------------------------------"
  echo "   |"
  echo "   +--+--> START TEST : $1 in 10 seconds"
  sleep 10
  stdbuf -i0 -o0 -e0 $2 $3 >&1 | sed -e "s;^;   |  | ;"
  echo "   |  |"
  echo "   +--+--> TEST RESULT : $?"
  echo "   |"
  echo "   |"
}
autotest()
{
  DG_SCRIPT=$SCRIPT_DIR/setupDG_MICHELIN.sh
  [ ! -f $DG_SCRIPT ] && die "$DG_SCRIPT must be present for autotests"
  
  echo
  echo -n "Please run 

$DG_SCRIPT -d RFOPMBOC -u RFOPMBOC_1GN_PAR -U RFOPMBOC_2GN_PAR -s parx01-zf5km-amnvb1.oci.michelin.com:1521

on the source machine and press ENTER : "
  read rep
  # oneTest "Drop all databases"                           $SCRIPT_FULL "-d RFOPMBOC -a DROP_ALL -f"
  # echo Y |   oneTest "Remove Stand-by (should not be there anymore" $DG_SCRIPT   "-m RunOnStandBY -d RFOPMBOC -u RFOPMBOC_1GN_PAR -U RFOPMBOC_2GN_PAR -s parx01-zf5km-scan.oci.michelin.com:1521 -R"
  # oneTest "Recreate the stand-by"                        $DG_SCRIPT   "-m RunOnStandBY -d RFOPMBOC -u RFOPMBOC_1GN_PAR -U RFOPMBOC_2GN_PAR -s parx01-zf5km-scan.oci.michelin.com:1521 -F"
  # oneTest "Clone the dataguard (202309)"                 $SCRIPT_FULL "-d RFOPMBOC -a CLONE_DG -S 202309"
  # oneTest "Clone status"                                 $SCRIPT_FULL "-d RFOPMBOC -a CLONE_LIST"
  oneTest "Create a snapshot"                            $SCRIPT_FULL "-d RFOPMBOC -a SNAP_CREATE -T SFOPMBOC -S 202309"
  oneTest "Clone status"                                 $SCRIPT_FULL "-d RFOPMBOC -a CLONE_LIST"
  oneTest "Clone the dataguard (202310)"                 $SCRIPT_FULL "-d RFOPMBOC -a CLONE_DG -S 202310"
  oneTest "Clone status"                                 $SCRIPT_FULL "-d RFOPMBOC -a CLONE_LIST"
  oneTest "Drop a snapshot"                              $SCRIPT_FULL "-d RFOPMBOC -a SNAP_DROP -T SFOPMBOC -S 202310"
  oneTest "Clone status"                                 $SCRIPT_FULL "-d RFOPMBOC -a CLONE_LIST"
  oneTest "Create a test master DB"                      $SCRIPT_FULL "-d RFOPMBOC -a TM_START -S 202309"
  oneTest "Clone status"                                 $SCRIPT_FULL "-d RFOPMBOC -a CLONE_LIST"
  oneTest "DROP a test master DB"                        $SCRIPT_FULL "-d RFOPMBOC -a TM_DROP -S 202309"
  oneTest "Clone status"                                 $SCRIPT_FULL "-d RFOPMBOC -a CLONE_LIST"
  oneTest "Create a test master DB"                      $SCRIPT_FULL "-d RFOPMBOC -a TM_START -S 202310"
  oneTest "Clone status"                                 $SCRIPT_FULL "-d RFOPMBOC -a CLONE_LIST"
  oneTest "Stop a test master DB"                        $SCRIPT_FULL "-d RFOPMBOC -a TM_STOP -S 202310"

}
____________________________main() { : ; }
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

# -----------------------------------------------------------------------------------------------
#
#         Main program.
#
# -----------------------------------------------------------------------------------------------
set -o pipefail

#if tty -s
if false
then
  die "Please run this script in nohup mode"
fi


set -o pipefail

SCRIPT=${BASH_SOURCE[0]}
SCRIPT_FULL=$(readlink -f $SCRIPT)
SCRIPT_BASE=$(basename $SCRIPT .sh)
SCRIPT_LIB="Database sparse cloning over DATAGUARD utility"
SCRIPT_DIR=$(dirname $SCRIPT_FULL)

[ "$(id -un)" != "oracle" ] && die "run this script as \"oracle\" user"

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -  
#
#      Default values and script paramaters analysis.
#
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -  
doDBID=N                             # Set to Y to change the DBID of the cloned database
FORCE_FLAG=N
toShift=0
while getopts d:P:T:a:S:nfh opt
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
   f) FORCE_FLAG=Y                  ; toShift=$(($toShift + 1)) ;;
   n)   logOutput=NO                ; toShift=$(($toShift + 1)) ;;
   h) usage FULL ;;
   ?) usage ;;
  esac
done
shift $toShift 
[ "$SOURCE_STANDBY" = "" -a ${ACTION^^} != "AUTOTEST" ] && die "Main stand-by database is mandatory (-d)"
[ "$ACTION" = "" ] && die "Action not specified (-a)"

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -  
#
#      LOG Files
#
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -  

LOG_DIR=$HOME/scriptsLOG/$SCRIPT_BASE/$SOURCE_STANDBY                      # Log directory
LOG_FILE=$LOG_DIR/${SCRIPT_BASE}_ACTION_$(date +%Y%m%d_%H%M%S).log         # Log file, 'ACTION' will be replaced
CMD_FILE=$LOG_DIR/${SCRIPT_BASE}_ACTION_$(date +%Y%m%d_%H%M%S).cmd         # Commands log
INFO_DIR=$HOME/sparseClonesInfo                                            # Files to be used for subsequent clonings

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -  
#
#      Action specific variables
#
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -  
DG_NAMES_NEEDED=Y                                                          # If Yes, DG variables are loaded
ACTION=${ACTION^^}

#
#          Depending on the action, define the LOG File and the command tracing file
#    Some actions does not require calculation of the DG values, so, set DG_NAMES_NEEDED to N
#

case $ACTION in
  DROP_ALL)     subLib="Drop all elements to recreate DG"
                LOG_FILE=$(echo $LOG_FILE | sed -e "s;ACTION;$ACTION;")
                CMD_FILE=$(echo $CMD_FILE | sed -e "s;ACTION;$ACTION;")
                ;;
  CLONE_DG)     subLib="Clone DATAGUARD to prepare for a new master"
                LOG_FILE=$(echo $LOG_FILE | sed -e "s;ACTION;$ACTION;")
                CMD_FILE=$(echo $CMD_FILE | sed -e "s;ACTION;$ACTION;")
                ;;
  CLONE_LIST_CB)subLib="List current clones of the database (connect-by)"
                LOG_FILE=/dev/null
                CMD_FILE=$(echo $CMD_FILE | sed -e "s;ACTION;$ACTION;")
                DG_NAMES_NEEDED=N
                ;;
  CLONE_LIST)   subLib="List current clones of the database"
                LOG_FILE=/dev/null
                CMD_FILE=$(echo $CMD_FILE | sed -e "s;ACTION;$ACTION;")
                DG_NAMES_NEEDED=N
                ;;
  SHOW_ENV)     subLib="Show environment"
                LOG_FILE=/dev/null
                CMD_FILE=""
                ;;
  TRACK_CREATE) subLib="Create the tracking table"
                LOG_FILE=/dev/null
                CMD_FILE=""
                DG_NAMES_NEEDED=N
                ;;
  TRACK_UPDATE) subLib="Create the tracking table"
                LOG_FILE=/dev/null
                CMD_FILE=""
                DG_NAMES_NEEDED=N
                ;;
  TRACK_DROP)   subLib="Create the tracking table"
                LOG_FILE=/dev/null
                CMD_FILE=""
                DG_NAMES_NEEDED=N
                ;;
  TRACK_LIST)   subLib="List the tracking table"
                LOG_FILE=/dev/null
                CMD_FILE=""
                DG_NAMES_NEEDED=N
                ;;
  TM_START)     subLib="Start (and create) a test master"
                LOG_FILE=$(echo $LOG_FILE | sed -e "s;ACTION;$ACTION;")
                CMD_FILE=$(echo $CMD_FILE | sed -e "s;ACTION;$ACTION;")
                ;;
  TM_STOP)      subLib="Stop a test master"
                LOG_FILE=$(echo $LOG_FILE | sed -e "s;ACTION;$ACTION;")
                CMD_FILE=$(echo $CMD_FILE | sed -e "s;ACTION;$ACTION;")
                DG_NAMES_NEEDED=N
                ;;
  TM_DROP)      subLib="Drop a test master"
                LOG_FILE=$(echo $LOG_FILE | sed -e "s;ACTION;$ACTION;")
                CMD_FILE=$(echo $CMD_FILE | sed -e "s;ACTION;$ACTION;")
                ;;
  TM_STATUS)    subLib="Test masters status"
                LOG_FILE=$(echo $LOG_FILE | sed -e "s;ACTION;$ACTION;")
                CMD_FILE=""
                DG_NAMES_NEEDED=N
                ;;
  SNAP_CREATE)  subLib="Setup a snapshot in an existing DB"
                LOG_FILE=$(echo $LOG_FILE | sed -e "s;ACTION;$ACTION;")
                CMD_FILE=$(echo $CMD_FILE | sed -e "s;ACTION;$ACTION;")
                ;;
  SNAP_DROP)   subLib="Drop a snapshot DB"
                LOG_FILE=$(echo $LOG_FILE | sed -e "s;ACTION;$ACTION;")
                CMD_FILE=$(echo $CMD_FILE | sed -e "s;ACTION;$ACTION;")
                ;;
  AUTOTEST  )   subLib="Test"
                LOG_FILE=/dev/null
                CMD_FILE=""
                DG_NAMES_NEEDED=N
                ;;
  *)            die "Unrecognized ACTION ($ACTION)"
                ;;
esac

[ "$logOutput" = "NO" ] && { LOG_FILE=/dev/null ; CMD_FILE="" ; }

TMP1=/tmp/$$.tmp

[ "$LOG_FILE" != "" -a "$LOG_FILE" != "/dev/null" ] && mkdir -p $LOG_DIR

mkdir -p $INFO_DIR/$SOURCE_STANDBY

SCRIPT_LIB="$SCRIPT_LIB ($subLib)"

#
#    POsition required variables for the script
#
[ "$ACTION" != "AUTOTEST" ] && setScriptEnv
 
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -  
#
#      SUDO test
#
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -  

#
#       This script need to run commands as "Grid", sudo from oracle to grid must be
#   activated. is SUDO is not available, each time a command need to be run as grid, the script prompts 
#   for manual exacution (NOT TESTED)
#
GRID_SUDO=Y
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
  GRID_SUDO=N
fi

{

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -  
  #
  #      Effective execution start
  #
  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -  

  startRun "$SCRIPT_LIB"

  #
  #     Launch actions
  #
  case $ACTION in
    DROP_ALL)       dropALL          ;;
    CLONE_DG)       cloneDG          ;;
    CLONE_LIST_CB)  cloneLIST        ;;
    CLONE_LIST)     cloneLISTFast    ;;
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
    AUTOTEST)       autotest         ;;
  esac ;
  endRun
  
} | tee $LOG_FILE
finalStatus=$?

# -----------------------------------------------------------------------------------------------
#
#         Clean LOGFILES.
#
# -----------------------------------------------------------------------------------------------
LOGS_TO_KEEP=100
i=0
ls -1t $LOG_DIR/*.log 2>/dev/null | while read f
do
  i=$(($i + 1))
  [ $i -gt $LOGS_TO_KEEP ] && { echo "  - Removing $f" ; rm -f $f ; }
done
i=0
ls -1t $LOG_DIR/*.cmd 2>/dev/null | while read f
do
  i=$(($i + 1))
  [ $i -gt $LOGS_TO_KEEP ] && { echo "  - Removing $f" ; rm -f $f ; }
done

exit $finalStatus
