#!/usr/bin/env ruby

begin ; require 'rubygems' ; rescue LoadError ; end

require 'net/http'
require 'uri'
require 'xmlsimple'
require 'cgi'

NEXT_TWIT = 'next_twit.txt'
USER = "[TWITTER_USER]"
PW = "[TWITTER_PASSWORD]"

CITIES = [
{:name => /([nN]ew [yY]ork( [cC]ity)?)|( [nN][Yy][cC]?( |$))/, :msg => ["Look up hotels on a map of New York www.seeyourhotel.com/city/New_York",
                                                                   "To book a hotel in the perfect place in New York check www.seeyourhotel.com/city/New_York"]},
{:name => /([lL]as)? [vV]egas/, :msg => ["Check www.seeyourhotel.com/city/Las_Vegas to find hotels in Las Vegas"]},
{:name => /[Ss]an [Ff]rancisco/, :msg => ["For that San Francisco trip you're planning, head to www.seeyourhotel.com/city/San_Francisco"]},
{:name => /[Bb]oston/, :msg => ["If you're looking for accommodations in Boston, check out www.seeyourhotel.com/city/Boston"]},
{:name => /[Rr]ome/, :msg => ["For that Rome trip you're planning, head to www.seeyourhotel.com/city/Rome"]},
{:name => /[Bb]erlin/, :msg => ["You can check Berlin hotels on a map at www.seeyourhotel.com/city/Berlin"]},
{:name => /[Pp]aris/, :msg => ["For that upcoming Paris trip, why not check out www.seeyourhotel.com/city/Paris"]},
{:name => /[Ll]ondon/, :msg => ["For that upcoming London trip, why not check out www.seeyourhotel.com/city/London"]},
{:name => /([Ll]os [Aa]ngeles)|( LA )/, :msg => ["For that Los Angeles trip you're planning, head to www.seeyourhotel.com/city/Los_Angeles"]},

{:name => /[Cc]hicago/, :msg => ["For that Chicago trip you're planning, head to www.seeyourhotel.com/city/Chicago"]},
{:name => /[Ss]an [Dd]iego/, :msg => ["Check www.seeyourhotel.com/city/San_Diego to find hotels in San Diego"]},
{:name => /[Ss]eattle/, :msg => ["For that Seattle trip you're planning, head to www.seeyourhotel.com/city/Seattle"]},
{:name => /[Oo]rlando/, :msg => ["Check www.seeyourhotel.com/city/Orlando to find hotels in Orlando"]},
{:name => /[Aa]tlanta/, :msg => ["For that Atlanta trip you're planning, head to www.seeyourhotel.com/city/Atlanta"]},
{:name => /[Dd]allas/, :msg => ["Check www.seeyourhotel.com/city/Dallas to find hotels in Dallas"]},
{:name => /[Nn]ew [Oo]leans/, :msg => ["For that New Orleans trip you're planning, head to www.seeyourhotel.com/city/New_orleans"]},
{:name => /[Aa]msterdam/, :msg => ["Check www.seeyourhotel.com/city/Amsterdam to find hotels in Amsterdam"]},
{:name => /[Pp]ortland/, :msg => ["For that Portland trip you're planning, head to www.seeyourhotel.com/city/53535"]},
{:name => /[Bb]arcelona/, :msg => ["Check www.seeyourhotel.com/city/Barcelona to find hotels in Barcelona"]},
{:name => /[Aa]ustin/, :msg => ["For that Austin trip you're planning, head to www.seeyourhotel.com/city/Austin-Texas-United_States"]},
{:name => /[Tt]okyo/, :msg => ["Check www.seeyourhotel.com/city/Tokyo to find hotels in Tokyo"]},
{:name => /[Tt]oronto/, :msg => ["For that Toronto trip you're planning, head to www.seeyourhotel.com/city/Toronto"]},
{:name => /[Hh]ong [Kk]ong/, :msg => ["Check www.seeyourhotel.com/city/Hong_Kong to find hotels in Hong Kong"]},
{:name => /[Ss]idney/, :msg => ["For that Sidney trip you're planning, head to www.seeyourhotel.com/city/Sidney"]},
{:name => /[Mm]ontreal/, :msg => ["Check www.seeyourhotel.com/city/Montreal to find hotels in Montreal"]},
{:name => /[Nn]ashville/, :msg => ["For that Nashville trip you're planning, head to www.seeyourhotel.com/city/Nashville"]},
{:name => /[Pp]illy/, :msg => ["Check www.seeyourhotel.com/city/Philadelphia to find hotels in Philly"]},

{:name => /Some impossible match/, :msg => ["What?"]}
]


def search (query, since)
  url = URI.parse('http://search.twitter.com/')
  result = Net::HTTP.start(url.host, url.port) do |http|
    http.get('/search.atom?q=' + query + '&since_id=' + since)
  end
  return XmlSimple.xml_in(result.body)
end

def extract_original_twit(list, since)
  original_twits = []
  if list['entry'] != nil
    list['entry'].each do |entry|
      text = entry['title'][0]
      if text.index("@") != 0 && !text.include?("http:") && text.index("RT") != 0 && text.downcase.index("spam") != 0
        author = entry['author'][0]['name'][0].split(" ")[0]
        original_twits << {
          :author => author, 
          :text => entry['title'][0],
          :id => entry['id'][0].split(':').last
        } if check_author(author)
      end
    end 
    write_next_twit list['entry'][0]['id'][0].split(':').last
  else
    write_next_twit since
  end
  return original_twits
end

def check_author(author)
  result = false
  url = URI.parse('http://twitter.com/')
  Net::HTTP.start(url.host, url.port) do |http|
    req = Net::HTTP::Get.new('/friendships/exists.xml?user_a=' + USER + '&user_b=' + author)
    req.basic_auth USER, PW 
    res = http.request(req)
    resxml = XmlSimple.xml_in(res.body) 
    if resxml == 'true'
      req = Net::HTTP::Get.new('/friendships/exists.xml?user_b=' + USER + '&user_a=' + author)
      req.basic_auth USER, PW 
      res = http.request(req)
      resxml = XmlSimple.xml_in(res.body) 
      if resxml == 'true'
        #result = true
	result = false #we should wait a period before saying anything else
      end
    else
      result = true
    end
  end
  return result
end

def write_next_twit(id)
  if !File.exist? NEXT_TWIT
    File.open(NEXT_TWIT, 'w') {|f| f.puts(id) }
  else
    File.open(NEXT_TWIT, 'a+') {|f| f.puts(id) }
  end
end

def read_next_twit()
  result = ['0', '0']
  if File.exist? NEXT_TWIT
    result = File.readlines(NEXT_TWIT).map do |l|
      l.rstrip 
    end
    File.delete NEXT_TWIT
  end
  return result
end

def get_twits()
  twit = read_next_twit
  hotels = search('+Hotel+OR+Hotels+suggestion+OR+tip+OR+recommendation+%3F', twit[0]);
  planning = search('+trip+planning', twit[1]);
  original_twits = extract_original_twit(hotels, twit[0]);
  original_twits = original_twits + extract_original_twit(planning, twit[1]);
  return original_twits
end

def post_twit(twit)
  url = URI.parse('http://twitter.com/')
  Net::HTTP.start(url.host, url.port) do |http|
    req = Net::HTTP::Post.new('/statuses/update.xml')
    req.basic_auth USER, PW 
    req.set_form_data({'status'=>"@#{twit[:to]} #{twit[:msg]}", 'in_reply_to_status_id'=>twit[:reply_to]})
    http.request(req)
    req = Net::HTTP::Post.new('/friendships/create/' + twit[:to] + '.xml')
    req.basic_auth USER, PW 
    http.request(req)
  end
end

def post_result_twit(twits)
  twits.each do |twit|
    post_twit twit
  end
end

def match_cities(original_twit) 
  CITIES.each do |city|
    if original_twit.index(city[:name]) != nil
      return city[:msg][0]
    end
  end
  return nil
end

def match_regex(original_twits)
  result_twits = []
  original_twits.each do |original_twit|
    text = match_cities(original_twit[:text])
    if text != nil
      result_twits << {
        :msg => text,
        :to => original_twit[:author],
	:reply_to => original_twit[:id]
      }
      p "From #{original_twit[:author]} Twit: #{original_twit[:text]}"
      p " Answer: #{text}"
    else
      p "=== No reply for Twit: #{original_twit[:text]} From: #{original_twit[:author]}"
    end
  end
  return result_twits
end

def main()
  original_twits = get_twits
  answer_twits = match_regex(original_twits)
  post_result_twit answer_twits
end

main()
