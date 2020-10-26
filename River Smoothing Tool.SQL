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
