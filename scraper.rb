require 'bundler/setup'
require 'scraperwiki'
require 'nokogiri'
require 'pp'

# title, url, author, summary, timestamp
db = SQLite3::Database.new('data.sqlite')
db.execute <<-SQL
  create table if not exists data
   (title text primary key on conflict replace,
     url text not null,
     author text not null,
     summary text not null,
     timestamp datetime not null);
SQL

# Grab the rss
feeds = ['http://rss.nytimes.com/services/xml/rss/nyt/Science.xml',
         'http://rss.nytimes.com/services/xml/rss/nyt/Technology.xml',
         'http://rss.nytimes.com/services/xml/rss/nyt/Space.xml',
         'http://rss.nytimes.com/services/xml/rss/nyt/HomePage.xml']
feeds.each do |feed|
  rss_xml = ScraperWiki.scrape(feed)
  rss = Nokogiri::HTML(rss_xml)
  things = rss.xpath('//item')
  # Convert to hash maps with proper data
  db_data = things.map do |element|
    title = element.css('title').text
    # URL item is not consistent so need to be careful
    url = (url_element = element.css('link').first)['href']
    url ||= url_element.next.text
    author = element.css('creator').text
    summary = element.css('description').text
    timestamp = element.css('pubdate').text
    db_item = {
      'title' => title, 
      'url' => url, 
      'author' => author, 
      'summary' => summary,
      'timestamp' => timestamp
    }
    # Some debug output
    if db_item.values.any?(&:nil?)
      pp db_item
      raise StandardError, "nil value found for item"
    else
      db_item
    end
  end

  # Insert into database
  db_data.each do |data_item|
    columns = data_item.keys.join(', ')
    values = data_item.keys.map {|k| ":#{k}"}.join(', ')
    db.execute("insert into data (#{columns}) values (#{values})", data_item)
  end

end
