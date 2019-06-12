# frozen_string_literal: true

require 'securerandom'
require 'json'

module ConvertManifest
  def self.convert_manifest(filename:, depth: 1) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
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

    items = collection['items']
    packs = convert_packages(items, depth, nil)

    JSON.pretty_generate({
      steward: collection['steward'],
      depositor: dep,
      collection_id: col,
      rights: 'TBD',
      locations: locations,
      packages: packs,
      number_packages: packs.length
    }.compact)
  end

  def self.flatten(dirname:, filehash:)
    filehash.map do |filename, attribs|
      convert_file(attribs, "#{dirname}/#{filename}")
    end
  end

  def self.flattened(dirname:, filehash:)
    files = []
    flatten_folder(files, filehash, dirname)
    files
  end

  def self.flatten_folder(files, items, prefix)
    items.each do |key, attribs|
      fullkey = [prefix, key]
      if attribs.key?('sha1')
        files << convert_file(attribs, fullkey)
      else
        flatten_folder(files, attribs, fullkey)
      end
    end
  end

  def self.convert_file(attribs, fullkey)
    fullkeys = fullkey.flatten.compact.join('/')
    {
      filepath: fullkeys,
      sha1: attribs['sha1'],
      size: attribs['size'],
      md5: attribs['md5'],
      bibid: attribs['bibid']
    }.compact
  end

  def self.convert_packages(items, depth, prefix)
    if depth == 1
      items.map { |path, files| convert_package(prefix, path, files) }
    else
      items.flat_map { |path, subitems| convert_packages(subitems, depth - 1, [prefix, path]) }
    end
  end

  def self.convert_package(prefix, path, files)
    flattened = flattened(dirname: [prefix, path], filehash: files)
    bibid = flattened[0][:bibid]

    flattened.each { |file| file.delete :bibid }
    {
      package_id: "urn:uuid:#{SecureRandom.uuid}",
      bibid: bibid,
      files: flattened,
      number_files: flattened.length

    }.compact
  end
end
