require 'win32ole'
require 'date'
t=Time.now

##Cmd Line Arguments! Need to update Batch File with the following arguments to be called in the script
if ARGV.size<=1
	puts "Error Processing Batch File. Additional parameters (after '/ICM') must be:"
	puts "	>	The File Directory Location of the blank Excel Report"
	puts
	puts "Please enter this information into the .BAT file and try again"
else
	@excelreport=ARGV[1]
	database='snumbat://localhost:40000/Demo'
	modelnetworkid=2802
	runid=3321
	rainfall=2969
	designpump='SS43393605.1'
	overflowobj='SS43393607.2'

	scenarios=Array.new

	puts
	puts '................................'
	puts 'Initialising Script...'

	##open network file
	db=WSApplication.open database,false

	puts
#======================================================================================================#
	puts '................................'
	puts 'Developing Scenarios...'

	orig_net=db.model_object_from_type_and_id 'Model Network',modelnetworkid
	new_net=orig_net.branch(orig_net.latest_commit_id,'Pump Optioneering')

	modgid=orig_net.parent_id
	mo=db.model_object_from_type_and_id 'Model Group',modgid
	
	net=new_net.open
	##Create Scenarios to increase Assist Pump by 1 l/s - until
	pmp=net.row_object('_links',designpump)

	i=1
	while i<50
		scenario = "Scenario_" + (0.07+i.to_f/1000).round(3).to_s + " m3/s pump discharge."

		net.add_scenario(scenario,nil,'') 
		net.current_scenario=scenario
		net.clear_selection
		
		net.transaction_begin 
			pmp['discharge'] += (i.to_f/1000)
			pmp.write
			net.transaction_commit 
		i+=1
		v=net.validate(scenario)
		scenarios<<scenario
	end

	##Validate scenario and commit:
	net.commit "Optioneering Script ran. Pump Discharge Testing at #{designpump} undertaken."
	net.close

	puts
#======================================================================================================#
	puts '................................'
	puts 'Setting up Simulation...'

	rundefault=db.model_object_from_type_and_id 'Run',runid
	runparams=Hash.new
	db.list_read_write_run_fields.each do |p|
		runparams[p]=rundefault[p]
	end

	puts
	puts '................................'
	puts 'Running Simulations...'
	
	run=mo.new_run('Optioneering_Runs',new_net.id,nil,rainfall,scenarios,runparams)
	WSApplication.connect_local_agent(1)

	sims=Array.new
	run.children.each do |c|
		sims<<c
	end

	handles=WSApplication.launch_sims(sims,'.',false,0,0)
	index=WSApplication.wait_for_jobs handles,true,160000

	puts
#======================================================================================================#
	puts '................................'
	puts 'Simluations Complete. Interrogating Results...'
	spillres=Array.new


	run.children.each do |c|
		puts c.name
		net=c.open
		ro = net.row_object('hw_weir',overflowobj)
		spill = ro.results('us_flow').max
		spillres<<[c.name,spill]
		net.close
	end
	spillres.sort_by!{|x| x[0]}

	puts
	puts '................................'
	puts 'Generating Report...'
	puts

	finish=Array.new
	lowestQrate=Array.new

	spillres.each do |abc|
		scenarioname=abc[0]
		if abc[1] < 0.001 && !finish.include?("finish")
			puts "Scenario: '#{scenarioname[0...-12]}' has a max flow of #{abc[1].round(4)} m3/s over the weir."	
			puts "This scenario has the lowest discharge before the weir stops spilling."
			finish<<"finish"
			lowestQrate<<abc[0]
		elsif abc[1] < 0.001 && finish.include?("finish")
			puts
		else
			puts "Scenario: '#{scenarioname[0...-12]}' has a max flow of #{abc[1].round(4)} m3/s over the weir."	
		end
	end

#======================================================================================================#
	puts "Creating Excel Graphical Output..."
	lowestQrate=lowestQrate.to_s

	##Creates Excel Output
	excel = WIN32OLE::new('excel.Application')
	workbook = excel.Workbooks.Open(@excelreport)
	worksheet = workbook.Worksheets(1)

	spillres.each do |abc|
		scenarioname=abc[0]
		scenarioname=scenarioname[9...19]

		indexpos=spillres.index(abc)
		worksheet.Cells(1,indexpos+1).value = [scenarioname]
		worksheet.Cells(2,indexpos+1).value = [abc[1]]
		
	end
	range = worksheet.Range(worksheet.Cells(1,1),worksheet.Cells(2,spillres.length))
	range.select
	chart = workbook.Charts.Add
	series = chart.SeriesCollection(1).Name = "Additional Pump Rate Increase (m3/s)"
	chart.HasTitle = true
	chart.ChartTitle.Text = "A Minimum Increase In The Downstream Pump Rate Of #{lowestQrate[11...21]} Is Required To Prevent Spills At The Weir"

	workbook.saved = true

	##Closes Excel
	excel.ActiveWorkbook.Close(0)
	excel.Quit()

	t2=Time.now
	puts
	puts "This script has taken #{t2.round(2)-t.round(2)} seconds to complete."
	puts "Process Completed. Please View Excel Spreadsheet."

	workbook = excel.Workbooks.Open(@excelreport)
	excel.visible = true
end
