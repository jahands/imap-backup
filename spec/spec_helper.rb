require "rspec"

ENV["SIMPLECOV_COMMAND_NAME"] = "RSpec tests"
require "simplecov"

$LOAD_PATH << File.expand_path("../lib", __dir__)

support_glob = File.join(__dir__, "support", "**", "*.rb")
Dir[support_glob].each { |f| require f }

silence_logging
