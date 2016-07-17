class Notify

  def self.email(text)
    mg = Mailgun::Client.new SyncConfig['mailgun']['apikey']
    mg.send_message SyncConfig['mailgun']['domain'], {
      from: SyncConfig['email_from'],
      to: SyncConfig['email_to'],
      subject: "New photos uploaded",
      text: text
    }
  end

end