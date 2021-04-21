# https://hub.docker.com/r/nvidia/cuda
# nvidia/cuda:latest-devel -> latest-compiler
# nvidia/cuda:latest-runtime -> latest-runtime
FROM fedora:latest AS base

ENV CV=11-2

RUN dnf -y update
RUN dnf -y install dnf-plugins-core
RUN dnf -y config-manager --add-repo https://developer.download.nvidia.com/compute/cuda/repos/fedora33/x86_64/cuda-fedora33.repo
RUN dnf -y clean all

RUN dnf -y install cuda-runtime-$CV cuda-compat-$CV cuda-libraries-$CV cuda-nvtx-$CV libcublas-$CV
RUN dnf install -y ocl-icd-devel

# https://forums.developer.nvidia.com/t/issues-running-deepstream-on-wsl2-docker-container-usr-lib-x86-64-linux-gnu-libcuda-so-1-file-exists-n-unknown/139700/3
ENV LD_LIBRARY_PATH="/usr/lib:/usr/lib64:/usr/local/lib:/usr/local/lib64"
RUN mv /usr/lib64/libcuda.so* /usr/local/lib64/
RUN mv /usr/lib64/libnvidia-ml* /usr/local/lib64/
RUN ldconfig

FROM base AS compilerbase

RUN echo "exclude=clang" >> /etc/dnf/dnf.conf

RUN dnf -y install cuda
RUN dnf -y groupinstall "Development Tools"
RUN dnf -y install python cmake ninja-build
ENV DPCPP_PKG /root/llvm_pkg
RUN echo "/usr/local/lib" > /etc/ld.so.conf.d/99local.conf

# build llvm
FROM compilerbase AS buildstep

RUN dnf -y install gcc-c++

ENV DPCPP_BUILD /root/llvm
ENV DPCPP_SRC /root/llvm_src

ADD . $DPCPP_SRC
RUN mkdir -p $DPCPP_BUILD

# install to /usr
RUN mkdir -p $DPCPP_PKG/usr

RUN python3 $DPCPP_SRC/buildbot/configure.py --no-werror -o $DPCPP_BUILD -t release --cuda
RUN python3 $DPCPP_SRC/buildbot/compile.py -o $DPCPP_BUILD

RUN tar -cf /root/llvm.tar -C $DPCPP_BUILD/install .

# install llvm
FROM compilerbase AS compiler

RUN --mount=type=bind,from=buildstep,target=/root/build,source=/root tar -C /usr/local -xvf /root/build/llvm.tar
RUN ldconfig

# install llvm libs
FROM base AS runtime

RUN --mount=type=bind,from=buildstep,target=/root/build,source=/root tar -C /usr/local -xvf /root/build/llvm.tar ./lib
RUN ldconfig
