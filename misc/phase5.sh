# on cular-ingest as user cular

source ./ingest_vars.sh

# make symlinks to the metadata to ingest

mkdir -p $METADATA_PATH
pushd $METADATA_PATH
ln -s $METADATA_SOURCE/* .
popd

# configure CULAR 

cat <<EOF > ${COLLECTION}_ingest.config
<?xml version="1.0" encoding="UTF-8"?>
<!-- config -->
<!DOCTYPE properties SYSTEM "http://java.sun.com/dtd/properties.dtd">
<properties version="1.0">
 
<entry key="repository-protocol">https</entry>
<entry key="repository-host">cular.library.cornell.edu</entry>
<entry key="repository-port">8443</entry>
<entry key="repository-user">fedoraAdmin</entry>
<entry key="repository-pass">facing-entirely-comfortable-task</entry>
 
<entry key="signed-certificate">no</entry>
<entry key="temp-web-directory">/cul/web/cular-ingest.library.cornell.edu/htdocs/cular</entry>
<entry key="temp-sip-directory">/cul/data/cular_prod_ingest/SIP/tmp_sip_dir</entry>
<entry key="ingest-host-address">http://cular-ingest.library.cornell.edu/cular</entry>
 
<entry key="collection-altid">local:collection/rmc</entry>
<entry key="start-altid">file:$DEPCOL</entry>
<entry key="data-path">$INGEST_DIR/metadata/${DEPOSITOR%/*}</entry>
<entry key="collection-metadata">$COLLECTION.xml</entry>
<entry key="add-only">true</entry>
 
</properties>

EOF

mkdir -p plans
mv plan*.xml plans

java -jar ingest.jar --ingestConfig=${COLLECTION}_ingest.config --planOnly

mv plan*.xml ${COLLECTION}_plan.xml

java -jar ingest.jar --ingestConfig=${COLLECTION}_ingest.config --plan=${COLLECTION}_plan.xml



