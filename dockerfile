FROM ubuntu:20.04 as builder

# Install dependancies
RUN apt update && DEBIAN_FRONTEND=noninteractive apt install -y lcov \
    libelf1 libelf-dev libftdi1-2 libftdi1-dev libncurses5 libssl-dev \
    libudev-dev libusb-1.0-0 lsb-release texinfo autoconf cmake flex bison \
    libexpat-dev gawk tree xterm python3-venv python3-dev \
    git wget python3 \
    && rm -rf /var/lib/apt/lists/*

# Install GCC-RISC-V toolchain
RUN git clone --branch 2022.01.17 --recursive https://github.com/riscv/riscv-gnu-toolchain /riscv-gnu-toolchain
RUN cd /riscv-gnu-toolchain && ./configure --prefix=/tools/riscv --with-arch=rv32imc --with-abi=ilp32
RUN apt update && apt install -y gcc build-essential make
RUN cd /riscv-gnu-toolchain && make
RUN rm /riscv-gnu-toolchain -rf
ENV RISCV=/tools/riscv

# Install clang
RUN git clone https://github.com/llvm/llvm-project.git /llvm-project
RUN cd /llvm-project && git checkout llvmorg-14.0.0 && mkdir build 
RUN cd /llvm-project/build && cmake -G "Unix Makefiles" -DLLVM_ENABLE_PROJECTS=clang -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=$RISCV -DLLVM_TARGETS_TO_BUILD="RISCV" ../llvm
RUN cd /llvm-project/build && cmake --build . --target install
RUN rm -rf /llvm-project

# Install Verilator
ENV VERILATOR_VERSION=4.210
RUN git clone https://github.com/verilator/verilator.git && cd verilator && git checkout v$VERILATOR_VERSION
RUN cd /verilator && autoconf && ./configure --prefix=/tools/verilator/$VERILATOR_VERSION
RUN cd /verilator && make && make install
RUN rm /verilator -rf

# Install Verible
ENV VERIBLE_VERSION=v0.0-2135-gb534c1fe
RUN wget https://github.com/google/verible/releases/download/${VERIBLE_VERSION}/verible-${VERIBLE_VERSION}-Ubuntu-20.04-focal-x86_64.tar.gz
RUN mkdir -p /tools/verible && tar -xf verible-${VERIBLE_VERSION}-Ubuntu-20.04-focal-x86_64.tar.gz -C /tools/verible/
RUN rm verible-${VERIBLE_VERSION}-Ubuntu-20.04-focal-x86_64.tar.gz

# Install conda
RUN wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh
RUN bash Miniconda3-latest-Linux-x86_64.sh -b -p /opt/conda
RUN /opt/conda/bin/conda init bash
RUN rm Miniconda3-latest-Linux-x86_64.sh

# Install conda environment
COPY environment.yml .
RUN /opt/conda/bin/conda env create -f environment.yml

# instlal perl
RUN apt update && apt install -y libfindbin-libs-perl g++ curl

# Pull busybox image
FROM busybox:1.35.0-uclibc as busybox
 
# Pull distroless image
FROM gcr.io/distroless/cc-debian12
 
# Copy RISC-V toolchain from builder
COPY --from=builder /tools/riscv /tools/riscv

# Copy Verilator from builder
COPY --from=builder /tools/verilator /tools/verilator

# Copy Verible from builder
COPY --from=builder /tools/verible /tools/verible

# Copy conda from builder
COPY --from=builder /opt/conda /opt/conda

# Copy binaries from builder
COPY --from=builder /usr/bin/perl /usr/bin/perl
COPY --from=builder /usr/bin/env /usr/bin/env
COPY --from=builder /usr/bin/make /usr/bin/make
COPY --from=builder /usr/bin/cpan /usr/bin/cpan
COPY --from=builder /usr/bin/cmake /usr/bin/cmake
COPY --from=builder /usr/bin/g++ /usr/bin/g++
COPY --from=builder /usr/bin/as /usr/bin/as
COPY --from=builder /usr/bin/ar /usr/bin/ar
COPY --from=builder /usr/bin/ld /usr/bin/ld
COPY --from=builder /usr/bin/git /usr/bin/git
COPY --from=builder /usr/bin/curl /usr/bin/curl

# Copy libraries from builder
COPY --from=builder /usr/include/ /usr/include/
COPY --from=builder /usr/share/gcc /usr/share/gcc
COPY --from=builder /usr/share/perl /usr/share/perlgi
COPY --from=builder /usr/share/cmake /usr/share/cmake
COPY --from=builder /usr/share/cmake-3.16 /usr/share/cmake-3.16
COPY --from=builder /usr/share/perl5 /usr/share/perl5
COPY --from=builder /usr/share/perl/5.30 /usr/share/perl/5.30
COPY --from=builder /usr/share/git-core/templates /usr/share/git-core/templates
COPY --from=builder /lib /lib
COPY --from=builder /usr/lib/git-core /usr/lib/git-core
COPY --from=builder /usr/lib/gcc /usr/lib/gcc
COPY --from=builder /usr/lib/x86_64-linux-gnu /usr/lib/x86_64-linux-gnu
COPY --from=builder /usr/lib/x86_64-linux-gnu/perl/5.30 /usr/lib/x86_64-linux-gnu/perl/5.30
COPY --from=builder /usr/lib/x86_64-linux-gnu/perl5/5.30 /usr/lib/x86_64-linux-gnu/perl5/5.30
COPY --from=builder /usr/lib/x86_64-linux-gnu/perl-base /usr/lib/x86_64-linux-gnu/perl-base

# Copy perl binaries from builder
COPY --from=builder /etc/perl /etc/perl

# Copy bash and system binaries 
COPY --from=builder /bin/bash /bin/bash
COPY --from=builder /usr/bin/bash /usr/bin/bash
COPY --from=busybox /bin/sh /bin/sh
COPY --from=busybox /bin/mkdir /bin/mkdir
COPY --from=busybox /bin/cat /bin/cat
COPY --from=busybox /bin/dirname /bin/dirname
COPY --from=busybox /bin/rm /bin/rm
COPY --from=busybox /bin/which /bin/which
COPY --from=busybox /bin/ls /bin/ls
COPY --from=busybox /bin/ln /bin/ln
COPY --from=busybox /bin/echo /bin/echo
COPY --from=busybox /bin/tee /bin/tee
COPY --from=busybox /bin/sed /bin/sed
COPY --from=busybox /bin/find /bin/find
COPY --from=busybox /bin/tr /bin/tr

# Set environment variables
ENV RISCV=/tools/riscv

# Set PATH
ENV PATH=/tools/verible/verible-v0.0-2135-gb534c1fe/bin:/tools/verilator/4.210/bin:/opt/conda/envs/core-v-mini-mcu/bin:/opt/conda/condabin:/tools/riscv/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# Select workdir
WORKDIR /workspace/x-heep

# Set conda environment
RUN conda init bash

ENTRYPOINT ["/bin/bash"]
