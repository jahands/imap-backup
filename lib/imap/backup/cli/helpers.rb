require "thor"

require "imap/backup/configuration"
require "imap/backup/configuration_not_found"

module Imap; end

module Imap::Backup
  class CLI < Thor; end

  # Provides helper methods for CLI classes
  module CLI::Helpers
    def self.included(base)
      base.class_eval do
        def self.accounts_option
          method_option(
            "accounts",
            type: :string,
            desc: "a comma-separated list of accounts (defaults to all configured accounts)",
            aliases: ["-a"]
          )
        end

        def self.config_option
          method_option(
            "config",
            type: :string,
            desc: "supply the configuration file path (default: ~/.imap-backup/config.json)",
            aliases: ["-c"]
          )
        end

        def self.format_option
          method_option(
            "format",
            type: :string,
            desc: "the output type, 'text' for plain text or 'json'",
            aliases: ["-f"]
          )
        end

        def self.quiet_option
          method_option(
            "quiet",
            type: :boolean,
            desc: "silence all output",
            aliases: ["-q"]
          )
        end

        def self.refresh_option
          method_option(
            "refresh",
            type: :boolean,
            desc: "in the default 'keep all emails' mode, " \
                  "updates flags for messages that are already downloaded",
            aliases: ["-r"]
          )
        end

        def self.verbose_option
          method_option(
            "verbose",
            type: :boolean,
            desc:
              "increase the amount of logging. " \
              "Without this option, the program gives minimal output. " \
              "Using this option once gives more detailed output. " \
              "Whereas, using this option twice also shows all IMAP network calls",
            aliases: ["-v"],
            repeatable: true
          )
        end
      end
    end

    # Processes command-line parameters
    # @return [Hash] the supplied command-line parameters with
    #   with hyphens in keys replaced by underscores
    #   and the keys converted to Symbols
    def options
      @symbolized_options ||= # rubocop:disable Naming/MemoizedInstanceVariableName
        begin
          options = super
          options.each.with_object({}) do |(k, v), acc|
            key =
              if k.is_a?(String)
                k.gsub("-", "_").intern
              else
                k
              end
            acc[key] = v
          end
        end
    end

    # Loads the application configuration
    # @raise [ConfigurationNotFound] if the configuration file does not exist
    # @return [Configuration]
    def load_config(**options)
      path = options[:config]
      require_exists = options.key?(:require_exists) ? options[:require_exists] : true
      if require_exists
        exists = Configuration.exist?(path: path)
        if !exists
          expected = path || Configuration.default_pathname
          raise ConfigurationNotFound, "Configuration file '#{expected}' not found"
        end
      end
      Configuration.new(path: path)
    end

    # @raise [RuntimeError] if the account does not exist
    # @return [Account] the Account information for the email address
    def account(config, email)
      account = config.accounts.find { |a| a.username == email }
      raise "#{email} is not a configured account" if !account

      account
    end

    # @return [Array<Account>] If email addresses have been specified
    #   returns the Account configurations for them.
    #   If non have been specified, returns all account configurations
    def requested_accounts(config)
      emails = (options[:accounts] || "").split(",")
      if emails.any?
        config.accounts.filter { |a| emails.include?(a.username) }
      else
        config.accounts
      end
    end
  end
end
