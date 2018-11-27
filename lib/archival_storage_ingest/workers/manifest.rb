# frozen_string_literal: true

require 'pathname'

class Manifest
  def initialize
    @manifest_hash = {
      number_files: 0,
      files: []
    }
  end

  attr_reader :manifest_hash

  def add_file(filepath, sha1)
    new_entry = {
      filepath: filepath,
      sha1: sha1
    }
    manifest_hash[:files].push(new_entry)
    manifest_hash[:number_files] += 1
  end

  def to_old_manifest(depositor, collection)
    depo_col = "#{depositor}/#{collection}"
    depo_col_as_path = Pathname.new(depo_col)
    old_manifest = { depo_col => { items: {} } }
    manifest_hash[:files].each do |entry|
      key = Pathname.new(entry[:filepath]).relative_path_from(depo_col_as_path).to_s
      sha1 = entry[:sha1]
      old_manifest[depo_col][:items][key] = { sha1: sha1 }
    end
    old_manifest
  end
end
