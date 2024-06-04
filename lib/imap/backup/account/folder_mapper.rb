require "thor"
require "pathname"

require "imap/backup/account/folder"
require "imap/backup/serializer"

module Imap; end

module Imap::Backup
  class Account; end

  # Implements a folder enumerator for backed-up accounts
  class Account::FolderMapper
    def initialize(
      account:,
      destination:,
      destination_delimiter: "/",
      destination_prefix: "",
      source_delimiter: "/",
      source_prefix: ""
    )
      @account = account
      @destination = destination
      @destination_delimiter = destination_delimiter
      @destination_prefix = destination_prefix
      @source_delimiter = source_delimiter
      @source_prefix = source_prefix
    end

    # Enumerates backed-up folders
    # When called without a block, returns an Enumerator
    # @yieldparam serializer [Serializer] the folder's serializer
    # @yieldparam folder [Account::Folder] the online folder
    # @return [Enumerator, void]
    def each(&block)
      return enum_for(:each) if !block_given?

      glob = File.join(source_local_path, "**", "*.imap")
      Pathname.glob(glob) do |path|
        name = source_folder_name(path)
        serializer = Serializer.new(source_local_path, name)
        folder = destination_folder_for_path(name)
        block.call(serializer, folder)
      end
    end

    private

    attr_reader :destination
    attr_reader :destination_delimiter
    attr_reader :account
    attr_reader :source_delimiter

    def destination_prefix_clipped
      @destination_prefix_clipped ||=
        if @destination_prefix.end_with?(destination_delimiter)
          @destination_prefix[0..-2]
        else
          @destination_prefix
        end
    end

    def source_prefix_clipped
      @source_prefix_clipped ||=
        if @source_prefix.end_with?(source_delimiter)
          @source_prefix[0..-2]
        else
          @source_prefix
        end
    end

    def destination_folder_for_path(name)
      parts = name.split("/")
      no_source_prefix =
        if source_prefix_clipped != "" && parts.first == source_prefix_clipped
          parts[1..]
        else
          parts
        end

      with_destination_prefix =
        if destination_prefix_clipped && destination_prefix_clipped != ""
          no_source_prefix.unshift(destination_prefix_clipped)
        else
          no_source_prefix
        end

      destination_name = with_destination_prefix.join(destination_delimiter)

      Account::Folder.new(
        destination.client,
        destination_name
      )
    end

    def source_local_path
      account.local_path
    end

    def source_folder_name(imap_pathname)
      base = Pathname.new(source_local_path)
      imap_name = imap_pathname.relative_path_from(base).to_s
      dir = File.dirname(imap_name)
      stripped = File.basename(imap_name, ".imap")
      if dir == "."
        stripped
      else
        File.join(dir, stripped)
      end
    end
  end
end
