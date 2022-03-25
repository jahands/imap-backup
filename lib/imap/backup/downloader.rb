module Imap::Backup
  class MultiFetchFailedError < StandardError; end

  class Downloader
    attr_reader :folder
    attr_reader :serializer
    attr_reader :multi_fetch_size

    def initialize(folder, serializer, multi_fetch_size: 1)
      @folder = folder
      @serializer = serializer
      @multi_fetch_size = multi_fetch_size
    end

    def run
      uids = folder.uids - serializer.uids
      count = uids.count
      debug "#{count} new messages"
      uids.each_slice(multi_fetch_size).with_index do |block, i|
        uids_and_bodies = folder.fetch_multi(block)
        if uids_and_bodies.nil?
          if multi_fetch_size > 1
            uids = block.join(", ")
            debug("Multi fetch failed for UIDs #{uids}, switching to single fetches")
            raise MultiFetchFailedError
          else
            debug("Fetch failed for UID #{block[0]} - skipping")
            next
          end
        end

        offset = (i * multi_fetch_size) + 1
        uids_and_bodies.each.with_index do |uid_and_body, j|
          uid = uid_and_body[:uid]
          body = uid_and_body[:body]
          case
          when !body
            info("Fetch returned empty body - skipping")
          when !uid
            info("Fetch returned empty UID - skipping")
          else
            debug("uid: #{uid} (#{offset + j}/#{count}) - #{body.size} bytes")
            serializer.append uid, body
          end
        end
      end
    rescue MultiFetchFailedError
      @multi_fetch_size = 1
      retry
    end

    private

    def info(message)
      Logger.logger.info("[#{folder.name}] #{message}")
    end

    def debug(message)
      Logger.logger.debug("[#{folder.name}] #{message}")
    end
  end
end
