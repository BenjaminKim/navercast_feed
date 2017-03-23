require 'nokogiri'
require 'open-uri'
require 'ostruct'

NAVER_CAST_BASE_URI = 'http://navercast.naver.com'

def banner_html
  <<~EOS
    <div>
      <p style="border-bottom: 5px solid #eaecef"/>
      <h3>개발자들을 위한 어썸블로그 안드로이드앱이 출시되었습니다.</h3>
      <a href="https://play.google.com/store/apps/details?id=org.petabytes.awesomeblogs">
        <img src="https://github.com/jungilhan/awesome-blogs-android/raw/develop/screenshot.png" style="margin: 10px;">
      </a>
    </div>
  EOS
end

def fetch_data(cid)
  Rails.logger.info("fetch_data: #{cid}")
  doc = Nokogiri::HTML(open("#{NAVER_CAST_BASE_URI}/list.nhn?cid=#{cid}&category_id=#{cid}"))
  feed_title = doc.css('title').first.text
  items = []
  doc.css('ul.card_lst div.card_w').lazy.first(30).each do |link|
    item = OpenStruct.new
    item.title = Rails::Html::FullSanitizer.new.sanitize(
      "#{link.css('span.info strong').text} - #{link.css('span.info span').text}"
    )
    item.link = NAVER_CAST_BASE_URI + link.css('a').attr('href')

    contents_uri = (NAVER_CAST_BASE_URI + link.css('a[href^="/contents.nhn"]').attr('href')).tap do |uri|
      Rails.logger.debug "Content Uri: #{uri}"
    end

    doc = Nokogiri::HTML(open(contents_uri))
    article_link = doc.css('div.smarteditor_area.naml_article').first
    Rails.logger.debug "article_link: #{article_link}"
    parsed_obj = article_link
    datetime = article_link.css('div.t_pdate span').text
    if datetime.blank?
      item.updated = Time.now.utc.strftime('%FT%T%z')
    else
      item.updated = Time.strptime(datetime, '%Y.%m.%d').utc.strftime('%FT%T%z')
    end

    item.summary = parsed_obj.to_html + banner_html
    items << item
  end
  feed_data = OpenStruct.new
  feed_data.title = feed_data.about = feed_title
  Rails.logger.info("item count: #{items.size}, feed_data: #{feed_data.inspect}")
  [items, feed_data]
end

def report_google_analytics(cid, feed_title, ua)
  RestClient.post('http://www.google-analytics.com/collect',
    {
      v: '1',
      tid: 'UA-87999219-1',
      cid: SecureRandom.uuid,
      t: 'pageview',
      dh: 'navercast.petabytes.org',
      dp: cid.to_s,
      dt: feed_title,
    },
    user_agent: ua
  )
end