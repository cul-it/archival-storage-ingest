# frozen_string_literal: true

require 'securerandom'
require 'json'

module ConvertManifest
  def self.convert_manifest(filename:) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    json_io = File.open(filename)

    old = JSON.parse(json_io.read)

    depcol = old.keys[0]

    collection = old[depcol]
    depcolsplit = depcol.split('/')
    col = depcolsplit[-1]
    dep = depcolsplit[0..-2].join('/')

    locs = collection['locations']
    locations = if locs['s3'].nil?
                  (locs || {}).keys
                else
                  locs.map { |_k, v| v[0]['uri'] }
                end

    newman = {
      steward: collection['steward'],
      depositor: dep,
      collection_id: col,
      rights: 'TBD',
      locations: locations,
      packages: []
    }

    packs = collection['items'].map do |path, files|
      flattened = flatten(dirname: path, filehash: files)
      bibid = flattened[0][:bibid]
      flattened.each do |file|
        file[:bibid] = nil
        file.compact!
      end
      {
        package_id: "urn:uuid:#{SecureRandom.uuid}",
        bibid: bibid,
        files: flattened,
        number_files: flattened.length

      }.compact
    end
    newman['packages'] = packs
    compact = newman.compact
    compact.to_json
  end

  def self.flatten(dirname:, filehash:)
    filehash.map do |filename, attribs|
      {
        filepath: "#{dirname}/#{filename}",
        sha1: attribs['sha1'],
        size: attribs['size'],
        md5: attribs['md5'],
        bibid: attribs['bibid']
      }
    end
  end

  def self.flatten_folder(files, items, prefix)
    items.each do |key, file_hash|
      fullkey = prefix + '/' + key
      if file_hash.key?('sha1')
        files[fullkey] = file_hash['sha1']
      else
        flatten_folder(files, file_hash, fullkey)
      end
    end
  end
end
