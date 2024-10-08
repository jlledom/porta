# frozen_string_literal: true

require 'active_support/string_inquirer'

module System
  module Database
    class ConnectionError < ActiveRecord::NoDatabaseError; end
    module_function

    def database_config
      @database_config ||= begin
        configurations = Rails.application.config.database_configuration
        ActiveRecord::DatabaseConfigurations.new(configurations).configs_for(env_name: Rails.env).first
      end
    end

    def adapter
      adapter_method.match(/^(oracle|postgres|mysql).*/).to_a.last
    end

    def adapter_method
      @adapter_method ||= ActiveSupport::StringInquirer.new(database_config.adapter)
    end

    def oracle?
      adapter_method.oracle_enhanced?
    end

    def mysql?
      adapter_method.mysql2?
    end

    def postgres?
      adapter_method.postgresql?
    end

    def execute_procedure(name, *params)
      command = postgres? ? 'SELECT' : 'CALL'
      ActiveRecord::Base.connection.execute("#{command} #{name}(#{params.join(',')})")
    end

    def ready?
      require_relative 'connection_probe'
      config = ConnectionProbe.connection_config
      connection_string = "#{config.fetch(:adapter)}://#{config.fetch(:username)}@#{config.fetch(:host) { 'localhost' }}/#{config.fetch(:database)}"
      if ConnectionProbe.ready?
        puts "Connected to #{connection_string}"
        return true
      else
        puts "Cannot connect to #{connection_string}"
        return false
      end
    rescue ActiveRecord::NoDatabaseError => error # In case of mysql
      puts "Connected, but database does not exist: #{error}"
      true
    rescue StandardError => error
      puts "Connection specification: #{config}"
      puts "Failed to connect to database: #{error} (#{error.class})"

      if (cause = error.cause)
        puts "Caused by: #{cause} (#{cause.class})"
      end
      false
    end

    module Scopes
      module IdOrSystemName
        def find_by_id_or_system_name!(id_or_system_name)
          by_id_or_system_name(id_or_system_name).first!
        end

        def find_by_id_or_system_name(id_or_system_name)
          by_id_or_system_name(id_or_system_name).first
        end

        def by_id_or_system_name(id_or_system_name)
          where.has do
            scope = (system_name == id_or_system_name)

            begin
              # TODO: tried using TO_NUMBER('n' DEFAULT 0 ON CONVERSION ERROR), but that fails with:
              #   OCIError: ORA-43907: This argument must be a literal or bind variable.
              # Maybe worth trying again on Rails 5.2.
              scope | (id == Integer(id_or_system_name))
            rescue ArgumentError
              scope
            end
          end
        end
      end
    end

    module Definitions
      extend ActiveSupport::Concern

      included do
        @triggers = []
        @procedures = []

        class << self
          attr_reader :triggers, :procedures

          def define(&block)
            @triggers.clear
            @procedures.clear

            class_eval(&block)
          end

          def trigger(name, options = {})
            klass_name = "#{System::Database.adapter_module}::Trigger"
            args = [name, yield]
            if variables = options[:with_variables].presence
              klass_name += 'WithVariables'
              args << variables
            end
            @triggers << klass_name.constantize.new(*args)
          end

          def procedure(name, parameters = {})
            klass_name = "#{System::Database.adapter_module}::Procedure"
            @procedures << klass_name.constantize.new(name, yield, parameters)
          end
        end
      end
    end

    def adapter_module
      case adapter.to_sym
      when :mysql
        require 'system/database/mysql'
        MySQL
      else
        require "system/database/#{adapter}"
        "System::Database::#{adapter.camelize}".constantize
      end
    end

    extend SingleForwardable

    def_delegators :adapter_module, :triggers, :procedures
  end
end

ActiveSupport.on_load(:active_record) do
  if System::Database.oracle? && defined?(ActiveRecord::ConnectionAdapters::OracleEnhancedAdapter::DatabaseTasks)

    ActiveRecord::ConnectionAdapters::OracleEnhancedAdapter.permissions = ['unlimited tablespace', 'create session',
                                                                           'create table', 'create view', 'create sequence',
                                                                           'create trigger', 'create procedure']

    ActiveRecord::ConnectionAdapters::OracleEnhancedAdapter::DatabaseTasks.class_eval do
      prepend(Module.new do
        # If ORACLE_SYSTEM_PASSWORD is provided, Porta impersonates Oracle's SYSTEM user to create/update a non-SYSTEM
        # user and grants it permissions. This is a behaviour that should preferably be used during development as
        # the usage of Oracle's SYSTEM user grants the application more power than it should have in the first place.
        # Alternatively, Porta should be provided with a non-SYSTEM user that has been granted the necessary
        # permissions.
        def create
          if ENV['ORACLE_SYSTEM_PASSWORD'].present?
            Logger.new($stderr).warn("Oracle's SYSTEM user will create/update a non-SYSTEM user and grant it permissions")
            super

            if ["1", "true"].include?(ENV["ORACLE_DO_NOT_EXPIRE_SYSTEM"])
              profile = connection.execute("select profile from DBA_USERS where username = 'SYSTEM'").fetch.first
              connection.execute "alter profile #{profile} limit password_life_time UNLIMITED"
            end
          else
            # Will raise ActiveRecord::NoDatabaseError if the database doesn't exist
            establish_connection(@config)
          end
        end
      end)
    end
  end
end
