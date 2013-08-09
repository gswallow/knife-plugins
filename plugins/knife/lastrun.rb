require 'date'
require 'time'
require 'json'
require 'chef/knife'
require 'chef/knife/core/node_presenter'

class Chef
  class Knife
    class Lastrun < Knife

      deps do
        require 'chef/search/query'
        require 'chef/knife/search'
        require 'chef/node'
      end

      banner "knife lastrun [QUERY] [OPTIONS]"

      option :time,
        :short => "-t",
        :long => "--time",
        :description => "Show failed nodes only"

      option :failed,
        :short => "-f",
        :long => "--failed",
        :description => "Show failed nodes only"

      option :log,
        :short => "-l",
        :long => "--log",
        :description => "Show the most recent log entry"

      def header(name, lasttime, status, runtime)
        msg = String.new
        msg << ui.color(name.ljust(40, ' '), :bold)
        msg << ui.color(lasttime.ljust(20, ' '), :bold)
        msg << ui.color(status.ljust(12, ' '), :bold)
        msg << ui.color(runtime.rjust(10, ' '), :bold)
        msg
      end

      def log_separator(name)
        msg = String.new
        msg << ui.color(name.ljust(40, ' '), :bold)
        msg
      end

      def format(name, lasttime, status, runtime)
        case status.downcase
        when "success"
          color = :green
        when "failure"
          color = :red
        else
          color = :white
        end

        msg = String.new
        msg << ui.color(name.ljust(40, ' '), :cyan)
        msg << lasttime.ljust(20, ' ')
        msg << ui.color(status.capitalize.ljust(12, ' '), color)
        msg << runtime.to_s.rjust(10, ' ')
        msg
      end

      def pp_json(log)
        pretty = JSON.pretty_generate(log)
        pretty
      end

      def run
        query = @name_args[0].nil? ? "*:*" : @name_args[0]
        nodes = Array.new

        begin
          q = Chef::Search::Query.new
          q.search(:node, query) do |n|
            unless n.automatic_attrs.empty? # filter out bad nodes (clients?)
              begin
                if n.attribute?('cloud')
                  name = n.cloud['public_hostname'].nil? ? n.fqdn : n.cloud['public_hostname']
                else
                  name = n.fqdn
                end
              rescue 
                 ui.error "This should never happen: #{n.name} has no FQDN attribute."
              end

              if n.attribute?('log')
                last = n['log'].first
                status = last['status'].to_s
                elapsed_time = last['elapsed_time'].to_i
                last_time = Time.parse(last['start_time']).strftime("%Y-%m-%d %H:%M:%S")
              else
                status = "No status"
                last_time = "Unknown"
                elapsed_time = 0
              end

              unless config[:failed] and status.downcase != "failed"
                nodes << { :name => n.name, :last => last, :last_time => last_time, :status => status, :elapsed_time => elapsed_time }
              end
            end
          end
        rescue Net::HTTPServerException => e
          msg = Chef::JSONCompat.from_json(e.response_body)["error"].first
          ui.error("knife search failed: #{msg}")
          exit 1
        end

        # Header
        ui.msg "#{nodes.count} items found"
        ui.msg("\n")
        output(header("Name", "Last time", "Status", "Elapsed time"))
        output(header("====", "=========", "======", "============"))

        # Default by name unless -t
        if config[:time]
          nodes.sort_by! { |n| n[:last_time] }.reverse
        else
          nodes.sort_by! { |n| n[:name] }
        end

        nodes.each do |n|
          output(format(n[:name], n[:last_time], n[:status], n[:elapsed_time]))
        end

        if config[:log]
          nodes.each do |n|
            output ""
            output(log_separator("========================================"))
            output(log_separator(n[:name]))
            output(log_separator("========================================"))
            output(pp_json n[:last]['updated_resources'])
            output ""
            output "Updated versions"
            output ""
            output(pp_json n[:last]['updated_versions'])
          end
        end
      end

    end
  end
end
