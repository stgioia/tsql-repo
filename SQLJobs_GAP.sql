--https://www.sqlserverscience.com/tools/gaps-between-sql-server-agent-jobs/
/*
      Shows gaps between agent jobs
*/
DECLARE @EarliestStartDate DATETIME;
DECLARE @LatestStopDate DATETIME;
SET @EarliestStartDate = DATEADD(DAY, -1, GETDATE());
SET @LatestStopDate = GETDATE();

;WITH s AS 
(
	SELECT StartDateTime = msdb.dbo.agent_datetime(sjh.run_date, sjh.run_time)
		  , MaxDuration = MAX(sjh.run_duration)
	FROM msdb.dbo.sysjobs sj 
		  INNER JOIN msdb.dbo.sysjobhistory sjh ON sj.job_id = sjh.job_id
	WHERE sjh.step_id = 0
		AND msdb.dbo.agent_datetime(sjh.run_date, sjh.run_time) >= @EarliestStartDate
		AND msdb.dbo.agent_datetime(sjh.run_date, sjh.run_time) < = @LatestStopDate
	GROUP BY msdb.dbo.agent_datetime(sjh.run_date, sjh.run_time)
	UNION ALL
	SELECT StartDate = DATEADD(SECOND, -1, @EarliestStartDate)
		, MaxDuration = 1
	UNION ALL 
	SELECT StartDate = @LatestStopDate
		, MaxDuration = 1
)
, s1 AS 
(
SELECT s.StartDateTime
	, EndDateTime = DATEADD(SECOND, s.MaxDuration - ((s.MaxDuration / 100) * 100)
		+ (((s.MaxDuration - ((s.MaxDuration / 10000) * 10000)) 
                    - (s.MaxDuration - ((s.MaxDuration / 100) * 100))) / 100) * 60
		+ (((s.MaxDuration - ((s.MaxDuration / 1000000) * 1000000)) 
                    - (s.MaxDuration - ((s.MaxDuration / 10000) * 10000))) / 10000) * 3600, s.StartDateTime)
FROM s
)
, s2 AS
(
	SELECT s1.StartDateTime
		, s1.EndDateTime
		, LastEndDateTime = LAG(s1.EndDateTime) OVER (ORDER BY s1.StartDateTime)
	FROM s1 
)
SELECT GapStart = CONVERT(DATETIME2(0), s2.LastEndDateTime)
	, GapEnd = CONVERT(DATETIME2(0), s2.StartDateTime)
	, GapLength = CONVERT(TIME(0), DATEADD(SECOND, DATEDIFF(SECOND, s2.LastEndDateTime, s2.StartDateTime), 0))
FROM s2 
WHERE s2.StartDateTime > s2.LastEndDateTime
	ORDER BY s2.StartDateTime;