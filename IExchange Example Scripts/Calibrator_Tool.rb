require 'win32ole'  # for Excel report generation
require 'date'      # for runtime reporting
require 'FileUtils' # for relative working path
t=Time.now

@excelreport=Dir.pwd+'\!Output Files\Calibration_Comparison.xlsx'
database='snumbat://localhost:40000/Demo'
modelnetworkid=3787
#	runid=4323
	runid=3971
rainfall=3970
meter_location='a.1'
sensor_file = Dir.pwd+'\Data\FlowMeter_12430.txt'
branch_network = 'Sensitivity Analysis'
run_name = 'Sensitivity_Analysis_Runs'
flow_units = 'MGD'

param=Hash.new
#	param['p_area_1'] =               {'name'=>'p1', 'table'=>'hw_land_use',            'id'=>'12430', 'Range'=>[0.3,1,2]}
	param['p_area_2'] =               {'name'=>'p2', 'table'=>'hw_land_use',            'id'=>'12430', 'Range'=>[30,40,3]} # - 35
	param['runoff_routing_value'] =   {'name'=>'rv', 'table'=>'hw_runoff_surface',      'id'=>'2',     'Range'=>[25,55,3]} # - 50
	param['percolation_coefficient'] ={'name'=>'pc', 'table'=>'hw_ground_infiltration', 'id'=>'12430', 'Range'=>[1,3,3]} # - 4
#	param['percolation_threshold'] =  {'name'=>'pt', 'table'=>'hw_ground_infiltration', 'id'=>'12430', 'Range'=>[10,20,3]} # - 10
#	param['percolation_percentage'] = {'name'=>'pp', 'table'=>'hw_ground_infiltration', 'id'=>'12430', 'Range'=>[20,70,3]} # - 20
#	param['baseflow_coefficient'] =   {'name'=>'bc', 'table'=>'hw_ground_infiltration', 'id'=>'12430', 'Range'=>[30,50,2]} # - 40
#	param['infiltration_coefficient']={'name'=>'ic', 'table'=>'hw_ground_infiltration', 'id'=>'12430', 'Range'=>[10,20,2]} # -15
var = param.keys

def list_values(range_array)
	dx = (range_array[1]-range_array[0])/(range_array[2]-1.00)
	return Array.new(range_array[2]) {|i| i*dx+range_array[0]}
end
def create_scenario(param,var,vars,net)
	scenario = ''
	for i in 0..var.length-1
		scenario << param[var[i]]['name'] + "=" + vars[i].to_s + "_"
	end
	net.add_scenario(scenario,nil,'') 
	net.current_scenario=scenario
	net.transaction_begin
	for i in 0..var.length-1
		row_obj = net.row_object(param[var[i]]['table'],param[var[i]]['id'])
		row_obj[var[i]] = vars[i]
		row_obj.write
	end
	net.transaction_commit
	v=net.validate(scenario)
	return [scenario, vars]
end
def get_base_param(param ,net)
	net.current_scenario='Base'
	base_param = Array.new
	param.each do |key, value|
		row_obj = net.row_object(param[key]['table'],param[key]['id'])
		base_param << row_obj[key]
	end
	return base_param
end
def unit_conversion_lookup(unit)
  flow_unit_lookup = {
    "MGD" => 22.824465,
    "CFS" => 35.3147,
    "gpm" => 15850.37,
    "L/s" => 1000
  }
  if flow_unit_lookup.key?(unit)
    return flow_unit_lookup[unit]
  end
  return nil
end

puts
#======================================================================================================#
puts '................................'
puts 'Developing Scenarios...'

##open network file
db=WSApplication.open database,false

orig_net=db.model_object_from_type_and_id 'Model Network',modelnetworkid
modgid=orig_net.parent_id
modg=db.model_object_from_type_and_id 'Model Group',modgid

orig_net.children.each do |c|
	if c.name == branch_network # Found old Sensitivity Analysis to clean up
		puts "Cleaning up old #{c.name} branch"
		c.bulk_delete
		old_run = db.model_object(modg.path+'>RUN~'+run_name)
		if !old_run.nil?
			puts "Cleaning up old run: #{old_run.name}"
			old_run.bulk_delete
		end
	end
end

new_net=orig_net.branch(orig_net.latest_commit_id,branch_network)
net=new_net.open

scenarios=Hash.new
var1 = list_values(param[var[0]]['Range'])
var1.each do | v1 |
	if var.length >= 2
		var2 = list_values(param[var[1]]['Range'])
		var2.each do | v2 |
			if var.length >= 3
				var3 = list_values(param[var[2]]['Range'])
				var3.each do | v3 |
					if var.length >= 4
						var4 = list_values(param[var[3]]['Range'])
						var4.each do | v4 |
							if var.length >= 5
								var5 = list_values(param[var[4]]['Range'])
								var5.each do | v5 |
									if var.length >= 6
										var6 = list_values(param[var[5]]['Range'])
										var6.each do | v6 |
											if var.length >= 7
												var7 = list_values(param[var[6]]['Range'])
												var7.each do | v7 |
													if var.length >= 8
														var8 = list_values(param[var[7]]['Range'])
														var8.each do | v8 |
															out = create_scenario(param,var,[v1,v2,v3,v4,v5,v6,v7,v8],net)
															scenarios[out[0]] = out[1]
														end
													else
														out = create_scenario(param,var,[v1,v2,v3,v4,v5,v6,v7],net)
														scenarios[out[0]] = out[1]
													end
												end
											else
												out = create_scenario(param,var,[v1,v2,v3,v4,v5,v6],net)
												scenarios[out[0]] = out[1]
											end
										end
									else
										out = create_scenario(param,var,[v1,v2,v3,v4,v5],net)
										scenarios[out[0]] = out[1]
									end
								end
							else
								out = create_scenario(param,var,[v1,v2,v3,v4],net)
								scenarios[out[0]] = out[1]
							end
						end
					else
						out = create_scenario(param,var,[v1,v2,v3],net)
						scenarios[out[0]] = out[1]
					end
				end
			else
				out = create_scenario(param,var,[v1,v2],net)
				scenarios[out[0]] = out[1]
			end
		end
	else
		out = create_scenario(param,var,[v1],net)
		scenarios[out[0]] = out[1]
	end
end
scenarios['Base'] = get_base_param(param ,net)

##Validate scenario and commit:
net.commit "Sensitivity Analysis Script: test run a range of variable combinations for key parameters"
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

run=modg.new_run(run_name,new_net.id,nil,rainfall,scenarios.keys,runparams)
WSApplication.connect_local_agent(1)

sims=Array.new
run.children.each do |c|
	sims<<c
end

timeout = 12*60*60*1000 # timeout time in miliseconds if runs take too long. Currently 12 hrs
handles=WSApplication.launch_sims(sims,'.',false,0,0)
index=WSApplication.wait_for_jobs handles,true,timeout

puts
#======================================================================================================#
puts '................................'
puts 'Simluations Complete. Interrogating Results...'

results_array=Array.new

sensor_data = IO.readlines(sensor_file)
unit_factor=unit_conversion_lookup(flow_units)
use_index = Array.new
sensor = Array.new
n=0
n_used=0
sensor_variance=0.0

run.children.each do |c|
	net=c.open
	if n==0 # only calculate first time
		n = net.timestep_count
		sensor_data = sensor_data.slice(0,n)
		sensor_data.each_index do |i|
			sensor << sensor_data[i].to_f
			if !sensor_data[i].strip.empty?
				use_index << i
			end
		end
		n_used = use_index.length
		sensor_avg = sensor.sum(0.0)/n_used
		use_index.each {|i| sensor_variance += (sensor[i]-sensor_avg)**2}
	end
	ro = net.row_object('hw_conduit',meter_location)
	results = ro.results('ds_flow')
	squared_difference = 0.0
	use_index.each {|i| squared_difference += (results[i]*unit_factor-sensor[i])**2}
	root_mean_squared_error = (squared_difference/n_used)**0.5
	nash_sutcliffe_efficiency = 1 - squared_difference/sensor_variance
	results_array << {'scenario' => net.current_scenario, 'rmse' => root_mean_squared_error, 'nse' => nash_sutcliffe_efficiency}
	net.close	
end

puts "Out of #{results_array.length} scenarios run..."
base_rmse = results_array.detect {|f| f['scenario']=='Base'}
results_array.delete_if {|h| h['rmse'] > base_rmse['rmse']}
results_array.replace results_array.sort_by {|h| h['rmse']}
puts "The following #{results_array.length} scenarios had lower RMSE to measurements than the base:"
results_array.each do |h|
	puts "Scenario #{h['scenario']} RMSE = #{h['rmse']},  NSE = #{h['nse']}"
end

#======================================================================================================#
puts "Creating Excel Graphical Output..."

##Creates Excel Output
excel = WIN32OLE::new('excel.Application')
workbook = excel.Workbooks.Open(@excelreport)
worksheet = workbook.Worksheets(1)
worksheet.Cells(1,1).value = 'Scenario'
worksheet.Cells(1,2).value = 'RMSE'
worksheet.Cells(1,3).value = 'NSE'
for k in 0..var.length-1
	worksheet.Cells(1,k+4).value = var[k]
end
j=2
puts "the troublesome loop:"
results_array.each do |h|
	worksheet.Cells(j,1).value = h['scenario']
	worksheet.Cells(j,2).value = h['rmse']
	worksheet.Cells(j,3).value = h['nse']
	for k in 0..var.length-1
		puts "#{h['scenario']},#{k}, #{scenarios[h['scenario']]}"
		worksheet.Cells(j,k+4).value = scenarios[h['scenario']][k]
	end
	j+=1
end
range = worksheet.Range(worksheet.Cells(2,1),worksheet.Cells(results_array.length+1,2)) # first two columns for chart
range.select
chart = workbook.Charts.Add
series = chart.SeriesCollection(1).Name = "RMSE"
chart.HasTitle = true
chart.ChartTitle.Text = "Lowest RMSE: #{results_array[0]['scenario']}"

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
