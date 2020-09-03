/* 
	SQL Query Examples for ICM
	by Nathan Gerdts
	2020-09-03
*/

/* ------------------------------------------------
Query:			Add Scenarios
Object Type:	Any
Description:	Example to generate multiple scenarios via SQL
*/

ADD SCENARIO "Population Increase 5%";
ADD SCENARIO "Population Increase 10%";
ADD SCENARIO "Population Increase 15%";
ADD SCENARIO "Population Increase 20%";

/* ------------------------------------------------
Query:			Update Data in Scenarios
Object Type:	Subcatchment
Description:	Make edits on multiple scenarios in one script.
Note: 			This only works if scenarios are created before running the query.
*/

UPDATE SELECTED IN SCENARIO "Population Increase 5%" 
SET population = population * 1.05;
UPDATE SELECTED IN SCENARIO "Population Increase 10%" 
SET population = population * 1.1;
UPDATE SELECTED IN SCENARIO "Population Increase 15%" 
SET population = population * 1.15;
UPDATE SELECTED IN SCENARIO "Population Increase 20%" 
SET population = population * 1.2;

/* ------------------------------------------------
Query:			Delete Scenarios
Object Type:	Any
Description:	Example to delete multiple scenarios via SQL
*/

DROP SCENARIO "Population Increase 5%";
DROP SCENARIO "Population Increase 10%";
DROP SCENARIO "Population Increase 15%";
DROP SCENARIO "Population Increase 20%";

/* ------------------------------------------------
Query:			Add Scenarios
Object Type:	All Links
Description:	Example Query to select and pull changes from a scenario to the base scenario.
*/

UPDATE IN SCENARIO 'Insert Scenario Name' // input scenario
  SET $x = conduit_width;
SELECT WHERE conduit_width <> $x and $x IS NOT NULL;

// Optional - apply differences from scenario to Base:
UPDATE SELECTED SET conduit_width = $x;
//UPDATE SELECTED SET conduit_width_flag = 'INF';

/* ------------------------------------------------
Query:			Select Contributing Subcatchments
Object Type:	Any
Description:	Select subcatchments that drain to selected nodes
*/

UPDATE SELECTED [All nodes] SET $selected = 1;
SELECT from Subcatchment WHERE node.$selected = 1;
/* Or to select connected links: */
//SELECT WHERE ds_node.$selected = 1 or us_node.$selected=1;

/* ------------------------------------------------
Query:			Trace Upstream from Selected Node(s)
Object Type:	All Nodes
Description:	Iterative trace upstream for user-defined number of iterations
*/

LET $iterations = 10; // Input the number of iterations to trace upstream.

UPDATE [ALL Links] SET $link_selected = 0;
UPDATE [All Nodes] SET $node_selected = 0;
UPDATE SELECTED SET $node_selected = 1;

LET $count = 0;
WHILE $count < 12;
   SET us_links.$link_selected = 1 WHERE $node_selected = 1;
   UPDATE [ALL Links] SET us_node.$node_selected = 1 WHERE $link_selected = 1;
   LET $count = $count + 1;
WEND;

SELECT WHERE $node_selected =1;
SELECT FROM [ALL LINKS] WHERE $link_selected = 1

/* ------------------------------------------------
Query:			User Prompt Example
Object Type:	All Links
Description:	Example for setting up a user prompt window in SQL
*/

LIST $zz STRING;
SELECT DISTINCT (us_node_id+"."+link_suffix) INTO $zz WHERE link_type = "FIXPMP";

PROMPT TITLE 'Add Some Title Here';
PROMPT LINE $a 'Enter a Number Here to be used later in the SQL';
PROMPT LINE $b 'Enter a String Here to be used later in the SQL' STRING;
PROMPT LINE $c 'Enter a Date Here to be used later in the SQL' DATE;
PROMPT LINE $d 'Enter a MONTH Here to be used later in the SQL' MONTH;
PROMPT LINE $e 'Enter a Tick Box Here to be used later in the SQL' BOOLEAN;
PROMPT LINE $f 'Allow the user to enter a folder directory' STRING FOLDER;
PROMPT LINE $g 'Allow the user to select a Number Based on a predefined Range (In this case 1-5)' RANGE 1 5;
PROMPT LINE $h 'Select Model Objects Based off of a defined LIST' LIST $zz;

PROMPT DISPLAY

/* ------------------------------------------------
Query:			Pipe Roughness Lookup
Object Type:	All Links
Description:	Example for global roughnes lookup values
*/

SET bottom_roughness_N = 0.015 WHERE conduit_material = 'BRICK';
SET bottom_roughness_N = 0.013 WHERE conduit_material = 'CIP';
SET bottom_roughness_N = 0.012 WHERE conduit_material = 'CIPP';
SET bottom_roughness_N = 0.025 WHERE conduit_material = 'CMP';
SET bottom_roughness_N = 0.013 WHERE conduit_material = 'CON';
SET bottom_roughness_N = 0.012 WHERE conduit_material = 'DIP';
SET bottom_roughness_N = 0.012 WHERE conduit_material = 'FRP';
SET bottom_roughness_N = 0.014 WHERE conduit_material = 'NCP';
SET bottom_roughness_N = 0.014 WHERE conduit_material = 'PCP';
SET bottom_roughness_N = 0.012 WHERE conduit_material = 'PVC';
SET bottom_roughness_N = 0.014 WHERE conduit_material = 'RCP';
SET bottom_roughness_N = 0.013 WHERE conduit_material = 'VCP';
SET top_roughness_N = bottom_roughness_N;

/* ------------------------------------------------
Query:			Network Travel Time Tracer
Object Type:	All Nodes
Description:	Trace upstream specified number of segments from selected node(s)
Travel time through each link is aproximated using the average velocity over a user-defined time window.
Required Fields: User Numbers 4-6 for Links, and User Number 5 for Nodes and Subcatchments
Instructions:	Open editable network, then drag simulation results on top so that query can use results and make edits at the same time.
*/

LET $n_hours = 16;    // Total number of hours in the simulation;
LET $iterations = 200;   // Number of iterations to trace upstream.
LET $min_speed = 0.01;    // Assumed minimum average travel velocity in pipes.

LET $start = 0;
LET $end = $n_hours ;

PROMPT TITLE "Define Parameters";
PROMPT LINE $iterations "Number of iterations upstream" DP 3;
PROMPT LINE $min_speed "Minimum assumed average velocity" DP 3;
PROMPT LINE $start "Start hour (0-24)" DP 3;
PROMPT LINE $end "End hour (0-24)" DP 3;
PROMPT DISPLAY;

UPDATE [All Links] SET $left = $start*MAX(tsr.timesteps)/$n_hours,
					$right = $end*MAX(tsr.timesteps)/$n_hours;
UPDATE [All Links] SET $speed = AVG(IIF((tsr.timestep_no > $left) AND (tsr.timestep_no < $right),tsr.us_vel,NULL));
UPDATE [All Links] SET $speed = $min_speed WHERE $speed<$min_speed;
UPDATE [All Links] SET $travel_time = IIF(conduit_length IS NOT NULL,conduit_length,1) / $speed / 60,
					$link_selected = 0,
					user_number_4 = '',
					user_number_5 = '',
					user_number_6 = $speed;
UPDATE [All Nodes] SET $node_selected = 0,
					user_number_5 = '';
UPDATE SELECTED SET ds_links.user_number_5 = 0,
					$node_selected = 1;

LET $count = 0;
WHILE $count < $iterations;
	UPDATE [All Nodes] SET user_number_5 = MIN(ds_links.user_number_5)   // Assume water prefers shortest path
		WHERE $node_selected = 1;
	UPDATE [All Nodes] SET us_links.$link_selected = 1,
		$node_selected = 0                             // Clear tracks as we work
		WHERE $node_selected = 1;
	UPDATE [ALL Links] SET us_node.$node_selected = 1,
		user_number_4 = ds_node.user_number_5,
		user_number_5 = ds_node.user_number_5 + $travel_time,
		$link_selected = 0
		WHERE $link_selected = 1;
   LET $count = $count + 1;
WEND;

UPDATE Subcatchment SET user_number_5 = node.user_number_5;

SELECT FROM Subcatchment WHERE user_number_5 > 0;
SELECT SELECTED subcatchment_id AS [Subcatchment], 
    sim.max_qcatch AS [Peak Flow],
    user_number_5 AS [Travel Time (minutes)]
    FROM Subcatchment 

/* ------------------------------------------------
Query:			Check for Unique Asset ID
Object Type:	All Links
Description:	Find duplicate Asset ID's
*/

SELECT link_type,  COUNT(*) GROUP BY asset_id ORDER BY Count(*) DESC

/* ------------------------------------------------
Query:			Find Subcatchments with broken node mapping
Object Type:	All Nodes
Description:	Select and flag subcatchments that don't have a cooresponding node to drain to. 
*/

LET $flag = 'INF'; // Define the flag to assign to node_id field for broken connections.

SET subcatchments.$temp = 1;
SELECT FROM subcatchment WHERE $temp <> 1;
UPDATE SELECTED subcatchment SET node_id_flag=$flag;

/* ------------------------------------------------
Query:			Select and Update nodes downstream of pumps
Object Type:	All Nodes
Description:	Select all nodes immediately downstream of Pump links.
				Update the node flood_type to 'Sealed'
*/

CLEAR SELECTION;
LIST $pumptypes = 'fixpmp','rotpmp','scrpmp','vsppmp','vfdpmp';
SELECT WHERE MEMBER(us_links.link_type,$pumptypes);
UPDATE SELECTED SET flood_type = 'Sealed';
UPDATE SELECTED SET flood_type_flag = 'TM';

/* ------------------------------------------------
Query:			Select Objects with TVD Connectors
Object Type:	TVD Connector
Description:	Select links and nodes with tvd connector assigned to them
*/

LIST $sensors STRING;
SELECT DISTINCT connected_object_id INTO $sensors;

SELECT FROM [all links] WHERE MEMBER(oid,$sensors);
SELECT FROM [all nodes] WHERE MEMBER(node_id,$sensors);

/* ------------------------------------------------
Query:			Report pipes with crown/soffit above ground
Object Type:	Conduit
Description:	Select and report table on pipes with US or DS crown/soffit above node ground level
*/

CLEAR SELECTION;
SELECT WHERE us_invert + conduit_height/12 > us_node.ground_level;

SELECT SELECTED OID AS [Pipes with Upstream Problem],
  conduit_height AS [Conduit Height],
  us_invert AS [Upstream Invert],
  us_node.ground_level AS [Upstream Ground level];

CLEAR SELECTION;
SELECT WHERE ds_invert + conduit_height/12 > ds_node.ground_level;

SELECT SELECTED OID AS [Pipes with Downstream Problem],
  conduit_height AS [Conduit Height],
  ds_invert AS [Downstream Invert],
  ds_node.ground_level AS [Downstream Ground Level];

// Add back upstream problem pipes to selection
SELECT WHERE us_invert + conduit_height/12 > us_node.ground_level;

/* ------------------------------------------------
Query:			River Reach Parameter Assignment
Object Type:	River Reach
Description:	Prompt-based Query to update array parameters across selected river reaches. 
				Note this applies the same constant parameter at all stations of each section.
*/

LET $n =0.03;
LET $A =0.8;
LET $B =0.8;
LET $C =0.9;
LET $D =0.9;
PROMPT TITLE "River Reach Parameters";
PROMPT LINE $n "Manning's n value" DP 3;
PROMPT LINE $A "Left Bank Discharge Coefficient" DP 3;
PROMPT LINE $B "Right Bank Discharge Coefficient" DP 3;
PROMPT LINE $C "Left Bank Modular Limit" DP 3;
PROMPT LINE $D "Right Bank Modular Limit" DP 3;
PROMPT DISPLAY;

//Comment out any of the below assignment lines that are not desired:
SET sections.roughness_N=$n;
SET left_bank.discharge_coeff=$A;
SET right_bank.discharge_coeff=$B;
SET left_bank.modular_ratio=$C;
SET right_bank.modular_ratio=$D;


/* ------------------------------------------------
Query:			Generate Dual Drainage Overland Links
Object Type:	Conduit
Description:	Example to auto-create prescribed overland channels above selected below-ground stormwater pipes.
*/

/* Initialize Variables */
LET $up_id = 'string';
LET $dn_id = 'string';
LET $up_elev = 0;
LET $dn_elev = 0;

/* Define Overland Conduit Shape */
LET $shape = 'OREC'; // simple built in option
LET $width = 500; //example in inches
LET $height = 10;

/* Iterate through selected storm pipe locations */
LIST $dual_drain_locations STRING;
SELECT SELECTED DISTINCT oid INTO $dual_drain_locations;
LET $i = 1;
WHILE $i <=LEN($dual_drain_locations);
	CLEAR SELECTION;
	SELECT WHERE oid = AREF($i,$dual_drain_locations);
	SELECT SELECTED us_node_id INTO $up_id;
	SELECT SELECTED ds_node_id INTO $dn_id;
	SELECT SELECTED us_node.ground_level INTO $up_elev;
	SELECT SELECTED ds_node.ground_level INTO $dn_elev;

	// Create overland channel
	INSERT INTO [Conduit] (
		link_suffix,
		us_node_id,
		ds_node_id, 
		us_invert, 
		ds_invert,
		system_type,
		shape,
		conduit_width,
		conduit_height
	) VALUES (
		9,
		$up_id,
		$dn_id,
		$up_elev,
		$dn_elev,
		'Overland',
		$shape,
		$width,
		$height
	);
	
	// Update attached nodes to use Inlet equation to transfer flow
	UPDATE SELECTED SET us_node.flood_type = 'Inlet',
		ds_node.flood_type = 'Inlet',
		us_node.inlet_type = 'ContCO',
		ds_node.inlet_type = 'ContCO';
		// ... and set other desired inlet parameters...

	LET $i=$i+1;
WEND;

/* ------------------------------------------------
Query:			Reroute Subcatchments to 2D Point Sources
Object Type:	All Nodes
Description:	New feature in version 11.0 allows subcatchments to drain to 2D points.  This script finds where subcatchments drain to underground nodes and instead re-directs flow to the surface by creating 2D inflow points. The purpose is to allow the 2D inlet to constrain inflow to the underground system.
*/

CLEAR SELECTION;
LIST $2d_nodes = '2D', 'Inlet 2D';
SELECT WHERE MEMBER(flood_type,$2d_nodes) AND COUNT(subcatchments.*) > 0;

LIST $inlet_nodes STRING;
SELECT SELECTED DISTINCT node_id INTO $inlet_nodes;

LET $x = 1;
LET $y = 1;
LET $i = 1;

WHILE $i <= LEN($inlet_nodes);
	CLEAR SELECTION;
	// Iterate at each node location
	SELECT FROM [All Nodes] WHERE node_id = AREF($i,$inlet_nodes);
	SELECT SELECTED x INTO $x;
	SELECT SELECTED y INTO $y;
	
	// Create 2D point source on top of node
	INSERT INTO [2D point source] (
		point_id, 
		x,
		y
	) 
	VALUES (
		AREF($i,$inlet_nodes),
		$x,
		$y
	);
	
	// Redirect Subcatchment to point source
	UPDATE [Subcatchment] SET drains_to ='2D point source' WHERE node_id = AREF($i,$inlet_nodes);
	UPDATE [Subcatchment] SET [2d_pt_id] = AREF($i,$inlet_nodes) WHERE node_id = AREF($i,$inlet_nodes);
		
	LET $i = $i+1;
WEND;

/* ------------------------------------------------
Query:			Subcatchments - Assign Lag Time by distance
Object Type:	Subcatchment
Description:	Applies an Output Lag for subcatchment flow to network based on the travel distance between the subcatchment centroid to its node. 
*/

// Calculate distance.
SET $distance = ((x-node.x)^2 + (y-node.y)^2 )^0.5;
// SET user_number_1 = $distance // optional for review

LET $travel_speed = 4; // Assume average 4 ft/s travel speed
SET output_lag = $distance  / $travel_speed / 60;



/* ------------------------------------------------
Query:			Generic report using Group BY
Object Type:	Subcatchment
Description:	Summarize subcatchment inflows by system type 
*/

SELECT SUM(population) DP 0 AS "Population", COUNT(trade_flow) AS "Number of Subs with a Trade Flow", SUM(base_flow) DP 4 AS "Total Base Flow (m3/s)" GROUP BY system_type

/* ------------------------------------------------
Query:			Report Flow volumes to outfalls
Object Type:	All Links
Description:	
*/

CLEAR SELECTION;
SELECT WHERE ds_node.node_type = 'Outfall';
SELECT SELECTED asset_id,  ds_node.node_id,  ds_invert, sim.ds_qcum ORDER BY ds_invert DESC

/* ------------------------------------------------
Query:			Summarize Result over Time Window
Object Type:	All Links
Description:	Example script to summarize flows at selected links during a desired time window of the simulation.
This script is based on hours as a unit of selection. Decimal hours are allowed. 
The script can be adapted to minutes, days, or seconds as well. 
*/

LET $n_hours = 24; // Input the total number of hours in the simulation;

LET $start = 0;
LET $end = $n_hours ;
PROMPT TITLE "Define Window For Aggregation";
PROMPT LINE $start "Start hour (0-24)" DP 3;
PROMPT LINE $end "End hour (0-24)" DP 3;
PROMPT DISPLAY;
SET $left = $start*MAX(tsr.timesteps)/$n_hours;
SET $right = $end*MAX(tsr.timesteps)/$n_hours;
SELECT OID, MIN(IIF((tsr.timestep_no > $left) AND (tsr.timestep_no < $right),tsr.ds_flow,NULL)) as Minimum, 
MAX(IIF((tsr.timestep_no > $left) AND (tsr.timestep_no < $right),tsr.ds_flow,NULL)) as Maximum, 
AVG(IIF((tsr.timestep_no > $left) AND (tsr.timestep_no < $right),tsr.ds_flow,NULL)) as Average,
INTEGRAL(IIF((tsr.timestep_no > $left) AND (tsr.timestep_no < $right),tsr.ds_flow,NULL)) as Integral; //Note this requires a conversion factor depending on desired units. Integral returns the sum of input by the timestep in minutes.

/* ------------------------------------------------
Query:			Route Subcatchments to lowest node within X Distance
Object Type:	All Nodes
Description:	Query to assign Subcatchment drainage to the lowest elevation node within 500 feet of the centroid.
Adjust the distance as needed.
Script reassigns subcatchments with node_id missing or equal to zero.

Search Type = 	Distance
Distance = 		500
Layer Type = 	Network Layer
Layer = 		Subcatchment
*/

CLEAR SELECTION;
LIST $subs STRING;
LET $low_invert = 3; //initialize number
LET $drain_node = 'x'; //initialize string
SELECT DISTINCT subcatchment_id INTO $subs FROM [Subcatchment] 
	WHERE node_id = '0' OR node_id = '';
LET $i = 1;
WHILE $i <= LEN($subs);
	CLEAR SELECTION;
	SELECT WHERE spatial.subcatchment_id  = AREF($i,$subs) AND node_type <> 'Outfall';
	SELECT SELECTED MIN(chamber_floor) INTO $low_invert;
	SELECT SELECTED node_id INTO $drain_node WHERE chamber_floor = $low_invert;
	NVL($drain_node,'0');
	UPDATE [Subcatchment] SET node_id = $drain_node,
		node_id_flag = 'INF' WHERE subcatchment_id  = AREF($i,$subs);
	LET $i = $i+1;
WEND;
SELECT FROM [Subcatchment] WHERE node_id_flag = 'INF';



/* ------------------------------------------------
Query:			Buildings - Assign Height above ground
Object Type:	Mesh Zone
Description:	Assign Mesh zones as buildings with flat roof heights to be 20 feet above the ground - which is assumed based on the nearest node ground level

Search Type = 	Nearest
Distance = 		200
Layer Type = 	Network Layer
Layer = 		All Nodes
*/
UPDATE SELECTED SET ground_level_mod = 'Level', 
         level = spatial.ground_level + 20;

