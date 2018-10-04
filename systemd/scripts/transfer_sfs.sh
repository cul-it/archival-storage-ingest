#!/usr/bin/env bash

export archival_storage_ingest_config=/cul/app/archival_storage_ingest/conf/transfer_sfs.yaml

export PATH="$PATH:/cul/app/archival_storage_ingest/rvm"
source /cul/app/archival_storage_ingest/rvm/scripts/rvm
rvm gemset use archival_storage_ingest_gemset
archival_storage_ingest_server