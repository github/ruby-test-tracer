module Test
  class Span < OpenTracing::Span
    class SpanAlreadyFinished < StandardError; end

    class LogEntry < Struct.new(:event, :timestamp, :fields); end

    include TypeCheck

    attr_reader :tracer, :operation_name, :start_time, :end_time, :tags, :logs

    def initialize(tracer:, context:, operation_name:, start_time: Time.now, tags: nil)
      Type! tracer, ::Test::Tracer
      Type! context, ::Test::SpanContext
      Type! operation_name, String
      Type! start_time, Time
      Type! tags, Hash, NilClass

      @tracer = tracer
      @context = context
      @operation_name = operation_name
      @tags = tags || {}
      @logs = []
      @start_time = start_time
      @end_time = nil
      @in_progress = true
    end

    def in_progress?
      @in_progress
    end

    alias_method :started?, :in_progress?

    def finished?
      !in_progress?
    end

    def context
      @context
    end

    def operation_name=(name)
      Type! name, String
      ensure_in_progress!

      @operation_name = name
    end

    def set_tag(key, value)
      Type! key, String
      ensure_in_progress!

      @tags[key] = Type?(value, String, Fixnum, Bignum, Float, TrueClass, FalseClass) ? value : value.to_s
      self
    end

    def set_baggage_item(key, value)
      Type! key, String
      Type! value, String, NilClass
      ensure_in_progress!

      @context.baggage[key] = value.to_s
      self
    end

    def get_baggage_item(key)
      Type! key, String
      @context.baggage[key]
    end

    def log(event: nil, timestamp: Time.now, **fields)
      warn 'Span#log is deprecated.  Please use Span#log_kv instead.'

      Type! event, String, NilClass
      Type! timestamp, Time
      ensure_in_progress!

      @logs << LogEntry.new(event, timestamp, fields)
    end

    def log_kv(timestamp: Time.now, **fields)
      Type! timestamp, Time
      ensure_in_progress!

      @logs << LogEntry.new(nil, timestamp, fields)
    end

    def finish(end_time: Time.now)
      Type! end_time, Time
      ensure_in_progress!

      @end_time = end_time
      @in_progress = false
      @tracer.finished_spans << self
      self
    end

    def to_s
      "Span(operation_name=#{operation_name}, " +
        "in_progress=#{in_progress?}, " +
        "tags=#{tags}, " +
        "logs=#{logs}, " +
        "start_time=#{start_time}, " +
        "end_time=#{end_time}, " +
        "context=#{context})"
    end

  private

    def ensure_in_progress!
      unless in_progress?
        raise SpanAlreadyFinished.new("No modification operations allowed. The span is already finished.")
      end
    end
  end
end
