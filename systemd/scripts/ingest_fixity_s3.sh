#!/usr/bin/env bash

# export asi_s3_fixity_log_path='/cul/app/archival_storage_ingest/logs/fixity_s3.log'
# export asi_s3_fixity_debug=true
# export asi_s3_fixity_dry_run=true
# export asi_s3_fixity_bucket=s3-cular-dev
# export asi_s3_fixity_polling_interval=60

export PATH="$PATH:/cul/app/archival_storage_ingest/rvm"
source /cul/app/archival_storage_ingest/rvm/scripts/rvm
rvm gemset use archival_storage_ingest
archival_storage_server_ingest_fixity_s3
