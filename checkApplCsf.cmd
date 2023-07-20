v=$(mount | grep applcsf)
case $v in
  /dev/mapper*) echo "            - APPLCSF is LOCAL"
                echo "            - $(hostname -f)"
                ip a
                ;;
  *)            echo "            - APPLCSF is mounted from : "
                echo "            - $(echo $v | cut -f1 -d":")"
                ;;
esac
