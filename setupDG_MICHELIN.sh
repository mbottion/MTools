VERSION="2.6 (Michelin PROD 07/2023)"
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#
#   Appelé par l'option -T, permet de tester des parties de script
#
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# DG (DATAGUARD)or ADG (Active DATAGUARD)

IsADG="true"

returnDGDATARECO ()
{
  . oraenv <<< $ASM_INSTANCE >/dev/null

  #DGDATA=$($ORACLE_HOME/bin/asmcmd --privilege sysdba lsdg | grep DATA | awk '{print $14}')
  #DGREDO=$($ORACLE_HOME/bin/asmcmd --privilege sysdba lsdg | grep RECO | awk '{print $14}')

  DGDATA=$($ORACLE_HOME/bin/asmcmd --privilege sysdba find DATA* $primDbUniqueName | head -n 1)
  DGDATA="${DGDATA%%/*}"

  DGREDO=$($ORACLE_HOME/bin/asmcmd --privilege sysdba find OTHER* $primDbUniqueName | head -n 1)
  DGREDO="${DGRECO%%/*}"
  #  if [[ -n "$DGREDO" ]]
  #then
    # "not Empty"
  # DGREDO="${DGRECO%%/*}"
  #elseF
   #   # "empty"
  # DGREDO=$($ORACLE_HOME/bin/asmcmd --privilege sysdba find RECO* $stbyDbUniqueName | head -n 1)
  # DGREDO="${DGRECO%%/*}"
  #fi

}

testUnit()
{
  startStep "Functionality Test"


  endStep
}
verificationDG()
{
  echo
  echo "  - Status DG"
  echo "    ==============================="
  echo

  #############################################################################################################
   # printf "%-75s : " "      - connection to ${primDbName}_dg    dbUniqueName (nominal) = $primDbUniqueName"
  #  res=$(exec_sql "sys/${dbPassword}@ ${primDbName}_dg as sysdba" "select db_unique_name from v\$database ;")
   # if [ "$res" = "$primDbUniqueName" ]
    #then
      #echo "OK --> $res"
    #elif [ "$res" = "$stbyDbUniqueName" ]
    #then
      #echo "Retourne --> $res"
    #else
      #echo "Error"
      #echo "$res"
      #die "Bad Connection to ${primDbName}_dg"
    #fi

   # printf "%-75s : " "      - connection to ${primDbName}_dg_ro dbUniqueName (nominal) = $stbyDbUniqueName"
   # res=$(exec_sql "sys/${dbPassword}@ ${primDbName}_dg_ro as sysdba" "select db_unique_name from v\$database ;")
   # if [ "$res" = "$stbyDbUniqueName" ]
  # then
  # echo "OK --> $res"
   # elif [ "$res" = "$primDbUniqueName" ]
   # then
      #echo "Retourne --> $res"
    #else
  # echo "Error"
  # echo "$res"
  # die "Bad Connection to ${primDbName}_dg_ro"
   # fi
  #############################################################################################################
  echo ===============================================================
  echo Configuration
  echo ===============================================================
  dgmgrl -silent / "show configuration"

  echo ===============================================================
  echo Show database $stbyDbUniqueName
  echo ===============================================================
  dgmgrl -silent / "show database verbose '$stbyDbUniqueName'"

  echo ===============================================================
  echo Show database $primDbUniqueName
  echo ===============================================================
  dgmgrl -silent / "show database verbose '$primDbUniqueName'"

  echo ===============================================================
  echo Validate database $stbyDbUniqueName
  echo ===============================================================
  dgmgrl -silent / "validate database verbose '$stbyDbUniqueName'"

  echo ===============================================================
  echo Validate database $primDbUniqueName
  echo ===============================================================
  dgmgrl -silent / "validate database verbose '$primDbUniqueName'"

  echo ===============================================================
  echo Configuration
  echo ===============================================================
  dgmgrl -silent / "show configuration"
  echo ===============================================================

}


#Fonction de positionnement sur l'env
setEnvPrimaire()
{
if [ -f "$HOME/${primDbName}.env" ]; then
  echo "  - Primary is cloud database ($HOME/${primDbName}.env exists)"
  . $HOME/${primDbName}.env
elif [ -f /dbfs_tools/TOOLS/admin/sh/osetenv ]
then
  echo "  - Primary is ARVAL database (/dbfs_tools/TOOLS/admin/sh/osetenv exists)"
  . /dbfs_tools/TOOLS/admin/sh/osetenv $primDbName
else
  die "Unable to set Primary environment"
fi

if [ "$TNS_ADMIN" = "" ]
then
  export TNS_ADMIN=$ORACLE_HOME/network/admin
fi
  echo "  - TNS_ADMIN=$TNS_ADMIN"
}
setEnvStandby()
{

. /home/oracle/$stbyDbName.env
#stbyEnvFile=${stbyEnvFile:-$HOME/$stbyDbName.env}
 # if [ -f $stbyEnvFile ]
 # then
 # . /home/oracle/$stbyEnvFile || die "Impossible de positionner l'environnement Standby"
 # fi
if [ "$TNS_ADMIN" = "" ]
then
  export TNS_ADMIN=$ORACLE_HOME/network/admin
fi
}

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#
#   Etapes post duplication
#   - Reinitialisation des LOGS et STANDBY LOGS
#   - Parametrage des deux bases pour le Broker
#   - Creation de la configuration broker
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
finalisationDG()
{

  startStep "Finalizing the configuration DATAGUARD"
  echo
  echo "
        NOTE: If the procedure in this phase fails , it can be re-execute again,
        it will be resume from the last error , be careful
        nevertheless, if the source database evolves too much, it is
        possible that the synchronization can no longer be done
      "

  echo
  exec_sql -verbose "/ as sysdba" "
set serveroutput on
begin
  dbms_output.put_line('Clearing redo log groups');
  for log_cur in ( select group# group_no from v\$log )
  loop
    dbms_output.put_line('-    Groupe ' || log_cur.group_no) ;
    execute immediate 'alter database clear logfile group '||log_cur.group_no;
  end loop;
end;
/
" "  - Clearing of REDO-LOGS (Erreur a la deuxieme execution)"

  echo
  exec_sql -verbose "/ as sysdba" "
set serveroutput on
begin
  dbms_output.put_line('Clearing stand-by redo log groups');
  for log_cur in ( select group# group_no from v\$standby_log )
  loop
    dbms_output.put_line('-    Groupe ' || log_cur.group_no) ;
    execute immediate 'alter database clear logfile group '||log_cur.group_no;
  end loop;
end;
/
" "  - Clearing of STANDBY REDO-LOGS (Erreur a la deuxieme execution)"


setEnvStandby >/dev/null

# se positionner de nouveau à l'environnement de STANDBY.

  echo
  echo "  - Dataguard Broker (Stand By : $stbyDbUniqueName)"

  exec_sql -verbose "/ as sysdba" \
                    "alter system set dg_broker_start=false SCOPE=BOTH SID='*';" \
                    "    - Arret broker"

  exec_sql -verbose "/ as sysdba" \
                    "alter system set dg_broker_config_file1='$SDATA/$stbyDbUniqueName/DG/dr${stbyDbName}_1.dat' SCOPE=BOTH SID='*';" \
                    "    - Config Broker #1"
  exec_sql -verbose "/ as sysdba" \
                    "alter system set dg_broker_config_file2='$SDATA/$stbyDbUniqueName/DG/dr${stbyDbName}_2.dat' SCOPE=BOTH SID='*';" \
                    "    - Config Broker #2"

  exec_sql -verbose "/ as sysdba" \
                    "alter system set dg_broker_start=true SCOPE=BOTH SID='*';" \
                    "    - Lancement broker"
  exec_sql -verbose "/ as sysdba" \
                    "alter database set standby database to maximize availability;" \
                    "    - Max availability"
  exec_sql -verbose "/ as sysdba" \
                    "alter system set DB_BLOCK_CHECKING=FALSE scope=both sid='*'; " \
                    "    - DB Block Checking = FALSE"

  echo
  echo "  - Dataguard Broker (Primary : $primDbUniqueName)"

  ## CBI - 20221114 - Ces actions ne sont pas utiles ?
  ## MBO - 20230603 - Ben si, si la primaire n'a pas de DG, çà ne peut pas marcher si on ne créepas les fichiers
  ##                 (ça crée par défaut des fichiers sur un seul noeud)!!!!

  exec_sql -verbose "sys/${dbPassword}@$primDbUniqueName as sysdba" \
                      "alter system set dg_broker_start=false SCOPE=BOTH SID='*';" \
                      "    - Stop broker (primary)"

  v=$(exec_sql "sys/${dbPassword}@$primDbUniqueName as sysdba" "select value from v\$parameter where name ='dg_broker_config_file1';")
  if [ "$v" = "" -o "$(echo $v | cut -c1-1)" = "/" ]
  then
    exec_sql -verbose "sys/${dbPassword}@$primDbUniqueName as sysdba" \
                      "alter system set dg_broker_config_file1='$(echo ${PDATA} | cut -d ',' -f1 | tr -d ' ')/$primDbUniqueName/DG/dr${primDbName}_1.dat' SCOPE=BOTH SID='*';" \
                      "    - Config Broker #1 (primary)"
  else
    echo "    - Config Broker #1 already exists ($v)"
  fi
  v=$(exec_sql "sys/${dbPassword}@$primDbUniqueName as sysdba" "select value from v\$parameter where name ='dg_broker_config_file2';")
  if [ "$v" = "" -o "$(echo $v | cut -c1-1)" = "/" ]
  then
    exec_sql -verbose "sys/${dbPassword}@$primDbUniqueName as sysdba" \
                      "alter system set dg_broker_config_file2='$(echo ${PDATA} | cut -d ',' -f1 | tr -d ' ')/$primDbUniqueName/DG/dr${primDbName}_2.dat' SCOPE=BOTH SID='*' ;" \
                      "    - Config Broker #2 (primary)"
  else
    echo "    - Config Broker #2 already exists ($v)"
  fi


  exec_sql -verbose "sys/${dbPassword}@$primDbUniqueName as sysdba" \
                    "alter system set dg_broker_start=true SCOPE=BOTH SID='*';" \
                    "    - Start broker (primary)"
  exec_sql -verbose "sys/${dbPassword}@$primDbUniqueName as sysdba" \
                    "alter system set DB_BLOCK_CHECKING=MEDIUM scope=both sid='*'; " \
                    "    - DB Block Checking = MEDIUM  (primary)"

  echo
  echo "  - Modify database startoption and role"

  exec_srvctl "modify database -d $ORACLE_UNQNAME -startoption MOUNT -role PHYSICAL_STANDBY" \
              "    - Change Database startoption to MOUNT" \
              "OK" "Error" "Impossible to modify the database startoption"

  echo
  echo "  - Setup of DATAGUARD Broker configuration"
  sleep 10

  ## CBI - 20221114 - Check if configuration already exists (FSC to Configuration name)

  createConfig="N"

  configName=$(echo 'show configuration' | dgmgrl sys/${dbPassword}@$primDbUniqueName | grep '^Configuration -' | cut -d '-' -f2 | tr -d ' ')
  if [ "$configName" = "" ]; then
    createConfig="Y"
    configName="fsc"
  fi

  echo "    Config Name : $configName To Create : $createConfig"
  # exit

  if [ "$createConfig" = "Y" ]; then
    i=1
    while [ $i -le 10 ]
    do

      exec_dgmgrl "sys/${dbPassword}@$primDbUniqueName" "create configuration '$configName' as primary database is '$primDbUniqueName' connect identifier is '$primDbUniqueName'" \
                  "Creation of configuration (trying : $i/10)"  2>&1 | tee $$.tmp2
      if  [ $? -ne 0 ]
      then
        if grep -i "already exists" $$.tmp2>/dev/null
        then
          echo "Configuration already exist"
          break
        fi
        rm -f $$.tmp2
        [ $i -lt 10 ] && { echo "    - Wait 30s" ; sleep 30 ; } || die "Impossible to create the DG configuration"
      else
        # i=10
        break
      fi
      i=$(($i + 1))
       # echo "Continue ..."
    done
    rm -f $$.tmp2
  fi

  echo
  echo "  - DATAGUARD Broker configuration Setup"
  sleep 5


 exec_dgmgrl "disable configuration" "Disable DGMGRL configuration" || die "Erreur DGMGRL"
 exec_dgmgrl "remove database '$stbyDbUniqueName'" "Remove Database $stbyDbUniqueName from DGMGRL (If Error => Not Exist) "

 exec_dgmgrl "add database '$stbyDbUniqueName' as connect identifier is '$stbyDbUniqueName' maintained as physical" \
                "Add Standby Database to DGMGRL " || die "Error DGMGRL"
 exec_dgmgrl "edit configuration set protection mode as maxperformance" "Set protection maxperformance"

 exec_dgmgrl "show configuration"
 
 primDbConf=$(echo 'show configuration' | dgmgrl sys/${dbPassword}@$primDbUniqueName | grep -i 'Primary database' | cut -d '-' -f1 | tr -d ' ')

 #  exec_dgmgrl "edit database '$primDbConf' set property FastStartFailoverTarget=''"
  exec_dgmgrl "EDIT CONFIGURATION SET PROPERTY OperationTimeout=600" \
              "Operation Timeout" || die "Erreur DGMGRL(OperationTimeout)"
  exec_dgmgrl "edit configuration set protection mode as MaxPerformance" \
              "Mode de protection" || die "Erreur DGMGRL (MaxPerformance)"
  exec_dgmgrl "edit database '$primDbConf' set property NetTimeout=30" \
              "NetTimeout (Primary)" || die "Erreur DGMGRL (NetTimeout)"
  exec_dgmgrl "edit database '$stbyDbUniqueName' set property LogXptMode='ASYNC'" \
              "LoXptMode (Stand-by)" || die "Erreur DGMGRL (LogXptMode)"
  exec_dgmgrl "edit database '$stbyDbUniqueName' set property NetTimeout=30" \
              "NetTimetout (STand-by)" || die "Erreur DGMGRL (NetTimeout)"
  exec_dgmgrl "edit database '$stbyDbUniqueName' set property FastStartFailoverTarget='$primDbConf'" \
              "Target (Primary)" || die "Erreur DGMGRL"
  exec_dgmgrl "edit database '$primDbConf' set property FastStartFailoverTarget='$stbyDbUniqueName'" \
              "Target (Stand-by)" || die "Erreur DGMGRL"
  exec_dgmgrl "edit database '$stbyDbUniqueName' set property ApplyLagThreshold=0" \
              "ApplyLagThreshold (STand-by)" || die "Erreur DGMGRL"
  exec_dgmgrl "edit database '$stbyDbUniqueName' set property TransportLagThreshold=0" \
              "TransportLagThreshold (STand-by)" || die "Erreur DGMGRL"
  exec_dgmgrl "edit database '$primDbConf' set property LogXptMode='ASYNC'" \
              "LoXptMode (Primary)" || die "Erreur DGMGRL"


#NodesListNum=$(exec_sql "sys/${dbPassword}@$tnsTestConnect as sysdba" "select substr(n,length(n),1) from (select regexp_replace(host_name,'([^.])\..*','\1') n from gv\$instance) order by 1;")

#for j in ${NodesListNum[@]}; do

#exec_dgmgrl "edit instance '${primDbName}$j' on database '$primDbUniqueName' set property StaticConnectIdentifier='${primDbUniqueName}$i_"DGMGRL"'" \
#             "Connection I1 (Primary)" || die "Error DGMGRL"

#done


 #NBNode=$(exec_sql "/ as sysdba" "select count(*) from gv\$instance;")

#for i in `seq 1 1 $NBNode`
#   do
#   exec_dgmgrl "edit instance '${stbyDbName}$i' on database '$stbyDbUniqueName' set property StaticConnectIdentifier='${stbyDbUniqueName}$i_DGMGRL'" \
#             "Connection I1 (Stand-BY)" || die "Error DGMGRL"
#done

  exec_dgmgrl "enable configuration" "enable configuration" || die "Error DGMGRL"

  sleep 10

  echo
  echo "  - Adding of DATAGUARD Services"
  echo "    ============================"
  echo
  if [ "$(ps -ef | grep smon_$ORACLE_SID | grep -v grep)" = "" ]
  then
    exec_srvctl "start database -d $ORACLE_UNQNAME" \
                "    - Start the Database" \
                "OK" "Error" "Impossible to startup database"
  fi
  printf "%-75s : " "    - Role of Database : $stbyDbUniqueName"
  dbRole=$(exec_sql "/ as sysdba" "select database_role from v\$database; ") \
    && { echo "$dbRole" ; } \
    || { echo Erreur ; echo $dbRole ; die "Impossible to get the database Role" ; }

  [ "$dbRole" = "PRIMARY" ] && die "The Role of database is incorrect"
    printf "%-75s : " "    - Status of the database : $stbyDbUniqueName"
  dbState=$(exec_sql "/ as sysdba" "select open_mode from v\$database; ") \
    && { echo "$dbState" ; } \
  || { echo Erreur ; echo $dbState ; die "Impossible to get the database Status" ; }

  if [ "$dbState" = "MOUNTED" ]
  then

    # exec_srvctl "modify database -d $ORACLE_UNQNAME -startoption MOUNT -role PHYSICAL_STANDBY" \
                # "    - Change Database startoption to MOUNT" \
                # "OK" "Error" "Impossible to modify the database startoption"

    exec_srvctl "stop database -d $ORACLE_UNQNAME" \
                "    - Stop Database" \
                "OK" "Error" "Impossible to stop the database"

    exec_srvctl "start database -d $ORACLE_UNQNAME" \
                "    - Startup Database" \
                "OK" "Error" "Impossible to start the database"

    printf "%-75s : " "    - Status of database $stbyDbUniqueName"
    dbState=$(exec_sql "/ as sysdba" "select open_mode from v\$database; ") \
      && { echo "$dbState" ; } \
      || { echo Error ; echo $dbState ; die "Impossible to get the database status" ; }

  fi
  # if [ ["$(echo $dbState | grep -i "READ ONLY")" = "" ] && [$IsADG = "true"] ]
  # then
    # exec_sql "/ as sysdba" "alter database open read only; " "    - Open database in Read-only" \
      # || die "Impossible to Open the Database in Ready Only"
  # fi

  exec_sql -verbose "/ as sysdba" \
                    "alter database flashback on ; " \
                    "    - Enable the flashback on the stand-by database"
####################################################################
####################################################################
#  addDGService ${primDbName}_dg    PRIMARY          N
#  addDGService ${primDbName}_dg_ro PHYSICAL_STANDBY Y

  exec_dgmgrl "edit database '$stbyDbUniqueName' set state=apply-on" \
              "Start the Recovery Apply-ON" || die "Error DGMGRL"

  verificationDG


  endStep
}
####################################################################
####################################################################
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#   Duplication de la base de donnees vers la stand-by.
#     - Generation des entrees TNSNAMES
#     - Recopie du TNSNAMES sur l'autre noeud
#     - Lancement en NOMOUNT et restauration Control File
#     - Lancement en MOUNT et restauration puis recover
#     - On lance ensuite la finalisation qui peut etre relancee plusieurs fois
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
duplicateDBForStandBY()
{
  LOG_TMP=$LOG_DIR/restau_${primDbName}_$DAT.log
  if [ "$step" = "" ]
  then
    startStep "Database Preparation"

    echo
    echo "  - RMAN Configuration (on primary)"
    echo "    ===================================="
    echo
    
    exec_rman "sys/${dbPassword}@$primDbUniqueName" "configure db_unique_name $primDbUniqueName connect identifier '$primDbUniqueName';" "Rman Connect identifier for $primDbUniqueName"
    exec_rman "sys/${dbPassword}@$primDbUniqueName" "configure db_unique_name $stbyDbUniqueName connect identifier '$stbyDbUniqueName';" "Rman Connect identifier for $primDbUniqueName"
    
    echo
    echo "  - Generation of Alias TNS necessary"
    echo "    ===================================="
    echo
    tnsAliasesForDG "$stbyDbUniqueName" "$hostStandBy"  "$portStandBy"  "$serviceStandBy"  "$domaineStandBy" \
                    "$primDbUniqueName" "$hostPrimaire" "$portPrimaire" "$servicePrimaire" "$domainePrimaire"

    echo
    echo "  - Copy the Alias TNS to the other(s) Node(s)"
    echo "    ===================================="
    echo

#######
#. oraenv <<< $ASM_INSTANCE >/dev/null
#ListDGHosts=$(olsnodes)
# ListDGHosts=$(srvctl status database -db $stbyDbUniqueName | awk '{print $8}')
ListDGHosts=$(srvctl config database -db $stbyDbUniqueName | grep 'Configured nodes:' | cut -d ':' -f2 | sed 's/^ *//g' | tr "," "\n")
setEnvStandby
########

## CBI - 20221219 - Ecrase la configuration du TNS sur les noeuds : LISTENER_IPLOCAL pointe sur le noeud 1
  for host in $ListDGHosts;
  do
    if [ "$host" != ${HOSTNAME%%.*} ]
    then

      echo "      ============================="
      echo "    - Updating TNS aliases on $host"
      echo "      ============================="
      echo

      ssh -q oracle@${host} -o StrictHostKeyChecking=no /bin/bash <<EOF
export stbyDbName=$stbyDbName
$(typeset -f setEnvStandby)
$(typeset -f addToTns)
$(typeset -f tnsAliasesForDG)
setEnvStandby
# env | grep ORA
# env | grep TNS
tnsAliasesForDG "$stbyDbUniqueName" "$hostStandBy"  "$portStandBy"  "$serviceStandBy"  "$domaineStandBy" \
                "$primDbUniqueName" "$hostPrimaire" "$portPrimaire" "$servicePrimaire" "$domainePrimaire"
EOF

    fi
  done

  # "Getting list of tempfiles"
SWITCH_TEMPFILE_CLAUSE=$(exec_sql "sys/${dbPassword}@$tnsTestConnect as sysdba" "
set feed off head off lines 200 pages 300
select 'set newname for tempfile '||file#||' to new;' from v\$tempfile;")

    endStep

    startStep "Duplication of the database (from $primDbUniqueName) "
    echo
    exec_srvctl "start database -d $stbyDbUniqueName -o nomount" \
              "    - Startup Database in NO MOUNT to restore control file" \
              "OK" "Error" "Impossible to startup in NOMOUT"


     #if [ "$CHECKCDB" = "YES" ]
     if [ "$CHECKCDB" = "YES" -a "$listePDB" != "" ]
     then
     SETNEWNAMEPDB="set newname for pluggable database $listePDB to NEW ;"
     else
     SETNEWNAMEPDB=""
     fi


              printf "%-75s : " "      - Restore of Control File"

    # rman target / >$$.tmp 2>&1 <<%%
    rman target sys/${dbPassword} >$$.tmp 2>&1 <<%%
run {
restore standby controlfile from service '$primDbUniqueName' ;
}
%%
    [ $? -eq 0 ] && { echo OK ; rm -f $$.tmp ; } \
                 || { echo ERREUR ; cat $$.tmp ; rm -f $$.tmp ; die "Error to restore control file" ; }

## Gestion du multi diskgroup
DGDATA=""
DBFNC=""
for DGDATA in $(echo ${PDATA} | tr "," "\n")
do
if [ "$DBFNC" != "" ]
then
DBFNC="$DBFNC,'$DGDATA','$SDATA'"
else
DBFNC="'$DGDATA','$SDATA'"
fi
done

DGRECO=""
LFNC=""
for DGRECO in $(echo ${PRECO} | tr "," "\n")
do
if [ "$LFNC" != "" ]
then
LFNC="$LFNC,'$DGRECO','$SRECO'"
else
LFNC="'$DGRECO','$SRECO'"
fi
done

    exec_sql "/ as sysdba" "
      ALTER SYSTEM SET DB_CREATE_FILE_DEST='$SDATA' scope=spfile;"
    exec_sql "/ as sysdba" "
      alter system SET DB_CREATE_ONLINE_LOG_DEST_1='$SRECO' scope=spfile;"
    exec_sql "/ as sysdba" "
      alter system SET DB_CREATE_ONLINE_LOG_DEST_2='$SDATA' scope=spfile;"


    exec_sql "/ as sysdba" "alter system reset db_domain scope=spfile;" "      - Remove db_domain (If Error => Already removed)"
    exec_sql "/ as sysdba" "alter system reset listener_networks scope=spfile;" "      - Reset listener_networks (If Error => Already reset)"

    exec_sql "/ as sysdba" "alter system set standby_file_management='AUTO' scope=spfile;" "      - Set standby_file_management to AUTO"
    exec_sql "/ as sysdba" "alter system set archive_lag_target=900 scope=spfile;" "      - Set archive_lag_target to 900"
    exec_sql "/ as sysdba" "alter system set db_file_name_convert=$DBFNC scope=spfile;" "      - Set db_file_name_convert"
    exec_sql "/ as sysdba" "alter system set log_file_name_convert=$DBFNC,$LFNC scope=spfile;" "      - Set log_file_name_convert"

    exec_dgmgrl "disable configuration" "Disable DGMGRL configuration (If Error => Configuration Not Exist)"
    exec_dgmgrl "remove database '$stbyDbUniqueName'" "Remove Database $stbyDbUniqueName from DGMGRL (If Error => Not Exist) "
    exec_dgmgrl "enable configuration" "enable configuration (If Error => Configuration Not Exist)"

    exec_srvctl "modify database -d $stbyDbUniqueName -domain \"\"" \
                "    - Remove domain from clusterware" \
                "OK" "Error" "Impossible to remove domain from clusterware"

    exec_srvctl "stop database -d $stbyDbUniqueName" \
                "      - Shutdown Database" \
                "OK" "Error" "Impossible to Shutdown Database"

    echo
    exec_srvctl "start database -d $stbyDbUniqueName -o mount" \
                "    - Startup in MOUNT to restore" \
                "OK" "Error" "Impossible to startup in MOUNT"

    # exec_srvctl "modify database -d $stbyDbUniqueName -domain \"\"" \
                # "    - Remove domain from clusterware" \
                # "OK" "Error" "Impossible to remove domain from clusterware"

    echo
    echo "     Note : You can follow the restore steps in : "
    echo "     $LOG_TMP"

    printf "%-75s : " "      - Database Restore"
  cat >/tmp/rman1_$$.txt <<%%

set echo on

run {
set newname for database to NEW ;

$SETNEWNAMEPDB

$SWITCH_TEMPFILE_CLAUSE

$channelClause

restore  database from service '$primDbUniqueName' section size $sectionSizeRESTORE;
switch datafile all ;
switch tempfile all ;
}
%%
# cp /tmp/rman1_$$.txt /tmp/restoreCmd.txt
    rman target sys/${dbPassword} >$LOG_TMP 2>&1 @/tmp/rman1_$$.txt
    [ $? -eq 0 ] && { echo OK ; cat $LOG_TMP ; rm -f $LOG_TMP; rm -f /tmp/rman1_$$.txt ; } \
                 || { echo ERREUR ; cat $LOG_TMP  ; rm -f $LOG_TMP; die "Erreur de restauration de la base" ; rm -f /tmp/rman1_$$.txt ; }

else
  startStep "Reprise of Step $step"
fi
 echo "     Note : You can follow the recover steps in : "
  echo "     $LOG_TMP"
  printf "%-75s : " "      - Recover Of Database"

cat >/tmp/rman2_$$.txt <<%%
run {
$channelClause
recover database from service '$primDbUniqueName' section size $sectionSizeRECOVER;
}
%%
  rman target sys/${dbPassword} >$LOG_TMP 2>&1 @/tmp/rman2_$$.txt
  [ $? -eq 0 ] && { echo OK ; cat $LOG_TMP ; rm -f $LOG_TMP; rm -f /tmp/rman2_$$.txt ; } \
               || { echo ERREUR ; cat $LOG_TMP  ; rm -f $LOG_TMP; die "Error of Recover on the database" ; rm -f /tmp/rman2_$$.txt ; }

  endStep
  echo
  echo "  - Waiting 30 sec . . . ."
  sleep 30

  endStep

  exec_sql "/ as sysdba" "
alter system reset db_file_name_convert ;" "      - reset db_file_name_convert"
  exec_sql "/ as sysdba" "
alter system reset log_file_name_convert ;" "      - reset log_file_name_convert"
  finalisationDG
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#
#  Cette procedure prepare la base stand-by pour mise en place de la base
#  stand-by. Il n'y a aucun arret de la base pendant cette phase
#
#    - Verifications de base
#    - Recuperation du wallet et du fichier password
#    - Mise a jour des parametres necessaires
#    - Generation des alias TNS utiles pour le broker
#    - Ajout des services DATAGUARD
#    - Si le SSH est ouvert vers le serveur stand-by on
#      recopie les fichiers, sinon il faudra les recopier
#      manuellement dans /tmp en gardant les mêmes noms.
#
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
preparePrimary()
{
  tmpOut=/tmp/$$.tmp

  echo "  - Operations on the database $primDbName PRIMARY site"
  echo
  echo "    When this operation is done, you should run"
  echo "    this script on the DR Site with all the parameters"
  echo "    given at the end of this execution"
  echo
  echo "  - Verification"
  echo "    ============="
  echo

  printf "%-75s : " "    - Test SQL*Net route to PRIMARY database (SCAN)"
  tnsping $tnsPrimaire >/dev/null 2>&1 && echo "OK" || { echo "ERROR" ; die "TNS of the database Primary is inaccessible" ; }

  printf "%-75s : " "    - Test SQL*Net route to STAND-BY database (SCAN)"
  tnsping $tnsStandBy >/dev/null 2>&1 && echo "OK" || { echo "ERROR" ; die "TNS of the database Standby is inaccessible" ; }
  printf "%-75s : " "    - Get GRID_HOME path"
  gridHome=$(grep "^+ASM$hostnum:" /etc/oratab | cut -f2 -d":")
  [ "$gridHome" = "" ] &&  { echo "Impossible" ; die "Impossible to get the GRID_HOME Path Location" ; } || echo "OK ($gridHome)"

  checkDBParam "  Database in force Logging"     "select force_logging from v\$database;"                           "YES"
  #checkDBParam "  Database in Flashback"         "select flashback_on  from v\$database;"                           "YES"
  tdeExist=$(exec_sql "/ as sysdba" "select to_char(count(*)) from v\$encryption_wallet where WRL_PARAMETER is not null and STATUS ='OPEN';")
    if [ $tdeExist != "0" ]
      then
  echo
  echo "  - Copy of files needed for Standby Database Creation "
  echo "    ============================================================="
  echo
  printf "%-75s : " "    - Get Location Path of TDE wallet"
  tdeWallet=$(exec_sql "/ as sysdba" "select wrl_parameter from v\$encryption_wallet;")
  [ -d "$tdeWallet" ] && { echo $tdeWallet ; } \
                      || { echo "Error" ; echo $tdeWallet ; die "Impossible to get the path of the wallet location" ; }

  printf "%-75s : " "    - Copy of Wallet files"
  { cp $tdeWallet/ewallet.p12 /tmp/${primDbUniqueName}_ewallet.p12 \
    && cp $tdeWallet/cwallet.sso /tmp/${primDbUniqueName}_cwallet.sso ; } \
       && echo "OK"  \
       || die "Impossible to copy wallet files"

         fi     #tdeExist

  #
  #   On doit avoir l'environnement ASM pour utiliser ASMCMD
  #
  echo
  printf "%-75s : " "    - Password File"
  passwordFile=$(srvctl config database -d ${primDbUniqueName} | grep -i "Password file" | sed -e "s;^.*: *;;")

  # if [ -z "$passwordFile" ]  ##Check if password file exist in $ORACLE_HOME/dbs/
  if [ "$(echo $passwordFile | cut -c1-1)" != "+" ]
  then
    # passwordFile=$ORACLE_HOME/dbs/orapw$ORACLE_SID*     ## Problematique si backup de passwordfile avec un nom commun
    passwordFile=$ORACLE_HOME/dbs/orapw$ORACLE_SID
        ls $passwordFile >/dev/null 2<&1 \
    && { echo $passwordFile ; } \
    || { echo "Error"  ; echo $passwordFile ; die "Impossible to find the Password File" ; }
    echo "      - Non ASM paswword file"
    printf "%-75s : " "    - Copy of password file"
    rm -rf /tmp/recup$$
    mkdir /tmp/recup$$
    chmod 777 /tmp/recup$$
    #$gridHome/bin/asmcmd --privilege sysdba cp $passwordFile /tmp/recup$$/${primDbUniqueName}_passwd.ora >$$.tmp 2<&1 \
    cp $passwordFile /tmp/recup$$/${primDbUniqueName}_passwd.ora >$$.tmp 2<&1 \
    && { echo "OK" ; cp /tmp/recup$$/${primDbUniqueName}_passwd.ora /tmp/${primDbUniqueName}_passwd.ora ; rm -f $$.tmp ; } \
    || { echo "Error"  ; cat $$.tmp ; rm -f $$.tmp ; die "Impossible to get the Password file" ; }
    rm -rf /tmp/recup$$

    ## Copy passwordfile to other nodes
    ListDGHosts=$(srvctl config database -db ${primDbUniqueName} | grep 'Configured nodes:' | cut -d ':' -f2 | sed 's/^ *//g' | tr "," "\n")

    for host in $ListDGHosts
    do
      if [ "$host" != ${HOSTNAME%%.*} ]
      then
        # passwordFilePath=$(ssh -q oracle@$host -o StrictHostKeyChecking=no ". /dbfs_tools/TOOLS/admin/sh/osetenv ${primDbUniqueName} && echo \$ORACLE_HOME/dbs/orapw\$ORACLE_SID")

        passwordFilePath=$(ssh -q oracle@$host -o StrictHostKeyChecking=no "if [ -f \"/home/oracle/${dbName}.env\" ]; then . /home/oracle/${dbName}.env ; else . /dbfs_tools/TOOLS/admin/sh/osetenv ${primDbUniqueName} ; fi && echo \$ORACLE_HOME/dbs/orapw\$ORACLE_SID")

        # if [ -f "/home/oracle/${dbName}.env" ]; then . /home/oracle/${dbName}.env && echo ECC ; else . /dbfs_tools/TOOLS/admin/sh/osetenv ${primDbUniqueName} && echo EXA ; fi && echo "$ORACLE_HOME/dbs/orapw$ORACLE_SID"

        printf "%-75s : " "      - Copy password file to $host"
                scp -o StrictHostKeyChecking=no /tmp/${primDbUniqueName}_passwd.ora $host:$passwordFilePath \
                  && echo "OK" \
                  || die "Error"
      fi
    done
 
  else ## CHECK the password file that exist in ASM
    . oraenv <<< $ASM_INSTANCE >/dev/null
    $gridHome/bin/asmcmd --privilege sysdba ls $passwordFile >/dev/null 2>&1 \
    && { echo $passwordFile ; } \
    || { echo "Error"  ; echo $passwrdFile ; die "Impossible to find the Password File" ; }
    echo "    - ASM password file"
    printf "%-75s : " "      Copy of password file From ASM"
    #
    #     Ce bricolage immonde permet de contourner le probleme
    # de droits d'accès au fichier qui appartient à grid au départ
    #
    rm -rf /tmp/recup$$
    mkdir /tmp/recup$$
    chmod 777 /tmp/recup$$
    $gridHome/bin/asmcmd --privilege sysdba cp $passwordFile /tmp/recup$$/${primDbUniqueName}_passwd.ora >$$.tmp 2<&1 \
    && { echo "OK" ; cp /tmp/recup$$/${primDbUniqueName}_passwd.ora /tmp/${primDbUniqueName}_passwd.ora ; rm -f $$.tmp ; } \
    || { echo "Error"  ; cat $$.tmp ; rm -f $$.tmp ; die "Impossible to get the Password file" ; }
    rm -rf /tmp/recup$$
  fi


  setEnvPrimaire > /dev/null

  asmPath=$(echo ${PDATA} | cut -d ',' -f1 | tr -d ' ')/$primDbUniqueName/DG
  printf "%-75s : " "    - Test of $asmPath"
  . oraenv <<< $ASM_INSTANCE >/dev/null
  $gridHome/bin/asmcmd --privilege sysdba ls -d $asmPath >/dev/null 2>&1 \
    && { v="OK" ; echo "OK" ; } \
    || { v="KO" ; echo "Not Exist" ; }


  if [ "$v" != "OK" ]
  then
    printf "%-75s : " "      - Creation of $asmPath"
        . oraenv <<< $ASM_INSTANCE >/dev/null
    $gridHome/bin/asmcmd --privilege sysdba mkdir $asmPath >$$.tmp 2>&1 \
      && { echo OK ; rm -f $$.tmp ; } \
      || { echo ERREUR ; cat $$.tmp ; rm -f $$.tmp ; die "Impossible to create $asmPath" ; }
  fi

  setEnvPrimaire > /dev/null


  GetArchConf=$(exec_sql "/ as sysdba" "select value FROM v\$parameter WHERE name ='log_archive_config';")

  echo
  echo "  - Modification of database parameters for DATAGUARD (if required)"
  echo "    ==============================================================="
  echo
  changeParam "LOG_ARCHIVE_DEST_1"                 "'LOCATION=USE_DB_RECOVERY_FILE_DEST VALID_FOR=(ALL_LOGFILES,ALL_ROLES) MAX_FAILURE=1 REOPEN=5 DB_UNIQUE_NAME=$primDbUniqueName ALTERNATE=LOG_ARCHIVE_DEST_10'"
  changeParam "LOG_ARCHIVE_DEST_10"                "'LOCATION=$(echo ${PDATA} | cut -d ',' -f1 | tr -d ' ') VALID_FOR=(ALL_LOGFILES,ALL_ROLES) DB_UNIQUE_NAME=$primDbUniqueName ALTERNATE=LOG_ARCHIVE_DEST_1'"
  changeParam "LOG_ARCHIVE_DEST_STATE_10"          "ALTERNATE"


  if [ -z "$GetArchConf" -o "$GetArchConf" = "nodg_config" ]
  then
    changeParam "LOG_ARCHIVE_CONFIG"                 "'DG_CONFIG=($primDbUniqueName,$stbyDbUniqueName)'"
  else

    if [ "$(echo $GetArchConf | grep $stbyDbUniqueName)" != "" ]
    then
      echo "     -  LOG_ARCHIVE_CONFIG :  The Standby database $stbyDbUniqueName already exist in the DG configuration "
    else
      changeParam "LOG_ARCHIVE_CONFIG"                 "'""${GetArchConf:0:$((${#str}-1))}",$stbyDbUniqueName")""""'"
    fi
  fi

  changeParam "log_archive_format"                 "'%t_%s_%r.dbf'"
  #changeParam "DB_WRITER_PROCESSES"                "4"
  changeParam "log_archive_max_processes"          "4"                           #ARVAL 4
  changeParam "STANDBY_FILE_MANAGEMENT"            "AUTO"
  changeParam "remote_login_passwordfile"          "'EXCLUSIVE'"
  changeParam "db_block_checking"                  "'MEDIUM'"                  #ARVAL FALSE
  changeParam "db_block_checksum"                  "'TYPICAL'"
  changeParam "db_lost_write_protect"              "'TYPICAL'"                 # ARVAL NONE
  changeParam "fast_start_mttr_target"             "300"                       # ARVAL 0
  #changeParam "log_buffer"                         "268435456"
  changeParam "\"_redo_transport_min_kbytes_sec\"" "100"

  printf "%-75s : " "    - Size of logs"
  tailleLogs=$(exec_sql "/ as sysdba" "select to_char(max(bytes)) from v\$log;")  \
    && echo $tailleLogs \
    || { echo "Error" ; echo "$tailleLogs" ; die "Error to get the logs size" ; }

  printf "%-75s : " "    - Last logs"
  lastLog=$(exec_sql "/ as sysdba" "select to_char(max(group#)) from v\$log;")  \
    && echo $lastLog \
    || { echo "Error" ; echo "$lastLog" ; die "Error to get the number of last log" ; }

  printf "%-75s : " "    - Number of Logs"
  nombreLogs=$(exec_sql "/ as sysdba" "select to_char(count(*)) from v\$log;")  \
    && echo $nombreLogs \
    || { echo "Error" ; echo "$nombreLogs" ; die "Error to get the number of logs" ; }

  printf "%-75s : " "    - Number of Standby Logs"
  nombreStandbyLogs=$(exec_sql "/ as sysdba" "select to_char(count(*)) from v\$standby_log;")  \
    && echo $nombreStandbyLogs \
    || { echo "Error" ; echo "$nombreStandbyLogs" ; die "Error to get the number of Standby logs" ; }

  printf "%-75s : " "    - Number of threads"
  nombreThreads=$(exec_sql "/ as sysdba" "select count(distinct thread#) from v\$log;")  \
    && echo $nombreThreads \
    || { echo "Error" ; echo "$nombreThreads" ; die "Error to get the number of threads" ; }

  if [ "$nombreStandbyLogs" = "0" ]
  then
    echo "    - Creation of STANDBY LOGS"
    exec_sql "/ as sysdba" "
select 'ALTER DATABASE ADD STANDBY LOGFILE THREAD ' ||
       thread# ||
       ' GROUP ' || to_char($lastLog + rownum + 1)  ||
       ' (''$(echo ${PDATA} | cut -d ',' -f1 | tr -d ' ')'') SIZE $tailleLogs'
from (          select thread# ,group#      from v\$log
      union all select thread# ,max(group#) from v\$log group by thread#
     ) ;
   " | while read line
    do
      exec_sql "/ as sysdba" "$line;" "        --> $line"  || break
    done || die "Erreur de creation de standby log"
  elif [ $nombreStandbyLogs -eq $(($nombreLogs+$nombreThreads)) -a $nombreStandbyLogs -ne 0 ]
  then
    echo "    - Standby logs correct "
  else
    die "The number of standby logs is not correct, Correct it before re-execute"
  fi

  echo
  echo "  - Generation of necessary TNS aliases"
  echo "    ===================================="
  echo
  tnsAliasesForDG "$primDbUniqueName" "$hostPrimaire" "$portPrimaire" "$servicePrimaire" "$domainePrimaire" \
                  "$stbyDbUniqueName" "$hostStandBy"  "$portStandBy"  "$serviceStandBy"  "$domaineStandBy"

  echo
  echo "  - Copy the Alias TNS to the other(s) Node(s)"
  echo "    ===================================="
  echo

#######
#. oraenv <<< $ASM_INSTANCE >/dev/null
#ListDGHosts=$(olsnodes)
# ListDGHosts=$(srvctl status database -db $primDbUniqueName | awk '{print $7}')
ListDGHosts=$(srvctl config database -db $primDbUniqueName | grep 'Configured nodes:' | cut -d ':' -f2 | sed 's/^ *//g' | tr "," "\n")
setEnvPrimaire >/dev/null
########

## CBI - 20221219 - Ecrase la configuration du TNS sur les noeuds : LISTENER_IPLOCAL pointe sur le noeud 1
  for host in $ListDGHosts;
  do
    if [ "$host" != ${HOSTNAME%%.*} ]
    then

      echo "      ============================================="
      echo "    - Updating TNS aliases on $host (re-generation)"
      echo "      ============================================="
      echo

      ssh -q oracle@${host} -o StrictHostKeyChecking=no /bin/bash <<EOF
export primDbName=$primDbName
$(typeset -f setEnvPrimaire)
$(typeset -f addToTns)
$(typeset -f tnsAliasesForDG)
setEnvPrimaire >/dev/null
# env | grep ORA
# env | grep TNS
echo "      - Remote generation for : $primDbUniqueName & $stbyDbUniqueName"
tnsAliasesForDG "$primDbUniqueName" "$hostPrimaire" "$portPrimaire" "$servicePrimaire" "$domainePrimaire" \
                "$stbyDbUniqueName" "$hostStandBy"  "$portStandBy"  "$serviceStandBy"  "$domaineStandBy" > /dev/null
EOF

    fi
  done

  echo
  echo "  - Extract DATABASE services (SRVCTL)"
  echo "    ===================================="
  echo
  extractStandbyDGService

  echo
  echo "  - Extract INIT parameters from SPFILE"
  echo "    ===================================="
  echo
  extractStandbyInitParameters

################################################

#  echo
#  echo "  - Adding DATAGUARD Services "
 # echo "    ============================"
 # echo
 # addDGService ${primDbName}_dg    PRIMARY          Y
#  addDGService ${primDbName}_dg_ro PHYSICAL_STANDBY N

################################################################

#
#  TODO : Traitement des cas où les numéros de noeuds diffèrent
#
if false
then
  if [ $(echo $scanOppose | cut -d ':' -f1 | cut -d '.' -f1 | sed 's/-scan//gi' | rev | cut -c1) -gt 3 ]
  then
    targetNode1="$(echo $scanOppose | cut -d ':' -f1 | cut -d '.' -f1 | sed 's/-scan//gi')db03"
    targetNode2="$(echo $scanOppose | cut -d ':' -f1 | cut -d '.' -f1 | sed 's/-scan//gi')db04"
  else
    targetNode1="$(echo $scanOppose | cut -d ':' -f1 | cut -d '.' -f1 | sed 's/-scan//gi')db01"
    targetNode2="$(echo $scanOppose | cut -d ':' -f1 | cut -d '.' -f1 | sed 's/-scan//gi')db02"
  fi
else
    targetNode1="$(echo $scanOppose | cut -d ':' -f1 | cut -d '.' -f1 | sed 's/-scan//gi')1"
    targetNode2="$(echo $scanOppose | cut -d ':' -f1 | cut -d '.' -f1 | sed 's/-scan//gi')2"
fi
  echo
  echo "  - Attempt to copy Files on target nodes"
  echo "    ====================================================="
  echo
  echo "    If this step fails, you should copy these files manually"
  echo
  
  ERR_COPY=NO
  for f in /tmp/${primDbUniqueName}_*
  do
    printf "%-75s : " "    - Copy of $(basename $f) to $targetNode1"
    scp -o StrictHostKeyChecking=no -q $f ${dbServerOppose}:/tmp >/dev/null 2>&1                         \
      && { echo "OK" ; }                                          \
      || { echo "Copy this file manually to /tmp@$targetNode1" ; ERR_COPY=YES ; }

  # printf "%-75s : " "    - Copy of $(basename $f) to $targetNode2"
    # scp -q $f ${targetNode2}:/tmp >/dev/null 2>&1                         \
      # && { echo "OK" ; }                                          \
      # || echo "TO Copy this file manually /tmp@$targetNode2"
  done
}

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#
#     Generation des commandes srvctl permettant de recréer les services
#  BDD à jouer sur la cible
#
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
extractStandbyDGService()
{
  if [ -f "/tmp/${primDbUniqueName}_database_services.sh" ]
  then
    rm -f "/tmp/${primDbUniqueName}_database_services.sh"
  fi

  sourceInstances=$(srvctl config database -d $primDbUniqueName | grep 'Database instances:' | sed 's/ //g' | cut -d ':' -f2)
  sourceInstance1=$(echo $sourceInstances | cut -d ',' -f1)
  sourceInstance2=$(echo $sourceInstances | cut -d ',' -f2)

  if [ "${stbyDbUniqueName}" != "" ]; then
    targetDbSid=$(echo $stbyDbUniqueName | rev | cut -c4- | rev)
  else
    targetDbSid=${dbName}
  fi

  # if [ "$(echo $scanOppose | cut -d ':' -f1 | cut -d '.' -f1 | sed 's/-scan//gi' | cut -c1-4)" = "occt" ]; then
#
#  TODO : Traitement des cas où les numéros de noeuds diffèrent
#
if false
then
    if [ $(echo $scanOppose | cut -d ':' -f1 | cut -d '.' -f1 | sed 's/-scan//gi' | rev | cut -c1) -gt 3 ]
    then
      targetInstance1="${targetDbSid}3"
      targetInstance2="${targetDbSid}4"
    else
      targetInstance1="${targetDbSid}1"
      targetInstance2="${targetDbSid}2"
    fi
  # else
    # targetInstance1="${targetDbSid}1"
    # targetInstance2="${targetDbSid}2"
  # fi
fi

  echo ". /home/oracle/${stbyDbName}.env" | tee /tmp/${primDbUniqueName}_database_services.sh  >/dev/null 2>&1
  printf "%-75s : " "    - Extract SRVCTL database services"

  # (srvctl config service -d ${primDbUniqueName} && echo '') | sed -e 's;: ;:;' | awk '
# /^Service name:/                  {s_name=substr($0,index($0,":")+1) }
# /^Service role:/                  {s_role=substr($0,index($0,":")+1) }
# /^Pluggable database name:/       {s_pdb=substr($0,index($0,":")+1) }
# /^Preferred instances:/           {s_preferred=substr($0,index($0,":")+1) }
# /^Available instances:/           {s_available=substr($0,index($0,":")+1) }
# /^TAF failover retries:/          {s_failoverretry=substr($0,index($0,":")+1) }
# /^TAF failover delay:/            {s_failoverdelay=substr($0,index($0,":")+1) }
# /^Failover type:/                 {s_failovertype=substr($0,index($0,":")+1) }
# /^Failover method:/               {s_failovermethod=substr($0,index($0,":")+1) }
# /^Management policy:/             {s_policy=substr($0,index($0,":")+1) }
# /^ *$/ {
  # cmd=sprintf("srvctl remove service -d $ORACLE_UNQNAME -service %s",s_name) ;
  # cmd=sprintf("%s\nsrvctl add service -d $ORACLE_UNQNAME -service %s",cmd,s_name) ;
  # if ( s_preferred != "" )        { cmd=sprintf("%s -preferred $(srvctl config database -db ${ORACLE_UNQNAME} | grep \"Database instances:\" | sed -e \"s;: ;:;\" | cut -d \":\" -f2)",cmd,s_preferred) }
  # if ( s_available != "" )        { cmd=sprintf("%s -available %s",cmd,s_available) }
  # if ( s_role != "" )             { cmd=sprintf("%s -role %s",cmd,s_role) }
  # if ( s_pdb != "" )              { cmd=sprintf("%s -pdb %s",cmd,s_pdb) }
  # if ( s_failoverretry != "" )    { cmd=sprintf("%s -failoverretry %s",cmd,s_failoverretry) }
  # if ( s_failoverdelay != "" )    { cmd=sprintf("%s -failoverdelay %s",cmd,s_failoverdelay) }
  # if ( s_failovertype != "" )     { cmd=sprintf("%s -failovertype %s",cmd,s_failovertype) }
  # if ( s_failovermethod != "" )   { cmd=sprintf("%s -failovermethod %s",cmd,s_failovermethod) }
  # if ( s_policy != "" )           { cmd=sprintf("%s -policy %s",cmd,s_policy) }
  # print cmd
# }' | tee -a /tmp/${primDbUniqueName}_database_services.sh >/dev/null 2>&1  \
          # && echo "OK" \
          # || die "Fail to extract SRVCTL services"

  (srvctl config service -d ${primDbUniqueName} && echo '') | sed -e 's;: ;:;' | awk '
/^Service name:/                  {s_name=substr($0,index($0,":")+1) }
/^Service role:/                  {s_role=substr($0,index($0,":")+1) }
/^Pluggable database name:/       {s_pdb=substr($0,index($0,":")+1) }
/^Preferred instances:/           {s_preferred=substr($0,index($0,":")+1) }
/^Available instances:/           {s_available=substr($0,index($0,":")+1) }
/^TAF failover retries:/          {s_failoverretry=substr($0,index($0,":")+1) }
/^TAF failover delay:/            {s_failoverdelay=substr($0,index($0,":")+1) }
/^Failover type:/                 {s_failovertype=substr($0,index($0,":")+1) }
/^Failover method:/               {s_failovermethod=substr($0,index($0,":")+1) }
/^Management policy:/             {s_policy=substr($0,index($0,":")+1) }
/^ *$/ {
  cmd=sprintf("srvctl remove service -d $ORACLE_UNQNAME -service %s 2> /dev/null",s_name) ;
  cmd=sprintf("%s\nsrvctl add service -d $ORACLE_UNQNAME -service %s",cmd,s_name) ;
  if ( s_preferred != "" )        { cmd=sprintf("%s -preferred %s",cmd,s_preferred) }
  if ( s_available != "" )        { cmd=sprintf("%s -available %s",cmd,s_available) }
  if ( s_role != "" )             { cmd=sprintf("%s -role %s",cmd,s_role) }
  if ( s_pdb != "" )              { cmd=sprintf("%s -pdb %s",cmd,s_pdb) }
  if ( s_failoverretry != "" )    { cmd=sprintf("%s -failoverretry %s",cmd,s_failoverretry) }
  if ( s_failoverdelay != "" )    { cmd=sprintf("%s -failoverdelay %s",cmd,s_failoverdelay) }
  if ( s_failovertype != "" )     { cmd=sprintf("%s -failovertype %s",cmd,s_failovertype) }
  if ( s_failovermethod != "" )   { cmd=sprintf("%s -failovermethod %s",cmd,s_failovermethod) }
  if ( s_policy != "" )           { cmd=sprintf("%s -policy %s",cmd,s_policy) }
  print cmd
}' | sed "s/$sourceInstance1/$targetInstance1/gi" | sed "s/$sourceInstance2/$targetInstance2/gi" | tee -a /tmp/${primDbUniqueName}_database_services.sh >/dev/null 2>&1  \
          && echo "OK" \
          || die "Fail to extract SRVCTL services"

  echo 'srvctl status service -d $ORACLE_UNQNAME' | tee -a /tmp/${primDbUniqueName}_database_services.sh  >/dev/null 2>&1

  if [ $(cat "/tmp/${primDbUniqueName}_database_services.sh" | egrep 'srvctl add service' | wc -l | tr -d ' ') -gt 0 ]
  then
    echo "    - The following database services have been extracted"
    echo ""
    cat /tmp/${primDbUniqueName}_database_services.sh | egrep 'srvctl add service' | sed 's/^.* -service //g' | cut -d ' ' -f1 | sed 's/^/        /g'
  fi
}

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#
#     Generation des commandes srvctl permettant de recréer les services
#  BDD à jouer sur la cible
#
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
extractStandbyInitParameters()
{
  if [ -f "/tmp/${primDbUniqueName}_init_parameters.sh" ]
  then
    rm -f "/tmp/${primDbUniqueName}_init_parameters.sh"
  fi

  echo ". /home/oracle/${stbyDbName}.env" | tee /tmp/${primDbUniqueName}_init_parameters.sh  >/dev/null 2>&1
  echo "sqlplus \"/ as sysdba\" <<SQL" | tee -a /tmp/${primDbUniqueName}_init_parameters.sh  >/dev/null 2>&1
  echo "CREATE PFILE='/tmp/${stbyDbUniqueName}_init.ora' FROM SPFILE;" | tee -a /tmp/${primDbUniqueName}_init_parameters.sh  >/dev/null 2>&1

  printf "%-75s : " "    - Extract INIT parameters from SPFILE"

  exec_sql "/ as sysdba" "
SET HEAD OFF FEED OFF;
SET PAGES 0 LINES 300;
SELECT
distinct
--spp.sid || '.' || p.name||'='|| case when p.add_quote='Y' then '''' else '' end || spp.value
'alter system set \"' ||
p.name || '\"=' || case when p.add_quote='Y' then '''' else '' end ||
value || case when p.add_quote='Y' then '''' else '' end ||
--' sid=''' || spp.sid || ''' scope=spfile;'
' sid=''*'' scope=spfile;'
FROM
gv\$spparameter spp
join (select name
,case
when type in (2) then 'Y'
else 'N'
end add_quote
from v\$parameter) p on ( spp.name = p.name )
WHERE
spp.isspecified = 'TRUE'
and LOWER(spp.name) not in ('local_listener','remote_listener','listener_networks'
,'audit_file_dest','background_dump_dest'
,'cluster_interconnects','control_files','core_dump_dest' ,'db_name'
,'db_unique_name','dispatchers'
,'instance_name','service_names','spfile','user_dump_dest'
,'audit_file_dest','background_dump_dest','diaqnostic_dest'
,'thread','undo_tablespace','instance_number'
,'instance_mode','db_recovery_file_dest','compatible','cluster_database'
,'diagnostic_dest','standby_file_management','archive_lag_target'
,'db_block_size','dg_broker_start','fal_server'
,'db_file_name_convert','log_file_name_convert'
,'db_cache_size'
)
and LOWER(spp.name) not like 'log_archive_config%'
and LOWER(spp.name) not like 'log_archive_dest%'
and LOWER(spp.name) not like 'db_create_file_dest%'
and LOWER(spp.name) not like 'db_create_online_log_dest%'
and LOWER(spp.name) not like 'dg_broker_config_%'
UNION
SELECT distinct 'alter system set \"' || name || '\"=' || LISTAGG(''''||value||'''', ',') WITHIN GROUP (ORDER BY value) || ' sid=''*'' scope=spfile;'
FROM v\$spparameter WHERE LOWER(name) = 'listener_networks' AND LOWER(value) LIKE '%cman%' GROUP BY name
UNION
SELECT 'alter system set \"local_listener\"=''listener_iplocal'' sid=''*'' scope=spfile;' FROM DUAL
ORDER BY 1;" | tee -a /tmp/${primDbUniqueName}_init_parameters.sh >/dev/null 2>&1  \
          && echo "OK" \
          || die "Fail to extract INIT parameters"


  if [ "${stbyDbUniqueName}" != "" ]; then
    targetDbSid=$(echo $stbyDbUniqueName | rev | cut -c4- | rev)
  else
    targetDbSid=${dbName}
  fi

#
#  TODO : Traitement des cas où les numéros de noeuds diffèrent
#
if false
then
  if [ $(echo $scanOppose | cut -d ':' -f1 | cut -d '.' -f1 | sed 's/-scan//gi' | rev | cut -c1) -gt 3 ]
  then
    targetInstance1="${targetDbSid}3"
    targetInstance2="${targetDbSid}4"
  else
    targetInstance1="${targetDbSid}1"
    targetInstance2="${targetDbSid}2"
  fi
fi

  echo "alter system set \"thread\"=1 sid='${targetInstance1}' scope=spfile;" | tee -a /tmp/${primDbUniqueName}_init_parameters.sh  >/dev/null 2>&1
  echo "alter system set \"thread\"=2 sid='${targetInstance2}' scope=spfile;" | tee -a /tmp/${primDbUniqueName}_init_parameters.sh  >/dev/null 2>&1

  echo "SQL" | tee -a /tmp/${primDbUniqueName}_init_parameters.sh  >/dev/null 2>&1

  echo 'srvctl stop database -d $ORACLE_UNQNAME' | tee -a /tmp/${primDbUniqueName}_init_parameters.sh  >/dev/null 2>&1
  echo 'srvctl start database -d $ORACLE_UNQNAME' | tee -a /tmp/${primDbUniqueName}_init_parameters.sh  >/dev/null 2>&1

  ## Reboot instance par instance
  # echo "for INSTANCE in \$(srvctl config database -db \$ORACLE_UNQNAME | grep 'Database instances:' | sed 's/: /:/g' | cut -d ':' -f2 | tr ',' '\n')" | tee -a /tmp/${primDbUniqueName}_init_parameters.sh  >/dev/null 2>&1
  # echo 'do' | tee -a /tmp/${primDbUniqueName}_init_parameters.sh  >/dev/null 2>&1
  # echo 'srvctl stop instance -d $ORACLE_UNQNAME -i $INSTANCE' | tee -a /tmp/${primDbUniqueName}_init_parameters.sh  >/dev/null 2>&1
  # echo 'srvctl start instance -d $ORACLE_UNQNAME -i $INSTANCE' | tee -a /tmp/${primDbUniqueName}_init_parameters.sh  >/dev/null 2>&1
  # echo 'if [ $? -ne 0 ]; then exit; fi' | tee -a /tmp/${primDbUniqueName}_init_parameters.sh  >/dev/null 2>&1
  # echo 'done' | tee -a /tmp/${primDbUniqueName}_init_parameters.sh  >/dev/null 2>&1

  if [ $(cat "/tmp/${primDbUniqueName}_init_parameters.sh" | egrep 'alter system set' | wc -l | tr -d ' ') -gt 0 ]
  then
    echo "    - The following INIT parameters have been extracted"
    echo ""
    cat /tmp/${primDbUniqueName}_init_parameters.sh | egrep 'alter system set' | sed 's/^.*alter system set //g' | sed 's/ sid=.*//g' | sed 's/^/        /g'
  fi

}

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#
#     Ajout des services _dg et _dg_ro sur la base de données (a faire sur
#  les deux bases de donnees
#
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
addDGService()
{
  service=$1
  role=$2
  start=$3
  echo "    - $service (role=$role start=$start)"
  printf "%-75s : " "      - $service Exist"
  if srvctl config service -s $service -d $ORACLE_UNQNAME >/dev/null
  then
    echo "Exist"
    exec_srvctl -silent "stop service -d $ORACLE_UNQNAME -s $service" \
                "        - Stop the $service" \
                "OK" "Service Stopped"
    exec_srvctl "remove service -d $ORACLE_UNQNAME -s $service" \
                "        - Remove the $service" \
                "OK" "Error" "Impossible to remove the $service"
  else
    echo "Not Exist"
  fi
  tmp=$(exec_sql "/ as sysdba" "select open_mode from v\$database;")
  if [ "$tmp" = "READ WRITE" ]
  then
    exec_sql "/ as sysdba" "
      delete from cdb_service\$ where name = '$service' ;
      commit ;
      " "      - Remove of service de cdb_service\$" || die "Impossible to delete cdb_service\$"
  fi
    exec_srvctl "add service -d $ORACLE_UNQNAME -s $service -r ${primDbName}$hostnum,${primDbName}$hostnumN -l $role -q TRUE -e SESSION -m BASIC -w 10 -z 150" \
                "      - Add of $service" \
                "OK" "Error" "Impossible to add $service"
    exec_srvctl "start service -d $ORACLE_UNQNAME -s $service" \
                "      - Start the $service" \
                "OK" "Error" "Impossible to start the $service"
  if [ "$start" != "Y" ]
  then
    exec_srvctl "stop service -d $ORACLE_UNQNAME -s $service" \
                "          - Stop the $service (start=$start)" \
                "OK" "Error" "Impossible to stop the $service"
  fi
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#     Cree l'ensemble des alias necessaires au fonctionnement du DG
#  on met à jour le tnsnames.ora associé à la base de données.
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
tnsAliasesForDG()
{
  tnsFile=$TNS_ADMIN/tnsnames.ora

  tnsBackup=$tnsFile.$(date +%Y%m%d)

  # echo $tnsFile
  # echo $tnsBackup

  printf "%-75s : " "    - $(basename $tnsFile) Exist"
  [ -f $tnsFile ] && echo "OK" || { echo "ERROR" ; die "$tnsFile not found" ; }
  printf "%-75s : " "    - $(basename $tnsBackup) Exist"
  if [ -f $tnsBackup ]
  then
    echo "OK"
  else
    echo "Non Trouve"
    printf "%-75s : " "      - backup in $(basename $tnsBackup)"
    cp -p $tnsFile $tnsBackup && echo "OK" || die "Impossible to backup $tnsFile"
  fi

  # echo
  case $1 in
    *EXA)
      dbTmp=$(echo $1 | sed -e "s;EXA$;;") ;; # ARVAL primary DB unique name ends whith EXA
    *)
      dbTmp=$(echo $1 | cut -f1 -d"_") ;;
  esac
  [ "$5" = "" ] && domaine1="" || domaine1=".$5"
  [ "${10}" = "" ] && domaine2="" || domaine2=".${10}"

  for db in $1 $6
  do
    echo
    echo "      ============================="
    echo "    - Aliases for $db"
    echo "      ============================="
    echo
    dbUniqueName=$1

    if [ "$(echo $dbName)" != "" ]
    then
      dbName=$dbName
    else
      dbName=$(echo $dbUniqueName | cut -f1 -d"_")
    fi

    host=$2
    port=$3
    service=$4
    [ "$5" = "" ] && domaine="" || domaine=".$5"
    shift 5
    addToTns $tnsFile "$dbUniqueName" "\
(DESCRIPTION =
   (ADDRESS = (PROTOCOL = TCP) (HOST = $host) (PORT = $port))
   (CONNECT_DATA =
     (SERVER = DEDICATED)
     (SERVICE_NAME = $service)
     (FAILOVER_MODE =
        (TYPE = select)
        (METHOD = basic)
     )
     (UR=A)
   )
 )"

    printf "%-75s : " "        - Testing ALIAS $dbUniqueName" 
    tnsping $dbUniqueName > /dev/null 2>&1 && echo OK || { echo ERROR ; die "TNS Alias $dbUniqueName is not correct" ; }

    sed -i "/^ *$/d" $tnsFile 
###############################################################################
#  NBNode=$(exec_sql "/ as sysdba" "select count(*) from gv\$instance;")

# re='^[0-9]+$'
#if ! [[ $NBNode =~ $re ]] ; then
#   NBNode=2
#fi
#         for i in `seq 1 1 $NBNode`
#   do
#     inst=${dbName}$i
#     a=${dbUniqueName}$i
#     addToTns $tnsFile "${a}" "\
#(DESCRIPTION =
#   (ADDRESS = (PROTOCOL=TCP) (HOST = $host) (PORT = $port))
#   (CONNECT_DATA =
#     (SERVICE_NAME = $service)
#     (INSTANCE_NAME=$inst)
#     (SERVER=DEDICATED)
#     (UR=A)
#   )
#)"
#     addToTns $tnsFile "${a}_DGMGRL" "\
#(DESCRIPTION =
#   (ADDRESS = (PROTOCOL=TCP) (HOST = $host) (PORT = $port))
#   (CONNECT_DATA =
#     (SERVICE_NAME = ${dbUniqueName}_DGMGRL${domaine})
#     (INSTANCE_NAME=$inst)
#     (SERVER=DEDICATED)
#     (UR=A)
#   )
#)"
#   done
 done
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#     Cree l'ensemble des alias necessaires au fonctionnement de CMAN
#  on met à jour le tnsnames.ora associé à la base de données.
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
tnsAliasesForCMAN()
{
  nodeList=$(srvctl config database -db ${stbyDbUniqueName} | grep -i 'Configured nodes:' | tr -d ' ' | cut -d ':' -f2)

  for node in $(echo ${nodeList} | tr "," "\n")
  do

    printf "%-75s : " "    - add CMAN aliases in tnsnames.ora on $node"

    ssh -q oracle@${node} -o StrictHostKeyChecking=no /bin/bash <<CMD && echo "OK" || die "Impossible to backup $tnsFile"
. /home/oracle/${dbName}.env
sed -i -e "/^CMAN_/,/^ *\$/d" -e "/^LISTENER_IPLOCAL/,/^ *\$/d" -e "/# CMAN Definitions/,/^ *\$/d" -e "/# LISTENER_IPLOCAL Definitions/,/^ *\$/d" \$TNS_ADMIN/tnsnames.ora
echo "
# LISTENER_IPLOCAL Definitions

LISTENER_IPLOCAL=(DESCRIPTION=(ADDRESS_LIST=(ADDRESS=(PROTOCOL = TCP)(HOST = \$(srvctl config vip -node \$(hostname) | grep -i 'VIP Name:' | tr -d ' ' | cut -d ':' -f2))(PORT = 1521))))

# CMAN Definitions

CMAN_DEV=(DESCRIPTION=(ADDRESS=(PROTOCOL = TCP)(HOST = FRDRPAPP99004-1)(PORT = 1521))(ADDRESS = (PROTOCOL = TCP)(HOST = FRDRPAPP99004-2)(PORT = 1521)))

CMAN_NPROD=(DESCRIPTION=(ADDRESS=(PROTOCOL = TCP)(HOST = FRDRPSRV8890)(PORT = 1521))(ADDRESS = (PROTOCOL = TCP)(HOST = FRDRPSRV8891)(PORT = 1521)))

CMAN_DRP=(DESCRIPTION=(ADDRESS=(PROTOCOL = TCP)(HOST = FRDRPSRV8906)(PORT = 1521))(ADDRESS=(PROTOCOL = TCP)(HOST = FRDRPSRV8907)(PORT = 1521)))

CMAN_PRD=(DESCRIPTION=(ADDRESS=(PROTOCOL = TCP)(HOST = FRPRDSRV8892)(PORT = 1521))(ADDRESS=(PROTOCOL = TCP)(HOST = FRPRDSRV8893)(PORT = 1521)))
" >> \$TNS_ADMIN/tnsnames.ora
sed -i -n '1{/^\$/p};{/./,/^\$/p}' \$TNS_ADMIN/tnsnames.ora
CMD
  done

  # tnsFile=$TNS_ADMIN/tnsnames.ora

  # nodeVip=$(srvctl config vip -node $(hostname) | grep -i 'VIP Name:' | tr -d ' ' | cut -d ':' -f2)

  # echo "
# LISTENER_IPLOCAL=(DESCRIPTION=(ADDRESS_LIST=(ADDRESS=(PROTOCOL = TCP)(HOST = ${nodeVip})(PORT = 1521))))

# CMAN Definitions
# CMAN_DEV=(DESCRIPTION=(ADDRESS=(PROTOCOL = TCP)(HOST = FRDRPAPP99004-1)(PORT = 1521))(ADDRESS = (PROTOCOL = TCP)(HOST = FRDRPAPP99004-2)(PORT = 1521)))
# CMAN_NPROD=(DESCRIPTION=(ADDRESS=(PROTOCOL = TCP)(HOST = FRDRPSRV8890)(PORT = 1521))(ADDRESS = (PROTOCOL = TCP)(HOST = FRDRPSRV8891)(PORT = 1521)))
# CMAN_DRP=(DESCRIPTION=(ADDRESS=(PROTOCOL = TCP)(HOST = FRDRPSRV8906)(PORT = 1521))(ADDRESS=(PROTOCOL = TCP)(HOST = FRDRPSRV8907)(PORT = 1521)))
# " | tee -a $tnsFile

  # sed -i -n '1{/^$/p};{/./,/^$/p}' $tnsFile
}

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#      Ajoute ou remplace un alias dans le tnsnames.ora
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
addToTns()
{
  local TNS_FILE=$1
  local alias=$2
  local tns=$3
  printf "%-75s : " "      - Add of $alias"
  if grep "^[ \t]*$alias[ \t]*=" $TNS_FILE >/dev/null
  then
    echo "Exist to be replaced"
    printf "%-75s : " "        - Remove Alias"
    cp -p $TNS_FILE $TNS_FILE.sv
    cat $TNS_FILE.sv | awk '
    BEGIN { toKeep="Y" }
    {
      if ( match(toupper($0) , toupper("^[ \t]*'$alias'[ \t]*=") ) )
      {
        parentheseTrouvee=0
        egaleTrouve=0
        toKeep="N"
        while ( egaleTrouve == 0 )
        {
          for ( i = 1 ; i<= length($0) && substr($0,i,1) != "=" ; i ++ ) ;
          if ( substr($0,i,1) == "=" ) egaleTrouve = 1 ; else {getline}
        }
        while ( parentheseTrouvee == 0 )
        {
          for (  ; i<= length($0) && substr($0,i,1) != "(" ; i ++ ) ;
          if ( substr($0,i,1) == "(" ) { parentheseTrouvee = 1 ;} else {getline ; i = 1 }
        }
        parLevel=1
        fini=0
        while ( fini == 0  )
        {
          for (  ; i<= length($0) ; i ++ )
          {
            c=substr($0,i,1)
            if ( c == "(" ) parLevel ++
            if ( c == ")" ) {parLevel -- ; if ( parLevel==1 ) {fini=1;toKeep="Y";next;} ;}
          }
          if ( fini == 0 ) { getline  }
          i = 1
        }
      }
      if ( toKeep=="Y" ) {print}
    }
    END { printf("\n") }' > $TNS_FILE 2>$$.tmp \
      && { echo "OK" ; rm -f $$.tmp $TNS_FILE.sv ; } \
      || { echo "ERROR" ; cat $$.tmp ; rm -f $$.tmp ; cp -p $TNS_FILE.sv $TNS_FILE ; die "Error in update TNS (remove $alias)" ; }
  else
    echo "New Alias"
  fi
  cp -p $TNS_FILE $TNS_FILE.sv
  printf "%-75s : " "        - Add alias"
  echo "
$alias = $tns
" >> $TNS_FILE 2>$$.tmp \
    && { echo "OK" ; rm -f $$.tmp $TNS_FILE.sv ; } \
    || { echo "ERROR" ; cat $$.tmp ; rm -f $$.tmp ; cp -p $TNS_FILE.sv $TNS_FILE ; die "Error in update TNS (add $alias)" ; }
  echo
}

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#    Change un parametre si la valeur voulue n'est pas positionnée
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
changeParam()
{
  local param=$1
  local new_val=$2
  old_val=$(exec_sql "/ as sysdba" "select value from v\$parameter where name=lower('$param');")
  echo    "    - Change of $param --->"
  echo    "      - Current Value : $old_val"
  echo    "      - New Value : $new_val"
  o=$(echo $old_val | sed -e "s;^'*;;g" -e "s;'*$;;g")
  n=$(echo $new_val | sed -e "s;^'*;;g" -e "s;'*$;;g")
  if [ "$o" != "$n" ]
  then
    exec_sql "/ as sysdba" "alter system set $param=$new_val scope=both sid='*';" "        - Changed Value"
  else
    echo "        - Correct Value, Not Changed"
  fi
  echo
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#   Verifie que le resultat d'un ordre SQL correspond a ce qui est attendu
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
checkDBParam()
{
  local lib=$1
  local sql=$2
  local res=$3
  printf "%-75s : " "    - $lib"
  v=$(exec_sql "/ as sysdba" "$sql")
  [ "$v" = "$res" ] && echo "OK" || { echo "ERROR" ; die "Verification of parameter values error" ; }
}

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

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#
#      Suppression des repertoires de la base de donnes Stand-By
#  S'il y a un SPFILE on le sauvegarde et on le recree. S'il
#  n'y a pas de SPFILE, on essaie de trouver une ancienne sauvegarde
#
#     Si DELETEONLY n'est pas specifie, on recree les principaux
#  repertoires
#
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
cleanASMBeforeCopy()
{
  echo
  echo  "
  ======================================================================
       Remove of the database $laBase and set up the files all the files copied from the Primary (TDE and password)
       If the file is in the ASM , it will be backup and recreated in the same place
       If this step fails, you can re-executed

  ======================================================================
  "
  local laBase=$1
  [ "$2" = "FORCE" ] && rep=Y || read -p "      Are you sure you want to stop the database and remove all this files  y/[N] : " rep
  rep=${rep:N}

  if [ "${rep^^}" = "Y" ]
  then

    echo
    echo "       NOTE : (It is possible to get errors on this step, if it's happen"
    echo "              and all the others steps pass correctly there is no any problem, but if the execution stopped/Blocked "
    echo "              You should stop manually the database before re-execute)"

    echo
    saveSpfile=$LOG_DIR/init_${stbyDbUniqueName}_${DAT}.ora
    exec_sql "/ as sysdba" "
whenever sqlerror continue
startup nomount;
whenever sqlerror exit failure
create pfile='$saveSpfile' from spfile;" "    - Backup SPFILE" ; status=$?
    if [ $status -ne 0 ]
    then
      saveSpFile=""
      echo "      --> There is no SPFILE in ASM"
      echo "          search in the previous Backup"
      saveSpfile=$(ls -1t $LOG_DIR/init*.ora | tail -1)
      echo "        --> INIT.ORA (Backup) : $saveSpfile"
    else
      echo "      --> INIT.ORA   : $saveSpfile"
    fi
    [ ! -f $saveSpFile ] && die "Impossible to Backup the SPFILE"

    echo
    printf "%-75s : " "    - Location of spfile"
    spfileLoc=$(srvctl config database -d $ORACLE_UNQNAME | grep "Spfile:" | cut -f2 -d" ") \
      && { echo "OK" ; } \
      || { echo "Erreur" ; echo $spfileLoc ; die "Impossible to get the location path of the SPFILE" ; }
    echo "      --> SPFILE : $spfileLoc"

    echo
    printf "%-75s : " "    - Location du Password File"
    pwfileLoc=$(srvctl config database -d $ORACLE_UNQNAME | grep "Password file" | sed -e "s;^.*: *;;") \
      && { echo "OK" ; } \
      || { echo "Erreur" ; echo $pwfileLoc ; die "Impossible to get the location path of the Password File" ; }
    echo "      --> PWFILE : $pwfileLoc"
    if [ ! -f /tmp/${primDbUniqueName}_passwd.ora ]
    then
      exec_asmcmd "cp $pwfileLoc /tmp/${primDbUniqueName}_passwd.ora" \
                  "    - Backup password file" "OK" "Error" "Impossible to copy and backup the password file"
    fi

    echo

    printf "%-75s : " "    - Stop database $stbyDbUniqueName"
    srvctl stop  database -d $stbyDbUniqueName -o abort >/dev/null 2>&1
    [ "$(ps -ef | grep smon_$ORACLE_SID | grep -v grep)" = "" ]  \
      && echo "Stopped" \
      || die "Impossible to Stop the database $laBase"

    sleep 10

    . oraenv <<< $ASM_INSTANCE >/dev/null || die "Impossible to go under ASM"

    echo
    removeASMDir "$SDATA/$stbyDbUniqueName"
    removeASMDir "$SRECO/$stbyDbUniqueName"
	removeASMDir "$SDATA/$primDbUniqueName"
	removeASMDir "$SRECO/$primDbUniqueName"
    echo
    if [ "$2" != "DELETEONLY" ]
    then
      createASMDir $SDATA/$stbyDbUniqueName
      createASMDir $SDATA/$stbyDbUniqueName/PARAMETERFILE
      createASMDir $SDATA/$stbyDbUniqueName/PASSWORD
      createASMDir $SDATA/$stbyDbUniqueName/DG
      createASMDir $SDATA/$stbyDbUniqueName/ONLINELOG
      createASMDir $SRECO/$stbyDbUniqueName
      createASMDir $SRECO/$stbyDbUniqueName/ONLINELOG

#--dbuniquename ${stbyDbUniqueName}
      if [ -f /tmp/${primDbUniqueName}_passwd.ora ]
      then
       exec_asmcmd "pwcopy /tmp/${primDbUniqueName}_passwd.ora $SDATA/$stbyDbUniqueName/PASSWORD/passwd.ora" \
                   "    - Copy of password file" "OK" "Error" "impossible to Copy password file"
      fi
    fi


setEnvStandby

    exec_sql "/ as sysdba" "
whenever sqlerror continue
startup nomount pfile='$saveSpfile';
whenever sqlerror exit failure
create spfile='$SDATA/$stbyDbUniqueName/PARAMETERFILE/spfile.ora' from pfile='$saveSpfile' ;
shutdown abort; " \
             "    - Creation of SPFILE" || die "Impossible to recreate SPFILE"

    printf "%-75s : " "    - Modification of spfile in clusterware "
    srvctl modify database -d $stbyDbUniqueName -spfile $SDATA/$stbyDbUniqueName/PARAMETERFILE/spfile.ora \
      && echo "OK" || die "Error setting SPFILE"

    printf "%-75s : " "    - Modification of pwfile in clusterware "
    srvctl modify database -d $stbyDbUniqueName -pwfile $SDATA/$stbyDbUniqueName/PASSWORD/passwd.ora \
      && echo "OK" || die "Error setting Password file"

	if [ -f /tmp/${primDbUniqueName}_ewallet.p12 ]
    then
	  echo
      printf "%-75s : " "    - Copy of ewallet.p12"
      ## CBI - 20230602 - Le répertoire de wallet est différent en 19c
      if [ -d "/var/opt/oracle/dbaas_acfs/${primDbName}/wallet_root/tde/" ]; then
        cp /tmp/${primDbUniqueName}_ewallet.p12 /var/opt/oracle/dbaas_acfs/$primDbName/wallet_root/tde/ewallet.p12 \
         && { echo OK ; } \
         || die "Impossible to copy ewallet.p12"
      else
        cp /tmp/${primDbUniqueName}_ewallet.p12 /var/opt/oracle/dbaas_acfs/$primDbName/tde_wallet/ewallet.p12 \
         && { echo OK ; } \
         || die "Impossible to copy ewallet.p12"
      fi
    fi

    if [ -f /tmp/${primDbUniqueName}_cwallet.sso ]
    then
      printf "%-75s : " "    - Copy of cwallet.sso"
      ## CBI - 20230602 - Le répertoire de wallet est différent en 19c
      if [ -d "/var/opt/oracle/dbaas_acfs/${primDbName}/wallet_root/tde/" ]; then
        cp /tmp/${primDbUniqueName}_cwallet.sso /var/opt/oracle/dbaas_acfs/$primDbName/wallet_root/tde/cwallet.sso \
         && { echo OK ; } \
         || die "Impossible to copy cwallet.sso"
      else
        cp /tmp/${primDbUniqueName}_cwallet.sso /var/opt/oracle/dbaas_acfs/$primDbName/tde_wallet/cwallet.sso \
         && { echo OK ; } \
         || die "Impossible to copy cwallet.sso"
      fi
    fi
  else
    die "Abandonment of the procedure"
  fi
}
deleteStandBy()
{
  startRun "Remove the standby and dde configuration DG"
  cleanASMBeforeCopy $stbyDbUniqueName DELETEONLY
  endRun
}
showVars()
{
  echo
  echo "==============================================================="
  echo "    Runtime variables"
  echo "==============================================================="
  echo "  - LOCAL Scan       : $scanLocal"
  echo "    --> $hostLocal ($portLocal)"
  echo "  - Opposite SCAN    : $scanOppose"
  echo "    --> $hostOppose ($portOppose)"
  echo "  - Opposite DB Serv : $dbServerOppose"
  echo
  echo "  - PRIMARY Database : $primDbName ($primDbUniqueName)"
  echo "    primDbService (p): $primDbService"
  echo "    servicePrimaire  : $servicePrimaire"
  echo "    domainePrimaire  : $domainePrimaire"
  echo "    --> Host         : $hostPrimaire - $portPrimaire"
  echo "    --> Scan         : $scanPrimaire"
  echo "    --> Tns          : $tnsPrimaire"
  echo
  echo "  - STANDBY Database : $stbyDbName ($stbyDbUniqueName)"
  echo "    stbyDbService (p): $stbyDbService"
  echo "    serviceStandBy   : $serviceStandBy"
  echo "    domaineStandBy   : $domaineStandBy"
  echo "    --> Host         : $hostStandBy - $portStandBy"
  echo "    --> Scan         : $scanStandBy"
  echo "    --> Tns          : $tnsStandBy"
  echo "  - ASM_INSTANCE     : $ASM_INSTANCE"
  echo "  - TNS_ADMIN        : $TNS_ADMIN"
  echo "  - tnsTestConnect   : $tnsTestConnect"
  echo "  - Execution On     : $opePart"
  echo "  - Source diskgroups"
  echo "    --> PDATA        : $PDATA"
  echo "    --> PRECO        : $PRECO"
  echo "  - Target diskgroups"
  echo "    --> SDATA        : $SDATA"
  echo "    --> SRECO        : $SRECO"
  echo
  echo "==============================================================="
  echo
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#       Procedure principale qui va lancer la creation de la base
# stand-by ou la preparation de la primaire.
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
createDG()
{
  if [ "$step" = "" ]
  then
    startRun "Standby database creation"
  else
    startRun "Standby database creation restart at step: $step"
  fi

  if [ "$opePart" = "STANDBY" ] # Script execution on the stand-by machine (-m runOnStandby positionned) ------------------------------------------------
  then

    startStep "Verification and Preparation"

    echo "    - Verification of database source files, it should be on OMF"
    nonOMF=$(exec_sql "sys/${dbPassword}@$tnsTestConnect as sysdba" "
with
function isomf( name v\$dbfile.name%type) return char as
isomf boolean;
isasm boolean;
begin
dbms_backup_restore.isfilenameomf(name,isomf,isasm);
if isomf then return 'Y'; else return 'N'; end if;
end;
select to_char(count(*))
from v\$dbfile
where isomf(name)='N'
/
"
)
    if [ "$nonOMF" != "0" ]
    then
      echo
      echo "these files $nonOMF are non OMF"
      echo "Commands to transform these files to OMF (ONLINE)"
      echo
      echo "-- -----------------------------------------------------"
      echo
      echo "sqlplus / as sysdba <<%%"
      exec_sql "sys/${dbPassword}@$tnsTestConnect as sysdba" "
col a format a200 newline
with
function isomf( name v\$dbfile.name%type) return char as
isomf boolean;
isasm boolean;
begin
dbms_backup_restore.isfilenameomf(name,isomf,isasm);
if isomf then return 'Y'; else return 'N'; end if;
end;
select
   'alter session set container=' || p.name || ';' a
  ,'alter database move datafile ''' || f.name || ''' ;' a
from v\$dbfile f
join v\$pdbs p on (f.con_id=p.con_id)
where isomf(f.name)='N'
/
"
      echo "%%"
      echo
      echo "-- -----------------------------------------------------"

      echo
    else
      echo "    - All the files are in OMF"
    fi

    CHECKCDB=$(exec_sql "sys/${dbPassword}@$tnsTestConnect as sysdba" "SELECT CDB FROM V\$DATABASE;")

    if [ "$CHECKCDB" = "YES" ]
    then
        ## CBI - 20221022 - ADD "within group" clause following bugs with 12c in container database
        listePDB=$(exec_sql "sys/${dbPassword}@$tnsTestConnect as sysdba" "select listagg(name,',') within group (order by con_id) from v\$pdbs where name not like '%SEED%';")
        echo
        echo "    - Liste of PDB : $listePDB"
    fi

    echo
    if [ "$step" = "" ]
    then
      echo "    - We are on standby machine, The database should not be started from here"
    elif [ "$step" = "RECOVER" ]
    then
      echo "    - Re-execute the RECOVER (The database should be stared in PHYSICAL STANDBY mode"
    else
      die "Mode Re-execute UNKNOWN : $step"
    fi
    if [ "$(srvctl status database -d $stbyDbUniqueName | grep -i running | grep -vi "not running")" != "" ]
    then
      echo "      - The database is started ... "
      printf "%-75s : " "  - The database $laBase Role"
      if [ "$(ps -ef | grep "smon_${ORACLE_SID}" | grep -v grep | wc -l)" = "1" ]
      then
        dbRole=$(exec_sql "/ as sysdba" "select database_role from v\$database ;")
      else
        dbRole="NotStarted"
      fi
      echo "$dbRole"
      if [ "$dbRole" = "PHYSICAL STANDBY" -a "$step" = "" ]
      then
        echo "    --> Procedure continue"
        endStep
        finalisationDG
      elif [ "$dbRole" = "PRIMARY" -a "$step" = "" ]
      then
        echo "  - The database is PRIMARY"
      elif [ "$step" = "" ]
      then
        echo "    - Stop of database"
        srvctl stop  database -d $stbyDbUniqueName >/dev/null 2>&1
        echo "    - Trying the started ...."
        srvctl start database -d $stbyDbUniqueName >/dev/null 2>&1
      fi
    else
      echo "    - The database is OFFLINE, trying to start it...."
      srvctl start database -d $stbyDbUniqueName >/dev/null 2>&1
    fi
    laBase=$stbyDbUniqueName
  else
    laBase=$primDbUniqueName
  fi
  printf "%-75s : " "  - Role of database $laBase"
  if [ "$(ps -ef | grep "smon_${ORACLE_SID}" | grep -v grep | wc -l)" = "1" ]
  then
    dbRole=$(exec_sql "/ as sysdba" "select database_role from v\$database ;") || die "Error to get the database role"
  else
    dbRole="NotStarted"
  fi
  echo $dbRole

  if [ "$dbRole" = "PRIMARY" -a "$opePart" = "PRIMARY" ]  # Script execution on the primary machine (-m runOnStandby NOT positionned) ----------------------
  then
    preparePrimary

    if [ "$ERR_COPY" = "YES" ]
    then
      scpMessage="
    Before running commands on the standby machine, please
    
    copy manually the files below to $dbServerOppose"
    for f in /tmp/${primDbUniqueName}_*
    do
      scpMessage="$scpMessage
           - $f"
    done
    scpMessage="$scpMessage
      in the /tmp folder, then delete them from the current server
      
      (ssh-equivalence is not in place)
      "
    else

     scpMessage="
       All the needed files are in place on the
       Standby database and are copied to $dbServerOppose,
       no manual operation is required before running the script"
    fi
    echo "

=============================================================================================================

              E N D   O F   P R O C E S S I N G   O N   P R I M A R Y   N O D E
              
=============================================================================================================
    
    The primary database preparation is finished now,You should now execute the following commands from the standby machine :

Next Steps
----------

    - Connect to the DR server (node 1) and execute :

        $0 -m RunOnStandBY -d $dbName -u $primDbService -U $stbyDbService -s $scanPrimaire -R

    Then :

        $0 -m RunOnStandBY -d $dbName -u $primDbService -U $stbyDbService -s $scanPrimaire

        You can add '-F' for interactive mode.



Once the dataguard has been created, you will need to create the previously extracted database services :


Final steps
-----------"

  if [ $(cat "/tmp/${primDbUniqueName}_database_services.sh" | egrep 'srvctl add service' | wc -l | tr -d ' ') -gt 0 ]
  then
    echo "
    - Create database services on the DR server (node 1) :
"
    cat "/tmp/${primDbUniqueName}_database_services.sh" | egrep 'srvctl add service' | sed 's/^/        /g'
  fi

  if [ $(cat "/tmp/${primDbUniqueName}_init_parameters.sh" | egrep 'alter system set' | wc -l | tr -d ' ') -gt 0 ]
  then
    echo "
    - Modify INIT parameters on DR server (node 1) :
"
    cat "/tmp/${primDbUniqueName}_init_parameters.sh" | egrep 'alter system set'  | sed 's/^/        /g'

    echo "
    - Restart the database on the DR servers

        srvctl stop database -db \$ORACLE_UNQNAME -i \$ORACLE_SID
        srvctl start database -db \$ORACLE_UNQNAME -i \$ORACLE_SID"
  fi


echo "

    $scpMessage

========================================================================
"

  elif [ "$dbRole" = "PRIMARY" -a "$opePart" = "STANDBY" ]
  then
    echo "

    ATTENTION : The database on this server is Primary,
    Kindly check the server and remove the database manually if needed
    by using these commands:

    $0 -d $dbName -u $primDbService -U $stbyDbService -R

    Then run the previous procedure:

    $0 -m RunOnStandBY -d $dbName -u $primDbService -U $stbyDbService -s $scanPrimaire

    To can add '-i' for interactive mode.

  "
  elif [ \( "$dbRole" = "NotStarted" -o \( "$dbRole" = "PHYSICAL STANDBY" -a "$step" = "RECOVER" \) \) -a "$opePart" = "STANDBY" ]
  then
  if  [ "$aRelancerEnBatch" = "Y" ]
    then
      echo
      echo "+===========================================================================+"
      echo "|       the main verification is done, the script will be re-execute        |"
      echo "|       in nohup mode with the same parameters                              |"
      echo "+===========================================================================+"


      echo
      echo "  The log file is:"
      echo "   $LOG_FILE"
      echo
      echo "+===========================================================================+"
      #
      #     On exporte les variables afin qu'elles soient reprises dans le script
      #

      export LOG_FILE
      export aRelancerEnBatch=N
      export dbPassword
      export stbyEnvFile
      export maxRmanChannels
      rm -f $LOG_FILE
#      nohup $0 -m RunOnStandBY -d $primDbUniqueName -D $stbyDbUniqueName -s $scanOppose >/dev/null 2>&1 &
      nohup $0 -m RunOnStandBY -d $dbName -u $primDbService -U $stbyDbService -s $scanOppose >/dev/null 2>&1 &
      pid=$!
      waitFor=30
      echo " Script re-executing ..... (pid=$!) monitoring of process ($waitFor sec) "
      echo -n "  Monitoring of $pid --> "
      i=1
      while [ $i -le $waitFor ]
      do
        sleep 1
        if ps -p $pid >/dev/null
        then
          [ $(($i % 10)) -eq 0 ] && { echo -n "+" ; } || { echo -n "." ; }
        else
           echo "Process finish (Likely error)"
           echo
           echo "      --+--> End of file LOG"
           tail -15 $LOG_FILE | sed -e "s;^;        | ;"
         echo "        +----------------------"

           die "Le process batch is stopped"
        fi
        i=$(($i + 1))
      done
      echo
      echo
      echo "+===========================================================================+"
      echo "It's seem that the copy is correctly executed"
      echo "+===========================================================================+"
      exit
    fi
    [ "$step" = "" ] && cleanASMBeforeCopy $laBase FORCE
    duplicateDBForStandBY
    [    -f /tmp/${primDbUniqueName}_ewallet.p12 \
      -o -f /tmp/${primDbUniqueName}_cwallet.sso \
      -o -f /tmp/${primDbUniqueName}_passwd.ora ] && rm -f /tmp/${primDbUniqueName}_ewallet.p12 \
                                                           /tmp/${primDbUniqueName}_cwallet.sso \
                                                           /tmp/${primDbUniqueName}_passwd.ora 2>/dev/null
  fi
  endRun
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#     Trace
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
startRun()
{
  START_INTERM_EPOCH=$(date +%s)
  echo   "========================================================================================"
  echo   " Demarrage de l'execution"
  echo   "========================================================================================"
  echo   "  - $1"
  echo   "  - Started at    : $(date)"
  echo   "========================================================================================"
  echo
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#     Trace
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
endRun()
{
  END_INTERM_EPOCH=$(date +%s)
  all_secs2=$(expr $END_INTERM_EPOCH - $START_INTERM_EPOCH)
  mins2=$(expr $all_secs2 / 60)
  secs2=$(expr $all_secs2 % 60 | awk '{printf("%02d",$0)}')
  echo
  echo   "========================================================================================"
  echo   "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - "
  echo   "  - Finish at      : $(date)"
  echo   "  - Duration       : ${mins2}:${secs2}"
  echo   "========================================================================================"
  echo   "Script LOG in : $LOG_FILE"
  echo   "========================================================================================"
  if [ "$CMD_FILE" != "" ]
  then
    echo   "Commands Logged to : $CMD_FILE"
    echo   "========================================================================================"
  fi
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#     Trace
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
startStep()
{
  STEP="$1"
  STEP_START_EPOCH=$(date +%s)
  echo
  echo "       - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - "
  echo "       - Start Step : $STEP"
  echo "       - At         : $(date)"
  echo "       - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - "
  echo
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#     Trace
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
endStep()
{
  STEP_END_EPOCH=$(date +%s)
  all_secs2=$(expr $STEP_END_EPOCH - $STEP_START_EPOCH)
  mins2=$(expr $all_secs2 / 60)
  secs2=$(expr $all_secs2 % 60 | awk '{printf("%02d",$0)}')
  echo
  echo "       - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - "
  echo "       - End Step : $STEP"
  echo "       - At       : $(date)"
  echo "       - Duration : ${mins2}:${secs2}"
  echo "       - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - "
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#     Abort du programme
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
die()
{
  echo "
ERROR :
  $*"
  exit 1
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#     Execution de commandes DGMGRL avec gestion de la trace
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
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
  printf "%-75s : " "    - $lib"
  dgmgrl -silent "$connect" "$cmd" > $$.tmp 2>&1 \
    && { echo "OK" ; rm -f $$.tmp ; return 0 ; } \
    || { echo "ERROR" ; cat $$.tmp ; rm -f $$.tmp ; return 1 ; }
}
exec_rman()
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
RMAN : ${lib:-No description}
===============================================================================
rman target \"$connectSecret\"   <<%%
$cmd
%%
    " >> $CMD_FILE
  fi
  # echo "    - $cmd"
  printf "%-75s : " "    - $lib"
  rman target "$connect"  > $$.tmp 2>&1  <<%%
$cmd
%%
  [ $? -eq 0 ]   && { echo "OK" ; rm -f $$.tmp ; return 0 ; } \
    || { echo "ERROR" ; cat $$.tmp ; rm -f $$.tmp ; return 1 ; }
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#     Execution de commandes SRVCTL avec gestion de la trace
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
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
  printf "%-75s : " "$lib"
  if srvctl $cmd > $tmpOut 2>&1
  then
    echo "$okMessage"
    rm -f $tmpOut
    return 0
  else
    echo "$koMessage"
    [ "$SILENT" = "N" ] && cat $tmpOut
    rm -f $tmpOut
    [ "$diemessage" = "" ] && return 1 || die "$dieMessage"
  fi
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#     Execution de commandes ASM avec gestion de la trace
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
exec_asmcmd()
{
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
ASMCMD : ${lib:-No description}
===============================================================================
asmcmd --privilege sysdba $cmd
    " >> $CMD_FILE
  fi
  printf "%-75s : " "$lib"
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
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#     Suppression de repertoires
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
removeASMDir()
{
  local dir=$1

  if asmcmd --privilege sysdba ls -d $dir >/dev/null 2>&1
  then
    exec_asmcmd "rm -rf $dir" "    - Remove of directory $dir" "OK" "Error" "Impossible to remove $dir"
    return $?
  else
    echo "    - $dir does not exist"
    return 0
  fi
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#     Creation de repertoires
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
createASMDir()
{
  local dir=$1
  if ! asmcmd --privilege sysdba ls -d $dir >/dev/null 2>&1
  then
    exec_asmcmd "mkdir $dir" "    - Creation of directory $dir" "OK" "Erreur" "Impossible to create $dir"
    return $?
  else
    return 0
  fi
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#      Exécute du SQL avec contrôle d'erreur et de format
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
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

  # CBI - 20221114 - Format output sqlplus
  if [ "$lib" != "" ]
  then
     printf "%-75s : " "$lib";
     sqlplus -s ${login} >$REDIR_FILE 2>&1 <<%EOF%
$bloc_sql
%EOF%
    status=$?
  else
     sqlplus -s ${login} <<%EOF% | tee $REDIR_FILE
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
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#     Teste un répertoire et le crée
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
checkDir()
{
  printf "%-75s : " "  - Existence of $1"
  if [ ! -d $1 ]
  then
    echo "Non Existent"
    printf "%-75s : " "    - Creation of $1"
    mkdir -p $1 && echo OK || { echo "*** ERROR ***" ; return 1 ; }
  else
    echo "OK"
  fi
  printf "%-75s : " "  - $1 is writable"
  [ -w $1 ] && echo OK || { echo "*** ERROR ***" ; return 1 ; }
  return 0
}
convertToCustDNS()
{
  local FQDN=$(echo "${1}:" | cut -f1 -d:) 
  local port=$(echo "${1}:" | cut -f2 -d:)
  local FQDNNew=$FQDN
  local host=$(echo "${FQDN}." | cut -f1 -d".")
  
  ipListOrig=$(nslookup $FQDN | grep Address | sed -e "1 d" | cut -f2 -d" " | sort | tr '\n' ' ' | sed -e "s; $;;")
  local tmp=${host}.oci.michelin.com
  ipListNew=$(nslookup $tmp | grep Address | sed -e "1 d" | cut -f2 -d" " | sort | tr '\n' ' ' | sed -e "s; $;;")
  [ "$ipListOrig" = "$ipListNew" ] && FQDNNew=$tmp
  [ "$port" = "" ] && echo "$FQDNNew" || echo "$FQDNNew:$port"
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#  Usage
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
usage()
{
echo " $*

Usage :
$SCRIPT -d dbName [-u primService] [-U stbyService]
         [-s scan] [-L Channels]
         [-C|-R|-V] [-F] [-m mode] [-h|-?]

         dbName       : The DB_NAME
         primService  : PRIMARY Database (db Unique Name Service - Must Exists)
         stbyService  : STANDBY Database (db Unique Name Service - Must exists)
         scan         : Scan Address (host:port) of the opposite DB (can be a local listener)
         Channels     : Number of channels RMAN to be used : defaut 16
         -C           : Creation mode (The script will execute
                        in nohup after the first verification done
                        unless -F is set)
         -r  step     : Continue at 'step'
                        Step can be :
                          - RECOVER : Start at recover DB (in case of error)
         -R           : Delete the database (To Run on Standby Server)
         -V           : Verification of dataguard status
         -F           : Do not run the script in Nohup (Foreground)
         -?|-h        : Help

  Version : $VERSION
  "
  exit
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
set -o pipefail

SCRIPT=$(basename $0)

hostname=${HOSTNAME%%.*}
hostnum="${hostname: -1}"
hostnumN=$(($hostnum+1))

[ "$(id -un)" != "oracle" ] && die "Kindly run this script with the user \"oracle\""
[ "$(hostname -s | sed -e "s;.*\([0-9]\)$;\1;")" != "$hostnum" ] && die "Run this script from the first node of the cluster"

[ "$1" = "" ] && usage
toShift=0
while getopts m:u:U:d:s:hL:Cr:RTVF opt
do
  case $opt in
   # --------- Source Database --------------------------------
   d)   dbName=$OPTARG           ; toShift=$(($toShift + 2)) ;;
   u)   primDbService=$OPTARG    ; toShift=$(($toShift + 2)) ;;
   U)   stbyDbService=$OPTARG    ; toShift=$(($toShift + 2)) ;;
   # --------- Target Database --------------------------------
   # --------- Keystore, Scan ... -----------------------------
   s)   scanOppose=$OPTARG       ; toShift=$(($toShift + 2)) ;;
   L)   maxRmanChannels=$OPTARG  ; toShift=$(($toShift + 2)) ;;
   # --------- Modes de fonctionnement ------------------------
   C)   mode=CREATE              ; toShift=$(($toShift + 1)) ;;
   r)   mode=CREATE
        step=${OPTARG^^}         ; toShift=$(($toShift + 2)) ;;
   R)   mode=DELETE              ; toShift=$(($toShift + 1)) ;;
   V)   mode=VERIFICATION        ; toShift=$(($toShift + 1)) ;;
   T)   mode=TEST                ; toShift=$(($toShift + 1)) ;;
   F)   aRelancerEnBatch=N       ; toShift=$(($toShift + 1)) ;;
   m)   ope=$OPTARG              ; toShift=$(($toShift + 2)) ;;
   # --------- Usage ------------------------------------------
   ?|h) usage "";;
  esac
done
shift $toShift

primDbName=$(echo "${primDbService}." | cut -f1 -d. | sed -e "s;\.*$;;")
primDbDomain=$(echo "${primDbService}." | cut -f2-20 -d. | sed -e "s;\.*$;;")
stbyDbName=$(echo "${stbyDbService}." | cut -f1 -d. | sed -e "s;\.*$;;")
stbyDbDomain=$(echo "${stbyDbService}." | cut -f2-20 -d. | sed -e "s;\.*$;;")

# -----------------------------------------------------------------------------
#
#       Analyse des paramètres et valeurs par défaut
#
# -----------------------------------------------------------------------------
if [ "${ope^^}" = "RUNONSTANDBY" ]
then
  opePart="STANDBY"
  shift
else
  opePart="PRIMARY"
fi

# maxRmanChannels=${maxRmanChannels:-32}
maxRmanChannels=${maxRmanChannels:-16}
# sectionSizeRESTORE="64G"
sectionSizeRESTORE="8G"
# sectionSizeRECOVER="128G"
sectionSizeRECOVER="8G"

#
#      Base de données source (Db Unique Name)
#

if [ "$(echo $dbName)" != "" ]
then
primDbUniqueName=$primDbName
primDbName=$dbName
else
  if [ "$(echo $primDbName)" != "" ]
  then
    primDbUniqueName=$primDbName
    primDbName=$(echo ${primDbName%EXA*})
  else
    die "Donner un DB Unique Name complet $primDbName (base)"
  fi
fi

if [ "$(echo $dbName)" != "" ]
then
stbyDbUniqueName=$stbyDbName
stbyDbName=$dbName
else
  if [ "$(echo $stbyDbName)" != "" ]
  then
    stbyDbUniqueName=$stbyDbName
    stbyDbName=$(echo $stbyDbName | cut -f1 -d"_")
  else
    die "Donner un DB Unique Name complet $stbyDbName (base)"
  fi
fi


#
#   Mode de fonctionnement
#
mode=${mode:-CREATE}                             # Par défaut Create
aRelancerEnBatch=${aRelancerEnBatch:-Y}          # Par défaut, le script de realne en nohup après les
                                                 # vérifications (pour la copie seulement)

[ "$step" != "" ] && aRelancerEnBatch=N          # LA reprise ne se fait que pour le RECOVER (rapide) on force l'interactif
# -----------------------------------------------------------------------------
#
#    Constantes et variables dépendantes
#
# -----------------------------------------------------------------------------
DAT=$(date +%Y%m%d_%H%M)                     # DATE (for filenames)
BASEDIR=$HOME/dataguard                      # Base dir for logs & files
LOG_DIR=$BASEDIR/$primDbName                  # Log DIR
ASM_INSTANCE=$(ps -ef | grep smon_+ASM | grep -v grep |sed -e "s;^.*+ASM;+ASM;")
if [ "$LOG_FILE" = "" ]
then
  case $mode in
    CREATE)       LOG_FILE=$LOG_DIR/dataGuard_CRE_${primDbName}_${DAT}.log 
                  CMD_FILE=$LOG_DIR/dataGuard_CRE_${primDbName}_${DAT}.cmd ;;
    DELETE)       LOG_FILE=$LOG_DIR/dataGuard_DEL_${primDbName}_${DAT}.log 
                  CMD_FILE=$LOG_DIR/dataGuard_DEL_${primDbName}_${DAT}.cmd ;;
    TEST)         LOG_FILE=/dev/null                                       ;;
    VERIFICATION) LOG_FILE=/dev/null                                       ;;
    *)            die "Mode inconnu"                                       ;;
  esac

fi
echo
echo "  ================================================="
echo "  - Verifications & variables computation"
echo "  ================================================="
echo

echo "  - Converting to customer's DNS FQDN"
tmp=$scanOppose
scanOppose=$(convertToCustDNS $scanOppose)
echo "    - $tmp "
[ "$scanOppose" = "$tmp" ] && echo "      --> Unchanged" || echo "      --> $scanOppose"

# -----------------------------------------------------------------------------
#    Controles basiques (il faut que l'on puisse poitionner l'environnement
# base de données cible (et que ce soit la bonne!!!
# -----------------------------------------------------------------------------
checkDir $LOG_DIR || die "$LOG_DIR is incorrect"
if [ "$mode" = "CREATE" ]
then
  if [ "$opePart" = "PRIMARY" ]
  then

    setEnvPrimaire
    ORACLE_UNQNAME=$primDbUniqueName
    scanLocal=$(srvctl config scan  | grep -i "SCAN name" | cut -f2 -d: | cut -f1 -d, | sed -e "s; ;;g"):1521
    scanLocal=$(convertToCustDNS $scanLocal)
    echo "  - Converting to customer's DNS FQDN"
    tmp=$scanLocal
    scanLocal=$(convertToCustDNS $scanLocal)
    echo "      - $tmp "
    [ "$scanLocal" = "$tmp" ] && echo "      --> Unchanged" || echo "      --> $scanLocal"

    [ "$ORACLE_UNQNAME" != "$primDbUniqueName" ] && die "Attention, the environment position is not corresponding with  : $primDbUniqueName"
    echo "    - Mode : CREATE (From the PRIMARY ($ORACLE_UNQNAME)"

    [ "$(exec_sql "/ as sysdba" "select  name from v\$database;")" != "${primDbName^^}" ] && die "Environment Badly positioned "
    primDbUniqueName=$ORACLE_UNQNAME

    scanStandBy=$scanOppose

    domaineStandBy=$stbyDbDomain
    serviceStandBy=$stbyDbService
    tnsStandBy="//$scanStandBy/$serviceStandBy"

    scanPrimaire=$scanLocal

    domainePrimaire=$primDbDomain
    servicePrimaire=$primDbService
    tnsPrimaire="//$scanLocal/$servicePrimaire"
    grep "^${primDbUniqueName}:" /etc/oratab >/dev/null 2>&1 || die "$primDbUniqueName not exist on /etc/oratab"

    hostLocal=$(echo $scanLocal | cut -f1 -d:)
    portLocal=$(echo $scanLocal | cut -f2 -d:)
    hostOppose=$(echo "$scanOppose:" | cut -f1 -d:)
    portOppose=$(echo "$scanOppose:" | cut -f2 -d:)
    [ "$portOppose" = "" ] && die "Scan address ($scanOppose) must contain host and port" 
    hostPrimaire=$hostLocal
    portPrimaire=$portLocal
    hostStandBy=$hostOppose
    portStandBy=$portOppose
    tnsTestConnect=$tnsPrimaire

    
     # showVars

  elif [ "$opePart" = "STANDBY" ]
  then

    setEnvStandby
    stbyDbUniqueName=$(echo "${stbyDbService}." | sed -e "s;^\([^\.]*\)\.[^\:]*.*$;\1;")
    scanLocal=$(srvctl config scan  | grep -i "SCAN name" | cut -f2 -d: | cut -f1 -d, | sed -e "s; ;;g"):1521
    scanLocal=$(convertToCustDNS $scanLocal)
    echo "  - Converting to customer's DNS FQDN"
    tmp=$scanLocal
    scanLocal=$(convertToCustDNS $scanLocal)
    echo "      - $tmp "
    [ "$scanLocal" = "$tmp" ] && echo "      --> Unchanged" || echo "      --> $scanLocal"
    
    [ "$ORACLE_UNQNAME" != "$stbyDbUniqueName" ] && die "Attention, the environment position $ORACLE_UNQNAME is not corresponding with : $stbyDbUniqueName"
    echo "    - Mode : CREATE (From database STANDBY ($ORACLE_UNQNAME)"



    scanStandBy=$scanLocal
    domaineStandBy=$stbyDbDomain


    [ "$domaineStandBy" = "" ] &&  serviceStandBy=$stbyDbUniqueName || serviceStandBy=$stbyDbUniqueName.$domaineStandBy
    tnsStandBy="//$scanLocal/$serviceStandBy"

    scanPrimaire=$scanOppose
    domainePrimaire=$primDbDomain
    [ "$domainePrimaire" = "" ] &&  servicePrimaire=$primDbUniqueName || servicePrimaire=$primDbUniqueName.$domainePrimaire

    tnsPrimaire="//$scanPrimaire/$servicePrimaire"

    hostLocal=$(echo $scanLocal | cut -f1 -d:)
    portLocal=$(echo $scanLocal | cut -f2 -d:)
    hostOppose=$(echo $scanOppose | cut -f1 -d:)
    portOppose=$(echo $scanOppose | cut -f2 -d:)
    hostPrimaire=$hostOppose
    portPrimaire=$portOppose
    hostStandBy=$hostLocal
    portStandBy=$portLocal

    grep "^${stbyDbUniqueName}:" /etc/oratab >/dev/null 2>&1 || die "$stbyDbUniqueName not exist on /etc/oratab"

    echo
    echo "  - Generation of Alias TNS necessary"
    echo "    ===================================="
    echo
    tnsAliasesForDG "$stbyDbUniqueName" "$hostStandBy"  "$portStandBy"  "$serviceStandBy"  "$domaineStandBy" \
                    "$primDbUniqueName" "$hostPrimaire" "$portPrimaire" "$servicePrimaire" "$domainePrimaire"

    echo
    echo "  - Copy the Alias TNS to the other(s) Node(s)"
    echo "    ===================================="
    echo

#######
#. oraenv <<< $ASM_INSTANCE >/dev/null
#ListDGHosts=$(olsnodes)
# ListDGHosts=$(srvctl status database -db $stbyDbUniqueName | awk '{print $8}')
ListDGHosts=$(srvctl config database -db $stbyDbUniqueName | grep 'Configured nodes:' | cut -d ':' -f2 | sed 's/^ *//g' | tr "," "\n")
setEnvStandby
########

## CBI - 20221219 - Ecrase la configuration du TNS sur les noeuds : LISTENER_IPLOCAL pointe sur le noeud 1
  for host in $ListDGHosts;
  do
    if [ "$host" != ${HOSTNAME%%.*} ]
    then

      echo "      ============================="
      echo "    - Updating TNS aliases on $host"
      echo "      ============================="
      echo

      ssh -q oracle@${host} -o StrictHostKeyChecking=no /bin/bash <<EOF
export stbyDbName=$stbyDbName
$(typeset -f setEnvStandby)
$(typeset -f addToTns)
$(typeset -f tnsAliasesForDG)
setEnvStandby
# env | grep ORA
# env | grep TNS
tnsAliasesForDG "$stbyDbUniqueName" "$hostStandBy"  "$portStandBy"  "$serviceStandBy"  "$domaineStandBy" \
                "$primDbUniqueName" "$hostPrimaire" "$portPrimaire" "$servicePrimaire" "$domainePrimaire"
EOF

    fi
  done

    # tnsAliasesForDG "$stbyDbUniqueName" "$hostStandBy"  "$portStandBy"  "$serviceStandBy"  "$domaineStandBy" \
                    # "$primDbUniqueName" "$hostPrimaire" "$portPrimaire" "$servicePrimaire" "$domainePrimaire"

#    tnsAliasesForCMAN

  fi
  tnsTestConnect=$tnsPrimaire
elif [ "$mode" = "VERIFICATION" -o "$mode" = "TEST" ]
then
  if grep "^${stbyDbUniqueName}:" /etc/oratab >/dev/null 2>&1
  then
setEnvStandby
    [ "$ORACLE_UNQNAME" != "$stbyDbUniqueName" ] && die "Attention, the environment position is not corresponding with : $stbyDbUniqueName"
    echo "  - Mode : VERIFICATION (From database STAND-BY ($ORACLE_UNQNAME)"
  else
setEnvPrimaire
    [ "$ORACLE_UNQNAME" != "$primDbUniqueName" ] && die "Attention, the environment position is not corresponding with : $primDbUniqueName"
    echo "  - Mode : VERIFICATION (From database PRIMAIRE ($ORACLE_UNQNAME)"
  fi
  tnsTestConnect=$ORACLE_UNQNAME
elif [ "$mode" = "DELETE" ]
then
setEnvStandby
  [ "$ORACLE_UNQNAME" != "$stbyDbUniqueName" ] && die "Attention, the environment position is not corresponding with : $stbyDbUniqueName"
    echo "  - Mode : DELETE (From database STANDBY ($ORACLE_UNQNAME)"
    tnsTestConnect=$primDbUniqueName
fi

dbServerOppose=$(echo $hostOppose | sed -e "s;^\(.*\)\(-scan\)\(.*\)$;\11\3;")

channelClause=""
i=1
while [ $i -le $maxRmanChannels ]
do
  channelClause="$channelClause
allocate channel C$i type disk ;"
    i=$(($i + 1))
done

# -----------------------------------------------------------------------------
#      Lancement de l'exécution
# -----------------------------------------------------------------------------
if [ "$mode" = 'CREATE' ]
then
  if [ "$tnsTestConnect" != "" ]
  then
    #
    #     Try to get the password in the Wallet
    #
    printf "%-75s : " "  - Try to get Password from the DBAAS Wallet"
    dbPassword=$(getPassDB)   
    [ "$dbPassword" != "" ] && echo "OK" || echo "Vide"
    # echo "    --> $dbPassword"
    if [ "$dbPassword" != "" ]
    then
      # echo "    --> sys/${dbPassword}@$tnsTestConnect as sysdba"
      printf "%-75s : " "  - Database connection test"
      res=$(exec_sql "sys/${dbPassword}@$tnsTestConnect as sysdba" "select 'X' from dual ;")
      [ "$res" != "X" ] && { dbPassword="" ; echo "Incorrect" ; echo "$res" ; } || echo OK
    fi
    if  [ "$dbPassword" = "" ]
    then
      read -sp "  - Enter SYS password for the primary : " dbPassword
      echo
      printf "%-75s : " "   - Database connection test (entered password)"
      [ "$dbPassword" = "" ] && dbPassword=xxx
      # echo "sys/${dbPassword}@$tnsTestConnect as sysdba"
      res=$(exec_sql "sys/${dbPassword}@$tnsTestConnect as sysdba" "select 'X' from dual ;")
      [ "$res" != "X" ] && { dbPassword="" ; echo "Incorrect" ; echo "$res" ; die "The password of the primary database is incorrect

------------------------------------------------------------------------
it may be because the db_domain is set in the database
To remove it, issue:
------------------------------------------------------------------------
            THIS WILL BOUNCE THE DATABASE
------------------------------------------------------------------------

. $HOME/$(echo $ORACLE_UNQNAME | cut -f1 -d'_').env
sqlplus / as sysdba <<%%
alter system set db_domain='' scope = spfile;
%%
srvctl stop database -d $ORACLE_UNQNAME
srvctl start database -d $ORACLE_UNQNAME
------------------------------------------------------------------------
" ; } || echo OK
    fi
  fi
fi

if [ "$opePart" = "PRIMARY" ]
then
  PDATA=$(exec_sql "/ as sysdba" "
SET HEAD OFF FEED OFF;
SELECT NVL(LISTAGG('+'||dg.name, ',') WITHIN GROUP (ORDER BY dg.name),'+DATA1') AS data_diskgroups
FROM V\$ASM_DISKGROUP dg, V\$ASM_CLIENT c
WHERE dg.group_number = c.group_number
AND UPPER(dg.name) LIKE '%DATA%';")

  PRECO=$(exec_sql "/ as sysdba" "
SET HEAD OFF FEED OFF;
SELECT NVL(LISTAGG('+'||dg.name, ',') WITHIN GROUP (ORDER BY dg.name),'+OTHER') AS data_diskgroups
FROM V\$ASM_DISKGROUP dg, V\$ASM_CLIENT c
WHERE dg.group_number = c.group_number
AND UPPER(dg.name) NOT LIKE '%DATA%';")
else
  if [ "$mode" = 'CREATE' ]
  then
    PDATA=$(exec_sql "sys/${dbPassword}@$tnsTestConnect as sysdba" "
SET HEAD OFF FEED OFF;
SELECT NVL(LISTAGG('+'||dg.name, ',') WITHIN GROUP (ORDER BY dg.name),'+DATA1') AS data_diskgroups
FROM V\$ASM_DISKGROUP dg, V\$ASM_CLIENT c
WHERE dg.group_number = c.group_number
AND UPPER(dg.name) LIKE '%DATA%';")

    PRECO=$(exec_sql "sys/${dbPassword}@$tnsTestConnect as sysdba" "
SET HEAD OFF FEED OFF;
SELECT NVL(LISTAGG('+'||dg.name, ',') WITHIN GROUP (ORDER BY dg.name),'+OTHER') AS data_diskgroups
FROM V\$ASM_DISKGROUP dg, V\$ASM_CLIENT c
WHERE dg.group_number = c.group_number
AND UPPER(dg.name) NOT LIKE '%DATA%';")
  fi

  SDATA=$(echo "+$(asmcmd --privilege sysdba ls | grep DATA | sed -e 's;/;;g')")
  SRECO=$(echo "+$(asmcmd --privilege sysdba ls | grep RECO | sed -e 's;/;;g')")
fi

showVars

case $mode in
CREATE)         createDG       2>&1 | tee $LOG_FILE ; exitStatus=$? ;;
DELETE)         deleteStandBy  2>&1 | tee $LOG_FILE ; exitStatus=$? ;;
TEST)           testUnit       2>&1 | tee $LOG_FILE ; exitStatus=$? ;;
VERIFICATION)   verificationDG 2>&1 | tee $LOG_FILE ; exitStatus=$? ;;
esac


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

exit $exitStatus
