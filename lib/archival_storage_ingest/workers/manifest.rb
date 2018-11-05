# frozen_string_literal: true

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
end
