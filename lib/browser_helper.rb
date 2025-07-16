# lib/browser_helper.rb

module BrowserHelper
  def self.get_browser_command(app_url, vagrant_host_browser = nil)
    browser_command = ""

    if Vagrant::Util::Platform.darwin? # macOS
      browser_command = "open #{app_url}"
    elsif Vagrant::Util::Platform.windows? # Windows
      if vagrant_host_browser && !vagrant_host_browser.empty?
        browser_command = "start \"\" \"#{vagrant_host_browser}\" \"#{app_url}\""
      else
        browser_command = "start \"\" \"#{app_url}\""
      end
    elsif Vagrant::Util::Platform.linux? # Linux
      if vagrant_host_browser && !vagrant_host_browser.empty?
        browser_command = "#{vagrant_host_browser} #{app_url}"
      else
        browser_command = "xdg-open #{app_url}"
      end
    else
      # Fallback or warning for unknown OS
      puts "Warning: Unknown host OS, cannot automatically open browser."
    end
    return browser_command
  end
end