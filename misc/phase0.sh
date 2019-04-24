# on cular-ingest as user cular

source ./ingest_vars.sh

# Set up working directories

mkdir -p $DATA_PATH
mkdir -p $METADATA_PATH

cd $INGEST_DIR
cp ../../ingest.jar .
cp ../../overflow/fixityDiff.jar .
cp ../../ingest_vars.sh .
cp ../../phase*.sh .

# copy over source manifest
cp $ASSET_SOURCE/$INGEST_MANIFEST .

# make symlinks to the assets to ingest
cd $DATA_PATH
ln -s $ASSET_SOURCE/* .
rm $INGEST_MANIFEST

# make symlinks to the metadata to ingest

cd $METADATA_PATH
ln -s $METADATA_SOURCE/* .



