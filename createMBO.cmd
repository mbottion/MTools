sudo -u oracle id
sudo -u oracle mkdir -p /home/oracle/mbo
sudo -u oracle chmod 755 /home/oracle
sudo -u oracle chmod 775 /home/oracle/mbo
sudo -u oracle setfacl -m u:opc:rwx /home/oracle/mbo
sudo -u oracle rm -f /home/oracle/mbo/runScript.sh
ls -ld /home/oracle /home/oracle/mbo
