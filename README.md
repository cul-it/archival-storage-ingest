# Archival Storage Ingest

Archival storage ingest is a ruby gem for automating parts of the ingest process. 

## Installation

After cloning from GitHub repository (https://github.com/cul-it/archival-storage-ingest), run the following command.

```ruby
$ rake install
```

It is recommended to install the gem under a local Ruby installation via RVM rather than the system Ruby.

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

## Usage

    $ archival_storage_ingest -s [SERVER_COMMAND]
    $ archival_storage_ingest -i [PATH_TO_INGEST_CONFIG_FILE]

-s flag will start the ingest server.
Available server commands are start, status and stop.

-i flag will queue a new ingest as described in the ingest config file.

## Development

For development, you could also create a test gemset via RVM as well with the following command before installation.

    $ rvm gemset create archival-storage-ingest-gemset

## Message

```json
{
  "ingest_id": "UUID generated for this ingest",
  "type": "Transfer S3"
}
```

ingest_id is generated when a new ingest is queued by a user and persists through all the steps of that ingest.

type designates the work that needs to be done upon reception.

Any information needed for the ingest should be included here.

## Behavior

Here is are the behaviors of this ingest manager.

* cular-ingest server subscribes to ingest, transfer s3, transfer sfs, fixity check sfs and fixity compare queues.
* AWS fixity checking VM subscribes to fixity check s3 queue.
* The ingest server only polls for new message if it has available worker slot in the worker pool.
* Upon receiving a message from SQS, ingest manager will log the contents of the message and remove it from SQS before working on it.
* During any phase, if it fails, it will put the original message with error message to error queue.
* On top of the error queue, each queue has corresponding dead-letter queue. If it fails to manipulate the queue unexpected such as network outage, the message will be put to this dead-letter queue.

## Workflow

The following describes the workflow of a single ingest job.
This workflow assumes ingest server is running and polling SQS every 30 seconds.
Also, if not specified, the ingest manager in question is running on cular-ingest.

P.S. Due to implementation details, we may put new message to SQS from ingest manager or workers from steps 4 and on.

1. User queues new ingest using -i flag.
2. Ingest manager puts new ingest message to ingest queue.
3. Ingest manager receives new ingest message from SQS and puts a message to each of transfer s3 and transfer sfs queues.
4. Ingest manager receives transfer s3 message and invokes transfer s3 worker.
When this work is complete, put fixity check s3 message to fixity check s3 queue.
5. Ingest manager receives transfer sfs message and invokes transfer sfs worker.
When this work is complete, put fixity check sfs message to fixity check sfs queue.
6. The cular-ingest server receives fixity check sfs message and invokes fixity check sfs worker.
When this work is complete, it stores resulting manifest to S3 bucket (.manifest prefix).
The filename of the manifest is derived from the ingest_id and work type (s3 vs sfs).
A new fixity compare (type sfs) is put to fixity compare queue.
7. The fixity VM receives fixity check s3 message and invokes fixity check s3 worker.
When this work is complete, it stores resulting manifest to S3 bucket (.manifest prefix).
The filename of the manifest is derived from the ingest_id and work type (s3 vs sfs).
A new fixity compare (type sfs) is put to fixity compare queue.
8. Ingest manager receives fixity compare message twice.
It will only invoke fixity compare worker if both s3 and sfs manifests are available in the s3 bucket.
9. Ingest manager puts a done message to done queue.