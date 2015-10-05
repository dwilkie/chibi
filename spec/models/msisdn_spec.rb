require 'rails_helper'

describe Msisdn do

  describe "defaults" do
    it { is_expected.not_to be_active }
  end

  describe "associations" do
    it { is_expected.to have_many(:msisdn_discoveries) }
  end

  describe "validations" do
    subject { build(:msisdn) }

    it { is_expected.to validate_presence_of(:mobile_number) }
    it { is_expected.to validate_uniqueness_of(:mobile_number) }
    it { is_expected.not_to allow_value(attributes_for(:user, :with_invalid_mobile_number)[:mobile_number]).for(:mobile_number) }
  end

  describe "#blacklisted?" do
    subject { create(:msisdn) }

    context "for ordinary numbers" do
      it { is_expected.not_to be_blacklisted }
    end

    context "for blacklisted numbers" do
      subject { create(:msisdn, :blacklisted) }
      it { is_expected.to be_blacklisted }
    end
  end

  describe "#activate!" do
    subject { create(:msisdn) }

    before do
      subject.activate!
      subject.reload
    end

    context "is active" do
      subject { create(:msisdn, :active) }
      it { is_expected.to be_active }
    end

    context "is inactive" do
      subject { create(:msisdn, :inactive) }
      it { is_expected.to be_active }
    end
  end

  describe "#deactivate!" do
    subject { create(:msisdn) }

    before do
      subject.deactivate!
      subject.reload
    end

    context "is active" do
      subject { create(:msisdn, :active) }
      it { is_expected.not_to be_active }
    end

    context "is inactive" do
      subject { create(:msisdn, :inactive) }
      it { is_expected.not_to be_active }
    end
  end
end
