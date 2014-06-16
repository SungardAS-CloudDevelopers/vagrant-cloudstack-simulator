#!/bin/bash -ex

source_dir=/tmp/cloudstack-simulator
destination_dir=/root
cloudstack_dir=$destination_dir/cloudstack

# Dependencies
yum install git wget -y
rpm -i http://mirror.metrocast.net/fedora/epel/6/i386/epel-release-6-8.noarch.rpm || true
rpm -i http://packages.erlang-solutions.com/erlang-solutions-1.0-1.noarch.rpm || true
yum update -y
yum install \
  ant \
  ant-devel \
  erlang \
  gcc \
  java-1.7.0-openjdk \
  java-1.7.0-openjdk-devel \
  mkisofs \
  mysql \
  mysql-server \
  nc \
  openssh-clients \
  tomcat6 \
  telnet \
  openssl-devel \
  ncurses-devel \
  -y

# install python 2.7
echo "/usr/local/lib" >> /etc/ld.so.conf
wget http://python.org/ftp/python/2.7.6/Python-2.7.6.tar.xz
tar xf Python-2.7.6.tar.xz
cd Python-2.7.6
./configure --prefix=/usr/local --enable-unicode=ucs4 --enable-shared LDFLAGS="-Wl,-rpath /usr/local/lib"
make && make altinstall
cd ..
rm -rf Python*

# this is not recommended, but installing two pythons is confusing:
cd /usr/local/bin
ln -s /usr/local/bin/python2.7 python

# Configure users to use this environment in the future (as well as THIS run):
echo 'export M2_HOME=/usr/local/apache-maven-3.0.5' >> /etc/bashrc
echo 'export PATH=/usr/local/bin:${PATH}:${M2_HOME}/bin' >> /etc/bashrc
export M2_HOME=/usr/local/apache-maven-3.0.5
export PATH=/usr/local/bin:${M2_HOME}/bin:${PATH}

# install setuptools + pip for python 2.7
cd ~/
wget https://bitbucket.org/pypa/setuptools/raw/bootstrap/ez_setup.py
python2.7 ez_setup.py
easy_install-2.7 pip

# RabbitMQ
rpm -i http://www.rabbitmq.com/releases/rabbitmq-server/v3.2.3/rabbitmq-server-3.2.3-1.noarch.rpm
chkconfig --level 345 rabbitmq-server on
/etc/init.d/rabbitmq-server start

# Start Dependency Services
chkconfig --level 345 mysqld on
/etc/init.d/mysqld start

# Maven
cd /usr/local
wget http://www.us.apache.org/dist/maven/maven-3/3.0.5/binaries/apache-maven-3.0.5-bin.tar.gz
tar -zxvf apache-maven-3.0.5-bin.tar.gz

# CloudStack Source
cd /root
git clone https://github.com/SungardAS-CloudDevelopers/cloudstack.git
cd cloudstack
git checkout -t origin/4.3

# Event Bus configuration
cp $source_dir/spring-event-bus-context.xml $cloudstack_dir/server/resources/META-INF/cloudstack/core/

# CloudStack Build
mvn -Pdeveloper -Dsimulator -DskipTests -Dmaven.install.skip=true install
cp $source_dir/cloudstack-simulator /etc/init.d/
chkconfig --level 345 cloudstack-simulator on

# Db Configuration
mvn -Pdeveloper -pl developer -Ddeploydb;mvn -Pdeveloper -pl developer -Ddeploydb-simulator

# mysql overwrites
mysql -uroot cloud -e "update service_offering set ram_size = 32;"
mysql -uroot cloud -e "update vm_template set enable_password = 1 where name like '%CentOS%';"

# commented out due to error:
#mysql -uroot cloud -e "insert into hypervisor_capabilities values (100,'100','Simulator','default',50,1,6,NULL,0,1);"
mysql -uroot cloud -e "update user set api_key = 'F0Hrpezpz4D3RBrM6CBWadbhzwQMLESawX-yMzc5BCdmjMon3NtDhrwmJSB1IBl7qOrVIT4H39PTEJoDnN-4vA' where id = 2;"
mysql -uroot cloud -e "update user set secret_key = 'uWpZUVnqQB4MLrS_pjHCRaGQjX62BTk_HU8uiPhEShsY7qGsrKKFBLlkTYpKsg1MzBJ4qWL0yJ7W7beemp-_Ng' where id = 2;"
mysql -uroot cloud -e "update configuration set value = 0 where name like 'max.account.%';"

# CloudStack Configuration
/etc/init.d/cloudstack-simulator start
pip install argparse
pip install mysql-connector-python --allow-external mysql-connector-python
pip install ipython[all]

while ! nc -vz localhost 8096; do sleep 10; done # Wait for CloudStack to start
/etc/init.d/cloudstack-simulator stop
sleep 10

# restart
/etc/init.d/cloudstack-simulator start
while ! nc -vz localhost 8096; do sleep 10; done # Wait for CloudStack to start
mysql -uroot cloud -e "update configuration set value = 'false' where name = 'router.version.check';"

# So, the mysql-connector-python needs to be installed specially, (see above), so let us mess with the setup script for marvin
sed -i 's,"mysql-connector-python",#"mysql-connector-python",g' tools/marvin/setup.py

# Set up the simulator
mvn -Pdeveloper,marvin.sync -Dendpoint=localhost -pl :cloud-marvin
mvn -Pdeveloper,marvin.setup -Dmarvin.config=setup/dev/advanced.cfg -pl :cloud-marvin integration-test

# to revert the setup file:
#sed -i tools/marvin/setup.py 's,"mysql-connector-python",#"mysql-connector-python",g'

/etc/init.d/cloudstack-simulator stop

# Cleanup
rm -rf ~/*.tar.gz
rm -rf ~/cloudstack/.git
yum clean all
find /var/log -type f | while read f; do echo -ne '' > $f; done;
dd if=/dev/zero of=wipefile bs=1024x1024 || rm -f wipefile

# Reset Networking
sync
sed -i /HWADDR/d /etc/sysconfig/network-scripts/ifcfg-eth0
rm -f /etc/sysconfig/networking-scripts/ifcfg-eth1
rm -f /etc/udev/rules.d/70-persistent-net.rules
