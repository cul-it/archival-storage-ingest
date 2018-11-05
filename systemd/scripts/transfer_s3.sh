#!/usr/bin/env bash

export asi_log_path='/cul/app/archival_storage_ingest/logs/transfer_s3.log'
export asi_debug=false
export asi_dry_run=false

export PATH="$PATH:/cul/app/archival_storage_ingest/rvm"
source /cul/app/archival_storage_ingest/rvm/scripts/rvm
rvm gemset use archival_storage_ingest
archival_storage_ingest_server_s3_transfer
