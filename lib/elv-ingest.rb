require "open3"
require "uuid"
require "json"

module Elv


  class Ingest


    # Elv::Ingest.new(arguments)
    # --> Elv::Ingest
    #
    # Use: Instanciates an instance of the Elv::Ingest object, which can be used
    #  to submit and monitor jobs to create master and derived playable mezzanine
    #  objects.
    #
    # arguments                                                       [Hash]
    # => required: :private_key, :config_url, :elv_client_dir
    # :private_key   The private key to use to create the master      [String]
    # :config_url    URL pointing to the Fabric configuration. i.e.
    #                https://main.net955210.contentfabric.io/config   [String]
    # :elv_client_dir The path to the location where elv-client-js is
    #                deployed                                         [String]
    #=> optional: :aws_region, : aws_bucket, :aws_key, :aws_secret
    # :aws_region                                                     [String]
    # :aws_bucket                                                     [String]
    # :aws_key                                                        [String]
    # :aws_secret                                                     [String]
    def initialize(arguments)
      puts "ZOB #{arguments}"
      @private_key = arguments[:private_key]
      @config_url = arguments[:config_url]
      @elv_client_dir = arguments[:elv_client_dir]
      @aws_region = arguments[:aws_region]
      @aws_bucket = arguments[:aws_bucket]
      @aws_key = arguments[:aws_key]
      @aws_secret = arguments[:aws_secret]
      @create_production_master_jobs = {}
      @pid_map = {}
      @masters_map = {}
    end


    # create_production_master(arguments)
    #  if :asynchronous is omitted or set to false
    # --> {:object_id , :hash, :stdout, :stderr, :command_line, :exit_code}
    #  if :asynchronous is set to true
    # --> Integer (tracking pid to monitor progress of the job)
    #
    # Use: Creates a Production master object either by uploading files or by
    #  referencing them in an Amazon S3 bucket. if :asynchronous is set to true,
    #  a tracking pid is returned immediately and it can be used to monitor the
    #  progress of the master creation using check_production_master_status.
    #  Once the Production master is created, it can be used to derive a
    #  playable mezzanine object using Elv::Ingest.create_ABR_mezzanine
    #
    # arguments                                                       [Hash]
    # => required:  :library, :title, :files
    # :title         Title for the master                             [String]
    # :library       ID of the library in which to create the master  [String]
    # :files         Array of files path or file descriptor           [Array]
    #
    # => optional: :asynchronous, :type, :metadata, :encrypt, :s3_copy, :s3_reference, :elv_geo
    # :asynchronous  If sets to true, the execution will be in the backgound,
    #                the call will return a tracking pid              [Boolean]
    # :type          Name, object ID, or version hash of the content type for
    #                the master                                       [String]
    # :metadata      Metadata to include in the object metadata, as
    #                - ruby map {"metadata-fieldname"=>metadata-fieldvalue}
    #                - a JSON string of the metadata
    #                - or file path prefixed with '@'
    # :s3_copy       If specified, files will be pulled from an S3 bucket instead
    #                of the local system                              [Boolean]
    # :s3_reference  If specified, files will be referenced from an S3 bucket
    #                instead of the local system                      [Boolean]
    # :elv_geo       Geographic region for the fabric nodes. Available regions:
    #                na-west-north|na-west-south|na-east|eu-west      [String]
    #
    def create_production_master(arguments)
      arguments[:private_key] ||= @private_key
      arguments[:config_url] ||= @config_url
      arguments[:elv_client_dir] ||= @elv_client_dir
      arguments[:aws_region] ||= @aws_region
      arguments[:aws_bucket] ||= @aws_bucket
      arguments[:aws_key] ||= @aws_key
      arguments[:aws_secret] ||= @aws_secret
      pid = nil
      uuid = UUID.generate
      if (arguments[:asynchronous])
        Thread.new do
          Ingest.create_production_master(arguments) {|msg, msg_type|
          case msg_type
            when :pid
              pid = msg
              @create_production_master_jobs[pid] = {:title => arguments[:title], :uuid=>uuid, :status=>"Initiated"}
              @pid_map[uuid]  = pid
            when :exit_code
              @create_production_master_jobs[pid][:exit_code] = msg
              if (msg.to_i == 0)
                @create_production_master_jobs[pid][:status] = "Complete"
              else
                @create_production_master_jobs[pid][:status] = "Failed"
              end
            when :stdout
                @create_production_master_jobs[pid][:status] = "Running"
              if (!@create_production_master_jobs[pid][:stdout])
                @create_production_master_jobs[pid][:stdout] = []
              end
              @create_production_master_jobs[pid][:stdout]  << msg
              @create_production_master_jobs[pid][:latest] = msg
            when :stderr
              @create_production_master_jobs[pid][:stderr] = msg.split(/\n/)
            when :object_id, :hash
              @create_production_master_jobs[pid][msg_type] = msg
            else
              if (pid && @create_production_master_jobs[pid])
                @create_production_master_jobs[pid][msg_type] = msg
              else
                puts "Unexpected status callback type: #{msg_type} -> #{msg}"
              end
            end
          }
        end
        while (!@pid_map[uuid])
          sleep(1)
        end
        return @pid_map[uuid]
      else
        return Ingest.create_production_master(arguments)
      end
    end


    # check_production_master_status(identifier)
    # --> {:object_id , :hash, :stdout, :stderr, :command_line, :exit_code}
    #
    # Use: Provides a report on the status of a master object creation that was
    #  launched asynchronously.
    #
    # identifier     tracking pid                                    [Integer]
    #                production master title                         [String]
    #  The identifier provided to identify the job can either be the tracking
    #  pid returned by create_production_master_status or the title used when
    #  launching the creation.
    #
    def check_production_master_status(identifier)
      if identifier.is_a?(String)
        if (identifier.match(/^[0-9]+$/)) #identifier is a pid passed as a string
          return @create_production_master_jobs[identifier.to_i] || @create_production_master_jobs[identifier]  #just in case the title was just numbers
        else
          @create_production_master_jobs.each do  |pid, stats|
            return stats if (stats.title == identifier)
          end
        end
      end
      return @create_production_master_jobs[identifier]
    end

    # production_master_jobs(status_filter)
    # --> []    And array of the tracking pids for master object creation jobs
    #
    # Use: Provides an array the tracking pids for master object creation jobs in
    #   the specified status. If no status is provided, then all tracking pids
    #   are returned regardless of the job status.
    #
    # status_filter                                                  [String]
    #
    def production_master_jobs(status_filter=nil)
      if (status_filter == nil)
        return @create_production_master_jobs.keys
      else
        jobs = []
        @create_production_master_jobs.each{|job_id, job_stats|
          jobs << job_id if (job_stats[:status] == status_filter)
        }
        return jobs
      end
    end


    # create_ABR_mezzanine(arguments)
    # --> {:object_id , :write_token, :write_node, :offering, :stdout, :stderr,
    #      :command_line, :exit_code}
    #
    # Use: Creates a Mezzanine object from a Production master and initiates the data
    #  preparation. The function returns once the data preparation is kicked-off.
    #  The preparation of the object can be monitored using check_mezzanine_status.
    #  Once the mezzanine status is reported to be "Complete", the mezzanine
    #  object must be explicly finalized eithe by calling Elv::Ingest.check_mezzanine_status
    #  with :finalize=>true or by calling Elv::Ingest.finalize_ABR_mezzanine.
    #
    # arguments                                                       [Hash]
    # => required:   :library, :master_hash
    # :library       ID of the library in which to create the master  [string]
    # :master_hash   Version hash of the master object                [string]
    #
    # => optional: :type, :title, :poster, :metadata, :variant, :offering_key,
    #              :existing_mezz_id :s3_copy, :s3_reference, :elv_geo
    # :title         Title for the master                             [string]
    # :type          Name, object ID, or version hash of the content type for
    #                the mezzanine                                    [string]
    # :poster        File pathh to poster image for this mezzanine    [string]
    # :variant       Variant of the mezzanine                [default: "default"]
    # :metadata      Metadata to include in the object metadata, as
    #                - ruby map {"metadata-fieldname"=>metadata-fieldvalue}
    #                - a JSON string of the metadata
    #                - or file path prefixed with '@'
    # :offering_key  Offering key for the new mezzanine      [default: "default"]
    # :existing_mezz_id  If re-running the mezzanine process, the ID of an existing
    #              mezzanine object                                   [string]
    # :abr_profile     Path to JSON file containing alternative ABR profile
    # :s3_copy       If specified, files will be pulled from an S3 bucket instead
    #                of the local system                              [boolean]
    # :s3_reference  If specified, files will be referenced from an S3 bucket
    #                instead of the local system                      [boolean]
    # :elv_geo       Geographic region for the fabric nodes. Available regions:
    #                na-west-north|na-west-south|na-east|eu-west      [string]
    #
    def create_ABR_mezzanine(arguments)
      arguments[:private_key] ||= @private_key
      arguments[:config_url] ||= @config_url
      arguments[:elv_client_dir] ||= @elv_client_dir
      arguments[:aws_region] ||= @aws_region
      arguments[:aws_bucket] ||= @aws_bucket
      arguments[:aws_key] ||= @aws_key
      arguments[:aws_secret] ||= @aws_secret
      stats = Ingest.create_ABR_mezzanine(arguments)
      @masters_map[arguments[:master_hash]] = stats[:object_id]
      return stats
    end


    # Elv::Ingest.check_mezzanine_status(arg) {|msg, msg_type|}
    # --> {:object_id, :hash, :jobs , :complete_jobs, :status, :stdout, :stderr,
    #      :command_line, :exit_code}
    #
    # Use: Returns the status of the mezzanine preparation process.
    #  During the preparation, the status will be set as "Running". Once the
    #  preparation is finished, the status will be set as "Complete". By default,
    #  (unless finalize is set to false), if the object is found to be Complete,
    #  it will be finalized.
    #  The identifier can be either the mezzanine object ID or the hash of th
    #  production master that the mezzanine is derived from.
    #
    # identifier:   the object ID of the mezzanine object             [String]
    #               the hash of the production master                 [String]
    #
    # finalize      indicates whether to finalize upon completion     [Boolean]
    #
    def check_ABR_mezzanine_status(identifier, finalize=true)
      arguments = {:private_key => @private_key, :config_url => @config_url, :elv_client_dir => @elv_client_dir}
      arguments[:object_id] = identifier.match(/iq__/) ? identifier : @masters_map[identifier]
      stats = Ingest.check_mezzanine_status(arguments)
      if ((stats[:status] == "Complete") && finalize)
        arguments[:finalize] = true
        stats.merge!(Ingest.check_mezzanine_status(arguments))
      end
      return stats
    end


    # Elv::Ingest.create_production_master(arg) {|msg, msg_type|}
    # --> {:object_id , :hash, :stdout, :stderr, :command_line, :exit_code}
    #
    # Use: Creates a Production master object either by uploading files or by
    #  referencing them in an Amazon S3 bucket.
    #  Once the Production master is created, it can be used to derive a
    #  playable mezzanine object using Elv::Ingest.create_ABR_mezzanine
    #
    # arg:
    # => required:  :private_key, :config_url, :elv_client_dir, :library, :title, :files
    # :private_key   The private key to use to create the master      [string]
    # :config_url    URL pointing to the Fabric configuration. i.e.
    #                https://main.net955210.contentfabric.io/config   [string]
    # :elv_client_dir The path to the location where elv-client-js is
    #                deployed                                         [string]
    # :title         Title for the master                             [string]
    # :library       ID of the library in which to create the master  [string]
    # :files         Array of files path or file descriptor           [array]
    #
    # => optional: :type, :metadata, :encrypt, :s3_copy, :s3_reference, :elv_geo
    # :type          Name, object ID, or version hash of the content type for
    #                the master                                       [string]
    # :metadata      Metadata to include in the object metadata, as
    #                - ruby map {"metadata-fieldname"=>metadata-fieldvalue}
    #                - a JSON string of the metadata
    #                - or file path prefixed with '@'
    # :s3_copy       If specified, files will be pulled from an S3 bucket instead
    #                of the local system                              [boolean]
    # :s3_reference  If specified, files will be referenced from an S3 bucket
    #                instead of the local system                      [boolean]
    # :elv_geo       Geographic region for the fabric nodes. Available regions:
    #                na-west-north|na-west-south|na-east|eu-west      [string]
    # :aws_region                                                     [String]
    # :aws_bucket                                                     [String]
    # :aws_key                                                        [String]
    # :aws_secret                                                     [String]
    #
    # reporting_callback
    # => if a reporting callback 2-argument (message, message type) block is provided, it will be called
    #    each time a reporting message is emitted by the creation process.
    #    The message types are: :pid, :object_id, :hash, :stdout, :stderr and :exit_code
    #    If no block is provided, the reporting is done on the standard output.
    def self.create_production_master(arg, &reporting_callback)
      outputs = {:stdout=>[]}
      files = arg[:files].map{|file| "--files \"#{file}\""}.join(" ")

      cmd_line = "node CreateProductionMaster.js --config-url #{arg[:config_url]} --library #{arg[:library]} #{files} --title \"#{arg[:title]}\""
      cmd_line << " --type #{arg[:type]}"  if (arg[:type])
      cmd_line << " --encrypt #{arg[:encrypt]}" if (arg[:encrypt] != nil)
      cmd_line << " --s3-copy #{arg[:s3_copy]}" if (arg[:s3_copy] != nil)
      cmd_line << " --s3-reference #{arg[:s3_reference]}" if (arg[:s3_reference] != nil)
      cmd_line << " --elv-geo #{arg[:elv_geo]}"  if (arg[:elv_geo])
      metadata = arg[:metadata]
      if metadata
        if (metadata.is_a?(String) == false)
          metadata = metadata.to_json
        end
        cmd_line << " --metadata '#{metadata.gsub(/'/){"'\\''"}}'"
      end
      outputs[:command_line]= cmd_line
      cmd_env = {"PRIVATE_KEY"=>arg[:private_key]}
      cmd_env["AWS_REGION"] = arg[:aws_region] if arg[:aws_region]
      cmd_env["AWS_BUCKET"] = arg[:aws_bucket] if arg[:aws_bucket]
      cmd_env["AWS_KEY"] = arg[:aws_key] if arg[:aws_key]
      cmd_env["AWS_SECRET"] = arg[:aws_secret] if arg[:aws_secret]
      cmd_path = File.join(arg[:elv_client_dir], "testScripts")
      Open3.popen3(cmd_env, cmd_line,  {:chdir=> cmd_path}) {|stdin, stdout, stderr, wait_thr|
          pid = wait_thr.pid # pid of the started process.
          if (!reporting_callback)
            reporting_callback = ->(msg,msg_type) { puts("#{msg_type}: #{msg}") }
          end
          reporting_callback.call(pid, :pid)

          stdout.each_line do |line|
            msg = line.strip
            if (msg != "")
              { :object_id => /Object ID.*(iq__[^ ]+)/,
                :hash=>/Version Hash.*(hq__[^ ]+)/,
                :stdout=>/(.*)/
              }.each do |type, pattern|
                matcher = msg.match(pattern)
                if (matcher)
                  reporting_callback.call(matcher[1], type)
                  if (outputs[type].is_a?(Array))
                    outputs[type] << matcher[1]
                  else
                    outputs[type] = matcher[1]
                  end
                  break
                end
              end
            end
          end

          matcher = wait_thr.value.to_s.match(/exit ([0-9]+)/)
          if (matcher)
            outputs[:exit_code] = matcher[1].to_i
          end
          errors = stderr.read
          errors = errors.strip if (errors)
          if (errors != "")
            reporting_callback.call(errors, :stderr)
            outputs[:stderr] = errors.split(/\n/)
          end
          reporting_callback.call(outputs[:exit_code], :exit_code)
      }
      return outputs
    end



    # Elv::Ingest.create_ABR_mezzanine(arg) {|msg, msg_type|}
    # --> {:object_id , :write_token, :write_node, :offering, :stdout, :stderr,
    #      :command_line, :exit_code}
    #
    # Use: Creates a Mezzanine object from a Production master and initiates the data
    #  preparation. The function returns once the data preparation is kicked-off.
    #  The preparation of the object can be monitored using check_mezzanine_status.
    #  Once the mezzanine status is reported to be "Complete", the mezzanine
    #  object must be explicly finalized eithe by calling Elv::Ingest.check_mezzanine_status
    #  with :finalize=>true or by calling Elv::Ingest.finalize_ABR_mezzanine.
    #
    # arg:
    # => required:  :private_key, :config_url, :elv_client_dir, :library, :master_hash
    # :private_key   The private key to use to create the master      [string]
    # :config_url    URL pointing to the Fabric configuration. i.e.
    #                https://main.net955210.contentfabric.io/config   [string]
    # :elv_client_dir The path to the location where elv-client-js is
    #                deployed                                         [string]
    # :library       ID of the library in which to create the master  [string]
    # :master_hash   Version hash of the master object                [string]
    #
    # => optional: :type, :title, :poster, :metadata, :variant, :offering_key,
    #              :existing_mezz_id :s3_copy, :s3_reference, :elv_geo
    # :title         Title for the master                             [string]
    # :type          Name, object ID, or version hash of the content type for
    #                the mezzanine                                    [string]
    # :poster        File pathh to poster image for this mezzanine    [string]
    # :variant       Variant of the mezzanine                [default: "default"]
    # :metadata      Metadata to include in the object metadata, as
    #                - ruby map {"metadata-fieldname"=>metadata-fieldvalue}
    #                - a JSON string of the metadata
    #                - or file path prefixed with '@'
    # :offering_key  Offering key for the new mezzanine      [default: "default"]
    # :existing_mezz_id  If re-running the mezzanine process, the ID of an existing
    #              mezzanine object                                   [string]
    # :abr_profile     Path to JSON file containing alternative ABR profile
    # :s3_copy       If specified, files will be pulled from an S3 bucket instead
    #                of the local system                              [boolean]
    # :s3_reference  If specified, files will be referenced from an S3 bucket
    #                instead of the local system                      [boolean]
    # :elv_geo       Geographic region for the fabric nodes. Available regions:
    #                na-west-north|na-west-south|na-east|eu-west      [string]
    # :aws_region                                                     [String]
    # :aws_bucket                                                     [String]
    # :aws_key                                                        [String]
    # :aws_secret                                                     [String]
    #
    # reporting_callback
    # => if a reporting callback 2-argument (message, message type) block is provided, it will be called
    #    each time a reporting message is emitted by the creation process.
    #    The message types are: :pid, :object_id, :write_token, :write_node,
    #    :offering, :stdout, :stderr and :exit_code
    #    If no block is provided, the reporting is done on the standard output.
    def self.create_ABR_mezzanine(arg, &reporting_callback)
      outputs = {:stdout=>[]}
      cmd_line = "node CreateABRMezzanine.js  --config-url #{arg[:config_url]} --library #{arg[:library]} --masterHash #{arg[:master_hash]}"
      cmd_line << " --type #{arg[:type]}"  if (arg[:type])
      cmd_line << " --title \"#{arg[:title]}\"" if (arg[:title])
      cmd_line << " --poster \"#{arg[:poster]}\"" if (arg[:poster])
      cmd_line << " --variant #{arg[:variant]}" if (arg[:variant])
      cmd_line << " --offering-key #{arg[:offering_key]}" if (arg[:offering_key])
      cmd_line << " --existingMezzId #{arg[:existing_mezz_id]}" if (arg[:existing_mezz_id])
      cmd_line << " --abr-profile #{arg[:abr_profile]}" if (arg[:abr_profile])
      cmd_line << " --s3-copy #{arg[:s3_copy]}" if (arg[:s3_copy] != nil)
      cmd_line << " --s3-reference #{arg[:s3_reference]}" if (arg[:s3_reference] != nil)
      cmd_line << " --elv-geo #{arg[:elv_geo]}"  if (arg[:elv_geo])
      metadata = arg[:metadata]
      if metadata
        if (metadata.is_a?(String) == false)
          metadata = metadata.to_json
        end
        cmd_line << " --metadata '#{metadata.gsub(/'/){"'\\''"}}'"
      end
      outputs[:command_line]= cmd_line
      cmd_env = {"PRIVATE_KEY"=>arg[:private_key]}
      cmd_env["AWS_REGION"] = arg[:aws_region] if arg[:aws_region]
      cmd_env["AWS_BUCKET"] = arg[:aws_bucket] if arg[:aws_bucket]
      cmd_env["AWS_KEY"] = arg[:aws_key] if arg[:aws_key]
      cmd_env["AWS_SECRET"] = arg[:aws_secret] if arg[:aws_secret]
      cmd_path = File.join(arg[:elv_client_dir], "testScripts")
      Open3.popen3(cmd_env, cmd_line,  {:chdir=> cmd_path}) {|stdin, stdout, stderr, wait_thr|
          pid = wait_thr.pid
          if (!reporting_callback)
            reporting_callback = ->(msg,msg_type) { puts("#{msg_type}: #{msg}") }
          end
          reporting_callback.call(pid, :pid)

          stdout.each_line do |line|
            msg = line.strip
            if (msg != "")
              { :object_id => /Object ID.*(iq__[^ ]+)/,
                :write_token=>/Write Token.*(tqw_[^ ]+)/,
                :write_node=>/Write Node.*(http[^ ]+)/,
                :offering=>/Offering.+?([^ ]+)/,
                :stdout=>/(.*)/
              }.each do |type, pattern|
                matcher = msg.match(pattern)
                if (matcher)
                  reporting_callback.call(matcher[1], type)
                  if (outputs[type].is_a?(Array))
                    outputs[type] << matcher[1]
                  else
                    outputs[type] = matcher[1]
                  end
                  break
                end
              end
            end
          end

          matcher = wait_thr.value.to_s.match(/exit ([0-9]+)/)
          if (matcher)
            outputs[:exit_code] = matcher[1].to_i
          end
          errors = stderr.read
          errors = errors.strip if (errors)
          if (errors != "")
            reporting_callback.call(errors, :stderr)
            outputs[:stderr] = errors.split(/\n/)
          end
          reporting_callback.call(outputs[:exit_code], :exit_code)
      }
      return outputs
    end

    # Elv::Ingest.check_mezzanine_status(arg) {|msg, msg_type|}
    # --> {:object_id, :hash, :jobs , :complete_jobs, :status, :stdout, :stderr,
    #      :command_line, :exit_code}
    #
    # Use: Returns the status of the mezzanine preparation process.
    #  During the preparation, the status will be set as "Running". Once the
    #  preparation is finished, the status will be set as "Complete". Before the
    #  mezzanine object can be used it must be finalized, which can be done by
    #  calling this function with the :finalize=>true or by calling
    #  Elv::Ingest.finalize_ABR_mezzanine. If the object is finalized, then the
    #  status returned is set to "ABR mezzanine object finalized"
    #
    # arg:
    # => required:  :private_key, :config_url, :elv_client_dir, :object_id
    # :private_key   The private key to use to create the master      [string]
    # :config-url    URL pointing to the Fabric configuration. i.e.
    #                https://main.net955210.contentfabric.io/config   [string]
    # :elv_client_dir The path to the location where elv-client-js is
    #                deployed                                         [string]
    # :object_id     The ID of the mezzanine object                   [string]
    #
    # => optional: :offering_key, :finalize
    # :offering_key  Offering key for the new mezzanine      [default: "default"]
    # :finalize      Indicates the mezzanine should be finalized      [boolean]
    #
    # reporting_callback
    # => if a reporting callback 2-argument (message, message type) block is provided, it will be called
    #    each time a reporting message is emitted by the creation process.
    #    The message types are: :pid, :hash, :status, :stdout, :stderr and :exit_code
    #    If no block is provided, the reporting is done on the standard output.
    def self.check_mezzanine_status(arg, &reporting_callback)
      outputs = {}
      cmd_line = "node MezzanineStatus.js  --config-url #{arg[:config_url]} --objectId #{arg[:object_id]}"
      cmd_line << " --variant #{arg[:variant]}" if (arg[:variant])
      cmd_line << " --offering-key #{arg[:offering_key]}" if (arg[:offering_key])
      cmd_line << " --finalize"  if (arg[:finalize])
      outputs[:command_line]= cmd_line
      Open3.popen3({"PRIVATE_KEY"=>arg[:private_key]}, cmd_line,
                    {:chdir=> File.join(arg[:elv_client_dir], "testScripts")}
      ) {|stdin, stdout, stderr, wait_thr|
          pid = wait_thr.pid # pid of the started process.
          if (!reporting_callback)
            reporting_callback = ->(msg,msg_type) { puts("#{msg_type}: #{msg}") }
          end
          reporting_callback.call(pid, :pid)

          raw_output = stdout.read.strip
          outputs[:jobs] = JSON.parse(raw_output) rescue nil
          if (!outputs[:jobs])
            outputs[:stdout]= []
            raw_output.split(/\n/).each { |line|
              msg = line.strip
              if (msg != "")
                { :object_id => /Object ID.*(iq__[^ ]+)/,
                  :hash=>/Version Hash.*(hq__[^ ]+)/,
                  :status=>/(ABR mezzanine object finalized):/,
                  :stdout=>/(.*)/
                }.each do |type, pattern|
                  matcher = msg.match(pattern)
                  if (matcher)
                    reporting_callback.call(matcher[1], type)
                    if (outputs[type].is_a?(Array))
                      outputs[type] << matcher[1]
                    else
                      outputs[type] = matcher[1]
                    end
                    break
                  end
                end
              end
            }
          else
            outputs[:complete_jobs] = 0
            outputs[:jobs].each do |job_id, job_stats|
              if (job_stats["run_state"] == "finished")
                outputs[:complete_jobs] += 1
              end
            end
            if (outputs[:complete_jobs] == outputs[:jobs].size)
              outputs[:status] = "Complete"
            else
              outputs[:status] = "Running"
            end
          end

          matcher = wait_thr.value.to_s.match(/exit ([0-9]+)/)
          if (matcher)
            outputs[:exit_code] = matcher[1].to_i
          end
          errors = stderr.read
          if (errors != "")
            reporting_callback.call(errors, :stderr)
            outputs[:stderr] = errors.split(/\n/)
          end
          reporting_callback.call(outputs[:exit_code], :exit_code)
      }
      return outputs
    end


    # Elv::Ingest.finalize_ABR_mezzanine(arg) {|msg, msg_type|}
    # --> {:object_id, :hash, :jobs , :complete_jobs, :status, :stdout, :stderr,
    #      :command_line, :exit_code}
    #
    # Use: Finalizes a mezzanine object for which the preparation was completed.
    #  Once finalized, a mezzanine object is playable.
    #
    # arg:
    # => required:  :private_key, :config_url, :elv_client_dir, :object_id
    # :private_key   The private key to use to create the master      [string]
    # :config-url    URL pointing to the Fabric configuration. i.e.
    #                https://main.net955210.contentfabric.io/config   [string]
    # :elv_client_dir The path to the location where elv-client-js is
    #                deployed                                         [string]
    # :object_id     The ID of the mezzanine object                   [string]
    #
    # => optional: :offering_key, :finalize
    # :offering_key  Offering key for the new mezzanine      [default: "default"]
    #
    # reporting_callback
    # => if a reporting callback 2-argument (message, message type) block is provided, it will be called
    #    each time a reporting message is emitted by the creation process.
    #    The message types are: :pid, :hash, :status, :stdout, :stderr and :exit_code
    #    If no block is provided, the reporting is done on the standard output.
    #
    def self.finalize_ABR_mezzanine(arg, &reporting_callback)
      return check_mezzanine_status(arg.merge({:finalize => true}), reporting_callback)
    end

  end




end
