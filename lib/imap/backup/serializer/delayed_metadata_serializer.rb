require "imap/backup/serializer/imap"
require "imap/backup/serializer/mbox"
require "imap/backup/serializer/transaction"

module Imap; end

module Imap::Backup
  class Serializer::DelayedMetadataSerializer
    extend Forwardable

    attr_reader :serializer

    def_delegator :serializer, :uids

    def initialize(serializer:)
      @serializer = serializer
      @tsx = nil
    end

    def transaction(&block)
      tsx.fail_in_transaction!(:transaction, message: "nested transactions are not supported")

      tsx.start
      tsx.data = {metadata: [], mbox: {length: mbox.length}}

      block.call

      commit

      tsx.clear
    end

    def commit
      tsx.fail_outside_transaction!(:commit)

      # rubocop:disable Lint/RescueException
      imap.transaction do
        tsx.data[:metadata].each do |m|
          imap.append m[:uid], m[:length], flags: m[:flags]
        end
      rescue Exception => e
        imap.rollback
        rollback
        raise e
      end
      # rubocop:enable Lint/RescueException
      tsx.data[:metadata] = []
      tsx.data[:mbox][:length] = mbox.length
    end

    def rollback
      tsx.fail_outside_transaction!(:rollback)

      mbox.rewind(tsx.data[:mbox][:length])

      tsx.clear
    end

    def append(uid, message, flags)
      tsx.fail_outside_transaction!(:append)
      mboxrd_message = Email::Mboxrd::Message.new(message)
      serialized = mboxrd_message.to_serialized
      tsx.data[:metadata] << {uid: uid, length: serialized.length, flags: flags}
      mbox.append(message)
    end

    private

    def mbox
      @mbox ||= Serializer::Mbox.new(serializer.folder_path)
    end

    def imap
      @imap ||= Serializer::Imap.new(serializer.folder_path)
    end

    def tsx
      @tsx ||= Serializer::Transaction.new(owner: self)
    end
  end
end
