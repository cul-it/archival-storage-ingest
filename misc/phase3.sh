# on cular-ingest as user cular

source ./ingest_vars.sh

cd $INGEST_DIR

cat <<EOF > ${COLLECTION}_fixity.config
{
  "collections": {
    "$DEPCOL": {
      "result_directory": "/cul/app/ingest/overflow/manifest",
      "data_path": "/cul/data/$SFS_SHARE/${DEPOSITOR%/*}",
      "prefix_to_trim": "$DEPCOL"
    }
  }
}
EOF

java -jar ingest.jar --op=script --script=generateManifestSFS --configPath=${COLLECTION}_fixity.config

echo
echo "Comparing ingest manifest to SFS fixity manifest"
echo

cp ../../overflow/manifest/*${COLLECTION_SFS}.json .

java -jar fixityDiff.jar _EM*.json.fixed *${COLLECTION}_SFS.json

