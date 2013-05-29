module CdrHelpers
  private

  def build_cdr(*args)
    CallDataRecord.new(:body => cdr_body(args))
  end

  def create_cdr(*args)
    CallDataRecord.create!(:body => cdr_body(args))
  end

  def cdr_body(*args)
    build(*(([:call_data_record] << args).flatten)).body
  end
end
