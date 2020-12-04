require "spec_helper"

RSpec.describe Test::Span do
  let(:tracer) { Test::Tracer.new }
  let(:span_context) { Test::SpanContext.root }
  let(:operation_name) { "span_name" }
  let(:span) { Test::Span.new(tracer: tracer, context: span_context, operation_name: operation_name) }

  describe :initialize do
    describe :in_progress? do
      it "is in progress" do
        expect(span.in_progress?).to eq(true)
        expect(span.started?).to eq(true)
      end
    end

    describe :finished? do
      it "is not finished" do
        expect(span.finished?).to eq(false)
      end
    end

    describe :operation_name do
      it "returns operation_name from initialization" do
        expect(span.operation_name).to eq(operation_name)
      end
    end

    describe :start_time do
      it "returns start_time from initialization" do
        time = Time.now - 60
        expect(Test::Span.new(tracer: tracer, context: span_context, operation_name: operation_name, start_time: time).start_time).to eq(time)
      end
    end
  end

  describe "OT spec" do
    describe :operation_name= do
      it "allows to change operation name" do
        new_span_name = "New span name"
        span.operation_name = new_span_name
        expect(span.operation_name).to eq(new_span_name)
      end

      it "allows only strings" do
        expect { span.operation_name = true }.to raise_error(TypeError)
      end
    end

    describe :context do
      it "allows to read context from initialization" do
        expect(span.context).to eq(span_context)
      end
    end

    describe :set_tag do
      it "returns current span instance" do
        expect(span.set_tag("key", "value")).to eq(span)
      end

      it "sets the tag" do
        span.set_tag("key", "value")
        expect(span.tags["key"]).to eq("value")
      end

      it "allows string only keys" do
        expect { span.set_tag(true, "value") }.to raise_error(TypeError)
      end

      it "allows to pass string, numeric, boolean as is, and encode other types with to_s for values" do
        [
          ["value", "value"],
          [2 ** 63 - 1, 2 ** 63 - 1],
          [2 ** 64, 2 ** 64],
          [1.to_f, 1.to_f],
          [true, true],
          [false, false],
          [{authenticated_user_id: 1}, "{:authenticated_user_id=>1}"]
        ].each do |value, expected|
          expect(span.set_tag("key", value).tags["key"]).to eq(expected)
        end
      end
    end

    describe :set_baggage_item do
      it "returns current span instance" do
        expect(span.set_baggage_item("key", "value")).to eq(span)
      end

      it "sets a baggage on context" do
        span.set_baggage_item("key", "value")
        expect(span.context.baggage["key"]).to eq("value")
      end

      it "allows string only keys" do
        expect { span.set_baggage_item(true, "value") }.to raise_error(TypeError)
      end

      it "allows to pass string only values" do
        [
          [2 ** 63 - 1, 2 ** 63 - 1],
          [2 ** 64, 2 ** 64],
          [1.to_f, 1.to_f],
          [true, true],
          [false, false],
          [{authenticated_user_id: 1}, "{:authenticated_user_id=>1}"]
        ].each do |value, _|
          expect { span.set_baggage_item("key", value) }.to raise_error(TypeError)
        end
      end
    end

    describe :get_baggage_item do
      it "returns found baggage item" do
        expect(span.set_baggage_item("key", "value").get_baggage_item("key")).to eq("value")
      end

      it "returns nil if baggage item is not found" do
        expect(span.get_baggage_item("key")).to eq(nil)
      end

      it "allows string only keys" do
        expect { span.get_baggage_item(true) }.to raise_error(TypeError)
      end
    end

    describe :log do
      it "creates new log entry" do
        span.log
        expect(span.logs.size).to eq(1)
      end

      it "fills up log entries attributes properly" do
        time = Time.now
        span.log(event: "event", timestamp: time, additional: :info)
        log = span.logs.last

        expect(log).to be_instance_of(Test::Span::LogEntry)
        expect(log.event).to eq("event")
        expect(log.timestamp).to eq(time)
        expect(log.fields).to eq(additional: :info)
      end
    end

    describe :log_kv do
      it "creates new log entry" do
        span.log_kv
        expect(span.logs.size).to eq(1)
      end

      it "fills up log entries attributes properly" do
        time = Time.now
        span.log_kv(timestamp: time, additional: :info)
        log = span.logs.last

        expect(log).to be_instance_of(Test::Span::LogEntry)
        expect(log.event).to be_nil
        expect(log.timestamp).to eq(time)
        expect(log.fields).to eq(additional: :info)
      end
    end

    describe :finish do
      describe :in_progress? do
        it "is not in progress" do
          span.finish
          expect(span.in_progress?).to eq(false)
          expect(span.started?).to eq(false)
        end
      end

      describe :finished? do
        it "is finished" do
          span.finish
          expect(span.finished?).to eq(true)
        end
      end

      describe :end_time do
        it "allows to pass custom end_time" do
          time = Time.now + 60
          span.finish(end_time: time)

          expect(span.end_time).to eq(time)
        end
      end

      it "deoesn't allow for finish to be called twice" do
        span.finish
        expect { span.finish }.to raise_error(Test::Span::SpanAlreadyFinished)
      end

      describe "modification operations" do
        context "after finish is called" do
          it "doesn't allow for modifications after span is finished" do
            span.finish
            expect { span.operation_name = "new span name" }.to raise_error(Test::Span::SpanAlreadyFinished)
            expect { span.set_tag("key", "value") }.to raise_error(Test::Span::SpanAlreadyFinished)
            expect { span.set_baggage_item("key", "value") }.to raise_error(Test::Span::SpanAlreadyFinished)
          end
        end
      end
    end
  end
end
