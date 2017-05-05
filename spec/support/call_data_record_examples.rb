shared_examples_for "call_data_record" do
  describe "associations" do
    it { is_expected.to belong_to(:phone_call) }
    it { is_expected.to belong_to(:inbound_cdr) }
  end
end
