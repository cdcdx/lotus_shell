#!/bin/bash

ENV_LOTUS_ROOT=/mnt

#rm -rf /usr/local/bin/pause
if [ ! -f "/usr/local/bin/pause" ]; then 
  sudo echo "#! /bin/bash
  get_char()
  {
    SAVEDSTTY=\`stty -g\` 
    stty -echo 
    stty raw 
    dd if=/dev/tty bs=1 count=1 2> /dev/null 
    stty -raw 
    stty echo 
    stty \$SAVEDSTTY 
  }
  if [ -z '$1' ]; then 
    echo ' ' 
    echo -e '\033[34m Please press any key to continue... \033[0m' 
    echo ' ' 
  else
    echo -e '$1' 
  fi
  get_char
  " > /usr/local/bin/pause
  
  sudo chmod 0755 /usr/local/bin/pause
fi

check_areyousure() {
  if [ -z $tips ]; then
    unset areyousure
  fi
  while [ -z $areyousure ]
  do
    echo " "
    read -e -r -p "Are you sure? [[Y]es/[N]o/[A]llow] " input
    case $input in
      [yY][eE][sS]|[yY])
        echo -e "\033[34m Yes \033[0m"
        areyousure=1
        ;;
      
      [nN][oO]|[nN])
        echo -e "\033[34m No \033[0m"
        areyousure=0
        ;;
      
      [aA][lL][lL][oO][wW]|[aA])
        echo -e "\033[34m Allow \033[0m"
        areyousure=1
        tips=99
        ;;
      
      *)
        echo -e "\033[31m Invalid input... \033[0m"
        ;;
    esac
  done
  return $areyousure
}

check_ssh() {
  apt install openssh-server -y
  
  num=`grep -i "PermitRootLogin yes" /etc/ssh/sshd_config |awk '{print length($0)}'|wc -L`
  if [ ! -z $num ]; then
    sed -i "s/#PermitRootLogin prohibit-password/PermitRootLogin yes/g"  /etc/ssh/sshd_config
  fi
  
  chmod 755 $HOME/.ssh/
  if [ -f "$HOME/.ssh/authorized_keys" ]; then 
    chmod 600 $HOME/.ssh/authorized_keys
  fi
  if [ -f "$HOME/.ssh/known_hosts" ]; then 
    chmod 644 $HOME/.ssh/known_hosts  
  fi
  
  systemctl restart sshd.service
}

check_init() {
  '''
  # 换Ubuntu源
  if [ ! -f "/etc/apt/sources.list.bak" ]; then 
    sudo cp /etc/apt/sources.list /etc/apt/sources.list.backup
    #阿里    #http://cn.archive.ubuntu.com/ubuntu/  ->  https://mirrors.aliyun.com/ubuntu/
    sed -i "s/http:\/\/cn.archive.ubuntu.com\/ubuntu/https:\/\/mirrors.aliyun.com\/ubuntu/g" /etc/apt/sources.list
    #sed -i "s/https:\/\/mirrors.aliyun.com\/ubuntu/http:\/\/cn.archive.ubuntu.com\/ubuntu/g" /etc/apt/sources.list 
    sudo apt-get -y update && sudo apt-get -y upgrade && sudo apt-get -y dist-upgrade
  fi
  '''
  #行号
  if [ ! -f "$HOME/.vimrc" ]; then 
    #echo "set nonu" > $HOME/.vimrc
    echo "set nu" > $HOME/.vimrc
    echo "set paste" > $HOME/.vimrc
  fi
  
  # install ulimit
  if [ `ulimit -n` -lt 1048576 ]; then
    ulimit -n 1048576
    sudo sed -i "/nofile/d" /etc/security/limits.conf
    sudo echo "
    * hard nofile 1048576
    * soft nofile 1048576
    root hard nofile 1048576
    root soft nofile 1048576
    " >> /etc/security/limits.conf
    
    sudo echo "ulimit -n 1048576" >> /etc/profile
  fi
  
  #SWAP
  # setup SWAP, 128GB, swappiness=1
  SWAPSIZE=`swapon --show |awk 'NR==2 {print $3}'`
  SWAPINT=`echo $SWAPSIZE | tr -cd "[0-9]"`
  echo $SWAPINT
  if [ "$SWAPINT" -lt "128" ]; then
  #if [ "$SWAPSIZE" != "128G" ]; then
    OLDSWAPFILE=`swapon --show |awk 'NR==2 {print $1}'`
    NEWSWAPFILE="/swapfile"
    if [ -n "$OLDSWAPFILE" ]; then
      swapoff -v $OLDSWAPFILE && \
      rm $OLDSWAPFILE && \
      sed -i "/swap/d" /etc/fstab
      #NEWSWAPFILE=$OLDSWAPFILE
    fi
    fallocate -l 128GiB $NEWSWAPFILE && \
    chmod 600 $NEWSWAPFILE && \
    mkswap $NEWSWAPFILE && \
    swapon $NEWSWAPFILE && \
    echo "$NEWSWAPFILE none swap sw 0 0" >> /etc/fstab
  fi
  
  #swappiness
  swappint=`cat /proc/sys/vm/swappiness`
  if [ $swappint -gt 1 ]; then
    #swappiness
    sysctl vm.swappiness=1
    sudo sed -i "/swappiness/d" /etc/sysctl.conf
    sudo echo "vm.swappiness=1" >> /etc/sysctl.conf
  fi
  
  # time adjust
  sudo apt install ntpdate -y
  ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
  ntpdate ntp.aliyun.com
  
  # update
  sudo apt update && sudo apt upgrade -y
  
  # monitor
  sudo apt install atop htop iotop nload nethogs sysstat lrzsz -y
  sudo apt install iputils-ping gawk -y
  
  # env
  sudo apt install mesa-opencl-icd ocl-icd-opencl-dev hwloc libhwloc-dev -y
  sudo add-apt-repository ppa:longsleep/golang-backports -y
  sudo apt update
  sudo apt install gcc git bzr jq pkg-config mesa-opencl-icd ocl-icd-opencl-dev gdisk zhcon g++ llvm clang -y
}

check_lotus_env() {
  # logs
  if [ ! -d "$ENV_LOTUS_ROOT/logs" ]; then
    sudo mkdir $ENV_LOTUS_ROOT/logs
  fi
  if [ ! -d "$HOME/logs" ]; then
    ln -s $ENV_LOTUS_ROOT/logs $HOME/logs
  fi
  
  # .lotus
  if [ ! -d "$ENV_LOTUS_ROOT/lotus" ]; then
    sudo mkdir $ENV_LOTUS_ROOT/lotus
  fi
  if [ ! -d "$HOME/.lotus" ]; then
    ln -s $ENV_LOTUS_ROOT/lotus $HOME/.lotus
  fi
  # .lotusminer
  if [ ! -d "$ENV_LOTUS_ROOT/miner" ]; then
    sudo mkdir $ENV_LOTUS_ROOT/miner
  fi
  if [ ! -d "$HOME/.lotusminer" ]; then
    ln -s $ENV_LOTUS_ROOT/miner $HOME/.lotusminer
  fi
  # .lotusworker
  if [ ! -d "$ENV_LOTUS_ROOT/worker" ]; then
    sudo mkdir $ENV_LOTUS_ROOT/worker
  fi
  if [ ! -d "$HOME/.lotusworker" ]; then
    ln -s $ENV_LOTUS_ROOT/worker $HOME/.lotusworker
  fi
  
  # tmp
  if [ ! -d "$ENV_LOTUS_ROOT/tmp" ]; then
    sudo mkdir $ENV_LOTUS_ROOT/tmp
  fi
  if [ ! -d "$HOME/tmp" ]; then
    ln -s $ENV_LOTUS_ROOT/tmp $HOME/tmp
  fi
  if [ ! -d "$ENV_LOTUS_ROOT/proofs_parent_cache" ]; then
    sudo mkdir $ENV_LOTUS_ROOT/proofs_parent_cache
  fi
  
  # filecoin-proof-parameters proofs
  if [ ! -d "$ENV_LOTUS_ROOT/proofs" ]; then
    sudo mkdir $ENV_LOTUS_ROOT/proofs
  fi
  
  if [ -z $LOTUS_PATH ]; then
    sudo echo "
    #lotus
    export LOTUS_PATH=$ENV_LOTUS_ROOT/lotus
    export LOTUS_MINER_PATH=$ENV_LOTUS_ROOT/miner
    export LOTUS_WORKER_PATH=$ENV_LOTUS_ROOT/worker
    export TMPDIR=$ENV_LOTUS_ROOT/tmp
    export FIL_PROOFS_PARENT_CACHE=$ENV_LOTUS_ROOT/proofs_parent_cache
    " >> /etc/profile
  fi
  
  if [ -z $FIL_PROOFS_PARAMETER_CACHE ]; then
    sudo echo "#lotus proof
    export FIL_PROOFS_PARAMETER_CACHE=$ENV_LOTUS_ROOT/proofs
    #export IPFS_GATEWAY=https://proof-parameters.s3.cn-south-1.jdcloud-oss.com/ipfs/
    " >> /etc/profile
  fi
  
  sudo source /etc/profile
}

check_ufw() {
  sudo ufw allow 1234/tcp
  sudo ufw allow 1347/tcp
  sudo ufw allow 2222/tcp
  sudo ufw allow 2345/tcp
  sudo ufw allow 3456/tcp
}

check_gpu() {
  #查询显卡核心
  string=`lspci |grep VGA |awk '{print $5}' | tr "\n" ","`
  array=(${string//,/ }) 
  for var in ${array[@]}
  do
    echo $var
    if [ "$var" == "NVIDIA" ]; then 
      
      # install GPU driver
      sudo apt install ubuntu-drivers-common -y
      nvidia-smi
      NEEDGPU=$?
      if [ $NEEDGPU -ne 0 ]; then
        sudo ubuntu-drivers autoinstall
        
        #nvtop
        check_nvtop
        
        #info 
        echo -e "\033[34m Warn:Need to restart to take effect. \033[0m"
        
        check_areyousure
        if [ $areyousure -eq 1 ]; then
          init 6
        fi
      fi
    fi
    echo " "
  done
}

check_nvtop() {
  RESULT=$(nvtop --version)
  RESULT=${RESULT:13:7}
  #echo $RESULT
  RESULT=${RESULT%.*}
  echo $RESULT
  if [ -z $RESULT ] || [ `expr $RESULT \> 0.9` -eq 0 ]; then
    echo "nvtop version must >= 1.0 . "
    
    # nvtop
    os_name=$(cat /etc/issue |sed -n '1p' |sed 's/\\n \\l//g' |awk '{print $2}')
    os_name=${os_name%.*}
    if [ $os_name -ge 19.04 ]; then
      # >= 19.04
      sudo apt install nvtop -y
    else
      # < 19.04
      dpkg --configure -a
      apt install libcurl4 cmake libncurses5-dev libncursesw5-dev -y
      git clone https://github.com/Syllo/nvtop.git
      sudo mkdir -p ./nvtop/build && cd ./nvtop/build
      cmake .. -DNVML_RETRIEVE_HEADER_ONLINE=True
      make && sudo make install
      cd ../..
      rm -rf ./nvtop
    fi
    
    # check
    nvtop --version
  fi
  echo " "
  return 1
}

check_cuda() {
  # # install cuda runfile
  rm -rf ./cuda && mkdir ./cuda && cd ./cuda
  wget https://developer.download.nvidia.com/compute/cuda/11.0.3/local_installers/cuda_11.0.3_450.51.06_linux.run
  sudo sh cuda_11.0.3_450.51.06_linux.run
  rm ./cuda_11.0.3_450.51.06_linux.run
  cd .. && rm -rf ./cuda 
}

check_ssh
check_areyousure
if [ $areyousure -eq 1 ]; then
  check_init
  check_lotus_env
  check_ufw
  check_gpu
  check_nvtop
  check_cuda
  
fi
