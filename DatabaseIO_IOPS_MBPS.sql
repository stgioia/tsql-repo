SET NOCOUNT ON
 
DECLARE @SQLRestartDateTime Datetime
DECLARE @TimeInSeconds Float
 
SELECT @SQLRestartDateTime = create_date FROM sys.databases WHERE database_id = 2
 
SET @TimeInSeconds = Datediff(s,@SQLRestartDateTime,GetDate())

    SELECT   DB_NAME(IVFS.database_id) AS DatabaseName
           , ROUND((SUM(num_of_reads + num_of_writes))/@TimeInSeconds,4) AS IOPS
           , ROUND(((SUM(num_of_bytes_read + num_of_bytes_written))/1048576.0)/@TimeInSeconds,2) AS MBPS
      FROM sys.dm_io_virtual_file_stats(null,null) IVFS
	  JOIN sys.master_files AS mf 
		ON IVFS.database_id = mf.database_id 
		AND IVFS.file_id = mf.file_id
  WHERE mf.physical_name LIKE 'D:\%'
  GROUP BY db_name(IVFS.database_id)
  ORDER BY 3 DESC
