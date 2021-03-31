t=Time.now
database='snumbat://localhost:40000/Demo'
netid=9917
runid=10174
simid=10175

iteration_limit = 10	# Maximum number of iterations to modify and rerun model
timeout = 60*1000		# simulation timeout time in miliseconds if runs take too long. Currently 60 sec
report_validation = false

db=WSApplication.open database,false
network=db.model_object_from_type_and_id 'Model Network',netid
runobject=db.model_object_from_type_and_id 'Run',runid
WSApplication.connect_local_agent(1)
sims=Array.new
runobject.children.each do |c|
	sims<<c
end

k = 0
while k < iteration_limit
	puts "Starting loop ##{k} out of max #{iteration_limit}"
	simobject=db.model_object_from_type_and_id 'Sim',simid
	net=network.open
	sim=simobject.open

	# ===========================================================================================
	# Incrementally upsize the most downstream pipes with surcharge state = 2
	sim.run_SQL('hw_conduit','SELECT WHERE sim.max_surcharge = 2 AND MAX(sim.all_ds_links.max_Surcharge) < 2')
	selected_pipes=sim.row_objects_selection('hw_conduit')
	if selected_pipes.length == 0
		puts 'Nothing more to upsize'
		k = iteration_limit
	else
		net.transaction_begin
		upsize_list = []
		selected_pipes.each do |pipe|
			oid = pipe['us_node_id']+'.'+pipe['link_suffix'].to_s
			upsize_list << oid
			net_pipe=net.row_object('_links',oid)
			net_pipe['conduit_width'] += 1 * 25.4
			net_pipe.write
		end
		net.transaction_commit
	end

	# ===========================================================================================
	# Validate and Commit changes
	valres=net.validate('Base')
	if report_validation
		puts "errors #{valres.error_count} warnings #{valres.warning_count}"
		valres.each do |v|
			puts "#{v.code},#{v.field},#{v.field_description},#{v.object_id},#{v.code},#{v.object_type},#{v.message},#{v.priority},#{v.scenario},#{v.type}"
		end
	end
	net.commit "Upsized #{upsize_list}"
	net.close
	sim.close


	# ===========================================================================================
	# Run updated simulation
	if k < iteration_limit
		puts "Running Iteration ##{k}"
		runobject.update_to_latest
		handles=WSApplication.launch_sims(sims,'.',false,0,0)
		index=WSApplication.wait_for_jobs handles,true,timeout
	end
	
	k += 1
end

t2=Time.now
puts
puts "This script has taken #{t2.round(2)-t.round(2)} seconds to complete."