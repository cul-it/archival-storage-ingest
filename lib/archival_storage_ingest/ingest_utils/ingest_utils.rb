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
  ALGORITHM_MD5 = 'md5'
  ALGORITHM_SHA1 = 'sha1'
  MAX_RETRY = 3

  def self.relativize(file, path_to_trim)
    Pathname.new(file).relative_path_from(path_to_trim).to_s
  end

  def self.digest(algorithm)
    case algorithm
    when ALGORITHM_SHA1
      Digest::SHA1.new
    when ALGORITHM_MD5
      Digest::MD5.new
    else
      raise IngestException, "Unknown algorithm #{algorithm}"
    end
  end

  def self.calculate_checksum(filepath:, algorithm: ALGORITHM_SHA1, retry_interval: 120) # rubocop:disable Metrics/MethodLength
    errors = []
    file_size = File.size(filepath)
    MAX_RETRY.times do
      begin
        dig, size = _calculate_checksum(filepath: filepath, algorithm: algorithm)
        return [dig, size, errors] if file_size == size

        errors << "Size mismatch: #{file_size}, #{size}!"
      rescue Error
        errors << "Error calculating checksum: #{Error}!"
      end

      sleep(retry_interval)
    end

    raise IngestException, "SFS calculate_checksum failed for #{filepath}:\n".errors.join("\n")
  end

  def self._calculate_checksum(filepath:, algorithm:)
    size = 0
    File.open(filepath, 'rb') do |file|
      dig = digest(algorithm)
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
