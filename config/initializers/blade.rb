require 'propeller/blade'

blade = Propeller::Blade.new
blade.selection.addons.each do |addon|
  require addon.to_s
end

Propeller.configure :path => File.expand_path(File.dirname(File.dirname(File.dirname(__FILE__))))

Propeller::AddonManager.modules.each do |addon, m|
  m.init
end
