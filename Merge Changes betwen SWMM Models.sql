/* This is an SQL for SWMM networks to merge changes brought in from other SWMM-imported networks (since the usual compare networks to CSV won't work in this case).
Save this text into a Stored SQL Query in ICM, setting the Object Type to [All Nodes].
Workflow: 
Copy all objects with suspected changes from new branch network
Paste objects on top of Parent master copy network - Any duplicate objects should get a "!" appended at end of ID - These will be deleted so make sure actual ID's don't have a ! at end.
Drag SQL script onto master copy network - this will iterate through pipes and nodes and copy over any changes from new branch.
The script has several attribute types commented out for efficiency - turn on any fields that are expected to contain changes.
*/

LET $flag = 'SWMM';

SELECT ALL FROM [All Nodes];
DESELECT WHERE node_id MATCHES '.*!';
LIST $ndid STRING;
SELECT SELECTED DISTINCT node_id INTO $ndid;
CLEAR SELECTION;

LET $i=1;
WHILE $i <= LEN($ndid);
	SELECT COUNT(node_id=AREF($i,$ndid)+'!') INTO $temp;
	IF $temp = 1;
		SELECT invert_elevation INTO $inv WHERE node_id = AREF($i,$ndid)+'!';
//		SELECT maximum_depth INTO $maxd WHERE node_id = AREF($i,$ndid)+'!';
//		SELECT surcharge_depth INTO $srch WHERE node_id = AREF($i,$ndid)+'!';
//		SELECT base_flow INTO $dwf WHERE node_id = AREF($i,$ndid)+'!';
//		SELECT bf_pattern_1 INTO $patt WHERE node_id = AREF($i,$ndid)+'!';
		SELECT unit_hydrograph_area INTO $uha WHERE node_id = AREF($i,$ndid)+'!';
		SELECT unit_hydrograph_id INTO $rtk WHERE node_id = AREF($i,$ndid)+'!';
		SET invert_elevation=$inv, 
			invert_elevation_flag=$flag,
			$modified = 1
			WHERE node_id = AREF($i,$ndid) AND INT(invert_elevation) <> INT($inv);
/*		SET maximum_depth = $maxd, 
			maximum_depth_flag=$flag,
			$modified = 1
			WHERE node_id = AREF($i,$ndid) AND maximum_depth <> $maxd;
		SET surcharge_depth = $srch, 
			surcharge_depth_flag=$flag,
			$modified = 1
			WHERE node_id = AREF($i,$ndid) AND surcharge_depth <> $srch;
		SET base_flow = $dwf, 
			base_flow_flag=$flag,
			$modified = 1
			WHERE node_id = AREF($i,$ndid) AND base_flow <> $dwf;
		SET bf_pattern_1 = $patt, 
			bf_pattern_1_flag=$flag,
			$modified = 1
			WHERE node_id = AREF($i,$ndid) AND bf_pattern_1 <> $patt; */
		SET unit_hydrograph_area = $uha, 
			unit_hydrograph_area_flag=$flag,
			$modified = 1
			WHERE node_id = AREF($i,$ndid) AND unit_hydrograph_area <> $uha;
		SET unit_hydrograph_id = $rtk, 
			unit_hydrograph_id_flag=$flag,
			$modified = 1
			WHERE node_id = AREF($i,$ndid) AND unit_hydrograph_id <> $rtk;
		DELETE WHERE node_id = AREF($i,$ndid)+'!';
	ENDIF;
	LET $i = $i+1;
WEND;



SELECT ALL FROM [All Links];
DESELECT FROM [All Links] WHERE id MATCHES '.*!';
LIST $pipeid STRING;
SELECT SELECTED DISTINCT id INTO $pipeid FROM [All Links];
CLEAR SELECTION;

LET $i=1;
WHILE $i <= LEN($pipeid);
	SELECT COUNT(id=AREF($i,$pipeid)+'!') INTO $temp FROM [All Links];
	IF $temp = 1;
//		SELECT us_invert INTO $usi FROM [All Links] WHERE id = AREF($i,$pipeid)+'!';
//		SELECT ds_invert INTO $dsi FROM [All Links] WHERE id = AREF($i,$pipeid)+'!';
		SELECT conduit_height INTO $diam FROM [All Links] WHERE id = AREF($i,$pipeid)+'!';
/*		UPDATE [All Links] SET us_invert=$usi, 
			us_invert_flag=$flag,
			$modified_pipe = 1
			WHERE id = AREF($i,$pipeid) AND us_invert <> $usi;
		UPDATE [All Links] SET ds_invert=$dsi, 
			ds_invert_flag=$flag,
			$modified_pipe = 1
			WHERE id = AREF($i,$pipeid) AND ds_invert <> $dsi; */
		UPDATE [All Links] SET conduit_height=$diam, 
			conduit_height_flag=$flag,
			$modified_pipe = 1
			WHERE id = AREF($i,$pipeid) AND conduit_height <> $diam;
		DELETE FROM [All Links] WHERE id = AREF($i,$pipeid)+'!';
	ENDIF;
	LET $i = $i+1;
WEND;

SELECT WHERE $modified = 1;
SELECT FROM [All Links] WHERE $modified_pipe=1;
