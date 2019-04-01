#!/usr/bin/env bash

# export asi_transfer_sfs_log_path='/cul/app/archival_storage_ingest/logs/transfer_sfs.log'
# export asi_transfer_sfs_dry_run=true
# export asi_transfer_sfs_polling_interval=60
# export asi_transfer_sfs_inhibit_file='/cul/app/archival_storage_ingest/control/transfer_sfs.inhibit'
# export asi_transfer_sfs_develop=true
# export asi_develop=true

export PATH="$PATH:/cul/app/archival_storage_ingest/rvm"
source /cul/app/archival_storage_ingest/rvm/scripts/rvm
rvm gemset use archival_storage_ingest
archival_storage_server_transfer_sfs
