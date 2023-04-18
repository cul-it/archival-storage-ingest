#!/usr/bin/env bash

# export asi_dead_letter_monitor_log_path='/cul/app/archival_storage_ingest/logs/dead_letter_monitor.log'
# export asi_develop=true
# export asi_dead_letter_monitor_develop=true

export default_cular_log_path=/cul/app/archival_storage_ingest/logs
export PATH="$PATH:/cul/app/archival_storage_ingest/rvm"
source /cul/app/archival_storage_ingest/rvm/scripts/rvm
rvm gemset use archival_storage_ingest
dead_letter_monitor
