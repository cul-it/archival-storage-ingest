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
