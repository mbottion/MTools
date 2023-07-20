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

  rm -f $PID_FILE

  exit 1
}
checkFiles()
{
  local src=$1
  local dst=$2

  srcFiles=$(ssh ${SOURCE_OWNER}@${SOURCE_SERVER} find $src -type f | wc -l)
  dstFiles=$(find $dst/$(basename $src) -type f | wc -l)

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

  echo "  - Starting synch of $src in background"
  {
    startStep "Syncing $src to $dst"

    STATUS="OK"
    if [ "$rsync_parallel" = "" ]
    then
      /usr/bin/rsync -rptgl -e ssh --progress --stats $CHECKSUM_FLAG $DRY_RUN_FLAG \
        $rsync_exclude \
        $rsync_options \
        ${SOURCE_OWNER}@${SOURCE_SERVER}:$src $dst
        [ $? -ne 0 ] && STATUS="*** ERROR ***"
    else
      ssh ${SOURCE_OWNER}@${SOURCE_SERVER} ls -d  $src/* -- | \
          sed -e "s;^;${SOURCE_OWNER}@${SOURCE_SERVER}:;" | \
          xargs -n $rsync_files | \
          xargs  -I% echo /usr/bin/rsync -rptgl -e ssh --progress --stats $CHECKSUM_FLAG $DRY_RUN_FLAG $rsync_exclude $rsync_options % $          dst/$(basename $src) | \
          xargs -n1 -P $rsync_parallel -I %  bash -c "%"
        [ $? -ne 0 ] && STATUS="*** ERROR ***"
    fi

    checkFiles $src $dst

    endStep "$STATUS"
  } >$local_log 2>&1
  while [ -f /tmp/tmp.lck ]
  do
    sleep 1
  done
  touch /tmp/tmp.lck
  cat $local_log
  rm -f /tmp/tmp.lck
  rm -f $local_log
}
usage()
{
  echo "Usage :
   $SCRIPT [-last|-dryrun] [-fast]

     -last    : to use for the last SYNCH (make exact copy and restore backed-up files)
     -dryrun  : Run everythin, but do not copy or delete files
     -fast    : run without checksum
  "
  exit 1
}


set -o pipefail

SCRIPT=$(basename $0 .sh)

DRYRUN=NO
LAST_SYNC=NO

while [ "$1" != "" ]
do
  [ "${1^^}" = "-H" -o "$1" = "-?" ] && usage
  [ "${1^^}" = "-LAST" ] && { LAST_SYNC=YES ; shift ; continue ; }
  [ "${1^^}" = "-DRYRUN" ] && { DRYRUN=YES ; shift ; continue ; }
  [ "${1^^}" = "-FAST" ] && { FAST=YES ; shift ; continue ; }
  [ "${1^^}" != "" ] && usage
done



if false
#if tty -s
then
  die "Please run this script in nohup mode"
fi

#
#     These variables need to be defined as (SOURCE:ON-PREM, TARGET:OCI). The script is launched on the target
#  Variables will be interverted if the script is used for switchback
#
SOURCE_SERVER=lnx002833.mpl.michelin.com
SOURCE_OWNER=rfopamea
TARGET_SERVER=lnx004016.oci.michelin.com
TARGET_OWNER=rfopamea

SWITCHBACK=NO
if [ "$(hostname -s)" != "$(echo $TARGET_SERVER | cut -f1 -d".")" ]
then
  #
  #   If we run on on-prem server, exchange the variables
  #
  SWITCHBACK=YES

  tmp=$SOURCE_SERVER
  SOURCE_SERVER=$TARGET_SERVER
  TARGET_SERVER=$tmp

  tmp=$SOURCE_OWNER
  SOURCE_OWNER=$TARGET_OWNER
  TARGET_OWNER=$tmp
fi

[ "$(id -un)" != "$TARGET_OWNER" ] && die "Script must be run by the \"$TARGET_OWNER\" user"

LOG_DIR=$HOME/synchro/logs
mkdir -p $LOG_DIR

LOG_FILE=$LOG_DIR/${SCRIPT}_$(date +%Y%m%d_%H%M%S).log
PID_FILE=$LOG_DIR/${SCRIPT}.pid

{
  startRun "Sych OP filesystems"

  #
  #    Block multiple concurrent executions
  #
  echo -n "  - Testing if already running       : "
  if [ -f $PID_FILE ]
  then
    if ps -p $(cat $PID_FILE) >/dev/null
    then
      echo "$SCRIPT is already running, aborting"
      die "SCript is currently running"
    else
      rm -f $PID_FILE
    fi
  fi
  p=$$
  echo "Not running (New instance : $p)"
  echo $p > $PID_FILE
  rm -f /tmp/tmp.lck

  echo    "  - Source server                    : $SOURCE_SERVER"
  echo    "  - Source user                      : $SOURCE_OWNER"
  echo -n "  - Test connectivity to ON-PREM     : "
  if ssh ${SOURCE_OWNER}@${SOURCE_SERVER} true
  then
    echo "OK"
  else
    echo "ERROR"
    die "Unable to connect to $SOURCE_SERVER"
  fi
  echo    "  - Fast Synch                       : $FAST"

  if [ "$FAST" = "YES" ]
  then
    CHECKSUM_FLAG=""
  else
    CHECKSUM_FLAG="--checksum"
  fi
  BACKUP_FILE="/tmp/SonmeNonExistentFile.tgz"
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

  #
  #   Define variables as src_base: ON-PREMISES, dst_base: OCI, variables will be exchanged
  #   when the script is used for switchback
  #
  src_base=/busdata/rfop/ame1/applcsf
  dst_base=/busdata/rfop/ame1/applcsf
  folder=data
  if [ "$SWITCHBACK" = "YES" ]
  then
    tmp=$src_base
    src_base=$dst_base
    dst_base=$tmp
  fi
  outFile=$LOG_DIR/applcsf_data.out
  rm -f $outFile

  #
  #     We use --delete to have EXACT Copy
  #
  synchOne $src_base/$folder $dst_base "--log-file=$outFile --progress $DELETE_BY_DEFAULT" "--exclude '*.log' --exclude '*.trc'"  &

  # -------------------------------------------------------------------------------

  #
  #   Define variables as src_base: ON-PREMISES, dst_base: OCI, variables will be exchanged
  #   when the script is used for switchback
  #
  src_base=/busdata/rfop/ame1/applcsf
  dst_base=/busdata/rfop/ame1/applcsf
  folder=inbound
  if [ "$SWITCHBACK" = "YES" ]
  then
    tmp=$src_base
    src_base=$dst_base
    dst_base=$tmp
  fi
  outFile=$LOG_DIR/applcsf_inbound.out
  rm -f $outFile

  #
  #     We use --delete to have EXACT Copy
  #
  synchOne $src_base/$folder $dst_base "--log-file=$outFile --progress $DELETE_BY_DEFAULT" "--exclude '*.log' --exclude '*.trc'"  &

  # -------------------------------------------------------------------------------

  #
  #   Define variables as src_base: ON-PREMISES, dst_base: OCI, variables will be exchanged
  #   when the script is used for switchback
  #
  src_base=/busdata/rfop/ame1/applcsf
  dst_base=/busdata/rfop/ame1/applcsf
  folder=outbound
  if [ "$SWITCHBACK" = "YES" ]
  then
    tmp=$src_base
    src_base=$dst_base
    dst_base=$tmp
  fi
  outFile=$LOG_DIR/applcsf_outbound.out
  rm -f $outFile

  #
  #     We use --delete to have EXACT Copy
  #
  synchOne $src_base/$folder $dst_base "--log-file=$outFile --progress $DELETE_BY_DEFAULT" "--exclude '*.log' --exclude '*.trc'"  &

  # -------------------------------------------------------------------------------

  #
  #   Define variables as src_base: ON-PREMISES, dst_base: OCI, variables will be exchanged
  #   when the script is used for switchback
  #
  src_base=/busdata/rfop/ame1/applcsf
  dst_base=/busdata/rfop/ame1/applcsf
  folder=log
  if [ "$SWITCHBACK" = "YES" ]
  then
    tmp=$src_base
    src_base=$dst_base
    dst_base=$tmp
  fi
  outFile=$LOG_DIR/applcsf_log.out
  rm -f $outFile

  #
  #     We use --delete to have EXACT Copy
  #
  synchOne $src_base/$folder $dst_base "--log-file=$outFile --progress $DELETE_BY_DEFAULT" "--exclude '*.log' --exclude '*.trc'"  &

  # -------------------------------------------------------------------------------

  #
  #   Define variables as src_base: ON-PREMISES, dst_base: OCI, variables will be exchanged
  #   when the script is used for switchback
  #
  src_base=/busdata/rfop/ame1/applcsf
  dst_base=/busdata/rfop/ame1/applcsf
  folder=out
  if [ "$SWITCHBACK" = "YES" ]
  then
    tmp=$src_base
    src_base=$dst_base
    dst_base=$tmp
  fi
  outFile=$LOG_DIR/applcsf_out.out
  rm -f $outFile

  #
  #     We use --delete to have EXACT Copy
  #
  synchOne $src_base/$folder $dst_base "--log-file=$outFile --progress $DELETE_BY_DEFAULT" "--exclude '*.log' --exclude '*.trc'"  &

  # -------------------------------------------------------------------------------

  #
  #   Define variables as src_base: ON-PREMISES, dst_base: OCI, variables will be exchanged
  #   when the script is used for switchback
  #
  src_base=/busapps/rfop/ame1/fs1/EBSapps
  dst_base=/busapps/rfop/ame1/fs1/EBSapps
  folder=appl
  if [ "$SWITCHBACK" = "YES" ]
  then
    tmp=$src_base
    src_base=$dst_base
    dst_base=$tmp
  fi
  outFile=$LOG_DIR/appltop_fs1.out
  rm -f $outFile

  #
  #     We do not use --delete here by default, during periodic syncs since it removes .env files prepared for the
  #  new environment
  #
  #     The result is that some deleted files on the source during the rsync at still on
  #  the target. If you want exact copy, use -last as first argument of the script
  #
  #     In the LAST SYNCH, use -last to add the --delete flag, the script will backup the files containing the
  #  hostname and will restore them after run (without overwriting if they exist)
  #
  synchOne $src_base/$folder $dst_base "--log-file=$outFile --progress -a --no-links $DELETE_FLAG" "--exclude '*.log' --exclude '*.trc'           --exclude '*.env'"  &

  # -------------------------------------------------------------------------------

  #
  #   Define variables as src_base: ON-PREMISES, dst_base: OCI, variables will be exchanged
  #   when the script is used for switchback
  #
  src_base=/busapps/rfop/ame1/fs2/EBSapps
  dst_base=/busapps/rfop/ame1/fs2/EBSapps
  folder=appl
  if [ "$SWITCHBACK" = "YES" ]
  then
    tmp=$src_base
    src_base=$dst_base
    dst_base=$tmp
  fi
  outFile=$LOG_DIR/appltop_fs2.out
  rm -f $outFile

  #
  #     Same as the previous one
  #
  synchOne $src_base/$folder $dst_base "--log-file=$outFile --progress -a --no-links $DELETE_FLAG" "--exclude '*.log' --exclude '*.trc'           --exclude '*.env'"  &

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

  endRun
} 2>&1 | tee $LOG_FILE


#
#    Clean LOGS
#


LOGS_TO_KEEP=20
echo
echo "======================================================"
echo "  - Cleaning LOGS (last $LOGS_TO_KEEP preserved)"
echo "======================================================"
echo
i=0
ls -1t $LOG_DIR/*.log | while read f
do
  i=$(($i + 1))
  [ $i -gt $LOGS_TO_KEEP ] && { echo "  - Deleting $f " ; rm -f $f ; }
done

rm -f $PID_FILE

