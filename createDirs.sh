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


#if tty -s
if false
then
  die "Please run this script in nohup mode"
fi

set -o pipefail

SCRIPT=$(basename $0 .sh)
SCRIPT_LIB="Copy folders and access rights"

#
#     These variables need to be defined as (SOURCE:ON-PREM, TARGET:OCI). The script is launched on the target
#  Variables will be interverted if the script is used for switchback
#
SOURCE_SERVER=lnx002833.mpl.michelin.com
SOURCE_OWNER=rfopamea
TARGET_SERVER=lnx004016.oci.michelin.com
TARGET_OWNER=rfopamea


[ "$(id -un)" != "$TARGET_OWNER" ] && die "Script must be run by the \"$TARGET_OWNER\" user"

LOG_DIR=$HOME/synchro/logs
mkdir -p $LOG_DIR

LOG_FILE=$LOG_DIR/$(basename $0 .sh)_$(date +%Y%m%d_%H%M%S).log
PID_FILE=$LOG_DIR/${SCRIPT}.pid

[ "$COUNT_ONLY" = "YES" ] && LOG_FILE=/dev/null

{
  startRun "$SCRIPT_DIR"

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

  #ssh $SOURCE_SERVER -- find $src_base -type d -maxdepth 3 -exec stat -c \'%n %U %G %a %A\' {} \\\; | grep -v "^$src_base " | sed -e "s;^$src_base/;;" | grep -v "lost+found" | while read f u g m M
  ssh $SOURCE_SERVER -- find $src_base -type d -exec stat -c \'%n %U %G %a %A\' {} \\\; | grep -v "^$src_base " | sed -e "s;^$src_base/;;" | grep -v "lost+found" | while read f u g m M
  do
    printf "%-50s %10s %10s %10s (%s) " $f $u $g $m $M
    if [ "$u" = "$SOURCE_OWNER" ]
    then
      #case $f in
      #data*|log*|out*|inbound*|outbound*|applptmp*|FEX*)
        d2=$dst_base/$f
        [ ! -d $d2 ] && { echo -n "Creating " ; mkdir $d2 ; } || echo -n "Exists  "
        echo -n " - - - - - - - - - - - - - -> "
        echo -n "Set Mode $m " 
        chown $(id -u):$g $d2
        chmod $m $d2
        mode=$(stat -c %A $d2)
        echo -n "($mode) "
        echo -n "Set ACL " 
        setfacl -m u:oracle:rwx $d2
      # ;;
      #*) echo -n "NOT processed (not used from DB)"
      #   ;;
      #esac
    else
      echo -n "NOT Processed (owner=$u)"
    fi
    echo
  done
 
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

