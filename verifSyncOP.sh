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
checkFiles()
{
  local src=$1
  local dst=$2

  srcFiles=$(ssh ${SOURCE_OWNER}@${SOURCE_SERVER} find $src -type f | wc -l)
  dstFiles=$(find $dst/$(basename $src) -type f | wc -l)

  echo
  echo "                      ======================================================================="
  echo "                      SUMMARY:"
  echo "                      ======================================================================="
  echo
  echo "                          Source Files     : $srcFiles (${SOURCE_OWNER}@${SOURCE_SERVER}:$src)"
  echo "                          Target Files     : $dstFiles ($dst/$(basename $src))"
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

  local local_log=$(mktemp)

  echo "  - Starting synch of $src in background"
  {
    startStep "Syncing $src to $dst"

    /usr/bin/rsync -rptgl -e ssh --progress --stats --checksum \
      $rsync_exclude \
      $rsync_options \
      ${SOURCE_OWNER}@${SOURCE_SERVER}:$src $dst

    checkFiles $src $dst

    endStep
  } 2>&1 >$local_log
  while [ -f /tmp/tmp.lck ]
  do
    sleep 1
  done
  touch /tmp/tmp.lck
  cat $local_log
  rm -f /tmp/tmp.lck
  rm -f $local_log
}


#if tty -s
if false
then
  die "Please run this script in nohup mode"
fi

set -o pipefail

SCRIPT=$(basename $0 .sh)
SCRIPT_LIB="Move segments to reduce space usage"

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

LOG_FILE=/dev/null
PID_FILE=$LOG_DIR/${SCRIPT}.pid

[ "$COUNT_ONLY" = "YES" ] && LOG_FILE=/dev/null

{
  startRun "Sych OP filesystems"

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
  echo    "  - SOurce user                      : $SOURCE_OWNER"
  echo -n "  - Test connectivity to ON-PREM     : "
  if ssh ${SOURCE_OWNER}@${SOURCE_SERVER} true
  then
    echo "OK"
  else
    echo "ERROR"
    die "Unable to connect to $SOURCE_SERVER"
  fi

  echo
  echo

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

  checkFiles $src_base/$folder $dst_base

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

  checkFiles $src_base/$folder $dst_base

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

  checkFiles $src_base/$folder $dst_base

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

  checkFiles $src_base/$folder $dst_base

  # -------------------------------------------------------------------------------

  sleep 5
  echo
  echo "Waiting for backgroud tasks to finish"
  echo
  wait

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

