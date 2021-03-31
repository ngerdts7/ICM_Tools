/* 
Water Talk - SQL Query Tips and Tricks
January 5, 2021

SQL's written by Nathan Gerdts
*/

/* ------------------------------------------------------------
SQL Commands used in PowerPoint File
--------------------------------------------------------------- */
/* Slide 7 */
SELECT WHERE conduit_width > 24;

SELECT conduit_width WHERE conduit_width > 24;

SELECT oid, conduit_width, conduit_length ORDER BY conduit_width DESC

SELECT oid AS [Pipe ID], 
	conduit_width AS [Diameter], 
	conduit_length AS [Length] 
	ORDER BY conduit_width DESC

SELECT SUM(conduit_length) GROUP BY conduit_width

LIST $bins= 0,0.3,0.5,0.7,0.8,0.9,1,2;
SELECT COUNT(*) AS [Count] 
GROUP BY TITLE(RINDEX(sim.Surcharge,$bins),$bins) AS [Surcharge];

/* Slide 8 */
pipe_repairs.completed = TRUE AND pipe_repairs.closed = FALSE

SUM(COUNT(all_ds_links.*)) AS 'Count of DS Links’

SUM(COUNT(details.code)) AS 'Count of CC Defects' WHERE details.code = 'CC’ 

/* Slide 9 */
SET flood_type = 'Stored';

UPDATE SELECTED SET flood_type = 'Stored';

SELECT WHERE chamber_floor IS NULL OR chamber_floor = 0;
UPDATE SELECTED SET
	chamber_floor = MIN(ds_links.us_invert), 
	chamber_roof_flag = 'INF';
	
CLEAR SELECTION;
SELECT WHERE ds_links.solution_model = 'Pressure'
	OR ds_links.solution_model = 'Forcemain'; 
UPDATE SELECTED SET node_type = 'Break', 
	node_type_flag = 'NG';

/* Slide 10 */
UPDATE [All Nodes] SET subcatchments.$temp = 1;
SELECT FROM subcatchment WHERE $temp <> 1;
UPDATE SELECTED subcatchment SET node_id_flag='INF';

UPDATE [All Links] SET $speed = AVG(IIF((tsr.timestep_no > $left)
	AND (tsr.timestep_no < $right),tsr.us_vel,NULL));
UPDATE [All Links] SET $speed = $min_speed
	WHERE $speed<$min_speed;
UPDATE [All Links] SET $travel_time = 
	IIF(conduit_length IS NOT NULL,conduit_length,1) / $speed / 60;

/* Slide 11 */
DELETE SELECTED FROM Conduit
INSERT INTO [Table] (Fields...) VALUES (Values...)



/* ------------------------------------------------------------
SQL Query ICM Examples used in Presentation
--------------------------------------------------------------- */
/* 1 - Check for Unique Asset ID
	Object Type: All Links */
SELECT link_type,  COUNT(*) GROUP BY asset_id ORDER BY Count(*) DESC

/* 2 - Select disconnected Nodes
	Object Type: All Nodes */
CLEAR SELECTION;
SELECT WHERE COUNT(ds_links.*) = 0 
   AND COUNT(us_links.*) = 0;
	
/* 3 - Get nearest ground level for Mesh Zones
	Object Type: Mesh Zone
	Spatial Search: Nearest
	Layer: All Nodes
	Description: Assign Mesh zones as buildings with flat roof heights to be 20 feet above the ground
		- which is assumed based on the nearest node ground level */
UPDATE SELECTED SET ground_level_mod = 'Level', 
	level = spatial.ground_level + 20;

/* 4 - Route Subcatchments to lowest node within distance
	Object Type: All Nodes
	Spatial Search: Distance (e.g. 50)
	Layer: Subcatchment
	Description: Query to assign Subcatchment drainage to the lowest elevation node within 500 feet of the centroid.
		Adjust the distance as needed.
		Script reassigns subcatchments with node_id missing or equal to zero. */
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

/* 5 - Reroute subcatchments to 2D Point sources
	Object Type: All Nodes */
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

/* 6 - Generate Dual Drainage Overland Links
	Object Type: All Links */
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

/* 7 - Network Travel Time Tracer
	Object Type: All Nodes
	Description: Trace upstream specified number of segments from selected node(s)
	Travel time through each link is aproximated using the average velocity over a user-defined time window. */

LET $n_hours = 24;    // Total number of hours in the simulation;
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

/* 8 - Scenario Creation Loop
	Object Type: All Links */
LIST $Diam = 20,21,22,24,26,28,30;
LET $i = 1;
WHILE $i <LEN($Diam);
  LET $scene = 'Size ' + AREF($i,$Diam);
  ADD SCENARIO $scene;
  UPDATE SELECTED [All Links] IN SCENARIO $scene
     SET conduit_width = AREF($i,$Diam);
  LET $i = $i+1;
WEND;

/* 9 - Profile Designer
	Object Type: All Links
	DISCLAIMER: THIS SCRIPT IS FOR ILLUSTRATION PURPOSES ONLY. IT IS NOT A COMPLETE DESIGN TOOL AND IS NOT SUPPORTED BY INNOVYZE.
	User Number Fields Used:
	Nodes : user_number_5 : user specified drop between upstream and downstream pipes
	Links : user_number_5 : user specified minimum slope for each pipe
	Links : user_number_6 : user specified maximum slope for each pipe
*/

LET $smin = 0.5;		// minimum slope
LET $smax = 4.5;		// maximum slope
LET $init_cov = 7;		// minimum initial cover from rim to invert
LET $ideal_cov = 10;	// average desired cover from rim to invert
LET $mh_drop = 0.2;		// applied elevation drop across each manhole
LET $alignment = 0.8;	// d/D fraction for aligning EGL across varying diameter pipes (e.g. use 1 for aligning crown/soffit, use 0 for aligning invert)
LET $keep_connections = True;	// option to preserve inflow pipe elevations as max inverts.
LET $defaultDiam = 12;  // default pipe diameter
LET $flagnew = 'SQL';	// flag for elevation changes
LET $flagkeep = 'GIS';	// Any elevations with this flag will be preserved
LET $flaginit = 'NG';	// flag to keep initial guess but modify if needed

LIST $networkflags STRING;
SELECT DISTINCT flags.value INTO $networkflags;

PROMPT TITLE 'Pipe Profile Designer';
PROMPT LINE $smin 'minimum slope %';
PROMPT LINE $smax 'maximum slope %';
PROMPT LINE $init_cov 'minimum initial cover from rim to invert';
PROMPT LINE $ideal_cov 'average desired cover from rim to invert' RANGE 3 15;
PROMPT LINE $mh_drop 'applied elevation drop across each manhole';
PROMPT LINE $alignment 'd/D fraction for aligning EGL across varying diameter pipes';
PROMPT LINE $keep_connections 'option to preserve inflow pipe elevations as max inverts' BOOLEAN;
PROMPT LINE $defaultDiam 'Default pipe diameter if undefined';
PROMPT LINE $flagnew 'flag for elevation changes' LIST $networkflags;
PROMPT LINE $flagkeep 'Any elevations with this flag will be preserved' LIST $networkflags;
PROMPT LINE $flaginit 'flag to keep initial guess but modify if needed' LIST $networkflags;
PROMPT DISPLAY;

UPDATE SELECTED [All Links] SET conduit_width = $defaultDiam WHERE conduit_width IS NULL;

UPDATE SELECTED [ALL Links] SET $design = 1;
LIST $nodes STRING;
SELECT SELECTED DISTINCT node_id INTO $nodes;
LET $i = 1;
WHILE $i <= LEN($nodes);
	UPDATE [All Links] SET $downstream = 0; 
	SET all_ds_links.$downstream = 1 WHERE node_id = AREF($i,$nodes);
	SELECT SUM(conduit_length) INTO $dist FROM [All LInks] WHERE $design = 1 and $downstream = 1;
	SET $distance = $dist WHERE node_id = AREF($i,$nodes);
	LET $i = $i+1;
WEND;
SET $distance = 0 WHERE MEMBER(node_id, $nodes) AND $distance IS NULL;
SELECT MAX($distance) INTO $total_distnace;

IF $keep_connections;
	UPDATE SELECTED SET chamber_floor_flag = $flaginit WHERE COUNT(us_links.*)>1;
ENDIF;

UPDATE SELECTED SET $drop = $mh_drop + $alignment * (MAX(ds_links.conduit_width) - MAX(us_links.conduit_width))/12;
UPDATE SELECTED SET $drop = user_number_5 WHERE user_number_5 IS NOT NULL;
UPDATE SELECTED SET $drop = 0 WHERE $distance = $total_distnace; // no drop needed at top manhole
UPDATE SELECTED SET chamber_floor = ground_level - $init_cov - $drop 
	WHERE chamber_floor_flag <> $flagkeep AND chamber_floor_flag <> $flaginit;

/* Enforce minimum slope from top down */
LIST $x;
SELECT DISTINCT $distance INTO $x ORDER BY $distance DESC;
LET $i = 2;
SELECT chamber_floor INTO $z_prev WHERE $distance = AREF(1,$x);
WHILE $i <= LEN($x);
	SELECT chamber_floor INTO $z_curr WHERE $distance = AREF($i,$x);
	SELECT $drop INTO $local_drop WHERE $distance = AREF($i,$x);
	SELECT $chamber_floor_flag INTO $zflag WHERE $distance = AREF($i,$x);
	LET $slope = ($z_prev-$z_curr-$local_drop)/(AREF($i-1,$x)-AREF($i,$x));
	IF $slope < $smin/100 AND $zflag <> $flagkeep;
		LET $z_curr = $z_prev - $local_drop - $smin/100*(AREF($i-1,$x)-AREF($i,$x));
		SET chamber_floor = $z_curr WHERE $distance = AREF($i,$x);
	ENDIF;
	LET $z_prev = $z_curr;
	LET $i = $i+1;
WEND;

/* Enforce maximum slope from bottom up */
SELECT DISTINCT $distance INTO $x ORDER BY $distance ASC;
LET $i = 2;
SELECT chamber_floor INTO $z_prev WHERE $distance = AREF(1,$x);
WHILE $i <= LEN($x);
	SELECT chamber_floor INTO $z_curr WHERE $distance = AREF($i,$x);
	SELECT $drop INTO $local_drop WHERE $distance = AREF($i-1,$x);
	LET $slope = ($z_curr-$z_prev-$local_drop)/(AREF($i,$x)-AREF($i-1,$x));
	IF $slope > $smax/100;
		LET $z_curr = $z_prev + $local_drop + $smax/100*(AREF($i,$x)-AREF($i-1,$x));
		SET chamber_floor = $z_curr WHERE $distance = AREF($i,$x);
	ENDIF;
	LET $z_prev = $z_curr;
	LET $i = $i+1;
WEND;

SELECT SELECTED AVG(ground_level-chamber_floor) INTO $avg_cov;
IF $avg_cov < $ideal_cov;
	UPDATE SELECTED SET chamber_floor = chamber_floor - ($ideal_cov - $avg_cov);
ENDIF;

UPDATE SELECTED [All Links] SET us_invert = us_node.chamber_floor, 
	us_invert_flag = $flagnew
	WHERE us_invert_flag <> $flagkeep;
UPDATE SELECTED [All Links] SET ds_invert = ds_node.chamber_floor+ds_node.$drop, 
	ds_invert_flag = $flagnew
	WHERE ds_invert_flag <> $flagkeep;
UPDATE SELECTED SET chamber_floor = MIN(ds_links.us_invert),
	chamber_floor_flag = $flagnew 
	WHERE chamber_floor_flag <> $flagkeep; // fix in case pre-defined pipe inverts are below node

/* 10 - River Smoothing Tool
	Object Type: River reach */
/* Define min and max slope thresholds to be enforced */
LET $min_slope = 0.0005;
LET $max_slope = 0.05;
PROMPT TITLE "River Reach Slope Enforcement";
PROMPT LINE $min_slope "Minimum allowed slope" DP 5;
PROMPT LINE $max_slope "Maximum allowed slope" DP 3;
PROMPT DISPLAY;

/* Establish sequential river reach index list */
SET user_number_1 = '';
UPDATE SELECTED SET $temp = 1;
UPDATE SELECTED SET user_number_1 = 1+SUM(all_us_links.$temp);
UPDATE SELECTED SET user_number_1 = 1 WHERE user_number_1 is null;

/* Initialize Variables & Lists */
LIST $reach;
LIST $keys STRING;
LET $x_prev = 0;
LET $y_prev = 0;
LET $z_prev = 0;
LET $distance = 0;
LET $slope = 0;
LET $dz = 0;

SELECT SELECTED DISTINCT user_number_1 INTO $reach ORDER BY user_number_1;
LET $i = 1;
/* Iterate through each River Reach */
WHILE $i <= LEN($reach);
	LET $j = 1;
	DESELECT All;
	SELECT WHERE user_number_1 = AREF($i,$reach);
	SELECT SELECTED DISTINCT river_section.key INTO $keys;
	/* Iterate for each section */
	WHILE $j <= LEN($keys);
		SELECT AVG(sections.X) INTO $x_current WHERE sections.key = AREF($j,$keys) AND user_number_1 = AREF($i,$reach);
		SELECT AVG(sections.Y) INTO $y_current WHERE sections.key = AREF($j,$keys) AND user_number_1 = AREF($i,$reach);
		SELECT MIN(sections.Z) INTO $z_current WHERE sections.key = AREF($j,$keys) AND user_number_1 = AREF($i,$reach);
		IF $j > 1; /* not needed for first section of each reach since key matches last of previous reach */
			LET $distance = (($x_current - $x_prev)^2 + ($y_current - $y_prev)^2)^0.5;
			LET $slope = ($z_prev - $z_current)/$distance;
			IF $slope < $min_slope;
				LET $dz = $z_prev - $z_current - $min_slope * $distance;
			ELSEIF $slope > $max_slope;
				LET $dz = $z_prev - $z_current - $max_slope * $distance;
			ENDIF;
		ENDIF;
		SET sections.Z = sections.Z + $dz WHERE sections.key = AREF($j,$keys); 
		LET $dz = 0;
		LET $x_prev = $x_current;
		LET $y_prev = $y_current;
		LET $z_prev = $z_current;
		LET $j = $j + 1;
	WEND;
	LET $i = $i + 1;
WEND;

/* 11 - River Section Panel Insert (Horizontal)
	Object Type: River reach */
/* Define Parameters */
LET $dsmax = 0.2;
PROMPT TITLE "Cross Section Slope change factor";
PROMPT LINE $ssmax "Max change in slope ratio to trigger new pannel marker" DP 3;
PROMPT DISPLAY;

/* Initialize Variables & Lists */
LIST $reach STRING;
LIST $keys STRING;
LIST $xx;
SELECT SELECTED DISTINCT oid INTO $reach;

/* Iterate through each River Reach */
LET $i = 1;
WHILE $i <= LEN($reach);
	DESELECT All;
	SELECT WHERE oid = AREF($i,$reach);
	LET $new_p_count = 0;
	
	/* Iterate for each section */
	SELECT SELECTED DISTINCT river_section.key INTO $keys;
	LET $j = 1;
	WHILE $j <= LEN($keys);
		SELECT SELECTED AVG(sections.Z)INTO $zbar WHERE  sections.key = AREF($j,$keys);
		
		/* Iterate through section vertices, from 2 to n-1 */
		SELECT SELECTED DISTINCT sections.X INTO $xx WHERE sections.key = AREF($j,$keys) ORDER BY sections.X;
		LET $k = 2;
		WHILE $k <= LEN($xx)-1;
			SELECT SELECTED sections.Z INTO $zp WHERE sections.key = AREF($j,$keys) and sections.X=AREF($k-1,$xx);
			SELECT SELECTED sections.Z INTO $zc WHERE sections.key = AREF($j,$keys) and sections.X=AREF($k,$xx);
			SELECT SELECTED sections.Z INTO $zn WHERE sections.key = AREF($j,$keys) and sections.X=AREF($k+1,$xx);
			LET $sp = (($zc - $zp)/(AREF($k,$xx)-AREF($k-1,$xx)));
			LET $sn = (($zn - $zc)/(AREF($k+1,$xx)-AREF($k,$xx)));
			IF $sp - $sn > $dsmax AND $zc > $zbar;
				UPDATE SELECTED SET sections.new_panel = 1 WHERE sections.key = AREF($j,$keys) and sections.X=AREF($k,$xx);
				LET $new_p_count = $new_p_count + 1;
			ENDIF;
			LET $k = $k + 1;
		WEND;
		
		LET $j = $j + 1;
	WEND;
	UPDATE SELECTED SET $new_panels = $new_p_count;
	LET $i = $i + 1;
WEND;
SELECT oid AS [River Reach],
 $new_p_count AS [Added Panels],
 Count(river_section.key) AS [Total Sections],
 COUNT(sections.new_panel=1)/Count(river_section.key) AS [Panels per Section]
 WHERE MEMBER(oid,$reach);

/* 12 CSO Compliance Report
	Object Type: All Links 
	Note: This was written for a Network that had flap valve links at each CSO location.
	The network was preprocessed with a CSO location name in the User Text 1 field of each
	Flap Valve and its cooresponding upstream pipe that bypasses the CSO.
	This query requires an editable network with results on top that include dissolved MCpl1 concentration as a passive tracer of wastewater contribution.*/
/* Iterate Through Locations to perform Statistics */
LIST $location STRING;
SELECT DISTINCT user_text_1 INTO $location;
LET $i = 1;
WHILE $i <= LEN($location);
  LET $wwf = 0;
  CLEAR SELECTION;
  SELECT WHERE user_text_1=AREF($i,$location) AND link_type <> 'flap'; 
  SELECT SELECTED INTEGRAL(tsr.us_flow*(1-tsr.us_MCpl1DIS))*60 INTO $wwf;
  CLEAR SELECTION;
  SELECT WHERE user_text_1=AREF($i,$location) AND link_type = 'flap'; 
  UPDATE SELECTED SET user_number_1 = INTEGRAL(tsr.us_flow)*60,
    user_number_2 = $wwf + user_number_1,
	user_number_4 = DURATION(tsr.us_flow>0.01),
	user_number_3 = (1 - user_number_1/user_number_2)*100,
	user_text_2 = WHENEARLIEST(tsr.us_flow > 0.01),
	user_text_3 = WHENLATEST(tsr.us_flow > 0.01);
  LET $i = $i + 1;
WEND;

/* Generate Report */
CLEAR SELECTION;
SELECT WHERE  link_type = 'Flap';
SELECT SELECTED user_text_1 as [CSO ID],
    user_number_1 as [Total Spill Volume (ft3)],
    user_number_2 as [Total WWF Volume (ft3)],
    user_number_3 as [WWF Passed Through (%)],
    user_number_4 as [Overflow Duration (min)],
    user_text_2 as [Spill Onset Time],
    user_text_3 as [Last spill time]

/* 13 Rain Gauge Interpolation
	Object Type: TVD Connector
	Note: Requires TSDB
/* Initialize Variables */
LIST $subs STRING;
LIST $dist;
LET $powerfactor = 2; /* IDW Power Factor */
LET $id = 'kitty';
LET $x = 0;
LET $y = 0;
LET $i = 1;
/* Iterate through Subcatchments */
SELECT DISTINCT id INTO $subs WHERE category_id = 'Rainfall';
WHILE $i <= LEN($subs);
  SELECT x INTO $x WHERE id = AREF($i,$subs);
  SELECT y INTO $y WHERE id = AREF($i,$subs);
  SET user_number_10 = ((x-$x)^2+(y-$y)^2)^0.5 WHERE category_id = 'Rain Gauge';
  SELECT DISTINCT user_number_10 INTO $dist WHERE user_number_10 > 0 ORDER BY user_number_10 ASC;
  SELECT id INTO $id WHERE user_number_10 = AREF(1,$dist);
  SET input_a = $id WHERE id = AREF($i,$subs);
  SELECT id INTO $id WHERE user_number_10 = AREF(2,$dist);
  SET input_b = $id WHERE id = AREF($i,$subs);
  SELECT id INTO $id WHERE user_number_10 = AREF(3,$dist);
  SET input_c = $id WHERE id = AREF($i,$subs);
  SET user_number_1 = AREF(1,$dist) WHERE id = AREF($i,$subs);
  SET user_number_2 = AREF(2,$dist) WHERE id = AREF($i,$subs);
  SET user_number_3 = AREF(3,$dist) WHERE id = AREF($i,$subs);
  LET $i = $i + 1;
WEND;
/* Apply Inverse Distance Weighting function for nearest 3 gauges */
SELECT WHERE category_id = 'Rainfall';
UPDATE SELECTED SET input_a_units = 'R',
  input_b_units = 'R',
  input_c_units = 'R',
  output_units = 'R',
  expression_units = 'in/hr',
  x = '',
  y = '',
  user_number_4 = $powerfactor,
  output_expression = '
SET $A = TSDATA(Input_a, "in/hr");    
SET $B = TSDATA(Input_b, "in/hr");    
SET $C = TSDATA(Input_c, "in/hr");
SET $aw = user_number_1^-user_number_4;
SET $bw = user_number_2^-user_number_4;
SET $cw = user_number_3^-user_number_4;
SET $total = 0 + IIF($A IS NOT NULL,$aw,0) + IIF($B IS NOT NULL,$bw,0) + IIF($C IS NOT NULL,$cw,0);
IIF($total>0,(NVL($A,0)*$aw + NVL($B,0)*$bw + NVL($C,0)*$cw) / $total,"")';



