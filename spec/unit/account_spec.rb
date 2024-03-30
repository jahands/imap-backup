require "imap/backup/account"

require "imap/backup/client/default"

module Imap::Backup
  RSpec.describe Account do
    subject { described_class.new(options) }

    let(:options) { {username: "user", password: "pwd"} }

    describe "#initialize" do
      context "with valid options" do
        let(:options) do
          {
            username: "user", password: "pwd", folder_blacklist: true, mirror_mode: true,
            local_path: "local_path", folders: ["folder"]
          }
        end

        it "sets the username" do
          expect(subject.username).to eq("user")
        end

        it "sets the password" do
          expect(subject.password).to eq("pwd")
        end

        it "sets the folders" do
          expect(subject.folders).to eq(["folder"])
        end

        it "sets the folder_blacklist" do
          expect(subject.folder_blacklist).to be true
        end

        it "sets the local_path" do
          expect(subject.local_path).to eq("local_path")
        end

        it "sets the mirror_mode" do
          expect(subject.mirror_mode).to be true
        end

        it "sets marked_for_deletion to false" do
          expect(subject.marked_for_deletion?).to be false
        end
      end

      context "without optional options" do
        it "sets folder_blacklist to false" do
          expect(subject.folder_blacklist).to be false
        end

        it "sets mirror_mode to false" do
          expect(subject.mirror_mode).to be false
        end

        it "sets server to nil" do
          expect(subject.server).to be_nil
        end
      end

      context "with missing required options" do
        let(:options) { {} }

        it "raises an error" do
          expect do
            described_class.new(options)
          end.to raise_error(ArgumentError, /Missing required options: password, username/)
        end
      end

      context "with invalid options" do
        let(:options) { {username: "a", password: "b", not_a_valid_option: "value"} }

        it "raises an error" do
          expect do
            described_class.new(options)
          end.to raise_error(ArgumentError, /Unknown options: not_a_valid_option/)
        end
      end
    end

    describe "#connection_options" do
      context "when the supplied connection_options is a String" do
        let(:options) { {username: "user", password: "pwd", connection_options: '{"foo": "bar"}'} }

        it "returns the parsed connection_options" do
          expect(subject.connection_options).to eq({foo: "bar"})
        end
      end

      context "when the supplied connection_options is a Hash" do
        let(:options) { {username: "user", password: "pwd", connection_options: {foo: "bar"}} }

        it "returns the connection_options" do
          expect(subject.connection_options).to eq({foo: "bar"})
        end
      end

      context "when not set" do
        it "defaults to nil" do
          expect(subject.connection_options).to be_nil
        end
      end
    end

    describe "#client" do
      let(:client_factory) { instance_double(Account::ClientFactory, run: client) }
      let(:client) do
        instance_double(Client::Default, authenticate: nil, login: nil)
      end

      before do
        allow(Account::ClientFactory).to receive(:new) { client_factory }
      end

      it "calls ClientFactory" do
        expect(subject.client).to eq(client)
      end
    end

    describe "#modified?" do
      context "with changes" do
        it "is true" do
          subject.username = "new"

          expect(subject.modified?).to be true
        end
      end

      context "without changes" do
        it "is false" do
          expect(subject.modified?).to be false
        end
      end
    end

    describe "#clear_changes" do
      it "clears changes" do
        subject.username = "new"
        subject.clear_changes

        expect(subject.modified?).to be false
      end
    end

    describe "#mark_for_deletion" do
      it "sets marked_for_deletion" do
        subject.mark_for_deletion

        expect(subject.marked_for_deletion?).to be true
      end
    end

    describe "#marked_for_deletion?" do
      it "defaults to false" do
        expect(subject.marked_for_deletion?).to be false
      end
    end

    describe "#to_h" do
      it "returns a Hash representation" do
        expect(subject.to_h).to include({username: "user", password: "pwd"})
      end

      context "when local_path is set" do
        let(:options) { {username: "user", password: "pwd", local_path: "local_path"} }

        it "includes local_path" do
          expect(subject.to_h).to include({local_path: "local_path"})
        end
      end

      context "when folders is set" do
        let(:options) { {username: "user", password: "pwd", folders: ["folder"]} }

        it "includes folders" do
          expect(subject.to_h).to include({folders: ["folder"]})
        end
      end

      context "when mirror_mode is set" do
        let(:options) { {username: "user", password: "pwd", mirror_mode: true} }

        it "includes mirror_mode" do
          expect(subject.to_h).to include({mirror_mode: true})
        end
      end

      context "when multi_fetch_size is set" do
        let(:options) { {username: "user", password: "pwd", multi_fetch_size: "3"} }

        it "includes multi_fetch_size" do
          expect(subject.to_h).to include({multi_fetch_size: 3})
        end
      end

      context "when server is set" do
        let(:options) { {username: "user", password: "pwd", server: "server"} }

        it "includes server" do
          expect(subject.to_h).to include({server: "server"})
        end
      end

      context "when connection_options is set" do
        let(:options) { {username: "user", password: "pwd", connection_options: '{"foo": "bar"}'} }

        it "includes connection_options" do
          expect(subject.to_h).to include({connection_options: {foo: "bar"}})
        end
      end

      context "when reset_seen_flags_after_fetch is set" do
        let(:options) { {username: "user", password: "pwd", reset_seen_flags_after_fetch: true} }

        it "includes reset_seen_flags_after_fetch" do
          expect(subject.to_h).to include({reset_seen_flags_after_fetch: true})
        end
      end
    end

    describe "#multi_fetch_size" do
      let(:options) { {username: "user", password: "pwd", multi_fetch_size: multi_fetch_size} }
      let(:multi_fetch_size) { 10 }

      it "returns the initialized value" do
        expect(subject.multi_fetch_size).to eq(10)
      end

      context "when the initialized value is a string representation of a positive number" do
        let(:multi_fetch_size) { "10" }

        it "returns one" do
          expect(subject.multi_fetch_size).to eq(10)
        end
      end

      context "when the initialized value is not a number" do
        let(:multi_fetch_size) { "ciao" }

        it "returns one" do
          expect(subject.multi_fetch_size).to eq(1)
        end
      end

      context "when the initialized value is not a positive number" do
        let(:multi_fetch_size) { "-99" }

        it "returns one" do
          expect(subject.multi_fetch_size).to eq(1)
        end
      end
    end

    [
      [:username, "username", "username"],
      [:password, "password", "password"],
      [:local_path, "local_path", "local_path"],
      [:multi_fetch_size, "2", 2],
      [:server, "server", "server"],
      [:folders, ["folder"], ["folder"]],
      [:connection_options, '{"some": "option"}', {some: "option"}]
    ].each do |attribute, value, expected|
      describe "setting ##{attribute}=" do
        let(:options) { {username: "original", password: "original"} }

        before { subject.send(:"#{attribute}=", value) }

        it "sets the #{attribute}" do
          expect(subject.send(attribute)).to eq(expected)
        end

        it "modifies the Account" do
          expect(subject.modified?).to be true
        end
      end
    end

    describe "#folders=" do
      context "when the supplied value is not an Array" do
        it "fails" do
          expect do
            subject.folders = "aaa"
          end.to raise_error(RuntimeError, /must be an Array/)
        end
      end
    end

    describe "#multi_fetch_size=" do
      context "when the supplied value is not a number" do
        before { subject.multi_fetch_size = "ciao" }

        it "sets multi_fetch_size to one" do
          expect(subject.multi_fetch_size).to eq(1)
        end
      end

      context "when the supplied value is not a positive number" do
        before { subject.multi_fetch_size = "-1" }

        it "sets multi_fetch_size to one" do
          expect(subject.multi_fetch_size).to eq(1)
        end
      end
    end

    describe "#connection_options=" do
      context "when the supplied value is not valid JSON" do
        it "fails" do
          expect do
            subject.connection_options = "NOT JSON"
          end.to raise_error(JSON::ParserError)
        end
      end
    end
  end
end
