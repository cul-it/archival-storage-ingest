#!/usr/bin/env bash

export archival_storage_ingest_config=/cul/app/archival_storage_ingest/conf/fixity_comparison.yaml

export PATH="$PATH:/cul/app/archival_storage_ingest/rvm"
source /cul/app/archival_storage_ingest/rvm/scripts/rvm
rvm gemset use archival_storage_ingest
archival_storage_ingest_server