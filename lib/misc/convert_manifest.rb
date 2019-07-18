# frozen_string_literal: true

require 'securerandom'
require 'json'
require 'csv'

module ConvertManifest # rubocop:disable Metrics/ModuleLength
  class ConvertManifest
    attr_reader
  end

  def self.convert_manifest_to_new_hash(filename:, depth:) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    json_io = File.open(filename)

    old = JSON.parse(json_io.read)

    depcol = old.keys[0]

    collection = old[depcol]
    depcolsplit = depcol.split('/')
    col = depcolsplit[-1]
    dep = depcolsplit[0..-2].join('/')

    locations = populate_locations(collection['locations'])

    items = collection['items']
    packs = convert_packages(items, depth, nil)

    {
      steward: collection['steward'],
      depositor: dep,
      collection_id: col,
      locations: locations,
      documentation: 'TBD',
      number_packages: packs.length,
      packages: packs
    }.compact
  end

  def self.populate_locations(locations)
    return (locations || {}).keys if (locations['s3']).nil?

    locs = []
    locations.keys.each do |storage_type|
      locations[storage_type].each do |loc|
        locs << loc['uri']
      end
    end
    locs
  end

  def self.convert_manifest(filename:, csv:, data_root:, depth: 1)
    manifest_hash = convert_manifest_to_new_hash(filename: filename, depth: depth)
    manifest_hash[:packages] = add_additional_metadata(packages: manifest_hash[:packages], data_root: data_root, csv: csv)
    JSON.pretty_generate(manifest_hash)
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
      filepath: fullkeys, sha1: attribs['sha1'],
      size: attribs['size'].to_i, md5: attribs['md5'],
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
      bibid: bibid, files: flattened,
      number_files: flattened.length
    }.compact
  end

  def self.add_additional_metadata(packages:, csv:, data_root:)
    csv_metadata = populate_metadata_from_csv(csv: csv)
    data_roots = data_root.split(',')

    packages.each do |package|
      add_package_metadata(package: package, csv_metadata: csv_metadata)
      add_file_metadata(package: package, data_roots: data_roots)
    end

    check_data(packages: packages, csv_metadata: csv_metadata)
  end

  def self.add_package_metadata(package:, csv_metadata:) # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity
    filepath = package[:files][0][:filepath]
    csv_entry = csv_metadata[filepath]
    csv_local_id = csv_entry['local_id']
    csv_bibid = csv_entry['bibid']
    package[:local_id] = csv_local_id if csv_local_id
    package[:bibid] = csv_bibid if !package[:bibid] && csv_bibid
    puts "BIBID mismatch! #{package[:bibid]} - #{csv_bibid}" if
      package[:bibid] && csv_bibid && package[:bibid].to_s != csv_bibid
  end

  def self.add_file_metadata(package:, data_roots:)
    package[:files].each do |file_entry|
      real_file_path = real_path(data_roots: data_roots, filepath: file_entry[:filepath])
      unless real_file_path
        puts "#{file_entry[:filepath]} does not exists!"
        next
      end
      file_entry[:size] = size(real_file_path) unless file_entry[:size]
    end
  end

  def self.real_path(data_roots:, filepath:)
    data_roots.each do |data_root|
      file = File.join(data_root, filepath)
      return file if File.exist?(file)
    end
  end

  def self.populate_metadata_from_csv(csv:)
    csv_metadata = {}
    CSV.foreach(csv, headers: true) do |row|
      csv_metadata[row['filepath']] = row
    end
    csv_metadata
  end

  def self.check_data(packages:, csv_metadata:) # rubocop:disable Metrics/AbcSize
    packages.each do |package|
      package[:files].each do |file|
        csv_data = csv_metadata[file[:filepath]]
        puts "SHA1 mismatch! #{file[:filepath]} #{file[:sha1]} - #{csv_data['sha1']}" unless
          file[:sha1] == csv_data['sha1']
        puts "Size mismatch! #{file[:filepath]} #{file[:size]} - #{csv_data['size']}" unless
          file[:size] == csv_data['size'].to_i
      end
    end

    packages
  end
end
