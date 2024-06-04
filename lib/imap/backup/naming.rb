module Imap; end

module Imap::Backup
  # Maps between server and file system folder names
  # `/` is treated as an acceptable character
  class Naming
    # The characters that cannot be used in file names
    INVALID_FILENAME_CHARACTERS = ":%;".freeze
    # A regular expression that captures each disallowed character
    INVALID_FILENAME_CHARACTER_MATCH = /([#{INVALID_FILENAME_CHARACTERS}])/

    # @param name [String] a folder name
    # @return [String] the supplied string iwth disallowed characters replaced
    #   by their hexadecimal representation
    def self.to_local_path(name)
      name.gsub(INVALID_FILENAME_CHARACTER_MATCH) do |character|
        hex =
          character.
          codepoints[0].
          to_s(16)
        "%#{hex};"
      end
    end

    # @param name [String] a serialized folder name
    # @return the supplied string with hexadecimal codes ('%xx') replaced with
    #   the characters they represent
    def self.from_local_path(name)
      name.gsub(/%(.*?);/) do
        ::Regexp.last_match(1).
          to_i(16).
          chr("UTF-8")
      end
    end
  end
end
