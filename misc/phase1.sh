# on cular-ingest as user cular

source ./ingest_vars.sh

cd $INGEST_DIR

java -jar ingest.jar --op=script --script=populateMissingJsonAttribute --dataPath=assets/${DEPOSITOR%%/*} --jsonManifest=$INGEST_MANIFEST

# This creates a new manifest named ${INGEST_MANIFEST}.fixed
