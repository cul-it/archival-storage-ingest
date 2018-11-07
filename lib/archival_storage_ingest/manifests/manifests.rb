# frozen_string_literal: true

module Manifests
  class Manifest
    attr_reader :hash
    attr_reader :files
    attr_reader :filename

    def initialize(filename:, json: nil)
      @filename = filename
      json_io = json || File.open(filename)
      json_text = json_io.read
      @hash = JSON.parse(json_text)
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

    def diff(manifest)
      left = files.to_a
      right = manifest.files.to_a
      leftfiles = (left - right).to_h
      rightfiles = (right - left).to_h

      diff = {}
      diff[filename] = leftfiles unless leftfiles.empty?
      diff[manifest.filename] = rightfiles unless rightfiles.empty?
      diff
    end

    private

    def flatten_folder(files, items, prefix)
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
end
