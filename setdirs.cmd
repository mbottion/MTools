echo ======================================================

sudo fuser -k /home/users/ifopame1
sudo usermod -d /busdata/ifop/ame1/home ifopame1
sudo fuser -k /home/users/ifopamea
sudo usermod -d /busapps/ifop/ame1/home ifopamea

echo ======================================================

grep ifopame1 /etc/passwd
echo -n "testing /busdata/ifop/ame1/home : "
[ -d /busdata/ifop/ame1/home ] && echo "OK" || { echo "KO, creating" ; sudo mkdir -p /busdata/ifop/ame1/home ; sudo chown ifopame1:ifopame1 /busdata/ifop/ame1/home ; }
echo
sudo ls -ld /busdata/ifop/ame1/home
sudo ls -ld /home/users/ifopame1
sudo sh -c "shopt -s dotglob ; cp -rp /home/users/ifopame1/* /busdata/ifop/ame1/home"

echo
echo content of : /home/users/ifopame1
echo
#sudo ls -la /home/users/ifopame1
echo
echo content of : /busdata/ifop/ame1/home
echo 
#sudo ls -la /busdata/ifop/ame1/home
#sudo rm -rf /busdata/ifop/ame1/home

echo ======================================================

grep ifopamea /etc/passwd
echo -n "testing /busapps/ifop/ame1/home : "
[ -d /busapps/ifop/ame1/home ] && echo "OK" || { echo "KO, creating" ; sudo mkdir -p /busapps/ifop/ame1/home ; sudo chown ifopamea:ifopame1 /busapps/ifop/ame1/home ; }
echo
sudo ls -ld /busapps/ifop/ame1/home
sudo ls -ld /home/users/ifopamea
sudo sh -c "shopt -s dotglob ; cp -rp /home/users/ifopamea/* /busapps/ifop/ame1/home"

echo
echo content of /home/users/ifopamea
echo 
#sudo ls -la /home/users/ifopamea
echo 
echo content of : /busapps/ifop/ame1/home
echo
#sudo ls -la /busapps/ifop/ame1/home
#sudo rm -rf /busapps/ifop/ame1/home

echo ======================================================

