# on cular-ingest as user cular

source ./ingest_vars.sh

cd $INGEST_DIR

java -jar ingest.jar \
    --op=script \
    --script=convertIngestManifestToCollectionManifest \
    --jsonManifest=$INGEST_MANIFEST.fixed \
    --dataPathPrefix=$DEPCOL \
    --sfsLocation=archival02

cp $INGEST_MANIFEST.fixed.collection_manifest /cul/data/$SFS_SHARE/$DEPCOL/$INGEST_MANIFEST
aws s3 cp $INGEST_MANIFEST.fixed.collection_manifest s3://s3-cular/$DEPCOL/$INGEST_MANIFEST
