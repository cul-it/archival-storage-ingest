# on cular-ingest as user cular

# set up variables from DCS

export DEPOSITOR=RMC/RMA
export COLLECTION=RMA02817_New_York_State_College_Human_Ecology
export ASSET_SOURCE=/cul/data/rmcdata2/${COLLECTION}/FOR_CULAR
export INGEST_MANIFEST=_EM_${DEPOSITOR/\//_}_$COLLECTION.json
export METADATA_SOURCE=/cul/data/ingest_share/$DEPOSITOR/$COLLECTION
export SFS_SHARE=archival02

# set up variables derived from above

export DEPCOL=$DEPOSITOR/$COLLECTION
export INGEST_DIR=/cul/app/ingest/ingests/$COLLECTION
export DATA_PATH=$INGEST_DIR/assets/$DEPCOL
export METADATA_PATH=$INGEST_DIR/metadata/$DEPCOL


echo "Depositor=$DEPOSITOR"
echo "Collection=$COLLECTION"
echo "Asset Source=$ASSET_SOURCE"
echo "Ingest Manifest=$INGEST_MANIFEST"
echo "Metadata Source=$METADATA_SOURCE"
echo "SFS Share=$SFS_SHARE"
echo
echo "Ingest dir=$INGEST_DIR"
echo "Data Path=$DATA_PATH"
echo "Metadata Path=$METADATA_PATH"



