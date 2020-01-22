require 'webpacker'
require 'shellwords'
require 'active_support/json'
require 'open-uri'
require 'rails'
require 'open3'

module RailsReactSSR
  ##
  # Executes the ReactJS package using NodeJS that was built using webpacker
  class ServerRunner
    ##
    # Redirect console output to be logged by an array
    CONSOLE_POLYFILL = <<-CONSOLE_POLYFILL
const stdout = console.log;
const stderr = console.error;

const recordedLogs = [];

['log', 'info', 'debug', 'warn', 'error'].forEach(level => {
    console[level] = (...args) => {
        recordedLogs.push({ level: level, args: args });
    }
});
    CONSOLE_POLYFILL

    ##
    # Execute the bundled package
    #
    # <tt>:props</tt> - The properties to pass to the server JS code
    # <tt>:outputTemp</tt> - If true, output the compiled bundle to the tmp/ssr directory, pass a string to specify the
    #   output file
    # <tt>:max_tries</tt> - The number of tries when getting the bundle from the webpack dev server
    # <tt>:delay</tt> - The delay in ms between tries
    def self.exec!(bundle, props: {}, outputTemp: false, max_tries: 10, delay: 1000)
      bundle_file = RailsReactSSR::WebpackerUtils.open_bundle bundle, max_tries: max_tries, delay: delay

      status = 0
      output = nil

      begin
        js = Tempfile.new [File.basename(bundle_file, '.*'), File.extname(bundle_file)]

        begin
          write_console_polyfill js
          write_props_polyfill js, props
          write_bundle js, bundle_file

          js.flush

          if outputTemp
            outputTemp = Rails.root.join('tmp/ssr/', bundle) if outputTemp.is_a? TrueClass

            Rails.logger.debug "Coping server bundle to #{outputTemp}"
            IO.copy_stream js.path, outputTemp
          end

          status, output = exec_contents js
        ensure
          js.unlink
        end
      rescue => e
        Rails.logger.error "Unable to execute the bundle '#{bundle}': #{e.message}"
        raise RailsReactSSR::ExecutionError.new(bundle, "Unable to run the bundle '#{bundle}'")
      ensure
        bundle_file.close
      end

      raise RailsReactSSR::ExecutionError.new(bundle,"Unable to execute the server bundle #{bundle}") unless status.zero?

      output
    end

    private

    def self.exec_contents(file)
      output = error = ''

      cmd = ['node', Shellwords.escape(file.path)]

      cmd_str = cmd.join ' '

      status = Open3.popen3 cmd_str do |inp, out, err, thr|
        output = out.read
        error = err.read

        Rails.logger.info "[#{thr.value.exitstatus}}] #{cmd_str}"
        Rails.logger.debug output
        Rails.logger.error error unless error.nil? || error.empty?

        thr.value.exitstatus
      end

      [status, output]
    end

    def self.write_props_polyfill(temp_file, props)
      ## Format the properties for js
      jsProps = props.inject({}) do |hash,(k,v)|
        hash[k.to_s.camelcase.gsub(/\A./, &:downcase)] = v
        hash
      end

      temp_file.write <<-JS
const serverProps = #{ActiveSupport::JSON.encode jsProps};

      JS
    end

    def self.write_console_polyfill(temp_file)
      temp_file.write CONSOLE_POLYFILL
      temp_file.write "\n\n"
    end

    def self.write_bundle(temp_file, bundle_file)
      IO.copy_stream bundle_file, temp_file
    end

  end
end