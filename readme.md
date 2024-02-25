# Docker安装


卸载旧版本docker
```
apt-get remove docker docker-engine docker.io containerd runc
```
更新Ubuntu软件包列表和已安装软件的版本
```
apt update
apt upgrade
```
安装docker依赖
```
apt-get install ca-certificates curl gnupg lsb-release
```
添加Docker官方的GPG密钥
```
curl -fsSL http://mirrors.aliyun.com/docker-ce/linux/ubuntu/gpg | apt-key add –
```
添加Docker的软件源
```
add-apt-repository "deb [arch=amd64] http://mirrors.aliyun.com/docker-ce/linux/ubuntu $(lsb_release -cs) stable"
```
安装Docker
```
apt-get install docker-ce docker-ce-cli containerd.io
```
运行docker
```
systemctl start docker
```
# 安装依赖和编译hoplite
拉取ubuntu18.04镜像，创建一个名为"hoplite-base"的 docker，并进入
```
docker run --name="hoplite-base" -it ubuntu: 18.04 /bin/bash
```
更新Ubuntu软件包列表
```
apt update
```
安装基础库
```
apt install cmake git  python3 python3-pip wget –y
```
检查cmake版本。若低于3.13，后续编译hoplite会报错
```
cmake –version
```
若cmake低于3.13,运行下面命令升级cmake
```
wget https://github.com/Kitware/CMake/releases/download/v3.23.0/cmake-3.23.0-linux-x86_64.sh
bash ./cmake-3.23.0-linux-x86_64.sh --skip-licence --prefix=/usr
```
脚本运行时两次提示输入，第一次输yes,第二次输no
再检查cmake版本
```
cmake –version
```
创建文件夹，用于存放hoplite代码
```
cd /root
mkdir efs
cd ~/efs && git clone https://github.com/suquark/hoplite.git
```
由于后续gRPC的1.31.0版本的 .gitmodule内有链接存在问题，导致不能成功git submodule,因此需将正确的.gitmodule和install_dependencies.sh覆盖原始文件
```
cd hoplite
```
运行脚本安装gRPC和protobuf等依赖
```
./install_dependencies.sh
```
安装OpenMPI
```
wget https://download.open-mpi.org/release/open-mpi/v4.0/openmpi-4.0.4.tar.gz
tar zxf openmpi-4.0.4.tar.gz
cd openmpi-4.0.4
 ./configure --prefix=/usr/local/openmpi --enable-orterun-prefix-by-default
make
make install
```
配置环境变量
```
~/.bashrc
```
在底部添加下列语句
```
MPI_HOME=/usr/local/openmpi
export PATH=${MPI_HOME}/bin:$PATH
export LD_LIBRARY_PATH=${MPI_HOME}/lib:$LD_LIBRARY_PATH
export MANPATH=${MPI_HOME}/share/man:$MANPATH
export OMPI_ALLOW_RUN_AS_ROOT=1
export OMPI_ALLOW_RUN_AS_ROOT_CONFIRM=1
```
编译hoplite
```
cd ~/efs/hoplite
mkdir build
cd build
cmake -DCMAKE_BUILD_TYPE=Release ..
```
若报错protoc: error while loading shared libraries: libprotoc.so.15: cannot open shared object file，执行动态链接库管理命令，让可共享的动态链接库被找到：
```
Ldconfig
cmake -DCMAKE_BUILD_TYPE=Release ..
```
编译
```
make –j
```
# 安装conda
```
wget https://mirrors.bfsu.edu.cn/anaconda/archive/Anaconda3-2022.10-Linux-x86_64.sh --no-check-certificate
bash Anaconda3-2022.10-Linux-x86_64.sh    
```
该脚本运行会有三次提示输入，依次输入yes、无输入、yes
```
source ~/.bashrc
```
创建和激活python3.8的环境
```
conda create -n py38 python=3.8
conda activate py38
```

# 安装Hoplite的python库
安装python依赖
```
pip install 'ray[all]==1.3' 'ray[serve]==1.3' mpi4py torchvision==0.8.2 efficientnet_pytorch cython protobuf==3.20.2
```
安装python的hoplite库
```
cd ~/efs/hoplite
pip install -e python
cp build/notification python/hoplite/
./python/setup.sh
```
# 为MPI配置ssh
```
cd /root
mkdir .ssh
echo -e "Host *\n    StrictHostKeyChecking no" >> ~/.ssh/config
chmod 400 ~/.ssh/config
```
启动ssh
```
apt install openssh-server -y
/etc/init.d/ssh restart
```
退出docker
```
exit
```
# 保存docker镜像，启动docker集群
保存docker镜像，名为hoplite:1.0
```
docker commit hoplite-base hoplite:1.0
```
在多个终端分别用hoplite:1.0镜像创建容器
```
docker run -it --ip 172.17.0.1 --name="hoplite1 " hoplite:1.0 /bin/bash
docker run -it --ip 172.17.0.2 --name="hoplite2 " hoplite:1.0 /bin/bash
…
```
在每个节点生成公钥：
```
ssh-keygen
cat ~/.ssh/id_rsa.pub 
```
将每个节点输出的id_rsa.pub都复制到本地
```
touch ~/.ssh/authorized_keys
```
每个节点都生成authorized_keys后，将上步复制的所有节点的公钥，拷贝到每个节点的authorized_key
重启ssh服务
```
/etc/init.d/ssh restart
```
测试各个节点间的免密链接
```
ssh root@172.17.0.1
ssh root@172.17.0.2
```
每个节点，激活py38虚拟环境
```
conda activate py38
```
启动ray集群
将hoplite1作为master,运行
```
ray start --head --port=6379 --object-manager-port=8076 --resources='{"machine": 1}' --system-config '{"num_heartbeats_timeout": 10000}'
```
其它节点为worker,运行
```
ray start --address='172.17.0.2:6379' --redis-password='5241590000000000' --object-manager-port=8076 --resources='{"machine": 1}'
```
