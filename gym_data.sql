/* 
Goal:
Using the columns in the given dataset, propose ideal workout plans and suggest calorie consumption to gym members.
*/

select *
from exercise;

-- Before data cleaning, create a staging table as a precaution.

CREATE TABLE gym_data.exercise_staging
LIKE gym_data.exercise;

INSERT exercise_staging
SELECT *
FROM gym_data.exercise;

SELECT *
FROM exercise_staging;

-- Data Cleaning Steps
-- 1. check for duplicates and remove any
-- 2. standardize data and fix errors
-- 3. Look at null and blank values
-- 4. remove any columns and rows that are not necessary - few ways

-- 1. Remove Duplicates

SELECT *
FROM (
	SELECT age, gender, `weight (kg)`, `height (m)`, calories_burned, workout_type,
		ROW_NUMBER() OVER (
			PARTITION BY age, gender, `weight (kg)`, `height (m)`, calories_burned, workout_type) AS rn
	FROM gym_data.exercise_staging 
	) duplicates
	WHERE 
		rn > 1;
        
-- 2. Standardize data and fix errors
-- 2-1 Remove spaces
UPDATE exercise_staging
SET age                             = TRIM(age),
	gender                          = TRIM(gender),
	`weight (kg)`                   = TRIM(`weight (kg)`),
	`height (m)`                    = TRIM(`height (m)`),
	avg_bpm                         = TRIM(avg_bpm),
	`session_duration (hours)`      = TRIM(`session_duration (hours)`),
	calories_burned                 = TRIM(calories_burned),
	workout_type                    = TRIM(workout_type),
	fat_percentage                  = TRIM(fat_percentage),
	`workout_frequency (days/week)` = TRIM(`workout_frequency (days/week)`),
	experience_level                = TRIM(experience_level),
	bmi                             = TRIM(bmi);

-- 2-2 Standardize workout type and gender to uppercase
SELECT *
FROM exercise_staging;

UPDATE exercise_staging
SET workout_type = UPPER(TRIM(workout_type)),
	gender       = UPPER(TRIM(gender));

SELECT DISTINCT workout_type, gender FROM exercise_staging;

-- 3. Look at null and blank values
DELETE FROM exercise_staging
WHERE 
	age IS NULL OR age = '' OR
    gender IS NULL OR gender = '' OR
    `weight (kg)` IS NULL OR `weight (kg)` = '' OR
    `height (m)` IS NULL OR `height (m)` = '' OR
    avg_bpm IS NULL OR avg_bpm = '' OR
    calories_burned IS NULL OR age = '' OR
    workout_type IS NULL OR workout_type = '';

-- 4. Remove unnecessary columns and rows
ALTER TABLE exercise_staging
DROP COLUMN max_bpm,
DROP COLUMN resting_bpm,
DROP COLUMN `water_intake (liters)`,
DROP COLUMN experience_level;

SELECT *
FROM exercise_staging;

-- 4-2 Handle outliers (Remove calorie outliers after checking `session_duration (hours)`)
SELECT 
	AVG(`session_duration (hours)`), 
	MIN(`session_duration (hours)`),
	MAX(`session_duration (hours)`),
    AVG(calories_burned), 
	MIN(calories_burned),
	MAX(calories_burned)
FROM exercise_staging;

-- Check workout duration of MAX(calories_burned) - 1783cal
SELECT *
FROM exercise_staging
WHERE calories_burned = 1783;

-- Also check fat_percentage, workout_frequency (days/week), bmi
SELECT 
	MIN(fat_percentage),
	MAX(fat_percentage)
FROM exercise_staging;

SELECT 
	MIN(`workout_frequency (days/week)`),
	MAX(`workout_frequency (days/week)`)
FROM exercise_staging;

SELECT 
	MIN(bmi),
	MAX(bmi)
FROM exercise_staging;

-- Check weight (kg) and height (m) for the max bmi value
SELECT *
FROM exercise_staging
WHERE bmi = 49.84;

/* 5. Deriving Insights
5-1. Analysis of calories burned by gender and workout_type → It is concluded that FEMALE burns the most calories with yoga, while MALE burns the most calories with HIIT.
Based on this result, if the calorie burn varies by workout type, adjusting the workout program can lead to more effective calorie burning.
However, there is not a big difference, and it is concluded that similar calorie burn effects can be expected for any type of exercise with similar workout_hours.
*/
SELECT *
FROM exercise_staging;

SELECT gender, workout_type,
	FORMAT(AVG(`session_duration (hours)`), 2) AS workout_hours,
    ROUND(AVG(calories_burned)) AS avg_cal,
    COUNT(*) AS count
FROM exercise_staging
GROUP BY gender, workout_type
ORDER BY gender, avg_cal DESC;

/*
5-1-1. So, I divided the age groups into 10-year intervals and derived the results
Upon review, the avg_cal amount is now more clearly derived compared to before → This allows for more effective workout recommendations for age groups.
However, there is a limitation due to the low count of data, which is a bit disappointing
*/
SELECT CONCAT(FLOOR(age / 10) * 10, '-', FLOOR(age / 10) * 10 + 9) AS age_group,
       gender, workout_type,
       ROUND(AVG(calories_burned)) AS avg_cal,
       FORMAT(AVG(`session_duration (hours)`), 2) AS workout_hours
       -- COUNT(*) AS count
FROM exercise_staging
GROUP BY age_group, gender, workout_type
ORDER BY age_group ASC, gender, avg_cal, workout_type DESC;


/* 5-2 Analysis of the relationship between BMI and calories burned
Analyze if there is a difference in calories burned between people with low or high BMI.
BMI is calculated by dividing a person's weight (kg) by the square of their height (m).
*/

SELECT *
FROM exercise_staging;

SELECT bmi,
	COUNT(*) AS count,
    AVG(calories_burned) AS avg_cal
FROM exercise_staging
GROUP BY bmi
ORDER BY bmi ASC;

/*
BMI range (by WHO) grouped due to too many rows for BMI values
0 - 18.4 	Underweight
18.5 - 24.9 Healthy
25 - 29.9 	Overweight
30 - 34.9	Obesity (Class I)
35 - 39.9 	Severe obesity (Class II)
40 - 		Morbid obesity (Class III)
There is no significant difference, but it was found that the "Obesity (Class I)" group burns the most calories.
*/
SELECT CASE
           WHEN bmi BETWEEN 0    AND 18.4 THEN '1. Underweight'
           WHEN bmi BETWEEN 18.5 AND 24.9 THEN '2. Healthy'
           WHEN bmi BETWEEN 25   AND 29.9 THEN '3. Overweight'
           WHEN bmi BETWEEN 30   AND 34.9 THEN '4. Obesity (Class I)'
           WHEN bmi BETWEEN 35   AND 39.9 THEN '5. Obesity (Class II)'
           ELSE '6. Obesity (Class III)'
       END AS bmi_range,
       ROUND(AVG(calories_burned)) AS avg_cal
       -- count(*) AS count
FROM exercise_staging
GROUP BY bmi_range
ORDER BY bmi_range ASC;

-- 5-3 Analysis of exercise type preferences by gender within age group
SELECT CONCAT(FLOOR(age / 10) * 10, '-', FLOOR(age / 10) * 10 + 9) AS age_group,
       gender, workout_type,
       COUNT(*) AS count
FROM exercise_staging
GROUP BY age_group, gender, workout_type
ORDER BY age_group, gender, count DESC;

SELECT * FROM exercise_staging;

-- Copy to the existing exercise table
TRUNCATE TABLE exercise;
INSERT INTO exercise (age, gender, `weight (kg)`, `height (m)`, avg_bpm, `session_duration (hours)`, calories_burned, workout_type, fat_percentage, `workout_frequency (days/week)`, bmi)
SELECT age, gender, `weight (kg)`, `height (m)`, avg_bpm, `session_duration (hours)`, calories_burned, workout_type, fat_percentage, `workout_frequency (days/week)`, bmi
FROM exercise_staging;

-- Drop unnecessary columns
ALTER TABLE exercise
DROP COLUMN max_bpm,
DROP COLUMN resting_bpm,
DROP COLUMN `water_intake (liters)`,
DROP COLUMN experience_level;

SELECT * FROM exercise;
SELECT * FROM exercise_staging;


/* 
What I learned after finishing the project
1. The column names could have been simplified more.
2. Since the data volume wasn’t large, I had doubts about the accuracy of the results.
3. I realized once again how important the initial dataset selection is.
*/
