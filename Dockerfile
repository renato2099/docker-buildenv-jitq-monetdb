FROM ingomuellernet/llvmgold:7.0.1 as gold-builder
FROM ingomuellernet/boost as boost-builder
FROM ingomuellernet/cppcheck as cppcheck-builder

FROM ubuntu:xenial
MAINTAINER R Marroquin <marenato@inf.ethz.ch>

# Basics
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
        build-essential \
        git \
        python3-pip \
        wget \
        xz-utils \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Clang+LLVM
RUN mkdir /opt/clang+llvm-7.0.1/ && \
    cd /opt/clang+llvm-7.0.1/ && \
    wget http://releases.llvm.org/7.0.1/clang+llvm-7.0.1-x86_64-linux-gnu-ubuntu-16.04.tar.xz -O - \
         | tar -x -I xz --strip-components=1 && \
    for file in bin/*; \
    do \
        ln -s $PWD/$file /usr/bin/$(basename $file)-7.0; \
    done && \
    cp /opt/clang+llvm-7.0.1/lib/libomp.so /opt/clang+llvm-7.0.1/lib/libomp.so.5

# Copy llvm gold plugin over from builder
COPY --from=gold-builder /tmp/llvm-7.0.1.src/build/lib/LLVMgold.so /opt/clang+llvm-7.0.1/lib

# Cmake
RUN mkdir /opt/cmake-3.13.4/ && \
    cd /opt/cmake-3.13.4/ && \
    wget https://cmake.org/files/v3.13/cmake-3.13.4-Linux-x86_64.tar.gz -O - \
        | tar -xz --strip-components=1 && \
    for file in bin/*; \
    do \
        ln -s $PWD/$file /usr/bin/$(basename $file)-3.13; \
    done

# Copy cppcheck over from builder
COPY --from=cppcheck-builder /opt/ /opt/

RUN for bin in /opt/cppcheck-1.*/bin/cppcheck-1.*; do \
        ln -s $bin /usr/bin/; \
    done

# Copy boost over from builder
COPY --from=boost-builder /opt/ /opt/

RUN for file in /opt/boost-1.*/include/*; do \
        ln -s $file /usr/include/; \
    done && \
    for file in /opt/boost-1.*/lib/*; do \
        ln -s $file /usr/lib/; \
    done

# Other packages
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
        libgraphviz-dev \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
    automake m4 python2.7 gettext curl bison libssl-dev pkg-config\
    && apt-get clean && rm -rf /var/lib/apt/lists/*

RUN ln -s /usr/bin/python2.7 /usr/bin/python

RUN cd /tmp && git clone https://github.com/MonetDB/MonetDB.git && \
    mkdir /opt/monetdb-build

RUN cd /tmp/MonetDB && /tmp/MonetDB/bootstrap && \
    /tmp/MonetDB/configure --prefix=/opt/monetdb-build/ --disable-strict --disable-assert --disable-debug --enable-optimize && \
    make && make install

# Python packages
RUN pip3 install --upgrade \
        autopep8 \
        cffi \
        dask \
        jsonmerge \
        matplotlib \
        numba \
        numpy \
        pandas \
        pip \
        psutil \
        pylint \
        pyspark \
        scipy \
        sklearn \
    && rm -r ~/.cache/pip
# Expose port 50000
EXPOSE 50000

RUN echo "#!/bin/bash" > /opt/start.sh && \
    echo "/opt/monetdb-build/bin/mserver5 --daemon=yes --set embedded_c=true --set embedded_py=true &" >> /opt/start.sh && \
    chmod ugo+x /opt/start.sh

#CMD /opt/start.sh && bash
CMD /opt/start.sh

