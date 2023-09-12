VERSION="1.3.1"
# ===============================================================================================
# Version history
# ===============================================================================================
#    1.2       30/07/2023  - Initial version customized for MICHELIN
#
#    1.3       30/08/2023  - Hosts managed on the basis of -par and -fra DBS aliases
#
#    1.3.1     04/09/2023  - Minor changes & abilyty to select all folder od amount point
#                          - RSYNC_LIMIT variable to limit the number of concurrent rsyncs
#                          - Possibility to ignore folders
#
# ===============================================================================================
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
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#     Trace
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
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
  echo "       - Step (end)    : $STEP - ${1:-No Status}"
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

  exit 1
}
checkFiles()
{
  local src=$1
  local dst=$2
  srcFiles=$(ssh ${PRIMARY_OWNER}@${PRIMARY_SERVER} find $src -type f 2>/dev/null | wc -l)
  dstFiles=$(find $dst/$(basename $src) -type f 2>/dev/null| wc -l)
  echo
  echo "                      ======================================================================="
  echo "                      SUMMARY:"
  echo "                      $src"
  echo "                      ======================================================================="
  echo
  echo "                          Source Files     : $srcFiles"
  echo "                          Target Files     : $dstFiles"
  echo "                          Target - Source  : $(($dstFiles - $srcFiles))"
  echo
  echo "                      ======================================================================="
  echo

}

synchOne()
{
  local src=$1
  local dst=$2
  local rsync_options=$3
  local rsync_exclude=$4
  local rsync_parallel=$5
  local rsync_files=${6:-5}

  local local_log=$(mktemp)
  rm -f $local_log
  local_log=${local_log}.$(basename $src).sync

  lib1="Starting synch of"
  lib2="Syncing"
  [ "$COUNT_ONLY" = "YES" ] && { lib1="Starting count of" ; lib2="Counting" ; }
  echo "  - $lib1 $src / $dst in background (temporary log : $local_log)"
  echo
  {
    startStep "$lib2 $src to $dst"

    if [ "$COUNT_ONLY" != "YES" ]
    then
      STATUS="OK"
      if [ "$rsync_parallel" = "" ]
      then
        #
        #        Here, we put the command in a file an run the file, otherwise, the exclude does not work well
        #
        local tmpFile=$(mktemp)
        echo /usr/bin/rsync -rptgl -e ssh --progress --stats $CHECKSUM_FLAG $DRY_RUN_FLAG \
          $rsync_exclude \
          $rsync_options \
          --port $PRIMARY_PORT ${PRIMARY_OWNER}@${PRIMARY_SERVER}:$src $dst > $tmpFile
        chmod 755 $tmpFile
        $tmpFile
        status=$?
        rm -f $tmpFile
          [ $status -ne 0 ] && STATUS="*** ERROR ***"
      else
        ssh ${PRIMARY_OWNER}@${PRIMARY_SERVER} ls -d  $src/* -- | \
            sed -e "s;^;${PRIMARY_OWNER}@${PRIMARY_SERVER}:;" | \
            xargs -n $rsync_files | \
            xargs  -I% echo /usr/bin/rsync -rptgl -e ssh --progress --port $PRIMARY_PORT --stats $CHECKSUM_FLAG $DRY_RUN_FLAG $rsync_exclude $rsync_options % $          dst/$(basename $src) | \
            xargs -n1 -P $rsync_parallel -I %  bash -c "%"
          [ $? -ne 0 ] && STATUS="*** ERROR ***"
      fi
    fi

    [ "$FAST" != "YES" ] && checkFiles $src $dst

    endStep "$STATUS"
  } >$local_log 2>&1
  while [ -f /tmp/tmp$$.lck ]
  do
    sleep 1
  done
  touch /tmp/tmp$$.lck
  cat $local_log
  echo "$src;$STATUS" >> $resultsSummary
  rm -f /tmp/tmp$$.lck
  rm -f $local_log
}
usage()
{
  echo "
${SCRIPT}.sh

VERSION=$VERSION

Usage :
   $SCRIPT -n subset [-dirs|-count|-log_analysis] [-last|-dryrun|-fast]

     -n subset     : MANDATORY as first flag, subset indicates the .var file containing the list of directories to synch

     -dirs         : Create directories and set acces rights, no synch (if -dryrun is set, just list source dirs and modes)
     -last         : to use for the last SYNCH (make exact copy and restore backed-up files)
     -dryrun       : Run everythin, but do not copy or delete files
     -count        : Only count files (no synch performed)
     -log_analysis : Quick log analysis
     -fast         : run without checksum --> DEFAULT
     -full         : run with checksum (slower)
  "
  exit 1
}

createDirs()
{
  src_base=$APPL_CSF_LOC_REMOTE
  dst_base=$APPL_CSF_LOC_LOCAL

  ssh $PRIMARY_OWNER@$PRIMARY_SERVER -p $PRIMARY_PORT -- find $src_base -type d -exec stat -c \'%n %U %G %a %A\' {} \\\; | \
                   grep -v "^$src_base " | sed -e "s;^$src_base/;;" | grep -v "lost+found" | while read f u g m M
  do
    printf "%-50s %10s %10s %10s (%s) " $f $u $g $m $M
    if [ "$u" = "$PRIMARY_OWNER" ]
    then
      #case $f in
      #data*|log*|out*|inbound*|outbound*|applptmp*|FEX*)
        d2=$dst_base/$f
        if [ "$DRYRUN" != "YES" ]
        then
          [ ! -d $d2 ] && { echo -n "Creating " ; mkdir $d2 ; } || echo -n "Exists  "
          echo -n " - - - - - - - - - - - - - -> "
          echo -n "Set Mode $m " 
          chown $(id -u):$(id -g) $d2
          chmod $m $d2
          mode=$(stat -c %A $d2)
          echo -n "($mode) "
          echo -n "Set ACL " 
          setfacl -m u:oracle:rwx $d2
        else
          echo -n " Dry run mode, no changes"
        fi
      # ;;
      #*) echo -n "NOT processed (not used from DB)"
      #   ;;
      #esac
    else
      echo -n "NOT Processed (owner=$u)"
    fi
    echo
  done
 
  if [ "$DRYRUN" != "YES" ]
  then
    echo "Specific to AME"
    echo "   - chmod 777 $APPL_CSF_LOC_LOCAL/FEX/Retorno* (mode 777)"
    [ -d $APPL_CSF_LOC_LOCAL/FEX ] && chmod 777 $APPL_CSF_LOC_LOCAL/FEX
    [ -d $APPL_CSF_LOC_LOCAL/FEX/Retorno ] && chmod 777 $APPL_CSF_LOC_LOCAL/FEX/Retorno*
  fi
}
analyzeLogs()
{
  NB_LOGS=10
  i=0
  echo "
========================================================================================
  $SCRIPT
     Analyze the last $NB_LOGS synch logs for $SUBSET
========================================================================================
        "
  
  rm -f /tmp/$$.tmp
  ls -1t $LOG_DIR/${SCRIPT}*.log | while read f
  do
    if ! grep "Step (start)  : Syncing" $f >/dev/null 2>&1
    then
     echo "$f" >> /tmp/$$.tmp
    else
     echo "$f" >> /tmp/$$.tmp
     i=$(($i + 1))
    fi
    [ $i -ge $NB_LOGS ] && break
  done

  tac /tmp/$$.tmp | while read f
  do
    echo "  --+--> $(basename $f)"
    if ! grep "Step (start)  : Syncing" $f >/dev/null 2>&1
    then
      echo "    |"
      echo "    +-------> Not a synch log"
      echo
    else
      st=$(grep "^  - Started at     :" $f | cut -f2-10 -d:)
      en=$(grep "^  - Ended at      : " $f | cut -f2-10 -d:)
      du=$(grep "^  - Duration      :"  $f | cut -f2-10 -d:)
      echo "    |"
      echo "    +--+---->  Started at $st"
      echo "       |"
      grep -B30 -A3 "^       - Step (end)    : Syncing" $f | \
        grep -v  "^$" | \
        egrep -v  "starting synch|(start)|Started|- - - - |Authorized|receiving incremental" | \
        egrep -v "^ *-.*=|Starting" | \
        grep -v "xfr#" | \
        grep -v "^[^ /]*/" | \
        grep -v "Total file size:" | \
        grep -v "Total transferred file size:" | \
        grep -v "Literal data:" | \
        grep -v "Matched data:" | \
        grep -v "File list size:" | \
        grep -v "File list generation time:" | \
        grep -v "File list transfer time:" | \
        grep -v "Total bytes sent:" | \
        grep -v "Total bytes received:" | \
        #grep -v "total size is" | \
        grep -v "skipping" | \
        grep -v "^sent" | \
        awk '/Duration/ { print ; print "" ; next } { print }' | \
        sed -e "s;^;       | ;" 
        if [ "$(grep "##status##" $f)" != "" ]
        then
          echo "       +--+----> Overall status ---------------------------------------------------------------------------------+" 
          echo "       |  |                                                                                                      |"
          grep "##status##" $f | cut -c 24-200 | sed -e "s;^;       |  | ;" -e "s;$;          |;"
          echo "       |  |                                                                                                      |"
          echo "       |  o------------------------------------------------------------------------------------------------------+"
          echo "       |"
        fi
      echo "       o---------> Ended at : $en / Duration : $du minutes"
      echo ""
      i=$(($i +1))
    fi
  done
  rm -f /tmp/$$.tmp


}
# ####################################################################################################################
#
#     To be used as a replacement of hostname, this fonction check if we are on PRIMARY or DR since the machines 
#  have the same names.
#
#     For other platforms, the real hostname is returned
#
# ####################################################################################################################
getHostname()
{
  local h=$(hostname -s)
  local d=$(hostname -d)
  local ip=$(hostname -I | awk '{print $1}')

  hst=${h}-par.$d
  tmp=$(host $hst | awk '{print $4}')
  if [ "$tmp" != "$ip" ]
  then
    hst=${h}-fra.$d
    tmp=$(host $hst | awk '{print $4}')
    if [ "$tmp" != "$ip" ]
    then
      hst=${h}.$d
      tmp=$(host $hst | awk '{print $4}')
      if [ "$tmp" != "$ip" ]
      then
        hst=""
      fi
    fi
  fi
  echo "$hst"
}

# ####################################################################################################################
# ####################################################################################################################

main() { : ; }

set -o pipefail

SCRIPT=$(basename $0 .sh)


DRYRUN=NO
LAST_SYNC=NO
COUNT_ONLY=NO
CREATE_DIRS=NO
FAST=YES
LOG_ANALYSIS=NO

if [ "${1^^}" = "-H" -o "${1^^}" = "-?" ]
then
  usage
fi

if [ "${1^^}" != "-N" -a "${1^^}" != "-H" -a "${1^^}" != "-?" ]
then
  die "No subset defined, use {-n subset} as first options"
else
  SUBSET=${2,,}
  shift 2
fi

#
#    SCRIPT variable is used for LOGS and for LOCKS, we add the subset in the nae to allow multiple instances at
# the same time
#
SCRIPT=$(basename $0 .sh)_${SUBSET}

#
#   Get the DNS alias to be used, the alias determines the .var file to be used.
#
HOSTNAME=$(getHostname)
[ "$HOSTNAME" = "" ] && die "Unable to find a suitable alias for the current HOST"
HOSTNAME_SHORT=$(echo $HOSTNAME | cut -f1 -d ".")

#
#   Creates the TMPDIR, to be able to use mktemp
#
if [ ! -d $TMPDIR ]
then
  mkdir -p $TMPDIR || die "Unable to create $TMPDIR"
fi

##################################################################################################
#
#  Search for the file containing the variables defining the syncs to be made
#
#  file is named [hostname].var and must be located in the same folder than the script
#
s=$(readlink -f $0)
s_dir=$(dirname $s)
global_vars_script=$s_dir/${HOSTNAME_SHORT}.global.var

[ ! -f $global_vars_script ] && die "Global variables script ($global_vars_script) not found"
. $global_vars_script || die "Unable to run $global_vars_script"

subset_vars_script=$s_dir/${HOSTNAME_SHORT}.$SUBSET.var
[ ! -f $subset_vars_script ] && die "Subset variables script ($subset_vars_script) not found"
. $subset_vars_script || die "Unable to run $subset_vars_script"

##################################################################################################

while [ "$1" != "" ]
do
  [ "${1^^}" = "-H" -o "$1" = "-?" ] && usage
  [ "${1^^}" = "-DIRS" ] && { CREATE_DIRS=YES ; TEST_MODE=YES ; shift ; continue ; }
  [ "${1^^}" = "-LAST" ] && { LAST_SYNC=YES ; shift ; continue ; }
  [ "${1^^}" = "-DRYRUN" ] && { DRYRUN=YES ; TEST_MODE=YES ; shift ; continue ; }
  [ "${1^^}" = "-FAST" ] && { FAST=YES ; shift ; continue ; }
  [ "${1^^}" = "-FULL" ] && { FAST=NO ; shift ; continue ; }
  [ "${1^^}" = "-LOG_ANALYSIS" ] && { LOG_ANALYSIS=YES ; TEST_MODE=YES ; shift ; continue ; }
  [ "${1^^}" = "-COUNT" ] && { COUNT_ONLY=YES ; FAST="NO" ; TEST_MODE=YES; shift ; continue ; }
  [ "${1^^}" != "" ] && usage
done


#
#     Check if we are running in a non-interruptible session
#
if [ "$CREATE_DIRS" = "NO" -a "$COUNT_ONLY" = "NO" ]
then
  if  tty -s  
  then
    if [ "$TERM" != "screen" -a "$TEST_MODE" = "" ]
    then
      die "Please run this script in nohup mode or in screen (or set TEST_MODE)"
    fi
  fi
fi


[ "$COUNT_ONLY" = "YES" ] && PROCESSES_TO_CHECK=""
[ "$DRYRUN" = "YES" ] && PROCESSES_TO_CHECK=""
[ "$LOG_ANALYSIS" = "YES" ] && PROCESSES_TO_CHECK=""
[ "$COUNT_ONLY" = "YES" ] && LAST_RUN=NO

#
#    Check if we are running on the primary, in this case, hostnames are exachanged and the same script runs in DR and PRIMARY
#
REVERSE_DIRECTION=NO
if [ "${HOSTNAME_SHORT}" != "$(echo $DR_SERVER | cut -f1 -d".")" ]
then
  if [ "${HOSTNAME_SHORT}" = "$(echo $PRIMARY_SERVER | cut -f1 -d".")" ]
  then
    #
    #   If we run on on-prem server, exchange the variables
    #
    
    REVERSE_DIRECTION=YES

    tmp=$PRIMARY_SERVER
    PRIMARY_SERVER=$DR_SERVER
    DR_SERVER=$tmp

    tmp=$PRIMARY_OWNER
    PRIMARY_OWNER=$DR_OWNER
    DR_OWNER=$tmp
  else
    die "Not running on primary or standby server, check configuration file (${HOSTNAME_SHORT}.global.var)"
  fi
fi

[ "$(id -un)" != "$DR_OWNER" ] && die "Script must be run by the \"$DR_OWNER\" user"

#
#     If the application is running, the synch should not occur
#
for p in $PROCESSES_TO_CHECK
do
  [ "$(ps -ef | grep $p | grep -v grep | wc -l)" != "0" ] && die "Process ($p) is running, check if the application is stopped on ${HOSTNAME}"
done

#
#    LOG File
#
LOG_DIR=$s_dir/logs
mkdir -p $LOG_DIR
LOG_FILE=$LOG_DIR/${SCRIPT}_$(date +%Y%m%d_%H%M%S).log
[ "$COUNT_ONLY" = "YES" ] && LOG_FILE=/dev/null

#
#   Lock file to avoid multiple runs on the same subset
#
PID_FILE=$LOG_DIR/${SCRIPT}.pid

# ##################################################################################################
#
#   Analyze thelogs for a simple status
#
# ##################################################################################################
if [ "${LOG_ANALYSIS}" = "YES" ]
then
  analyzeLogs
  exit 0
fi

{
  if [ "$CREATE_DIRS" = "YES" ]
  then
    # ##################################################################################################
    #
    #     Copy directory structure ans add ACLS
    #
    # ##################################################################################################
    [ "$APPL_CSF_LOC_REMOTE" = "" ] && die "\$APPL_CSF_LOC_REMOTE not defined, use the correct declinaison of the script"
    [ "$APPL_CSF_LOC_LOCAL" = "" ] && die "\$APPL_CSF_LOC_LOCAL not defined, use the correct declinaison of the script"
    startRun "Setup APPLCSF folders"    
    createDirs $APPL_CSF_LOC
  else
    # ##################################################################################################
    #
    #     Synch or count
    #
    # ##################################################################################################
    startRun "Sych DR filesystems (COUNT_ONLY=$COUNT_ONLY)"

    #
    #    Block multiple concurrent executions
    #
    if [ "$COUNT_ONLY" != "YES" ]
    then
      echo -n "  - Testing if already running       : "
      if [ -f $PID_FILE ]
      then
        if ps -p $(cat $PID_FILE) >/dev/null
        then
          echo "$SCRIPT is already running, aborting"
          die "SCript is currently running"
        else
          echo "$PID_FILE was for an old run, removing"
          rm -f $PID_FILE
        fi
      fi
      p=$$
      echo "Not running (New instance : $p)"
      echo $p > $PID_FILE
      rm -f /tmp/tmp.lck
    fi

    [ "$RSYNC_LIMIT" = "" ] && RSYNC_LIMIT=20 

    echo    "  - Source server                    : $PRIMARY_SERVER"
    echo    "  - Source user                      : $PRIMARY_OWNER"
    echo    "  - Target server                    : $DR_SERVER"
    echo    "  - Target user                      : $DR_OWNER"
    echo -n "  - Test connectivity to SOURCE      : "
    if ssh -o strictHostKeyChecking=no ${PRIMARY_OWNER}@${PRIMARY_SERVER} true >/dev/null 2>&1
    then
      echo "OK"
    else
      echo "ERROR"
      die "Unable to connect to $PRIMARY_SERVER"
    fi
    echo    "  - Fast Synch                       : $FAST"

    if [ "$FAST" = "YES" ]
    then
      CHECKSUM_FLAG=""
    else
      CHECKSUM_FLAG="--checksum"
    fi
    BACKUP_FILE="/tmp/someNonExistentFile.tgz"
    [ "$BASE_DIR" = "" ] && LAST_SYNC=NO
    if [ "$LAST_SYNC" = "YES" ]
    then
      #
      #      Specific for LAST Synch, backup some files that
      #   may be erased by the --delete flag of RSYNC, we will
      #   restore them at the end
      #
      echo "  - Last synch, backup files containing $(hostname -s) in their name"
      BACKUP_FILE=$LOG_DIR/localFiles_$(date +%Y%m%d_%H%M%S).tgz
      cd $BASE_DIR || die "Unable to move to base dir"
      find . -name "*$(hostname -s)*" | xargs tar czf $BACKUP_FILE
      [ $? -ne 0 ] && die "unable to backup local files"
      echo "  - Local Files backed up in $BACKUP_FILE"
      DELETE_FLAG="--delete"
      CHECKSUM_FLAG=""
    fi
    echo    "  - Last Synch                       : $LAST_SYNC"
    echo    "  - Delete FLAG                      : $DELETE_FLAG"
    echo    "  - Checksum FLAG                    : $CHECKSUM_FLAG"

    DELETE_BY_DEFAULT="--delete"
    DRY_RUN_FLAG=""
    if [ "$DRYRUN" = "YES" ]
    then
      DELETE_BY_DEFAULT=""
      DRY_RUN_FLAG="--dry-run"
    fi

    echo    "  - Delete by default                : $DELETE_BY_DEFAULT"
    echo    "  - Dry run                          : $DRYRUN"
    echo
    echo

    
    # -------------------------------------------------------------------------------

    tmpfolders=$(mktemp)
    listFolders > $tmpfolders
    
    #
    #  Ckeck existence of the parent dir before doing anything
    #
    echo "  -Testing target parent forders existence"
    old_parent=/xxxzzz
    while read l
    do
      
      ftmp="$(echo ${l}: | cut -f1 -d: | sed -e "s;^ *;;" -e "s; *$;;")"
      if [ "$(echo $ftmp | grep "|")" != "" ]
      then
        ftmp_source=$(echo $ftmp | cut -f1 -d"|"| sed -e "s;^ *;;" -e "s; *$;;")
          ftmp_dest=$(echo $ftmp | cut -f2 -d"|"| sed -e "s;^ *;;" -e "s; *$;;")
      else
        ftmp_source=$ftmp
        ftmp_dest=$ftmp
      fi
      parent=$(dirname $ftmp_dest)
      if [ "$parent" != "$old_parent" ]
      then
        printf "%-75.75s :" "    - $parent"
    
        [ ! -d "$(dirname $parent)" ] && { echo "Non existent" ; die "$(dirname $parent) does not exists, please create it manually" ; }
        echo " Exists"
        old_parent=$parent
      fi

    done < $tmpfolders
    
    # -------------------------------------------------------------------------------

    echo "  -Launching jobs"
    resultsSummary=$(mktemp)
    while read l
    do
      while [ $(jobs | wc -l) -gt $RSYNC_LIMIT ]
      do
        echo "               - Too many jobs ... Waiting 5 secs"
        sleep 5
      done      
      ftmp="$(echo ${l}: | cut -f1 -d: | sed -e "s;^ *;;" -e "s; *$;;")"
      if [ "$(echo $ftmp | grep "|")" != "" ]
      then
        ftmp_source=$(echo $ftmp | cut -f1 -d"|"| sed -e "s;^ *;;" -e "s; *$;;")
          ftmp_dest=$(echo $ftmp | cut -f2 -d"|"| sed -e "s;^ *;;" -e "s; *$;;")
      else
        ftmp_source=$ftmp
        ftmp_dest=$ftmp
      fi
       del="$(echo ${l}: | cut -f2 -d: | sed -e "s;^ *;;" -e "s; *$;;")"
      excl="$(echo ${l}: | cut -f3 -d: | sed -e "s;^ *;;" -e "s; *$;;")"
     
      echo "  - $ftmp_source --> $ftmp_dest"

      if [ "${del^^}" = "N" ]
      then
        del_for_folder=$DELETE_FLAG
      else
        del_for_folder=$DELETE_BY_DEFAULT
      fi
      echo "    - del_for_folder=$del_for_folder"
      #
      #   define variables to pass to the background process
      #
      src_base=$(dirname $ftmp_source)
      dst_base=$(dirname $ftmp_dest)
      dst_base=$dst_base
      folder=$(basename $ftmp_dest)
      if [ "$REVERSE_DIRECTION" = "YES" ]
      then
        tmp=$src_base
        src_base=$dst_base
        dst_base=$tmp
      fi
      #
      #  Build exclude
      #
      eFlag=""

      set -o noglob # Disable wildcard expansion
      for e in $excl
      do
        eFlag="$eFlag --exclude '$e'"
      done
      set +o noglob # enable wildcard expansion

      echo "    - eFlag         = $eFlag"
      synchOne $src_base/$folder $dst_base "--log-file=/dev/null --progress -a --no-links $del_for_folder" "$eFlag"  &
      sleep 1 # to avoid connect errors
    done < $tmpfolders
    rm -f $tmpfolders

    # -------------------------------------------------------------------------------

    sleep 5
    echo
    echo "Waiting for backgroud tasks to finish"
    echo

    wait

    if [ "$LAST_SYNC" = "YES" -a -f $BACKUP_FILE ]
    then
      #
      #    If last Synch, restore files that have been backed-up at the begining
      #
      startStep "Last SYNC : Restore local files"
      echo "  - Restoring local files (if not existant)"
      echo "  - Backup file : $BACKUP_FILE"
      cd $BASE_DIR || die "Unable to move to base dir"
      tar xvzf $BACKUP_FILE --skip-old-files || die "Error restoring local files"
      endStep
    fi
  fi

  if [  "$COUNT_ONLY" = "NO" -a -f $resultsSummary ]
  then
    overallResult=OK
    echo "======= Folder Synch Summary (start) ========================================================"
    while read line
    do
      dir=$(echo "$line" | cut -f1 -d";")
      result=$(echo "$line" | cut -f2 -d";")
      [ "$result" != "OK" ] && overallResult="*** ERROR ***"
      printf "  %-20.20s %-70.70s %-20.20s\n" "##status##Folder##" "$dir" "$result"
    done < $resultsSummary
    printf "  %-20.20s %-70.70s %-20.20s\n" "##status##Global##" "All Folders" "$overallResult"
    rm -f $resultsSummary
    echo "======= Folder Synch Summary (end) =========================================================="
  fi
  endRun

  if [ -f $PID_FILE ]
  then
    [ "$(cat $PID_FILE)" = "$$" ] && rm -f $PID_FILE
  fi

} 2>&1 | tee $LOG_FILE
exitStatus=$?

if [ "$COUNT_ONLY" = "NO" -a "$CREATE_DIRS" = "NO" ]
then

  #
  #    Clean LOGS
  #


  LOGS_TO_KEEP=${LOGS_TO_KEEP:-20}
  echo
  echo "======================================================"
  echo "  - Cleaning LOGS (last $LOGS_TO_KEEP preserved)"
  echo "======================================================"
  echo
  i=0
  ls -1t $LOG_DIR/${SCRIPT}_*.log | while read f
  do
    i=$(($i + 1))
    [ $i -gt $LOGS_TO_KEEP ] && { echo "  - Deleting $f " ; rm -f $f ; }
  done
fi

exit $exitStatus

