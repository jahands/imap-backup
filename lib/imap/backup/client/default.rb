require "forwardable"
require "net/imap"

module Imap::Backup
  module Client; end

  class Client::Default
    extend Forwardable
    def_delegators :imap, *%i(
      append authenticate create expunge login
      responses uid_fetch uid_search uid_store
    )

    attr_reader :args
    attr_accessor :state

    def initialize(*args)
      @args = args
      @state = nil
    end

    def list
      root = provider_root
      mailbox_lists = imap.list(root, "*")

      return [] if mailbox_lists.nil?

      mailbox_lists.map { |ml| extract_name(ml) }
    end

    # Track mailbox selection during delegation to Net::IMAP instance

    def disconnect
      imap.disconnect
      self.state = nil
    end

    def examine(mailbox)
      result = imap.examine(mailbox)
      self.state = [:examine, mailbox]
      result
    end

    def select(mailbox)
      imap.select(mailbox)
      self.state = [:select, mailbox]
    end

    private

    def imap
      @imap ||= Net::IMAP.new(*args)
    end

    def extract_name(mailbox_list)
      utf7_encoded = mailbox_list.name
      Net::IMAP.decode_utf7(utf7_encoded)
    end

    # 6.3.8. LIST Command
    # An empty ("" string) mailbox name argument is a special request to
    # return the hierarchy delimiter and the root name of the name given
    # in the reference.
    def provider_root
      @provider_root ||= begin
        root_info = imap.list("", "")[0]
        root_info.name
      end
    end
  end
end
