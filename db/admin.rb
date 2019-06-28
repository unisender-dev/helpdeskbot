class Admin < ActiveRecord::Base
  has_many :tickets

  def check_started(message)
    begin
      self.chat_id = message.chat.id
    rescue
      return false unless self.chat_id
    end
    if self.changed?
      if message.text == '/start'
        self.save
        $replies.push(chat_id: self.chat_id, text: "Hello, #{self.get_name}!\nPlease select available action", reply_markup: BotHelper.admin_global_keyboard)
        return false
      else
        $replies.push(chat_id: self.chat_id, text: 'Please send /start command to begin', reply_markup: BotHelper.remove_keyboard)
        self.chat_id = nil
        return false
      end
    end
    return true
  end

  def get_name
    return "@#{self.username}" unless self.name
    return "#{self.name}"
  end

  def action_main
    self.ticket_id = nil
    self.save if self.changed?
    $replies.push(chat_id: self.chat_id, text: 'Please select available action', reply_markup: BotHelper.admin_global_keyboard)
  end

  def action_stop
    $replies.push(chat_id: self.chat_id, text: "Bye, #{self.get_name}!", reply_markup: BotHelper.remove_keyboard)
    self.ticket_id = nil
    self.chat_id = nil
    self.save if self.changed?
  end

  def action_tickets(where = {status: 0})
    $replies.push(chat_id: self.chat_id, text: "Loading tickets...", reply_markup: BotHelper.remove_keyboard)
    kb = []
    Ticket.where(where).order(created_at: :asc).each do |t|
      kb << Telegram::Bot::Types::InlineKeyboardButton.new(text: "#{t.admin_id.nil? ? '!! ' : ''}#{t.id} from #{t.user.get_name}", callback_data: "/#{t.id}")
    end
    if kb.empty?
      self.action_main
    else
      kb << Telegram::Bot::Types::InlineKeyboardButton.new(text: "Main Menu", callback_data: "main")
      keyboard = Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: kb)
      $replies.push(chat_id: self.chat_id, text: "You tickets:", reply_markup: keyboard)
    end
  end

  def action_ticket(id)
    if t = Ticket.find_by(id: id)
      self.ticket_id = t.id
      self.save if self.changed?
      t.show_ticket(self.chat_id)
      $replies.push(chat_id: self.chat_id, text: 'Please select action or write reply', reply_markup: BotHelper.admin_ticket_keyboard)
    else
      self.action_main
    end
  end

  def action_assign(t)
    if !t.admin_id.nil? && t.admin_id != self.id
      if oa = Admin.find_by(id: t.admin_id)
        if oa.chat_id
          $replies.push(chat_id: oa.chat_id, text: "#{self.get_name} has taken your ticket /#{t.id}")
        end
      end
    end
    t.notify_admin_assigment(self.get_name)
    $replies.push(chat_id: self.chat_id, text: "Ticket assigned to you")
    t.admin_id = self.id
    t.save if t.changed?
  end

  def action_release(t)
    t.admin_id = nil
    t.save if t.changed?
    $replies.push(chat_id: self.chat_id, text: "Ticket released")
  end

  def action_close(t)
    t.status = 21
    t.closed_at = Time.now
    t.save if t.changed?
    t.close_ticket
    action_main
  end

  def action_reject(t)
    t.status = 22
    t.closed_at = Time.now
    t.save if t.changed?
    t.cancel_ticket
    action_main
  end

  def process_message(m)
    case m
    when Telegram::Bot::Types::CallbackQuery
      self.process_message_callback(m)
    when Telegram::Bot::Types::Message
      if m.forward_from.nil?
        self.process_message_text(m)
      else
        self.process_message_forward(m)
      end
    end
  end

  def process_message_callback(m)
    case m.data
    when 'main'
      self.action_main
    when /^\/(\d+)$/
      self.action_ticket($1)
    end
  end

  def process_message_text(m)
    if t = Ticket.find_by(id: self.ticket_id)
      case m.text
      when 'Assign to me'
        self.action_assign(t)
      when 'Release ticket'
        self.action_release(t)
      when 'Close'
        self.action_close(t)
      when 'Reject'
        self.action_reject(t)
      when 'Main Menu', '/start'
        self.action_main
      when '/stop'
        self.action_stop
      when /^\/(\d+)$/
        self.action_ticket($1)
      when /^\//
        $replies.push(chat_id: self.chat_id, text: 'Unsupported command.')
      else
        Message.from_admin(self, t, m)
      end
    else
      case m.text
      when 'Unassigned'
        self.action_tickets(status: 0, admin_id: nil)
      when 'Assigned to me'
        self.action_tickets(status: 0, admin_id: self.id)
      when 'All Tickets'
        self.action_tickets(status: 0)
      when '/start'
        self.action_main
      when 'Exit', '/stop'
        self.action_stop
      when /^\/(\d+)$/
        self.action_ticket($1)
      else
        $replies.push(chat_id: self.chat_id, text: 'Unsupported command.')
      end
    end
  end

  def process_message_forward(m)
    u = User.find_by(chat_id: m.forward_from.id)
    u = User.find_by(username: m.forward_from.username) if u.nil?
    u = User.create!(username: m.forward_from.username) if u.nil? && m.forward_from.username
    if u
      t = Ticket.create!(user_id: u.id, created_at: Time.now)
      t.notify_new_ticket
      Message.from_user(u, t, m)
    end
  end
end
