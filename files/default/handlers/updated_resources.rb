#
# Copyright:: 2011, Joshua Timberman <chefcode@housepub.org>
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require 'chef/handler'

module SimpleReport
  class UpdatedResources < Chef::Handler

    def report
      ignored_resources = [ "/var/cache/chef/handlers", "apt_get_update" ]

      report_resources = Hash.new

      header

      status = run_status.success? ? "success" : "failure"

      run_status.updated_resources.each do |r|
        if !ignored_resources.include?(r.name)
          report_resources[r.name] = r.class.to_s.gsub("Chef::Resource::", "")
          Chef::Log.info "#{report_resources[r.name]} #{r.name} #{r.action}"
        end
      end

      summary = { :status            => status,
                  :elapsed_time      => run_status.elapsed_time,
                  :start_time        => run_status.start_time,
                  :end_time          => run_status.end_time,
                  :updated_resources => report_resources,
                  :exception         => ( run_status.success? ? "none" : run_status.formatted_exception ) }

      log = Array.new
      log.push(summary)
      2.times do
        log.push(node['log'].shift) unless node['log'].nil?
      end

      node.set['log'] = log
      node.save
    end

    def header
      Chef::Log.info ""
      Chef::Log.info "Resources updated this run"
      Chef::Log.info "=========================="
      Chef::Log.info ""
    end

  end
end
