require 'spec_helper'

describe "Report" do
  include AuthenticationHelpers
  include ActiveJobHelpers
  include ReportHelpers

  before do
    stub_redis
  end

  def report_path
    super(:format => :json)
  end

  def authentication_params
    super(:admin)
  end

  def report_params(params = {})
    {:report => params}
  end

  def post_report(params = {})
    post(
      report_path,
      report_params(params),
      authentication_params
    )
  end

  def get_report
    get(
      report_path,
      {},
      authentication_params
    )
  end

  def do_post_report(request_params = {}, options = {})
    trigger_job(options) { post_report(request_params) }
  end

  def post_wait_and_retrieve_report(params)
    do_post_report(params)
    get_report
  end

  describe "POST '/report.json'", :active_job do
    context "with valid params" do
      before do
        do_post_report({:month => 1, :year => 2014}, :queue_only => true)
      end

      it "should queue a job to generate a report" do
        expect(enqueued_jobs.size).to eq(1)
        job = enqueued_jobs.first
        job[:args].first.should == {"year" => "2014", "month" => "1"}
      end

      it "should return a 201" do
        response.status.should be(201)
      end
    end

    context "with invalid params" do
      before do
        do_post_report({:year => 2014}, :queue_only => true)
      end

      it "should not queue a job to generate a report" do
        expect(enqueued_jobs.size).to eq(0)
      end

      it "should return a 400" do
        response.status.should be(400)
      end
    end
  end

  describe "GET '/report.json'" do
    context "given the report has not yet been generated" do
      before do
        get_report
      end

      it "should return a 404" do
        response.status.should be(404)
      end
    end

    context "given the report has already been generated" do
      before do
        post_wait_and_retrieve_report(:year => 2014, :month => 1)
      end

      it "should return a 200" do
        response.status.should be(200)
      end

      it "should return the generated report" do
        parsed_response = JSON.parse(response.body)["report"]
        parsed_response["month"].should == "1"
        parsed_response["year"].should == "2014"
      end
    end
  end

  describe "'DELETE' /report.json" do
    def delete_report
      delete(
        report_path,
        {},
        authentication_params
      )
    end

    before do
      delete_report
    end

    it "should return a 200" do
      response.status.should be(200)
    end

    it "should delete the report" do
      post_wait_and_retrieve_report(:month => 1, :year => 2014)
      response.status.should be(200)
      delete_report
      get_report
      response.status.should be(404)
    end
  end
end
