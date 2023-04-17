#!/usr/bin/env bash

# export asi_s3_ingest_log_path='/cul/app/archival_storage_ingest/logs/ingest.log'
# export asi_ingest_dry_run=true
export asi_ingest_logger_polling_interval=5
# export asi_ingest_develop=true
# export asi_develop=true

export default_cular_log_path=/cul/app/archival_storage_ingest/logs
export PATH="$PATH:/cul/app/archival_storage_ingest/rvm"
source /cul/app/archival_storage_ingest/rvm/scripts/rvm
rvm gemset use archival_storage_ingest
archival_storage_server_log
