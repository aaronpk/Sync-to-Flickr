class Notify

  def self.email(text, html=nil)
    mg = Mailgun::Client.new SyncConfig['mailgun']['apikey']
    obj = Mailgun::MessageBuilder.new
    obj.from SyncConfig['email_from']
    obj.add_recipient :to, SyncConfig['email_to']
    obj.subject "New photos uploaded"
    obj.body_text text
    obj.body_html(html) if html
    mg.send_message SyncConfig['mailgun']['domain'], obj
  end

  def self.irc(text)
    HTTParty.post(SyncConfig['irc']['url'],
      :body => {
        :channel => SyncConfig['irc']['channel'],
        :content => text
      },
      :headers => {
        'Authorization' => "Bearer #{SyncConfig['irc']['token']}"
      })
  end

end
