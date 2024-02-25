#!/bin/bash

cd $HOME

apt update

## build grpc
if [ ! -d grpc ]; then

     apt-get install -y \
       build-essential \
	  autoconf \
	  libtool \
	  pkg-config \
	  libgflags-dev \
	  libgtest-dev \
	  clang-5.0 \
	  libc++-dev
     
     git clone https://github.com/grpc/grpc.git
     git checkout tags/v1.31.0
     rm /root/grpc/.gitmodules
     cp /root/efs/hoplite/.gitmodules /root/grpc/.gitmodules
     pushd grpc
     git submodule update --init --recursive

     mkdir build && cd build
     cmake .. -DCMAKE_INSTALL_PREFIX=/usr/local
     make -j8 && make install
     popd

     pushd grpc/third_party/protobuf
     ./autogen.sh
     ./configure
     make -j8 && make install
     popd
fi
