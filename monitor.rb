require 'digest'
require 'twilio-ruby'

require_relative './credentials.rb'

class Monitor
  require 'open-uri'
  require 'fileutils'

  CACHE_DIR = '/tmp/web_monitor/'

  def initialize(url, name, email_recipients, sms_recipients)
    @url = url
    @name = name
    @email_recipients = email_recipients
		@sms_recipients = sms_recipients
  end

  def run
    begin
      open(@url, read_timeout: 30).read
      log "#{@url} is fine. "
      notify("back up") if prev_downs > 2
      commit_flutter("fine")
    rescue Exception => e
      log "#{@url} is down for #{prev_downs + 1} times in a row. "
      notify("down") if prev_downs == 2
      commit_flutter("down")
    end
  end

  private
    def prev_downs
      prevs = load_flutter
      curr = prevs.size - 1
      count = 0

      while curr >= 0 && prevs[curr] == "down"
        count += 1
        curr -= 1
      end

      count
    end

    def flutter_path
      FileUtils.mkdir_p CACHE_DIR
      File.join(CACHE_DIR, "#{@name}.flutter")
    end

    def log(msg)
      puts "#{Time.now}: #{msg}"
    end

    def notify(adj)
			message = "Apps Monitor: #{@url} is #{adj}. "
      @email_recipients.each do |r|
        `echo '' | mail -s "#{message}" #{r}`
      end

			@twilio_client = Twilio::REST::Client.new(TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN)

			@sms_recipients.each do |r|
				message = @twilio_client.account.messages.create(
					body: message,
					from: TWILIO_FROM_NUMBER, 
					to: r
				)
			end
    end

    def load_flutter
      return [] unless File.exists?(flutter_path)

      return File.read(flutter_path).lines.map do |l|
        l.split[1].strip
      end
    end

    def commit_flutter(result)
      timestamp = Time.now.to_i
      open(flutter_path, 'a') do |f|
        f.puts "#{timestamp} #{result}"
      end
    end
end

Monitor.new(
	ARGV[0], 
	Digest::SHA256.new.update(ARGV[0]).hexdigest, 
	EMAIL_RECIPIENTS,
	SMS_RECIPIENTS
).run

