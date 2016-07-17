class PhotoSync

  class << self
    attr_accessor :flickr
  end

  @flickr = nil

  def self.upload(opts) 
    if opts[:filename].match /\.jpg$/
      type = 'photo'
    elsif opts[:filename].match /\.png$/
      type = 'screenshot'
    else
      type = false
    end

    # Upload the photo
    args = {}
    args['title'] = opts[:filename]
    args['description'] = ''
    args['is_public'] = 0
    args['is_friend'] = 0
    args['is_family'] = 0
    if type
      args['content_type'] = type == 'photo' ? 1 : 2
    end
    args['tags'] = [
      'uploaded:by=foldersync',
      "sync:filename=#{opts[:filename]}",
      "sync:batch=#{opts[:batch]}"
    ]
    args['tags'] += opts[:folder]['tags']

    # Flatten tags for Flickr
    args['tags'] = args['tags'].map{|k| "\"#{k}\""}.join ' '

    full_filename = "#{opts[:folder]['folder']}/#{opts[:filename]}"

    begin
      flickr_id = @flickr.upload_photo full_filename, args
    rescue => e
      puts "Error uploading photo!"
      puts e.message
      flickr_id = nil
    end

    flickr_id
  end

  def self.set_date(flickr_id, date)
    args = {
      'photo_id' => flickr_id,
      'date_taken' => date,
    }
    begin
      response = @flickr.photos.setDates args
    rescue FlickRaw::FailedResponse => e
      puts "Error setting photo dates"
      puts e.message
      nil
    end
  end

  def self.set_location(flickr_id, lat, lng) 
    args = {
      'photo_id' => flickr_id,
      'lat' => lat,
      'lon' => lng
    }
    begin
      response = @flickr.photos.geo.setLocation args    
    rescue FlickRaw::FailedResponse => e
      puts "Error setting photo location"
      puts e.message
      nil
    end
  end

  def self.exif(filename)
    begin
      exif = EXIFR::JPEG.new(filename)

      data = {
        raw: exif.exif.to_hash
      }
      data[:date] = exif.date_time_original if exif.respond_to? :date_time_original
      # The exif data doesn't have timezone info, so don't return a timezone here
      data[:date_string] = data[:date].strftime('%Y-%m-%d %H:%M:%S') if data[:date]
      data[:software] = exif.software if !exif.software.nil?
      data[:latitude] = exif.gps.latitude if !exif.gps.nil?
      data[:longitude] = exif.gps.longitude if !exif.gps.nil?
      data
    rescue => e
      puts "Unable to read exif data"
      puts e.message
      nil
    end
  end

  def self.find_location_at_time(date, tz=nil)
    if SyncConfig['compass']
      if tz
        response = HTTParty.get "#{SyncConfig['compass']['baseurl']}/api/last?token=#{SyncConfig['compass']['token']}&geocode=true&before=#{URI.encode_www_form_component(date+tz)}"
      else
        response = HTTParty.get "#{SyncConfig['compass']['baseurl']}/api/find-from-localtime?token=#{SyncConfig['compass']['token']}&input=#{URI.encode_www_form_component(date)}"
      end
      if response.parsed_response && response.parsed_response.class == Hash
        return response.parsed_response
      end
    end
    nil
  end

end
