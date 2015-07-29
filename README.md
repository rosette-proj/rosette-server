[![Build Status](https://travis-ci.org/rosette-proj/rosette-server.svg?branch=master)](https://travis-ci.org/rosette-proj/rosette-server) [![Code Climate](https://codeclimate.com/github/rosette-proj/rosette-server/badges/gpa.svg)](https://codeclimate.com/github/rosette-proj/rosette-server)

rosette-server
========

## Installation

`gem install rosette-server`

## Usage

```ruby
require 'rosette/server'
```

# Intro

`Rosette::Server` provides a simple Rack-based JSON API for your Rosette config. Just plug in your Rosette config and stand up the server. For example, you might put this in your `config.ru` file:

```ruby
require 'rosette/core'
require 'rosette/server'

rosette_config = Rosette.build_config do |config|
  # your configuration here
end

run Rosette::Server::ApiV1.new(rosette_config)
```

Then run `bundle exec rackup` to start the server.

# Endpoints

Supported endpoints and their parameters are listed below:

## Locales
Information about configured locales.

### /v1/locales.{format}

List configured locales

|Name|Description|Type|Required|
|:----------|:----------|:----------|:----------|
repo_name|The name of the repository to get locales for. Must be configured in the current Rosette config.|string|true

## Git
Perform various git-insipired operations on phrases and translations

### /v1/git/commit.{format}

Extract phrases from a commit and store them in the datastore.

|Name|Description|Type|Required|
|:----------|:----------|:----------|:----------|
repo_name|The name of the repository to examine. Must be configured in the current Rosette config.|string|true
ref|The git ref to commit phrases from. Can be either a git symbolic ref (i.e. branch name) or a git commit id.|string|true

### /v1/git/show.{format}

List the phrases contained in a commit

|Name|Description|Type|Required|
|:----------|:----------|:----------|:----------|
repo_name|The name of the repository to examine. Must be configured in the current Rosette config.|string|true
ref|The git ref to list phrases for. Can be either a git symbolic ref (i.e. branch name) or a git commit id.|string|true

### /v1/git/status.{format}

Translation progress for a given commit

|Name|Description|Type|Required|
|:----------|:----------|:----------|:----------|
repo_name|The name of the repository to examine. Must be configured in the current Rosette config.|string|true
ref|The git ref to get the status for. Can be either a git symbolic ref (i.e. branch name) or a git commit id.|string|true

### /v1/git/diff.{format}

Lists the phrases that were added, removed, or changed between two commits

|Name|Description|Type|Required|
|:----------|:----------|:----------|:----------|
repo_name|The name of the repository to examine. Must be configured in the current Rosette config.|string|true
head_ref|The git ref to compare against diff_point_ref. This is usually a HEAD (i.e. branch name). Can be either a git symbolic ref (i.e. branch name) or a git commit id.|string|true
diff_point_ref|The git ref to compare to head_ref. This is usually master or some common parent. Can be either a git symbolic ref (i.e. branch name) or a git commit id.|string|true
paths|A space-separated list of paths to include in the diff.|string|false

### /v1/git/snapshot.{format}

Returns the phrases for the most recent changes for each file in the repository

|Name|Description|Type|Required|
|:----------|:----------|:----------|:----------|
repo_name|The name of the repository in which to take the snapshot. Must be configured in the current Rosette config.|string|true
ref|The git ref to take the snapshot of. Can be either a git symbolic ref (i.e. branch name) or a git commit id.|string|true

### /v1/git/repo_snapshot.{format}

Returns the commit ids for the most recent changes for each file in the repository

|Name|Description|Type|Required|
|:----------|:----------|:----------|:----------|
repo_name|The name of the repository in which to take the snapshot. Must be configured in the current Rosette config.|string|true
ref|The git ref to take the snapshot of. Can be either a git symbolic ref (i.e. branch name) or a git commit id.|string|true

## Translations
Perform various operations on translations

### /v1/translations/export.{format}

Retrieve and serialize the phrases and translations for a given ref

|Name|Description|Type|Required|
|:----------|:----------|:----------|:----------|
repo_name|The name of the repository to export translations from. Must be configured in the current Rosette config.|string|true
ref|The git ref to export translations from. Can be either a git symbolic ref (i.e. branch name) or a git commit id.|string|true
locale|The locale of the translations to retrieve.|string|true
serializer|The serializer to use to serialize the phrases in the given ref. The serializer must have been configured in the configuration for the repo.|string|true
paths|When phrases are extracted, the path of the file they were extracted from gets recorded. With this parameter, specify a pipe-separated list of paths to include in the export.|string|false
base_64_encode|If set to true, the serialized phrases will be base-64 encoded. This is often desirable to avoid unexpected encoding issues when transmitting data over the Internet.|Virtus::Attribute::Boolean|false
encoding|The text encoding to encode the phrases in before serialization. Any encoding supported by Ruby can be specified, eg. UTF-8, UTF-16, US-ASCII, etc.|string|false
include_snapshot|If true, includes the snapshot (hash of paths to commit ids) that was used to identify the phrases and therefore translations in the response.|Virtus::Attribute::Boolean|false
include_checksum|If true, includes an MD5 checksum of the exported translations.|Virtus::Attribute::Boolean|false

### /v1/translations/untranslated.{format}

Identifies phrases by locale that have not yet been translated

|Name|Description|Type|Required|
|:----------|:----------|:----------|:----------|
repo_name|The name of the repository the phrases were found in. Must be configured in the current Rosette config.|string|true
ref|The git ref to check translations for. Can be either a git symbolic ref (i.e. branch name) or a git commit id.|string|true


## Requirements

All Rosette components only run under jRuby. Java dependencies are managed via the [expert gem](https://github.com/camertron/expert). Run `bundle exec expert install` to install Java dependencies.

## Running Tests

`bundle`, then `bundle exec expert install`, then `bundle exec rspec`.

## Authors

* Cameron C. Dutro: http://github.com/camertron
* Matthew Low: http://github.com/11mdlow
