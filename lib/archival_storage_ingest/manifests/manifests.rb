# frozen_string_literal: true

module Manifests
  class Manifest
    attr_reader :hash
    attr_reader :files
    attr_reader :filename

    def initialize(json)
      @filename = json
      file = File.read(json)
      @hash = JSON.parse(file)
      @files = flattened
    end

    def depcol
      hash.keys[0]
    end

    def size
      files.length
    end

    def flattened
      files = {}
      items = hash[depcol]['items']
      flatten_folder(files, items, depcol)
      files
    end

    def diff(m)
      leftfiles = files.reject { |file, _| m.files.has_key? file }
      rightfiles = m.files.reject { |file, _| files.has_key? file }

      diff = {}
      diff[filename] = leftfiles unless leftfiles.empty?
      diff[m.filename] = rightfiles unless rightfiles.empty?
      diff
    end

    private

    def flatten_folder(files, items, prefix)
      items.each do |key, file_hash|
        fullkey = prefix + '/' + key
        if file_hash.has_key?('sha1')
          files[fullkey] = file_hash['sha1']
        else
          flatten_folder(files, file_hash, fullkey)
        end
      end
    end
  end
end
