#!/usr/bin/env bash

# export asi_s3_ingest_log_path='/cul/app/archival_storage_ingest/logs/ingest.log'
# export asi_ingest_debug=true
# export asi_ingest_dry_run=true
# export asi_ingest_s3_bucket=s3-cular-dev
# export asi_ingest_polling_interval=60

export PATH="$PATH:/cul/app/archival_storage_ingest/rvm"
source /cul/app/archival_storage_ingest/rvm/scripts/rvm
rvm gemset use archival_storage_ingest
archival_storage_server_ingest
