#!/usr/bin/env bash

# export asi_ingest_fixity_comparison_log_path='/cul/app/archival_storage_ingest/logs/compare_fixity.log'
# export asi_ingest_fixity_comparison_dry_run=true
# export asi_ingest_fixity_comparison_polling_interval=60
# export asi_ingest_fixity_comparison_inhibit_file='/cul/app/archival_storage_ingest/control/ingest_fixity_comparison.inhibit'
# export asi_ingest_fixity_comparison_develop=true
# export asi_develop=true

export PATH="$PATH:/cul/app/archival_storage_ingest/rvm"
source /cul/app/archival_storage_ingest/rvm/scripts/rvm
rvm gemset use archival_storage_ingest
archival_storage_server_ingest_fixity_comparison
