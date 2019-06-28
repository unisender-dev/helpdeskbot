class User < ActiveRecord::Base
  has_many :tickets

  def self.check_started(m)
    # find user
    u = nil
    u = self.find_by(username: m.from.username) if u.nil? && m.from && m.from.username
    u = self.find_by(chat_id: m.from.id) if u.nil? && m.from && m.from.id
    u = self.find_by(chat_id: m.chat.id) if u.nil? && m.chat && m.chat.id

    # check if user logged in
    if !u.nil? && !u.chat_id.nil?
      # update user info
      begin
        u.chat_id = m.chat.id if !m.chat && m.chat.id
      rescue
      end
      u.username = m.from.username if m.from && m.from.username
      u.firstname = m.from.first_name if m.from && m.from.first_name
      u.lastname = m.from.last_name if m.from && m.from.last_name
      if u.changed?
        u.ticket_id = nil
        u.save
        $replies.push(chat_id: u.chat_id, text: "Hello, #{u.get_name}!", reply_markup: BotHelper.user_global_keyboard) if u.chat_id
      end
      return u
    end

    # user not logged in
    return nil unless m.chat || m.chat.id
    u = User.new if u.nil?
    u.username = m.from.username if m.from && m.from.username
    u.firstname = m.from.first_name if m.from && m.from.first_name
    u.lastname = m.from.last_name if m.from && m.from.last_name
    u.ticket_id = nil
    u.save if u.changed?
    chat_id = nil
    chat_id = m.chat.id if m.chat && m.chat.id
    if m.text == '/start'
      if chat_id
        u.start(chat_id)
      end
    else
      $replies.push(chat_id: chat_id, text: "Welcome!\nPlease send /start command to begin.", reply_markup: BotHelper.remove_keyboard) if chat_id
    end
    return nil
  end

  def get_name
    name = ""
    name += "#{name.length != 0 ? ' ' : ''}" + "@#{self.username}" if self.username
    if self.firstname && self.lastname
      name = self.firstname if self.firstname
      name += "#{name.length != 0 ? ' ' : ''}" + "#{self.lastname}" if self.lastname
    end
    return name
  end

  def start(chat_id)
    self.ticket_id = nil
    self.chat_id = chat_id
    self.save if self.changed?
    $replies.push(chat_id: self.chat_id, text: "Hello, #{self.get_name}!\nSelect action or write your request please", reply_markup: BotHelper.user_global_keyboard) if self.chat_id
  end

  def stop
    $replies.push(chat_id: self.chat_id, text: "Bye, #{self.get_name}!", reply_markup: BotHelper.remove_keyboard)
    self.ticket_id = nil
    self.chat_id = nil
    self.save
  end

  def show_tickets
    $replies.push(chat_id: chat_id, text: "Loading tickets...", reply_markup: BotHelper.remove_keyboard) if chat_id
    kb = []
    Ticket.where(status: [0], user_id: self.id).order(created_at: :asc).each do |t|
      kb << Telegram::Bot::Types::InlineKeyboardButton.new(text: "#{t.id} #{t.created_at.strftime('%F %T UTC')}", callback_data: "/#{t.id}")
    end
    kb << Telegram::Bot::Types::InlineKeyboardButton.new(text: "Main Menu", callback_data: "main")
    keyboard = Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: kb)
    $replies.push(chat_id: self.chat_id, text: "You tickets:", reply_markup: keyboard)
  end

  def load_ticket(id)
    if t = Ticket.find_by(id: id)
      self.ticket_id = t.id
      self.save if self.changed?
      t.show_ticket(self.chat_id)
      $replies.push(chat_id: self.chat_id, text: 'Please select action or write reply', reply_markup: BotHelper.user_ticket_keyboard)
    else
      self.start(self.chat_id)
    end
  end

  def rate_ticket(id)
    if Ticket.find_by(id: id, user_id: self.id)
      kb = [
          Telegram::Bot::Types::InlineKeyboardButton.new(text: "1 - TERRIBLE!", callback_data: "/rate#{id}-1"),
          Telegram::Bot::Types::InlineKeyboardButton.new(text: "2 - Bad", callback_data: "/rate#{id}-2"),
          Telegram::Bot::Types::InlineKeyboardButton.new(text: "3 - ...", callback_data: "/rate#{id}-3"),
          Telegram::Bot::Types::InlineKeyboardButton.new(text: "4 - Good", callback_data: "/rate#{id}-4"),
          Telegram::Bot::Types::InlineKeyboardButton.new(text: "5 - Excellent!", callback_data: "/rate#{id}-5")
      ]
      keyboard = Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: kb)
      $replies.push(chat_id: self.chat_id, text: "Please rate ticket /#{id}", reply_markup: keyboard)
    end
  end

  def rate_ticket_save(id, rate)
    if t = Ticket.find_by(id: id)
      t.rate = rate
      t.save if t.changed?
    end
  end

  def process_message(m)
    case m
    when Telegram::Bot::Types::CallbackQuery
      self.process_message_callback(m)
    when Telegram::Bot::Types::Message
      self.process_message_text(m)
    end
  end

  def process_message_callback(m)
    case m.data
    when 'main'
      self.start(self.chat_id)
    when /^\/(\d+)$/
      self.load_ticket($1)
    when /^\/rate(\d+)-(\d+)$/
      self.rate_ticket_save($1, $2)
    when /^\/rate(\d+)$/
      self.rate_ticket($1)
    end
  end

  def process_message_text(m)
    if t = Ticket.find_by(id: self.ticket_id)
      case m.text
      when 'Close Ticket'
        t.status = 11
        t.closed_at = Time.now
        t.save if t.changed?
        t.close_ticket
        self.start(self.chat_id)
      when 'Cancel Ticket'
        t.status = 12
        t.closed_at = Time.now
        t.save if t.changed?
        t.cancel_ticket
        self.start(self.chat_id)
      when 'Main Menu'
        self.start(self.chat_id)
      when '/stop'
        self.stop
      when '/start'
        self.start(self.chat_id)
      when /^\/(\d+)$/
        self.load_ticket($1)
      when /^\/rate(\d+)$/
        self.rate_ticket($1)
      when /^\//
        $replies.push(chat_id: self.chat_id, text: 'Unknown command.', reply_markup: BotHelper.user_ticket_keyboard)
      else
        Message.from_user(self, t, m)
      end
    else
      case m.text
      when 'My Tickets'
        self.show_tickets
      when 'New Ticket'
        $replies.push(chat_id: self.chat_id, text: "Please send me some text, photo or document.")
      when '/stop', 'Exit'
        self.stop
      when '/start'
        self.start(self.chat_id)
      when /^\/(\d+)$/
        self.load_ticket($1)
      when /^\/rate(\d+)$/
        self.rate_ticket($1)
      when /^\//
        $replies.push(chat_id: self.chat_id, text: 'Unknown command.', reply_markup: BotHelper.user_global_keyboard)
      else
        t = Ticket.create!(user_id: self.id, created_at: Time.now)
        t.notify_new_ticket
        self.ticket_id = t.id
        self.save if self.changed?
        Message.from_user(self, t, m)
        $replies.push(chat_id: self.chat_id, text: "Ticket /#{t.id} created.", reply_markup: BotHelper.user_ticket_keyboard)
      end
    end
  end

end
