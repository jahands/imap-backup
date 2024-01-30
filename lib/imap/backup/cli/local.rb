require "thor"

require "imap/backup/account/serialized_folders"
require "imap/backup/cli/helpers"
require "imap/backup/cli/local/check"
require "imap/backup/logger"

module Imap; end

module Imap::Backup
  class CLI < Thor; end

  # Implements the CLI functions relating to local storage
  class CLI::Local < Thor
    include Thor::Actions
    include CLI::Helpers

    desc "accounts [OPTIONS]", "List locally backed-up accounts"
    config_option
    format_option
    quiet_option
    verbose_option
    # Lists configured accounts
    # @return [void]
    def accounts
      names = config.accounts.map(&:username)
      case options[:format]
      when "json"
        list = names.map { |n| {username: n} }
        Kernel.puts list.to_json
      else
        names.each { |n| Kernel.puts n }
      end
    end

    desc(
      "check [OPTIONS]",
      "Check the integrity of backups for all accounts (or the selected account(s))"
    )
    method_option(
      "delete_corrupt",
      type: :boolean,
      desc: "deletes any corrupted folders - USE WITH CAUTION!"
    )
    accounts_option
    config_option
    format_option
    quiet_option
    verbose_option
    # Runs integrity checks on backups
    # @return [void]
    def check
      non_logging_options = Imap::Backup::Logger.setup_logging(options)
      Check.new(non_logging_options).run
    end

    desc "folders EMAIL [OPTIONS]", "List backed up folders"
    config_option
    format_option
    quiet_option
    verbose_option
    # Lists backed-up folders for an account
    # @return [void]
    def folders(email)
      account = account(config, email)

      serialized_folders = Account::SerializedFolders.new(account: account)
      case options[:format]
      when "json"
        list = serialized_folders.map { |_s, f| {name: f.name} }
        Kernel.puts list.to_json
      else
        serialized_folders.each_value do |f|
          Kernel.puts %("#{f.name}")
        end
      end
    end

    desc "list EMAIL FOLDER [OPTIONS]", "List emails in a folder"
    config_option
    format_option
    quiet_option
    verbose_option
    # Lists backed-up emails for an account folder
    # @raise [RuntimeError] if the folder does not exist
    # @return [void]
    def list(email, folder_name)
      account = account(config, email)

      serialized_folders = Account::SerializedFolders.new(account: account)
      serializer, _folder = serialized_folders.find do |_s, f|
        f.name == folder_name
      end
      raise "Folder '#{folder_name}' not found" if !serializer

      case options[:format]
      when "json"
        list_emails_as_json serializer
      else
        list_emails_as_text serializer
      end
    end

    desc "show EMAIL FOLDER UID[,UID] [OPTIONS]", "Show one or more emails"
    long_desc <<~DESC
      Prints out the requested emails.
      If more than one UID is given, they are separated by a header indicating
      the UID.
    DESC
    config_option
    format_option
    quiet_option
    verbose_option
    # Shows the content of one or more backed-up email messages
    # @raise [RuntimeError] if the folder does not exist
    # @return [void]
    def show(email, folder_name, uids)
      account = account(config, email)

      serialized_folders = Account::SerializedFolders.new(account: account)
      serializer, _folder = serialized_folders.find do |_s, f|
        f.name == folder_name
      end
      raise "Folder '#{folder_name}' not found" if !serializer

      uid_list = uids.split(",")

      case options[:format]
      when "json"
        show_emails_as_json serializer, uid_list
      else
        show_emails_as_text serializer, uid_list
      end
    end

    private

    MAX_SUBJECT = 60

    def list_emails_as_json(serializer)
      emails = serializer.each_message.map do |message|
        {
          uid: message.uid,
          date: message.date.to_s,
          subject: message.subject || ""
        }
      end
      Kernel.puts emails.to_json
    end

    def list_emails_as_text(serializer)
      Kernel.puts format(
        "%-10<uid>s  %-#{MAX_SUBJECT}<subject>s - %<date>s",
        {uid: "UID", subject: "Subject", date: "Date"}
      )
      Kernel.puts "-" * (12 + MAX_SUBJECT + 28)

      serializer.each_message.map do |message|
        list_message_as_text message
      end
    end

    def list_message_as_text(message)
      m = {
        uid: message.uid,
        date: message.date.to_s,
        subject: message.subject || ""
      }
      if m[:subject].length > MAX_SUBJECT
        Kernel.puts format("% 10<uid>u: %.#{MAX_SUBJECT - 3}<subject>s... - %<date>s", m)
      else
        Kernel.puts format("% 10<uid>u: %-#{MAX_SUBJECT}<subject>s - %<date>s", m)
      end
    end

    def show_emails_as_json(serializer, uids)
      emails = serializer.each_message(uids).map do |m|
        m.to_h.tap { |h| h[:body] = m.body }
      end
      Kernel.puts emails.to_json
    end

    def show_emails_as_text(serializer, uids)
      serializer.each_message(uids).each do |message|
        if uids.count > 1
          Kernel.puts <<~HEADER
            #{'-' * 80}
            #{format('| UID: %-71s |', message.uid)}
            #{'-' * 80}
          HEADER
        end
        Kernel.puts message.body
      end
    end

    def config
      @config ||=
        begin
          non_logging_options = Logger.setup_logging(options)
          load_config(**non_logging_options)
        end
    end
  end
end
