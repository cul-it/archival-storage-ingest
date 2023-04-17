#!/usr/bin/env bash

# export asi_periodic_fixity_sfs_log_path='/cul/app/archival_storage_ingest/logs/ingest_fixity_sfs.log'
# export asi_periodic_fixity_sfs_debug=true
# export asi_periodic_fixity_sfs_dry_run=true
# export asi_periodic_fixity_sfs_bucket=s3-cular-dev
# export asi_periodic_fixity_sfs_polling_interval=60
# export asi_periodic_fixity_sfs_inhibit_file='/cul/app/archival_storage_ingest/control/ingest_fixity_sfs.inhibit'

export default_cular_log_path=/cul/app/archival_storage_ingest/logs
export use_lambda_logger=true
export PATH="$PATH:/cul/app/archival_storage_ingest/rvm"
source /cul/app/archival_storage_ingest/rvm/scripts/rvm
rvm gemset use archival_storage_ingest
archival_storage_server_periodic_fixity_sfs
