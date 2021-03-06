--[[
    Copyright 2020 Matthew Hesketh <matthew@matthewhesketh.com>
    This code is licensed under the MIT. See LICENSE for details.
]]

local news = {}
local mattata = require('mattata')
local https = require('ssl.https')
local json = require('dkjson')
local redis = require('libs.redis')

function news:init()
    news.commands = mattata.commands(self.info.username)
    :command('news')
    :command('nsources')
    :command('setnews').table
    news.help = '/news <news source> - Sends the current top story from the given news source. Use /nsources to view a list of available sources. Use /setnews <news source> to set your preferred news source, and be able to use /news without giving any arguments.'
end

function news.send_sources(message, language)
    local input = mattata.input(message.text:lower())
    if not input then
        input = false
    else
        local success = pcall(function()
            return input:match(input)
        end)
        if not success then
            return mattata.send_reply(
                message,
                string.format(language['news']['1'], mattata.escape_html(input)),
                'html'
            )
        end
    end
    local sources = news.get_sources(input)
    if not sources then
        return mattata.send_reply(message, language['news']['2'])
    end
    sources = table.concat(sources, ', ')
    if input then
        sources = string.format(
            language['news']['3'],
            mattata.escape_html(input),
            sources
        )
    else
        sources = string.format(language['news']['4'], sources)
    end
    return mattata.send_message(message.chat.id, sources, 'html')
end

function news.set_news(message, language)
    local input = mattata.input(
        message.text:lower()
    )
    if input
    then
        input = input:gsub('%-', ' ')
    end
    local preferred_source = redis:get(
        string.format(
            'user:%s:news',
            message.from.id
        )
    )
    if not preferred_source
    and not input
    then
        return mattata.send_reply(
            message,
            language['news']['5']
        )
    elseif not input
    then
        return mattata.send_reply(
            message,
            string.format(
                language['news']['6'],
                preferred_source
            )
        )
    elseif preferred_source == input
    then
        return mattata.send_reply(
            message,
            string.format(
                language['news']['7'],
                input
            )
        )
    end
    if not news.is_valid(input)
    then
        return mattata.send_reply(
            message,
            language['news']['8']
        )
    end
    redis:set(
        string.format(
            'user:%s:news',
            message.from.id
        ),
        input
    )
    return mattata.send_reply(
        message,
        string.format(
            language['news']['9'],
            input
        )
    )
end

function news.is_valid(source)
    local sources = news.get_sources()
    for k, v in pairs(sources)
    do
        if v == source
        then
            return true
        end
    end
    return false
end

function news.get_sources(input)
    local jstr, res = https.request('https://newsapi.org/v1/sources')
    if res ~= 200
    then
        return false
    end
    local jdat = json.decode(jstr)
    if jdat.status ~= 'ok'
    then
        return false
    end
    local sources = {}
    for k, v in pairs(jdat.sources)
    do
        v.id = v.id:gsub('%-', ' ')
        if input
        then
            if v.id:match(input)
            then
                table.insert(
                    sources,
                    v.id
                )
            end
        else
            table.insert(
                sources,
                v.id
            )
        end
    end
    table.sort(sources)
    return sources
end

function news:on_message(message, configuration, language)
    if message.text:match('^[/!#]nsources')
    then
        return news.send_sources(
            message,
            language
        )
    elseif message.text:match('^[/!#]setnews')
    then
        return news.set_news(
            message,
            language
        )
    end
    local input = mattata.input(
        message.text:lower()
    )
    if not input
    then
	    local user = string.format('user:%s:news', message.from.id)
		local preferred_source = redis:get(user)
        if preferred_source then
            input = preferred_source
        else
            return mattata.send_reply(message, news.help)
        end
    end
    input = input:gsub('-', ' ')
    if not news.is_valid(input) then
        return mattata.send_reply(message, language['news']['10'])
    end
    input = input:gsub('%s', '-')
    local jstr, res = https.request('https://newsapi.org/v1/articles?apiKey=' .. configuration.keys.news .. '&source=' .. input .. '&sortBy=top')
    if res ~= 200 then
        return mattata.send_reply(message, language['errors']['connection'])
    end
    local jdat = json.decode(jstr)
    if not jdat.articles[1]
    then
        return mattata.send_reply(
            message,
            language['errors']['results']
        )
    end
    jdat.articles[1].publishedAt = jdat.articles[1].publishedAt:gsub('T.-$', '')
    local output = string.format(
        '<b>%s</b> <code>[%s]</code>\n%s\n<a href="%s">%s</a>\n<i>Powered by NewsAPI.</i>',
        jdat.articles[1].title,
        mattata.escape_html(jdat.articles[1].publishedAt),
        jdat.articles[1].description,
        jdat.articles[1].url,
        language['news']['11']
    )
    return mattata.send_message(message.chat.id, output, 'html')
end

return news