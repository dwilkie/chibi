module CdrHelpers
  private

  def build_cdr(*args)
    typed_cdr(*args)
  end

  def create_cdr(*args)
    typed_cdr = typed_cdr(*args)
    binding.pry
    typed_cdr.save!
    typed_cdr
  end

  def typed_cdr(*args)
    CallDataRecord.new(:body => cdr_body(args)).typed
  end

  def cdr_body(*args)
    build(*(([:call_data_record] << args).flatten)).body
  end
end
