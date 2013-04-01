#!/usr/bin/env ruby

begin ; require 'rubygems' ; rescue LoadError ; end

require 'net/http'
require 'uri'
require 'xmlsimple'
require 'ruby-aws'
require 'cgi'

### Disable logging
require 'logger'

module Amazon
module Util
module Logging

@@AmazonLogger = nil

def set_log( filename )
 #@@AmazonLogger = Logger.new filename
end

def log( str )
 #set_log 'ruby-aws.log' if @@AmazonLogger.nil?
 #@@AmazonLogger.debug str
end

end
end
end
### Disable logging

NEXT_TWIT = 'next_twit.txt'
HIT_ID = 'hit_id.txt'
USER = "[TWITTER_USER]"
PW = "[TWITTER_PASSWORD]"

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
      if text.index("@") != 0 && !text.include?("http:")
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
        result = true
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

def create_hit(mturk, twit)
  title = "Insert a URL in a short phrase (130 char)"
  desc = "Given a question give a helpful answer with a URL to a hotel site"
  keywords = "Question, Answer, travel, hotels"
  numAssignments = 1
  rewardAmount = 0.05 # 5 cents
  assignmentDurationInSeconds = 30 * 60 # 30 minutes 
  autoApprovalDelayInSeconds = 72 * 60 * 60 # 72 hours
  lifetimeInSeconds = 3 * 60 * 60 # 3 hour

  qualReqs = [{ :QualificationTypeId => Amazon::WebServices::MechanicalTurkRequester::APPROVAL_RATE_QUALIFICATION_TYPE_ID,
                :Comparator => 'GreaterThan', 
                :IntegerValue => 95 }]

  rootDir = File.dirname(__FILE__)
  questionFile = rootDir + "/hit.question"

  question = File.read(questionFile)

  question = question.sub("<%= @otwit %>", CGI::escapeHTML(twit[:text]))

  result = mturk.createHIT( :Title => title,
    :Description => desc,
    :MaxAssignments => numAssignments,
    :Reward => { :Amount => rewardAmount, :CurrencyCode => 'USD' },
    :AssignmentDurationInSeconds => assignmentDurationInSeconds,
    :AutoApprovalDelayInSeconds => autoApprovalDelayInSeconds,
    :LifetimeInSeconds => lifetimeInSeconds,
    :Question => question,
    :QualificationRequirement => qualReqs,
    :RequesterAnnotation => twit[:author],
    :Keywords => keywords )

  File.open(HIT_ID, 'a+') do |f|
    f.puts(result[:HITId])
  end
end

def create_hits(original_twits)
  mturk = Amazon::WebServices::MechanicalTurkRequester.new :Config => File.join( File.dirname(__FILE__), 'mturk.yml' )

  available = mturk.availableFunds
  if available > 0.055
    original_twits.each do |twit|
      create_hit mturk, twit
    end
  end
end

def get_result_for_hit(id)
  mturk = Amazon::WebServices::MechanicalTurkRequester.new :Config => File.join( File.dirname(__FILE__), 'mturk.yml' )

  results = mturk.getHITResults([{:HITId => id}])
  if results[0] != nil
    person = results[0][:RequesterAnnotation]
    results.each do |ass|
      answers = mturk.simplifyAnswer( ass[:Answer] ) 

      answers.each do |id,answer|
        if id == "rtwit" 
          if answer.length > 0
            return {:to => person, :msg => answer}
          else
            return nil
          end
        end
      end
    end
  else
    File.open(HIT_ID, 'a+') do |f|
      f.puts(id)
    end
    return nil
  end
end

def post_twit(twit)
  url = URI.parse('http://twitter.com/')
  Net::HTTP.start(url.host, url.port) do |http|
    req = Net::HTTP::Post.new('/statuses/update.xml')
    req.basic_auth USER, PW 
    req.set_form_data({'status'=>"@#{twit[:to]} #{twit[:msg]}"}, ';')
    http.request(req)
    req = Net::HTTP::Post.new('/friendships/create/' + twit[:to] + '.xml')
    req.basic_auth USER, PW 
    http.request(req)
  end
end

def post_result_twit()
  if File.exist? HIT_ID
    result = File.readlines(HIT_ID).map do |l|
      l.rstrip 
    end
    File.delete HIT_ID
    result.each do |id|
      twit = get_result_for_hit(id)
      if twit != nil
        post_twit twit
      end
    end
  end
end

def main()
  post_result_twit
  original_twits = get_twits
  create_hits original_twits
end

main()

