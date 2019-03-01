FROM ubuntu:18.04

LABEL authors="Carmen Tawalika,Markus Neteler,Anika Bettge"
LABEL maintainer="tawalika@mundialis.de,neteler@mundialis.de,bettge@mundialis.de"

ENV DEBIAN_FRONTEND noninteractive

# define versions to be used
ARG GRASS_VERSION=7.7
ARG GRASS_SHORT_VERSION=77
ARG PDAL_VERSION=1.8.0
ARG PROJ_VERSION=4.9.3
ARG PROJ_DATUMGRID_VERSION=1.6
ARG LAZ_PERF_VERSION=1.3.0

SHELL ["/bin/bash", "-c"]

WORKDIR /tmp

RUN apt-get update && apt-get upgrade -y && \
    apt-get install -y --no-install-recommends --no-install-suggests \
    build-essential \
    bison \
    bzip2 \
    cmake \
    curl \
    flex \
    g++ \
    gcc \
    gdal-bin \
    git \
    language-pack-en-base \
    libbz2-dev \
    libcairo2 \
    libcairo2-dev \
    libcurl4-gnutls-dev \
    libfftw3-bin \
    libfftw3-dev \
    libfreetype6-dev \
    libgdal-dev \
    libgeos-dev \
    libgsl0-dev \
    libjpeg-dev \
    libjsoncpp-dev \
    libopenblas-base \
    libopenblas-dev \
    libnetcdf-dev \
    libncurses5-dev \
    libopenjp2-7 \
    libopenjp2-7-dev \
    libpnglite-dev \
    libpq-dev \
    libpython3-all-dev \
    libsqlite3-dev \
    libtiff-dev \
    libzstd-dev \
    make \
    mesa-common-dev \
    moreutils \
    ncurses-bin \
    netcdf-bin \
    python3 \
    python3-dateutil \
    python3-dev \
    python3-magic \
    python3-numpy \
    python3-pil \
    python3-pip \
    python3-ply \
    python3-setuptools \
    python3-venv \
    software-properties-common \
    sqlite3 \
    subversion \
    unzip \
    vim \
    wget \
    zip \
    zlib1g-dev

RUN echo LANG="en_US.UTF-8" > /etc/default/locale

## install the latest projection library for GRASS GIS
WORKDIR /src
RUN wget http://download.osgeo.org/proj/proj-${PROJ_VERSION}.tar.gz && \
    tar xzvf proj-${PROJ_VERSION}.tar.gz && \
    cd /src/proj-${PROJ_VERSION}/ && \
    wget http://download.osgeo.org/proj/proj-datumgrid-${PROJ_DATUMGRID_VERSION}.zip && \
    cd nad && \
    unzip ../proj-datumgrid-${PROJ_DATUMGRID_VERSION}.zip && \
    cd .. && \
    ./configure --prefix=/usr/ && \
    make && \
    make install

## install laz-perf
RUN apt-get install cmake
WORKDIR /src
RUN wget https://github.com/hobu/laz-perf/archive/${LAZ_PERF_VERSION}.tar.gz -O laz-perf-${LAZ_PERF_VERSION}.tar.gz && \
    tar -zxf laz-perf-${LAZ_PERF_VERSION}.tar.gz && \
    cd laz-perf-${LAZ_PERF_VERSION} && \
    mkdir build && \
    cd build && \
    cmake .. && \
    make && \
    make install

## fetch vertical datums and store into PROJ dir
WORKDIR /src
RUN mkdir vdatum && \
    cd /vdatum && \
    wget http://download.osgeo.org/proj/vdatum/usa_geoid2012.zip && unzip -j -u usa_geoid2012.zip -d /usr/share/proj; \
    wget http://download.osgeo.org/proj/vdatum/usa_geoid2009.zip && unzip -j -u usa_geoid2009.zip -d /usr/share/proj; \
    wget http://download.osgeo.org/proj/vdatum/usa_geoid2003.zip && unzip -j -u usa_geoid2003.zip -d /usr/share/proj; \
    wget http://download.osgeo.org/proj/vdatum/usa_geoid1999.zip && unzip -j -u usa_geoid1999.zip -d /usr/share/proj; \
    wget http://download.osgeo.org/proj/vdatum/vertcon/vertconc.gtx && mv vertconc.gtx /usr/share/proj; \
    wget http://download.osgeo.org/proj/vdatum/vertcon/vertcone.gtx && mv vertcone.gtx /usr/share/proj; \
    wget http://download.osgeo.org/proj/vdatum/vertcon/vertconw.gtx && mv vertconw.gtx /usr/share/proj; \
    wget http://download.osgeo.org/proj/vdatum/egm96_15/egm96_15.gtx && mv egm96_15.gtx /usr/share/proj; \
    wget http://download.osgeo.org/proj/vdatum/egm08_25/egm08_25.gtx && mv egm08_25.gtx /usr/share/proj; \
    cd .. && \
    rm -rf vdatum

## install pdal
ENV NUMTHREADS=4
WORKDIR /src
RUN wget \
 https://github.com/PDAL/PDAL/releases/download/${PDAL_VERSION}/PDAL-${PDAL_VERSION}-src.tar.gz && \
    tar xfz PDAL-${PDAL_VERSION}-src.tar.gz && \
    cd /src/PDAL-${PDAL_VERSION}-src && \
    mkdir build && \
    cd build && \
    cmake .. \
      -G "Unix Makefiles" \
      -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_INSTALL_PREFIX=/usr \
      -DCMAKE_C_COMPILER=gcc \
      -DCMAKE_CXX_COMPILER=g++ \
      -DCMAKE_MAKE_PROGRAM=make \
      -DBUILD_PLUGIN_PYTHON=ON \
      -DBUILD_PLUGIN_CPD=OFF \
      -DBUILD_PLUGIN_GREYHOUND=ON \
      -DBUILD_PLUGIN_HEXBIN=ON \
      -DHEXER_INCLUDE_DIR=/usr/include/ \
      -DBUILD_PLUGIN_NITF=OFF \
      -DBUILD_PLUGIN_ICEBRIDGE=ON \
      -DBUILD_PLUGIN_PGPOINTCLOUD=ON \
      -DBUILD_PGPOINTCLOUD_TESTS=OFF \
      -DBUILD_PLUGIN_SQLITE=ON \
      -DWITH_LASZIP=ON \
      -DWITH_LAZPERF=ON \
      -DWITH_TESTS=ON && \
    make -j $NUMTHREADS && \
    make install

# download grass gis source
WORKDIR /src
# this line should break docker cache if there are changes - weekly updated
ADD https://grass.osgeo.org/grass${GRASS_SHORT_VERSION}/source/snapshot/ChangeLog.gz /src/ChangeLog.gz
RUN wget https://grass.osgeo.org/grass${GRASS_SHORT_VERSION}/source/snapshot/grass-${GRASS_VERSION}.svn_src_snapshot_latest.tar.gz
RUN mkdir -p /src/grass_build && \
    tar xfz grass-$GRASS_VERSION.svn_src_snapshot_latest.tar.gz --strip=1 -C /src/grass_build && \
    rm -f grass-$GRASS_VERSION.svn_src_snapshot_latest.tar.gz
WORKDIR /src/grass_build
RUN svn update

# Set environmental variables for GRASS GIS compilation, without debug symbols
ENV INTEL "-march=native -std=gnu99 -fexceptions -fstack-protector -m64"
ENV MYCFLAGS "-O2 -fno-fast-math -fno-common $INTEL"
ENV MYLDFLAGS "-s -Wl,--no-undefined"
# CXX stuff:
ENV LD_LIBRARY_PATH "/usr/local/lib"
ENV LDFLAGS "$MYLDFLAGS"
ENV CFLAGS "$MYCFLAGS"
ENV CXXFLAGS "$MYCXXFLAGS"

# Fixup python shebangs - TODO: will be resolved in future by grass-core
WORKDIR /src/grass_build
RUN find -name '*.py' | xargs sed -i 's,#!/usr/bin/env python,#!/usr/bin/env python3,'
RUN sed -i 's,python,python3,' include/Make/Platform.make.in

# Configure compile and install GRASS GIS
ENV GRASS_PYTHON=/usr/bin/python3
ENV NUMTHREADS=4
RUN /src/grass_build/configure \
  --with-cxx \
  --enable-largefile \
  --with-proj --with-proj-share=/usr/share/proj \
  --with-gdal=/usr/bin/gdal-config \
  --with-geos \
  --with-sqlite \
  --with-cairo --with-cairo-ldflags=-lfontconfig \
  --with-freetype --with-freetype-includes="/usr/include/freetype2/" \
  --with-fftw \
  --with-postgres=yes --with-postgres-includes="/usr/include/postgresql" \
  --with-netcdf \
  --with-zstd \
  --with-bzlib \
  --with-pdal \
  --without-mysql \
  --without-odbc \
  --without-openmp \
  --without-ffmpeg \
  --without-opengl \
    && make -j $NUMTHREADS \
    && make install && ldconfig

# Unset environmental variables to avoid later compilation issues
ENV INTEL ""
ENV MYCFLAGS ""
ENV MYLDFLAGS ""
ENV MYCXXFLAGS ""
ENV LD_LIBRARY_PATH ""
ENV LDFLAGS ""
ENV CFLAGS ""
ENV CXXFLAGS ""

# set SHELL var to avoid /bin/sh fallback in interactive GRASS GIS sessions
ENV SHELL /bin/bash
ENV LC_ALL "en_US.UTF-8"
ENV GRASS_SKIP_MAPSET_OWNER_CHECK 1

# Create generic GRASS GIS binary name regardless of version number
RUN ln -sf `find /usr/local/bin -name "grass??" | sort | tail -n 1` /usr/local/bin/grass

RUN grass --config svn_revision version

# Reduce the image size
RUN apt-get autoremove -y
RUN apt-get clean -y

RUN mkdir /scripts
WORKDIR /scripts

ADD requirements.txt /scripts
RUN pip3 install -r /scripts/requirements.txt

# TODO: is there a better workaround to install addons?
RUN update-alternatives --install /usr/bin/python python /usr/bin/python3 1
RUN grass --tmp-location EPSG:4326 --exec g.extension extension=r.in.pdal
RUN update-alternatives --remove python /usr/bin/python3

# Fixup python shebangs - TODO: will be resolved in future by grass-core
WORKDIR /root/.grass7/addons/scripts
RUN find -type f | xargs sed -i 's,#!/usr/bin/env python,#!/usr/bin/env python3,'

# add GRASS GIS envs for python usage
ENV GISBASE "/usr/local/grass77/"
ENV GRASSBIN "/usr/local/bin/grass"
ENV PYTHONPATH "${PYTHONPATH}:$GISBASE/etc/python/"
ENV LD_LIBRARY_PATH "$LD_LIBRARY_PATH:$GISBASE/lib"

ADD src/test_grass_session.py /scripts
ADD testdata/simple.laz /tmp

ENTRYPOINT ["/bin/bash"]
