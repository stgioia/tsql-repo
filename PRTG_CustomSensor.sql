IF NOT EXISTS (SELECT 1 FROM master..sysdatabases WHERE name = 'DBA')
RAISERROR('The database DBA does not exist - halting execution.',16,1) WITH NOWAIT 

USE DBA

/* 
Wrote a bunch of procedures for a SINGLE PRTG custom sensor (each procedure can feed multiple channels)


PRTG Monitoring Procedures - 25/06/2019

           ▄              ▄
          ▌▒█           ▄▀▒▌
          ▌▒▒█        ▄▀▒▒▒▐
         ▐▄▀▒▒▀▀▀▀▄▄▄▀▒▒▒▒▒▐
       ▄▄▀▒░▒▒▒▒▒▒▒▒▒█▒▒▄█▒▐
     ▄▀▒▒▒░░░▒▒▒░░░▒▒▒▀██▀▒▌
    ▐▒▒▒▄▄▒▒▒▒░░░▒▒▒▒▒▒▒▀▄▒▒▌
    ▌░░▌█▀▒▒▒▒▒▄▀█▄▒▒▒▒▒▒▒█▒▐
   ▐░░░▒▒▒▒▒▒▒▒▌██▀▒▒░░░▒▒▒▀▄▌
   ▌░▒▄██▄▒▒▒▒▒▒▒▒▒░░░░░░▒▒▒▒▌
  ▌▒▀▐▄█▄█▌▄░▀▒▒░░░░░░░░░░▒▒▒▐
  ▐▒▒▐▀▐▀▒░▄▄▒▄▒▒▒▒▒▒░▒░▒░▒▒▒▒▌
  ▐▒▒▒▀▀▄▄▒▒▒▄▒▒▒▒▒▒▒▒░▒░▒░▒▒▐
   ▌▒▒▒▒▒▒▀▀▀▒▒▒▒▒▒░▒░▒░▒░▒▒▒▌
   ▐▒▒▒▒▒▒▒▒▒▒▒▒▒▒░▒░▒░▒▒▄▒▒▐
    ▀▄▒▒▒▒▒▒▒▒▒▒▒░▒░▒░▒▄▒▒▒▒▌
      ▀▄▒▒▒▒▒▒▒▒▒▒▄▄▄▀▒▒▒▒▄▀
        ▀▄▄▄▄▄▄▀▀▀▒▒▒▒▒▄▄▀
           ▒▒▒▒▒▒▒▒▒▒▀▀


*/

-- Add rows to this table if you want to ignore a particular database backup failing
IF NOT EXISTS (SELECT * FROM sysobjects WHERE type = 'U' AND name = 'tb_PRTG_BackupWhiteList')

CREATE TABLE tb_PRTG_BackupWhiteList (
	DatabaseName	varchar (256)
	)
GO

-- Add rows to this table if you want to ignore a particular job failing
IF NOT EXISTS (SELECT * FROM sysobjects WHERE type = 'U' AND name = 'tb_PRTG_JobWhiteList')

CREATE TABLE tb_PRTG_JobWhiteList (
	JobName	varchar (512)
	)
GO

--Low Disk Space sensor
DECLARE @SQLDiskSpace varchar (8000)

IF EXISTS (SELECT * FROM sysobjects WHERE type = 'P' AND name = 'sp_PRTG_DiskSpace')
DROP PROCEDURE sp_PRTG_DiskSpace

IF  (CASE 
     WHEN CONVERT(VARCHAR(128), SERVERPROPERTY ('productversion')) like '8%' THEN 'SQL2000'
     WHEN CONVERT(VARCHAR(128), SERVERPROPERTY ('productversion')) like '9%' THEN 'SQL2005'
     WHEN CONVERT(VARCHAR(128), SERVERPROPERTY ('productversion')) like '10.0%' THEN 'SQL2008'
     WHEN CONVERT(VARCHAR(128), SERVERPROPERTY ('productversion')) like '10.5%' THEN 'SQL2008 R2'
     WHEN CONVERT(VARCHAR(128), SERVERPROPERTY ('productversion')) like '11%' THEN 'SQL2012'
     WHEN CONVERT(VARCHAR(128), SERVERPROPERTY ('productversion')) like '12%' THEN 'SQL2014'
     WHEN CONVERT(VARCHAR(128), SERVERPROPERTY ('productversion')) like '13%' THEN 'SQL2016'     
     WHEN CONVERT(VARCHAR(128), SERVERPROPERTY ('productversion')) like '14%' THEN 'SQL2017' 
     ELSE 'unknown'
  END) = 'SQL2000'
BEGIN
	SELECT @SQLDiskSpace = 'CREATE PROCEDURE sp_PRTG_DiskSpace
	AS
	BEGIN
		SET NOCOUNT ON

		DECLARE @OLE_enabled SQL_VARIANT
		DECLARE @hr INT
		DECLARE @fso INT
		DECLARE @drive CHAR(1)
		DECLARE @odrive INT
		DECLARE @TotalSize VARCHAR(20)
		DECLARE @MB NUMERIC;

		SET @MB = 1048576

		CREATE TABLE #drives (
			drive CHAR(1) PRIMARY KEY
			,FreeSpace INT NULL
			,TotalSize INT NULL
			)

		INSERT #drives (
			drive
			,FreeSpace
			)
		EXEC master.dbo.xp_fixeddrives

		EXEC @hr = sp_OACreate ''Scripting.FileSystemObject''
			,@fso OUTPUT

		IF @hr <> 0
			EXEC sp_OAGetErrorInfo @fso

		DECLARE dcur CURSOR LOCAL FAST_FORWARD
		FOR
		SELECT drive
		FROM #drives
		ORDER BY drive

		OPEN dcur

		FETCH NEXT
		FROM dcur
		INTO @drive

		WHILE @@FETCH_STATUS = 0
		BEGIN
			EXEC @hr = sp_OAMethod @fso
				,''GetDrive''
				,@odrive OUTPUT
				,@drive

			IF @hr <> 0
				EXEC sp_OAGetErrorInfo @fso

			EXEC @hr = sp_OAGetProperty @odrive
				,''TotalSize''
				,@TotalSize OUTPUT

			IF @hr <> 0
				EXEC sp_OAGetErrorInfo @odrive

			UPDATE #drives
			SET TotalSize = @TotalSize / @MB
			WHERE drive = @drive

			FETCH NEXT
			FROM dcur
			INTO @drive
		END

		CLOSE dcur

		DEALLOCATE dcur

		EXEC @hr = sp_OADestroy @fso

		IF @hr <> 0
			EXEC sp_OAGetErrorInfo @fso

		      SELECT count (1) AS Error, NULL AS Message
				FROM #drives 
				WHERE convert (decimal (10,2), (FreeSpace * 1.0/TotalSize)*100) < 10  

		DROP TABLE #drives

		END'
END
ELSE
BEGIN
	SELECT @SQLDiskSpace = 'CREATE PROCEDURE sp_PRTG_DiskSpace
	AS
	BEGIN
		SET NOCOUNT ON

		DECLARE @OLE_enabled SQL_VARIANT
		DECLARE @hr INT
		DECLARE @fso INT
		DECLARE @drive CHAR(1)
		DECLARE @odrive INT
		DECLARE @TotalSize VARCHAR(20)
		DECLARE @MB NUMERIC;

		SET @MB = 1048576

		SELECT @OLE_enabled = value_in_use
		FROM sys.configurations
		WHERE name = ''Ole automation Procedures''

		IF @OLE_enabled = 0
		BEGIN
			EXEC sp_configure ''Ole Automation Procedures'', 1

			RECONFIGURE
			WITH OVERRIDE
		END

		CREATE TABLE #drives (
			drive CHAR(1) PRIMARY KEY
			,FreeSpace INT NULL
			,TotalSize INT NULL
			)

		INSERT #drives (
			drive
			,FreeSpace
			)
		EXEC master.dbo.xp_fixeddrives

		EXEC @hr = sp_OACreate ''Scripting.FileSystemObject''
			,@fso OUTPUT

		IF @hr <> 0
			EXEC sp_OAGetErrorInfo @fso

		DECLARE dcur CURSOR LOCAL FAST_FORWARD
		FOR
		SELECT drive
		FROM #drives
		ORDER BY drive

		OPEN dcur

		FETCH NEXT
		FROM dcur
		INTO @drive

		WHILE @@FETCH_STATUS = 0
		BEGIN
			EXEC @hr = sp_OAMethod @fso
				,''GetDrive''
				,@odrive OUTPUT
				,@drive

			IF @hr <> 0
				EXEC sp_OAGetErrorInfo @fso

			EXEC @hr = sp_OAGetProperty @odrive
				,''TotalSize''
				,@TotalSize OUTPUT

			IF @hr <> 0
				EXEC sp_OAGetErrorInfo @odrive

			UPDATE #drives
			SET TotalSize = @TotalSize / @MB
			WHERE drive = @drive

			FETCH NEXT
			FROM dcur
			INTO @drive
		END

		CLOSE dcur

		DEALLOCATE dcur

		EXEC @hr = sp_OADestroy @fso

		IF @hr <> 0
			EXEC sp_OAGetErrorInfo @fso

		  SELECT (SELECT count (1) FROM #drives WHERE convert (decimal (10,2), (FreeSpace * 1.0/TotalSize)*100) < 10) ''Error'', 
		  (SELECT drive + '':\ Low Disk Space '' + convert (varchar, convert (decimal (10,2), (FreeSpace * 1.0/TotalSize)*100)) + ''%'' + '' | '' AS ''data()''  
		  FROM #drives  
		  WHERE convert (decimal (10,2), (FreeSpace * 1.0/TotalSize)*100) < 10
		  FOR XML PATH('''')) ''Message''

		DROP TABLE #drives

		IF @OLE_enabled = 0
		BEGIN
			EXEC sp_configure ''Ole Automation Procedures'', 0

			RECONFIGURE
			WITH OVERRIDE
		END
		END'
END

EXEC (@SQLDiskSpace)
GO

--SQL Agent Monitor
IF EXISTS (SELECT * FROM sysobjects WHERE type = 'P' AND name = 'sp_PRTG_SQLAgent')
DROP PROCEDURE sp_PRTG_SQLAgent
GO

CREATE PROCEDURE sp_PRTG_SQLAgent
AS
BEGIN
	SET NOCOUNT ON
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

	SELECT coalesce (count (1), 0) 'SQLAgentRunning'
	FROM master..sysprocesses
	WHERE program_name = N'SQLAgent - Generic Refresher'
END
GO

--SQL Monitor
DECLARE @SQLMonitor varchar (8000)

IF EXISTS (SELECT * FROM sysobjects WHERE type = 'P' AND name = 'sp_PRTG_Monitor')
DROP PROCEDURE sp_PRTG_Monitor

IF  (CASE 
     WHEN CONVERT(VARCHAR(128), SERVERPROPERTY ('productversion')) like '8%' THEN 'SQL2000'
     WHEN CONVERT(VARCHAR(128), SERVERPROPERTY ('productversion')) like '9%' THEN 'SQL2005'
     WHEN CONVERT(VARCHAR(128), SERVERPROPERTY ('productversion')) like '10.0%' THEN 'SQL2008'
     WHEN CONVERT(VARCHAR(128), SERVERPROPERTY ('productversion')) like '10.5%' THEN 'SQL2008 R2'
     WHEN CONVERT(VARCHAR(128), SERVERPROPERTY ('productversion')) like '11%' THEN 'SQL2012'
     WHEN CONVERT(VARCHAR(128), SERVERPROPERTY ('productversion')) like '12%' THEN 'SQL2014'
     WHEN CONVERT(VARCHAR(128), SERVERPROPERTY ('productversion')) like '13%' THEN 'SQL2016'     
     WHEN CONVERT(VARCHAR(128), SERVERPROPERTY ('productversion')) like '14%' THEN 'SQL2017' 
     ELSE 'unknown'
  END) = 'SQL2000'
BEGIN
	SELECT @SQLMonitor = '
	CREATE PROCEDURE sp_PRTG_Monitor
	AS
	BEGIN
	SET NOCOUNT ON
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

	SELECT 
	(SELECT count (1)
	FROM master..sysdatabases
	WHERE name <> ''tempdb''
	AND DATABASEPROPERTYEX (name, ''Status'') = ''ONLINE''
	AND name NOT IN (SELECT DISTINCT DatabaseName FROM DBA..tb_PRTG_BackupWhiteList)
	AND name NOT IN (SELECT DISTINCT database_name FROM msdb..backupset
	WHERE backup_start_date > DATEADD (DAY,-7,GETDATE())
	AND type = ''D'')) ''NoFullBackups'',
		(SELECT count (1)
		FROM master..sysdatabases
		WHERE name not in (''tempdb'', ''master'')
		AND DATABASEPROPERTYEX (name, ''Status'') = ''ONLINE''
		AND name NOT IN (SELECT DISTINCT DatabaseName FROM DBA..tb_PRTG_BackupWhiteList)
		AND name NOT IN (SELECT DISTINCT database_name FROM msdb..backupset
		WHERE backup_start_date > DATEADD (DAY,-1,GETDATE()))) ''NoBackups'',
	(SELECT count (1) FROM msdb.dbo.sysjobhistory jh
		INNER JOIN msdb.dbo.sysjobs j ON j.job_id = jh.job_id
		AND jh.step_id = 0
		AND jh.run_status = 0
		AND j.enabled = 1
		AND j.name NOT IN (SELECT DISTINCT JobName FROM DBA..tb_PRTG_JobWhiteList)
		AND left(cast(jh.run_date AS CHAR(10)), 4) + ''-'' + substring(cast(jh.run_date AS CHAR(10)), 5, 2) + ''-'' + substring(cast(jh.run_date AS CHAR(10)), 7, 2) + '' '' + 
		substring(right(stuff('' '', 1, 1, ''000000'') + convert(VARCHAR(6), jh.run_time), 6), 1, 2) + '':'' + substring(right(stuff('' '', 1, 1, ''000000'') + convert(VARCHAR(6), jh.run_time), 6), 3, 2) + '':'' + 
		substring(right(stuff('' '', 1, 1, ''000000'') + convert(VARCHAR(6), jh.run_time), 6), 5, 2) >= CONVERT(CHAR(19), GETDATE() - 2, 121)) ''FailedJobs'',
	0 as ''LongRunningJobs'',
	(select count (1)
		from master..sysprocesses
		where datediff (hh, last_batch, getdate()) > 12
		and last_batch <> ''1900-01-01 00:00:00.000''
		and status not in (''background'', ''sleeping'')) ''LongRunningQueries'',
	(SELECT count (1)
		FROM master..sysprocesses
		WHERE blocked <> 0
			AND waittime/1000/60 > 1) ''BlockedQueries'', 0 AS MemPressure, 0 AS UsageCPU, 0 AS AGHealth
	END'
END

IF  (CASE 
     WHEN CONVERT(VARCHAR(128), SERVERPROPERTY ('productversion')) like '8%' THEN 'SQL2000'
     WHEN CONVERT(VARCHAR(128), SERVERPROPERTY ('productversion')) like '9%' THEN 'SQL2005'
     WHEN CONVERT(VARCHAR(128), SERVERPROPERTY ('productversion')) like '10.0%' THEN 'SQL2008'
     WHEN CONVERT(VARCHAR(128), SERVERPROPERTY ('productversion')) like '10.5%' THEN 'SQL2008 R2'
     WHEN CONVERT(VARCHAR(128), SERVERPROPERTY ('productversion')) like '11%' THEN 'SQL2012'
     WHEN CONVERT(VARCHAR(128), SERVERPROPERTY ('productversion')) like '12%' THEN 'SQL2014'
     WHEN CONVERT(VARCHAR(128), SERVERPROPERTY ('productversion')) like '13%' THEN 'SQL2016'     
     WHEN CONVERT(VARCHAR(128), SERVERPROPERTY ('productversion')) like '14%' THEN 'SQL2017' 
     ELSE 'unknown'
  END) IN ('SQL2008', 'SQL 2008 R2', 'SQL2005')
BEGIN
	SELECT @SQLMonitor = '
	CREATE PROCEDURE sp_PRTG_Monitor
	AS
	BEGIN
	SET NOCOUNT ON
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

	WITH    MemBuffers
          AS ( SELECT   EventTime ,
                        record.value(''(/Record/ResourceMonitor/Notification)[1]'',
                                     ''varchar(max)'') AS [Type] ,
                        record.value(''(/Record/@id)[1]'', ''int'') AS RecordID ,
                        record.value(''(/Record/MemoryNode/@id)[1]'', ''int'') AS MemoryNodeID
               FROM     ( SELECT    DATEADD(ss,
                                            ( -1 * ( ( cpu_ticks
                                                       / CONVERT (FLOAT, ( cpu_ticks
                                                              / ms_ticks )) )
                                                     - [timestamp] ) / 1000 ),
                                            GETDATE()) AS EventTime ,
                                    CONVERT (XML, record) AS record
                          FROM      sys.dm_os_ring_buffers
                                    CROSS JOIN sys.dm_os_sys_info
                          WHERE     ring_buffer_type = ''RING_BUFFER_RESOURCE_MONITOR''
                        ) AS tab
             ),
        OrderedBuffers
          AS ( SELECT   EventTime ,
                        Type ,
                        RecordID ,
                        MemoryNodeID ,
                        ROW_NUMBER() OVER ( ORDER BY MemoryNodeID, MemBuffers.RecordID DESC, MemBuffers.EventTime DESC ) AS RowNum
               FROM     MemBuffers
               WHERE    EventTime >= DATEADD(DAY, -1, GETDATE())
                        AND Type IN ( ''RESOURCE_MEMPHYSICAL_LOW'',
                                      ''RESOURCE_MEM_STEADY'' )
               UNION
               SELECT DISTINCT
                        GETDATE() ,
                        ''Header'' ,
                        0 ,
                        MemoryNodeID ,
                        0
               FROM     MemBuffers
             )
	SELECT 
		(SELECT count (1)
		FROM sys.databases
		WHERE name <> ''tempdb''
		AND DATABASEPROPERTYEX (name, ''Status'') = ''ONLINE''
		AND name NOT IN (SELECT DISTINCT database_name FROM msdb..backupset
		WHERE backup_start_date > DATEADD (DAY,-7,GETDATE())
		AND type = ''D'')
		AND name NOT IN (SELECT DISTINCT DatabaseName FROM DBA..tb_PRTG_BackupWhiteList)
		AND name NOT IN (select secondary_database from msdb.dbo.log_shipping_secondary_databases)) ''NoFullBackups'',
			(SELECT count (1)
			FROM sys.databases
			WHERE name not in (''tempdb'', ''master'')
			AND DATABASEPROPERTYEX (name, ''Status'') = ''ONLINE''
			AND name NOT IN (SELECT DISTINCT database_name FROM msdb..backupset
			WHERE backup_start_date > DATEADD (DAY,-1,GETDATE()))
			AND name NOT IN (SELECT DISTINCT DatabaseName FROM DBA..tb_PRTG_BackupWhiteList)
			AND name NOT IN (select secondary_database from msdb.dbo.log_shipping_secondary_databases)) ''NoBackups'',
		(SELECT count (1)
		FROM msdb..sysjobhistory T1 INNER JOIN msdb..sysjobs T2 ON T1.job_id = T2.job_id
		WHERE T1.run_status NOT IN (1, 4)
		AND T2.name NOT IN (SELECT DISTINCT JobName FROM DBA..tb_PRTG_JobWhiteList)
		AND T2.enabled = 1
		AND T1.step_id != 0
		AND run_date >= CONVERT(CHAR(8), (SELECT DATEADD (DAY,(-1), GETDATE())), 112)
		AND (SELECT last_run_outcome FROM msdb.dbo.sysjobservers sjs LEFT OUTER JOIN msdb.dbo.sysjobs sj ON(sj.job_id = sjs.job_id) WHERE sj.job_id = t1.job_id) <> 1) ''FailedJobs'',
		(SELECT count (1)
			FROM msdb.dbo.sysjobactivity ja 
			LEFT JOIN msdb.dbo.sysjobhistory jh 
			ON ja.job_history_id = jh.instance_id
			JOIN msdb.dbo.sysjobs j 
			ON ja.job_id = j.job_id
			JOIN msdb.dbo.sysjobsteps js
			ON ja.job_id = js.job_id
			AND ISNULL(ja.last_executed_step_id,0)+1 = js.step_id
			WHERE ja.session_id = (SELECT TOP 1 session_id FROM msdb.dbo.syssessions ORDER BY agent_start_date DESC)
			AND start_execution_date is not null
			AND stop_execution_date is null
			AND j.name NOT IN (SELECT DISTINCT JobName FROM DBA..tb_PRTG_JobWhiteList)
			AND j.enabled = 1
			AND start_execution_date < dateadd (day,-1,getdate())
			AND js.step_name NOT IN (''Change Data Capture Collection Agent'', ''Run agent.'')) ''LongRunningJobs'',
		(select count (1)
			from sys.dm_exec_requests
			where datediff (hh, start_time, getdate()) > 12
			and status not in (''background'', ''sleeping'') and command <> ''WAITFOR'' and last_wait_type <> ''SP_SERVER_DIAGNOSTICS_SLEEP'') ''LongRunningQueries'',
		(SELECT count (1)
			FROM master..sysprocesses
			WHERE blocked <> 0
			  AND waittime/1000/60 > 1) ''BlockedQueries'',
		(SELECT  COALESCE (SUM(CONVERT(INT, ABS(CONVERT(FLOAT, ob1.EventTime - ob.EventTime)
                                 * 24 * 60 * 60))), 0) AS SecondsPressure
    FROM    OrderedBuffers ob
            LEFT JOIN OrderedBuffers ob1 ON ob.RowNum = ob1.RowNum + 1
                                            AND ob.MemoryNodeID = ob1.MemoryNodeID
    WHERE   ob.Type = ''RESOURCE_MEMPHYSICAL_LOW'') AS ''MemPressure'',
	(select top 1
	100 - SystemIdle
	from (
	select
	record.value(''(./Record/@id)[1]'', ''int'') as record_id,
	record.value(''(./Record/SchedulerMonitorEvent/SystemHealth/SystemIdle)[1]'', ''int'')
	as SystemIdle,
	record.value(''(./Record/SchedulerMonitorEvent/SystemHealth/ProcessUtilization)[1]'',
	''int'') as SQLProcessUtilization,
	timestamp
	from (
	select timestamp, convert(xml, record) as record
	from sys.dm_os_ring_buffers
	where ring_buffer_type = N''RING_BUFFER_SCHEDULER_MONITOR''
	and record like ''%<SystemHealth>%'') as x
	) as y
	order by record_id desc) AS ''UsageCPU'',
	0 AS AGHealth
	END'
END

IF  (CASE 
     WHEN CONVERT(VARCHAR(128), SERVERPROPERTY ('productversion')) like '8%' THEN 'SQL2000'
     WHEN CONVERT(VARCHAR(128), SERVERPROPERTY ('productversion')) like '9%' THEN 'SQL2005'
     WHEN CONVERT(VARCHAR(128), SERVERPROPERTY ('productversion')) like '10.0%' THEN 'SQL2008'
     WHEN CONVERT(VARCHAR(128), SERVERPROPERTY ('productversion')) like '10.5%' THEN 'SQL2008 R2'
     WHEN CONVERT(VARCHAR(128), SERVERPROPERTY ('productversion')) like '11%' THEN 'SQL2012'
     WHEN CONVERT(VARCHAR(128), SERVERPROPERTY ('productversion')) like '12%' THEN 'SQL2014'
     WHEN CONVERT(VARCHAR(128), SERVERPROPERTY ('productversion')) like '13%' THEN 'SQL2016'     
     WHEN CONVERT(VARCHAR(128), SERVERPROPERTY ('productversion')) like '14%' THEN 'SQL2017' 
     ELSE 'unknown'
  END) IN ('SQL2012', 'SQL2014', 'SQL2016', 'SQL2017')
BEGIN
	SELECT @SQLMonitor = '
		CREATE PROCEDURE sp_PRTG_Monitor
	AS
	BEGIN
	SET NOCOUNT ON
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

	WITH    MemBuffers
          AS ( SELECT   EventTime ,
                        record.value(''(/Record/ResourceMonitor/Notification)[1]'',
                                     ''varchar(max)'') AS [Type] ,
                        record.value(''(/Record/@id)[1]'', ''int'') AS RecordID ,
                        record.value(''(/Record/MemoryNode/@id)[1]'', ''int'') AS MemoryNodeID
               FROM     ( SELECT    DATEADD(ss,
                                            ( -1 * ( ( cpu_ticks
                                                       / CONVERT (FLOAT, ( cpu_ticks
                                                              / ms_ticks )) )
                                                     - [timestamp] ) / 1000 ),
                                            GETDATE()) AS EventTime ,
                                    CONVERT (XML, record) AS record
                          FROM      sys.dm_os_ring_buffers
                                    CROSS JOIN sys.dm_os_sys_info
                          WHERE     ring_buffer_type = ''RING_BUFFER_RESOURCE_MONITOR''
                        ) AS tab
             ),
        OrderedBuffers
          AS ( SELECT   EventTime ,
                        Type ,
                        RecordID ,
                        MemoryNodeID ,
                        ROW_NUMBER() OVER ( ORDER BY MemoryNodeID, MemBuffers.RecordID DESC, MemBuffers.EventTime DESC ) AS RowNum
               FROM     MemBuffers
               WHERE    EventTime >= DATEADD(DAY, -1, GETDATE())
                        AND Type IN ( ''RESOURCE_MEMPHYSICAL_LOW'',
                                      ''RESOURCE_MEM_STEADY'' )
               UNION
               SELECT DISTINCT
                        GETDATE() ,
                        ''Header'' ,
                        0 ,
                        MemoryNodeID ,
                        0
               FROM     MemBuffers
             )
	SELECT 
		(SELECT count (1)
		FROM sysdatabases
		WHERE name <> ''tempdb''
		AND DATABASEPROPERTYEX (name, ''Status'') = ''ONLINE''
		AND name NOT IN (SELECT DISTINCT database_name FROM msdb..backupset
		WHERE backup_start_date > DATEADD (DAY,-7,GETDATE())
		AND type = ''D'')
		AND name NOT IN (select secondary_database from msdb.dbo.log_shipping_secondary_databases)
		AND name NOT IN (SELECT DISTINCT DatabaseName FROM DBA..tb_PRTG_BackupWhiteList)
		AND name NOT IN  (SELECT DISTINCT
		dbcs.database_name AS [DatabaseName]
		FROM master.sys.availability_groups AS AG
		LEFT OUTER JOIN master.sys.dm_hadr_availability_group_states as agstates
		   ON AG.group_id = agstates.group_id
		INNER JOIN master.sys.availability_replicas AS AR
		   ON AG.group_id = AR.group_id
		INNER JOIN master.sys.dm_hadr_availability_replica_states AS arstates
		   ON AR.replica_id = arstates.replica_id AND arstates.is_local = 1
		INNER JOIN master.sys.dm_hadr_database_replica_cluster_states AS dbcs
		   ON arstates.replica_id = dbcs.replica_id
		LEFT OUTER JOIN master.sys.dm_hadr_database_replica_states AS dbrs
		   ON dbcs.replica_id = dbrs.replica_id AND dbcs.group_database_id = dbrs.group_database_id
		WHERE ISNULL(arstates.role, 3) = 2 AND ISNULL(dbcs.is_database_joined, 0) = 1)) ''NoFullBackups'',
			(SELECT count (1)
			FROM sysdatabases
			WHERE name not in (''tempdb'', ''master'')
			AND DATABASEPROPERTYEX (name, ''Status'') = ''ONLINE''
			AND name NOT IN (SELECT DISTINCT database_name FROM msdb..backupset
			WHERE backup_start_date > DATEADD (DAY,-1,GETDATE()))
			AND name NOT IN (select secondary_database from msdb.dbo.log_shipping_secondary_databases)
			AND name NOT IN (SELECT DISTINCT DatabaseName FROM DBA..tb_PRTG_BackupWhiteList)
			AND name NOT IN  (SELECT DISTINCT
		dbcs.database_name AS [DatabaseName]
		FROM master.sys.availability_groups AS AG
		LEFT OUTER JOIN master.sys.dm_hadr_availability_group_states as agstates
		   ON AG.group_id = agstates.group_id
		INNER JOIN master.sys.availability_replicas AS AR
		   ON AG.group_id = AR.group_id
		INNER JOIN master.sys.dm_hadr_availability_replica_states AS arstates
		   ON AR.replica_id = arstates.replica_id AND arstates.is_local = 1
		INNER JOIN master.sys.dm_hadr_database_replica_cluster_states AS dbcs
		   ON arstates.replica_id = dbcs.replica_id
		LEFT OUTER JOIN master.sys.dm_hadr_database_replica_states AS dbrs
		   ON dbcs.replica_id = dbrs.replica_id AND dbcs.group_database_id = dbrs.group_database_id
		WHERE ISNULL(arstates.role, 3) = 2 AND ISNULL(dbcs.is_database_joined, 0) = 1)) ''NoBackups'',
		(SELECT count (1)
		FROM msdb..sysjobhistory T1 INNER JOIN msdb..sysjobs T2 ON T1.job_id = T2.job_id
		WHERE T1.run_status NOT IN (1, 4)
		AND T2.name NOT IN (SELECT DISTINCT JobName FROM DBA..tb_PRTG_JobWhiteList)
		AND T2.enabled = 1
		AND T1.step_id != 0
		AND run_date >= CONVERT(CHAR(8), (SELECT DATEADD (DAY,(-1), GETDATE())), 112)
		AND (SELECT last_run_outcome FROM msdb.dbo.sysjobservers sjs LEFT OUTER JOIN msdb.dbo.sysjobs sj ON(sj.job_id = sjs.job_id) WHERE sj.job_id = t1.job_id) <> 1) ''FailedJobs'',
		(SELECT count (1)
			FROM msdb.dbo.sysjobactivity ja 
			LEFT JOIN msdb.dbo.sysjobhistory jh 
			ON ja.job_history_id = jh.instance_id
			JOIN msdb.dbo.sysjobs j 
			ON ja.job_id = j.job_id
			JOIN msdb.dbo.sysjobsteps js
			ON ja.job_id = js.job_id
			AND ISNULL(ja.last_executed_step_id,0)+1 = js.step_id
			WHERE ja.session_id = (SELECT TOP 1 session_id FROM msdb.dbo.syssessions ORDER BY agent_start_date DESC)
			AND j.name NOT IN (SELECT DISTINCT JobName FROM DBA..tb_PRTG_JobWhiteList)
			AND j.enabled = 1
			AND start_execution_date is not null
			AND stop_execution_date is null
			AND start_execution_date < dateadd (day,-1,getdate())
			AND js.step_name NOT IN (''Change Data Capture Collection Agent'', ''Run agent.'')) ''LongRunningJobs'',
		(select count (1)
			from sys.dm_exec_requests
			where datediff (hh, start_time, getdate()) > 12
			and status not in (''background'', ''sleeping'') and command <> ''WAITFOR'' and last_wait_type <> ''SP_SERVER_DIAGNOSTICS_SLEEP'') ''LongRunningQueries'',
		(SELECT count (1)
			FROM master..sysprocesses
			WHERE blocked <> 0
			  AND waittime/1000/60 > 1) ''BlockedQueries'',
		(SELECT  COALESCE (SUM(CONVERT(INT, ABS(CONVERT(FLOAT, ob1.EventTime - ob.EventTime)
                                 * 24 * 60 * 60))), 0) AS SecondsPressure
    FROM    OrderedBuffers ob
            LEFT JOIN OrderedBuffers ob1 ON ob.RowNum = ob1.RowNum + 1
                                            AND ob.MemoryNodeID = ob1.MemoryNodeID
    WHERE   ob.Type = ''RESOURCE_MEMPHYSICAL_LOW'') AS ''MemPressure'',
	(select top 1
	100 - SystemIdle
	from (
	select
	record.value(''(./Record/@id)[1]'', ''int'') as record_id,
	record.value(''(./Record/SchedulerMonitorEvent/SystemHealth/SystemIdle)[1]'', ''int'')
	as SystemIdle,
	record.value(''(./Record/SchedulerMonitorEvent/SystemHealth/ProcessUtilization)[1]'',
	''int'') as SQLProcessUtilization,
	timestamp
	from (
	select timestamp, convert(xml, record) as record
	from sys.dm_os_ring_buffers
	where ring_buffer_type = N''RING_BUFFER_SCHEDULER_MONITOR''
	and record like ''%<SystemHealth>%'') as x
	) as y
	order by record_id desc) AS ''UsageCPU'',
	(select count (1)
	from sys.dm_hadr_database_replica_states
	where synchronization_health_desc <> ''HEALTHY'') AS AGHealth
	END'
END

EXEC (@SQLMonitor)
