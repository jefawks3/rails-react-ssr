require 'test_helper'
require 'webpacker/dev_server_runner'

class RailsReactSSR::WebpackerUtilsTest < RailsReactSSR::Test
  def test_bundle_not_found!
    error = assert_raises RailsReactSSR::MissingBundleError do
      RailsReactSSR::WebpackerUtils.hashed_bundle_name! 'missing.js'
    end

    assert_match 'missing.js', error.bundle
    assert_match "The ReactJS package 'missing.js' is missing from the manifest.json file.", error.message
  end

  def test_bundle_found!
    assert_equal RailsReactSSR::WebpackerUtils.hashed_bundle_name!('application.js'),
                 '/packs/application-k344a6d59eef8632c9d1.js'
  end

  def test_open_local_file
    io = RailsReactSSR::WebpackerUtils.open_bundle 'application.js'

    refute Webpacker.dev_server.running?

    assert_equal io.read, raw_application_js
  end

  def test_open_remote_file
    # TODO Run dev server during tests to make sure remote file is accessible
    skip 'Need to find a way to run the dev server during the tests'
  end

  def test_build_remote_uri
    with_rails_env 'development' do
      hashed_bundle = '/packs/application-k344a6d59eef8632c9d1.js'
      uri = RailsReactSSR::WebpackerUtils.send :dev_bundle_uri, hashed_bundle

      assert_equal uri, 'http://localhost:3035/packs/application-k344a6d59eef8632c9d1.js'
    end
  end

  private

  def raw_application_js
    <<-AppplicaitonJS
console.log('Hello World from Webpacker');

stdout('<html><body>Hello from the server</body></html>');
    AppplicaitonJS
  end
end