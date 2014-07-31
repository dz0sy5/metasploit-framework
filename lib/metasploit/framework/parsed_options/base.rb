#
# Standard Library
#

require 'optparse'

#
# Gems
#

require 'active_support/ordered_options'

#
# Project
#

require 'metasploit/framework/parsed_options'
require 'msf/base/config'

# Options parsed from the command line that can be used to change the `Metasploit::Framework::Application.config` and
# `Rails.env`
class Metasploit::Framework::ParsedOptions::Base
  #
  # CONSTANTS
  #

  # msfconsole boots in production mode instead of the normal rails default of development.
  DEFAULT_ENVIRONMENT = 'production'

  #
  # Attributes
  #

  attr_reader :positional

  #
  # Instance Methods
  #

  def initialize(arguments=ARGV)
    @positional = option_parser.parse(arguments)
  end

  # Translates {#options} to the `application`'s config
  #
  # @param application [Rails::Application]
  # @return [void]
  def configure(application)
    application.config['config/database'] = options.database.config
  end

  # Sets the `RAILS_ENV` environment variable.
  #
  # 1. If the -E/--environment option is given, then its value is used.
  # 2. The default value, 'production', is used.
  #
  # @return [void]
  def environment!
    if defined?(Rails) && Rails.instance_variable_defined?(:@_env)
      raise "#{self.class}##{__method__} called too late to set RAILS_ENV: Rails.env already memoized"
    end

    ENV['RAILS_ENV'] = options.environment
  end

  # Options parsed from
  #
  # @return [ActiveSupport::OrderedOptions]
  def options
    unless @options
      options = ActiveSupport::OrderedOptions.new

      options.database = ActiveSupport::OrderedOptions.new

      user_config_root = Pathname.new(Msf::Config.get_config_root)
      user_database_yaml = user_config_root.join('database.yml')

      if user_database_yaml.exist?
        options.database.config = user_database_yaml.to_path
      else
        options.database.config = 'config/database.yml'
      end

      options.database.disable = false
      options.database.migrations_paths = []

      options.framework = ActiveSupport::OrderedOptions.new
      options.framework.config = nil

      options.modules = ActiveSupport::OrderedOptions.new
      options.modules.path = nil

      options.environment = DEFAULT_ENVIRONMENT

      @options = options
    end

    @options
  end

  private

  # Parses arguments into {#options}.
  #
  # @return [OptionParser]
  def option_parser
    @option_parser ||= OptionParser.new { |option_parser|
      option_parser.separator ''
      option_parser.separator 'Common options'

      option_parser.on(
          '-E',
          '--environment ENVIRONMENT',
          %w{development production test},
          "The Rails environment. Will use RAIL_ENV environment variable if that is set.  " \
          "Defaults to production if neither option not RAILS_ENV environment variable is set."
      ) do |environment|
        options.environment = environment
      end

      option_parser.separator ''
      option_parser.separator 'Database options'

      option_parser.on(
          '-M',
          '--migration-path DIRECTORY',
          'Specify a directory containing additional DB migrations'
      ) do |directory|
        options.database.migrations_paths << directory
      end

      option_parser.on('-n', '--no-database', 'Disable database support') do
        options.database.disable = true
      end

      option_parser.on(
          '-y',
          '--yaml PATH',
          'Specify a YAML file containing database settings'
      ) do |path|
        options.database.config = path
      end

      option_parser.separator ''
      option_parser.separator 'Framework options'


      option_parser.on('-c', '-c FILE', 'Load the specified configuration file') do |file|
        options.framework.config = file
      end

      option_parser.on(
          '-v',
          '--version',
          'Show version'
      ) do
        options.subcommand = :version
      end

      option_parser.separator ''
      option_parser.separator 'Module options'

      option_parser.on(
          '-m',
          '--module-path DIRECTORY',
          'An additional module path'
      ) do |directory|
        options.modules.path = directory
      end

      #
      # Tail
      #

      option_parser.separator ''
      option_parser.on_tail('-h', '--help', 'Show this message') do
        puts option_parser
        exit
      end
    }
  end
end