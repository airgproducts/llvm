# https://hub.docker.com/r/nvidia/cuda
# nvidia/cuda:latest-devel -> latest-compiler
# nvidia/cuda:latest-runtime -> latest-runtime
from nvidia/cuda:10.1-devel-centos8 as compilerbase

RUN dnf -y install dnf-plugins-core
RUN dnf config-manager --set-enabled powertools
RUN dnf -y groupinstall "Development Tools"
RUN dnf -y install python3 cmake ninja-build
ENV DPCPP_PKG /root/llvm_pkg

# build llvm
from compilerbase as buildstep

RUN dnf -y install gcc-c++

ENV DPCPP_BUILD /root/llvm
ENV DPCPP_SRC /root/llvm_src

ADD . $DPCPP_SRC
RUN mkdir -p $DPCPP_BUILD
RUN mkdir -p $DPCPP_PKG

RUN python $DPCPP_SRC/buildbot/configure.py --no-werror -o $DPCPP_BUILD -t release --cuda
RUN python $DPCPP_SRC/buildbot/compile.py -o $DPCPP_BUILD

WORKDIR $DPCPP_BUILD
RUN cmake --build . --target install
RUN cmake -DCMAKE_INSTALL_PREFIX=$DPCPP_PKG -P cmake_install.cmake
RUN tar -cf /root/llvm.tar -C $DPCPP_PKG .

RUN rm -rf $DPCPP_SRC
RUN rm -rf $DPCPP_BUILD


# install llvm
from compilerbase as compiler

COPY --from=builder /root/llvm.tar /tmp/llvm.tar
RUN tar -xf /tmp/llvm.tar -C / && rm /root/llvm.tar


# install llvm libs
from nvidia/cuda:10.1-runtime-centos8 as runtime

COPY --from=builder /root/llvm_pkg/lib /lib