#!/usr/bin/env ruby2.1
#
# Copyright (C) 2014-2014, Daniele Orlandi
#
# Author:: Daniele Orlandi <daniele@orlandi.com>
#
# License:: You can redistribute it and/or modify it under the terms of the LICENSE file.
#

require 'ygg/agent/base'

require 'ygg/app/line_buffer'

require 'glideradar/version'
require 'glideradar/task'

require 'serialport'

module Glideradar

class App < Ygg::Agent::Base
  self.app_name = 'glideradar'
  self.app_version = VERSION
  self.task_class = Task

  def prepare_default_config
    app_config_files << File.join(File.dirname(__FILE__), '..', 'config', 'glideradar.conf')
    app_config_files << '/etc/yggdra/glideradar.conf'
  end

  def prepare_options(o)
    super

    o.on('--debug-serial', 'Debug serial messages') { |v| config.debug_serial = true }
  end

  def agent_boot
    @my_alt = 0
    @my_lat = 0
    @my_lng = 0

    @pending_updates = {}

    @gps_status = nil

    @amqp.ask(AM::AMQP::MsgDeclareExchange.new(
      name: mycfg.exchange,
      type: :topic,
      options: {
        durable: true,
        auto_delete: false,
      }
    )).value

    @line_buffer = Ygg::App::LineBuffer.new(line_received_cb: method(:receive_line))

    @serialport = SerialPort.new(mycfg.serial.device,
      'baud' => mycfg.serial.speed,
      'data_bits' => 8,
      'stop_bits' => 1,
      'parity' => SerialPort::NONE)

    @actor_epoll.add(@serialport, SleepyPenguin::Epoll::IN)
  end

  def receive(events, io)
    case io
    when @serialport
      data = @serialport.read_nonblock(65536)

      if !data || data.empty?
        @actor_epoll.del(@socket)
        actor_exit
        return
      end

      @line_buffer.push(data)
    else
      super
    end
  end

  def receive_line(line)

    line.chomp!

    log.debug "<<< #{line}" if config.debug_serial

    if mycfg.raw_exchange
      @amqp.tell AM::AMQP::MsgPublish.new(
        destination: mycfg.raw_exchange,
        payload: line.dup,
        options: {
          content_type: 'application/octet-stream',
          type: 'RAW',
          persistent: false,
          mandatory: false,
          expiration: 60000,
          headers: {
          },
        }
      )
    end

    if line =~ /\$([A-Z]+),(.*)\*([0-9A-F][0-9A-F])$/
      sum = line[1..-4].chars.inject(0) { |a,x| a ^ x.ord }
      chk = $3.to_i(16)

      if sum == chk
        handle_nmea($1, $2)
      else
        log.error "NMEA CHK INCORRECT"
      end
    end
  end

  def handle_nmea(msg, values)
    case msg
    when 'GPGGA' ; handle_gpgga(values)
    when 'GPGSA' ; handle_gpgsa(values)
    when 'GPRMC' ; handle_gprmc(values)
    when 'PGRMZ' ; handle_pgrmz(values)
    when 'PFLAU' ; handle_pflau(values)
    when 'PFLAA' ; handle_pflaa(values)
    end
  end

  def handle_pgrmz(line)
  end

  def handle_gpgga(line)
    (time, lat, lat_dir, lng, lng_dir, fix_qual, satellites, hdop,
     altitude, altitude_unit, height_of_geoid, height_of_geoid_unit, time_since_dgps, dgps_station_id) = nmea_parse(line)

    @my_alt = altitude.to_f

    @gps_fix_qual = fix_qual.to_i
    @gps_sats = satellites.to_i
  end

  def handle_gpgsa(line)
    (gps_alt_mode, gps_fix_type, sat1, sat2, sat3, sat4, sat5, sat6, sat7, sat8, sat9, sat10, sat11, sat12,
    gps_pdop, gps_hdop, gps_vdop) = nmea_parse(line)

    @gps_pdop = gps_pdop.to_f
    @gps_hdop = gps_hdop.to_f
    @gps_vdop = gps_vdop.to_f

    @gps_fix_type = gps_fix_type.to_i
  end

  def handle_gprmc(line)
    (time, warning, lat, lat_dir, lng, lng_dir, sog, cog, date, mag_var) = nmea_parse(line)

    tm = time.match(/^([0-9]{2})([0-9]{2})([0-9]{2}\.[0-9]+)$/)
    dm = date.match(/^([0-9]{2})([0-9]{2})([0-9]{2})$/)

    if dm && tm
      @time = Time.utc(dm[3].to_i + 2000, dm[2].to_i, dm[1].to_i, tm[1].to_i, tm[2].to_i, tm[3].to_f)
    else
      @time = nil
    end

    @my_lat = (lat[0..1].to_f + lat[2..-1].to_f / 60) * (lat_dir == 'N' ? 1 : -1)
    @my_lng = (lng[0..2].to_f + lng[3..-1].to_f / 60) * (lng_dir == 'E' ? 1 : -1)
    @my_sog = sog.to_f
    @my_cog = cog.to_i

    @amqp.tell AM::AMQP::MsgPublish.new(
      destination: mycfg.exchange,
      payload: {
        station_id: mycfg.station_name,
        time: @time,
        lat: @my_lat,
        lng: @my_lng,
        alt: @my_alt,
        cog: @my_cog,
        sog: @my_sog,
        gps_fix_qual: @gps_fix_qual,
        gps_sats: @gps_sats,
        gps_fix_type: @gps_fix_type,
        gps_pdop: @gps_pdop,
        gps_hdop: @gps_hdop,
        gps_vdop: @gps_vdop,
      },
      options: {
        type: 'STATION_UPDATE',
        persistent: false,
        mandatory: false,
        expiration: 60000,
      }
    )

#    handle_pflaa('0,29,-16,-14,2,DF0855,100,,0,-0.1,1')

    if @pending_updates.any?
#      log.debug "SENDING UPDATES #{@pending_updates}"

      @amqp.tell AM::AMQP::MsgPublish.new(
        destination: mycfg.exchange,
        payload: {
          station_id: mycfg.station_name,
          objects: @pending_update
        },
        options: {
          type: 'TRAFFIC_UPDATE',
          persistent: false,
          mandatory: false,
          expiration: 60000,
        }
      )
    end

    @pending_updates = {}
  end

  def handle_pflau(line)
    (rx, tx, gps_status) = nmea_parse(line)

    if @gps_status != gps_status
      @gps_status = gps_status

      @amqp.tell AM::AMQP::MsgPublish.new(
        destination: mycfg.exchange,
        payload: {
          msg_type: :status_update,
          msg: {
            gps_status: gps_status,
          },
        },
        options: {
          type: 'TRAFFIC_UPDATE',
          persistent: false,
          mandatory: false,
          expiration: 60000,
        }
      )
    end
  end

  def handle_pflaa(line)

#    log.debug "PFLAA: #{line}"

    (alarm_level, rel_north, rel_east, rel_vertical, id_type, id, track, turn_rate, gs, climb_rate, type) = nmea_parse(line)

    plane = nil

    id_type_s = case id_type.to_i
      when 1; 'icao'
      when 2; 'flarm'
      else; id_type.to_s
    end

    @pending_updates[id_type_s + ':' + id] = {
      ts: @time, # We have no better timestamp for now
      type: type.to_i,
      lat: @my_lat + rel_north.to_f / 111111,
      lng: @my_lng + rel_east.to_f / (111111 * Math.cos((@my_lat / 180) * Math::PI)),
      alt: @my_alt + rel_vertical.to_f,
      cog: track.to_i,
      sog: gs.to_f,
      tr: turn_rate.to_i,
      cr: climb_rate.to_f,
    }
  end

  def nmea_parse(line)
    line.split(',')
  end
end

end
