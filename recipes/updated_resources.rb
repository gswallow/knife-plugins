# Likewise, register the chef handler at compile time
# to catch compile-time exceptions, too.
h = chef_handler "SimpleReport::UpdatedResources" do
  source "#{node['chef_handler']['handler_path']}/updated_resources.rb"
  action :nothing
end
h.run_action("enable")
