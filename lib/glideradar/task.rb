#
# Copyright (C) 2014-2014, Daniele Orlandi
#
# Author:: Daniele Orlandi <daniele@orlandi.com>
#
# License:: You can redistribute it and/or modify it under the terms of the LICENSE file.
#

require 'ygg/agent/task'


require 'objspace'

module Glideradar

class Task < Ygg::Agent::Task
  operation :dump_mem do
    help_caption ''
    help_text ''
  end
  def dump_mem
    {
     count: ObjectSpace.count_objects,
     size: ObjectSpace.count_objects_size,
     nodes: ObjectSpace.count_nodes,
     tdata: ObjectSpace.count_tdata_objects,
    }
  end

end

end
