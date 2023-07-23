require "json"
require "features/helper"
require "imap/backup/configuration"

# rubocop:disable RSpec/BeforeAfterAll

RSpec.describe "imap-backup backup performance", type: :aruba, docker: true, performance: true do
  # Use exponentially-spaced values so we get an even plot on a logarithmic scale
  counts = 0.upto(12).map { |p| (Math::E ** p).round }
  runs = 4
  results = []

  before(:all) do
    existing = test_server.folders.map(&:name)
    existing.each do |folder|
      next if !folder.start_with?("bulk-")

      test_server.delete_folder folder
    end
    counts.each do |count|
      folder = "bulk-#{count}"
      test_server.create_folder folder
      message = {from: "address@example.org", subject: "Test 1", body: "body 1\nHi"}
      test_server.send_multiple_emails folder, count: count, batch: 1000, **message
    end
  end

  counts.each do |message_count|
    count_runs = {count: message_count}
    Imap::Backup::Configuration::DOWNLOAD_STRATEGIES.each do |strategy|
      run_times = []
      1.upto(runs) do |run|
        context "with #{message_count} emails, download_strategy: #{strategy[:key]}, run #{run}" do
          let(:account_config) do
            test_server_connection_parameters.merge(
              folders: [{name: folder}],
              multi_fetch_size: multi_fetch_size
            )
          end
          let(:multi_fetch_size) { 25 }
          let(:folder) { "bulk-#{message_count}" }
          let(:config_options) do
            {accounts: [account_config], download_strategy: strategy[:key]}
          end
          let(:t_start_run) { Time.now }
          let(:t_finish_run) { Time.now }

          before do
            create_config(**config_options)
          end

          after do
            test_server.disconnect
          end

          specify "run" do
            t_start_run
            run_command_and_stop "imap-backup backup"
            t_finish_run
            time_taken = t_finish_run - t_start_run
            run_times << time_taken
            email = account_config[:username]
            metadata = imap_parsed(email, folder)
            expect(metadata[:messages].count).to eq(message_count)
          end
        end
      end
      count_runs[strategy[:key]] = run_times
    end
    results << count_runs
  end

  after(:all) do
    existing = test_server.folders.map(&:name)
    existing.each do |folder|
      next if !folder.start_with?("bulk-")

      test_server.delete_folder folder
    end
    test_server.disconnect
    puts results.to_json
  end
end

# rubocop:enable RSpec/BeforeAfterAll
