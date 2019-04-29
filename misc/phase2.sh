# on cular-ingest as user cular

source ./ingest_vars.sh

cd $INGEST_DIR

time rsync -rk \
    --exclude=.DS_Store \
    --exclude=Thumbs.db \
    --exclude=.BridgeCache \
    --exclude=.BridgeCacheT \
    $DATA_PATH /cul/data/$SFS_SHARE/$DEPOSITOR

time aws s3 cp --recursive \
    --exclude="*/.DS_Store" \
    --exclude="*/Thumbs.db" \
    --exclude="*/.BridgeCacheT" \
    --exclude="*/.BridgeCache" \
    $DATA_PATH s3://s3-cular/$DEPOSITOR/$COLLECTION