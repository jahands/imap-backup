require "thunderbird/profile"
require "imap/backup/thunderbird/mailbox_exporter"
require "imap/backup/serializer"
require "imap/backup/serializer/message"

module Imap::Backup
  RSpec.describe Thunderbird::MailboxExporter do
    subject { described_class.new("email", serializer, profile, **args) }

    let(:args) { {} }
    let(:serializer) do
      instance_double(
        Serializer,
        folder: "folder",
        messages: [message]
      )
    end
    let(:message) do
      instance_double(
        Serializer::Message,
        body: "Ciao"
      )
    end
    let(:profile) do
      instance_double(
        ::Thunderbird::Profile,
        local_folders_path: "local_folders_path",
        title: "profile_title"
      )
    end
    let(:profile_local_folders_exists) { true }
    let(:local_folder) do
      instance_double(
        ::Thunderbird::LocalFolder,
        exists?: local_folder_exists,
        full_path: "full_path",
        msf_exists?: msf_exists,
        msf_path: "msf_path",
        path: "thunderbird_path",
        set_up: set_up_result
      )
    end
    let(:local_folder_exists) { false }
    let(:msf_exists) { false }
    let(:set_up_result) { true }
    let(:file) { instance_double(File, write: nil) }

    before do
      allow(File).to receive(:exist?).and_call_original
      allow(File).to receive(:exist?).with("local_folders_path") { profile_local_folders_exists }
      allow(File).to receive(:open).with("full_path", "w").and_yield(file)
      allow(FileUtils).to receive(:rm).and_call_original
      allow(FileUtils).to receive(:rm).with("msf_path")
      allow(::Thunderbird::LocalFolder).to receive(:new).
        with(path: anything, profile: anything) { local_folder }
      allow(Kernel).to receive(:puts)
    end

    describe "#run" do
      let!(:result) { subject.run }

      context "when the account is not set up" do
        let(:profile_local_folders_exists) { false }

        it "refuses to run" do
          expect(result).to be false
        end
      end

      context "when the destination folder cannot be set up" do
        let(:set_up_result) { false }

        it "doesn't copy the mailbox" do
          expect(file).to_not have_received(:write)
        end

        it "returns false" do
          expect(result).to be false
        end
      end

      context "when the .msf file exists" do
        let(:msf_exists) { true }

        context "when 'force' is set" do
          let(:args) { {force: true} }

          it "deletes the file" do
            expect(FileUtils).to have_received(:rm).with("msf_path")
          end
        end

        context "when 'force' isn't set" do
          it "doesn't copy the mailbox" do
            expect(file).to_not have_received(:write)
          end

          it "returns false" do
            expect(result).to be false
          end
        end
      end

      context "when the destination mailbox exists" do
        let(:local_folder_exists) { true }

        context "when 'force' is set" do
          let(:args) { {force: true} }

          it "writes the message" do
            expect(file).to have_received(:write)
          end

          it "returns true" do
            expect(result).to be true
          end
        end

        context "when 'force' isn't set" do
          it "doesn't copy the mailbox" do
            expect(file).to_not have_received(:write)
          end

          it "returns false" do
            expect(result).to be false
          end
        end
      end

      it "adds a 'From' line" do
        expect(file).to have_received(:write).with(/From - \w+ \w+ \d+ \d+:\d+:\d+/)
      end

      it "writes the message" do
        expect(file).to have_received(:write).with(/Ciao/)
      end

      it "returns true" do
        expect(result).to be true
      end
    end
  end
end
