require 'test_helper'

class RailsReactSSR::ServerRunnerTest < RailsReactSSR::Test
  def setup
    # Do nothing
  end

  def teardown
    # Do nothing
  end

  def test_application_temp_output
    tempFile = File.expand_path 'tmp/output.js'

    File.unlink tempFile if File.exists? tempFile

    RailsReactSSR::ServerRunner.exec! 'application.js', outputTemp: tempFile

    assert_equal File.read(tempFile), <<-OUTPUT
const stdout = console.log;
const stderr = console.error;

const recordedLogs = [];

['log', 'info', 'debug', 'warn', 'error'].forEach(level => {
    console[level] = (...args) => {
        recordedLogs.push({ level: level, args: args });
    }
});


const serverProps = {};

console.log('Hello World from Webpacker');

stdout('<html><body>Hello from the server</body></html>');
    OUTPUT
  end

  def test_application_output
    output = RailsReactSSR::ServerRunner.exec! 'application.js'

    assert_equal output, <<-OUTPUT
<html><body>Hello from the server</body></html>
OUTPUT
  end
end