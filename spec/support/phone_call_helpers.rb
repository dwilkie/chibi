def phone_call_prompts(&block)
  [:gender, :looking_for].each do |attribute|
    [nil, :_in_menu].each do |call_context|
      yield(attribute, call_context, "asking_for_#{attribute}#{call_context}_phone_call".to_sym)
    end
  end
end

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
    options[:call_sid]
  end
end
