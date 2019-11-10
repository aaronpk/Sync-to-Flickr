require './env/'

login = @flickr.test.login
if login.username.nil?
	puts "Something went wrong!"
	exit
end

puts "Connected as #{login.username}"


photoset_id = nil

# All photos added this batch will have a tag so they can be referenced easily
batch = Time.now.strftime '%Y%m%d%H%M%S'
photos_added = 0
photo_urls = []


SyncConfig['sync_folders'].each do |folder|
  next if photos_added >= 100 

  puts "============================================="
  puts "Beginning Folder:"
  puts folder['folder']

  photos = []
  Dir.foreach(folder['folder']) do |filename|
    if filename.match /\.(jpg|png)/i
      photos << filename
    end
  end
  photos.sort!

  puts "Found #{photos.length} photos to sync"
  # puts photos.inspect

  last_timezone = nil

  photos.each do |filename|

  	next if photos_added >= 100

    full_filename = "#{folder['folder']}/#{filename}"
    error_filename = "#{folder['errors']}/#{filename}"

    puts "Beginning #{full_filename}"

    flickr_id = PhotoSync.upload({
      folder: folder,
      filename: filename,
      batch: batch
    })

    if flickr_id
      puts "Uploaded with id #{flickr_id}: http://flic.kr/p/#{Base58.encode(flickr_id.to_i)}"
    else
      File.rename full_filename, error_filename
      next
    end

    exif = PhotoSync.exif full_filename

    photo_date = nil
    photo_coords = nil

    if exif
      photo_date = exif[:date_string]
      if exif[:latitude]
        photo_coords = {latitude: exif[:latitude], longitude: exif[:longitude]}
      end
    end

    # If the photo contained exif data, we may have been able to extract the date and location from it.
    # If not, Flickr won't be able to get much out of the photo, so let's set some things manually now.

    # Set the date taken if there was no exif date
    if photo_date.nil?
      if(match=filename.match(/^(\d{4}-\d{2}-\d{2}) (\d{2})\.(\d{2})\.(\d{2})/))
        photo_date = "#{match[1]} #{match[2]}:#{match[3]}:#{match[4]}"
        puts "Setting photo date taken from filename: #{photo_date}"
        PhotoSync.set_date flickr_id, photo_date
      end
    end

    # If there were no GPS coordinates in the exif data, look up the location from Compass for the given date
    if photo_coords.nil? && !photo_date.nil?
      if last_timezone
        puts "Looking up location..."
        # If we've found a timezone before, there's a good chance this photo is also in that timezone.
        # Query the GPS logs and check if the timezone offset matches.
        location = PhotoSync.find_location_at_time photo_date, last_timezone
        if location && location['geocode']
          if location['geocode']['offset'] != last_timezone
            puts "\tTimezone offset didn't match, checking for new offset..."
            # If the offset does not match, then we need to find the offset for this photo
            location = PhotoSync.find_location_at_time photo_date
            if location && location['timezone']
              puts "\tFound offset #{location['timezone']['offset']}"
              last_timezone = location['timezone']['offset']
            end
          end
        end
      else
        puts "Looking up location given an exif date..."
        location = PhotoSync.find_location_at_time photo_date
        if location && location['timezone']
          puts "\tFound offset #{location['timezone']['offset']}"
          last_timezone = location['timezone']['offset']
        end
      end

      if location && location['data'] && location['data']['geometry']
        puts "Setting photo location: #{location['data']['geometry']['coordinates'][1]}, #{location['data']['geometry']['coordinates'][0]}"
        PhotoSync.set_location flickr_id, location['data']['geometry']['coordinates'][1], location['data']['geometry']['coordinates'][0]
      end
    end

    if folder['photoset_id']
      # Add the photo to the photoset
      puts "Adding to photoset..."
      response = @flickr.photosets.addPhoto :photoset_id => folder['photoset_id'], :photo_id => flickr_id
    end

    # Move the photo to the "complete" folder
    if photo_date.nil?
      dir_date = DateTime.now.strftime("%Y-%m-%d")
    else
      dir_date = DateTime.parse(photo_date).strftime("%Y-%m-%d")
    end
    dir = "#{folder['complete']}/#{dir_date}"
    completed_filename = "#{dir}/#{filename}"
    Dir.mkdir(dir) unless File.exists?(dir)
    File.rename full_filename, completed_filename
    
    info = @flickr.photos.getInfo(:photo_id => flickr_id)
    photo_urls << FlickRaw.url_m(info)
    
    Notify.irc FlickRaw.url_m(info)
    
    photos_added += 1

    puts "."
  end

end


# After all photos are finished, send an email with a link to see the photos that were just imported

if photos_added > 0

  batch_url = "https://www.flickr.com/photos/#{SyncConfig['flickr_username']}/tags/sync%3Abatch%3D#{batch}"

	email_text = "#{photos_added} photo#{photos_added == 1 ? ' was' : 's were'} just uploaded to your Flickr stream.\n\n"
	email_text += "#{batch_url}"

  email_html = "<p>#{photos_added} photo#{photos_added == 1 ? ' was' : 's were'} were just uploaded to your Flickr stream.</p>\n"
  email_html += "<p><a href=\"#{batch_url}\">View Photo#{photos_added == 1 ? '' : 's'}</a></p>\n"
  
  photo_urls.each do |u|
    email_html += "<img src=\"#{u}\"> "
  end

	puts
	puts email_text

  Notify.email email_text, email_html

	puts "Done!"

end
