require 'tomte'
require 'tomte/agent/async'

module Tomte
module Agent

class GlideradarSniff < Tomte::Agent::Async

  DEFAULT_OPTIONS = {
  }

  read_configuration 'glideradar.yml', :path => :application, :queue => :before
  read_configuration 'glideradar.yml', :path => :system

  caption 'Glideradar'
  help_text ''

  base_configuration :glideradar, DEFAULT_OPTIONS
  needs_privilege_management

  has_worker :glideradar_sniff, :class => 'Glideradar::SniffWorker', :file => 'glideradar/sniff_worker.rb'

  def init(options = {})
  end
end

end
end
