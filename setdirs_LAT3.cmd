echo ======================================================

sudo usermod -d /busdata/ifop/acj1/home ifopacj1
sudo usermod -d /busapps/ifop/acj1/home ifopacja

echo ======================================================

grep ifopacj1 /etc/passwd
echo -n "testing /busdata/ifop/acj1/home : "
[ -d /busdata/ifop/acj1/home ] && echo "OK" || { echo "KO, creating" ; sudo mkdir -p /busdata/ifop/acj1/home ; sudo chown ifopacj1:ifopacj1 /busdata/ifop/acj1/home ; }
echo
sudo ls -ld /busdata/ifop/acj1/home
sudo ls -ld /home/users/ifopacj1
sudo sh -c "shopt -s dotglob ; cp -rp /home/users/ifopacj1/* /busdata/ifop/acj1/home"

echo
echo content of : /home/users/ifopacj1
echo
sudo ls -la /home/users/ifopacj1
echo
echo content of : /busdata/ifop/acj1/home
echo 
sudo ls -la /busdata/ifop/acj1/home
#sudo rm -rf /busdata/ifop/acj1/home

echo ======================================================

grep ifopacja /etc/passwd
echo -n "testing /busapps/ifop/acj1/home : "
[ -d /busapps/ifop/acj1/home ] && echo "OK" || { echo "KO, creating" ; sudo mkdir -p /busapps/ifop/acj1/home ; sudo chown ifopacja:ifopacj1 /busapps/ifop/acj1/home ; }
echo
sudo ls -ld /busapps/ifop/acj1/home
sudo ls -ld /home/users/ifopacja
sudo sh -c "shopt -s dotglob ; cp -rp /home/users/ifopacja/* /busapps/ifop/acj1/home"

echo
echo content of /home/users/ifopacja
echo 
sudo ls -la /home/users/ifopacja
echo 
echo content of : /busapps/ifop/acj1/home
echo
sudo ls -la /busapps/ifop/acj1/home
#sudo rm -rf /busapps/ifop/acj1/home

echo ======================================================

