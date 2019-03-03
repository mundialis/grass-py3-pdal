# grass-py3-pdal
Repo which contains a Dockerfile to compile latest GRASS GIS (trunk, currently grass77) with Python-3 and PDAL support

# Installation

```bash
docker pull mundialis/grass-py3-pdal
```

# Usage

Note: This docker image contains a link from the current `grass7x` start script to a generic `grass` script:

## Show version

```bash
docker run --rm mundialis/grass-py3-pdal grass --version
```

This will display the version and copyright statement.

## Use convenient alias to start GRASS GIS on command line

In order to simplify the use through docker, consider to define an alias.
Note that this variant will remove the docker container immediately after usage
in order to not increasingly consume dist space.
The alias is useful both for a single command or for executing a script:

```bash
# the alias does the following
# - runs docker container and removes it  at exit
# - mounts current directory into docker container under /data/
# - runs GRASS GIS inside with current user/group, in order to avoid writing out data as root user
# - uses /tmp/ in docker container to avoid write permission issues
alias grass_docker="docker run -v $PWD:/data --user $(id --user):$(id --group) -e "HOME=/tmp/" --rm mundialis/grass-py3-pdal grass"

# run dockerized GRASS GIS via alias
grass_docker --version
```

## Show detailed SVN revision number

```bash
# using alias from above
grass_docker --config svn_revision version
```

## Run a PDAL test with an included LAZ file

The `simple.laz` file (originating from [PDAL test data](https://github.com/PDAL/PDAL/tree/master/test/data/laz)
is included in this Docker image under /tmp/. It can be scanned by GRASS GIS using the r.in.pdal addon (also included):

```bash
# using alias from above
grass_docker -c epsg:4326 --tmp-location --exec r.in.pdal -sg input=/tmp/simple.laz output=dummy
 Starting GRASS GIS...
 Creating new GRASS GIS location <tmploc>...
 Cleaning up temporary files...
 Executing <r.in.pdal -sg input=/tmp/simple.laz output=dummy> ...
 n=853535.43 s=848899.7 w=635619.85 e=638982.55 t=586.38 b=406.59
 Execution of <r.in.pdal -sg input=/tmp/simple.laz output=dummy> finished.
 Cleaning up temporary files...
```

## Executing a script: zonal statistics

Instead of a single GRASS GIS command also a sequence, stored in a text file, can be executed:

```bash
# download North Carolina, USA, elevation raster map to current directory
wget https://apps.mundialis.de/workshops/osgeo_ireland2017/north_carolina/elev_state_500m.tif
gdalinfo elev_state_500m.tif

# download Raleigh, NC USA, ZIP code vector map (Geopackage) to current directory
wget https://apps.mundialis.de/workshops/osgeo_ireland2017/north_carolina/zipcodes_wake.gpkg
ogrinfo -al -so zipcodes_wake.gpkg
```

We now have two spatial datasets downloaded. The spatial reference system of these
North Carolina data is EPSG:32119, NAD83 / North Carolina (see also [https://epsg.io/32119](https://epsg.io/32119)).

Next we write a script to analyse these datasets in order to compute the minimum, average,
maximum elevation as well as 1st and 3rd quartiles per ZIP code area. Store the following
code block as a text file `grass_zonal_stats.sh` in the current directory:

```bash
# note that the current directory is mounted under /data/ in the docker container
#  import datasets
r.import input=/data/elev_state_500m.tif output=elev_state_500m
v.import input=/data/zipcodes_wake.gpkg output=zipcodes_wake

# check metadata
r.info elev_state_500m
v.info zipcodes_wake

# set computational region to vector map and pixel geometry to raster map
#  see https://grasswiki.osgeo.org/wiki/Computational_region
g.region vector=zipcodes_wake align=elev_state_500m -p

# enrich attribute table of 'zipcodes_wake' with additional columns
v.rast.stats map=zipcodes_wake raster=elev_state_500m column_prefix=elev method=minimum,maximum,average,first_quartile,third_quartile

# export result outside of GRASS GIS/docker image to current directory
v.out.ogr input=zipcodes_wake output=/data/zipcodes_wake_elev_stats.gpkg
```

The stored script is then run as follows:

```bash
# note: via alias the current directory is mounted under /data/ in the docker container
grass_docker -c epsg:32119 --tmp-location --exec bash /data/grass_zonal_stats.sh
```

After successful completion the resulting vector maps `zipcodes_wake_elev_stats.gpkg` is found
in the current directory.

```bash
# check metadata of new map
ogrinfo -al -so zipcodes_wake_elev_stats.gpkg

# look at it e.g. in QGIS
qgis zipcodes_wake_elev_stats.gpkg
```
