#!/usr/bin/env bash

# export asi_transfer_s3_log_path='/cul/app/archival_storage_ingest/logs/transfer_s3.log'
# export asi_transfer_s3_dry_run=true
# export asi_transfer_s3_polling_interval=60
# export asi_transfer_s3_inhibit_file='/cul/app/archival_storage_ingest/control/transfer_s3.inhibit'
# export asi_transfer_s3_develop=true
# export asi_develop=true

export default_cular_log_path=/cul/app/archival_storage_ingest/logs
export use_lambda_logger=true
export PATH="$PATH:/cul/app/archival_storage_ingest/rvm"
source /cul/app/archival_storage_ingest/rvm/scripts/rvm
rvm gemset use archival_storage_ingest
archival_storage_server_transfer_s3
