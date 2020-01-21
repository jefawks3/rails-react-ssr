require 'uri'

module RailsReactSSR
  class WebpackerUtils
    ##
    # Return the hashed name from the +bundle+
    def self.hashed_bundle_name!(bundle)
      Webpacker.manifest.lookup! bundle
    rescue Webpacker::Manifest::MissingEntryError
      raise RailsReactSSR::MissingBundleError.new(bundle, "The ReactJS package '#{bundle}' is missing from the manifest.json file.")
    end

    ##
    # Open the +bundle+ file for reading
    #
    # Returns IO stream with the +bundle+ contents. If +bundle+ cannot be found,
    # raises +RailsReactSSR::MissingBundleError+
    def self.open_bundle(bundle, max_tries: 10, delay: 1000)
      hashed = hashed_bundle_name! bundle

      if Webpacker.dev_server.running?
        dev_server_bundle hashed, max_tries, delay
      else
        local_file_bundle hashed
      end
    end

    private

    def self.dev_bundle_uri(path)
      URI::Generic.new(
          Webpacker.dev_server.protocol,
          nil,
          Webpacker.dev_server.host,
          Webpacker.dev_server.port,
          nil,
          path,
          nil,
          nil,
          nil
      ).to_s
    end

    def self.bundle_fullpath(path)
      File.join Rails.root, 'public', path
    end

    def self.dev_server_bundle(hashed_bundle, max_tries, delay, tries = 0)
      tries += 1

      uri = self.dev_bundle_uri hashed_bundle

      Rails.logger.debug "Reading remote bundle #{uri}"

      open uri
    rescue OpenURI::HTTPError => e
      # On the first page hit my not be available on the dev server so we need to wait for it to compile
      if tries < max_tries
        Rails.logger.debug "The remote bundle is not ready trying again in #{delay}ms - #{tries} of #{max_tries}"
        sleep delay / 1000
        retry
      else
        raise e
      end
    end

    def self.local_file_bundle(hashed_bundle)
      full_path = File.join Rails.root, 'public', hashed_bundle

      File.open full_path, 'rb'
    end
  end
end