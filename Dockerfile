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


FROM base AS compilerbase

RUN dnf -y install cuda
RUN dnf -y groupinstall "Development Tools"
RUN dnf -y install python cmake ninja-build
ENV DPCPP_PKG /root/llvm_pkg

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

WORKDIR $DPCPP_BUILD
RUN cmake --build . --target deploy-sycl-toolchain

# install llvm
FROM compilerbase AS compiler

COPY --from=buildstep /root/llvm/install/bin/* /usr/bin/
COPY --from=buildstep /root/llvm/install/lib/* /usr/lib/
COPY --from=buildstep /root/llvm/install/include/* /usr/include/

# install llvm libs
FROM base AS runtime

COPY --from=buildstep /root/llvm/install/lib/* /usr/lib/
