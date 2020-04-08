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
    :master_hash=> master_stats["hash"],
    :metadata=> "@/tmp/metadata"
  })

=> {:stdout=>["Creating ABR Mezzanine...", "Starting Mezzanine Job(s)", "Library ID ilib3MCLKj9a7Vwfi1RQ2TjpqRGMQ6FS"], :command_line=>"node CreateABRMezzanine.js  --config-url https://main.net955210.contentfabric.io/config --library ilib3MCLKj9a7Vwfi1RQ2TjpqRGMQ6FS --masterHash hq__82MKx9MfwuqeB74pLvpy1ZkJ6JeoBbvMcL7qagfSFSNz5sYHJRn52V1HQz6s1Qg7hBUvZD3Khf --type iq__39g4WK8kDXVP8yuq6nQTuEcTBGbi --abr-profile /Users/marc-olivier/ELV/elv-client-js/testScripts/abr_profile_clear.json", :object_id=>"iq__YHegYyfZdEV3KLDrsjrbuC77wUb", :offering=>"default", :write_token=>"tqw_48sN3sw6F2naHdDQ1CRoQNqvYrHZeFSH1", :write_node=>"https://host-35-233-145-232.test.contentfabric.io/", :exit_code=>0}


irb> s3ingestor.check_ABR_mezzanine_status(mezz_stats.object_id)

=> {:command_line=>"node MezzanineStatus.js  --config-url https://main.net955210.contentfabric.io/config --objectId iq__YHegYyfZdEV3KLDrsjrbuC77wUb", :jobs=>{"09688ccb-5f4c-469d-8391-7ccd7b17ad12"=>{"duration"=>124673185480, "duration_ms"=>0, "progress"=>{"percentage"=>75.86206896551724}, "run_state"=>"running", "start"=>"2020-04-06T20:08:11Z"}, "88225f85-ef04-487f-8897-76b8e1063c2e"=>{"duration"=>16123986647, "duration_ms"=>16123, "end"=>"2020-04-06T20:08:27Z", "progress"=>{"percentage"=>0}, "run_state"=>"finished", "start"=>"2020-04-06T20:08:11Z"}}, :complete_jobs=>1, :status=>"Running", :exit_code=>0}


irb> s3ingestor.check_ABR_mezzanine_status(mezz_stats.object_id)

=> {:command_line=>"node MezzanineStatus.js  --config-url https://main.net955210.contentfabric.io/config --objectId iq__YHegYyfZdEV3KLDrsjrbuC77wUb --finalize", :jobs=>nil, :complete_jobs=>2, :status=>"ABR mezzanine object finalized", :exit_code=>0, :stdout=>[], :object_id=>"iq__YHegYyfZdEV3KLDrsjrbuC77wUb", :hash=>"hq__51Z4Pt1NRaFTchkJyaUtTNeBnBKvr6WyUFATZ46MFPfYXRRQiBRY6xEZnQRu5iTN5FJ9oL1Lbx"}


