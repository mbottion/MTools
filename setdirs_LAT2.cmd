echo ======================================================

sudo usermod -d /busdata/ifop/eur1/home ifopeur1
sudo usermod -d /busapps/ifop/eur1/home ifopeura

echo ======================================================

grep ifopeur1 /etc/passwd
echo -n "testing /busdata/ifop/eur1/home : "
[ -d /busdata/ifop/eur1/home ] && echo "OK" || { echo "KO, creating" ; sudo mkdir -p /busdata/ifop/eur1/home ; sudo chown ifopeur1:ifopeur1 /busdata/ifop/eur1/home ; }
echo
sudo ls -ld /busdata/ifop/eur1/home
sudo ls -ld /home/users/ifopeur1
sudo sh -c "shopt -s dotglob ; cp -rp /home/users/ifopeur1/* /busdata/ifop/eur1/home"

echo
echo content of : /home/users/ifopeur1
echo
sudo ls -la /home/users/ifopeur1
echo
echo content of : /busdata/ifop/eur1/home
echo 
sudo ls -la /busdata/ifop/eur1/home
#sudo rm -rf /busdata/ifop/eur1/home

echo ======================================================

grep ifopeura /etc/passwd
echo -n "testing /busapps/ifop/eur1/home : "
[ -d /busapps/ifop/eur1/home ] && echo "OK" || { echo "KO, creating" ; sudo mkdir -p /busapps/ifop/eur1/home ; sudo chown ifopeura:ifopeur1 /busapps/ifop/eur1/home ; }
echo
sudo ls -ld /busapps/ifop/eur1/home
sudo ls -ld /home/users/ifopeura
sudo sh -c "shopt -s dotglob ; cp -rp /home/users/ifopeura/* /busapps/ifop/eur1/home"

echo
echo content of /home/users/ifopeura
echo 
sudo ls -la /home/users/ifopeura
echo 
echo content of : /busapps/ifop/eur1/home
echo
sudo ls -la /busapps/ifop/eur1/home
#sudo rm -rf /busapps/ifop/eur1/home

echo ======================================================

