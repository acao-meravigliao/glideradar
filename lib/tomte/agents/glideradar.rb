require 'tomte'
require 'tomte/agent/async'

module Tomte
module Agent

class Glideradar < Tomte::Agent::Async

  DEFAULT_OPTIONS = {
  }

  read_configuration 'glideradar.yml', :path => :application, :queue => :before
  read_configuration 'glideradar.yml', :path => :system

  caption 'Glideradar'
  help_text ''

  base_configuration :glideradar, DEFAULT_OPTIONS
  needs_privilege_management

  has_worker :glideradar, :class => 'Glideradar::Worker', :file => 'glideradar/worker.rb'

  def init(options = {})
    log.debug "= Glideradar initializing"
  end
end

end
end
