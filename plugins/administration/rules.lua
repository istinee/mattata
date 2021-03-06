--[[
    Copyright 2020 Matthew Hesketh <matthew@matthewhesketh.com>
    This code is licensed under the MIT. See LICENSE for details.
]]

local rules = {}
local mattata = require('mattata')
local redis = require('libs.redis')

function rules:init()
    rules.commands = mattata.commands(self.info.username):command('rules').table
    rules.help = '/rules - View the group\'s rules.'
end

function rules:on_message(message, configuration, language)
    local input = mattata.input(message.text)
    local chat_id = message.chat.id
    if not input and message.chat.type ~= 'supergroup' then
        return false
    elseif input and input:match('^%-?%d+$') then
        chat_id = input
    end
    local output = mattata.get_value(chat_id, 'rules') or 'There are no rules set for this chat!'
    if mattata.get_setting(message.chat.id, 'send rules in group') or (input and message.chat.type == 'private') then
        return mattata.send_message(message.chat.id, output, 'markdown', true, false)
    end
    local success = mattata.send_message(message.from.id, output, 'markdown', true, false)
    output = success and 'I have sent you the rules via private chat!' or string.format('You need to speak to me in private chat before I can send you the rules! Just click [here](https://t.me/%s?start=rules_%s), press the "START" button, and try again!', self.info.username, message.chat.id)
    return mattata.send_reply(message, output, 'markdown', true)
end

return rules