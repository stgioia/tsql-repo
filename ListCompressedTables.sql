--Compressed Tables
select distinct t.name AS CompressedTables
from sys.partitions p
inner join sys.tables t
on p.object_id = t.object_id
where p.data_compression > 0