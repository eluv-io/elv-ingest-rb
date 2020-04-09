# elv-ingest-rb
A ruby wrapper for the elv-client-js Mezzanine creation process 

The elv-ingest gem is a ruby extension that wraps the mezzanine creation process provided in elv-client-js to allow its use from ruby.

Current version: elv-ingest-0.0.1.gem



Installation
--------------

- Install elv-client-js
	- go to the target location
		$ mkdir ~/ELV
		$ cd ~/ELV
	- pull the git branch for elv-client-js
		$ git clone git@github.com:eluv-io/elv-client-js.git
	- Switch to the 'develop' branch
		$ git checkout develop
	- Install the node dependencies
		$ npm install
	- test that the install works
		$ node testScripts/CreateProductionMaster.js --version

- install the ruby gem

	- download the gem

	- install the gem
		$ gem install <Path to where the gem was downloaded>/elv-ingest-0.0.1.gem


Use
-----

The process to create a playable mezzanine is done in several steps. First a production master must be created. The master object typically only references media files on Amazon. Once a master is created, a playable mezzanine file can be derived from it. Here is an example use:

$ irb
irb>


irb> require "elv-ingest"

=> true


irb> s3ingestor = Elv::Ingest.new({
    :private_key=>"0x THE ELUVIO PRIVATE KEY FOR THE CREATOR USER",
    :config_url=>"https:// THE URL FOR THE FABRIC CONFIGURATION /config",
    :elv_client_dir=>"THE PATH FOR ELV/elv-client-js",
    :aws_region=>"AWS REGION",
    :aws_bucket=>"AWS BUCKET",
    :aws_key=>"AWS KEY",
    :aws_secret=>"AWS SECRET"
  })

=> #<Elv::Ingest:0x00007f862e0f7a60  @create_production_master_jobs={}, @pid_map={}, @masters_map={}>


irb> master_stats = s3ingestor.create_production_master({
    :title=>"Test with S3 origin #1",
    :library=>"ilib ID of the library in which to create the master object",
    :files=>[
      "Path to the video file in the bucket.mxf",
      "Path to the audio file in the bucket.mxf"
    ],
    :type=>"iq__ Object ID of the content type Production Master",
    :s3_reference=>true,
    :asynchronous=>false,
    :metadata=> {"public"=>{"note"=>"A 'test' object"}, "something"=>"else"}
  })

=> {:stdout=>["Creating Production Master", "iq__39g4WK8kDXVP8yuq6nQTuEcTBGbi", "{ done: true, uploadedFiles: 2, totalFiles: 2 }", "Production master object created:"], :command_line=>"node CreateProductionMaster.js --config-url https://main.net955210.contentfabric.io/config --library ilib3MCLKj9a7Vwfi1RQ2TjpqRGMQ6FS  --title \"Test with S3 origin #1\" --type iq__39g4WK8kDXVP8yuq6nQTuEcTBGbi --s3-reference true", :object_id=>"iq__2nEn9riTudJhdicqQRemxg85uB65", :hash=>"hq__82MKx9MfwuqeB74pLvpy1ZkJ6JeoBbvMcL7qagfSFSNz5sYHJRn52V1HQz6s1Qg7hBUvZD3Khf", :exit_code=>0}

*Note*: when entering the s3 file path for the creation of the master, leave off S3 bucket name from beginning of file paths

irb> File.open("/tmp/metadata", "w"){|f| f.puts({"another_field"=>["more","values"]}.to_json)}

=> nil


irb> mezz_stats = s3ingestor .create_ABR_mezzanine({
    :library=>"ilib ID of the library in which to create the mezzanine object",
    :title=>"Test with S3 origin #1 -- MEZZ",
    :type=>"q__ Object ID of the content type ABR master",
    :abr_profile=> " Path to the ABR profiled file, for example elv-client-js/testScripts/abr_profile_clear.json",
    :master_hash=> master_stats[:hash],
    :metadata=> "@/tmp/metadata"
  })

=> {:stdout=>["Creating ABR Mezzanine...", "Starting Mezzanine Job(s)", "Library ID ilib3MCLKj9a7Vwfi1RQ2TjpqRGMQ6FS"], :command_line=>"node CreateABRMezzanine.js  --config-url https://main.net955210.contentfabric.io/config --library ilib3MCLKj9a7Vwfi1RQ2TjpqRGMQ6FS --masterHash hq__82MKx9MfwuqeB74pLvpy1ZkJ6JeoBbvMcL7qagfSFSNz5sYHJRn52V1HQz6s1Qg7hBUvZD3Khf --type iq__39g4WK8kDXVP8yuq6nQTuEcTBGbi --abr-profile /Users/marc-olivier/ELV/elv-client-js/testScripts/abr_profile_clear.json", :object_id=>"iq__YHegYyfZdEV3KLDrsjrbuC77wUb", :offering=>"default", :write_token=>"tqw_48sN3sw6F2naHdDQ1CRoQNqvYrHZeFSH1", :write_node=>"https://host-35-233-145-232.test.contentfabric.io/", :exit_code=>0}


irb> s3ingestor.check_ABR_mezzanine_status(mezz_stats[:object_id])

=> {:command_line=>"node MezzanineStatus.js  --config-url https://main.net955210.contentfabric.io/config --objectId iq__YHegYyfZdEV3KLDrsjrbuC77wUb", :jobs=>{"09688ccb-5f4c-469d-8391-7ccd7b17ad12"=>{"duration"=>124673185480, "duration_ms"=>0, "progress"=>{"percentage"=>75.86206896551724}, "run_state"=>"running", "start"=>"2020-04-06T20:08:11Z"}, "88225f85-ef04-487f-8897-76b8e1063c2e"=>{"duration"=>16123986647, "duration_ms"=>16123, "end"=>"2020-04-06T20:08:27Z", "progress"=>{"percentage"=>0}, "run_state"=>"finished", "start"=>"2020-04-06T20:08:11Z"}}, :complete_jobs=>1, :status=>"Running", :exit_code=>0}


irb> s3ingestor.check_ABR_mezzanine_status(mezz_stats[:object_id])

=> {:command_line=>"node MezzanineStatus.js  --config-url https://main.net955210.contentfabric.io/config --objectId iq__YHegYyfZdEV3KLDrsjrbuC77wUb --finalize", :jobs=>nil, :complete_jobs=>2, :status=>"ABR mezzanine object finalized", :exit_code=>0, :stdout=>[], :object_id=>"iq__YHegYyfZdEV3KLDrsjrbuC77wUb", :hash=>"hq__51Z4Pt1NRaFTchkJyaUtTNeBnBKvr6WyUFATZ46MFPfYXRRQiBRY6xEZnQRu5iTN5FJ9oL1Lbx"}



Inline documentation:
---------------------


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
    # => optional: :asynchronous, :type, :name, :ip_title_id, :display_title
    #              :metadata, :encrypt, :s3_copy, :s3_reference, :elv_geo
    # :asynchronous  If sets to true, the execution will be in the backgound,
    #                the call will return a tracking pid              [Boolean]
    # :type          Name, object ID, or version hash of the content type for
    #                the master                                       [String]
    # :name          The Name to give the production master object    [String]
    # :ip_title_id   The ip-title-id of the asset                     [String]
    # :display_title The display title of the asset                   [String]
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
    
# production_master_jobs(status_filter)
    # --> []    And array of the tracking pids for master object creation jobs
    #
    # Use: Provides an array the tracking pids for master object creation jobs in
    #   the specified status. If no status is provided, then all tracking pids
    #   are returned regardless of the job status.
    #
    # status_filter                                                  [String]
    #
    
    
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
    # => required:   :library, :master_hash, :title
    # :library       ID of the library in which to create the master  [string]
    # :master_hash   Version hash of the master object                [string]
    # :title         Title for the master                             [string]
    #
    # => optional: :type, :name, :display_title, :ip_title_id, :slug,
    #              :poster, :metadata, :variant, :offering_key,
    #              :existing_mezz_id :s3_copy, :s3_reference, :elv_geo
    # :type          Name, object ID, or version hash of the content type for
    #                the mezzanine
    # :name          The Object name for the mezzanine object         [string]
    # :display_title Display title of mezzanine (defaulted to title)  [String]
    # :slug          Slug for the mezzanine (generated based on display title
    #                if not specified)                                [String]
    # :ip_title_id   IP title ID for the mezzanine (equivalent to slug
    #                if not specified)                                [String]
    # :title_type    Title type for the mezzanine                     [String]
    # :asset_type    Asset type for the mezzanine                     [String]
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
    

# check_ABR_mezzanine_status(identifier, finalize=true) 
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
    # :private_key   The private key to use to create the master      [String]
    # :config_url    URL pointing to the Fabric configuration. i.e.
    #                https://main.net955210.contentfabric.io/config   [String]
    # :elv_client_dir The path to the location where elv-client-js is
    #                deployed                                         [String]
    # :title         Title of the asset                               [String]
    # :library       ID of the library in which to create the master  [String]
    # :files         Array of files path or file descriptor           [Array]
    #
    # => optional: :type, :metadata, :encrypt, :s3_copy, :s3_reference, :elv_geo,
    #              :name, :ip_title_id, :display_title
    # :type          Name, object ID, or version hash of the content type for
    #                the master                                       [String]
    # :name          The Name to give the production master object    [String]
    # :ip_title_id   The ip-title-id of the asset                     [String]
    # :display_title The display title of the asset                   [String]
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
    # => required:  :private_key, :config_url, :elv_client_dir, :library,
    #               :master_hash, :type, :title
    # :private_key   The private key to use to create the master      [String]
    # :config_url    URL pointing to the Fabric configuration. i.e.
    #                https://main.net955210.contentfabric.io/config   [String]
    # :elv_client_dir The path to the location where elv-client-js is
    #                deployed                                         [String]
    # :library       ID of the library in which to create the master  [String]
    # :master_hash   Version hash of the master object                [String]
    # :type          Name, object ID, or version hash of the content type for
    #                the mezzanine                                    [String]
    # :title         Title for the mezzanine object created           [String]
    #
    # => optional: :type, :poster, :metadata, :variant, :offering_key,
    #              :display_title, :slug, :ip_title_id, :title_type, :asset_type
    #              :existing_mezz_id :s3_copy, :s3_reference, :elv_geo
    # :poster        File pathh to poster image for this mezzanine    [String]
    # :variant       Variant of the mezzanine                [default: "default"]
    # :metadata      Metadata to include in the object metadata, as
    #                - ruby map {"metadata-fieldname"=>metadata-fieldvalue}
    #                - a JSON string of the metadata
    #                - or file path prefixed with '@'
    # :display_title Display title of mezzanine (defaulted to title)  [String]
    # :slug          Slug for the mezzanine (generated based on display title
    #                if not specified)                                [String]
    # :ip_title_id   IP title ID for the mezzanine (equivalent to slug
    #                if not specified)                                [String]
    # :title_type    Title type for the mezzanine                     [String]
    # :asset_type    Asset type for the mezzanine                     [String]
    # :offering_key  Offering key for the new mezzanine      [default: "default"]
    # :existing_mezz_id  If re-running the mezzanine process, the ID of an existing
    #              mezzanine object                                   [String]
    # :abr_profile   Path to JSON file containing alternative ABR profile
    # :s3_copy       If specified, files will be pulled from an S3 bucket instead
    #                of the local system                              [Boolean]
    # :s3_reference  If specified, files will be referenced from an S3 bucket
    #                instead of the local system                      [Boolean]
    # :elv_geo       Geographic region for the fabric nodes. Available regions:
    #                na-west-north|na-west-south|na-east|eu-west      [String]
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
