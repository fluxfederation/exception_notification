require 'test_helper'

class EmailNotifierWhitespaceTest < ActiveSupport::TestCase
  setup do
    @dummy_env_var = "KAKEEDKANSJHSJIWWKSKLALEJE"

    Time.stubs(:current).returns('Sat, 20 Apr 2013 20:58:55 UTC +00:00')
    @email_notifier = ExceptionNotifier.registered_exception_notifier(:email)
    @captured_env_vars = Hash[@email_notifier.mailer.whitelisted_env_vars.map do |k|
        k = k.to_s.sub(/^(\(.*:)(.*)(\))$/, '\2') if k.is_a? Regexp
        [k.to_s, "val #{k}"]
      end]

    begin
      1/0
    rescue => e
      @exception = e
      @mail1 = @email_notifier.create_email(@exception,
        :sections => %w(environment),
        :env => @captured_env_vars.dup)
      @mail2 = @email_notifier.create_email(@exception,
        :sections => %w(environment),
        :env => {@dummy_env_var => "woot"})
    end
  end

  test "should have the same whitelist at class and instance level" do
    #NB: Need to use #class_eval, as the underlying is dynamically extended
    assert @email_notifier.mailer.whitelisted_env_vars == @email_notifier.mailer.class_eval { self.whitelisted_env_vars }
  end

  test "should keep whitelisted env-vars" do
    @captured_env_vars.each do |k, v|
      assert @mail1.body =~ /\*\s*#{k}\s*:\s*#{v}$/, "Could not find #{k.inspect}: #{v.inspect} in the mail.body"
    end
  end

  test "should drop the non-whitelisted env-vars" do
    assert @mail1.body !~ /#{@dummy_env_var}:/
  end

  test "should update the class-level whitelisted env-vars" do
    # Make sure the dummy var-name isn't somehow in the whitelisted list, before we start:
    assert !@email_notifier.mailer.whitelisted_env_vars.include?(@dummy_env_var)
    assert !@email_notifier.mailer.class_eval { whitelisted_env_vars }.include?(@dummy_env_var)

    @email_notifier.mailer.whitelisted_env_vars << @dummy_env_var

    assert @email_notifier.mailer.whitelisted_env_vars.include?(@dummy_env_var)
    assert @email_notifier.mailer.class_eval { whitelisted_env_vars }.include?(@dummy_env_var)
  end
end
