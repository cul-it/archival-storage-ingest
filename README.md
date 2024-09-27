# Archival Storage Ingest

[![Coverage Status](https://coveralls.io/repos/github/cul-it/archival-storage-ingest/badge.svg?branch=master)](https://coveralls.io/github/cul-it/archival-storage-ingest?branch=master)
[![Build Status](https://travis-ci.org/cul-it/archival-storage-ingest.svg?branch=master)](https://travis-ci.org/cul-it/archival-storage-ingest)

Archival storage ingest is a ruby gem for automating parts of the ingest process.

1. [Installation and configuration](#Installation)
1. [Usage](#Usage)
1. [Behavior](#Behavior)
1. [Workflow](#Workflow)
1. [Implementation details](#Implementation)

<a name="Installation"/>

## Installation

#### Archival storage ingest installation

This guide assumes that rvm is installed under /cul/app/archival_storage_ingest/rvm.

```bash
curl -sSL https://get.rvm.io | bash -s -- --path /cul/app/archival_storage_ingest/rvm
```

If it is installed at a different location, make a symlink to above path.

After cloning from GitHub repository (https://github.com/cul-it/archival-storage-ingest), run the following command.

```bash
$ bundle install
$ rake install
```

#### AWS Configuration

It uses AWS Ruby SDK.
As per the installation guide (https://docs.aws.amazon.com/sdk-for-ruby/v3/developer-guide/setup-install.html),
run the following command.

    $ gem install aws-sdk

After the installation, credentials should be configured.
(https://docs.aws.amazon.com/sdk-for-ruby/v3/developer-guide/setup-config.html).

Either correct environment variables must be set or ~/.aws/credentials file must be created.

If you already have AWS CLI installed, you could run the following command for the configuration.

    $ aws configure

The region must be set to us-east-1.

#### Systemd service setup

For production environments, the gem should be set to run as service.
We may implement a runnable command to handle this part in the future.

Inside the systemd directory of this project, there are conf, scripts and service directory.
- service directory contains systemd service files.
- scripts directory contains shell scripts used by the systemd service.

As cular user, make symlinks of conf and scripts directory and create log directory.
```bash
$ ln -s PROJECT_DIR/systemd/scripts /cul/app/archival_storage_ingest/scripts
$ mkdir /cul/app/archival_storage_ingest/logs
```

Copy service files to a location systemd can recognize.
```bash
$ cp PROJECT_DIR/systemd/service/*.service /etc/systemd/system/
```

Testing
```bash
$ systemctl status fixity_check_sfs
```

Above command should display message similar to the following.
```bash
● fixity_check_sfs.service - Archival Storage Fixity Check SFS Server
   Loaded: loaded (/etc/systemd/system/fixity_check_sfs.service; disabled; vendor preset: disabled)
   Active: inactive (dead)
   ...
```

If you get "Unit fixity_check_sfs could not be found.", check for your OS systemd manual for where to put the service files.

Enabling service
```bash
$ systemctl enable SERVICE
```

On cular-ingest server, you should enable the following services.
- fixity_check_sfs
- fixity_comparison
- ingest
- transfer_s3
- transfer_sfs

On S3 fixity checking VM, enable the following service.
- fixity_check_s3

#### Graceful shutdown of the service

Using `systemctl stop <servicename>` will cause the running service to terminate immediately, even in the middle of
processing an item in the queue. This potentially leaves the system in a bad state.

To prevent this, the services are configured to look for the presence of an "inhibit" file at `/cul/app/archival_storage_ingest/control/<service>.inhibit`
to tell a specific service it should gracefully shutdown after finishing its current work, and to look at `/cul/app/archival_storage_ingest/control/archival_storage.inhibit` to gracefully shut down all services.

<a name='Usage'>

## Usage

    $ archival_storage_ingest -i [PATH_TO_INGEST_CONFIG_FILE]

-i flag will queue a new ingest as described in the ingest config file.

## Example ingest config file
    ---
    depositor: DEPOSITOR
    collection: COLLECTION
    dest_path: /cul/data/archivalxx/DEPOSITOR/COLLECTION
    ingest_manifest: /PATH_TO/_EM_DEPOSITOR_COLLECTION.json

The _EM_DEPOSITOR_COLLECTION.json must be conforming to the new ingest JSON format as specified in https://github.com/cul-it/cular-metadata/.

It requires that by combining the source_path and filepath from the ingest manifest, you get the absolute path of the asset.

Also, by combining the dest_path from the ingest config and the filepath from the ingest manifest, you get the absolute path of the SFS destination.

It still relies on the depositor and collection attributes to generate the S3 keys.

## Development

For development, you could also create a test gemset via RVM as well with the following command before installation.

    $ rvm gemset create archival_storage_ingest

Each services and queuer can be run in develop mode by setting specific environment variable. To run it in develop mode, set the desired environment variable with any value such as 1. To disable it, simply unset the environment variable.

Under the develop mode, the application will use develop queues, S3 bucket. In case of each services, it will run the code once and terminate.

This is useful for integration test.

There is a global develop environment variable and specific environment variables for each services.
- asi_develop (global)
- asi_queue_develop
- asi_ingest_develop
- asi_ingest_transfer_s3_develop
- asi_ingest_transfer_sfs_develop
- asi_ingest_fixity_s3_develop
- asi_ingest_fixity_comparison_develop

There are environment variables for periodic fixity services but we currently do not have develop queues for these and will use production queues.

## Message

```json
{
  "job_id": "ee4b25f4-d67a-4110-9a8d-2dcf5497fd7a",
  "depositor": "RMC/RMA",
  "collection": "RMA1234",
  "dest_path": "/cul/data/archival02/RCM/RMA/RMA1234",
  "ingest_manifest": "/cul/data/somewhere/_EM_RMC_RMA_RMA1234_ExampleCollection.json",
  "ticket_id": "CULAR-1937"
}
```

job_id is generated when a new ingest is queued by a user and persists through all of the steps for that ingest.

ingest_manifest is used by the workers down in the pipeline.

ticket_id is the JIRA ticket id which the application will comment its progress.

When a new ingest is queued successfully, it will add comment to the ticket with a message containing the timestamp, depositor/collection and the message sent to the ingest queue, similar to the following.

```ticket_update
New ingest queued at 2019-03-28 15:29:39 -0400.
Depositor/Collection: test_depositor/test_collection
Ingest Info

{ "job_id": "ee4b25f4-d67a-4110-9a8d-2dcf5497fd7a", "dest_path": "/cul/app/archival_storage_ingest/data/target/test_depositor/test_collection", "depositor": "test_depositor", "collection": "test_collection", "ingest_manifest": "/cul/app/archival_storage_ingest/ingest/test/manifest/ingest_manifest/test.json", "ticket_id": "CULAR-1937" }
```

For each services, it will add comment to the ticket with its progress with timestamp, worker name, depositor/collection and the status such as the following.

```ticket_update
2019-03-28 15:30:29 -0400
Ingest Initiator
Depositor/Collection: test_depositor/test_collection
Ingest ID: ee4b25f4-d67a-4110-9a8d-2dcf5497fd7a
Status: Started
```

<a name="Behavior"/>

## Behavior

* Each service is run as a systemd service and has its own logs.
* Each service works on a dedicated queue.
* Each service will try to poll one message from its designated queue periodically.
* Each service is set to restart on failures. This means that if the service exits normally, systemd won't restart it automatically.
* cular-ingest server uses ingest, transfer s3, transfer sfs, fixity check sfs and fixity comparison services.
* AWS fixity checking VM uses fixity check s3 service only.
* Each services as well as the queuer will update the JIRA ticket specified in the ingest message its progress.

<a name="Workflow"/>

## Workflow

1. Each service polls for a message from SQS periodically (in progress then work queue).
2. If a message from in progress queue is received, exit normally. *
3. When a service receives a message from the work queue, it logs the contents of the message.
4. The message is put to "in progress" queue of the same work type.
5. The original message is deleted from the work queue.
6. The service completes work task.
7. Send message for next work. E.g. Upon completing transfer s3 task, send new message to fixity check s3 queue with same job_id.
8. The message put to in progress queue earlier in this process is deleted.

- If a message is received from in progress queue, it means the service did not complete the job. It will notify admins and exit normally which would make the systemd to not start the service again.
When the problem is resolved, admins should start the service manually.

- Each SQS request would have up to 3 retries. If it still fails after the retries, the service should notify admins and exit normally.

Following diagram describes the work flow.

![Worker Communication](images/worker_communication.png)

<a name="Implementation"/>

## Implementation details

With the new ingest JSON format update (https://github.com/cul-it/cular-metadata/), the behavior of the application is also updated.

In the previous version of the application, the expectation was that by combining the data_path, depositor, collection and filepath attributes, you would get the absolute path of the source asset and dest_path, depositor, collection and filepath attributes for the target SFS location. (The filepath was generated on the fly by combining keys in the old ingest manifest.)

The new format requires each package in the ingest manifest to specify source_path attribute. The expectation is that by combining the source_path and the filepath attributes for each file in the package, you would get the absolute path of the source asset. Thus, the data_path attribute is deprecated and not supported. By the same token, combining the dest_path and filepath would give you the target SFS location.

Please note that the S3 key generation still relies on depositor and collection attributes.

### Ingest queuer

Invocation:

    $ archival_storage_ingest -i [PATH_TO_INGEST_CONFIG_FILE]

It makes basic checks on the ingest settings as specified in the config file.
For the ingest config file:
- The dest_path must be a valid directory.
- The ingest_manifest must be a valid JSON file.
- Inside the ingest manifest, each of the source_path attribute must be a valid directory.

When all of the checks pass, it prompts user for the final confirmation before queuing the ingest.

```Confirmation
$ archival_storage_ingest -i ingest_config.yml
S3 bucket: s3-cular-dev
Destination Queue: cular_development_ingest
collection: test_collection
depositor: test_depositor
dest_path: /cul/app/archival_storage_ingest/test/dest/test_depositor/test_collection
ingest_manifest: /cul/app/archival_storage_ingest/test/data/ingest_manifest.json
ticket_id: CULAR-2205
Source path: /cul/app/archival_storage_ingest/test/data/test_depositor/test_collection
Queue ingest? (Y/N)
```

### Transfer workers

With the ingest manifest update, it no longer traverses a directory to populate the assets to ingest.

Instead, it traverses the ingest manifest to populate the assets to ingest.

```Example ingest manifest
{
  ...
  "packages": [
    {
      "package_id": "SOME_UUID",
      "source_path": "/PATH_TO_ASSETS_ROOT/USUALLY/DEPOSITOR/COLLECTION",
      "number_files": 2,
      "files": [
        {
          "filepath": "some_dir_1/a_file",
          "sha1": "058bbd836dfc8e22d57d5dc8c048f15d8aed7dc4",
          "md5": "61a6104561744087fe62e7878948d9b7",
          "size": 12
        },
        {
          "filepath": "foo/bar.xml",
          "sha1": "2c789aee68c6803b0a45f1627a368a0af9785223",
          "md5": "5f859ade8cffd1a94543f4f660ab1b99",
          "size": 68
        }
      ]
    }
  ]
}
```

The above example ingest manifest would result in the following two assets to be transferred.

```Assets to be ingested
/PATH_TO_ASSETS_ROOT/USUALLY/DEPOSITOR/COLLECTION/some_dir_1/a_file
/PATH_TO_ASSETS_ROOT/USUALLY/DEPOSITOR/COLLECTION/foo/bar.xml
```

The SFS transfer worker would combine the dest_path and filepath to find the target location while S3 transfer worker would combine depositor, collection and filepath attributes to generate the S3 key.
