#!/bin/bash -x
USER="todoapp"
DIR="/home/todoapp/ACIT4640-todo-app"
NGINX_CONF="/etc/nginx/nginx.conf"
ADMIN_SSH="/home/admin/.ssh"
#add todoapp user
sudo useradd todoapp
#set password to todoapp user
sudo sh -c 'echo P@ssw0rd | passwd todoapp --stdin'
#create admin user
sudo useradd admin
#set password to admin user
sudo sh -c 'echo P@ssw0rd | passwd admin --stdin'
#Add admin user to sudoers group
sudo usermod -aG wheel admin
#create .ssh folder
sudo mkdir /home/admin/.ssh
sudo chmod 700 $ADMIN_SSH
#Create authorized_keys file
sudo curl https://student:BCIT2020@acit4640.y.vu/docs/module02/resources/acit_admin_id_rsa.pub -o $ADMIN_SSH/authorized_keys
sudo chmod 600 $ADMIN_SSH/authorized_keys
sudo chown admin:admin $ADMIN_SSH/authorized_keys
sudo chown admin:admin $ADMIN_SSH
#setup passwordless sudo
sudo sed -i 's/^#\s*\(%wheel\s*ALL=(ALL)\s*NOPASSWD:\s*ALL\)/\1/' /etc/sudoers
# install Mongodb
cat <<EOF > mongodb-org-4.4.repo
[mongodb-org-4.4]
name=MongoDB Repository
baseurl=https://repo.mongodb.org/yum/redhat/\$releasever/mongodb-org/4.4/x86_64/
gpgcheck=1
enabled=1
gpgkey=https://www.mongodb.org/static/pgp/server-4.4.asc
EOF
sudo mv mongodb-org-4.4.repo /etc/yum.repos.d/mongodb-org-4.4.repo
#sudo dnf search mongodb
sudo dnf install -y -b mongodb-org
# start mongodb
sudo systemctl enable mongod
sudo systemctl start mongod
# create mongodb instance
mongo --eval "db.createCollection('acit4640')"
echo "Mongo DB installed and started.."
# Reconfig MongoDB path
sudo rm -rf $DIR/config/database.js
sudo cat <<EOF > database.js 
module.exports = {
    localUrl: 'mongodb://localhost/acit4640'
}; 
EOF
sudo mv database.js $DIR/config/
# navigate to the todoapp home
cd /home/todoapp/
# If the project folder already exists, DELETE it
if [ -d "./ACIT4640-todo-app" ]; then sudo rm -Rf "./ACIT4640-todo-app"; fi
#Install Git
sudo dnf install -y -b git
# clone project from git to current folder
sudo git clone https://github.com/timoguic/ACIT4640-todo-app.git
# navigate to the project folder
cd ./ACIT4640-todo-app
# Reconfig MongoDB path
sudo sh -c 'echo "module.exports = {localUrl: \"mongodb://localhost/acit4640\"};" > ./config/database.js'
# install project packages
sudo dnf install -y -b nodejs
sudo npm install
# install nginx
sudo dnf install -y nginx
# config nginx
sudo sed -i 's:/usr/share/nginx/html;:/home/todoapp/ACIT4640-todo-app/public;:' $NGINX_CONF
if grep -qF "location /api/todos" $NGINX_CONF; then
	echo "Nginx file already configured!"
else
	sudo sed -i '49 i \ \ \ \ \ \ \ \ location /api/todos {\n \ \ \ \ \ \ \ \ \ \ \ \ proxy_pass http://localhost:8080;\n \ \ \ \ \ \ \ \}' $NGINX_CONF
fi
# start nginx
sudo systemctl enable nginx
sudo systemctl start nginx
echo "nginx installed and started"
# disable SE Linux
sudo setenforce 0
sudo sed -r -i 's/SELINUX=(enforcing|disabled)/SELINUX=permissive/' /etc/selinux/config
# start nginx
sudo systemctl enable nginx
sudo systemctl start nginx
# disable SE Linux
sudo setenforce 0
sudo sed -r -i 's/SELINUX=(enforcing|disabled)/SELINUX=permissive/' /etc/selinux/config
# config firewall
sudo firewall-cmd --zone=public --add-port=8080/tcp
sudo firewall-cmd --zone=public --add-service=http
sudo firewall-cmd --runtime-to-permanent
# Adjust todoapp home folder permission
cd ~
sudo chmod a+rx /home/todoapp/
sudo chown todoapp:todoapp /home/todoapp/ACIT4640-todo-app/
cat <<EOF > todoapp.service
[Unit]
Description=Todo app, ACIT4640
After=network.target
Requires=mongod.service
[Service]
Environment=NODE_PORT=8080
WorkingDirectory=/home/todoapp/ACIT4640-todo-app
Type=simple
User=$USER
ExecStartPre=/bin/sleep 5
ExecStart=node /home/todoapp/ACIT4640-todo-app/server.js
Restart=always
[Install]
WantedBy=multi-user.target
EOF
sudo mv todoapp.service /etc/systemd/system/
# Reload and start todoapp Deamon
sudo systemctl daemon-reload
sudo systemctl enable todoapp
sudo systemctl start todoapp