/* Run this script on the Nodes table of ICM networks to redirect subcatchment flow to 2D points above inlet nodes */

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
