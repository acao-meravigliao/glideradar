
module Glideradar

class SniffWorker < Tomte::Worker

  attr_accessor :producer
  attr_accessor :raw_producer

  bus :service do |ep|
    @consumer = ep.consumer(
      :queue => config.glideradar[:exchange] + '.sniff',
      :queue_options => {
        :passive => false,
        :auto_delete => true,
      },
      :prefetch => 1,
    )

    @consumer.connect! do |c|
      c.bind(config.glideradar[:exchange], :routing_key => '#')
      c.consume { log.info "ready to receive messages on #{config.glideradar[:exchange]}" }
    end

    @consumer.on_delivery do |metadata, message|
      log.info "ORTOMIOOOOOOOOOOOOOO"
      metadata.ack
    end
  end

  def init(args = {})
  end
end

end
