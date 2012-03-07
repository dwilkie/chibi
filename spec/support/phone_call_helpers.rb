module PhoneCallHelpers
  include AuthenticationHelpers

  def make_call(options = {})
    post_phone_call options
  end

  alias :update_call_status :make_call

  private

  def post_phone_call(options = {})
    post phone_calls_path(:format => :xml),
    {
      :From => options[:from],
      :CallSid => options[:call_sid] || "245",
      :Channel => options[:channel] || "test",
      :Digits => options[:digits]
    }, authentication_params

    response.status.should be(options[:response] || 200)
  end
end
