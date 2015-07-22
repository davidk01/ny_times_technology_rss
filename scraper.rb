require 'bundler/setup'
require 'scraperwiki'
require 'nokogiri'

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
rss_xml = ScraperWiki.scrape('http://rss.nytimes.com/services/xml/rss/nyt/Technology.xml')
rss = Nokogiri::HTML(rss_xml)
things = rss.xpath('//item')
# Convert to hash maps with proper data
db_data = things.map do |element|
  title = element.css('title').text
  url = element.css('link').first['href']
  author = element.css('creator').text
  summary = element.css('description').text
  timestamp = element.css('pubdate').text
  db_data = {
    'title' => title, 
    'url' => url, 
    'author' => author, 
    'summary' => summary,
    'timestamp' => timestamp
  }
end

# Insert into database
db_data.each do |data_item|
  columns = data_item.keys.join(', ')
  values = data_item.keys.map {|k| ":#{k}"}.join(', ')
  db.execute("insert into data (#{columns}) values (#{values})", data_item)
end
