# require 'FileUtils' # for relative working path
t=Time.now
database='snumbat://localhost:40000/Demo'
netid=10179
runid=10180
simid=10181

iteration_limit = 100	# Maximum number of iterations to modify and rerun model
timeout = 60*1000		# simulation timeout time in miliseconds if runs take too long. Currently 60 sec
report_validation = true

#working_dir = Dir.pwd
working_dir = 'C:\Users\nathan.gerdts\OneDrive - Innovyze, INC\Development\Github\ICM_Tools\IExchange Example Scripts\Automated CIP Testing'
existing_pipes = working_dir+'\Shapefiles\existing.shp'
proposed_pipes = working_dir+'\Shapefiles\proposed.shp'
cip_differences = working_dir+'cip_differences.csv'
import_config_file = working_dir + '\Shapefiles\pipe_import.cfg'
export_config_file = working_dir + '\Shapefiles\pipe_export.cfg'
err_file = working_dir + '\errors.txt'				# File for tracking errors and status
File.open(err_file,'w'){|file| file.truncate(0) }	# Remove old content
import_options = {
	"Error File" => err_file,						# Save error log path
	"Set Value Flag" => 'NG',						# Import Flag
	"Duplication Behaviour" => 'Overwrite',			# 'Overwrite','Merge','Ignore'
	"Units Behaviour" => 'User' 					# 'Native' or 'User' units
}
export_options = {
	"Error File" => err_file,						# Save error log path
	"Units Behaviour" => 'User' 					# 'Native' or 'User' units
}

# ===========================================================================================
# Prepare methods and initialize model

def validate_commit_close(open_network,report_validation,commit_comments)
	valres=open_network.validate('Base')
	if report_validation
		puts "errors #{valres.error_count} warnings #{valres.warning_count}"
		valres.each do |v|
			puts "#{v.code},#{v.field},#{v.field_description},#{v.object_id},#{v.code},#{v.object_type},#{v.message},#{v.priority},#{v.scenario},#{v.type}"
		end
	end
	open_network.commit commit_comments
	open_network.close
end
def rerun_simulation(run_object,simlist,run_timeout)
	run_object.update_to_latest
	handles=WSApplication.launch_sims(simlist,'.',false,0,0)
	index=WSApplication.wait_for_jobs handles,true,run_timeout
end

db=WSApplication.open database,false
network=db.model_object_from_type_and_id 'Model Network',netid
runobject=db.model_object_from_type_and_id 'Run',runid
existing_commit_id = network.current_commit_id
WSApplication.connect_local_agent(1)
sims=Array.new
runobject.children.each do |c|
	sims<<c
end

# ===========================================================================================
# Update from GIS and run updated model

puts "Updating model from source data"
net=network.open
existing_commit_id = network.current_commit_id
net.odic_import_ex(
	'SHP',					# Data Format
	import_config_file,		# Field Mapping Configuration
	import_options,			# Additional options in Ruby Hash
	'Conduit',				# Parameter 1 - InfoWorks Layer to Import
	existing_pipes			# Parameter 2 - Path to Shapefile
)
File.write(err_file, "\n End of Import \n", File.size(err_file))
validate_commit_close(net,report_validation,"Updated Pipes to existing GIS conditions")
puts "Running Updated Model"
rerun_simulation(runobject,sims,timeout)

# ===========================================================================================
# Begin Iteration loop: Check for capacity issues, modify, run, restart

k = 1
while k <= iteration_limit
	puts "Starting loop ##{k} out of max #{iteration_limit}"
	simobject=db.model_object_from_type_and_id 'Sim',simid
	net=network.open
	sim=simobject.open

	sim.run_SQL('hw_conduit','SELECT WHERE sim.max_surcharge = 2 AND MAX(sim.all_ds_links.max_Surcharge) < 2')
	selected_pipes=sim.row_objects_selection('hw_conduit')
	if selected_pipes.length == 0
		puts ''
		puts 'Nothing more to upsize!'
		puts ''
		k += iteration_limit
	else
		net.transaction_begin
		upsize_list = []
		selected_pipes.each do |pipe|
			oid = pipe['us_node_id']+'.'+pipe['link_suffix'].to_s
			upsize_list << oid
			net_pipe=net.row_object('_links',oid)
			net_pipe['conduit_width'] += 2 * 25.4
			net_pipe.write
		end
		net.transaction_commit
		sim.close

		validate_commit_close(net,report_validation,"Upsized #{upsize_list}")
		puts "Running Iteration ##{k}"
		rerun_simulation(runobject,sims,timeout)

	end

	k += 1
end

# ===========================================================================================
# Export proposed changes to CSV and shapefile of pipes with changes and results

#net=network.open
final_commit_id = network.current_commit_id
network.csv_changes(existing_commit_id, final_commit_id, cip_differences)
#net.close

puts 'Exporting proposed pipes'
sim=simobject.open
sim.odec_export_ex(
	'SHP',				# Data Format
	export_config_file,	# Field Mapping Configuration
	export_options,		# Additional options in Ruby Hash
	'Conduit',			# Parameter 1 - InfoWorks Layer to Import
	proposed_pipes		# Parameter 2 - Path to Shapefile
)
File.write(err_file, "\n End of Export \n", File.size(err_file))

t2=Time.now
puts
puts "This script has taken #{t2.round(2)-t.round(2)} seconds to complete."