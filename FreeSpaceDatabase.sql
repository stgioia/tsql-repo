SELECT DISTINCT
 volume_mount_point
 , CAST( ( total_bytes / 1073741824. ) as numeric(18,4)) AS [Total_GB]
 , CAST( ( available_bytes / 1073741824. ) as numeric(18,4)) AS [Available_GB]
 , CAST(
 ( CAST( ( available_bytes / 1073741824. ) as numeric(18,4)) /
 CAST( ( total_bytes / 1073741824. ) as numeric(18,4))
 ) * 100.0000
 as numeric(18,4)) AS [PercentFree]
FROM sys.master_files AS f CROSS APPLY
 sys.dm_os_volume_stats(f.database_id, f.FILE_ID)
ORDER BY volume_mount_point;