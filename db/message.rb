class Message < ActiveRecord::Base
  belongs_to :ticket
  belongs_to :user, optional: true
  belongs_to :admin, optional: true

  def self.from_user(u, t, m)
    message = self.new(ticket_id: t.id, user_id: u.id, messaged_at: Time.now)
    if m.text
      message.message = m.text
    end
    if m.photo.length > 0
      message.photo = m.photo.last.file_id
      message.message = m.caption if m.caption
    end
    if m.document
      message.file = m.document.file_id
      message.file_name = m.document.file_name
      message.message = m.caption if m.caption
    end
    message.save
    t.notify_message_from_user(message)
  end

  def self.from_admin(a, t, m)
    message = self.new(ticket_id: t.id, admin_id: a.id, messaged_at: Time.now)
    if m.text
      message.message = m.text
    end
    if m.photo.length > 0
      message.photo = m.photo.last.file_id
      message.message = m.caption if m.caption
    end
    if m.document
      message.file = m.document.file_id
      message.file_name = m.document.file_name
      message.message = m.caption if m.caption
    end
    message.save
    t.notify_message_from_admin(message)
  end
end
