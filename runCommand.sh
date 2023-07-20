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

usage()
{
echo "Usage :
  $(basename $0) {servers list} [command file]

  Run a scrip on a list of servers. If no script is given, just test the connection "
  exit 1
}
set -o pipefail

SCRIPT=$(basename $0 .sh)
SCRIPT_LIB="Run commands on several servers" 

[ "$1" = "-?" ] && usage
[ "$1" = "-h" ] && usage
[ "$1" = "" ] && usage

LOG_DIR=$HOME/mbo/logs
mkdir -p $LOG_DIR

LOG_FILE=$LOG_DIR/${SCRIPT}_$(date +%Y%m%d_%H%M%S).log


{
  startRun "$SCRIPT_LIB"

  grep -v "^#" $1 | sed -e "/^ *$/ d" -e "s;#.*$;;" | while read line
  do

    host=$(echo $line | cut -f1 -d";")
    lib=$(echo $line | cut -f2 -d";")

    startStep "Run on $host"

    echo "    =========================================================="
    echo "    - $lib"
    echo -n "    - $host : "
    if ssh -q -o strictHostKeyChecking=no $host true </dev/null
    then
      echo "Access OK, can run command"
      echo "    =========================================================="
      echo
      if [ "$2" = "" ]
      then
        echo "    - No file to run"
      else
        echo "    - Running $2 on $host"
        echo
        ssh -q -o strictHostKeyChecking=no $host < $2
        echo
      fi
    else
      echo "Unable to access host"
      echo "    =========================================================="
      echo
    fi
    
    endStep

  done

  endRun
} 2>&1 | tee $LOG_FILE
