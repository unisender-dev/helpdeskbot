module BotHelper
  class << self

    def remove_keyboard
      return Telegram::Bot::Types::ReplyKeyboardRemove.new(remove_keyboard: true)
    end

    def user_global_keyboard
      return Telegram::Bot::Types::ReplyKeyboardMarkup.new(keyboard: [['My Tickets', 'New Ticket', 'Exit']], one_time_keyboard: false, resize_keyboard: true)
    end

    def user_ticket_keyboard
      return Telegram::Bot::Types::ReplyKeyboardMarkup.new(keyboard: [['Cancel Ticket', 'Main Menu']], one_time_keyboard: false, resize_keyboard: true)
    end

    def admin_global_keyboard
      return Telegram::Bot::Types::ReplyKeyboardMarkup.new(keyboard: [['Unassigned', 'Assigned to me'], ['All Tickets', 'Exit']], one_time_keyboard: false, resize_keyboard: true)
    end

    def admin_ticket_keyboard
      return Telegram::Bot::Types::ReplyKeyboardMarkup.new(keyboard: [['Assign to me', 'Release ticket'], ['Close', 'Reject', 'Main Menu']], one_time_keyboard: false, resize_keyboard: true)
    end

  end
end
