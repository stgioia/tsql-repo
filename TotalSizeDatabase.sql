SELECT DB_NAME(database_id) AS database_name, 
    type_desc, 
    name AS FileName, 
    size/128.0 AS CurrentSizeMB
FROM sys.master_files
WHERE database_id > 6 AND type IN (0,1)

SELECT sum ((size/128)/1024)
FROM sys.master_files
WHERE database_id > 6 AND type IN (0) --datafiles only
