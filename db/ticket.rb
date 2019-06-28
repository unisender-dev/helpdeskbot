class Ticket < ActiveRecord::Base
  belongs_to :user
  belongs_to :admin, optional: true
  has_many :messages

  def show_ticket(chat_id)
    text = "Ticket /#{self.id}\nCreated at #{self.created_at.strftime('%F %T UTC')}\nCreated by #{self.user.get_name}"
    text += "\nAssigned to #{self.admin.get_name}" if self.admin
    text += "\nTicket is CLOSED" if self.status == 11 || self.status == 21
    text += "\nTicket is CANCELED" if self.status == 12
    text += "\nTicket is REJECTED" if self.status == 22
    $replies.push(chat_id: chat_id, text: text, reply_markup: BotHelper.remove_keyboard)
    text = ""
    self.messages.order(messaged_at: :asc).each do |message|
      if message.photo || message.file
        if text.length > 0
          $replies.push(chat_id: chat_id, text: text)
          text = ""
        end
        data = {chat_id: chat_id}
        if message.photo
          data[:photo] = message.photo
          data[:caption] = message.messaged_at.strftime('%F %T UTC')
          data[:caption] += " [U:#{message.user.get_name}]" if message.user
          data[:caption] += " [A:#{message.admin.get_name}]" if message.admin
          data[:caption] += "\n#{message.message}" if message.message
        elsif message.file
          data[:document] = message.file
          data[:caption] = message.messaged_at.strftime('%F %T UTC')
          data[:caption] += " [U:#{message.user.get_name}]" if message.user
          data[:caption] += " [A:#{message.admin.get_name}]" if message.admin
          data[:caption] += "\n#{message.message}" if message.message
        end
        $replies.push(data)
      else
        newtext = ""
        newtext += message.messaged_at.strftime('%F %T UTC')
        newtext += " [U:#{message.user.get_name}]" if message.user
        newtext += " [A:#{message.admin.get_name}]" if message.admin
        newtext += "\n#{message.message}" if message.message
        if (text + "\n" + newtext).length >= 4096
          $replies.push(chat_id: chat_id, text: text)
          text = newtext
        else
          text += "\n" + newtext
        end
      end
    end
    $replies.push(chat_id: chat_id, text: text) if text.length > 0
  end

  def notify_new_ticket
    Admin.where.not(chat_id: nil).each do |a|
      $replies.push(chat_id: a.chat_id, text: "Ticket /#{self.id} created.")
    end
  end

  def notify_admin_assigment(name)
    if self.user.chat_id
      if self.user.ticket_id == self.id
        $replies.push(chat_id: self.user.chat_id, text: "Assigned to #{name}")
      else
        $replies.push(chat_id: self.user.chat_id, text: "Ticket /#{self.id} assigned to #{name}")
      end
    end
  end

  def notify_message_from_user(message)
    Admin.where.not(chat_id: nil).each do |a|
      if a.ticket_id == self.id
        data = {
            chat_id: a.chat_id
        }
        if message.photo
          data[:photo] = message.photo
          data[:caption] = message.messaged_at.strftime('%F %T UTC')
          data[:caption] += " [U:#{message.user.get_name}]" if message.user
          data[:caption] += " [A:#{message.admin.get_name}]" if message.admin
          data[:caption] += "\n#{message.message}" if message.message
        elsif message.file
          data[:document] = message.file
          data[:caption] = message.messaged_at.strftime('%F %T UTC')
          data[:caption] += " [U:#{message.user.get_name}]" if message.user
          data[:caption] += " [A:#{message.admin.get_name}]" if message.admin
          data[:caption] += "\n#{message.message}" if message.message
        else
          data[:text] = message.messaged_at.strftime('%F %T UTC')
          data[:text] += " [U:#{message.user.get_name}]" if message.user
          data[:text] += " [A:#{message.admin.get_name}]" if message.admin
          data[:text] += "\n#{message.message}" if message.message
        end
        $replies.push(data)
      else
        $replies.push(chat_id: a.chat_id, text: "Ticket /#{self.id} replied by user")
      end
    end
  end

  def notify_message_from_admin(message)
    if u = User.find_by(id: self.user_id)
      if u.chat_id
        if u.ticket_id == self.id
          data = {
              chat_id: u.chat_id
          }
          if message.photo
            data[:photo] = message.photo
            data[:caption] = message.messaged_at.strftime('%F %T UTC')
            data[:caption] += " [#{message.user.get_name}]" if message.user
            data[:caption] += " [#{message.admin.get_name}]" if message.admin
            data[:caption] += "\n#{message.message}" if message.message
          elsif message.file
            data[:document] = message.file
            data[:caption] = message.messaged_at.strftime('%F %T UTC')
            data[:caption] += " [#{message.user.get_name}]" if message.user
            data[:caption] += " [#{message.admin.get_name}]" if message.admin
            data[:caption] += "\n#{message.message}" if message.message
          else
            data[:text] = message.messaged_at.strftime('%F %T UTC')
            data[:text] += " [#{message.user.get_name}]" if message.user
            data[:text] += " [#{message.admin.get_name}]" if message.admin
            data[:text] += "\n#{message.message}" if message.message          end
          $replies.push(data)
        else
          $replies.push(chat_id: u.chat_id, text: "Ticket /#{self.id} replied by admin.")
        end
      end
    end
  end

  def close_ticket
    if self.status == 11
      # closed by user
      if self.admin_id
        if a = Admin.find_by(id: self.admin_id)
          if a.chat_id && a.ticket_id != self.id
            $replies.push(chat_id: a.chat_id, text: "Ticket /#{self.id} closed by user")
          end
        end
      end
      Admin.where(ticket_id: nil).each do |a|
        if a.chat_id && a.ticket_id != self.id
          $replies.push(chat_id: a.chat_id, text: "Ticket /#{self.id} closed by user")
        end
      end
      Admin.where(ticket_id: self.id).each do |a|
        if a.chat_id
          $replies.push(chat_id: a.chat_id, text: "Ticket closed by user")
        end
      end
    elsif self.status == 21
      # closed by admin
      if self.user.chat_id
        if self.user.ticket_id == self.id
          $replies.push(chat_id: self.user.chat_id, text: "Ticket closed. Rate it: /rate#{self.id}")
        else
          $replies.push(chat_id: self.user.chat_id, text: "Ticket /#{self.id} was closed. Rate it: /rate#{self.id}")
        end
      end
    end
  end

  def cancel_ticket
    if self.status == 12
      # canceled by user
      if self.admin_id
        if a = Admin.find_by(id: self.admin_id)
          if a.chat_id && a.ticket_id != self.id
            $replies.push(chat_id: a.chat_id, text: "Ticket /#{self.id} canceled by user")
          end
        end
      end
      Admin.where(ticket_id: nil).each do |a|
        if a.chat_id && a.ticket_id != self.id
          $replies.push(chat_id: a.chat_id, text: "Ticket /#{self.id} canceled by user")
        end
      end
      Admin.where(ticket_id: self.id).each do |a|
        if a.chat_id
          $replies.push(chat_id: a.chat_id, text: "Ticket canceled by user")
        end
      end
    elsif self.status == 22
      # canceled by admin
      if self.user.chat_id
        if self.user.ticket_id == self.id
          $replies.push(chat_id: self.user.chat_id, text: "Ticket rejected.")
        else
          $replies.push(chat_id: self.user.chat_id, text: "Ticket /#{self.id} was rejected.")
        end
      end
    end
  end
end
