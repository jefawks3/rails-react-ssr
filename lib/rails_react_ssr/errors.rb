module RailsReactSSR
  # RailsReactSSR error
  class Error < StandardError
  end

  # Bundle errors
  class BundleError < Error
    attr_reader :bundle

    def initialize(bundle, *args)
      super *args

      @bundle = bundle
    end
  end

  # Missing bundle package
  class MissingBundleError < BundleError
  end

  # Execution Error
  class ExecutionError < BundleError
  end
end
