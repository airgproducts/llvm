from fedora:latest

RUN dnf -y groupinstall "Development Tools"
RUN dnf -y install python cmake ninja-build gcc-c++

# Install cuda

# install config-manager
RUN dnf -y install dnf-plugins-core
RUN dnf -y config-manager --add-repo https://developer.download.nvidia.com/compute/cuda/repos/fedora33/x86_64/cuda-fedora33.repo
RUN dnf -y clean all
#RUN dnf -y module disable nvidia-driver
RUN dnf -y install cuda

ENV DPCPP_BUILD /root/llvm
ENV DPCPP_SRC /root/llvm_src

ADD . $DPCPP_SRC
RUN mkdir -p $DPCPP_BUILD

RUN python $DPCPP_SRC/buildbot/configure.py --no-werror -o $DPCPP_BUILD -t release --cuda
RUN python $DPCPP_SRC/buildbot/compile.py -o $DPCPP_BUILD

WORKDIR $DPCPP_BUILD
RUN cmake --build . --target install
RUN cmake -DCMAKE_INSTALL_PREFIX=/ -P cmake_install.cmake

RUN rm -rf $DPCPP_SRC
RUN rm -rf $DPCPP_BUILD