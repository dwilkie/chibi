module MissedCallHelpers
  include AuthenticationHelpers

  def missed_call(options = {})
    post_missed_call options
  end

  def expect_call(options = {}, &block)
    VCR.use_cassette("twilio/calls", :match_requests_on => [:method, :uri, :body], :erb => {
      :account_sid => ENV['TWILIO_ACCOUNT_SID'],
      :auth_token =>  ENV['TWILIO_AUTH_TOKEN'],
      :from => ENV['TWILIO_OUTGOING_NUMBER'],
      :application_sid => ENV['TWILIO_APPLICATION_SID'],
      :to => options[:to]
    }) do
      yield
    end
  end

  private

  def post_missed_call(options = {})
    with_resque do
      post missed_calls_path,
      {
        :to => options[:to] || "<#{ENV['CLOUDMAILIN_FORWARD_ADDRESS']}>",
        :disposable => options[:disposable] || "",
        :from => options[:from] || "androidmcmail@genovese.dreamhost.com",
        :subject => options[:subject] || "You have a missed call from #{options[:number]}",
        :message => options[:message] || "You had a missed call from #{options[:number]}",
        :plain => options[:plain] || "You had a missed call from #{options[:number]}",
        :html => options[:html] || "",
        :mid => options[:mid] || "20120317054111.03CFD16E001@genovese.dreamhost.com",
        :x_to_header => options[:x_to_header] || "[\"4f2ae593a7c8c5785a77@cloudmailin.net\"]",
        :x_from_header => options[:x_from_header] || "[\"no-reply@mcmail.android.bitplane.net\"]",
        :x_cc_header => options[:x_cc_header] || "",
        :x_remote_ip => options[:x_remote_ip] || "208.113.175.8",
        :helo_domain => options[:helo_domain] || "smarty.dreamhost.com",
        :signature => options[:signature] || "d12ae6c85f3e136a69a5d678aea47101"
      }, authentication_params(:missed_call)
    end

    response.status.should be(options[:response] || 200)
  end
end
