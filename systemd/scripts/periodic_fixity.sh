#!/usr/bin/env bash

# export asi_periodic_fixity_log_path='/cul/app/archival_storage_ingest/logs/periodic_fixity.log'
# export asi_periodic_fixity_dry_run=true
# export asi_periodic_fixity_polling_interval=60
# export asi_periodic_fixity_develop=true
# export asi_develop=true

export default_cular_log_path=/cul/app/archival_storage_ingest/logs
export use_lambda_logger=true
export PATH="$PATH:/cul/app/archival_storage_ingest/rvm"
source /cul/app/archival_storage_ingest/rvm/scripts/rvm
rvm gemset use archival_storage_ingest
archival_storage_server_periodic_fixity_check
