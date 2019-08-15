# frozen_string_literal: true

require 'digest/sha1'
require 'pathname'

module IngestUtils
  EXCLUDE_FILE_LIST = {
    '.ds_store' => true,
    'thumbs.db' => true,
    '.bridgecache' => true,
    '.bridgecachet' => true
  }.freeze
  BUFFER_SIZE = 4096

  def self.relativize(file, path_to_trim)
    Pathname.new(file).relative_path_from(path_to_trim).to_s
  end

  def self.calculate_checksum(filepath)
    size = 0
    File.open(filepath, 'rb') do |file|
      dig = Digest::SHA1.new
      until file.eof?
        buffer = file.read(BUFFER_SIZE)
        dig.update(buffer)
        size += buffer.length
      end
      return dig.hexdigest, size
    end
  end

  def self.relative_path(file, path_to_trim)
    basepath = Pathname.new(path_to_trim)
    Pathname.new(file).relative_path_from(basepath).to_s
  end

  def self.blank?(str)
    str.to_s.strip.empty?
  end

  def self.if_empty(str, replacement)
    return replacement if blank?(str)

    str
  end

  # deprecated, use process instead
  class DirectoryWalker
    def process_immediate_children(dir)
      Dir.glob("#{dir}/*").sort.each do |path|
        next if EXCLUDE_FILE_LIST[File.basename(path).downcase]

        yield(path)
      end
    end

    # deprecated, use process instead
    def process_rest(dir)
      Dir.glob("#{dir}/**/*/**").sort.each do |path|
        next if EXCLUDE_FILE_LIST[File.basename(path).downcase]

        yield(path)
      end
    end

    def process(dir)
      Dir.glob("#{dir}{,/*/**}/*").sort.each do |path|
        next if EXCLUDE_FILE_LIST[File.basename(path).downcase]

        yield(path)
      end
    end
  end
end
