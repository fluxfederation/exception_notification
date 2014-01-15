require 'action_mailer'
require 'pp'

class ExceptionNotifier
  class Notifier < ActionMailer::Base
    self.mailer_name = 'exception_notifier'
    self.append_view_path "#{File.dirname(__FILE__)}/views"

    @@whitelisted_env_vars = [
      'action_dispatch.request.parameters',
      'action_dispatch.request.path_parameters',
      'action_dispatch.request.query_parameters',
      'action_dispatch.request.request_parameters',
      'BUNDLE_BIN_PATH',
      'BUNDLE_GEMFILE',
      'CONTENT_LENGTH',
      'CONTENT_TYPE',
      'DOCUMENT_ROOT',
      'GEM_HOME',
      'HOME',
      /HTTP_/,
      'ORIGINAL_FULLPATH',
      'PASSENGER_APP_TYPE',
      'PASSENGER_ENV',
      'PASSENGER_RUBY',
      'PASSENGER_SPAWN_METHOD',
      'PASSENGER_USER',
      'PATH',
      'PATH_INFO',
      'PWD',
      'RAILS_ENV',
      'REMOTE_ADDR',
      'REMOTE_PORT',
      'REQUEST_METHOD',
      'REQUEST_URI',
      'RUBYOPT',
      'SERVER_ADDR',
      'SERVER_NAME',
      'SERVER_PORT',
      'SERVER_PROTOCOL',
      'SERVER_SOFTWARE',
      'TMPDIR',
      'USER',
    ]
    cattr_accessor :whitelisted_env_vars

    class << self
      def default_sender_address
        %("Exception Notifier" <exception.notifier@default.com>)
      end

      def default_exception_recipients
        []
      end

      def default_email_prefix
        "[ERROR] "
      end

      def default_sections
        %w(request session environment backtrace)
      end

      def default_options
        { :sender_address => default_sender_address,
          :exception_recipients => default_exception_recipients,
          :email_prefix => default_email_prefix,
          :sections => default_sections }
      end
    end

    class MissingController
      def method_missing(*args, &block)
      end
    end

    def exception_notification(env, exception)
      @exception  = exception
      @parameter_filter = ActionDispatch::Http::ParameterFilter.new(env["action_dispatch.parameter_filter"])
      @request    = ActionDispatch::Request.new(env)
      @env        = whitelist_env(@request.try(:filtered_env) || @parameter_filter.filter(env))
      @session    = @parameter_filter.filter(@request.session)
      @options    = (env['exception_notifier.options'] || {}).reverse_merge(self.class.default_options)
      @kontroller = env['action_controller.instance'] || MissingController.new
      @backtrace  = clean_backtrace(exception)
      @sections   = @options[:sections]
      @source     = "#{@kontroller.controller_name}##{@kontroller.action_name}"
      data        = env['exception_notifier.exception_data'] || {}

      data.each do |name, value|
        instance_variable_set("@#{name}", value)
      end

      subject  = "#{@options[:email_prefix]}#{@source} (#{@exception.class}) #{@exception.message.inspect[0..255]}"

      mail(:to => @options[:exception_recipients], :from => @options[:sender_address], :subject => subject) do |format|
        format.text { render "#{mailer_name}/exception_notification" }
      end
    end

    private

      def whitelist_env(env)
        env.select do |key, val|
          whitelisted_env_vars.any? do |allowed|
            allowed.is_a?(Regexp) ? key =~ allowed : key == allowed
          end
        end
      end
      
      def clean_backtrace(exception)
        Rails.respond_to?(:backtrace_cleaner) ?
          Rails.backtrace_cleaner.send(:filter, exception.backtrace) :
          exception.backtrace
      end
      
      helper_method :inspect_object
      
      def inspect_object(object)
        case object
        when Hash, Array
          object.inspect
        when ActionController::Base
          "#{object.controller_name}##{object.action_name}"
        else
          object.to_s
        end
      end
      
  end
end
